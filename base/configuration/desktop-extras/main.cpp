#include <QAbstractListModel>
#include <algorithm>
#include <QColor>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QGuiApplication>
#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQuickWindow>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>
#include <QVariant>

#include <LayerShellQt/Window>

namespace {

struct Entry {
    QString name;
    QString icon;
    QString exec;
    QString path;
    QString categories;
    bool isDir = false;
};

QString resolveIcon(const QString &name)
{
    if (name.isEmpty())
        return {};
    if (name.startsWith("file://"))
        return name;
    if (name.startsWith('/'))
        return QFileInfo::exists(name) ? "file://" + name : QString();

    const QString home = QDir::homePath();
    const QStringList dirs = {
        "/usr/share/icons/hicolor/scalable/apps/",
        "/usr/share/icons/hicolor/512x512/apps/",
        "/usr/share/icons/hicolor/256x256/apps/",
        "/usr/share/icons/hicolor/128x128/apps/",
        "/usr/share/icons/hicolor/64x64/apps/",
        "/usr/share/icons/hicolor/48x48/apps/",
        "/usr/share/icons/Papirus/64x64/apps/",
        "/usr/share/icons/Papirus/48x48/apps/",
        "/usr/share/icons/Adwaita/64x64/apps/",
        "/usr/share/icons/Adwaita/48x48/apps/",
        "/usr/share/pixmaps/",
        "/var/lib/flatpak/exports/share/icons/hicolor/scalable/apps/",
        "/var/lib/flatpak/exports/share/icons/hicolor/512x512/apps/",
        "/var/lib/flatpak/exports/share/icons/hicolor/256x256/apps/",
        "/var/lib/flatpak/exports/share/icons/hicolor/128x128/apps/",
        home + "/.local/share/icons/hicolor/256x256/apps/",
        home + "/.local/share/icons/hicolor/scalable/apps/",
    };
    for (const QString &dir : dirs) {
        for (const QString &ext : {".png", ".svg", ".xpm"}) {
            const QString candidate = dir + name + ext;
            if (QFileInfo::exists(candidate))
                return "file://" + candidate;
        }
    }
    return {};
}

bool parseDesktop(const QString &path, Entry &out)
{
    QSettings settings(path, QSettings::IniFormat);
    settings.beginGroup("Desktop Entry");
    if (settings.value("Type", "Application").toString() != "Application")
        return false;
    if (settings.value("NoDisplay", false).toBool())
        return false;
    const QString name = settings.value("Name").toString().trimmed();
    const QString exec = settings.value("Exec").toString().trimmed();
    if (name.isEmpty() || exec.isEmpty())
        return false;

    out.name = name;
    out.exec = exec;
    out.icon = resolveIcon(settings.value("Icon").toString().trimmed());
    out.path = path;
    out.categories = settings.value("Categories").toString().trimmed();
    out.isDir = false;
    return true;
}

QString uniqueTarget(const QString &dir, const QString &base,
                     const QString &suffix = QString())
{
    QString candidate = dir + QLatin1Char('/') + base + suffix;
    int counter = 1;
    while (QFileInfo::exists(candidate)) {
        candidate = dir + QLatin1Char('/') + base
                    + QStringLiteral(" (") + QString::number(counter++) + QLatin1Char(')')
                    + suffix;
    }
    return candidate;
}

void runCommand(QString command)
{
    static const QRegularExpression placeholders("%[UuFfDdNnVvMmIiCcKk]");
    command.remove(placeholders);
    command = command.trimmed();
    if (command.isEmpty())
        return;
    QProcess::startDetached("/bin/sh", {"-c", command}, QDir::homePath());
}

QString resolveSearchIcon(const QString &name)
{
    if (name.isEmpty())
        return {};
    if (name.startsWith("file://"))
        return name;
    if (name.startsWith(QLatin1Char('/')))
        return QFileInfo::exists(name) ? "file://" + name : QString();

    const QStringList dirs = {
        "/usr/share/icons/Papirus/64x64/apps/",
        "/usr/share/icons/Papirus/48x48/apps/",
        "/usr/share/icons/Papirus/48x48/mimetypes/",
        "/usr/share/icons/Papirus/48x48/places/",
        "/usr/share/icons/Papirus/24x24/actions/",
        "/usr/share/icons/hicolor/scalable/apps/",
        "/usr/share/icons/hicolor/scalable/mimetypes/",
        "/usr/share/icons/hicolor/64x64/apps/",
        "/usr/share/icons/hicolor/48x48/apps/",
        "/usr/share/icons/Adwaita/48x48/apps/",
        "/usr/share/pixmaps/",
    };
    for (const QString &dir : dirs) {
        for (const QString &suffix : {QStringLiteral(".svg"), QStringLiteral(".png")}) {
            const QString path = dir + name + suffix;
            if (QFileInfo::exists(path))
                return "file://" + path;
        }
    }
    return {};
}

} // namespace

class DesktopModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(QString lastMessage READ lastMessage NOTIFY lastMessageChanged)

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        IconRole,
        ExecRole,
        PathRole,
        CategoriesRole,
        IsDirRole,
    };

    QString lastMessage() const { return m_lastMessage; }

    explicit DesktopModel(QObject *parent = nullptr)
        : QAbstractListModel(parent)
    {
        m_dir = QStandardPaths::writableLocation(QStandardPaths::DesktopLocation);
        if (m_dir.isEmpty())
            m_dir = QDir::homePath() + "/Desktop";
        QDir().mkpath(m_dir);
        m_watcher.addPath(m_dir);
        connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] {
            QTimer::singleShot(200, this, &DesktopModel::refresh);
        });
        refresh();
    }

    int rowCount(const QModelIndex &parent = QModelIndex()) const override
    {
        return parent.isValid() ? 0 : m_entries.size();
    }

    QVariant data(const QModelIndex &index, int role) const override
    {
        if (!index.isValid() || index.row() < 0 || index.row() >= m_entries.size())
            return {};
        const Entry &entry = m_entries.at(index.row());
        switch (role) {
        case NameRole:
            return entry.name;
        case IconRole:
            return entry.icon;
        case ExecRole:
            return entry.exec;
        case PathRole:
            return entry.path;
        case CategoriesRole:
            return entry.categories;
        case IsDirRole:
            return entry.isDir;
        default:
            return {};
        }
    }

    QHash<int, QByteArray> roleNames() const override
    {
        return {
            {NameRole, "name"},
            {IconRole, "icon"},
            {ExecRole, "exec"},
            {PathRole, "path"},
            {CategoriesRole, "categories"},
            {IsDirRole, "isDir"},
        };
    }

    Q_INVOKABLE void refresh()
    {
        beginResetModel();
        m_entries.clear();
        const QFileInfoList dirs = QDir(m_dir).entryInfoList(
            QDir::Dirs | QDir::NoDotAndDotDot | QDir::Readable, QDir::Name);
        for (const QFileInfo &dir : dirs) {
            if (dir.fileName().startsWith(QLatin1Char('.')))
                continue;
            Entry entry;
            entry.name = dir.fileName();
            entry.path = dir.absoluteFilePath();
            entry.icon = QStringLiteral("file:///usr/share/icons/Papirus/48x48/places/folder.svg");
            entry.isDir = true;
            m_entries.append(entry);
        }
        const QFileInfoList files = QDir(m_dir).entryInfoList(
            {"*.desktop"}, QDir::Files | QDir::Readable, QDir::Name);
        for (const QFileInfo &file : files) {
            Entry entry;
            if (parseDesktop(file.absoluteFilePath(), entry))
                m_entries.append(entry);
        }
        std::sort(m_entries.begin(), m_entries.end(), [](const Entry &a, const Entry &b) {
            if (a.isDir != b.isDir)
                return a.isDir;
            return a.name.toLower() < b.name.toLower();
        });
        endResetModel();
        emit countChanged();
        if (!m_watcher.files().contains(m_dir))
            m_watcher.addPath(m_dir);
    }

    Q_INVOKABLE void launch(int index)
    {
        if (index < 0 || index >= m_entries.size())
            return;
        const Entry &entry = m_entries.at(index);
        if (entry.isDir) {
            QString explorer =
                QStandardPaths::findExecutable(QStringLiteral("elvonos-explorer"));
            if (explorer.isEmpty())
                explorer = QStandardPaths::findExecutable(QStringLiteral("thunar"));
            if (!explorer.isEmpty())
                QProcess::startDetached(explorer, {entry.path});
        } else {
            runCommand(entry.exec);
        }
    }

    Q_INVOKABLE bool isDirAt(int index) const
    {
        return index >= 0 && index < m_entries.size() && m_entries.at(index).isDir;
    }

    Q_INVOKABLE QVariantList entriesIn(const QString &directory) const
    {
        QList<Entry> entries;
        const QFileInfoList files = QDir(directory).entryInfoList(
            {QStringLiteral("*.desktop")}, QDir::Files | QDir::Readable, QDir::Name);
        for (const QFileInfo &file : files) {
            Entry entry;
            if (parseDesktop(file.absoluteFilePath(), entry))
                entries.append(entry);
        }
        std::sort(entries.begin(), entries.end(), [](const Entry &a, const Entry &b) {
            return a.name.toLower() < b.name.toLower();
        });

        QVariantList result;
        for (const Entry &entry : entries) {
            QVariantMap item;
            item.insert(QStringLiteral("name"), entry.name);
            item.insert(QStringLiteral("icon"), entry.icon);
            item.insert(QStringLiteral("exec"), entry.exec);
            item.insert(QStringLiteral("path"), entry.path);
            result.append(item);
        }
        return result;
    }

    Q_INVOKABLE void launchEntry(const QString &path)
    {
        Entry entry;
        if (parseDesktop(path, entry))
            runCommand(entry.exec);
    }

    Q_INVOKABLE bool copyEntry(int index)
    {
        if (index < 0 || index >= m_entries.size())
            return false;
        const Entry &entry = m_entries.at(index);
        const QFileInfo info(entry.path);
        const QString targetBase = entry.isDir ? entry.name
                                               : info.completeBaseName();
        const QString suffix = entry.isDir ? QString() : QStringLiteral(".desktop");
        const QString target = uniqueTarget(m_dir, targetBase + QStringLiteral(" copy"),
                                            suffix);
        bool ok = false;
        if (entry.isDir) {
            ok = copyDirectory(entry.path, target);
        } else {
            ok = QFile::copy(entry.path, target);
            if (ok)
                setDesktopName(target, targetBase + QStringLiteral(" copy"));
        }
        setMessage(ok ? QStringLiteral("Copied %1").arg(entry.name)
                      : QStringLiteral("Could not copy %1").arg(entry.name));
        if (ok)
            refresh();
        return ok;
    }

    Q_INVOKABLE bool renameEntry(int index, const QString &newName)
    {
        if (index < 0 || index >= m_entries.size())
            return false;
        QString name = newName.trimmed();
        if (name.endsWith(QStringLiteral(".desktop")))
            name.chop(9);
        if (name.isEmpty())
            return false;
        const Entry &entry = m_entries.at(index);
        const QFileInfo info(entry.path);
        const QString suffix = entry.isDir ? QString() : QStringLiteral(".desktop");
        QString target = m_dir + QLatin1Char('/') + name + suffix;
        if (target == entry.path)
            return true;
        target = uniqueTarget(m_dir, name, suffix);
        bool ok = false;
        if (entry.isDir) {
            ok = QDir().rename(entry.path, target);
        } else {
            ok = QFile::rename(entry.path, target);
            if (ok)
                setDesktopName(target, name);
        }
        setMessage(ok ? QStringLiteral("Renamed to %1").arg(QFileInfo(target).fileName())
                      : QStringLiteral("Could not rename %1").arg(entry.name));
        if (ok)
            refresh();
        return ok;
    }

    Q_INVOKABLE bool deleteEntry(int index)
    {
        if (index < 0 || index >= m_entries.size())
            return false;
        const Entry entry = m_entries.at(index);
        bool ok = QFile::moveToTrash(entry.path);
        if (!ok) {
            if (entry.isDir)
                ok = QDir(entry.path).removeRecursively();
            else
                ok = QFile::remove(entry.path);
        }
        setMessage(ok ? QStringLiteral("Moved %1 to Trash").arg(entry.name)
                      : QStringLiteral("Could not delete %1").arg(entry.name));
        if (ok)
            refresh();
        return ok;
    }

    Q_INVOKABLE bool groupEntry(int index, const QString &groupName)
    {
        if (index < 0 || index >= m_entries.size())
            return false;
        QString name = groupName.trimmed();
        if (name.isEmpty())
            return false;
        const Entry &entry = m_entries.at(index);
        const QString groupDir = m_dir + QLatin1Char('/') + name;
        if (!QDir().mkpath(groupDir)) {
            setMessage(QStringLiteral("Could not create group %1").arg(name));
            return false;
        }
        const QFileInfo info(entry.path);
        const QString target = uniqueTarget(groupDir, info.fileName());
        bool ok = false;
        if (entry.isDir)
            ok = QDir().rename(entry.path, target);
        else
            ok = QFile::rename(entry.path, target);
        setMessage(ok ? QStringLiteral("Grouped %1 into %2").arg(entry.name, name)
                      : QStringLiteral("Could not group %1").arg(entry.name));
        if (ok)
            refresh();
        return ok;
    }

    Q_INVOKABLE QVariantMap properties(int index) const
    {
        QVariantMap result;
        if (index < 0 || index >= m_entries.size())
            return result;
        const Entry &entry = m_entries.at(index);
        const QFileInfo info(entry.path);
        result.insert(QStringLiteral("name"), entry.name);
        result.insert(QStringLiteral("path"), entry.path);
        result.insert(QStringLiteral("isDir"), entry.isDir);
        result.insert(QStringLiteral("type"),
                      entry.isDir ? QStringLiteral("Folder")
                                  : QStringLiteral("Desktop Entry"));
        result.insert(QStringLiteral("size"), humanSize(info.size()));
        result.insert(QStringLiteral("modified"),
                      info.lastModified().toString(QStringLiteral("yyyy-MM-dd HH:mm")));
        result.insert(QStringLiteral("exec"), entry.exec);
        result.insert(QStringLiteral("icon"), entry.icon);
        result.insert(QStringLiteral("categories"), entry.categories);
        result.insert(QStringLiteral("package"), packageFor(entry.path));
        if (!entry.isDir) {
            QSettings settings(entry.path, QSettings::IniFormat);
            settings.beginGroup(QStringLiteral("Desktop Entry"));
            result.insert(QStringLiteral("comment"),
                          settings.value(QStringLiteral("Comment")).toString());
        }
        return result;
    }

    Q_INVOKABLE bool uninstallEntry(int index)
    {
        if (index < 0 || index >= m_entries.size())
            return false;
        const Entry &entry = m_entries.at(index);
        if (entry.isDir) {
            setMessage(QStringLiteral("Folders cannot be uninstalled"));
            return false;
        }
        const QString package = packageFor(entry.path);
        if (package.isEmpty()) {
            setMessage(QStringLiteral("No installed package found for this shortcut"));
            return false;
        }
        QProcess process;
        if (package.startsWith(QStringLiteral("flatpak:"))) {
            const QString appId = package.mid(8);
            process.start(QStringLiteral("flatpak"),
                          {QStringLiteral("uninstall"), QStringLiteral("-y"), appId});
        } else {
            process.start(QStringLiteral("sudo"),
                          {QStringLiteral("-n"), QStringLiteral("apt-get"),
                           QStringLiteral("remove"), QStringLiteral("-y"), package});
        }
        if (!process.waitForFinished(180000)) {
            process.kill();
            setMessage(QStringLiteral("Uninstall timed out"));
            return false;
        }
        const bool ok = process.exitStatus() == QProcess::NormalExit
                        && process.exitCode() == 0;
        if (ok) {
            const QString message =
                QString::fromUtf8(process.readAllStandardOutput()).trimmed();
            setMessage(message.isEmpty()
                           ? QStringLiteral("Uninstalled %1").arg(package)
                           : message.split(QLatin1Char('\n')).last());
            refresh();
        } else {
            const QString error =
                QString::fromUtf8(process.readAllStandardError()).trimmed();
            setMessage(error.isEmpty()
                           ? QStringLiteral("Uninstall failed")
                           : error.split(QLatin1Char('\n')).last());
        }
        return ok;
    }

    Q_INVOKABLE QString nameAt(int index) const
    {
        return index >= 0 && index < m_entries.size() ? m_entries.at(index).name : QString();
    }

    Q_INVOKABLE QString iconAt(int index) const
    {
        return index >= 0 && index < m_entries.size() ? m_entries.at(index).icon : QString();
    }

    Q_INVOKABLE QString pathAt(int index) const
    {
        return index >= 0 && index < m_entries.size() ? m_entries.at(index).path : QString();
    }

    Q_INVOKABLE void addShortcut(const QUrl &url)
    {
        QString path = url.isLocalFile() ? url.toLocalFile() : url.toString();
        if (!path.endsWith(".desktop"))
            return;
        const QFileInfo info(path);
        if (!info.exists() || !info.isFile())
            return;
        const QString target = QDir(m_dir).filePath(info.fileName());
        if (QFileInfo::exists(target))
            return;
        if (QFile::copy(info.absoluteFilePath(), target))
            refresh();
    }

signals:
    void countChanged();
    void lastMessageChanged();

private:
    void setMessage(const QString &message)
    {
        m_lastMessage = message;
        emit lastMessageChanged();
    }

    static void setDesktopName(const QString &path, const QString &name)
    {
        QSettings settings(path, QSettings::IniFormat);
        settings.beginGroup(QStringLiteral("Desktop Entry"));
        settings.setValue(QStringLiteral("Name"), name);
        settings.sync();
    }

    static bool copyDirectory(const QString &source, const QString &target)
    {
        QDir dir(source);
        if (!QDir().mkpath(target))
            return false;
        const QFileInfoList entries = dir.entryInfoList(
            QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot);
        for (const QFileInfo &entry : entries) {
            const QString destination = target + QLatin1Char('/') + entry.fileName();
            if (entry.isDir()) {
                if (!copyDirectory(entry.absoluteFilePath(), destination))
                    return false;
            } else if (!QFile::copy(entry.absoluteFilePath(), destination)) {
                return false;
            }
        }
        return true;
    }

    static QString humanSize(qint64 bytes)
    {
        if (bytes < 1024)
            return QString::number(bytes) + QStringLiteral(" B");
        const double kb = bytes / 1024.0;
        if (kb < 1024)
            return QString::number(kb, 'f', 0) + QStringLiteral(" KB");
        const double mb = kb / 1024.0;
        return QString::number(mb, 'f', 1) + QStringLiteral(" MB");
    }

    static QString packageFor(const QString &path)
    {
        // Desktop shortcuts are copies of the system entries; resolve the
        // owning package through the matching /usr/share/applications file.
        QString lookupPath = path;
        if (path.startsWith(QDir::homePath() + QStringLiteral("/Desktop/"))) {
            const QString candidate = QStringLiteral("/usr/share/applications/")
                                      + QFileInfo(path).fileName();
            if (QFileInfo::exists(candidate))
                lookupPath = candidate;
        }
        if (lookupPath.startsWith(QStringLiteral("/var/lib/flatpak/exports/share/applications/")))
            return QStringLiteral("flatpak:") + QFileInfo(lookupPath).completeBaseName();
        if (!lookupPath.startsWith(QStringLiteral("/usr/share/applications/"))
            && !lookupPath.startsWith(QStringLiteral("/usr/local/share/applications/")))
            return {};
        QProcess process;
        process.start(QStringLiteral("dpkg-query"),
                      {QStringLiteral("-S"), lookupPath});
        if (!process.waitForFinished(5000)
            || process.exitStatus() != QProcess::NormalExit
            || process.exitCode() != 0)
            return {};
        const QString output =
            QString::fromUtf8(process.readAllStandardOutput()).trimmed();
        if (output.isEmpty())
            return {};
        QString package = output.section(QLatin1Char(':'), 0, 0).trimmed();
        if (package.contains(QLatin1Char(',')))
            package = package.section(QLatin1Char(','), 0, 0).trimmed();
        return package;
    }

    QList<Entry> m_entries;
    QFileSystemWatcher m_watcher;
    QString m_dir;
    QString m_lastMessage;
};

class DockModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        IconRole,
        ExecRole,
        PathRole,
    };

    explicit DockModel(QObject *parent = nullptr)
        : QAbstractListModel(parent)
    {
        m_config = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
                   + "/elvonos/dock.json";
        load();
    }

    int rowCount(const QModelIndex &parent = QModelIndex()) const override
    {
        return parent.isValid() ? 0 : m_entries.size();
    }

    QVariant data(const QModelIndex &index, int role) const override
    {
        if (!index.isValid() || index.row() < 0 || index.row() >= m_entries.size())
            return {};
        const Entry &entry = m_entries.at(index.row());
        switch (role) {
        case NameRole:
            return entry.name;
        case IconRole:
            return entry.icon;
        case ExecRole:
            return entry.exec;
        case PathRole:
            return entry.path;
        default:
            return {};
        }
    }

    QHash<int, QByteArray> roleNames() const override
    {
        return {
            {NameRole, "name"},
            {IconRole, "icon"},
            {ExecRole, "exec"},
            {PathRole, "path"},
        };
    }

    Q_INVOKABLE void addFile(const QUrl &url)
    {
        QString path = url.isLocalFile() ? url.toLocalFile() : url.toString();
        if (!path.endsWith(".desktop"))
            return;
        const QFileInfo info(path);
        if (!info.exists() || !info.isFile())
            return;
        path = info.absoluteFilePath();
        if (m_paths.contains(path))
            return;
        m_paths.append(path);
        rebuild();
        save();
    }

    Q_INVOKABLE void removeAt(int index)
    {
        if (index < 0 || index >= m_paths.size())
            return;
        m_paths.removeAt(index);
        rebuild();
        save();
    }

    Q_INVOKABLE void launch(int index)
    {
        if (index < 0 || index >= m_entries.size())
            return;
        runCommand(m_entries.at(index).exec);
    }

    Q_INVOKABLE void showDesktop()
    {
        QString executable = QStandardPaths::findExecutable("Win8Running");
        if (executable.isEmpty())
            executable = "/usr/local/bin/Win8Running";
        QProcess::startDetached(executable, {"--minimize"}, QDir::homePath());
    }

signals:
    void countChanged();

private:
    QString m_config;
    QStringList m_paths;
    QList<Entry> m_entries;

    static QStringList defaultPaths()
    {
        // Keep the dock focused on the four primary applications; every other
        // application lives in the grouped folders on the desktop.
        return {
            "/usr/share/applications/elvonos-explorer.desktop",
            "/usr/share/applications/elvonos-store.desktop",
            "/usr/share/applications/elvonos-screenshot.desktop",
            "/usr/share/applications/elvonos-media.desktop",
        };
    }

    void load()
    {
        QFile file(m_config);
        if (file.open(QIODevice::ReadOnly)) {
            const QJsonDocument document = QJsonDocument::fromJson(file.readAll());
            if (document.isArray()) {
                for (const QJsonValue &value : document.array()) {
                    if (value.isString())
                        m_paths.append(value.toString());
                }
            }
        }
        // The unified Store replaces the standalone Aurora and Bazaar shortcuts.
        m_paths.erase(std::remove_if(m_paths.begin(), m_paths.end(),
                                     [](const QString &path) {
                                         return path.contains("io.github.kolunmi.Bazaar")
                                                || path.contains("waydroid-com.aurora.store");
                                     }),
                      m_paths.end());
        if (m_paths.isEmpty())
            m_paths = defaultPaths();
        rebuild();
    }

    void save() const
    {
        QDir().mkpath(QFileInfo(m_config).absolutePath());
        QJsonArray array;
        for (const QString &path : m_paths)
            array.append(path);
        QFile file(m_config);
        if (file.open(QIODevice::WriteOnly | QIODevice::Truncate))
            file.write(QJsonDocument(array).toJson());
    }

    void rebuild()
    {
        beginResetModel();
        m_entries.clear();
        QStringList kept;
        for (const QString &path : m_paths) {
            Entry entry;
            if (parseDesktop(path, entry)) {
                m_entries.append(entry);
                kept.append(path);
            }
        }
        m_paths = kept;
        endResetModel();
        emit countChanged();
    }
};

/* ---------------- Desktop search ---------------- */

class SearchModel : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList results READ results NOTIFY resultsChanged)
    Q_PROPERTY(QString query READ query NOTIFY queryChanged)

public:
    explicit SearchModel(QObject *parent = nullptr)
        : QObject(parent)
    {
    }

    QVariantList results() const { return m_results; }
    QString query() const { return m_query; }

    Q_INVOKABLE void setQuery(const QString &query)
    {
        const QString trimmed = query.trimmed();
        if (trimmed == m_query)
            return;
        m_query = trimmed;
        emit queryChanged();
        rebuild();
    }

    Q_INVOKABLE void clear()
    {
        setQuery(QString());
    }

    void ensureIndex()
    {
        if (m_indexBuilt)
            return;
        buildAppIndex();
        m_indexBuilt = true;
    }

    Q_INVOKABLE void activate(int index)
    {
        if (index < 0 || index >= m_results.size())
            return;
        const QVariantMap item = m_results.at(index).toMap();
        if (item.value(QStringLiteral("kind")).toString() != QStringLiteral("item"))
            return;
        const QString type = item.value(QStringLiteral("type")).toString();
        if (type == QStringLiteral("app")) {
            runCommand(item.value(QStringLiteral("command")).toString());
        } else if (type == QStringLiteral("file")) {
            QProcess::startDetached(QStringLiteral("xdg-open"),
                                    {item.value(QStringLiteral("path")).toString()});
        }
        clear();
    }

signals:
    void resultsChanged();
    void queryChanged();

private:
    struct AppEntry {
        QString name;
        QString exec;
        QString icon;
    };

    void buildAppIndex()
    {
        const QStringList dirs = {
            QStringLiteral("/usr/share/applications"),
            QStringLiteral("/usr/local/share/applications"),
            QDir::homePath() + QStringLiteral("/.local/share/applications"),
            QStringLiteral("/var/lib/flatpak/exports/share/applications"),
            QDir::homePath() + QStringLiteral("/.local/share/flatpak/exports/share/applications"),
        };
        QStringList seen;
        for (const QString &dir : dirs) {
            QDirIterator it(dir, {QStringLiteral("*.desktop")}, QDir::Files);
            while (it.hasNext()) {
                const QString path = it.next();
                QSettings settings(path, QSettings::IniFormat);
                if (settings.value(QStringLiteral("Desktop Entry/NoDisplay"), false).toBool())
                    continue;
                if (settings.value(QStringLiteral("Desktop Entry/Type"),
                                   QStringLiteral("Application")).toString()
                    != QStringLiteral("Application"))
                    continue;
                const QString name = settings.value(QStringLiteral("Desktop Entry/Name"))
                                         .toString().trimmed();
                const QString exec = settings.value(QStringLiteral("Desktop Entry/Exec"))
                                         .toString().trimmed();
                if (name.isEmpty() || exec.isEmpty())
                    continue;
                const QString key = name.toLower();
                if (seen.contains(key))
                    continue;
                seen.append(key);
                AppEntry entry;
                entry.name = name;
                entry.exec = exec;
                entry.icon = resolveSearchIcon(
                    settings.value(QStringLiteral("Desktop Entry/Icon")).toString().trimmed());
                m_apps.append(entry);
            }
        }
    }

    void rebuild()
    {
        m_results.clear();
        if (m_query.isEmpty()) {
            emit resultsChanged();
            return;
        }

        // Build the application index on the first search instead of during
        // startup: on a cold squashfs image this scan can take a while and
        // would otherwise delay the whole desktop surface.
        ensureIndex();

        QVariantList apps;
        for (const AppEntry &app : m_apps) {
            if (!app.name.contains(m_query, Qt::CaseInsensitive))
                continue;
            QVariantMap item;
            item.insert(QStringLiteral("kind"), QStringLiteral("item"));
            item.insert(QStringLiteral("type"), QStringLiteral("app"));
            item.insert(QStringLiteral("name"), app.name);
            item.insert(QStringLiteral("detail"), QStringLiteral("Application"));
            item.insert(QStringLiteral("icon"), app.icon);
            item.insert(QStringLiteral("command"), app.exec);
            apps.append(item);
            if (apps.size() >= 6)
                break;
        }
        if (!apps.isEmpty()) {
            QVariantMap header;
            header.insert(QStringLiteral("kind"), QStringLiteral("header"));
            header.insert(QStringLiteral("name"), QStringLiteral("APPLICATIONS"));
            m_results.append(header);
            for (const QVariant &entry : apps)
                m_results.append(entry);
        }

        const QVariantList files = findFiles(m_query, 4);
        if (!files.isEmpty()) {
            QVariantMap header;
            header.insert(QStringLiteral("kind"), QStringLiteral("header"));
            header.insert(QStringLiteral("name"), QStringLiteral("FILES"));
            m_results.append(header);
            for (const QVariant &entry : files)
                m_results.append(entry);
        }

        emit resultsChanged();
    }

    QVariantList findFiles(const QString &query, int limit) const
    {
        const QStringList roots = {
            QStandardPaths::writableLocation(QStandardPaths::DesktopLocation),
            QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation),
            QStandardPaths::writableLocation(QStandardPaths::DownloadLocation),
            QStandardPaths::writableLocation(QStandardPaths::PicturesLocation),
            QStandardPaths::writableLocation(QStandardPaths::MusicLocation),
            QStandardPaths::writableLocation(QStandardPaths::MoviesLocation),
        };
        QVariantList found;
        int visited = 0;
        const QString home = QDir::homePath();
        for (const QString &root : roots) {
            if (found.size() >= limit)
                break;
            if (root.isEmpty() || !QDir(root).exists())
                continue;
            QDirIterator it(root,
                            QDir::Files | QDir::Readable | QDir::NoDotAndDotDot,
                            QDirIterator::Subdirectories);
            while (it.hasNext() && visited < 4000 && found.size() < limit) {
                const QString path = it.next();
                ++visited;
                if (path.contains(QStringLiteral("/.")))
                    continue;
                const QFileInfo info(path);
                if (info.suffix().compare(QStringLiteral("desktop"), Qt::CaseInsensitive) == 0)
                    continue;
                if (!info.fileName().contains(query, Qt::CaseInsensitive))
                    continue;

                QVariantMap item;
                item.insert(QStringLiteral("kind"), QStringLiteral("item"));
                item.insert(QStringLiteral("type"), QStringLiteral("file"));
                item.insert(QStringLiteral("name"), info.fileName());
                QString directory = info.absolutePath();
                if (directory.startsWith(home))
                    directory = QStringLiteral("~") + directory.mid(home.size());
                item.insert(QStringLiteral("detail"), directory);
                item.insert(QStringLiteral("path"), path);
                item.insert(QStringLiteral("icon"), iconForFile(info));
                found.append(item);
            }
        }
        return found;
    }

    static QString iconForFile(const QFileInfo &info)
    {
        static const QStringList imageSuffixes = {
            QStringLiteral("png"), QStringLiteral("jpg"), QStringLiteral("jpeg"),
            QStringLiteral("gif"), QStringLiteral("webp"), QStringLiteral("bmp"),
            QStringLiteral("svg"), QStringLiteral("tif"), QStringLiteral("tiff"),
        };
        static const QStringList audioSuffixes = {
            QStringLiteral("mp3"), QStringLiteral("flac"), QStringLiteral("ogg"),
            QStringLiteral("wav"), QStringLiteral("opus"), QStringLiteral("m4a"),
        };
        static const QStringList videoSuffixes = {
            QStringLiteral("mp4"), QStringLiteral("mkv"), QStringLiteral("webm"),
            QStringLiteral("avi"), QStringLiteral("mov"),
        };
        static const QStringList archiveSuffixes = {
            QStringLiteral("zip"), QStringLiteral("tar"), QStringLiteral("gz"),
            QStringLiteral("xz"), QStringLiteral("7z"), QStringLiteral("deb"),
        };
        const QString suffix = info.suffix().toLower();
        if (imageSuffixes.contains(suffix))
            return resolveSearchIcon(QStringLiteral("image-x-generic"));
        if (audioSuffixes.contains(suffix))
            return resolveSearchIcon(QStringLiteral("audio-x-generic"));
        if (videoSuffixes.contains(suffix))
            return resolveSearchIcon(QStringLiteral("video-x-generic"));
        if (archiveSuffixes.contains(suffix))
            return resolveSearchIcon(QStringLiteral("package-x-generic"));
        if (suffix == QStringLiteral("pdf"))
            return resolveSearchIcon(QStringLiteral("application-pdf"));
        return resolveSearchIcon(QStringLiteral("text-x-generic"));
    }

    QList<AppEntry> m_apps;
    QVariantList m_results;
    QString m_query;
    bool m_indexBuilt = false;
};

class PanelLayout : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString dockPosition READ dockPosition NOTIFY dockPositionChanged)

public:
    explicit PanelLayout(QObject *parent = nullptr) : QObject(parent)
    {
        m_path = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
                 + QStringLiteral("/elvonos/panels.json");
        QDir().mkpath(QFileInfo(m_path).absolutePath());
        reload();
        m_watcher.addPath(QFileInfo(m_path).absolutePath());
        if (QFileInfo::exists(m_path))
            m_watcher.addPath(m_path);
        connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] {
            if (!m_watcher.files().contains(m_path) && QFileInfo::exists(m_path))
                m_watcher.addPath(m_path);
            reload();
        });
        connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] {
            if (!m_watcher.files().contains(m_path) && QFileInfo::exists(m_path))
                m_watcher.addPath(m_path);
            reload();
        });
    }

    QString dockPosition() const { return m_position; }

signals:
    void dockPositionChanged();

private:
    void reload()
    {
        QString position = QStringLiteral("bottom");
        QFile file(m_path);
        if (file.open(QIODevice::ReadOnly)) {
            const QJsonObject object =
                QJsonDocument::fromJson(file.readAll()).object();
            position = object.value(QStringLiteral("dockPosition"))
                           .toString(position);
        }
        position = position == QStringLiteral("top") ? QStringLiteral("top")
                                                     : QStringLiteral("bottom");
        if (position != m_position) {
            m_position = position;
            emit dockPositionChanged();
        }
    }

    QString m_path;
    QFileSystemWatcher m_watcher;
    QString m_position = QStringLiteral("bottom");
};

class DesktopLang : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString language READ language NOTIFY languageChanged)
    Q_PROPERTY(int revision READ revision NOTIFY languageChanged)

public:
    explicit DesktopLang(QObject *parent = nullptr) : QObject(parent)
    {
        const QString configHome =
            QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
        m_path = configHome + QStringLiteral("/elvonos/language");
        QDir().mkpath(QFileInfo(m_path).absolutePath());
        reload();
        m_watcher.addPath(QFileInfo(m_path).absolutePath());
        if (QFileInfo::exists(m_path))
            m_watcher.addPath(m_path);
        connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] {
            if (!m_watcher.files().contains(m_path) && QFileInfo::exists(m_path))
                m_watcher.addPath(m_path);
            reload();
        });
        connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] {
            if (!m_watcher.files().contains(m_path) && QFileInfo::exists(m_path))
                m_watcher.addPath(m_path);
            reload();
        });
    }

    QString language() const { return m_language; }
    int revision() const { return m_revision; }

    Q_INVOKABLE QString tr(const QString &source) const
    {
        return m_dict.value(source, source);
    }

signals:
    void languageChanged();

private:
    static QStringList supported()
    {
        return {QStringLiteral("en"), QStringLiteral("de"), QStringLiteral("fr"),
                QStringLiteral("es"), QStringLiteral("it"), QStringLiteral("pt"),
                QStringLiteral("nl"), QStringLiteral("pl"), QStringLiteral("ru"),
                QStringLiteral("tr"), QStringLiteral("uk"), QStringLiteral("cs"),
                QStringLiteral("sv"), QStringLiteral("zh"), QStringLiteral("ja")};
    }

    void reload()
    {
        QString code;
        QFile file(m_path);
        if (file.open(QIODevice::ReadOnly))
            code = QString::fromUtf8(file.readAll()).trimmed();
        if (code.isEmpty()) {
            const QString environment = qEnvironmentVariable("LANG");
            for (const QString &candidate : supported()) {
                if (environment.startsWith(candidate)) {
                    code = candidate;
                    break;
                }
            }
        }
        if (!supported().contains(code))
            code = QStringLiteral("en");
        if (code == m_language && !m_dict.isEmpty())
            return;
        m_language = code;
        m_dict.clear();
        if (code != QStringLiteral("en")) {
            QFile dictionary(QStringLiteral("/usr/share/elvonos/i18n/")
                             + code + QStringLiteral(".json"));
            if (dictionary.open(QIODevice::ReadOnly)) {
                const QJsonObject object =
                    QJsonDocument::fromJson(dictionary.readAll()).object();
                for (auto it = object.constBegin(); it != object.constEnd(); ++it)
                    m_dict.insert(it.key(), it.value().toString());
            }
        }
        m_revision++;
        emit languageChanged();
    }

    QString m_path;
    QString m_language = QStringLiteral("en");
    int m_revision = 0;
    QHash<QString, QString> m_dict;
    QFileSystemWatcher m_watcher;
};

class FormFactor : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString type READ type NOTIFY changed)
    Q_PROPERTY(double scale READ scale NOTIFY changed)
    Q_PROPERTY(bool touch READ touch NOTIFY changed)
    Q_PROPERTY(int iconSize READ iconSize NOTIFY changed)
    Q_PROPERTY(int dockHeight READ dockHeight NOTIFY changed)
    Q_PROPERTY(int searchWidth READ searchWidth NOTIFY changed)
    Q_PROPERTY(int overscan READ overscan NOTIFY changed)

public:
    explicit FormFactor(QObject *parent = nullptr) : QObject(parent)
    {
        m_path = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
                 + QStringLiteral("/elvonos/formfactor.json");
        reload();
        m_watcher.addPath(QFileInfo(m_path).absolutePath());
        if (QFileInfo::exists(m_path))
            m_watcher.addPath(m_path);
        connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] {
            if (!m_watcher.files().contains(m_path) && QFileInfo::exists(m_path))
                m_watcher.addPath(m_path);
            reload();
        });
        connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] {
            if (!m_watcher.files().contains(m_path) && QFileInfo::exists(m_path))
                m_watcher.addPath(m_path);
            reload();
        });
    }

    QString type() const { return m_type; }
    double scale() const { return m_scale; }
    bool touch() const { return m_touch; }
    int iconSize() const { return m_iconSize; }
    int dockHeight() const { return m_dockHeight; }
    int searchWidth() const { return m_searchWidth; }
    int overscan() const { return m_overscan; }

signals:
    void changed();

private:
    void reload()
    {
        QString type = QStringLiteral("pc");
        double scale = 1.0;
        bool touch = false;
        int iconSize = 64;
        int dockHeight = 86;
        int searchWidth = 470;
        int overscan = 0;
        QFile file(m_path);
        if (file.open(QIODevice::ReadOnly)) {
            const QJsonObject object =
                QJsonDocument::fromJson(file.readAll()).object();
            type = object.value(QStringLiteral("type")).toString(type);
            scale = object.value(QStringLiteral("scale")).toDouble(scale);
            touch = object.value(QStringLiteral("touch")).toBool(touch);
            iconSize = object.value(QStringLiteral("iconSize")).toInt(iconSize);
            dockHeight = object.value(QStringLiteral("dockHeight")).toInt(dockHeight);
            searchWidth = object.value(QStringLiteral("searchWidth")).toInt(searchWidth);
            overscan = object.value(QStringLiteral("overscan")).toInt(overscan);
        }
        if (type == m_type && qFuzzyCompare(scale, m_scale) && touch == m_touch
            && iconSize == m_iconSize && dockHeight == m_dockHeight
            && searchWidth == m_searchWidth && overscan == m_overscan)
            return;
        m_type = type;
        m_scale = scale;
        m_touch = touch;
        m_iconSize = iconSize;
        m_dockHeight = dockHeight;
        m_searchWidth = searchWidth;
        m_overscan = overscan;
        emit changed();
    }

    QString m_path;
    QFileSystemWatcher m_watcher;
    QString m_type = QStringLiteral("pc");
    double m_scale = 1.0;
    bool m_touch = false;
    int m_iconSize = 64;
    int m_dockHeight = 86;
    int m_searchWidth = 470;
    int m_overscan = 0;
};

class ThemeSettings : public QObject {
    Q_OBJECT
    Q_PROPERTY(QColor accent READ accent NOTIFY themeChanged)
    Q_PROPERTY(QColor accent2 READ accent2 NOTIFY themeChanged)
    Q_PROPERTY(QColor panel READ panel NOTIFY themeChanged)
    Q_PROPERTY(QColor background READ background NOTIFY themeChanged)
    Q_PROPERTY(QColor surface READ surface NOTIFY themeChanged)
    Q_PROPERTY(QColor text READ text NOTIFY themeChanged)
    Q_PROPERTY(QColor muted READ muted NOTIFY themeChanged)
    Q_PROPERTY(QColor border READ border NOTIFY themeChanged)
    Q_PROPERTY(int radius READ radius NOTIFY themeChanged)
    Q_PROPERTY(int glass READ glass NOTIFY themeChanged)

public:
    explicit ThemeSettings(QObject *parent = nullptr) : QObject(parent)
    {
        m_path = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
                 + QStringLiteral("/elvonos/theme.json");
        reload();
        m_watcher.addPath(QFileInfo(m_path).absolutePath());
        if (QFileInfo::exists(m_path))
            m_watcher.addPath(m_path);
        connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] {
            if (!m_watcher.files().contains(m_path) && QFileInfo::exists(m_path))
                m_watcher.addPath(m_path);
            reload();
        });
        connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] {
            if (!m_watcher.files().contains(m_path) && QFileInfo::exists(m_path))
                m_watcher.addPath(m_path);
            reload();
        });
    }

    QColor accent() const { return m_accent; }
    QColor accent2() const { return m_accent2; }
    QColor panel() const { return m_panel; }
    QColor background() const { return m_background; }
    QColor surface() const { return m_surface; }
    QColor text() const { return m_text; }
    QColor muted() const { return m_muted; }
    QColor border() const { return m_border; }
    int radius() const { return m_radius; }
    int glass() const { return m_glass; }

signals:
    void themeChanged();

private:
    void reload()
    {
        QColor accent(QStringLiteral("#4CC2FF"));
        QColor accent2(QStringLiteral("#8FD3FF"));
        QColor panel(QStringLiteral("#15151C"));
        QColor background(QStringLiteral("#101016"));
        QColor surface(QStringLiteral("#1B1B26"));
        QColor text(QStringLiteral("#E9ECF2"));
        QColor muted(QStringLiteral("#8B93A1"));
        QColor border(QStringLiteral("#FFFFFF"));
        int radius = 14;
        int glass = 78;
        QFile file(m_path);
        if (file.open(QIODevice::ReadOnly)) {
            const QJsonObject object =
                QJsonDocument::fromJson(file.readAll()).object();
            auto take = [&object](const QString &key, QColor &value) {
                const QColor configured(object.value(key).toString());
                if (configured.isValid())
                    value = configured;
            };
            take(QStringLiteral("accent"), accent);
            take(QStringLiteral("accent2"), accent2);
            take(QStringLiteral("panel"), panel);
            take(QStringLiteral("background"), background);
            take(QStringLiteral("surface"), surface);
            take(QStringLiteral("text"), text);
            take(QStringLiteral("muted"), muted);
            take(QStringLiteral("border"), border);
            radius = qBound(0, object.value(QStringLiteral("radius")).toInt(radius), 28);
            glass = qBound(0, object.value(QStringLiteral("glass")).toInt(glass), 100);
        }
        if (accent == m_accent && accent2 == m_accent2 && panel == m_panel && background == m_background
            && surface == m_surface && text == m_text && muted == m_muted
            && border == m_border && radius == m_radius && glass == m_glass)
            return;
        m_accent = accent;
        m_accent2 = accent2;
        m_panel = panel;
        m_background = background;
        m_surface = surface;
        m_text = text;
        m_muted = muted;
        m_border = border;
        m_radius = radius;
        m_glass = glass;
        emit themeChanged();
    }

    QString m_path;
    QFileSystemWatcher m_watcher;
    QColor m_accent = QColor(QStringLiteral("#4CC2FF"));
    QColor m_accent2 = QColor(QStringLiteral("#8FD3FF"));
    QColor m_panel = QColor(QStringLiteral("#15151C"));
    QColor m_background = QColor(QStringLiteral("#101016"));
    QColor m_surface = QColor(QStringLiteral("#1B1B26"));
    QColor m_text = QColor(QStringLiteral("#E9ECF2"));
    QColor m_muted = QColor(QStringLiteral("#8B93A1"));
    QColor m_border = QColor(QStringLiteral("#FFFFFF"));
    int m_radius = 14;
    int m_glass = 78;
};

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;

    DesktopModel desktopModel;
    DockModel dockModel;
    SearchModel desktopSearch;
    PanelLayout panelLayout;
    ThemeSettings themeSettings;
    FormFactor formFactor;
    DesktopLang desktopLang;
    engine.rootContext()->setContextProperty("desktopModel", &desktopModel);
    engine.rootContext()->setContextProperty("dockModel", &dockModel);
    engine.rootContext()->setContextProperty("desktopSearch", &desktopSearch);
    engine.rootContext()->setContextProperty("desktopLang", &desktopLang);
    engine.rootContext()->setContextProperty("panelLayout", &panelLayout);
    engine.rootContext()->setContextProperty("themeSettings", &themeSettings);
    engine.rootContext()->setContextProperty("formFactor", &formFactor);
    engine.rootContext()->setContextProperty(
        "desktopTest", qEnvironmentVariable("ELVONOS_DESKTOP_TEST"));

    auto createWindow = [&engine](const QString &resource, const QString &scope,
                                  LayerShellQt::Window::Layer layer,
                                  const LayerShellQt::Window::Anchors &anchors,
                                  int exclusiveZone,
                                  LayerShellQt::Window::KeyboardInteractivity keyboard) -> QQuickWindow * {
        QQmlComponent component(&engine, QUrl(resource));
        if (component.isError()) {
            qWarning() << "Failed to load" << resource << ":" << component.errorString();
            return nullptr;
        }
        QObject *object = component.create();
        auto *window = qobject_cast<QQuickWindow *>(object);
        if (!window) {
            qWarning() << resource << "did not create a window";
            return nullptr;
        }
        window->setFlags(Qt::FramelessWindowHint);
        auto *layerWindow = LayerShellQt::Window::get(window);
        if (layerWindow) {
            layerWindow->setLayer(layer);
            layerWindow->setAnchors(anchors);
            layerWindow->setExclusiveZone(exclusiveZone);
            layerWindow->setKeyboardInteractivity(keyboard);
            layerWindow->setScope(scope);
        }
        window->show();
        return window;
    };

    createWindow("qrc:/DesktopIcons.qml", "elvonos-desktop-icons",
                 LayerShellQt::Window::LayerBottom,
                 {LayerShellQt::Window::AnchorTop | LayerShellQt::Window::AnchorBottom
                  | LayerShellQt::Window::AnchorLeft | LayerShellQt::Window::AnchorRight},
                 0, LayerShellQt::Window::KeyboardInteractivityOnDemand);

    QQuickWindow *dockWindow = createWindow(
        "qrc:/Dock.qml", "elvonos-dock",
        LayerShellQt::Window::LayerTop,
        {LayerShellQt::Window::AnchorBottom | LayerShellQt::Window::AnchorLeft
         | LayerShellQt::Window::AnchorRight},
        formFactor.dockHeight(), LayerShellQt::Window::KeyboardInteractivityOnDemand);

    auto *dockLayer = dockWindow ? LayerShellQt::Window::get(dockWindow) : nullptr;
    auto applyDockPlacement = [dockLayer, &panelLayout, &formFactor]() {
        if (!dockLayer)
            return;
        const bool top = panelLayout.dockPosition() == QStringLiteral("top");
        dockLayer->setAnchors({top ? LayerShellQt::Window::AnchorTop
                                   : LayerShellQt::Window::AnchorBottom,
                               LayerShellQt::Window::AnchorLeft,
                               LayerShellQt::Window::AnchorRight});
        dockLayer->setExclusiveZone(formFactor.dockHeight());
    };
    applyDockPlacement();
    QObject::connect(&panelLayout, &PanelLayout::dockPositionChanged,
                     &app, applyDockPlacement);
    QObject::connect(&formFactor, &FormFactor::changed, &app, [dockLayer, &formFactor] {
        if (dockLayer)
            dockLayer->setExclusiveZone(formFactor.dockHeight());
    });

    // Warm the application index once the desktop is on screen, so the first
    // search does not have to scan the .desktop files in the foreground.
    QTimer::singleShot(4000, &app, [&desktopSearch]() {
        desktopSearch.ensureIndex();
    });

    const QString searchTest = qEnvironmentVariable("ELVONOS_DESKTOP_SEARCH");
    if (!searchTest.isEmpty()) {
        QTimer::singleShot(6000, &app, [&desktopSearch, searchTest]() {
            desktopSearch.setQuery(searchTest);
        });
    }

    return app.exec();
}

#include "main.moc"

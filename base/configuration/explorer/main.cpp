#include <QAbstractListModel>
#include <QClipboard>
#include <QColor>
#include <QDateTime>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QGuiApplication>
#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QMimeDatabase>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QTimer>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>

#include <algorithm>

namespace {

struct Entry {
    QString name;
    QString path;
    bool isDir = false;
    bool isImage = false;
    qint64 bytes = 0;
    QDateTime modifiedTime;
    QString size;
    QString modified;
    QString icon;
};

QString resolveNamedIcon(const QString &name)
{
    if (name.isEmpty())
        return {};
    if (name.startsWith("file://"))
        return name;
    if (name.startsWith('/'))
        return QFileInfo::exists(name) ? "file://" + name : QString();

    const QString home = QDir::homePath();
    const QStringList dirs = {
        "/usr/share/icons/Papirus/64x64/apps/",
        "/usr/share/icons/Papirus/48x48/apps/",
        "/usr/share/icons/Papirus/64x64/places/",
        "/usr/share/icons/Papirus/48x48/places/",
        "/usr/share/icons/Papirus/64x64/devices/",
        "/usr/share/icons/Papirus/48x48/devices/",
        "/usr/share/icons/hicolor/scalable/apps/",
        "/usr/share/icons/hicolor/scalable/devices/",
        "/usr/share/icons/hicolor/256x256/apps/",
        "/usr/share/icons/hicolor/128x128/apps/",
        "/usr/share/icons/hicolor/64x64/apps/",
        "/usr/share/icons/hicolor/48x48/apps/",
        "/usr/share/icons/Adwaita/64x64/apps/",
        "/usr/share/icons/Adwaita/64x64/devices/",
        "/usr/share/pixmaps/",
        "/var/lib/flatpak/exports/share/icons/hicolor/scalable/apps/",
        "/var/lib/flatpak/exports/share/icons/hicolor/256x256/apps/",
        home + "/.local/share/icons/hicolor/256x256/apps/",
    };
    for (const QString &dir : dirs) {
        for (const QString &ext : {".svg", ".png", ".xpm"}) {
            const QString candidate = dir + name + ext;
            if (QFileInfo::exists(candidate))
                return "file://" + candidate;
        }
    }
    return {};
}

QString humanSize(qint64 bytes)
{
    if (bytes < 1024)
        return QString::number(bytes) + " B";
    const double kb = bytes / 1024.0;
    if (kb < 1024)
        return QString::number(kb, 'f', 1) + " KB";
    const double mb = kb / 1024.0;
    if (mb < 1024)
        return QString::number(mb, 'f', 1) + " MB";
    return QString::number(mb / 1024.0, 'f', 1) + " GB";
}

QString iconForFile(const QFileInfo &info)
{
    if (info.isDir())
        return resolveNamedIcon("folder");

    const QString suffix = info.suffix().toLower();
    if (QStringList{"png", "jpg", "jpeg", "gif", "webp", "bmp", "svg"}.contains(suffix))
        return resolveNamedIcon("image-x-generic");
    if (QStringList{"mp4", "mkv", "webm", "avi", "mov"}.contains(suffix))
        return resolveNamedIcon("video-x-generic");
    if (QStringList{"mp3", "flac", "ogg", "wav", "m4a"}.contains(suffix))
        return resolveNamedIcon("audio-x-generic");
    if (suffix == "pdf")
        return resolveNamedIcon("application-pdf");
    if (QStringList{"zip", "tar", "gz", "xz", "7z", "zst"}.contains(suffix))
        return resolveNamedIcon("package-x-generic");
    if (info.isExecutable())
        return resolveNamedIcon("application-x-executable");
    return resolveNamedIcon("text-x-generic");
}

bool isImageFile(const QFileInfo &info)
{
    static const QStringList suffixes{"png", "jpg", "jpeg", "webp", "bmp", "gif"};
    return info.isFile() && info.size() > 0 && info.size() < 64LL * 1024 * 1024
           && suffixes.contains(info.suffix().toLower());
}

bool copyRecursively(const QString &source, const QString &target)
{
    const QFileInfo info(source);
    if (info.isDir() && !info.isSymLink()) {
        if (!QDir().mkpath(target))
            return false;
        const QFileInfoList children = QDir(source).entryInfoList(
            QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System);
        for (const QFileInfo &child : children) {
            if (!copyRecursively(child.absoluteFilePath(),
                                 target + "/" + child.fileName()))
                return false;
        }
        return true;
    }
    return QFile::copy(source, target);
}

bool removePath(const QString &path)
{
    const QFileInfo info(path);
    if (info.isDir() && !info.isSymLink())
        return QDir(path).removeRecursively();
    return QFile::remove(path);
}

bool moveToTrashSafe(const QString &path)
{
    QString uniqueDestination(const QString &directory, const QString &name, const QString &tag);
    if (QFile::moveToTrash(path))
        return true;
    const QString trashDir = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
                             + "/Trash/files";
    if (!QDir().mkpath(trashDir))
        return false;
    const QString target = uniqueDestination(trashDir, QFileInfo(path).fileName(), "trashed");
    if (QFile::rename(path, target))
        return true;
    return copyRecursively(path, target) && removePath(path);
}

QString uniqueDestination(const QString &directory, const QString &name, const QString &tag)
{
    QString base = name;
    QString suffix;
    const int dot = name.lastIndexOf('.');
    if (dot > 0) {
        base = name.left(dot);
        suffix = name.mid(dot);
    }
    QString candidate = directory + "/" + name;
    int counter = 1;
    while (QFileInfo::exists(candidate)) {
        const QString label = counter == 1 ? tag
                                           : tag + " " + QString::number(counter);
        candidate = directory + "/" + base + " (" + label + ")" + suffix;
        ++counter;
    }
    return candidate;
}

QString permissionString(const QFileInfo &info)
{
    const QFileDevice::Permissions p = info.permissions();
    QString text;
    text += (p & QFileDevice::ReadOwner) ? 'r' : '-';
    text += (p & QFileDevice::WriteOwner) ? 'w' : '-';
    text += (p & QFileDevice::ExeOwner) ? 'x' : '-';
    text += (p & QFileDevice::ReadGroup) ? 'r' : '-';
    text += (p & QFileDevice::WriteGroup) ? 'w' : '-';
    text += (p & QFileDevice::ExeGroup) ? 'x' : '-';
    text += (p & QFileDevice::ReadOther) ? 'r' : '-';
    text += (p & QFileDevice::WriteOther) ? 'w' : '-';
    text += (p & QFileDevice::ExeOther) ? 'x' : '-';
    return text;
}

} // namespace

class DirectoryModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(QString path READ path WRITE setPath NOTIFY pathChanged)
    Q_PROPERTY(QString parentPath READ parentPath NOTIFY pathChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(bool showHidden READ showHidden WRITE setShowHidden NOTIFY showHiddenChanged)
    Q_PROPERTY(QString filter READ filter WRITE setFilter NOTIFY filterChanged)
    Q_PROPERTY(QString sortMode READ sortMode WRITE setSortMode NOTIFY sortModeChanged)
    Q_PROPERTY(bool sortDescending READ sortDescending WRITE setSortDescending NOTIFY sortDescendingChanged)

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        PathRole,
        IsDirRole,
        SizeRole,
        ModifiedRole,
        IconRole,
        ThumbnailRole,
    };

    explicit DirectoryModel(QObject *parent = nullptr) : QAbstractListModel(parent)
    {
        m_watcher.setParent(this);
        connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] {
            QTimer::singleShot(180, this, &DirectoryModel::refresh);
        });
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
        case PathRole:
            return entry.path;
        case IsDirRole:
            return entry.isDir;
        case SizeRole:
            return entry.size;
        case ModifiedRole:
            return entry.modified;
        case IconRole:
            return entry.icon;
        case ThumbnailRole:
            return entry.isImage ? "file://" + entry.path : QString();
        default:
            return {};
        }
    }

    QHash<int, QByteArray> roleNames() const override
    {
        return {
            {NameRole, "name"},
            {PathRole, "path"},
            {IsDirRole, "isDir"},
            {SizeRole, "size"},
            {ModifiedRole, "modified"},
            {IconRole, "icon"},
            {ThumbnailRole, "thumbnail"},
        };
    }

    QString path() const { return m_path; }
    QString parentPath() const
    {
        if (m_path == "/")
            return "/";
        QDir dir(m_path);
        return dir.cdUp() ? dir.absolutePath() : "/";
    }
    QString error() const { return m_error; }
    bool showHidden() const { return m_showHidden; }
    QString filter() const { return m_filter; }
    QString sortMode() const { return m_sortMode; }
    bool sortDescending() const { return m_sortDescending; }

    void setShowHidden(bool value)
    {
        if (m_showHidden == value)
            return;
        m_showHidden = value;
        emit showHiddenChanged();
        refresh();
    }

    void setFilter(const QString &value)
    {
        if (m_filter == value)
            return;
        m_filter = value;
        emit filterChanged();
        refresh();
    }

    void setSortMode(const QString &value)
    {
        if (m_sortMode == value)
            return;
        m_sortMode = value;
        emit sortModeChanged();
        refresh();
    }

    void setSortDescending(bool value)
    {
        if (m_sortDescending == value)
            return;
        m_sortDescending = value;
        emit sortDescendingChanged();
        refresh();
    }

    Q_INVOKABLE void setPath(const QString &path)
    {
        QString clean = QDir::cleanPath(path);
        if (clean.isEmpty())
            clean = QDir::homePath();
        if (clean == m_path) {
            refresh();
            return;
        }
        m_path = clean;
        emit pathChanged();
        refresh();
    }

    Q_INVOKABLE void refresh()
    {
        beginResetModel();
        m_entries.clear();
        m_error.clear();

        QDir dir(m_path);
        if (!dir.exists()) {
            m_error = "This folder is not available.";
            endResetModel();
            emit countChanged();
            emit errorChanged();
            return;
        }

        QDir::Filters filters = QDir::AllEntries | QDir::NoDotAndDotDot | QDir::System;
        if (m_showHidden)
            filters |= QDir::Hidden;

        const QFileInfoList files = dir.entryInfoList(filters, QDir::NoSort);
        for (const QFileInfo &info : files) {
            if (!m_filter.isEmpty() &&
                !info.fileName().contains(m_filter, Qt::CaseInsensitive))
                continue;
            Entry entry;
            entry.name = info.fileName();
            entry.path = info.absoluteFilePath();
            entry.isDir = info.isDir();
            entry.isImage = isImageFile(info);
            entry.bytes = info.size();
            entry.modifiedTime = info.lastModified();
            entry.size = entry.isDir ? "Folder" : humanSize(info.size());
            entry.modified = entry.modifiedTime.toString("yyyy-MM-dd HH:mm");
            entry.icon = iconForFile(info);
            m_entries.append(entry);
        }

        std::sort(m_entries.begin(), m_entries.end(), [this](const Entry &a, const Entry &b) {
            if (a.isDir != b.isDir)
                return a.isDir;
            if (m_sortMode == "size")
                return m_sortDescending ? a.bytes > b.bytes : a.bytes < b.bytes;
            if (m_sortMode == "modified")
                return m_sortDescending ? a.modifiedTime > b.modifiedTime : a.modifiedTime < b.modifiedTime;
            const int compare = a.name.localeAwareCompare(b.name);
            return m_sortDescending ? compare > 0 : compare < 0;
        });

        endResetModel();
        emit countChanged();
        emit errorChanged();

        const QStringList watched = m_watcher.directories();
        if (!watched.contains(m_path) && QFileInfo(m_path).isDir()) {
            if (!watched.isEmpty())
                m_watcher.removePaths(watched);
            m_watcher.addPath(m_path);
        }
    }

    Q_INVOKABLE QString nameAt(int index) const
    {
        return index >= 0 && index < m_entries.size() ? m_entries.at(index).name : QString();
    }

    Q_INVOKABLE QString pathAt(int index) const
    {
        return index >= 0 && index < m_entries.size() ? m_entries.at(index).path : QString();
    }

    Q_INVOKABLE bool isDirAt(int index) const
    {
        return index >= 0 && index < m_entries.size() && m_entries.at(index).isDir;
    }

    Q_INVOKABLE void openAt(int index)
    {
        if (index < 0 || index >= m_entries.size())
            return;
        const Entry &entry = m_entries.at(index);
        if (entry.isDir)
            setPath(entry.path);
        else
            QDesktopServices::openUrl(QUrl::fromLocalFile(entry.path));
    }

    Q_INVOKABLE void renameAt(int index, const QString &newName)
    {
        if (index < 0 || index >= m_entries.size() || newName.trimmed().isEmpty())
            return;
        QDir dir(m_path);
        dir.rename(m_entries.at(index).name, newName.trimmed());
        refresh();
    }

    Q_INVOKABLE void deleteAt(int index)
    {
        if (index < 0 || index >= m_entries.size())
            return;
        const Entry &entry = m_entries.at(index);
        if (!moveToTrashSafe(entry.path) && entry.isDir)
            QDir(entry.path).removeRecursively();
        refresh();
    }

    Q_INVOKABLE QStringList pathsAt(const QVariantList &indices) const
    {
        QStringList result;
        for (const QVariant &value : indices) {
            const int index = value.toInt();
            if (index >= 0 && index < m_entries.size())
                result.append(m_entries.at(index).path);
        }
        return result;
    }

    Q_INVOKABLE qint64 bytesAt(const QVariantList &indices) const
    {
        qint64 total = 0;
        for (const QVariant &value : indices) {
            const int index = value.toInt();
            if (index >= 0 && index < m_entries.size())
                total += m_entries.at(index).bytes;
        }
        return total;
    }

    Q_INVOKABLE int trashIndices(const QVariantList &indices)
    {
        int done = 0;
        for (const QString &path : pathsAt(indices)) {
            if (moveToTrashSafe(path))
                ++done;
        }
        if (done > 0)
            refresh();
        return done;
    }

    Q_INVOKABLE int deleteIndices(const QVariantList &indices)
    {
        int done = 0;
        for (const QString &path : pathsAt(indices)) {
            const QFileInfo info(path);
            if (removePath(path) && !QFileInfo::exists(path))
                ++done;
        }
        if (done > 0)
            refresh();
        return done;
    }

    Q_INVOKABLE void newFolder(const QString &name)
    {
        const QString trimmed = name.trimmed();
        if (trimmed.isEmpty())
            return;
        QDir(m_path).mkpath(trimmed);
        refresh();
    }

    Q_INVOKABLE void copyPathAt(int index)
    {
        if (index < 0 || index >= m_entries.size())
            return;
        QGuiApplication::clipboard()->setText(m_entries.at(index).path);
    }

    Q_INVOKABLE QString freeSpace() const
    {
        QStorageInfo storage(m_path);
        return storage.isValid() ? humanSize(storage.bytesAvailable()) : "n/a";
    }

signals:
    void pathChanged();
    void countChanged();
    void errorChanged();
    void showHiddenChanged();
    void filterChanged();
    void sortModeChanged();
    void sortDescendingChanged();

private:
    QString m_path = QDir::homePath();
    QString m_error;
    QString m_filter;
    QString m_sortMode = "name";
    bool m_sortDescending = false;
    bool m_showHidden = false;
    QList<Entry> m_entries;
    QFileSystemWatcher m_watcher;
};

class WaydroidAppsModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(QString filter READ filter WRITE setFilter NOTIFY filterChanged)

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        PackageRole,
        IconRole,
    };

    explicit WaydroidAppsModel(QObject *parent = nullptr) : QAbstractListModel(parent)
    {
        m_dir = QStandardPaths::writableLocation(QStandardPaths::ApplicationsLocation);
        if (m_dir.isEmpty())
            m_dir = QDir::homePath() + "/.local/share/applications";
        QDir().mkpath(m_dir);
        m_watcher.addPath(m_dir);
        connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] {
            QTimer::singleShot(200, this, &WaydroidAppsModel::refresh);
        });
        refresh();
    }

    int rowCount(const QModelIndex &parent = QModelIndex()) const override
    {
        return parent.isValid() ? 0 : m_apps.size();
    }

    QVariant data(const QModelIndex &index, int role) const override
    {
        if (!index.isValid() || index.row() < 0 || index.row() >= m_apps.size())
            return {};
        const App &app = m_apps.at(index.row());
        switch (role) {
        case NameRole:
            return app.name;
        case PackageRole:
            return app.package;
        case IconRole:
            return app.icon;
        default:
            return {};
        }
    }

    QHash<int, QByteArray> roleNames() const override
    {
        return {
            {NameRole, "name"},
            {PackageRole, "packageName"},
            {IconRole, "icon"},
        };
    }

    Q_INVOKABLE void refresh()
    {
        m_all.clear();
        const QStringList files = QDir(m_dir).entryList(
            {"waydroid-*.desktop"}, QDir::Files | QDir::Readable, QDir::Name);
        for (const QString &file : files) {
            const QString full = QDir(m_dir).absoluteFilePath(file);
            QSettings settings(full, QSettings::IniFormat);
            settings.beginGroup("Desktop Entry");
            App app;
            app.name = settings.value("Name").toString().trimmed();
            const QString exec = settings.value("Exec").toString().trimmed();
            const QStringList parts = exec.split(' ', Qt::SkipEmptyParts);
            app.package = parts.isEmpty() ? QString() : parts.last();
            app.icon = resolveNamedIcon(settings.value("Icon").toString().trimmed());
            if (!app.name.isEmpty() && !app.package.isEmpty())
                m_all.append(app);
        }
        if (m_all.isEmpty()) {
            App app;
            app.name = "Aurora Store";
            app.package = "com.aurora.store";
            app.icon = "file:///usr/share/icons/elvonos/metro/aurora-store.png";
            m_all.append(app);
        }
        std::sort(m_all.begin(), m_all.end(), [](const App &a, const App &b) {
            return a.name.localeAwareCompare(b.name) < 0;
        });
        applyFilter();
        if (!m_watcher.directories().contains(m_dir))
            m_watcher.addPath(m_dir);
    }

    QString filter() const { return m_filter; }

    void setFilter(const QString &value)
    {
        if (m_filter == value)
            return;
        m_filter = value;
        emit filterChanged();
        applyFilter();
    }

    Q_INVOKABLE void launch(int index)
    {
        if (index < 0 || index >= m_apps.size())
            return;
        QProcess::startDetached("elvonos-waydroid", {m_apps.at(index).package});
    }

signals:
    void countChanged();
    void filterChanged();

private:
    struct App {
        QString name;
        QString package;
        QString icon;
    };

    void applyFilter()
    {
        beginResetModel();
        m_apps.clear();
        const QString needle = m_filter.trimmed();
        for (const App &app : std::as_const(m_all)) {
            if (needle.isEmpty()
                || app.name.contains(needle, Qt::CaseInsensitive)
                || app.package.contains(needle, Qt::CaseInsensitive))
                m_apps.append(app);
        }
        endResetModel();
        emit countChanged();
    }

    QString m_dir;
    QString m_filter;
    QList<App> m_all;
    QList<App> m_apps;
    QFileSystemWatcher m_watcher;
};

class VolumesModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(bool available READ available CONSTANT)

public:
    enum Roles {
        LabelRole = Qt::UserRole + 1,
        DeviceRole,
        SizeRole,
        FsRole,
        MountRole,
        MountedRole,
        RemovableRole,
        IconRole,
    };

    explicit VolumesModel(QObject *parent = nullptr) : QAbstractListModel(parent)
    {
        m_timer.setInterval(4000);
        connect(&m_timer, &QTimer::timeout, this, &VolumesModel::refresh);
        m_timer.start();
        QTimer::singleShot(400, this, &VolumesModel::refresh);
    }

    int rowCount(const QModelIndex &parent = QModelIndex()) const override
    {
        return parent.isValid() ? 0 : m_volumes.size();
    }

    QVariant data(const QModelIndex &index, int role) const override
    {
        if (!index.isValid() || index.row() < 0 || index.row() >= m_volumes.size())
            return {};
        const Volume &volume = m_volumes.at(index.row());
        switch (role) {
        case LabelRole:
            return volume.label;
        case DeviceRole:
            return volume.device;
        case SizeRole:
            return volume.size;
        case FsRole:
            return volume.fs;
        case MountRole:
            return volume.mountPoint;
        case MountedRole:
            return !volume.mountPoint.isEmpty();
        case RemovableRole:
            return volume.removable;
        case IconRole:
            return volume.icon;
        default:
            return {};
        }
    }

    QHash<int, QByteArray> roleNames() const override
    {
        return {
            {LabelRole, "label"},
            {DeviceRole, "device"},
            {SizeRole, "size"},
            {FsRole, "fs"},
            {MountRole, "mountPoint"},
            {MountedRole, "mounted"},
            {RemovableRole, "removable"},
            {IconRole, "icon"},
        };
    }

    bool available() const
    {
        return !QStandardPaths::findExecutable("udisksctl").isEmpty();
    }

    Q_INVOKABLE void refresh()
    {
        QProcess process;
        process.start("lsblk", {"-J", "-o",
                                "NAME,LABEL,SIZE,FSTYPE,MOUNTPOINT,TYPE,RM,TRAN,MODEL"});
        if (!process.waitForFinished(1500)) {
            process.kill();
            return;
        }
        const QJsonDocument document = QJsonDocument::fromJson(process.readAllStandardOutput());
        if (!document.isObject())
            return;

        QList<Volume> volumes;
        collect(document.object().value("blockdevices").toArray(), volumes);

        bool same = volumes.size() == m_volumes.size();
        if (same) {
            for (int i = 0; i < volumes.size(); ++i) {
                if (volumes.at(i).device != m_volumes.at(i).device
                    || volumes.at(i).mountPoint != m_volumes.at(i).mountPoint
                    || volumes.at(i).label != m_volumes.at(i).label) {
                    same = false;
                    break;
                }
            }
        }
        if (same)
            return;

        beginResetModel();
        m_volumes = volumes;
        endResetModel();
        emit countChanged();
    }

    Q_INVOKABLE QString mountAt(int index)
    {
        if (index < 0 || index >= m_volumes.size())
            return {};
        const Volume volume = m_volumes.at(index);
        if (!volume.mountPoint.isEmpty())
            return volume.mountPoint;

        QProcess process;
        process.start("udisksctl", {"mount", "-b", volume.device});
        if (!process.waitForFinished(15000)) {
            process.kill();
            return {};
        }
        const QString output = QString::fromUtf8(process.readAllStandardOutput())
                               + QString::fromUtf8(process.readAllStandardError());
        refresh();
        for (const Volume &entry : std::as_const(m_volumes)) {
            if (entry.device == volume.device && !entry.mountPoint.isEmpty())
                return entry.mountPoint;
        }
        const QRegularExpression match(QStringLiteral("at (\\S+)"));
        const auto found = match.match(output);
        return found.hasMatch() ? found.captured(1) : QString();
    }

    Q_INVOKABLE bool unmountAt(int index)
    {
        if (index < 0 || index >= m_volumes.size())
            return false;
        const Volume volume = m_volumes.at(index);
        if (volume.mountPoint.isEmpty())
            return false;
        QProcess process;
        process.start("udisksctl", {"unmount", "-b", volume.device});
        if (!process.waitForFinished(15000)) {
            process.kill();
            return false;
        }
        const bool ok = process.exitStatus() == QProcess::NormalExit
                        && process.exitCode() == 0;
        refresh();
        return ok;
    }

signals:
    void countChanged();

private:
    struct Volume {
        QString label;
        QString device;
        QString size;
        QString fs;
        QString mountPoint;
        bool removable = false;
        QString icon;
    };

    void collect(const QJsonArray &devices, QList<Volume> &out)
    {
        for (const QJsonValue &value : devices) {
            const QJsonObject object = value.toObject();
            const QString type = object.value("type").toString();
            const QString fs = object.value("fstype").toString();
            const QString mount = object.value("mountpoint").toString();
            const QString name = object.value("name").toString();
            const bool removable = object.value("rm").toBool();
            const QString transport = object.value("tran").toString();

            const bool isUsb = removable || transport == "usb";
            const bool skipFs = fs.isEmpty() || fs == "squashfs" || fs == "overlay"
                                || fs == "swap" || fs == "iso9660";
            const bool skipMount = mount == "/" || mount.startsWith("/run/live")
                                   || mount.startsWith("/run/initramfs");
            const bool include = !skipFs && !skipMount
                                 && (type == "part"
                                     || (type == "disk"
                                         && (isUsb || !mount.isEmpty())));
            if (include) {
                Volume volume;
                QString label = object.value("label").toString().trimmed();
                if (label.isEmpty()) {
                    const QString model = object.value("model").toString().trimmed();
                    label = !model.isEmpty() ? model : name;
                }
                volume.label = label;
                volume.device = "/dev/" + name;
                volume.size = object.value("size").toString();
                volume.fs = fs;
                volume.mountPoint = mount;
                volume.removable = isUsb;
                volume.icon = resolveNamedIcon(volume.removable
                                               ? "drive-removable-media-usb"
                                               : "drive-harddisk");
                out.append(volume);
            }

            collect(object.value("children").toArray(), out);
        }
    }

    QList<Volume> m_volumes;
    QTimer m_timer;
};

class ExplorerApi : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString home READ home CONSTANT)
    Q_PROPERTY(QString desktop READ desktop CONSTANT)
    Q_PROPERTY(QString documents READ documents CONSTANT)
    Q_PROPERTY(QString downloads READ downloads CONSTANT)
    Q_PROPERTY(QString pictures READ pictures CONSTANT)
    Q_PROPERTY(QString music READ music CONSTANT)
    Q_PROPERTY(QString videos READ videos CONSTANT)
    Q_PROPERTY(QString waydroidStorage READ waydroidStorage CONSTANT)
    Q_PROPERTY(bool hasClipboard READ hasClipboard NOTIFY clipboardChanged)
    Q_PROPERTY(bool clipboardCut READ clipboardCut NOTIFY clipboardChanged)
    Q_PROPERTY(int clipboardCount READ clipboardCount NOTIFY clipboardChanged)
    Q_PROPERTY(bool gridMode READ gridMode WRITE setGridMode NOTIFY gridModeChanged)
    Q_PROPERTY(QString sortMode READ sortMode WRITE setSortMode NOTIFY sortModeChanged)
    Q_PROPERTY(bool sortDescending READ sortDescending WRITE setSortDescending NOTIFY sortDescendingChanged)
    Q_PROPERTY(bool showHidden READ showHidden WRITE setShowHidden NOTIFY showHiddenChanged)
    Q_PROPERTY(int iconSize READ iconSize WRITE setIconSize NOTIFY iconSizeChanged)

public:
    explicit ExplorerApi(QObject *parent = nullptr)
        : QObject(parent)
        , m_settings("ElvonOS", "Explorer")
    {
        m_gridMode = m_settings.value("gridMode", true).toBool();
        m_sortMode = m_settings.value("sortMode", "name").toString();
        m_sortDescending = m_settings.value("sortDescending", false).toBool();
        m_showHidden = m_settings.value("showHidden", false).toBool();
        m_iconSize = m_settings.value("iconSize", 58).toInt();
        if (m_iconSize < 40 || m_iconSize > 96)
            m_iconSize = 58;
    }

    QString home() const { return QStandardPaths::writableLocation(QStandardPaths::HomeLocation); }
    QString desktop() const { return QStandardPaths::writableLocation(QStandardPaths::DesktopLocation); }
    QString documents() const { return QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation); }
    QString downloads() const { return QStandardPaths::writableLocation(QStandardPaths::DownloadLocation); }
    QString pictures() const { return QStandardPaths::writableLocation(QStandardPaths::PicturesLocation); }
    QString music() const { return QStandardPaths::writableLocation(QStandardPaths::MusicLocation); }
    QString videos() const { return QStandardPaths::writableLocation(QStandardPaths::MoviesLocation); }

    QString waydroidStorage() const
    {
        const QString mounted = "/run/elvonos/waydroid";
        if (QDir(mounted).exists())
            return mounted;
        const QString raw = QStandardPaths::writableLocation(
                                QStandardPaths::GenericDataLocation)
                            + "/waydroid/data/media/0";
        if (QDir(raw).exists())
            return raw;
        const QString legacy = "/var/lib/waydroid/data/media/0";
        if (QDir(legacy).exists())
            return legacy;
        return {};
    }

    bool hasClipboard() const { return !m_clipboard.isEmpty(); }
    bool clipboardCut() const { return m_clipboardCut; }
    int clipboardCount() const { return m_clipboard.size(); }

    bool gridMode() const { return m_gridMode; }
    void setGridMode(bool value)
    {
        if (m_gridMode == value)
            return;
        m_gridMode = value;
        m_settings.setValue("gridMode", value);
        emit gridModeChanged();
    }

    QString sortMode() const { return m_sortMode; }
    void setSortMode(const QString &value)
    {
        if (m_sortMode == value)
            return;
        m_sortMode = value;
        m_settings.setValue("sortMode", value);
        emit sortModeChanged();
    }

    bool sortDescending() const { return m_sortDescending; }
    void setSortDescending(bool value)
    {
        if (m_sortDescending == value)
            return;
        m_sortDescending = value;
        m_settings.setValue("sortDescending", value);
        emit sortDescendingChanged();
    }

    bool showHidden() const { return m_showHidden; }
    void setShowHidden(bool value)
    {
        if (m_showHidden == value)
            return;
        m_showHidden = value;
        m_settings.setValue("showHidden", value);
        emit showHiddenChanged();
    }

    int iconSize() const { return m_iconSize; }
    void setIconSize(int value)
    {
        const int clamped = qBound(40, value, 96);
        if (m_iconSize == clamped)
            return;
        m_iconSize = clamped;
        m_settings.setValue("iconSize", clamped);
        emit iconSizeChanged();
    }

    Q_INVOKABLE bool storageReady() const
    {
        QFile mounts(QStringLiteral("/proc/mounts"));
        if (!mounts.open(QIODevice::ReadOnly | QIODevice::Text))
            return false;
        const QString body = QString::fromUtf8(mounts.readAll());
        return body.contains(QStringLiteral(" /run/elvonos/waydroid "));
    }

    Q_INVOKABLE QString ensureStorage()
    {
        QProcess process;
        process.start("elvonos-waydroid-storage");
        process.waitForFinished(8000);
        return waydroidStorage();
    }

    Q_INVOKABLE void openWithAndroid(const QString &path)
    {
        if (path.isEmpty())
            return;
        QProcess::startDetached(QStringLiteral("elvonos-waydroid"),
                                {QStringLiteral("open"), path});
    }

    Q_INVOKABLE void setClipboardPaths(const QStringList &paths, bool cut)
    {
        m_clipboard = paths;
        m_clipboardCut = cut;
        emit clipboardChanged();
    }

    Q_INVOKABLE void clearClipboard()
    {
        if (m_clipboard.isEmpty())
            return;
        m_clipboard.clear();
        m_clipboardCut = false;
        emit clipboardChanged();
    }

    Q_INVOKABLE int pasteInto(const QString &directory)
    {
        if (m_clipboard.isEmpty())
            return 0;
        const QFileInfo dirInfo(directory);
        if (!dirInfo.isDir() || !dirInfo.isWritable())
            return -1;

        int done = 0;
        const QString tag = m_clipboardCut ? "moved" : "copy";
        QStringList remaining;
        for (const QString &source : std::as_const(m_clipboard)) {
            const QFileInfo info(source);
            if (!info.exists())
                continue;
            const QString target = uniqueDestination(directory, info.fileName(), tag);
            const QString absoluteSource = info.absoluteFilePath();
            if (target == absoluteSource || target.startsWith(absoluteSource + "/")) {
                remaining.append(source);
                continue;
            }
            bool ok = false;
            if (m_clipboardCut) {
                ok = QFile::rename(source, target);
                if (!ok)
                    ok = copyRecursively(source, target) && removePath(source);
            } else {
                ok = copyRecursively(source, target);
            }
            if (ok)
                ++done;
            else
                remaining.append(source);
        }
        if (m_clipboardCut) {
            m_clipboard = remaining;
            if (m_clipboard.isEmpty())
                m_clipboardCut = false;
        }
        emit clipboardChanged();
        return done;
    }

    Q_INVOKABLE QVariantMap properties(const QString &path) const
    {
        QVariantMap map;
        const QFileInfo info(path);
        if (!info.exists())
            return map;
        QMimeDatabase mimeDatabase;
        const QMimeType mime = mimeDatabase.mimeTypeForFile(info, QMimeDatabase::MatchExtension);
        map.insert("name", info.fileName());
        map.insert("path", info.absoluteFilePath());
        map.insert("type", info.isDir() ? QStringLiteral("Folder")
                                         : mime.comment().isEmpty() ? mime.name() : mime.comment());
        map.insert("size", info.isDir() ? QStringLiteral("—") : humanSize(info.size())
                                                                 + " (" + QString::number(info.size()) + " bytes)");
        map.insert("modified", QLocale().toString(info.lastModified(), QLocale::ShortFormat));
        map.insert("permissions", permissionString(info));
        map.insert("owner", info.owner());
        map.insert("group", info.group());
        map.insert("hidden", info.isHidden());
        if (info.isSymLink())
            map.insert("target", info.symLinkTarget());
        return map;
    }

    Q_INVOKABLE bool createFile(const QString &directory, const QString &name)
    {
        const QString trimmed = name.trimmed();
        if (trimmed.isEmpty())
            return false;
        const QString path = directory + "/" + trimmed;
        if (QFileInfo::exists(path))
            return false;
        QFile file(path);
        if (!file.open(QIODevice::WriteOnly))
            return false;
        file.close();
        return true;
    }

    Q_INVOKABLE void openTerminal(const QString &path)
    {
        QString dir = path;
        if (QFileInfo(path).isFile())
            dir = QFileInfo(path).absolutePath();
        if (!QFileInfo(dir).isDir())
            return;
        const QString terminal = QStandardPaths::findExecutable("elvonos-terminal");
        if (terminal.isEmpty())
            return;
        QProcess::startDetached(terminal, {"--working-directory", dir});
    }

    Q_INVOKABLE QString humanSize(qint64 bytes) const { return ::humanSize(bytes); }

    Q_INVOKABLE void copyText(const QStringList &values)
    {
        QGuiApplication::clipboard()->setText(values.join('\n'));
    }

    Q_INVOKABLE void quit()
    {
        QCoreApplication::quit();
    }

signals:
    void clipboardChanged();
    void gridModeChanged();
    void sortModeChanged();
    void sortDescendingChanged();
    void showHiddenChanged();
    void iconSizeChanged();

private:
    QSettings m_settings;
    QStringList m_clipboard;
    bool m_clipboardCut = false;
    bool m_gridMode = true;
    bool m_showHidden = false;
    int m_iconSize = 58;
    QString m_sortMode = "name";
    bool m_sortDescending = false;
};

class ExplorerLang : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString language READ language NOTIFY languageChanged)
    Q_PROPERTY(int revision READ revision NOTIFY languageChanged)

public:
    explicit ExplorerLang(QObject *parent = nullptr) : QObject(parent)
    {
        m_path = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
                 + QStringLiteral("/elvonos/language");
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

class ThemeSettings : public QObject {
    Q_OBJECT
    Q_PROPERTY(QColor accent READ accent NOTIFY changed)
    Q_PROPERTY(QColor background READ background NOTIFY changed)
    Q_PROPERTY(QColor panel READ panel NOTIFY changed)
    Q_PROPERTY(QColor surface READ surface NOTIFY changed)
    Q_PROPERTY(QColor text READ text NOTIFY changed)
    Q_PROPERTY(QColor muted READ muted NOTIFY changed)
    Q_PROPERTY(QColor border READ border NOTIFY changed)
    Q_PROPERTY(int radius READ radius NOTIFY changed)
    Q_PROPERTY(int glass READ glass NOTIFY changed)

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
    QColor background() const { return m_background; }
    QColor panel() const { return m_panel; }
    QColor surface() const { return m_surface; }
    QColor text() const { return m_text; }
    QColor muted() const { return m_muted; }
    QColor border() const { return m_border; }
    int radius() const { return m_radius; }
    int glass() const { return m_glass; }

signals:
    void changed();

private:
    void reload()
    {
        QColor accent(QStringLiteral("#8FD3FF"));
        QColor background(QStringLiteral("#101016"));
        QColor panel(QStringLiteral("#15151C"));
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
            take(QStringLiteral("background"), background);
            take(QStringLiteral("panel"), panel);
            take(QStringLiteral("surface"), surface);
            take(QStringLiteral("text"), text);
            take(QStringLiteral("muted"), muted);
            take(QStringLiteral("border"), border);
            radius = qBound(0, object.value(QStringLiteral("radius")).toInt(radius), 28);
            glass = qBound(0, object.value(QStringLiteral("glass")).toInt(glass), 100);
        }
        if (accent == m_accent && background == m_background && panel == m_panel
            && surface == m_surface && text == m_text
            && muted == m_muted && border == m_border && radius == m_radius
            && glass == m_glass)
            return;
        m_accent = accent;
        m_background = background;
        m_panel = panel;
        m_surface = surface;
        m_text = text;
        m_muted = muted;
        m_border = border;
        m_radius = radius;
        m_glass = glass;
        emit changed();
    }

    QString m_path;
    QFileSystemWatcher m_watcher;
    QColor m_accent = QColor(QStringLiteral("#8FD3FF"));
    QColor m_background = QColor(QStringLiteral("#101016"));
    QColor m_panel = QColor(QStringLiteral("#15151C"));
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
    app.setApplicationName(QStringLiteral("elvonos-explorer"));
    app.setApplicationDisplayName(QStringLiteral("Explorer"));
    app.setDesktopFileName(QStringLiteral("elvonos-explorer"));
    QQmlApplicationEngine engine;

    DirectoryModel directory;
    WaydroidAppsModel waydroidApps;
    VolumesModel volumes;
    ExplorerApi api;
    ThemeSettings theme;
    ExplorerLang lang;

    engine.rootContext()->setContextProperty("theme", &theme);
    engine.rootContext()->setContextProperty("lang", &lang);
    engine.rootContext()->setContextProperty("directoryModel", &directory);
    engine.rootContext()->setContextProperty("waydroidApps", &waydroidApps);
    engine.rootContext()->setContextProperty("volumesModel", &volumes);
    engine.rootContext()->setContextProperty("explorer", &api);

    QString initialPath = api.home();
    bool startupApps = false;
    for (int i = 1; i < argc; ++i) {
        const QString argument = QString::fromLocal8Bit(argv[i]);
        if (argument == QStringLiteral("--android-apps")) {
            startupApps = true;
            continue;
        }
        if (argument.startsWith(QLatin1Char('-')))
            continue;
        const QFileInfo info(argument);
        if (!info.exists())
            continue;
        initialPath = info.isDir() ? info.absoluteFilePath()
                                   : info.absolutePath();
        break;
    }
    directory.setPath(initialPath);
    engine.rootContext()->setContextProperty("startupPath", initialPath);
    engine.rootContext()->setContextProperty("startupApps", startupApps);

    engine.load(QUrl("qrc:/Explorer.qml"));
    if (engine.rootObjects().isEmpty())
        return -1;
    return app.exec();
}

#include "main.moc"

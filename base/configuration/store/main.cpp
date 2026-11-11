#include <QAbstractListModel>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QGuiApplication>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QSet>
#include <QSettings>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>
#include <QVariantList>

#include <algorithm>
#include "../common/elvonapp.h"

namespace {

QString humanSize(qint64 bytes)
{
    if (bytes < 1024)
        return QString::number(bytes) + " B";
    const double kb = bytes / 1024.0;
    if (kb < 1024)
        return QString::number(kb, 'f', 0) + " KB";
    const double mb = kb / 1024.0;
    if (mb < 1024)
        return QString::number(mb, 'f', 1) + " MB";
    return QString::number(mb / 1024.0, 'f', 2) + " GB";
}

QString iconFromDirs(const QString &name, const QStringList &dirs)
{
    if (name.isEmpty())
        return {};
    for (const QString &dir : dirs) {
        for (const QString &ext : {".svg", ".png", ".xpm"}) {
            const QString candidate = dir + name + ext;
            if (QFileInfo::exists(candidate))
                return "file://" + candidate;
        }
    }
    return {};
}

QString resolveAppIcon(const QString &name)
{
    const QString home = QDir::homePath();
    return iconFromDirs(name, {
        "/usr/share/icons/Papirus/64x64/apps/",
        "/usr/share/icons/Papirus/48x48/apps/",
        "/usr/share/icons/hicolor/256x256/apps/",
        "/usr/share/icons/hicolor/128x128/apps/",
        "/usr/share/icons/hicolor/64x64/apps/",
        "/usr/share/icons/hicolor/48x48/apps/",
        "/usr/share/icons/Adwaita/64x64/apps/",
        "/usr/share/pixmaps/",
        home + "/.local/share/icons/hicolor/256x256/apps/",
        home + "/.local/share/icons/hicolor/scalable/apps/",
    });
}

QString resolveFlatpakIcon(const QString &appId)
{
    const QString home = QDir::homePath();
    const QStringList roots{
        "/var/lib/flatpak/exports/share/icons/hicolor/",
        home + "/.local/share/flatpak/exports/share/icons/hicolor/",
    };
    for (const QString &root : roots) {
        for (const QString &size : {"512x512", "256x256", "128x128", "64x64", "scalable"}) {
            for (const QString &ext : {".png", ".svg"}) {
                const QString candidate = root + size + "/apps/" + appId + ext;
                if (QFileInfo::exists(candidate))
                    return "file://" + candidate;
            }
        }
    }
    return {};
}

} // namespace

class FlatpakModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(int installedCount READ installedCount NOTIFY countChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString output READ output NOTIFY outputChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString filter READ filter WRITE setFilter NOTIFY filterChanged)
    Q_PROPERTY(bool flathubReady READ flathubReady NOTIFY flathubReadyChanged)

public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        NameRole,
        SummaryRole,
        InstalledRole,
        IconRole,
    };

    explicit FlatpakModel(QObject *parent = nullptr) : QAbstractListModel(parent)
    {
        m_timer.setSingleShot(true);
        m_timer.setInterval(90000);
        connect(&m_timer, &QTimer::timeout, this, [this] {
            if (m_process) {
                appendOutput("flatpak timed out.\n");
                m_process->kill();
            }
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
        const App &app = m_entries.at(index.row());
        switch (role) {
        case IdRole:
            return app.id;
        case NameRole:
            return app.name;
        case SummaryRole:
            return app.summary;
        case InstalledRole:
            return app.installed;
        case IconRole:
            return app.icon;
        default:
            return {};
        }
    }

    QHash<int, QByteArray> roleNames() const override
    {
        return {
            {IdRole, "appId"},
            {NameRole, "name"},
            {SummaryRole, "summary"},
            {InstalledRole, "installed"},
            {IconRole, "icon"},
        };
    }

    int installedCount() const
    {
        int n = 0;
        for (const App &app : m_all) {
            if (app.installed)
                ++n;
        }
        return n;
    }

    bool busy() const { return m_busy; }
    QString output() const { return m_output; }
    QString status() const { return appTr(m_status); }
    bool flathubReady() const
    {
        const QStringList files{
            QStringLiteral("/var/lib/flatpak/repo/config"),
            QDir::homePath() + QStringLiteral("/.local/share/flatpak/repo/config"),
        };
        for (const QString &path : files) {
            QFile file(path);
            if (file.open(QIODevice::ReadOnly | QIODevice::Text)
                && QString::fromUtf8(file.readAll())
                       .contains(QStringLiteral("[remote \"flathub\"]"))) {
                return true;
            }
        }
        return false;
    }

    Q_INVOKABLE void setupFlathub()
    {
        if (m_setupProcess)
            return;
        setStatus(QStringLiteral("Setting up Flathub…"));
        m_setupProcess = new QProcess(this);
        m_setupProcess->setProcessChannelMode(QProcess::MergedChannels);
        connect(m_setupProcess,
                QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this](int exitCode, QProcess::ExitStatus) {
            appendOutput(QString::fromUtf8(m_setupProcess->readAll()));
            const bool ok = exitCode == 0;
            m_setupProcess->deleteLater();
            m_setupProcess = nullptr;
            emit flathubReadyChanged();
            if (ok) {
                setStatus(QStringLiteral("Flathub is ready."));
                refresh();
            } else {
                setStatus(QStringLiteral("Flathub setup failed."));
            }
        });
        if (QFileInfo::exists(QStringLiteral("/usr/bin/pkexec")))
            m_setupProcess->start(QStringLiteral("pkexec"),
                                  {QStringLiteral("elvonos-flatpak-setup")});
        else
            m_setupProcess->start(QStringLiteral("elvonos-flatpak-setup"), {});
    }
    QString filter() const { return m_filter; }

    void setFilter(const QString &value)
    {
        if (m_filter == value)
            return;
        m_filter = value;
        emit filterChanged();
        rebuild();
    }

    Q_INVOKABLE void refresh()
    {
        if (m_busy)
            return;
        m_installed.clear();
        m_installedNames.clear();
        m_all.clear();
        m_entries.clear();
        emit countChanged();
        setBusy(true);
        setStatus("Loading installed applications…");
        startProcess({"list", "--app", "--columns=application,name"}, Stage::LoadingInstalled);
    }

    Q_INVOKABLE void install(int index)
    {
        if (m_busy || index < 0 || index >= m_entries.size())
            return;
        const QString id = m_entries.at(index).id;
        if (id.isEmpty())
            return;
        setBusy(true);
        setStatus(appTr(QStringLiteral("Installing ")) + id + QStringLiteral("…"));
        startProcess({"install", "-y", "flathub", id}, Stage::Installing);
    }

    Q_INVOKABLE void uninstall(int index)
    {
        if (m_busy || index < 0 || index >= m_entries.size())
            return;
        const QString id = m_entries.at(index).id;
        if (id.isEmpty())
            return;
        setBusy(true);
        setStatus(appTr(QStringLiteral("Removing ")) + id + QStringLiteral("…"));
        startProcess({"uninstall", "-y", id}, Stage::Uninstalling);
    }

    Q_INVOKABLE void launch(int index)
    {
        if (index < 0 || index >= m_entries.size())
            return;
        const QString id = m_entries.at(index).id;
        if (!m_entries.at(index).installed)
            return;
        QProcess::startDetached("flatpak", {"run", id});
    }

signals:
    void countChanged();
    void busyChanged();
    void outputChanged();
    void statusChanged();
    void filterChanged();
    void flathubReadyChanged();

private:
    enum class Stage { Idle, LoadingInstalled, LoadingCatalog, Installing, Uninstalling };

    struct App {
        QString id;
        QString name;
        QString summary;
        bool installed = false;
        QString icon;
    };

    void startProcess(const QStringList &arguments, Stage stage)
    {
        m_process = new QProcess(this);
        m_stage = stage;
        m_processOutput.clear();
        m_process->setProcessChannelMode(QProcess::MergedChannels);
        connect(m_process, &QProcess::readyRead, this, [this] {
            appendOutput(QString::fromUtf8(m_process->readAll()));
        });
        connect(m_process, &QProcess::finished, this,
                [this](int exitCode, QProcess::ExitStatus status) {
            appendOutput(QString::fromUtf8(m_process->readAll()));
            handleFinished(exitCode, status);
        });
        m_process->start("flatpak", arguments);
        m_timer.start();
    }

    void handleFinished(int exitCode, QProcess::ExitStatus exitStatus)
    {
        const Stage stage = m_stage;
        m_process->deleteLater();
        m_process = nullptr;
        m_timer.stop();
        const bool ok = exitStatus == QProcess::NormalExit && exitCode == 0;

        if (stage == Stage::LoadingInstalled) {
            if (ok)
                parseInstalled(m_processOutput);
            addInstalledOnly();
            rebuild();
            setStatus("Loading Flathub catalog…");
            startProcess({"remote-ls", "flathub", "--app",
                          "--columns=application,name,description"},
                         Stage::LoadingCatalog);
            return;
        }

        if (stage == Stage::LoadingCatalog) {
            if (ok)
                parseCatalog(m_processOutput);
            bool usedCache = false;
            if (m_all.size() <= m_installed.size()) {
                QFile cache("/usr/share/elvonos/flathub-catalog.tsv");
                if (cache.open(QIODevice::ReadOnly)) {
                    const QString cached = QString::fromUtf8(cache.readAll());
                    if (!cached.trimmed().isEmpty()) {
                        parseCatalog(cached);
                        usedCache = true;
                    }
                }
            }
            addInstalledOnly();
            rebuild();
            setBusy(false);
            if (usedCache)
                setStatus(QString::number(m_all.size()) + appTr(QStringLiteral(" Linux apps  ·  "))
                          + QString::number(installedCount())
                          + appTr(QStringLiteral(" installed  ·  offline catalog")));
            else if (ok)
                setStatus(QString::number(m_all.size()) + appTr(QStringLiteral(" Linux apps  ·  "))
                          + QString::number(installedCount()) + appTr(QStringLiteral(" installed")));
            else if (!m_all.isEmpty())
                setStatus(appTr(QStringLiteral("Flathub catalog unavailable  ·  "))
                          + QString::number(installedCount()) + appTr(QStringLiteral(" installed")));
            else
                setStatus("Could not load the Flathub catalog.");
            return;
        }

        if (stage == Stage::Installing || stage == Stage::Uninstalling) {
            if (ok)
                setStatus(stage == Stage::Installing ? "Installation finished."
                                                     : "Application removed.");
            else
                setStatus(stage == Stage::Installing ? "Installation failed."
                                                     : "Removal failed.");
            m_busy = false;
            emit busyChanged();
            refresh();
        }
    }

    void parseInstalled(const QString &text)
    {
        for (const QString &line : text.split('\n')) {
            const QStringList parts = line.split('\t');
            if (parts.isEmpty() || parts.first().trimmed().isEmpty())
                continue;
            const QString id = parts.first().trimmed();
            m_installed.insert(id);
            m_installedNames.insert(id, parts.size() > 1 ? parts.at(1).trimmed() : id);
        }
    }

    void parseCatalog(const QString &text)
    {
        for (const QString &line : text.split('\n')) {
            const QStringList parts = line.split('\t');
            if (parts.isEmpty())
                continue;
            const QString id = parts.first().trimmed();
            if (id.isEmpty() || !id.contains('.'))
                continue;
            App app;
            app.id = id;
            app.name = parts.size() > 1 ? parts.at(1).trimmed() : id;
            app.summary = parts.size() > 2 ? parts.at(2).trimmed() : QString();
            app.installed = m_installed.contains(id);
            if (app.installed)
                app.icon = resolveFlatpakIcon(id);

            bool merged = false;
            for (App &existing : m_all) {
                if (existing.id == id) {
                    if (!app.name.isEmpty())
                        existing.name = app.name;
                    if (!app.summary.isEmpty())
                        existing.summary = app.summary;
                    existing.installed = app.installed;
                    if (!app.icon.isEmpty())
                        existing.icon = app.icon;
                    merged = true;
                    break;
                }
            }
            if (!merged)
                m_all.append(app);
        }
    }

    void addInstalledOnly()
    {
        QSet<QString> known;
        for (const App &app : m_all)
            known.insert(app.id);
        for (const QString &id : m_installed) {
            if (known.contains(id))
                continue;
            App app;
            app.id = id;
            app.name = m_installedNames.value(id, id);
            app.summary = appTr(QStringLiteral("Installed Flatpak application"));
            app.installed = true;
            app.icon = resolveFlatpakIcon(id);
            m_all.append(app);
        }
    }

    void rebuild()
    {
        QList<App> list;
        const QString needle = m_filter.trimmed();
        for (const App &app : m_all) {
            if (!needle.isEmpty()
                && !app.name.contains(needle, Qt::CaseInsensitive)
                && !app.id.contains(needle, Qt::CaseInsensitive)
                && !app.summary.contains(needle, Qt::CaseInsensitive))
                continue;
            list.append(app);
        }
        std::sort(list.begin(), list.end(), [](const App &a, const App &b) {
            if (a.installed != b.installed)
                return a.installed;
            return a.name.localeAwareCompare(b.name) < 0;
        });
        beginResetModel();
        m_entries = list;
        endResetModel();
        emit countChanged();
    }

    void setBusy(bool value)
    {
        if (m_busy == value)
            return;
        m_busy = value;
        emit busyChanged();
    }

    void setStatus(const QString &value)
    {
        m_status = appTr(value);
        emit statusChanged();
    }

    void appendOutput(const QString &text)
    {
        m_processOutput += text;
        if (m_processOutput.size() > 120000)
            m_processOutput = m_processOutput.right(120000);
        m_output = text;
        emit outputChanged();
    }

    QProcess *m_process = nullptr;
    QProcess *m_setupProcess = nullptr;
    Stage m_stage = Stage::Idle;
    QTimer m_timer;
    QSet<QString> m_installed;
    QHash<QString, QString> m_installedNames;
    QList<App> m_all;
    QList<App> m_entries;
    QString m_filter;
    QString m_processOutput;
    QString m_output;
    QString m_status;
    bool m_busy = false;
};

class AndroidAppsModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(QString filter READ filter WRITE setFilter NOTIFY filterChanged)

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        PackageRole,
        IconRole,
    };

    explicit AndroidAppsModel(QObject *parent = nullptr) : QAbstractListModel(parent)
    {
        m_dir = QStandardPaths::writableLocation(QStandardPaths::ApplicationsLocation);
        if (m_dir.isEmpty())
            m_dir = QDir::homePath() + "/.local/share/applications";
        QDir().mkpath(m_dir);
        m_watcher.addPath(m_dir);
        connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] {
            QTimer::singleShot(200, this, &AndroidAppsModel::refresh);
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
        const App &app = m_entries.at(index.row());
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

    QString filter() const { return m_filter; }
    void setFilter(const QString &value)
    {
        if (m_filter == value)
            return;
        m_filter = value;
        emit filterChanged();
        rebuild();
    }

    Q_INVOKABLE void refresh()
    {
        m_all.clear();
        const QStringList files = QDir(m_dir).entryList(
            {"waydroid-*.desktop"}, QDir::Files | QDir::Readable, QDir::Name);
        for (const QString &file : files) {
            QSettings settings(QDir(m_dir).absoluteFilePath(file), QSettings::IniFormat);
            settings.beginGroup("Desktop Entry");
            App app;
            app.name = settings.value("Name").toString().trimmed();
            const QString exec = settings.value("Exec").toString().trimmed();
            const QStringList parts = exec.split(' ', Qt::SkipEmptyParts);
            app.package = parts.isEmpty() ? QString() : parts.last();
            app.icon = resolveAppIcon(settings.value("Icon").toString().trimmed());
            if (!app.name.isEmpty() && !app.package.isEmpty())
                m_all.append(app);
        }
        std::sort(m_all.begin(), m_all.end(), [](const App &a, const App &b) {
            return a.name.localeAwareCompare(b.name) < 0;
        });
        rebuild();
        if (!m_watcher.directories().contains(m_dir))
            m_watcher.addPath(m_dir);
    }

    Q_INVOKABLE void launch(int index)
    {
        if (index < 0 || index >= m_entries.size())
            return;
        QProcess::startDetached("elvonos-waydroid", {m_entries.at(index).package});
    }

    Q_INVOKABLE void openAurora()
    {
        // Android 16 on Waydroid 1.6.3 can create the Android task without a
        // Wayland window.  If no Aurora window appears, fall back to the
        // fullscreen Waydroid UI so the app is still usable.
        QProcess::startDetached(QStringLiteral("sh"), {
            QStringLiteral("-c"),
            QStringLiteral("elvonos-waydroid com.aurora.store; sleep 2; "
                           "grep -qi aurora \"$HOME/.config/list-windows/windows.ini\" "
                           "2>/dev/null || waydroid show-full-ui")
        });
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

    void rebuild()
    {
        QList<App> list;
        const QString needle = m_filter.trimmed();
        for (const App &app : m_all) {
            if (!needle.isEmpty()
                && !app.name.contains(needle, Qt::CaseInsensitive)
                && !app.package.contains(needle, Qt::CaseInsensitive))
                continue;
            list.append(app);
        }
        beginResetModel();
        m_entries = list;
        endResetModel();
        emit countChanged();
    }

    QString m_dir;
    QString m_filter;
    QList<App> m_all;
    QList<App> m_entries;
    QFileSystemWatcher m_watcher;
};

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    AppLang lang;
    AppTheme theme;
    appLangInstance() = &lang;
    app.setApplicationName(QStringLiteral("elvonos-store"));
    app.setApplicationDisplayName(QStringLiteral("Store"));
    app.setDesktopFileName(QStringLiteral("elvonos-store"));

    FlatpakModel flatpak;
    AndroidAppsModel androidApps;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("lang"), &lang);
    engine.rootContext()->setContextProperty(QStringLiteral("theme"), &theme);
    engine.rootContext()->setContextProperty("flatpakModel", &flatpak);
    engine.rootContext()->setContextProperty("androidModel", &androidApps);

    engine.load(QUrl("qrc:/Store.qml"));
    if (engine.rootObjects().isEmpty())
        return -1;
    return app.exec();
}

#include "main.moc"

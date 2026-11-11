#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QRegularExpression>
#include <QSet>
#include <QSettings>
#include <QStandardPaths>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

namespace {

QString humanSize(qint64 bytes)
{
    if (bytes < 1024)
        return QString::number(bytes) + QStringLiteral(" B");
    const double kb = bytes / 1024.0;
    if (kb < 1024)
        return QString::number(kb, 'f', 0) + QStringLiteral(" KB");
    const double mb = kb / 1024.0;
    if (mb < 1024)
        return QString::number(mb, 'f', 1) + QStringLiteral(" MB");
    return QString::number(mb / 1024.0, 'f', 1) + QStringLiteral(" GB");
}

QString readText(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return QString::fromUtf8(file.readAll());
}

QString firstMatch(const QString &text, const QRegularExpression &expression,
                   int capture = 1)
{
    const QRegularExpressionMatch match = expression.match(text);
    return match.hasMatch() ? match.captured(capture).trimmed() : QString();
}

QString iconFor(const QString &name)
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
        "/usr/share/icons/Papirus/48x48/places/",
        "/usr/share/icons/hicolor/scalable/apps/",
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

struct AppInfo {
    QString id;
    QString name;
    QString icon;
    QString exec;
};

} // namespace

class Lang : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString language READ language NOTIFY languageChanged)
    Q_PROPERTY(int revision READ revision NOTIFY languageChanged)

public:
    explicit Lang(QObject *parent = nullptr) : QObject(parent)
    {
        QString code;
        QFile file(configPath());
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
        m_language = code;
        loadDictionary();
    }

    static QStringList supported()
    {
        return {QStringLiteral("en"), QStringLiteral("de"), QStringLiteral("fr"),
                QStringLiteral("es"), QStringLiteral("it"), QStringLiteral("pt"),
                QStringLiteral("nl"), QStringLiteral("pl"), QStringLiteral("ru"),
                QStringLiteral("tr"), QStringLiteral("uk"), QStringLiteral("cs"),
                QStringLiteral("sv"), QStringLiteral("zh"), QStringLiteral("ja")};
    }

    QString language() const { return m_language; }
    int revision() const { return m_revision; }

    Q_INVOKABLE QString t(const QString &source) const
    {
        return m_dict.value(source, source);
    }

    Q_INVOKABLE void setLanguage(const QString &code)
    {
        const QString next = supported().contains(code) ? code : QStringLiteral("en");
        if (next == m_language)
            return;
        m_language = next;
        loadDictionary();
        m_revision++;
        QDir().mkpath(QFileInfo(configPath()).absolutePath());
        QFile file(configPath());
        if (file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            file.write(m_language.toUtf8());
            file.write("\n");
        }
        emit languageChanged();
    }

signals:
    void languageChanged();

private:
    QString configPath() const
    {
        return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
               + QStringLiteral("/elvonos/language");
    }

    void loadDictionary()
    {
        m_dict.clear();
        if (m_language == QStringLiteral("en"))
            return;
        QFile file(QStringLiteral(":/i18n/") + m_language
                   + QStringLiteral(".json"));
        if (!file.open(QIODevice::ReadOnly))
            return;
        const QJsonDocument document = QJsonDocument::fromJson(file.readAll());
        const QJsonObject object = document.object();
        for (auto it = object.constBegin(); it != object.constEnd(); ++it)
            m_dict.insert(it.key(), it.value().toString());
    }

    QHash<QString, QString> m_dict;
    QString m_language = QStringLiteral("en");
    int m_revision = 0;
};

class SettingsApi : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList systemInfo READ systemInfo NOTIFY changed)
    Q_PROPERTY(QVariantList networkInfo READ networkInfo NOTIFY changed)
    Q_PROPERTY(QVariantList deviceInfo READ deviceInfo NOTIFY changed)
    Q_PROPERTY(QVariantList installedApps READ installedApps NOTIFY changed)
    Q_PROPERTY(QVariantList defaultApps READ defaultApps NOTIFY changed)
    Q_PROPERTY(QVariantList autostartEntries READ autostartEntries NOTIFY changed)
    Q_PROPERTY(QVariantList wallpapers READ wallpapers NOTIFY changed)
    Q_PROPERTY(QVariantList timezones READ timezones NOTIFY changed)
    Q_PROPERTY(QVariantList locales READ locales NOTIFY changed)
    Q_PROPERTY(QVariantList updates READ updates NOTIFY changed)
    Q_PROPERTY(QVariantList backups READ backups NOTIFY changed)
    Q_PROPERTY(QString profile READ profile NOTIFY changed)
    Q_PROPERTY(bool zram READ zram NOTIFY changed)
    Q_PROPERTY(bool firewallOn READ firewallOn NOTIFY changed)
    Q_PROPERTY(QString firewallRules READ firewallRules NOTIFY changed)
    Q_PROPERTY(QString currentTimezone READ currentTimezone NOTIFY changed)
    Q_PROPERTY(QString currentLocale READ currentLocale NOTIFY changed)
    Q_PROPERTY(QVariantMap gamingStatus READ gamingStatus NOTIFY changed)
    Q_PROPERTY(QString wallpaperPath READ wallpaperPath NOTIFY changed)
    Q_PROPERTY(bool wifiEnabled READ wifiEnabled NOTIFY changed)
    Q_PROPERTY(bool networkingEnabled READ networkingEnabled NOTIFY changed)
    Q_PROPERTY(QVariantList wifiNetworks READ wifiNetworks NOTIFY changed)
    Q_PROPERTY(QVariantList audioSinks READ audioSinks NOTIFY changed)
    Q_PROPERTY(QVariantList audioSources READ audioSources NOTIFY changed)
    Q_PROPERTY(QString defaultSink READ defaultSink NOTIFY changed)
    Q_PROPERTY(QString defaultSource READ defaultSource NOTIFY changed)
    Q_PROPERTY(int sinkVolume READ sinkVolume NOTIFY changed)
    Q_PROPERTY(bool sinkMuted READ sinkMuted NOTIFY changed)
    Q_PROPERTY(int sourceVolume READ sourceVolume NOTIFY changed)
    Q_PROPERTY(bool sourceMuted READ sourceMuted NOTIFY changed)
    Q_PROPERTY(QVariantList displayOutputs READ displayOutputs NOTIFY changed)
    Q_PROPERTY(bool ntpEnabled READ ntpEnabled NOTIFY changed)
    Q_PROPERTY(QString keyboardLayout READ keyboardLayout NOTIFY changed)
    Q_PROPERTY(QString hostname READ hostname NOTIFY changed)
    Q_PROPERTY(QString taskbarPosition READ taskbarPosition NOTIFY panelChanged)
    Q_PROPERTY(QString dockPosition READ dockPosition NOTIFY panelChanged)
    Q_PROPERTY(int taskbarHeight READ taskbarHeight NOTIFY panelChanged)
    Q_PROPERTY(QVariantList vpnConnections READ vpnConnections NOTIFY changed)
    Q_PROPERTY(bool flightMode READ flightMode NOTIFY changed)
    Q_PROPERTY(bool hotspotActive READ hotspotActive NOTIFY changed)
    Q_PROPERTY(bool bluetoothAvailable READ bluetoothAvailable NOTIFY changed)
    Q_PROPERTY(bool bluetoothEnabled READ bluetoothEnabled NOTIFY changed)
    Q_PROPERTY(QVariantList bluetoothDevices READ bluetoothDevices NOTIFY changed)
    Q_PROPERTY(int mouseSpeed READ mouseSpeed NOTIFY inputChanged)
    Q_PROPERTY(bool naturalScroll READ naturalScroll NOTIFY inputChanged)
    Q_PROPERTY(bool tapToClick READ tapToClick NOTIFY inputChanged)
    Q_PROPERTY(bool leftHanded READ leftHanded NOTIFY inputChanged)
    Q_PROPERTY(int screenTimeout READ screenTimeout NOTIFY powerChanged)
    Q_PROPERTY(int suspendTimeout READ suspendTimeout NOTIFY powerChanged)
    Q_PROPERTY(int batteryPercent READ batteryPercent NOTIFY powerChanged)
    Q_PROPERTY(bool batteryCharging READ batteryCharging NOTIFY powerChanged)
    Q_PROPERTY(QVariantList printers READ printers NOTIFY changed)
    Q_PROPERTY(QString defaultPrinter READ defaultPrinter NOTIFY changed)
    Q_PROPERTY(bool notificationsEnabled READ notificationsEnabled NOTIFY changed)
    Q_PROPERTY(QString themePreset READ themePreset NOTIFY themeChanged)
    Q_PROPERTY(QString themeAccent READ themeAccent NOTIFY themeChanged)
    Q_PROPERTY(QString themeAccent2 READ themeAccent2 NOTIFY themeChanged)
    Q_PROPERTY(QString themeWallpaper READ themeWallpaper NOTIFY themeChanged)
    Q_PROPERTY(int themeWallpaperDim READ themeWallpaperDim NOTIFY themeChanged)
    Q_PROPERTY(QString themeWallpaperFill READ themeWallpaperFill NOTIFY themeChanged)
    Q_PROPERTY(QString themePanel READ themePanel NOTIFY themeChanged)
    Q_PROPERTY(QString themeBackground READ themeBackground NOTIFY themeChanged)
    Q_PROPERTY(QString themeSurface READ themeSurface NOTIFY themeChanged)
    Q_PROPERTY(QString themeText READ themeText NOTIFY themeChanged)
    Q_PROPERTY(QString formFactor READ formFactor NOTIFY changed)
    Q_PROPERTY(QString formFactorMode READ formFactorMode NOTIFY changed)
    Q_PROPERTY(QString formFactorInfo READ formFactorInfo NOTIFY changed)
    Q_PROPERTY(double formFactorScale READ formFactorScale NOTIFY changed)
    Q_PROPERTY(bool touchMode READ touchMode NOTIFY changed)
    Q_PROPERTY(QString storageInfo READ storageInfo NOTIFY changed)
    Q_PROPERTY(bool largeText READ largeText NOTIFY changed)
    Q_PROPERTY(int cursorSize READ cursorSize NOTIFY changed)
    Q_PROPERTY(QString dnsServers READ dnsServers NOTIFY changed)
    Q_PROPERTY(bool waydroidRunning READ waydroidRunning NOTIFY changed)
    Q_PROPERTY(int waydroidApps READ waydroidApps NOTIFY changed)
    Q_PROPERTY(QVariantList waydroidAppList READ waydroidAppList NOTIFY changed)
    Q_PROPERTY(bool waydroidAutostart READ waydroidAutostart NOTIFY changed)
    Q_PROPERTY(bool waydroidBridge READ waydroidBridge NOTIFY changed)
    Q_PROPERTY(bool waydroidMultiwindow READ waydroidMultiwindow NOTIFY changed)
    Q_PROPERTY(qint64 waydroidStorageUsed READ waydroidStorageUsed NOTIFY changed)
    Q_PROPERTY(qint64 waydroidStorageFree READ waydroidStorageFree NOTIFY changed)
    Q_PROPERTY(qint64 waydroidStorageTotal READ waydroidStorageTotal NOTIFY changed)
    Q_PROPERTY(QVariantList soundEvents READ soundEvents NOTIFY changed)
    Q_PROPERTY(bool metroApps READ metroApps NOTIFY changed)
    Q_PROPERTY(QString elvonosVersion READ elvonosVersion NOTIFY changed)
    Q_PROPERTY(QString elvonosLatest READ elvonosLatest NOTIFY changed)
    Q_PROPERTY(int elvonosOsUpdates READ elvonosOsUpdates NOTIFY changed)
    Q_PROPERTY(int elvonosComponentUpdates READ elvonosComponentUpdates NOTIFY changed)
    Q_PROPERTY(QString elvonosComponentList READ elvonosComponentList NOTIFY changed)
    Q_PROPERTY(bool elvonosBusy READ elvonosBusy NOTIFY changed)
    Q_PROPERTY(QString elvonosLog READ elvonosLog NOTIFY changed)
    Q_PROPERTY(bool elvonosIsoAvailable READ elvonosIsoAvailable NOTIFY changed)
    Q_PROPERTY(QString elvonosCheckedAt READ elvonosCheckedAt NOTIFY changed)
    Q_PROPERTY(bool elvonosAutoShutdown READ elvonosAutoShutdown NOTIFY changed)
    Q_PROPERTY(bool elvonosUpdateAvailable READ elvonosUpdateAvailable NOTIFY changed)
    Q_PROPERTY(QString themeMuted READ themeMuted NOTIFY themeChanged)
    Q_PROPERTY(QString themeBorder READ themeBorder NOTIFY themeChanged)
    Q_PROPERTY(int themeRadius READ themeRadius NOTIFY themeChanged)
    Q_PROPERTY(int themeGlass READ themeGlass NOTIFY themeChanged)
    Q_PROPERTY(QString log READ log NOTIFY logChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit SettingsApi(QObject *parent = nullptr) : QObject(parent)
    {
        m_log.reserve(20000);
        m_timer.setInterval(12000);
        connect(&m_timer, &QTimer::timeout, this, [this] {
            if (!m_busy)
                refreshTune();
        });
        m_timer.start();
        loadPanels();
        loadThemeSettings();
        loadInputSettings();
        loadPowerSettings();
        loadNotifications();
        loadFormFactor();
        loadAccessibility();
    }

    void setLang(Lang *lang) { m_lang = lang; }

    QVariantList systemInfo() const { return m_systemInfo; }
    QVariantList networkInfo() const { return m_networkInfo; }
    QVariantList deviceInfo() const { return m_deviceInfo; }
    QVariantList installedApps() const { return m_installedApps; }
    QVariantList defaultApps() const { return m_defaultApps; }
    QVariantList autostartEntries() const { return m_autostartEntries; }
    QVariantList wallpapers() const { return m_wallpapers; }
    QVariantList timezones() const { return m_timezones; }
    QVariantList locales() const { return m_locales; }
    QVariantList updates() const { return m_updates; }
    QVariantList backups() const { return m_backups; }
    QString profile() const { return m_profile; }
    bool zram() const { return m_zram; }
    bool firewallOn() const { return m_firewallOn; }
    QString firewallRules() const { return m_firewallRules; }
    QString currentTimezone() const { return m_currentTimezone; }
    QString currentLocale() const { return m_currentLocale; }
    QVariantMap gamingStatus() const { return m_gamingStatus; }
    QString wallpaperPath() const { return m_wallpaperPath; }
    bool wifiEnabled() const { return m_wifiEnabled; }
    bool networkingEnabled() const { return m_networkingEnabled; }
    QVariantList wifiNetworks() const { return m_wifiNetworks; }
    QVariantList audioSinks() const { return m_audioSinks; }
    QVariantList audioSources() const { return m_audioSources; }
    QString defaultSink() const { return m_defaultSink; }
    QString defaultSource() const { return m_defaultSource; }
    int sinkVolume() const { return m_sinkVolume; }
    bool sinkMuted() const { return m_sinkMuted; }
    int sourceVolume() const { return m_sourceVolume; }
    bool sourceMuted() const { return m_sourceMuted; }
    QVariantList displayOutputs() const { return m_displayOutputs; }
    bool ntpEnabled() const { return m_ntpEnabled; }
    QString keyboardLayout() const { return m_keyboardLayout; }
    QString hostname() const { return m_hostname; }
    QString taskbarPosition() const { return m_taskbarPosition; }
    QString dockPosition() const { return m_dockPosition; }
    int taskbarHeight() const { return m_taskbarHeight; }
    QVariantList vpnConnections() const { return m_vpnConnections; }
    bool flightMode() const { return m_flightMode; }
    bool hotspotActive() const { return m_hotspotActive; }
    bool bluetoothAvailable() const { return m_bluetoothAvailable; }
    bool bluetoothEnabled() const { return m_bluetoothEnabled; }
    QVariantList bluetoothDevices() const { return m_bluetoothDevices; }
    int mouseSpeed() const { return m_mouseSpeed; }
    bool naturalScroll() const { return m_naturalScroll; }
    bool tapToClick() const { return m_tapToClick; }
    bool leftHanded() const { return m_leftHanded; }
    int screenTimeout() const { return m_screenTimeout; }
    int suspendTimeout() const { return m_suspendTimeout; }
    int batteryPercent() const { return m_batteryPercent; }
    bool batteryCharging() const { return m_batteryCharging; }
    QVariantList printers() const { return m_printers; }
    QString defaultPrinter() const { return m_defaultPrinter; }
    bool notificationsEnabled() const { return m_notificationsEnabled; }
    QString themePreset() const { return m_themePreset; }
    QString themeAccent() const { return m_themeAccent; }
    QString themeAccent2() const { return m_themeAccent2; }
    QString themeWallpaper() const { return m_themeWallpaper; }
    int themeWallpaperDim() const { return m_themeWallpaperDim; }
    QString themeWallpaperFill() const { return m_themeWallpaperFill; }
    QString themePanel() const { return m_themePanel; }
    QString themeBackground() const { return m_themeBackground; }
    QString themeSurface() const { return m_themeSurface; }
    QString themeText() const { return m_themeText; }
    QString formFactor() const { return m_formFactor; }
    QString formFactorMode() const { return m_formFactorMode; }
    QString formFactorInfo() const { return m_formFactorInfo; }
    double formFactorScale() const { return m_formFactorScale; }
    bool touchMode() const { return m_touchMode; }
    QString storageInfo() const { return m_storageInfo; }
    bool largeText() const { return m_largeText; }
    int cursorSize() const { return m_cursorSize; }
    QString dnsServers() const { return m_dnsServers; }
    bool waydroidRunning() const { return m_waydroidRunning; }
    int waydroidApps() const { return m_waydroidApps; }
    QVariantList waydroidAppList() const { return m_waydroidAppList; }
    bool waydroidAutostart() const { return m_waydroidAutostart; }
    bool waydroidBridge() const { return m_waydroidBridge; }
    bool waydroidMultiwindow() const { return m_waydroidMultiwindow; }
    qint64 waydroidStorageUsed() const { return m_waydroidStorageUsed; }
    qint64 waydroidStorageFree() const { return m_waydroidStorageFree; }
    qint64 waydroidStorageTotal() const { return m_waydroidStorageTotal; }
    QVariantList soundEvents() const { return m_soundEvents; }
    bool metroApps() const { return m_metroApps; }
    QString themeMuted() const { return m_themeMuted; }
    QString themeBorder() const { return m_themeBorder; }
    int themeRadius() const { return m_themeRadius; }
    int themeGlass() const { return m_themeGlass; }
    QString log() const { return m_log; }
    QString status() const { return m_status; }
    bool busy() const { return m_busy; }

    Q_INVOKABLE void loadSection(const QString &section)
    {
        if (section == QStringLiteral("system"))
            loadSystem();
        else if (section == QStringLiteral("network"))
            loadNetwork();
        else if (section == QStringLiteral("devices"))
            loadDevices();
        else if (section == QStringLiteral("apps"))
            loadApps();
        else if (section == QStringLiteral("design"))
            loadWallpapers();
        else if (section == QStringLiteral("time"))
            loadTime();
        else if (section == QStringLiteral("gaming"))
            loadGaming();
        else if (section == QStringLiteral("firewall"))
            loadFirewall();
        else if (section == QStringLiteral("privacy"))
            loadPrivacy();
        else if (section == QStringLiteral("updates")) {
            loadUpdates();
            checkElvonosUpdate();
        }
        else if (section == QStringLiteral("backups"))
            loadBackups();
        emit changed();
    }

    /* ---------------- System ---------------- */

    Q_INVOKABLE void setProfile(const QString &profile)
    {
        runTune({QStringLiteral("profile"), profile},
                QStringLiteral("Switching performance profile…"));
    }

    Q_INVOKABLE void setZram(bool enabled)
    {
        runTune({QStringLiteral("zram"), enabled ? QStringLiteral("on")
                                                 : QStringLiteral("off")},
                enabled ? QStringLiteral("Enabling ZRAM…")
                        : QStringLiteral("Disabling ZRAM…"));
    }

    /* ---------------- Network / devices ---------------- */

    Q_INVOKABLE void openNetworkSettings()
    {
        if (!launchFirst({QStringLiteral("nm-connection-editor"),
                          QStringLiteral("elvonos-control")}))
            setStatus(false, QStringLiteral("No network settings tool found"));
    }

    Q_INVOKABLE void openSoundSettings()
    {
        if (!launchFirst({QStringLiteral("pavucontrol"),
                          QStringLiteral("elvonos-control")}))
            setStatus(false, QStringLiteral("No sound settings tool found"));
    }

    Q_INVOKABLE void openControlCenter()
    {
        if (!QProcess::startDetached(QStringLiteral("elvonos-control"), {}))
            setStatus(false, QStringLiteral("Control Center is not installed"));
    }

    /* ---------------- Panels / themes ---------------- */

    Q_INVOKABLE void setTaskbarPosition(const QString &position)
    {
        QJsonObject object = readJsonObject(taskbarConfigPath());
        object.insert(QStringLiteral("position"),
                      position == QStringLiteral("bottom")
                          ? QStringLiteral("bottom") : QStringLiteral("top"));
        writeJsonObject(taskbarConfigPath(), object);
        m_taskbarPosition = object.value(QStringLiteral("position")).toString();
        emit panelChanged();
        setStatus(true, QStringLiteral("Taskbar position updated"));
    }

    Q_INVOKABLE void setDockPosition(const QString &position)
    {
        QJsonObject object = readJsonObject(panelsConfigPath());
        object.insert(QStringLiteral("dockPosition"),
                      position == QStringLiteral("top")
                          ? QStringLiteral("top") : QStringLiteral("bottom"));
        writeJsonObject(panelsConfigPath(), object);
        m_dockPosition = object.value(QStringLiteral("dockPosition")).toString();
        emit panelChanged();
        setStatus(true, QStringLiteral("Dock position updated"));
    }

    Q_INVOKABLE void setTaskbarHeight(int height)
    {
        height = qBound(44, height, 72);
        QJsonObject object = readJsonObject(taskbarConfigPath());
        object.insert(QStringLiteral("height"), height);
        writeJsonObject(taskbarConfigPath(), object);
        m_taskbarHeight = height;
        emit panelChanged();
    }

    Q_INVOKABLE void applyTheme(const QString &preset)
    {
        struct ThemePreset {
            const char *accent;
            const char *accent2;
            const char *panel;
            const char *background;
            const char *surface;
            const char *text;
            const char *muted;
            const char *border;
            const char *tile;
            int radius;
            int glass;
        };
        const QHash<QString, ThemePreset> presets = {
            {QStringLiteral("aero"),
             {"#8FD3FF", "#4CC2FF", "#15151C", "#101016", "#1B1B26", "#E9ECF2",
              "#8B93A1", "#FFFFFF", "#4CC2FF", 14, 78}},
            {QStringLiteral("aurora"),
             {"#C8A0FF", "#FF8FD8", "#191323", "#120E1A", "#221A30", "#F2ECFF",
              "#A79BBE", "#C8A0FF", "#A06BFF", 18, 72}},
            {QStringLiteral("emerald"),
             {"#7DFFC4", "#A8FF7D", "#101A17", "#0A1210", "#182A24", "#E9FFF5",
              "#8FB3A6", "#7DFFC4", "#35E0A0", 16, 70}},
            {QStringLiteral("sunset"),
             {"#FFB27D", "#FF5C8A", "#1F1512", "#160F0C", "#2C1D17", "#FFF0E6",
              "#C4A08C", "#FFB27D", "#FF8A4C", 16, 75}},
            {QStringLiteral("light"),
             {"#2A7ED6", "#6FB6FF", "#F2F4F8", "#E6EAF0", "#FFFFFF", "#1A1F26",
              "#5F6B7A", "#A9B4C2", "#2A7ED6", 12, 92}},
            {QStringLiteral("rose"),
             {"#FF8FBF", "#FFD36E", "#1E1218", "#150C11", "#2A1820", "#FFF0F6",
              "#C89BAF", "#FF8FBF", "#FF5CA8", 18, 72}},
            {QStringLiteral("mono"),
             {"#D8DEE9", "#8C95A3", "#16181D", "#0E1014", "#1E2229", "#ECEFF4",
              "#8C95A3", "#D8DEE9", "#D8DEE9", 10, 80}},
            {QStringLiteral("cyber"),
             {"#39FF14", "#00C8FF", "#0C1410", "#050A07", "#122019", "#E6FFE0",
              "#7FAF7F", "#39FF14", "#39FF14", 8, 65}},
        };
        const QString key = presets.contains(preset) ? preset
                                                     : QStringLiteral("aero");
        const ThemePreset theme = presets.value(key);
        m_themePreset = key;
        m_themeAccent = QString::fromLatin1(theme.accent);
        m_themeAccent2 = QString::fromLatin1(theme.accent2);
        m_themePanel = QString::fromLatin1(theme.panel);
        m_themeBackground = QString::fromLatin1(theme.background);
        m_themeSurface = QString::fromLatin1(theme.surface);
        m_themeText = QString::fromLatin1(theme.text);
        m_themeMuted = QString::fromLatin1(theme.muted);
        m_themeBorder = QString::fromLatin1(theme.border);
        m_themeRadius = qBound(0, theme.radius, 28);
        m_themeGlass = qBound(0, theme.glass, 100);
        persistTheme();
        emit themeChanged();
        setStatus(true, QStringLiteral("Theme applied"));
    }

    Q_INVOKABLE void setThemeColor(const QString &role, const QString &value)
    {
        static const QRegularExpression hex(QStringLiteral("^#[0-9A-Fa-f]{6}$"));
        if (!hex.match(value).hasMatch()) {
            setStatus(false, QStringLiteral("Invalid colour, use #RRGGBB"));
            return;
        }
        if (role == QStringLiteral("accent"))
            m_themeAccent = value.toUpper();
        else if (role == QStringLiteral("accent2"))
            m_themeAccent2 = value.toUpper();
        else if (role == QStringLiteral("panel"))
            m_themePanel = value.toUpper();
        else if (role == QStringLiteral("background"))
            m_themeBackground = value.toUpper();
        else if (role == QStringLiteral("surface"))
            m_themeSurface = value.toUpper();
        else if (role == QStringLiteral("text"))
            m_themeText = value.toUpper();
        else if (role == QStringLiteral("muted"))
            m_themeMuted = value.toUpper();
        else if (role == QStringLiteral("border"))
            m_themeBorder = value.toUpper();
        else
            return;
        m_themePreset = QStringLiteral("custom");
        persistTheme();
        emit themeChanged();
        setStatus(true, QStringLiteral("Theme colour updated"));
    }

    Q_INVOKABLE void setThemeRadius(int radius)
    {
        m_themeRadius = qBound(0, radius, 28);
        m_themePreset = QStringLiteral("custom");
        persistTheme();
        emit themeChanged();
    }

    Q_INVOKABLE void setThemeGlass(int glass)
    {
        m_themeGlass = qBound(0, glass, 100);
        m_themePreset = QStringLiteral("custom");
        persistTheme();
        emit themeChanged();
    }

    Q_INVOKABLE void setThemeWallpaper(const QString &path)
    {
        QString image = path.trimmed();
        if (image.startsWith(QStringLiteral("file://")))
            image = image.mid(7);
        if (!image.isEmpty() && !QFileInfo::exists(image)) {
            setStatus(false, QStringLiteral("Background image not found"));
            return;
        }
        m_themeWallpaper = image;
        m_themePreset = QStringLiteral("custom");
        if (image.isEmpty()) {
            QSettings win8(win8SettingsPath(), QSettings::IniFormat);
            win8.setValue(QStringLiteral("Wallpaper/Desktop"),
                          QStringLiteral("/usr/share/backgrounds/elvonos/wallpaper.png"));
        }
        persistTheme();
        emit themeChanged();
        setStatus(true, image.isEmpty()
                            ? QStringLiteral("System wallpaper restored")
                            : QStringLiteral("Theme background image updated"));
    }

    Q_INVOKABLE void setThemeWallpaperDim(int dim)
    {
        m_themeWallpaperDim = qBound(0, dim, 90);
        m_themePreset = QStringLiteral("custom");
        persistTheme();
        emit themeChanged();
    }

    Q_INVOKABLE void setThemeWallpaperFill(const QString &fill)
    {
        if (fill != QStringLiteral("fit") && fill != QStringLiteral("stretch"))
            m_themeWallpaperFill = QStringLiteral("fill");
        else
            m_themeWallpaperFill = fill;
        m_themePreset = QStringLiteral("custom");
        persistTheme();
        emit themeChanged();
    }

    Q_INVOKABLE void exportTheme(const QString &path)
    {
        QString target = path.trimmed();
        if (target.isEmpty()) {
            target = QStandardPaths::writableLocation(
                         QStandardPaths::DocumentsLocation)
                     + QStringLiteral("/ElvonOS-Theme.json");
        }
        QDir().mkpath(QFileInfo(target).absolutePath());
        QFile file(target);
        if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)
            || file.write(QJsonDocument(currentTheme()).toJson(
                              QJsonDocument::Indented)) < 0) {
            setStatus(false, QStringLiteral("Could not export the theme"));
            return;
        }
        setStatus(true, QStringLiteral("Theme exported to %1").arg(target));
    }

    Q_INVOKABLE void importTheme(const QString &path)
    {
        QFile file(path.trimmed());
        if (!file.open(QIODevice::ReadOnly)) {
            setStatus(false, QStringLiteral("Theme file not found"));
            return;
        }
        const QJsonObject object =
            QJsonDocument::fromJson(file.readAll()).object();
        static const QRegularExpression hex(QStringLiteral("^#[0-9A-Fa-f]{6}$"));
        auto take = [&object, &hex](const QString &key, QString &member) {
            const QString value =
                object.value(key).toString().toUpper();
            if (hex.match(value).hasMatch())
                member = value;
        };
        take(QStringLiteral("accent"), m_themeAccent);
        take(QStringLiteral("accent2"), m_themeAccent2);
        take(QStringLiteral("panel"), m_themePanel);
        take(QStringLiteral("background"), m_themeBackground);
        take(QStringLiteral("surface"), m_themeSurface);
        take(QStringLiteral("text"), m_themeText);
        take(QStringLiteral("muted"), m_themeMuted);
        take(QStringLiteral("border"), m_themeBorder);
        m_themeRadius =
            qBound(0, object.value(QStringLiteral("radius")).toInt(m_themeRadius), 28);
        m_themeGlass =
            qBound(0, object.value(QStringLiteral("glass")).toInt(m_themeGlass), 100);
        const QString wallpaper =
            object.value(QStringLiteral("wallpaper")).toString();
        if (wallpaper.isEmpty() || QFileInfo::exists(wallpaper))
            m_themeWallpaper = wallpaper;
        m_themeWallpaperDim =
            qBound(0, object.value(QStringLiteral("wallpaperDim"))
                           .toInt(m_themeWallpaperDim), 90);
        const QString fill =
            object.value(QStringLiteral("wallpaperFill")).toString();
        if (fill == QStringLiteral("fit") || fill == QStringLiteral("stretch"))
            m_themeWallpaperFill = fill;
        else
            m_themeWallpaperFill = QStringLiteral("fill");
        m_themePreset = QStringLiteral("custom");
        persistTheme();
        emit themeChanged();
        setStatus(true, QStringLiteral("Theme imported"));
    }

    Q_INVOKABLE void resetTheme()
    {
        applyTheme(QStringLiteral("aero"));
    }

    Q_INVOKABLE void setLargeText(bool enabled)
    {
        m_largeText = enabled;
        QJsonObject object = readJsonObject(accessibilityConfigPath());
        object.insert(QStringLiteral("largeText"), enabled);
        object.insert(QStringLiteral("cursorSize"), m_cursorSize);
        writeJsonObject(accessibilityConfigPath(), object);
        applyAccessibility();
        emit changed();
        setStatus(true, QStringLiteral("Large text applies to new sessions"));
    }

    Q_INVOKABLE void setCursorSize(int size)
    {
        m_cursorSize = qBound(16, size, 64);
        QJsonObject object = readJsonObject(accessibilityConfigPath());
        object.insert(QStringLiteral("largeText"), m_largeText);
        object.insert(QStringLiteral("cursorSize"), m_cursorSize);
        writeJsonObject(accessibilityConfigPath(), object);
        applyAccessibility();
        emit changed();
        setStatus(true, QStringLiteral("Cursor size updated"));
    }

    Q_INVOKABLE void refreshWaydroid()
    {
        if (m_waydroidProcess)
            return;
        m_waydroidProcess = new QProcess(this);
        connect(m_waydroidProcess,
                QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this](int, QProcess::ExitStatus) {
            if (m_waydroidProcess) {
                const QJsonObject object =
                    QJsonDocument::fromJson(m_waydroidProcess->readAllStandardOutput())
                        .object();
                m_waydroidRunning = object.value(QStringLiteral("session")).toBool();
                m_waydroidApps = object.value(QStringLiteral("apps")).toInt();
                m_waydroidBridge = object.value(QStringLiteral("bridge")).toBool();
                m_waydroidMultiwindow =
                    object.value(QStringLiteral("multiwindow")).toBool(true);
                m_waydroidProcess->deleteLater();
                m_waydroidProcess = nullptr;
            }
            m_waydroidAutostart = readWaydroidAutostart();
            refreshWaydroidStorage();
            emit changed();
        });
        connect(m_waydroidProcess, &QProcess::errorOccurred, this, [this] {
            if (m_waydroidProcess) {
                m_waydroidProcess->deleteLater();
                m_waydroidProcess = nullptr;
            }
            emit changed();
        });
        m_waydroidProcess->start(QStringLiteral("elvonos-waydroid"),
                                 {QStringLiteral("status"), QStringLiteral("--json")});
    }

    Q_INVOKABLE void startWaydroid()
    {
        QProcess::startDetached(QStringLiteral("elvonos-waydroid"),
                                {QStringLiteral("start")});
        setStatus(true, QStringLiteral("Waydroid is starting…"));
    }

    Q_INVOKABLE void syncWaydroid()
    {
        QProcess::startDetached(QStringLiteral("elvonos-waydroid"),
                                {QStringLiteral("sync")});
        setStatus(true, QStringLiteral("Refreshing Android apps…"));
    }

    Q_INVOKABLE void openAndroidSettings()
    {
        QProcess::startDetached(QStringLiteral("elvonos-waydroid"),
                                {QStringLiteral("com.android.settings")});
    }

    Q_INVOKABLE void installWaydroidApk()
    {
        QProcess::startDetached(QStringLiteral("elvonos-waydroid"),
                                {QStringLiteral("install")});
    }

    Q_INVOKABLE void refreshWaydroidApps()
    {
        if (m_waydroidAppsProcess)
            return;
        m_waydroidAppsProcess = new QProcess(this);
        connect(m_waydroidAppsProcess,
                QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this](int, QProcess::ExitStatus) {
            if (m_waydroidAppsProcess) {
                const QJsonArray array =
                    QJsonDocument::fromJson(
                        m_waydroidAppsProcess->readAllStandardOutput())
                        .array();
                QVariantList list;
                for (const QJsonValue &value : array) {
                    const QJsonObject object = value.toObject();
                    const QString package =
                        object.value(QStringLiteral("package")).toString();
                    if (package.isEmpty())
                        continue;
                    QVariantMap item;
                    item.insert(QStringLiteral("package"), package);
                    item.insert(QStringLiteral("label"),
                                object.value(QStringLiteral("label"))
                                    .toString(package));
                    item.insert(QStringLiteral("icon"),
                                object.value(QStringLiteral("icon")).toString());
                    list.append(item);
                }
                m_waydroidAppList = list;
                m_waydroidAppsProcess->deleteLater();
                m_waydroidAppsProcess = nullptr;
                emit changed();
            }
        });
        connect(m_waydroidAppsProcess, &QProcess::errorOccurred, this, [this] {
            if (m_waydroidAppsProcess) {
                m_waydroidAppsProcess->deleteLater();
                m_waydroidAppsProcess = nullptr;
            }
            emit changed();
        });
        m_waydroidAppsProcess->start(QStringLiteral("elvonos-waydroid"),
                                     {QStringLiteral("list"), QStringLiteral("--json")});
    }

    Q_INVOKABLE void openWaydroidApp(const QString &package)
    {
        if (!package.isEmpty())
            QProcess::startDetached(QStringLiteral("elvonos-waydroid"), {package});
    }

    Q_INVOKABLE void removeWaydroidApp(const QString &package)
    {
        if (package.isEmpty())
            return;
        QProcess::startDetached(QStringLiteral("elvonos-waydroid"),
                                {QStringLiteral("remove"), package});
        setStatus(true, QStringLiteral("Removing Android app…"));
        QTimer::singleShot(8000, this, [this] {
            refreshWaydroid();
            refreshWaydroidApps();
        });
    }

    Q_INVOKABLE void setWaydroidAutostart(bool enabled)
    {
        runProgram(QStringLiteral("elvonos-waydroid"),
                   {QStringLiteral("autostart"),
                    enabled ? QStringLiteral("on") : QStringLiteral("off")},
                   10000);
        m_waydroidAutostart = enabled;
        emit changed();
        setStatus(true, enabled ? QStringLiteral("Waydroid starts at login")
                                : QStringLiteral("Waydroid autostart disabled"));
    }

    Q_INVOKABLE void backupWaydroid()
    {
        QProcess::startDetached(QStringLiteral("elvonos-waydroid"),
                                {QStringLiteral("backup")});
        setStatus(true, QStringLiteral("Backing up Android data…"));
    }

    Q_INVOKABLE void restoreWaydroid()
    {
        QProcess::startDetached(QStringLiteral("elvonos-waydroid"),
                                {QStringLiteral("restore")});
        setStatus(true, QStringLiteral("Restoring Android data…"));
        QTimer::singleShot(20000, this, [this] {
            refreshWaydroid();
            refreshWaydroidApps();
        });
    }

    Q_INVOKABLE QString readHealth() const
    {
        QFile file(QStringLiteral("/run/elvonos/health.json"));
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
            return QStringLiteral("{}");
        return QString::fromUtf8(file.readAll());
    }

    Q_INVOKABLE void refreshWaydroidStorage()
    {
        if (m_waydroidStorageProcess)
            return;
        m_waydroidStorageProcess = new QProcess(this);
        connect(m_waydroidStorageProcess,
                QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this](int, QProcess::ExitStatus) {
            if (m_waydroidStorageProcess) {
                const QJsonObject object =
                    QJsonDocument::fromJson(
                        m_waydroidStorageProcess->readAllStandardOutput())
                        .object();
                const double used = object.value(QStringLiteral("used")).toDouble();
                const double free = object.value(QStringLiteral("free")).toDouble();
                const double total = object.value(QStringLiteral("total")).toDouble();
                m_waydroidStorageUsed = static_cast<qint64>(used);
                m_waydroidStorageFree = static_cast<qint64>(free);
                m_waydroidStorageTotal = static_cast<qint64>(total);
                m_waydroidStorageProcess->deleteLater();
                m_waydroidStorageProcess = nullptr;
                emit changed();
            }
        });
        connect(m_waydroidStorageProcess, &QProcess::errorOccurred, this, [this] {
            if (m_waydroidStorageProcess) {
                m_waydroidStorageProcess->deleteLater();
                m_waydroidStorageProcess = nullptr;
            }
            emit changed();
        });
        m_waydroidStorageProcess->start(QStringLiteral("elvonos-waydroid"),
                                        {QStringLiteral("storage"), QStringLiteral("--json")});
    }

    Q_INVOKABLE void restartWaydroid()
    {
        QProcess::startDetached(QStringLiteral("elvonos-waydroid"),
                                {QStringLiteral("restart")});
        setStatus(true, QStringLiteral("Waydroid is restarting…"));
        QTimer::singleShot(15000, this, [this] {
            refreshWaydroid();
            refreshWaydroidApps();
        });
    }

    Q_INVOKABLE void setWaydroidBridge(bool enabled)
    {
        runProgram(QStringLiteral("elvonos-waydroid"),
                   {QStringLiteral("config"), QStringLiteral("set"),
                    QStringLiteral("bridge"),
                    enabled ? QStringLiteral("true") : QStringLiteral("false")},
                   5000);
        QProcess::startDetached(QStringLiteral("elvonos-waydroid"),
                                {QStringLiteral("bridge"),
                                 enabled ? QStringLiteral("start") : QStringLiteral("stop")});
        m_waydroidBridge = enabled;
        emit changed();
        setStatus(true, enabled ? QStringLiteral("Clipboard and notifications bridged")
                                : QStringLiteral("Clipboard bridge disabled"));
    }

    Q_INVOKABLE void setWaydroidMultiwindow(bool enabled)
    {
        runProgram(QStringLiteral("elvonos-waydroid"),
                   {QStringLiteral("multiwindow"),
                    enabled ? QStringLiteral("on") : QStringLiteral("off")},
                   5000);
        m_waydroidMultiwindow = enabled;
        emit changed();
        setStatus(true, enabled
                           ? QStringLiteral("Multi-window enabled (restart Waydroid)")
                           : QStringLiteral("Multi-window disabled (restart Waydroid)"));
    }

    Q_INVOKABLE void clearWaydroidAppData(const QString &package)
    {
        if (package.isEmpty())
            return;
        runProgram(QStringLiteral("elvonos-waydroid"),
                   {QStringLiteral("clear-data"), package}, 60000);
        setStatus(true, QStringLiteral("Android app data cleared"));
    }

    QString soundsPath() const
    {
        return QStandardPaths::writableLocation(
                   QStandardPaths::GenericConfigLocation)
               + QStringLiteral("/elvonos/sounds.json");
    }

    Q_INVOKABLE void loadSounds()
    {
        QVariantMap stored;
        QFile file(soundsPath());
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            stored = QJsonDocument::fromJson(file.readAll()).object().toVariantMap();
            file.close();
        }
        static const QString theme = QStringLiteral("/usr/share/sounds/freedesktop/stereo");
        const QList<QPair<QString, QString>> defaults = {
            {QStringLiteral("startup"), theme + QStringLiteral("/service-login.oga")},
            {QStringLiteral("notification"), theme + QStringLiteral("/message.oga")},
            {QStringLiteral("error"), theme + QStringLiteral("/dialog-error.oga")},
            {QStringLiteral("complete"), theme + QStringLiteral("/complete.oga")},
            {QStringLiteral("lock"), theme + QStringLiteral("/dialog-warning.oga")},
        };
        m_soundEvents.clear();
        for (const auto &entry : defaults) {
            QVariantMap item;
            item.insert(QStringLiteral("key"), entry.first);
            item.insert(QStringLiteral("path"),
                        stored.value(entry.first, entry.second).toString());
            m_soundEvents.append(item);
        }
        emit changed();
    }

    Q_INVOKABLE void playSoundEvent(const QString &key)
    {
        if (!key.isEmpty())
            QProcess::startDetached(QStringLiteral("elvonos-sound"),
                                    {QStringLiteral("play"), key});
    }

    Q_INVOKABLE void chooseSoundFile(const QString &key)
    {
        if (key.isEmpty())
            return;
        const QString selected = runProgram(
            QStringLiteral("zenity"),
            {QStringLiteral("--file-selection"),
             QStringLiteral("--title=Choose system sound"),
             QStringLiteral("--file-filter=Audio (*.oga *.ogg *.wav *.mp3) | *.oga *.ogg *.wav *.mp3")},
            60000).trimmed();
        if (selected.isEmpty())
            return;
        writeSoundSetting(key, selected);
        playSoundEvent(key);
        setStatus(true, QStringLiteral("Sound selected"));
    }

    Q_INVOKABLE void resetSound(const QString &key)
    {
        if (key.isEmpty())
            return;
        writeSoundSetting(key, QString());
        setStatus(true, QStringLiteral("Sound reset to default"));
    }

    Q_INVOKABLE void loadAppMode()
    {
        QFile file(QStandardPaths::writableLocation(
                       QStandardPaths::GenericConfigLocation)
                   + QStringLiteral("/elvonos/app-mode"));
        m_metroApps = false;
        if (file.open(QIODevice::ReadOnly | QIODevice::Text))
            m_metroApps = QString::fromUtf8(file.readAll()).trimmed()
                          == QStringLiteral("metro");
        emit changed();
    }

    Q_INVOKABLE void setMetroApps(bool enabled)
    {
        runProgram(QStringLiteral("elvonos-appmode"),
                   {enabled ? QStringLiteral("metro") : QStringLiteral("desktop")},
                   8000);
        m_metroApps = enabled;
        emit changed();
        setStatus(true, enabled ? QStringLiteral("Metro app windows enabled")
                                : QStringLiteral("Desktop app windows enabled"));
    }

    void writeSoundSetting(const QString &key, const QString &path)
    {
        QVariantMap stored;
        QFile file(soundsPath());
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            stored = QJsonDocument::fromJson(file.readAll()).object().toVariantMap();
            file.close();
        }
        if (path.isEmpty())
            stored.remove(key);
        else
            stored.insert(key, path);
        QDir().mkpath(QFileInfo(soundsPath()).absolutePath());
        if (file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            file.write(QJsonDocument(QJsonObject::fromVariantMap(stored))
                           .toJson(QJsonDocument::Indented));
            file.close();
        }
        loadSounds();
    }

    Q_INVOKABLE void setDnsServers(const QString &servers)
    {
        const QString active =
            runProgram(QStringLiteral("nmcli"),
                       {QStringLiteral("-t"), QStringLiteral("-f"),
                        QStringLiteral("NAME,TYPE"), QStringLiteral("connection"),
                        QStringLiteral("show"), QStringLiteral("--active")},
                       8000);
        QString connection;
        for (const QString &line : active.split(QLatin1Char('\n'))) {
            const QStringList parts = line.split(QLatin1Char(':'));
            if (parts.size() >= 2 && !parts.at(1).contains(QStringLiteral("loopback"))) {
                connection = parts.at(0);
                break;
            }
        }
        if (connection.isEmpty()) {
            setStatus(false, QStringLiteral("No active connection"));
            return;
        }
        const QString value = servers.trimmed();
        int exitCode = 0;
        if (value.isEmpty()) {
            runProgram(QStringLiteral("nmcli"),
                       {QStringLiteral("connection"), QStringLiteral("modify"),
                        connection, QStringLiteral("ipv4.ignore-auto-dns"),
                        QStringLiteral("no")}, 10000, &exitCode);
        } else {
            runProgram(QStringLiteral("nmcli"),
                       {QStringLiteral("connection"), QStringLiteral("modify"),
                        connection, QStringLiteral("ipv4.dns"), value,
                        QStringLiteral("ipv4.ignore-auto-dns"), QStringLiteral("yes")},
                       10000, &exitCode);
        }
        if (exitCode == 0)
            runProgram(QStringLiteral("nmcli"),
                       {QStringLiteral("connection"), QStringLiteral("up"), connection},
                       30000, &exitCode);
        setStatus(exitCode == 0, exitCode == 0
                                     ? QStringLiteral("DNS servers updated")
                                     : QStringLiteral("Could not update DNS servers"));
        loadNetwork();
    }

    Q_INVOKABLE void setFormFactorMode(const QString &mode)
    {
        static const QStringList modes = {
            QStringLiteral("auto"), QStringLiteral("pc"), QStringLiteral("laptop"),
            QStringLiteral("tablet"), QStringLiteral("tv")};
        if (!modes.contains(mode))
            return;
        QJsonObject object = readJsonObject(formFactorConfigPath());
        object.insert(QStringLiteral("mode"), mode);
        writeJsonObject(formFactorConfigPath(), object);
        QString script = QStandardPaths::findExecutable(
            QStringLiteral("elvonos-formfactor"));
        if (script.isEmpty())
            script = QStringLiteral("/usr/bin/elvonos-formfactor");
        runProgram(script, {}, 12000);
        loadFormFactor();
        QProcess::startDetached(QStringLiteral("pkill"),
                                {QStringLiteral("-f"),
                                 QStringLiteral("elvonos-desktop-extras")});
        QProcess::startDetached(QStringLiteral("pkill"),
                                {QStringLiteral("-x"), QStringLiteral("Win8Running")});
        QTimer::singleShot(700, []() {
            QProcess::startDetached(QStringLiteral("elvonos-desktop-extras"), {},
                                    QDir::homePath());
            QProcess::startDetached(QStringLiteral("Win8Running"), {},
                                    QDir::homePath());
        });
        QTimer::singleShot(1300, this, [this]() { loadFormFactor(); });
        setStatus(true, QStringLiteral("Device profile updated"));
    }

    /* ---------------- Input devices ---------------- */

    Q_INVOKABLE void setMouseSpeed(int speed)
    {
        m_mouseSpeed = qBound(-100, speed, 100);
        saveInputSettings();
        applyInputSettings();
        emit inputChanged();
    }

    Q_INVOKABLE void setNaturalScroll(bool enabled)
    {
        m_naturalScroll = enabled;
        saveInputSettings();
        applyInputSettings();
        emit inputChanged();
    }

    Q_INVOKABLE void setTapToClick(bool enabled)
    {
        m_tapToClick = enabled;
        saveInputSettings();
        applyInputSettings();
        emit inputChanged();
    }

    Q_INVOKABLE void setLeftHanded(bool enabled)
    {
        m_leftHanded = enabled;
        saveInputSettings();
        applyInputSettings();
        emit inputChanged();
    }

    Q_INVOKABLE void applyInputSettings()
    {
        const QString path = QStandardPaths::writableLocation(
                                 QStandardPaths::GenericConfigLocation)
                             + QStringLiteral("/labwc/rc.xml");
        QString xml = readText(path);
        if (xml.isEmpty())
            return;
        static const QRegularExpression libinputBlock(
            QStringLiteral("<libinput>.*?</libinput>"),
            QRegularExpression::DotMatchesEverythingOption);
        xml.remove(libinputBlock);
        const QString speed = QString::number(m_mouseSpeed / 100.0, 'f', 2);
        const QString block = QStringLiteral(
            "  <libinput>\n"
            "    <device category=\"default\">\n"
            "      <pointerSpeed>%1</pointerSpeed>\n"
            "      <naturalScroll>%2</naturalScroll>\n"
            "      <leftHanded>%3</leftHanded>\n"
            "      <tap>%4</tap>\n"
            "      <disableWhileTyping>yes</disableWhileTyping>\n"
            "    </device>\n"
            "  </libinput>\n")
            .arg(speed,
                 m_naturalScroll ? QStringLiteral("yes") : QStringLiteral("no"),
                 m_leftHanded ? QStringLiteral("yes") : QStringLiteral("no"),
                 m_tapToClick ? QStringLiteral("yes") : QStringLiteral("no"));
        const int closing = xml.lastIndexOf(QStringLiteral("</labwc>"));
        if (closing < 0)
            return;
        xml.insert(closing, block);
        QFile file(path);
        if (file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            file.write(xml.toUtf8());
        }
        QProcess::startDetached(QStringLiteral("pkill"),
                                {QStringLiteral("-HUP"), QStringLiteral("labwc")});
        setStatus(true, QStringLiteral("Input settings applied"));
    }

    /* ---------------- Power ---------------- */

    Q_INVOKABLE void setScreenTimeout(int minutes)
    {
        m_screenTimeout = qBound(0, minutes, 120);
        savePowerSettings();
        applyPowerSettings();
        emit powerChanged();
    }

    Q_INVOKABLE void setSuspendTimeout(int minutes)
    {
        m_suspendTimeout = qBound(0, minutes, 240);
        savePowerSettings();
        applyPowerSettings();
        emit powerChanged();
    }

    Q_INVOKABLE void suspendNow()
    {
        QProcess::startDetached(QStringLiteral("systemctl"),
                                {QStringLiteral("suspend")});
        setStatus(true, QStringLiteral("Suspending…"));
    }

    /* ---------------- Printers ---------------- */

    Q_INVOKABLE void openPrinterSettings()
    {
        if (!launchFirst({QStringLiteral("system-config-printer"),
                          QStringLiteral("elvonos-printscan")}))
            setStatus(false, QStringLiteral("Printer settings are not installed"));
    }

    Q_INVOKABLE void testPrinter(const QString &name)
    {
        QString printer = name;
        if (printer.isEmpty())
            printer = m_defaultPrinter;
        if (printer.isEmpty()) {
            setStatus(false, QStringLiteral("No printer selected"));
            return;
        }
        const QString page = QStringLiteral("/tmp/elvonos-testpage.txt");
        QFile file(page);
        if (file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            file.write(QStringLiteral(
                           "ElvonOS printer test page\n"
                           "Printer: %1\n"
                           "If you can read this, the queue is working.\n")
                           .arg(printer).toUtf8());
        }
        int exitCode = 0;
        runProgram(QStringLiteral("lp"),
                   {QStringLiteral("-d"), printer, page}, 20000, &exitCode);
        setStatus(exitCode == 0,
                  exitCode == 0 ? QStringLiteral("Test page sent to %1").arg(printer)
                                : QStringLiteral("Could not send the test page"));
    }

    /* ---------------- Notifications ---------------- */

    Q_INVOKABLE void setNotificationsEnabled(bool enabled)
    {
        if (enabled) {
            QProcess::startDetached(QStringLiteral("fnott"), {},
                                    QDir::homePath());
        } else {
            QProcess::startDetached(QStringLiteral("pkill"),
                                    {QStringLiteral("-x"), QStringLiteral("fnott")});
        }
        m_notificationsEnabled = enabled;
        emit changed();
        setStatus(true, enabled ? QStringLiteral("Notifications enabled")
                                : QStringLiteral("Notifications disabled"));
    }

    Q_INVOKABLE void sendTestNotification()
    {
        if (!m_notificationsEnabled)
            setNotificationsEnabled(true);
        QProcess::startDetached(QStringLiteral("notify-send"),
                                {QStringLiteral("ElvonOS"),
                                 QStringLiteral("Notifications are working.")});
        setStatus(true, QStringLiteral("Test notification sent"));
    }

    Q_INVOKABLE void clearNotifications()
    {
        QProcess::startDetached(QStringLiteral("fnottctl"),
                                {QStringLiteral("dismiss"),
                                 QStringLiteral("all")});
        setStatus(true, QStringLiteral("Notifications dismissed"));
    }

    /* ---------------- Wi-Fi ---------------- */

    Q_INVOKABLE void setWifiEnabled(bool enabled)
    {
        int exitCode = 0;
        runProgram(QStringLiteral("nmcli"),
                   {QStringLiteral("radio"), QStringLiteral("wifi"),
                    enabled ? QStringLiteral("on") : QStringLiteral("off")},
                   15000, &exitCode);
        setStatus(exitCode == 0, enabled ? QStringLiteral("Wi-Fi enabled")
                                         : QStringLiteral("Wi-Fi disabled"));
        loadNetwork();
    }

    Q_INVOKABLE void setNetworkingEnabled(bool enabled)
    {
        int exitCode = 0;
        runProgram(QStringLiteral("nmcli"),
                   {QStringLiteral("networking"),
                    enabled ? QStringLiteral("on") : QStringLiteral("off")},
                   15000, &exitCode);
        setStatus(exitCode == 0, enabled ? QStringLiteral("Networking enabled")
                                         : QStringLiteral("Networking disabled"));
        loadNetwork();
    }

    Q_INVOKABLE void refreshWifi()
    {
        runProgram(QStringLiteral("nmcli"),
                   {QStringLiteral("dev"), QStringLiteral("wifi"),
                    QStringLiteral("rescan")},
                   20000);
        loadNetwork();
    }

    Q_INVOKABLE void connectWifi(const QString &ssid, const QString &password)
    {
        if (ssid.isEmpty() || m_busy)
            return;
        setBusy(true);
        setStatus(true, QStringLiteral("Connecting to %1…").arg(ssid));
        QStringList arguments = {QStringLiteral("dev"), QStringLiteral("wifi"),
                                 QStringLiteral("connect"), ssid};
        if (!password.isEmpty())
            arguments << QStringLiteral("password") << password;
        appendLog(QStringLiteral("$ nmcli %1").arg(arguments.join(QLatin1Char(' '))));
        int exitCode = 0;
        const QString output = runProgram(QStringLiteral("nmcli"), arguments,
                                          90000, &exitCode);
        appendLog(output);
        setBusy(false);
        setStatus(exitCode == 0, exitCode == 0
                                     ? QStringLiteral("Connected to %1").arg(ssid)
                                     : QStringLiteral("Could not connect to %1").arg(ssid));
        loadNetwork();
    }

    Q_INVOKABLE void disconnectWifi()
    {
        const QString active =
            runProgram(QStringLiteral("nmcli"),
                       {QStringLiteral("-t"), QStringLiteral("-f"),
                        QStringLiteral("NAME,TYPE"), QStringLiteral("connection"),
                        QStringLiteral("show"), QStringLiteral("--active")},
                       8000);
        QString connection;
        for (const QString &line : active.split(QLatin1Char('\n'))) {
            const QStringList parts = line.split(QLatin1Char(':'));
            if (parts.size() >= 2 && parts.at(1).contains(QStringLiteral("wireless"))) {
                connection = parts.at(0);
                break;
            }
        }
        if (connection.isEmpty()) {
            setStatus(false, QStringLiteral("No active Wi-Fi connection"));
            return;
        }
        int exitCode = 0;
        runProgram(QStringLiteral("nmcli"),
                   {QStringLiteral("connection"), QStringLiteral("down"), connection},
                   20000, &exitCode);
        setStatus(exitCode == 0, exitCode == 0
                                     ? QStringLiteral("Disconnected %1").arg(connection)
                                     : QStringLiteral("Could not disconnect"));
        loadNetwork();
    }

    Q_INVOKABLE void startHotspot(const QString &ssid, const QString &password)
    {
        const QString name = ssid.trimmed().isEmpty()
                                 ? QStringLiteral("ElvonOS Hotspot")
                                 : ssid.trimmed();
        if (password.size() < 8) {
            setStatus(false, QStringLiteral("Hotspot password needs 8 characters"));
            return;
        }
        const QString interfaces =
            runProgram(QStringLiteral("nmcli"),
                       {QStringLiteral("-t"), QStringLiteral("-f"),
                        QStringLiteral("DEVICE,TYPE"), QStringLiteral("device"),
                        QStringLiteral("status")}, 8000);
        QString wifi;
        for (const QString &line : interfaces.split(QLatin1Char('\n'))) {
            const QStringList parts = line.split(QLatin1Char(':'));
            if (parts.size() >= 2 && parts.at(1) == QStringLiteral("wifi")) {
                wifi = parts.at(0);
                break;
            }
        }
        if (wifi.isEmpty()) {
            setStatus(false, QStringLiteral("No Wi-Fi adapter available"));
            return;
        }
        setBusy(true);
        setStatus(true, QStringLiteral("Starting hotspot %1…").arg(name));
        int exitCode = 0;
        const QString output = runProgram(
            QStringLiteral("nmcli"),
            {QStringLiteral("device"), QStringLiteral("wifi"),
             QStringLiteral("hotspot"), QStringLiteral("ifname"), wifi,
             QStringLiteral("ssid"), name, QStringLiteral("password"), password},
            90000, &exitCode);
        appendLog(output);
        setBusy(false);
        setStatus(exitCode == 0, exitCode == 0
                                     ? QStringLiteral("Hotspot %1 is active").arg(name)
                                     : QStringLiteral("Could not start the hotspot"));
        loadNetwork();
    }

    Q_INVOKABLE void stopHotspot()
    {
        int exitCode = 0;
        runProgram(QStringLiteral("nmcli"),
                   {QStringLiteral("connection"), QStringLiteral("down"),
                    QStringLiteral("Hotspot")}, 20000, &exitCode);
        setStatus(exitCode == 0, exitCode == 0
                                     ? QStringLiteral("Hotspot stopped")
                                     : QStringLiteral("Could not stop the hotspot"));
        loadNetwork();
    }

    Q_INVOKABLE void setFlightMode(bool enabled)
    {
        int exitCode = 0;
        runProgram(QStringLiteral("nmcli"),
                   {QStringLiteral("radio"), QStringLiteral("all"),
                    enabled ? QStringLiteral("off") : QStringLiteral("on")},
                   20000, &exitCode);
        if (m_bluetoothAvailable) {
            runProgram(QStringLiteral("bluetoothctl"),
                       {QStringLiteral("power"),
                        enabled ? QStringLiteral("off") : QStringLiteral("on")},
                       15000);
        }
        m_flightMode = enabled;
        emit changed();
        setStatus(exitCode == 0, enabled ? QStringLiteral("Flight mode enabled")
                                         : QStringLiteral("Flight mode disabled"));
        loadNetwork();
        if (m_bluetoothAvailable)
            loadBluetooth();
    }

    Q_INVOKABLE void connectVpn(const QString &name)
    {
        if (name.isEmpty())
            return;
        setBusy(true);
        int exitCode = 0;
        const QString output =
            runProgram(QStringLiteral("nmcli"),
                       {QStringLiteral("connection"), QStringLiteral("up"),
                        QStringLiteral("id"), name}, 120000, &exitCode);
        appendLog(output);
        setBusy(false);
        setStatus(exitCode == 0, exitCode == 0
                                     ? QStringLiteral("VPN %1 connected").arg(name)
                                     : QStringLiteral("Could not connect VPN %1").arg(name));
        loadNetwork();
    }

    Q_INVOKABLE void disconnectVpn(const QString &name)
    {
        if (name.isEmpty())
            return;
        int exitCode = 0;
        runProgram(QStringLiteral("nmcli"),
                   {QStringLiteral("connection"), QStringLiteral("down"),
                    QStringLiteral("id"), name}, 30000, &exitCode);
        setStatus(exitCode == 0, exitCode == 0
                                     ? QStringLiteral("VPN %1 disconnected").arg(name)
                                     : QStringLiteral("Could not disconnect VPN %1").arg(name));
        loadNetwork();
    }

    Q_INVOKABLE void importVpn(const QString &path)
    {
        const QString source = path.trimmed();
        if (source.isEmpty() || !QFileInfo::exists(source)) {
            setStatus(false, QStringLiteral("VPN configuration file not found"));
            return;
        }
        QString type = QStringLiteral("openvpn");
        if (source.endsWith(QStringLiteral(".conf"), Qt::CaseInsensitive))
            type = QStringLiteral("wireguard");
        int exitCode = 0;
        const QString output =
            runProgram(QStringLiteral("nmcli"),
                       {QStringLiteral("connection"), QStringLiteral("import"),
                        QStringLiteral("type"), type, QStringLiteral("file"), source},
                       60000, &exitCode);
        appendLog(output);
        setStatus(exitCode == 0, exitCode == 0
                                     ? QStringLiteral("VPN configuration imported")
                                     : QStringLiteral("Could not import the VPN configuration"));
        loadNetwork();
    }

    Q_INVOKABLE void openVpnSettings()
    {
        if (!launchFirst({QStringLiteral("nm-connection-editor")}))
            setStatus(false, QStringLiteral("VPN settings are not installed"));
    }

    /* ---------------- Bluetooth ---------------- */

    Q_INVOKABLE void setBluetoothEnabled(bool enabled)
    {
        int exitCode = 0;
        runProgram(QStringLiteral("bluetoothctl"),
                   {QStringLiteral("power"),
                    enabled ? QStringLiteral("on") : QStringLiteral("off")},
                   15000, &exitCode);
        m_bluetoothEnabled = enabled && exitCode == 0;
        emit changed();
        setStatus(exitCode == 0, enabled ? QStringLiteral("Bluetooth enabled")
                                         : QStringLiteral("Bluetooth disabled"));
        loadBluetooth();
    }

    Q_INVOKABLE void scanBluetooth()
    {
        if (!m_bluetoothAvailable) {
            setStatus(false, QStringLiteral("No Bluetooth adapter available"));
            return;
        }
        setBusy(true);
        setStatus(true, QStringLiteral("Scanning for Bluetooth devices…"));
        runProgram(QStringLiteral("bluetoothctl"),
                   {QStringLiteral("--timeout"), QStringLiteral("10"),
                    QStringLiteral("scan"), QStringLiteral("on")}, 15000);
        setBusy(false);
        loadBluetooth();
    }

    Q_INVOKABLE void pairBluetooth(const QString &address)
    {
        if (address.isEmpty())
            return;
        setBusy(true);
        runProgram(QStringLiteral("bluetoothctl"),
                   {QStringLiteral("pair"), address}, 45000);
        runProgram(QStringLiteral("bluetoothctl"),
                   {QStringLiteral("trust"), address}, 15000);
        runProgram(QStringLiteral("bluetoothctl"),
                   {QStringLiteral("connect"), address}, 30000);
        setBusy(false);
        setStatus(true, QStringLiteral("Bluetooth device paired"));
        loadBluetooth();
    }

    Q_INVOKABLE void connectBluetooth(const QString &address)
    {
        if (address.isEmpty())
            return;
        int exitCode = 0;
        runProgram(QStringLiteral("bluetoothctl"),
                   {QStringLiteral("connect"), address}, 30000, &exitCode);
        setStatus(exitCode == 0, exitCode == 0
                                     ? QStringLiteral("Bluetooth device connected")
                                     : QStringLiteral("Could not connect the Bluetooth device"));
        loadBluetooth();
    }

    /* ---------------- Audio / displays ---------------- */

    Q_INVOKABLE void setDefaultSink(const QString &name)
    {
        if (name.isEmpty())
            return;
        runProgram(QStringLiteral("pactl"),
                   {QStringLiteral("set-default-sink"), name}, 8000);
        setStatus(true, QStringLiteral("Default output: %1").arg(name));
        loadDevices();
    }

    Q_INVOKABLE void setSinkVolume(int percent)
    {
        const int value = qBound(0, percent, 100);
        runProgram(QStringLiteral("pactl"),
                   {QStringLiteral("set-sink-volume"), QStringLiteral("@DEFAULT_SINK@"),
                    QString::number(value) + QLatin1Char('%')},
                   5000);
        m_sinkVolume = value;
        emit changed();
    }

    Q_INVOKABLE void setSinkMuted(bool muted)
    {
        runProgram(QStringLiteral("pactl"),
                   {QStringLiteral("set-sink-mute"), QStringLiteral("@DEFAULT_SINK@"),
                    muted ? QStringLiteral("1") : QStringLiteral("0")},
                   5000);
        m_sinkMuted = muted;
        emit changed();
    }

    Q_INVOKABLE void setDefaultSource(const QString &name)
    {
        if (name.isEmpty())
            return;
        runProgram(QStringLiteral("pactl"),
                   {QStringLiteral("set-default-source"), name}, 8000);
        setStatus(true, QStringLiteral("Default input: %1").arg(name));
        loadDevices();
    }

    Q_INVOKABLE void setSourceVolume(int percent)
    {
        const int value = qBound(0, percent, 100);
        runProgram(QStringLiteral("pactl"),
                   {QStringLiteral("set-source-volume"), QStringLiteral("@DEFAULT_SOURCE@"),
                    QString::number(value) + QLatin1Char('%')},
                   5000);
        m_sourceVolume = value;
        emit changed();
    }

    Q_INVOKABLE void setSourceMuted(bool muted)
    {
        runProgram(QStringLiteral("pactl"),
                   {QStringLiteral("set-source-mute"), QStringLiteral("@DEFAULT_SOURCE@"),
                    muted ? QStringLiteral("1") : QStringLiteral("0")},
                   5000);
        m_sourceMuted = muted;
        emit changed();
    }

    Q_INVOKABLE void setDisplayMode(const QString &output, const QString &mode)
    {
        if (output.isEmpty() || mode.isEmpty())
            return;
        int exitCode = 0;
        runProgram(QStringLiteral("wlr-randr"),
                   {QStringLiteral("--output"), output, QStringLiteral("--mode"), mode},
                   15000, &exitCode);
        setStatus(exitCode == 0, exitCode == 0
                                     ? QStringLiteral("Display mode updated")
                                     : QStringLiteral("Could not change the display mode"));
        loadDevices();
    }

    Q_INVOKABLE void openPrintScan()
    {
        if (!QProcess::startDetached(QStringLiteral("elvonos-printscan"), {}))
            setStatus(false, QStringLiteral("Print & Scan is not installed"));
    }

    Q_INVOKABLE void openCleaner()
    {
        if (!launchFirst({QStringLiteral("elvonos-cleaner")}))
            setStatus(false, QStringLiteral("Cleaner is not installed"));
    }

    Q_INVOKABLE void openPackageInstaller()
    {
        if (!QProcess::startDetached(QStringLiteral("elvonos-package-installer"), {}))
            setStatus(false, QStringLiteral("Package Installer is not installed"));
    }

    Q_INVOKABLE void openWinePrefix()
    {
        const QString prefix = QDir::homePath() + QStringLiteral("/.wine");
        QDir().mkpath(prefix);
        openExternal(prefix);
    }

    /* ---------------- Apps ---------------- */

    Q_INVOKABLE void uninstallApp(const QString &kind, const QString &id)
    {
        if (m_busy || id.isEmpty())
            return;
        setBusy(true);
        appendLog(QStringLiteral("$ uninstall %1 (%2)").arg(id, kind));
        QStringList arguments;
        QString program;
        if (kind == QStringLiteral("flatpak")) {
            program = QStringLiteral("flatpak");
            arguments = {QStringLiteral("uninstall"), QStringLiteral("-y"), id};
        } else {
            program = QStringLiteral("sudo");
            arguments = {QStringLiteral("-n"), QStringLiteral("apt-get"),
                         QStringLiteral("remove"), QStringLiteral("-y"), id};
        }
        int exitCode = 0;
        const QString output = runProgram(program, arguments, 180000, &exitCode);
        appendLog(output);
        if (exitCode == 0 && kind != QStringLiteral("flatpak")) {
            runProgram(QStringLiteral("sudo"),
                       {QStringLiteral("-n"), QStringLiteral("rm"), QStringLiteral("-f"),
                        QStringLiteral("/var/lib/elvonos/installed-apps/") + id},
                       5000);
        }
        setBusy(false);
        setStatus(exitCode == 0, exitCode == 0
                                     ? QStringLiteral("Removed %1").arg(id)
                                     : QStringLiteral("Could not remove %1").arg(id));
        loadApps();
    }

    Q_INVOKABLE void setDefaultApp(const QString &mime, const QString &desktopId)
    {
        if (mime.isEmpty() || desktopId.isEmpty())
            return;
        int exitCode = 0;
        runProgram(QStringLiteral("xdg-mime"),
                   {QStringLiteral("default"), desktopId, mime}, 10000, &exitCode);
        setStatus(exitCode == 0, exitCode == 0
                                     ? QStringLiteral("Default application updated")
                                     : QStringLiteral("Could not set the default application"));
        loadDefaultApps();
        emit changed();
    }

    Q_INVOKABLE void setAutostart(const QString &path, bool enabled)
    {
        QSettings settings(path, QSettings::IniFormat);
        settings.beginGroup(QStringLiteral("Desktop Entry"));
        if (enabled) {
            settings.remove(QStringLiteral("Hidden"));
            settings.setValue(QStringLiteral("X-GNOME-Autostart-enabled"), true);
        } else {
            settings.setValue(QStringLiteral("Hidden"), true);
        }
        settings.sync();
        settings.endGroup();
        setStatus(true, enabled ? QStringLiteral("Autostart enabled")
                                : QStringLiteral("Autostart disabled"));
        loadAutostart();
        emit changed();
    }

    /* ---------------- Design ---------------- */

    Q_INVOKABLE void applyWallpaper(const QString &path)
    {
        if (path.isEmpty() || !QFileInfo::exists(path))
            return;
        QSettings settings(win8SettingsPath(), QSettings::IniFormat);
        settings.setValue(QStringLiteral("Wallpaper/Desktop"), path);
        settings.sync();
        m_wallpaperPath = path;
        QProcess::startDetached(QStringLiteral("swaybg"),
                                {QStringLiteral("-i"), path, QStringLiteral("-m"),
                                 QStringLiteral("fill")});
        setStatus(true, QStringLiteral("Wallpaper updated"));
        emit changed();
    }

    /* ---------------- Time and language ---------------- */

    Q_INVOKABLE void setTimezone(const QString &timezone)
    {
        if (timezone.isEmpty())
            return;
        if (m_busy)
            return;
        setBusy(true);
        int exitCode = 0;
        const QString output =
            runProgram(QStringLiteral("sudo"),
                       {QStringLiteral("-n"), QStringLiteral("timedatectl"),
                        QStringLiteral("set-timezone"), timezone},
                       30000, &exitCode);
        appendLog(output);
        setBusy(false);
        setStatus(exitCode == 0, exitCode == 0
                                     ? QStringLiteral("Timezone set to %1").arg(timezone)
                                     : QStringLiteral("Could not set the timezone"));
        loadTime();
        emit changed();
    }

    Q_INVOKABLE void setNtp(bool enabled)
    {
        int exitCode = 0;
        runProgram(QStringLiteral("sudo"),
                   {QStringLiteral("-n"), QStringLiteral("timedatectl"),
                    QStringLiteral("set-ntp"),
                    enabled ? QStringLiteral("true") : QStringLiteral("false")},
                   30000, &exitCode);
        setStatus(exitCode == 0, enabled ? QStringLiteral("Automatic time enabled")
                                         : QStringLiteral("Automatic time disabled"));
        loadTime();
        emit changed();
    }

    Q_INVOKABLE void setKeyboardLayout(const QString &layout)
    {
        if (layout.isEmpty())
            return;
        const QString directory =
            QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
            + QStringLiteral("/environment.d");
        QDir().mkpath(directory);
        QFile file(directory + QStringLiteral("/99-elvonos-keyboard.conf"));
        if (file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            file.write(QStringLiteral("XKB_DEFAULT_LAYOUT=%1\n").arg(layout).toUtf8());
            file.close();
        }
        m_keyboardLayout = layout;
        setStatus(true, QStringLiteral("Keyboard layout set to %1 (applies to new sessions)")
                            .arg(layout));
        emit changed();
    }

    Q_INVOKABLE void setHostname(const QString &hostname)
    {
        const QString name = hostname.trimmed();
        if (name.isEmpty() || m_busy)
            return;
        setBusy(true);
        int exitCode = 0;
        const QString output =
            runProgram(QStringLiteral("sudo"),
                       {QStringLiteral("-n"), QStringLiteral("hostnamectl"),
                        QStringLiteral("set-hostname"), name},
                       30000, &exitCode);
        appendLog(output);
        setBusy(false);
        setStatus(exitCode == 0, exitCode == 0
                                     ? QStringLiteral("Hostname set to %1").arg(name)
                                     : QStringLiteral("Could not set the hostname"));
        loadSystem();
        emit changed();
    }

    Q_INVOKABLE void setLocale(const QString &locale)
    {
        if (locale.isEmpty() || m_busy)
            return;
        setBusy(true);
        int exitCode = 0;
        const QString output =
            runProgram(QStringLiteral("sudo"),
                       {QStringLiteral("-n"), QStringLiteral("localectl"),
                        QStringLiteral("set-locale"),
                        QStringLiteral("LANG=") + locale},
                       30000, &exitCode);
        appendLog(output);
        const QString envDir =
            QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
            + QStringLiteral("/environment.d");
        QDir().mkpath(envDir);
        QFile file(envDir + QStringLiteral("/99-elvonos-locale.conf"));
        if (file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            file.write(QStringLiteral("LANG=%1\n").arg(locale).toUtf8());
            file.close();
        }
        setBusy(false);
        setStatus(exitCode == 0, exitCode == 0
                                     ? QStringLiteral("Language set to %1").arg(locale)
                                     : QStringLiteral("Could not set the language"));
        loadTime();
        emit changed();
    }

    /* ---------------- Gaming / VR ---------------- */

    Q_INVOKABLE void gamingInstall(const QString &what)
    {
        if (m_busy)
            return;
        const QString action = QStringLiteral("install-") + what;
        setBusy(true);
        appendLog(QStringLiteral("$ elvonos-gaming-setup %1").arg(action));
        setStatus(true, QStringLiteral("Installing %1…").arg(what));
        int exitCode = 0;
        const QString output =
            runProgram(QStringLiteral("sudo"),
                       {QStringLiteral("-n"), gamingScript(), action},
                       900000, &exitCode);
        appendLog(output);
        setBusy(false);
        setStatus(exitCode == 0, exitCode == 0
                                     ? QStringLiteral("%1 installed").arg(what)
                                     : QStringLiteral("%1 installation failed (see log)").arg(what));
        loadGaming();
        emit changed();
    }

    Q_INVOKABLE void setWineHandler(bool enabled)
    {
        int exitCode = 0;
        const QString output =
            runProgram(gamingScript(),
                       {enabled ? QStringLiteral("wine-handler-on")
                                : QStringLiteral("wine-handler-off")},
                       30000, &exitCode);
        appendLog(output);
        setStatus(exitCode == 0,
                  enabled ? QStringLiteral("Wine handles .exe/.msi files")
                          : QStringLiteral("Wine handler removed"));
        loadGaming();
        emit changed();
    }

    Q_INVOKABLE void openWineConfig()
    {
        if (!QProcess::startDetached(QStringLiteral("winecfg"), {}))
            setStatus(false, QStringLiteral("Wine is not installed"));
    }

    Q_INVOKABLE void refreshGaming() { loadGaming(); emit changed(); }

    /* ---------------- Firewall ---------------- */

    Q_INVOKABLE void setFirewall(bool enabled)
    {
        runTune({QStringLiteral("firewall"), enabled ? QStringLiteral("on")
                                                     : QStringLiteral("off")},
                enabled ? QStringLiteral("Enabling the firewall…")
                        : QStringLiteral("Disabling the firewall…"));
        QTimer::singleShot(800, this, &SettingsApi::loadFirewall);
    }

    Q_INVOKABLE void loadFirewall()
    {
        refreshTune();
        int exitCode = 0;
        QString rules = runProgram(QStringLiteral("sudo"),
                                   {QStringLiteral("-n"), QStringLiteral("nft"),
                                    QStringLiteral("list"), QStringLiteral("ruleset")},
                                   8000, &exitCode);
        if (exitCode != 0)
            rules = runProgram(QStringLiteral("nft"),
                               {QStringLiteral("list"), QStringLiteral("ruleset")},
                               8000);
        if (rules.size() > 30000)
            rules = rules.left(30000) + QStringLiteral("\n…");
        m_firewallRules = rules.trimmed().isEmpty()
                              ? QStringLiteral("No nftables rules loaded.")
                              : rules;
        emit changed();
    }

    /* ---------------- Privacy ---------------- */

    Q_INVOKABLE void clearRecentFiles()
    {
        const QString path = QStandardPaths::writableLocation(
                                 QStandardPaths::GenericDataLocation)
                             + QStringLiteral("/recently-used.xbel");
        const bool ok = !QFileInfo::exists(path) || QFile::remove(path);
        setStatus(ok, ok ? QStringLiteral("Recent files cleared")
                         : QStringLiteral("Could not clear recent files"));
        loadPrivacy();
        emit changed();
    }

    Q_INVOKABLE void clearThumbnails()
    {
        const QString path = QStandardPaths::writableLocation(
                                 QStandardPaths::CacheLocation);
        QDir cache(path);
        bool ok = true;
        if (cache.exists(QStringLiteral("thumbnails")))
            ok = QDir(cache.filePath(QStringLiteral("thumbnails"))).removeRecursively();
        setStatus(ok, ok ? QStringLiteral("Thumbnail cache cleared")
                         : QStringLiteral("Could not clear the thumbnail cache"));
        loadPrivacy();
        emit changed();
    }

    Q_INVOKABLE void clearClipboard()
    {
        int exitCode = 0;
        runProgram(QStringLiteral("wl-copy"), {QStringLiteral("--clear")}, 3000, &exitCode);
        setStatus(exitCode == 0, exitCode == 0
                                     ? QStringLiteral("Clipboard cleared")
                                     : QStringLiteral("Could not clear the clipboard"));
    }

    Q_INVOKABLE void clearShellHistory()
    {
        QFile::remove(QDir::homePath() + QStringLiteral("/.bash_history"));
        setStatus(true, QStringLiteral("Shell history cleared"));
        loadPrivacy();
        emit changed();
    }

    Q_INVOKABLE void clearPackageCache()
    {
        if (m_busy)
            return;
        setBusy(true);
        int exitCode = 0;
        appendLog(QStringLiteral("$ apt-get clean"));
        const QString output =
            runProgram(QStringLiteral("sudo"),
                       {QStringLiteral("-n"), QStringLiteral("apt-get"),
                        QStringLiteral("clean")},
                       120000, &exitCode);
        appendLog(output);
        setBusy(false);
        setStatus(exitCode == 0, exitCode == 0
                                     ? QStringLiteral("Package cache cleared")
                                     : QStringLiteral("Could not clear the package cache"));
    }

    Q_INVOKABLE void clearApplicationCache()
    {
        const QString cache = QStandardPaths::writableLocation(
            QStandardPaths::CacheLocation);
        QDir directory(cache);
        bool ok = true;
        for (const QFileInfo &entry : directory.entryInfoList(
                 QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot)) {
            if (entry.isDir())
                ok = QDir(entry.absoluteFilePath()).removeRecursively() && ok;
            else
                ok = QFile::remove(entry.absoluteFilePath()) && ok;
        }
        setStatus(ok, ok ? QStringLiteral("Application cache cleared")
                         : QStringLiteral("Some cache files could not be removed"));
        emit changed();
    }

    /* ---------------- Updates ---------------- */

    Q_INVOKABLE void checkUpdates()
    {
        if (m_busy)
            return;
        setBusy(true);
        setStatus(true, QStringLiteral("Checking for updates…"));
        appendLog(QStringLiteral("$ apt-get update"));
        int exitCode = 0;
        const QString updateOutput =
            runProgram(QStringLiteral("sudo"),
                       {QStringLiteral("-n"), QStringLiteral("apt-get"),
                        QStringLiteral("update")},
                       180000, &exitCode);
        appendLog(updateOutput);

        m_updates.clear();
        const QString list =
            runProgram(QStringLiteral("apt"), {QStringLiteral("list"),
                                               QStringLiteral("--upgradable")},
                       30000);
        const QRegularExpression lineExpression(
            QStringLiteral("^([^/\\s]+)/\\S+\\s+(\\S+)\\s+\\S+.*upgradable"));
        for (const QString &line : list.split(QLatin1Char('\n'))) {
            const QRegularExpressionMatch match = lineExpression.match(line);
            if (!match.hasMatch())
                continue;
            QVariantMap item;
            item.insert(QStringLiteral("name"), match.captured(1));
            item.insert(QStringLiteral("version"), match.captured(2));
            m_updates.append(item);
        }
        setBusy(false);
        setStatus(exitCode == 0,
                  m_updates.isEmpty()
                      ? QStringLiteral("System is up to date")
                      : QStringLiteral("%1 updates available").arg(m_updates.size()));
        emit changed();
    }

    Q_INVOKABLE void installUpdates()
    {
        if (m_busy)
            return;
        setBusy(true);
        setStatus(true, QStringLiteral("Installing updates…"));
        appendLog(QStringLiteral("$ apt-get upgrade -y"));
        int exitCode = 0;
        const QString output =
            runProgram(QStringLiteral("sudo"),
                       {QStringLiteral("-n"), QStringLiteral("apt-get"),
                        QStringLiteral("upgrade"), QStringLiteral("-y")},
                       900000, &exitCode);
        appendLog(output);
        setBusy(false);
        setStatus(exitCode == 0, exitCode == 0
                                     ? QStringLiteral("Updates installed")
                                     : QStringLiteral("Update installation failed (see log)"));
        checkUpdates();
    }

    /* ---------------- ElvonOS update feed ---------------- */

    QString elvonosVersion() const { return m_elvonosVersion; }
    QString elvonosLatest() const { return m_elvonosLatest; }
    bool elvonosUpdateAvailable() const { return m_elvonosUpdateAvailable; }
    int elvonosOsUpdates() const { return m_elvonosOsUpdates; }
    int elvonosComponentUpdates() const { return m_elvonosComponentUpdates; }
    QString elvonosComponentList() const { return m_elvonosComponentList; }
    bool elvonosBusy() const { return m_elvonosBusy; }
    QString elvonosLog() const { return m_elvonosLog; }
    bool elvonosIsoAvailable() const { return m_elvonosIsoAvailable; }
    QString elvonosCheckedAt() const { return m_elvonosCheckedAt; }
    bool elvonosAutoShutdown() const
    {
        QFile file(QStringLiteral("/etc/elvonos/update.conf"));
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
            return true;
        for (const QString &line :
             QString::fromUtf8(file.readAll()).split(QLatin1Char('\n'))) {
            if (line.startsWith(QStringLiteral("AUTO_APPLY=")))
                return line.mid(11).trimmed() != QStringLiteral("off");
        }
        return true;
    }

    void appendElvonosLog(const QString &text)
    {
        if (text.isEmpty())
            return;
        m_elvonosLog += text;
        if (m_elvonosLog.size() > 30000)
            m_elvonosLog = m_elvonosLog.right(30000);
        emit changed();
    }

    Q_INVOKABLE void checkElvonosUpdate()
    {
        if (m_elvonosProcess)
            return;
        m_elvonosBusy = true;
        m_elvonosLog.clear();
        emit changed();
        m_elvonosProcess = new QProcess(this);
        m_elvonosProcess->setProcessChannelMode(QProcess::SeparateChannels);
        connect(m_elvonosProcess, &QProcess::readyReadStandardError, this, [this] {
            if (m_elvonosProcess)
                appendElvonosLog(
                    QString::fromUtf8(m_elvonosProcess->readAllStandardError()));
        });
        connect(m_elvonosProcess,
                QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this](int exitCode, QProcess::ExitStatus) {
            if (!m_elvonosProcess)
                return;
            appendElvonosLog(
                QString::fromUtf8(m_elvonosProcess->readAllStandardError()));
            const QJsonObject object =
                QJsonDocument::fromJson(
                    m_elvonosProcess->readAllStandardOutput()).object();
            m_elvonosProcess->deleteLater();
            m_elvonosProcess = nullptr;
            m_elvonosBusy = false;
            if (object.isEmpty() || exitCode != 0) {
                setStatus(false, QStringLiteral("ElvonOS update check failed"));
                emit changed();
                return;
            }
            m_elvonosLatest = object.value(QStringLiteral("latest")).toString();
            m_elvonosUpdateAvailable =
                object.value(QStringLiteral("update")).toBool();
            m_elvonosOsUpdates =
                object.value(QStringLiteral("os_updates")).toInt();
            m_elvonosIsoAvailable =
                object.value(QStringLiteral("iso")).toBool();
            const QJsonArray components =
                object.value(QStringLiteral("components")).toArray();
            m_elvonosComponentUpdates = components.size();
            QStringList ids;
            for (const QJsonValue &value : components)
                ids.append(value.toObject().value(QStringLiteral("id")).toString());
            m_elvonosComponentList = ids.join(QStringLiteral(", "));
            m_elvonosCheckedAt = QDateTime::currentDateTime().toString(
                QStringLiteral("yyyy-MM-dd HH:mm"));
            setStatus(true, QStringLiteral("Update check finished."));
            emit changed();
        });
        connect(m_elvonosProcess, &QProcess::errorOccurred, this, [this] {
            if (!m_elvonosProcess)
                return;
            m_elvonosProcess->deleteLater();
            m_elvonosProcess = nullptr;
            m_elvonosBusy = false;
            setStatus(false, QStringLiteral("ElvonOS update check failed"));
            emit changed();
        });
        m_elvonosProcess->start(QStringLiteral("elvonos-update"),
                                {QStringLiteral("check")});
        setStatus(true, QStringLiteral("Checking ElvonOS updates…"));
    }

    void runElvonosAction(bool root, const QStringList &args,
                          const QString &label, bool recheck)
    {
        if (m_elvonosProcess)
            return;
        m_elvonosBusy = true;
        m_elvonosLog.clear();
        emit changed();

        QString program = QStringLiteral("elvonos-update");
        QStringList arguments = args;
        if (root && QFileInfo::exists(QStringLiteral("/usr/bin/pkexec"))) {
            program = QStringLiteral("pkexec");
            arguments.prepend(QStringLiteral("elvonos-update"));
        }

        m_elvonosProcess = new QProcess(this);
        m_elvonosProcess->setProcessChannelMode(QProcess::MergedChannels);
        connect(m_elvonosProcess, &QProcess::readyRead, this, [this] {
            if (m_elvonosProcess)
                appendElvonosLog(QString::fromUtf8(m_elvonosProcess->readAll()));
        });
        connect(m_elvonosProcess,
                QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                this, [this, label, recheck](int exitCode, QProcess::ExitStatus) {
            if (!m_elvonosProcess)
                return;
            appendElvonosLog(QString::fromUtf8(m_elvonosProcess->readAll()));
            const bool ok = exitCode == 0;
            m_elvonosProcess->deleteLater();
            m_elvonosProcess = nullptr;
            m_elvonosBusy = false;
            setStatus(ok, label + (ok ? QStringLiteral(" finished.")
                                     : QStringLiteral(" failed.")));
            emit changed();
            if (ok && recheck)
                QTimer::singleShot(1200, this, [this] { checkElvonosUpdate(); });
        });
        connect(m_elvonosProcess, &QProcess::errorOccurred, this, [this, label] {
            if (!m_elvonosProcess)
                return;
            m_elvonosProcess->deleteLater();
            m_elvonosProcess = nullptr;
            m_elvonosBusy = false;
            setStatus(false, label + QStringLiteral(" failed."));
            emit changed();
        });
        m_elvonosProcess->start(program, arguments);
        setStatus(true, label + QStringLiteral("…"));
        emit changed();
    }

    Q_INVOKABLE void downloadElvonosUpdate()
    {
        runElvonosAction(false, {QStringLiteral("download")},
                         QStringLiteral("ISO download"), false);
    }

    Q_INVOKABLE void applyElvonosUpdate()
    {
        runElvonosAction(true, {QStringLiteral("apply")},
                         QStringLiteral("Update"), true);
    }

    Q_INVOKABLE void setElvonosAutoShutdown(bool enabled)
    {
        const QStringList arguments{QStringLiteral("elvonos-update-policy"),
                                    enabled ? QStringLiteral("on")
                                            : QStringLiteral("off")};
        if (QFileInfo::exists(QStringLiteral("/usr/bin/pkexec")))
            QProcess::startDetached(QStringLiteral("pkexec"), arguments);
        else
            QProcess::startDetached(QStringLiteral("elvonos-update-policy"),
                                    {enabled ? QStringLiteral("on")
                                             : QStringLiteral("off")});
        setStatus(true, enabled
                  ? QStringLiteral("Automatic shutdown updates enabled.")
                  : QStringLiteral("Automatic shutdown updates disabled."));
        QTimer::singleShot(1500, this, [this] { emit changed(); });
    }

    /* ---------------- Backups ---------------- */

    Q_INVOKABLE void createBackup()
    {
        if (m_busy)
            return;
        const QString directory = backupDir();
        QDir().mkpath(directory);
        const QString name = QStringLiteral("ElvonOS-backup-")
                             + QDateTime::currentDateTime().toString(
                                 QStringLiteral("yyyyMMdd-HHmmss"))
                             + QStringLiteral(".tar.gz");
        const QString path = directory + QLatin1Char('/') + name;
        const QString home = QDir::homePath();
        QStringList arguments = {QStringLiteral("-czf"), path,
                                 QStringLiteral("--ignore-failed-read"),
                                 QStringLiteral("-C"), home};
        const QStringList candidates = {
            QStringLiteral("Desktop"), QStringLiteral("Documents"),
            QStringLiteral("Downloads"), QStringLiteral("Pictures"),
            QStringLiteral("Music"), QStringLiteral("Videos"),
            QStringLiteral(".config/elvonos"),
        };
        for (const QString &candidate : candidates) {
            if (QFileInfo::exists(home + QLatin1Char('/') + candidate))
                arguments.append(candidate);
        }
        if (arguments.size() <= 5) {
            setStatus(false, QStringLiteral("Nothing to back up"));
            return;
        }
        setBusy(true);
        setStatus(true, QStringLiteral("Creating backup…"));
        appendLog(QStringLiteral("$ tar %1").arg(name));
        int exitCode = 0;
        const QString output = runProgram(QStringLiteral("tar"), arguments, 300000, &exitCode);
        appendLog(output);
        setBusy(false);
        setStatus(exitCode == 0, exitCode == 0
                                     ? QStringLiteral("Backup created: %1").arg(name)
                                     : QStringLiteral("Backup failed (see log)"));
        loadBackups();
        emit changed();
    }

    Q_INVOKABLE void restoreBackup(const QString &path)
    {
        if (m_busy || path.isEmpty())
            return;
        setBusy(true);
        setStatus(true, QStringLiteral("Restoring backup…"));
        appendLog(QStringLiteral("$ tar -xzf %1").arg(QFileInfo(path).fileName()));
        int exitCode = 0;
        const QString output =
            runProgram(QStringLiteral("tar"),
                       {QStringLiteral("-xzf"), path, QStringLiteral("-C"),
                        QDir::homePath()},
                       300000, &exitCode);
        appendLog(output);
        setBusy(false);
        setStatus(exitCode == 0, exitCode == 0
                                     ? QStringLiteral("Backup restored")
                                     : QStringLiteral("Restore failed (see log)"));
    }

    Q_INVOKABLE void deleteBackup(const QString &path)
    {
        if (path.isEmpty())
            return;
        const bool ok = QFile::remove(path);
        setStatus(ok, ok ? QStringLiteral("Backup deleted")
                         : QStringLiteral("Could not delete the backup"));
        loadBackups();
        emit changed();
    }

    Q_INVOKABLE void verifyBackup(const QString &path)
    {
        if (path.isEmpty() || m_busy)
            return;
        setBusy(true);
        int exitCode = 0;
        appendLog(QStringLiteral("$ tar -tzf %1").arg(QFileInfo(path).fileName()));
        const QString output =
            runProgram(QStringLiteral("tar"),
                       {QStringLiteral("-tzf"), path},
                       120000, &exitCode);
        const int entries = output.count(QLatin1Char('\n'));
        appendLog(output.left(4000));
        setBusy(false);
        setStatus(exitCode == 0, exitCode == 0
                                     ? QStringLiteral("Backup verified · %1 entries").arg(entries)
                                     : QStringLiteral("Backup verification failed"));
        emit changed();
    }

    Q_INVOKABLE void openBackups()
    {
        QDir().mkpath(backupDir());
        openExternal(backupDir());
    }

    /* ---------------- helpers exposed to QML ---------------- */

    Q_INVOKABLE void openPath(const QString &path)
    {
        openExternal(path);
    }

    Q_INVOKABLE void clearLog()
    {
        m_log.clear();
        emit logChanged();
    }

    Q_INVOKABLE QString appIcon(const QString &name) const { return iconFor(name); }

signals:
    void changed();
    void panelChanged();
    void inputChanged();
    void powerChanged();
    void themeChanged();
    void logChanged();
    void statusChanged();
    void busyChanged();

private:
    /* ---------------- data loading ---------------- */

    void loadSystem()
    {
        m_systemInfo.clear();
        const QString os = firstMatch(readText(QStringLiteral("/etc/os-release")),
                                      QRegularExpression(QStringLiteral(
                                          "^PRETTY_NAME=\"?([^\"\\n]+)\"?"),
                                          QRegularExpression::MultilineOption));
        const QString kernel = runProgram(QStringLiteral("uname"),
                                          {QStringLiteral("-r")}, 3000).trimmed();
        const QString host = runProgram(QStringLiteral("hostname"), {}, 3000).trimmed();
        m_hostname = host;
        const QString cpu =
            firstMatch(readText(QStringLiteral("/proc/cpuinfo")),
                       QRegularExpression(QStringLiteral("^model name\\s*:\\s*(.+)$"),
                                          QRegularExpression::MultilineOption));
        const QString memText =
            firstMatch(readText(QStringLiteral("/proc/meminfo")),
                       QRegularExpression(QStringLiteral("^MemTotal:\\s*(\\d+) kB")));
        qint64 memKb = memText.toLongLong();
        QString disk = runProgram(QStringLiteral("df"),
                                  {QStringLiteral("-h"), QStringLiteral("/")}, 5000);
        const QStringList diskLines = disk.split(QLatin1Char('\n'));
        QString diskText = diskLines.size() > 1
                               ? diskLines.at(1).simplified() : QStringLiteral("N/A");
        const QString uptime = runProgram(QStringLiteral("uptime"),
                                          {QStringLiteral("-p")}, 3000).trimmed();

        auto add = [this](const QString &label, const QString &value) {
            QVariantMap item;
            item.insert(QStringLiteral("label"), label);
            item.insert(QStringLiteral("value"), value.isEmpty()
                                                     ? QStringLiteral("N/A") : value);
            m_systemInfo.append(item);
        };
        add(QStringLiteral("Operating system"), os);
        add(QStringLiteral("Kernel"), kernel);
        add(QStringLiteral("Hostname"), host);
        add(QStringLiteral("Processor"), cpu);
        add(QStringLiteral("Memory"), memKb > 0 ? humanSize(memKb * 1024)
                                                : QStringLiteral("N/A"));
        add(QStringLiteral("Disk (/)"), diskText);
        add(QStringLiteral("Uptime"), uptime);

        const QStringList storage =
            runProgram(QStringLiteral("df"), {QStringLiteral("-h"), QStringLiteral("/")},
                       5000).split(QLatin1Char('\n'));
        m_storageInfo = storage.size() > 1 ? storage.at(1).simplified() : QString();

        refreshTune();
        loadPowerSettings();
        loadNotifications();
        loadFormFactor();
        emit changed();
    }

    void loadNetwork()
    {
        m_networkInfo.clear();
        const QString nm = runProgram(QStringLiteral("nmcli"),
                                      {QStringLiteral("-t"), QStringLiteral("-f"),
                                       QStringLiteral("DEVICE,TYPE,STATE,CONNECTION"),
                                       QStringLiteral("device"), QStringLiteral("status")},
                                      8000);
        if (!nm.trimmed().isEmpty()) {
            const QStringList lines = nm.split(QLatin1Char('\n'));
            const QString general =
                runProgram(QStringLiteral("nmcli"),
                           {QStringLiteral("-t"), QStringLiteral("-f"),
                            QStringLiteral("STATE"), QStringLiteral("general")},
                           5000).trimmed();
            for (const QString &line : lines) {
                const QStringList parts = line.split(QLatin1Char(':'));
                if (parts.size() < 3)
                    continue;
                QVariantMap item;
                item.insert(QStringLiteral("label"), parts.at(0));
                item.insert(QStringLiteral("value"),
                            parts.at(1) + QStringLiteral(" · ") + parts.at(2));
                item.insert(QStringLiteral("detail"),
                            parts.size() > 3 && !parts.at(3).isEmpty()
                                ? QStringLiteral("Connection: ") + parts.at(3)
                                : general);
                m_networkInfo.append(item);
            }
        } else {
            const QDir netDir(QStringLiteral("/sys/class/net"));
            for (const QString &entry :
                 netDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
                if (entry == QStringLiteral("lo"))
                    continue;
                QVariantMap item;
                item.insert(QStringLiteral("label"), entry);
                item.insert(QStringLiteral("value"),
                            readText(netDir.filePath(entry) + QStringLiteral("/operstate")));
                item.insert(QStringLiteral("detail"), QStringLiteral("Network interface"));
                m_networkInfo.append(item);
            }
        }

        const QString addresses = runProgram(QStringLiteral("ip"),
                                             {QStringLiteral("-o"), QStringLiteral("-4"),
                                              QStringLiteral("addr"), QStringLiteral("show")},
                                             5000);
        for (const QString &line : addresses.split(QLatin1Char('\n'))) {
            const QRegularExpressionMatch match =
                QRegularExpression(QStringLiteral("^\\d+:\\s+(\\S+)\\s+inet\\s+(\\S+)"))
                    .match(line);
            if (!match.hasMatch())
                continue;
            const QString device = match.captured(1);
            const QString address = match.captured(2);
            for (int i = 0; i < m_networkInfo.size(); ++i) {
                QVariantMap item = m_networkInfo.at(i).toMap();
                if (item.value(QStringLiteral("label")).toString() == device) {
                    item.insert(QStringLiteral("detail"),
                                address + QStringLiteral("  ·  ")
                                    + item.value(QStringLiteral("detail")).toString());
                    m_networkInfo[i] = item;
                    break;
                }
            }
        }

        m_wifiEnabled = runProgram(QStringLiteral("nmcli"),
                                   {QStringLiteral("radio"), QStringLiteral("wifi")},
                                   5000).trimmed() == QStringLiteral("enabled");
        m_networkingEnabled = runProgram(QStringLiteral("nmcli"),
                                         {QStringLiteral("networking")},
                                         5000).trimmed() == QStringLiteral("enabled");
        m_wifiNetworks.clear();
        const QString wifiList =
            runProgram(QStringLiteral("nmcli"),
                       {QStringLiteral("-t"), QStringLiteral("-f"),
                        QStringLiteral("IN-USE,SSID,SIGNAL,SECURITY"),
                        QStringLiteral("dev"), QStringLiteral("wifi"),
                        QStringLiteral("list")},
                       20000);
        QSet<QString> seen;
        for (const QString &line : wifiList.split(QLatin1Char('\n'))) {
            const QStringList parts = line.split(QLatin1Char(':'));
            if (parts.size() < 4)
                continue;
            const QString ssid = parts.at(1).trimmed();
            if (ssid.isEmpty() || seen.contains(ssid))
                continue;
            seen.insert(ssid);
            QVariantMap item;
            item.insert(QStringLiteral("ssid"), ssid);
            item.insert(QStringLiteral("signal"), parts.at(2).toInt());
            item.insert(QStringLiteral("security"),
                        parts.at(3).trimmed().isEmpty()
                            ? QStringLiteral("Open") : parts.at(3).trimmed());
            item.insert(QStringLiteral("active"),
                        parts.at(0).trimmed() == QStringLiteral("*")
                            || parts.at(0).trimmed() == QStringLiteral("yes"));
            m_wifiNetworks.append(item);
        }

        m_vpnConnections.clear();
        const QString connections =
            runProgram(QStringLiteral("nmcli"),
                       {QStringLiteral("-t"), QStringLiteral("-f"),
                        QStringLiteral("NAME,TYPE,ACTIVE"), QStringLiteral("connection"),
                        QStringLiteral("show")}, 8000);
        bool hotspot = false;
        for (const QString &line : connections.split(QLatin1Char('\n'))) {
            const QStringList parts = line.split(QLatin1Char(':'));
            if (parts.size() < 3)
                continue;
            if (parts.at(2) == QStringLiteral("yes")
                && parts.at(0) == QStringLiteral("Hotspot"))
                hotspot = true;
            if (parts.at(1) != QStringLiteral("vpn")
                && parts.at(1) != QStringLiteral("wireguard"))
                continue;
            QVariantMap vpn;
            vpn.insert(QStringLiteral("name"), parts.at(0));
            vpn.insert(QStringLiteral("type"), parts.at(1));
            vpn.insert(QStringLiteral("active"), parts.at(2) == QStringLiteral("yes"));
            m_vpnConnections.append(vpn);
        }
        m_hotspotActive = hotspot;

        const QString radio =
            runProgram(QStringLiteral("nmcli"),
                       {QStringLiteral("radio"), QStringLiteral("all")}, 4000);
        const bool wifiRadio = radio.contains(QStringLiteral("WIFI:enabled"));
        const bool wwanRadio = radio.contains(QStringLiteral("WWAN:enabled"));
        m_flightMode = !wifiRadio && !wwanRadio;

        QString activeConnection;
        const QString activeList =
            runProgram(QStringLiteral("nmcli"),
                       {QStringLiteral("-t"), QStringLiteral("-f"),
                        QStringLiteral("NAME,TYPE"), QStringLiteral("connection"),
                        QStringLiteral("show"), QStringLiteral("--active")}, 8000);
        for (const QString &line : activeList.split(QLatin1Char('\n'))) {
            const QStringList parts = line.split(QLatin1Char(':'));
            if (parts.size() >= 2 && !parts.at(1).contains(QStringLiteral("loopback"))) {
                activeConnection = parts.at(0);
                break;
            }
        }
        QString dns;
        if (!activeConnection.isEmpty())
            dns = runProgram(QStringLiteral("nmcli"),
                             {QStringLiteral("-g"), QStringLiteral("IP4.DNS"),
                              QStringLiteral("connection"), QStringLiteral("show"),
                              activeConnection}, 8000);
        m_dnsServers = QStringList(dns.split(QLatin1Char('\n'), Qt::SkipEmptyParts))
                           .join(QStringLiteral(", "));
        emit changed();
    }

    void loadDevices()
    {
        m_deviceInfo.clear();
        auto addInfo = [this](const QString &label, const QString &value,
                              const QString &detail) {
            QVariantMap item;
            item.insert(QStringLiteral("label"), label);
            item.insert(QStringLiteral("value"), value);
            item.insert(QStringLiteral("detail"), detail);
            m_deviceInfo.append(item);
        };

        const QString inputs = readText(QStringLiteral("/proc/bus/input/devices"));
        const QRegularExpression nameExpression(QStringLiteral("^N: Name=\"(.+)\"$"),
                                                QRegularExpression::MultilineOption);
        auto iterator = nameExpression.globalMatch(inputs);
        while (iterator.hasNext()) {
            const QRegularExpressionMatch match = iterator.next();
            addInfo(QStringLiteral("Input device"), match.captured(1),
                    QStringLiteral("input"));
        }

        m_audioSinks.clear();
        const QString sinks = runProgram(QStringLiteral("pactl"),
                                         {QStringLiteral("list"), QStringLiteral("short"),
                                          QStringLiteral("sinks")}, 5000);
        for (const QString &line : sinks.split(QLatin1Char('\n'))) {
            const QStringList parts = line.split(QLatin1Char('\t'));
            if (parts.size() >= 2) {
                QVariantMap item;
                item.insert(QStringLiteral("name"), parts.at(1));
                item.insert(QStringLiteral("detail"),
                            parts.size() > 2 ? parts.at(2) : QString());
                m_audioSinks.append(item);
            }
        }
        m_defaultSink = runProgram(QStringLiteral("pactl"),
                                   {QStringLiteral("get-default-sink")},
                                   5000).trimmed();
        const QString sinkVolume = runProgram(QStringLiteral("pactl"),
                                              {QStringLiteral("get-sink-volume"),
                                               QStringLiteral("@DEFAULT_SINK@")},
                                              5000);
        m_sinkVolume = qBound(0,
                              firstMatch(sinkVolume,
                                         QRegularExpression(QStringLiteral("(\\d+)%"))).toInt(),
                              100);
        m_sinkMuted = runProgram(QStringLiteral("pactl"),
                                 {QStringLiteral("get-sink-mute"),
                                  QStringLiteral("@DEFAULT_SINK@")},
                                 5000).contains(QStringLiteral("yes"),
                                                Qt::CaseInsensitive);

        m_audioSources.clear();
        const QString sources = runProgram(QStringLiteral("pactl"),
                                           {QStringLiteral("list"), QStringLiteral("short"),
                                            QStringLiteral("sources")}, 5000);
        for (const QString &line : sources.split(QLatin1Char('\n'))) {
            const QStringList parts = line.split(QLatin1Char('\t'));
            if (parts.size() >= 2
                && !parts.at(1).contains(QStringLiteral("monitor"))) {
                QVariantMap item;
                item.insert(QStringLiteral("name"), parts.at(1));
                item.insert(QStringLiteral("detail"),
                            parts.size() > 2 ? parts.at(2) : QString());
                m_audioSources.append(item);
            }
        }
        m_defaultSource = runProgram(QStringLiteral("pactl"),
                                     {QStringLiteral("get-default-source")},
                                     5000).trimmed();
        const QString sourceVolume = runProgram(QStringLiteral("pactl"),
                                                {QStringLiteral("get-source-volume"),
                                                 QStringLiteral("@DEFAULT_SOURCE@")},
                                                5000);
        m_sourceVolume = qBound(0,
                                firstMatch(sourceVolume,
                                           QRegularExpression(QStringLiteral("(\\d+)%"))).toInt(),
                                100);
        m_sourceMuted = runProgram(QStringLiteral("pactl"),
                                   {QStringLiteral("get-source-mute"),
                                    QStringLiteral("@DEFAULT_SOURCE@")},
                                   5000).contains(QStringLiteral("yes"),
                                                  Qt::CaseInsensitive);

        m_displayOutputs.clear();
        const QString displays = runProgram(QStringLiteral("wlr-randr"), {}, 5000);
        QString outputName;
        QString outputLabel;
        QStringList modes;
        QString currentMode;
        auto flushDisplay = [this, &outputName, &outputLabel, &modes, &currentMode]() {
            if (outputName.isEmpty())
                return;
            QVariantList modeItems;
            for (const QString &mode : modes) {
                QVariantMap modeItem;
                modeItem.insert(QStringLiteral("name"), mode);
                modeItems.append(modeItem);
            }
            QVariantMap item;
            item.insert(QStringLiteral("name"), outputName);
            item.insert(QStringLiteral("label"),
                        outputLabel.isEmpty() ? outputName : outputLabel);
            item.insert(QStringLiteral("current"), currentMode);
            item.insert(QStringLiteral("modes"), modeItems);
            m_displayOutputs.append(item);
            outputName.clear();
            outputLabel.clear();
            modes.clear();
            currentMode.clear();
        };
        for (const QString &line : displays.split(QLatin1Char('\n'))) {
            if (line.trimmed().isEmpty())
                continue;
            if (!line.startsWith(QLatin1Char(' '))) {
                flushDisplay();
                outputLabel = line.trimmed();
                outputName = outputLabel.section(QLatin1Char(' '), 0, 0);
            } else {
                const QRegularExpressionMatch match =
                    QRegularExpression(QStringLiteral("(\\d+x\\d+) px")).match(line);
                if (match.hasMatch()) {
                    const QString mode = match.captured(1);
                    if (!modes.contains(mode))
                        modes.append(mode);
                    if (line.contains(QStringLiteral("current")))
                        currentMode = mode;
                }
            }
        }
        flushDisplay();
        loadBluetooth();
        loadInputSettings();
        loadPrinters();

        emit changed();
    }

    void loadPanels()
    {
        const QJsonObject taskbar = readJsonObject(taskbarConfigPath());
        const QString position =
            taskbar.value(QStringLiteral("position")).toString(QStringLiteral("top"));
        m_taskbarPosition = position == QStringLiteral("bottom")
                                ? QStringLiteral("bottom") : QStringLiteral("top");
        m_taskbarHeight = qBound(44, taskbar.value(QStringLiteral("height")).toInt(54), 72);
        const QJsonObject panels = readJsonObject(panelsConfigPath());
        const QString dock =
            panels.value(QStringLiteral("dockPosition")).toString(QStringLiteral("bottom"));
        m_dockPosition = dock == QStringLiteral("top")
                             ? QStringLiteral("top") : QStringLiteral("bottom");
        emit panelChanged();
    }

    void loadFormFactor()
    {
        const QJsonObject object = readJsonObject(formFactorConfigPath());
        m_formFactor = object.value(QStringLiteral("type"))
                           .toString(QStringLiteral("pc"));
        m_formFactorMode = object.value(QStringLiteral("mode"))
                               .toString(QStringLiteral("auto"));
        m_formFactorScale = qBound(0.75,
                                   object.value(QStringLiteral("scale"))
                                       .toDouble(1.0), 2.0);
        m_touchMode = object.value(QStringLiteral("touch")).toBool(false)
                      || m_formFactor == QStringLiteral("tablet")
                      || m_formFactor == QStringLiteral("tv");
        const int width = object.value(QStringLiteral("displayWidth")).toInt(0);
        const int height = object.value(QStringLiteral("displayHeight")).toInt(0);
        if (width > 0 && height > 0)
            m_formFactorInfo = QStringLiteral("%1×%2 · %3×")
                                   .arg(width).arg(height)
                                   .arg(m_formFactorScale, 0, 'f', 2);
        else
            m_formFactorInfo = QStringLiteral("%1×")
                                   .arg(m_formFactorScale, 0, 'f', 2);
        emit changed();
    }

    void loadThemeSettings()
    {
        const QJsonObject object = readJsonObject(themeConfigPath());
        m_themePreset = object.value(QStringLiteral("preset"))
                            .toString(QStringLiteral("aero"));
        m_themeAccent = object.value(QStringLiteral("accent"))
                            .toString(QStringLiteral("#8FD3FF"));
        m_themeAccent2 = object.value(QStringLiteral("accent2"))
                             .toString(QStringLiteral("#4CC2FF"));
        m_themeWallpaper = object.value(QStringLiteral("wallpaper")).toString();
        m_themeWallpaperDim =
            qBound(0, object.value(QStringLiteral("wallpaperDim")).toInt(45), 90);
        m_themeWallpaperFill = object.value(QStringLiteral("wallpaperFill"))
                                   .toString(QStringLiteral("fill"));
        m_themePanel = object.value(QStringLiteral("panel"))
                           .toString(QStringLiteral("#15151C"));
        m_themeBackground = object.value(QStringLiteral("background"))
                                .toString(QStringLiteral("#101016"));
        m_themeSurface = object.value(QStringLiteral("surface"))
                             .toString(QStringLiteral("#1B1B26"));
        m_themeText = object.value(QStringLiteral("text"))
                          .toString(QStringLiteral("#E9ECF2"));
        m_themeMuted = object.value(QStringLiteral("muted"))
                           .toString(QStringLiteral("#8B93A1"));
        m_themeBorder = object.value(QStringLiteral("border"))
                            .toString(QStringLiteral("#FFFFFF"));
        m_themeRadius = qBound(0, object.value(QStringLiteral("radius")).toInt(14), 28);
        m_themeGlass = qBound(0, object.value(QStringLiteral("glass")).toInt(78), 100);
        emit themeChanged();
    }

    QJsonObject currentTheme() const
    {
        QJsonObject object;
        object.insert(QStringLiteral("preset"), m_themePreset);
        object.insert(QStringLiteral("accent"), m_themeAccent);
        object.insert(QStringLiteral("accent2"), m_themeAccent2);
        object.insert(QStringLiteral("wallpaper"), m_themeWallpaper);
        object.insert(QStringLiteral("wallpaperDim"), m_themeWallpaperDim);
        object.insert(QStringLiteral("wallpaperFill"), m_themeWallpaperFill);
        object.insert(QStringLiteral("panel"), m_themePanel);
        object.insert(QStringLiteral("background"), m_themeBackground);
        object.insert(QStringLiteral("surface"), m_themeSurface);
        object.insert(QStringLiteral("text"), m_themeText);
        object.insert(QStringLiteral("muted"), m_themeMuted);
        object.insert(QStringLiteral("border"), m_themeBorder);
        object.insert(QStringLiteral("radius"), m_themeRadius);
        object.insert(QStringLiteral("glass"), m_themeGlass);
        return object;
    }

    void persistTheme()
    {
        writeJsonObject(themeConfigPath(), currentTheme());

        QSettings win8(win8SettingsPath(), QSettings::IniFormat);
        win8.beginGroup(QStringLiteral("Colors"));
        win8.setValue(QStringLiteral("Background"), m_themeBackground);
        win8.setValue(QStringLiteral("Tile"), m_themePanel);
        win8.setValue(QStringLiteral("TileHighlight"), m_themeAccent);
        win8.setValue(QStringLiteral("Panel"), m_themePanel);
        win8.setValue(QStringLiteral("Surface"), m_themeSurface);
        win8.setValue(QStringLiteral("Text"), m_themeText);
        win8.setValue(QStringLiteral("Accent"), m_themeAccent);
        win8.setValue(QStringLiteral("Accent2"), m_themeAccent2);
        win8.endGroup();
        if (!m_themeWallpaper.isEmpty())
            win8.setValue(QStringLiteral("Wallpaper/Desktop"), m_themeWallpaper);

        const QString configHome =
            QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
        for (const QString &version : {QStringLiteral("gtk-3.0"),
                                       QStringLiteral("gtk-4.0")}) {
            const QString directory = configHome + QLatin1Char('/') + version;
            QDir().mkpath(directory);
            QFile css(directory + QStringLiteral("/gtk.css"));
            if (css.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
                css.write(QStringLiteral(
                              "@define-color accent_color %1;\n"
                              "@define-color accent_bg_color %1;\n"
                              "@define-color window_bg_color %2;\n"
                              "@define-color window_fg_color %4;\n"
                              "@define-color headerbar_bg_color %3;\n"
                              "@define-color headerbar_fg_color %4;\n"
                              "@define-color card_bg_color %5;\n"
                              "window { background-color: %2; color: %4; }\n"
                              "headerbar { background: %3; color: %4; }\n")
                              .arg(m_themeAccent, m_themeBackground, m_themePanel,
                                   m_themeText, m_themeSurface)
                              .toUtf8());
            }
        }

        const QString labwcDir = configHome + QStringLiteral("/labwc");
        QDir().mkpath(labwcDir);
        QFile themerc(labwcDir + QStringLiteral("/themerc-override"));
        if (themerc.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            themerc.write(QStringLiteral(
                              "window.active.border.color: %1\n"
                              "window.inactive.border.color: %2\n"
                              "window.active.title.bg.color: %2\n"
                              "window.inactive.title.bg.color: %3\n"
                              "window.active.label.text.color: %4\n"
                              "window.inactive.label.text.color: %4\n"
                              "window.active.button.unpressed.image.color: %4\n"
                              "window.inactive.button.unpressed.image.color: %4\n"
                              "menu.items.bg.color: %3\n"
                              "menu.items.text.color: %4\n"
                              "menu.items.active.bg.color: %1\n"
                              "menu.items.active.text.color: %3\n"
                              "menu.title.bg.color: %2\n"
                              "menu.title.text.color: %4\n"
                              "menu.border.color: %2\n"
                              "menu.separator.color: %2\n"
                              "osd.bg.color: %3\n"
                              "osd.border.color: %1\n"
                              "osd.label.text.color: %4\n")
                              .arg(m_themeAccent, m_themePanel,
                                   m_themeBackground, m_themeText)
                              .toUtf8());
        }
        QProcess::startDetached(QStringLiteral("pkill"),
                                {QStringLiteral("-HUP"), QStringLiteral("labwc")});
        QProcess::startDetached(QStringLiteral("pkill"),
                                {QStringLiteral("-x"), QStringLiteral("Win8Running")});
        QTimer::singleShot(900, []() {
            QProcess::startDetached(QStringLiteral("Win8Running"), {},
                                    QDir::homePath());
        });
    }

    bool readWaydroidAutostart() const
    {
        QFile file(configPath(QStringLiteral("waydroid.conf")));
        if (!file.open(QIODevice::ReadOnly))
            return false;
        for (const QString &line : QString::fromUtf8(file.readAll()).split(QLatin1Char('\n'))) {
            const QString trimmed = line.trimmed();
            if (trimmed == QStringLiteral("autostart=true"))
                return true;
        }
        return false;
    }

    void loadAccessibility()
    {
        const QJsonObject object = readJsonObject(accessibilityConfigPath());
        m_largeText = object.value(QStringLiteral("largeText")).toBool(false);
        m_cursorSize =
            qBound(16, object.value(QStringLiteral("cursorSize")).toInt(24), 64);
        m_waydroidAutostart = readWaydroidAutostart();
        emit changed();
    }

    void applyAccessibility()
    {
        const QString configHome =
            QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
        for (const QString &version : {QStringLiteral("gtk-3.0"),
                                       QStringLiteral("gtk-4.0")}) {
            const QString directory = configHome + QLatin1Char('/') + version;
            QDir().mkpath(directory);
            QSettings settings(directory + QStringLiteral("/settings.ini"),
                               QSettings::IniFormat);
            settings.setValue(QStringLiteral("gtk-font-name"),
                              m_largeText ? QStringLiteral("Noto Sans 13")
                                          : QStringLiteral("Noto Sans 11"));
            settings.setValue(QStringLiteral("gtk-cursor-theme-size"), m_cursorSize);
            settings.sync();
        }
        const QString envDir = configHome + QStringLiteral("/environment.d");
        QDir().mkpath(envDir);
        QFile env(envDir + QStringLiteral("/99-elvonos-accessibility.conf"));
        if (env.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            if (m_largeText)
                env.write("QT_SCALE_FACTOR=1.15\nGDK_DPI_SCALE=1.15\n");
            env.write(QStringLiteral("XCURSOR_SIZE=%1\n").arg(m_cursorSize).toUtf8());
        }
    }

    void loadInputSettings()
    {
        const QJsonObject object = readJsonObject(inputConfigPath());
        m_mouseSpeed = qBound(-100, object.value(QStringLiteral("speed")).toInt(0), 100);
        m_naturalScroll = object.value(QStringLiteral("naturalScroll")).toBool(false);
        m_tapToClick = object.value(QStringLiteral("tapToClick")).toBool(true);
        m_leftHanded = object.value(QStringLiteral("leftHanded")).toBool(false);
        emit inputChanged();
    }

    void saveInputSettings() const
    {
        QJsonObject object;
        object.insert(QStringLiteral("speed"), m_mouseSpeed);
        object.insert(QStringLiteral("naturalScroll"), m_naturalScroll);
        object.insert(QStringLiteral("tapToClick"), m_tapToClick);
        object.insert(QStringLiteral("leftHanded"), m_leftHanded);
        writeJsonObject(inputConfigPath(), object);
    }

    void loadPowerSettings()
    {
        const QJsonObject object = readJsonObject(powerConfigPath());
        m_screenTimeout =
            qBound(0, object.value(QStringLiteral("screenTimeout")).toInt(5), 120);
        m_suspendTimeout =
            qBound(0, object.value(QStringLiteral("suspendTimeout")).toInt(0), 240);
        m_batteryPercent = -1;
        const QDir powerSupply(QStringLiteral("/sys/class/power_supply"));
        for (const QString &entry :
             powerSupply.entryList(QStringList() << QStringLiteral("BAT*"),
                                   QDir::Dirs | QDir::NoDotAndDotDot)) {
            const QString base = powerSupply.filePath(entry);
            const QString capacity = readText(base + QStringLiteral("/capacity")).trimmed();
            if (capacity.isEmpty())
                continue;
            m_batteryPercent = capacity.toInt();
            m_batteryCharging =
                readText(base + QStringLiteral("/status")).trimmed()
                    == QStringLiteral("Charging");
            break;
        }
        emit powerChanged();
    }

    void savePowerSettings() const
    {
        QJsonObject object;
        object.insert(QStringLiteral("screenTimeout"), m_screenTimeout);
        object.insert(QStringLiteral("suspendTimeout"), m_suspendTimeout);
        writeJsonObject(powerConfigPath(), object);
    }

    void applyPowerSettings()
    {
        const QString directory = QStandardPaths::writableLocation(
                                      QStandardPaths::GenericConfigLocation)
                                  + QStringLiteral("/swayidle");
        QDir().mkpath(directory);
        QFile file(directory + QStringLiteral("/config"));
        if (file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            if (m_screenTimeout > 0) {
                file.write(QStringLiteral("timeout %1 'elvonos-waydroid-lock'\n")
                               .arg(m_screenTimeout * 60).toUtf8());
                file.write(QStringLiteral(
                               "timeout %1 'elvonos-dpms off' resume 'elvonos-dpms on'\n")
                               .arg(m_screenTimeout * 60 + 60).toUtf8());
            }
            if (m_suspendTimeout > 0) {
                file.write(QStringLiteral("timeout %1 'systemctl suspend'\n")
                               .arg(m_suspendTimeout * 60).toUtf8());
            }
            file.write("before-sleep 'elvonos-waydroid-lock'\n");
        }
        runProgram(QStringLiteral("pkill"),
                   {QStringLiteral("-x"), QStringLiteral("swayidle")}, 3000);
        QProcess::startDetached(QStringLiteral("swayidle"),
                                {QStringLiteral("-w"), QStringLiteral("-C"),
                                 directory + QStringLiteral("/config")},
                                QDir::homePath());
        setStatus(true, QStringLiteral("Power settings applied"));
    }

    void loadNotifications()
    {
        m_notificationsEnabled =
            !runProgram(QStringLiteral("pgrep"),
                        {QStringLiteral("-x"), QStringLiteral("fnott")}, 3000)
                 .trimmed().isEmpty();
        emit changed();
    }

    void loadBluetooth()
    {
        const QString show =
            runProgram(QStringLiteral("bluetoothctl"), {QStringLiteral("show")}, 6000);
        m_bluetoothAvailable = show.contains(QStringLiteral("Controller "));
        m_bluetoothEnabled =
            m_bluetoothAvailable && show.contains(QStringLiteral("Powered: yes"));
        m_bluetoothDevices.clear();
        if (!m_bluetoothAvailable) {
            emit changed();
            return;
        }
        QStringList paired;
        const QString pairedOutput =
            runProgram(QStringLiteral("bluetoothctl"),
                       {QStringLiteral("devices"), QStringLiteral("Paired")}, 6000);
        for (const QString &line : pairedOutput.split(QLatin1Char('\n'))) {
            const QStringList parts = line.split(QLatin1Char(' '));
            if (parts.size() >= 2 && parts.at(0) == QStringLiteral("Device"))
                paired.append(parts.at(1));
        }
        QStringList connected;
        const QString connectedOutput =
            runProgram(QStringLiteral("bluetoothctl"),
                       {QStringLiteral("devices"), QStringLiteral("Connected")}, 6000);
        for (const QString &line : connectedOutput.split(QLatin1Char('\n'))) {
            const QStringList parts = line.split(QLatin1Char(' '));
            if (parts.size() >= 2 && parts.at(0) == QStringLiteral("Device"))
                connected.append(parts.at(1));
        }
        const QString devices =
            runProgram(QStringLiteral("bluetoothctl"), {QStringLiteral("devices")}, 6000);
        for (const QString &line : devices.split(QLatin1Char('\n'))) {
            const QString trimmed = line.trimmed();
            if (!trimmed.startsWith(QStringLiteral("Device ")))
                continue;
            const QString rest = trimmed.mid(7);
            const QString address = rest.section(QLatin1Char(' '), 0, 0);
            const QString name = rest.section(QLatin1Char(' '), 1).trimmed();
            QVariantMap device;
            device.insert(QStringLiteral("address"), address);
            device.insert(QStringLiteral("name"),
                          name.isEmpty() ? address : name);
            device.insert(QStringLiteral("paired"), paired.contains(address));
            device.insert(QStringLiteral("connected"), connected.contains(address));
            m_bluetoothDevices.append(device);
        }
        emit changed();
    }

    void loadPrinters()
    {
        m_printers.clear();
        m_defaultPrinter.clear();
        const QString defaultOutput =
            runProgram(QStringLiteral("lpstat"), {QStringLiteral("-d")}, 5000);
        const QRegularExpressionMatch defaultMatch =
            QRegularExpression(QStringLiteral("system default destination: (\\S+)"))
                .match(defaultOutput);
        if (defaultMatch.hasMatch())
            m_defaultPrinter = defaultMatch.captured(1);
        const QString output =
            runProgram(QStringLiteral("lpstat"), {QStringLiteral("-p")}, 5000);
        for (const QString &line : output.split(QLatin1Char('\n'))) {
            if (!line.startsWith(QStringLiteral("printer ")))
                continue;
            const QStringList parts = line.split(QLatin1Char(' '));
            if (parts.size() < 2)
                continue;
            QVariantMap printer;
            printer.insert(QStringLiteral("name"), parts.at(1));
            printer.insert(QStringLiteral("detail"), line.section(QLatin1Char(' '), 2));
            m_printers.append(printer);
        }
        emit changed();
    }

    void buildAppIndex()
    {
        if (!m_apps.isEmpty())
            return;
        const QStringList dirs = {
            QStringLiteral("/usr/share/applications"),
            QStringLiteral("/usr/local/share/applications"),
            QDir::homePath() + QStringLiteral("/.local/share/applications"),
            QStringLiteral("/var/lib/flatpak/exports/share/applications"),
        };
        QStringList seen;
        for (const QString &dir : dirs) {
            const QFileInfoList files = QDir(dir).entryInfoList(
                {QStringLiteral("*.desktop")}, QDir::Files | QDir::Readable, QDir::Name);
            for (const QFileInfo &file : files) {
                QSettings settings(file.absoluteFilePath(), QSettings::IniFormat);
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
                if (seen.contains(file.fileName()))
                    continue;
                seen.append(file.fileName());
                AppInfo info;
                info.id = file.fileName();
                info.name = name;
                info.exec = exec;
                info.icon = iconFor(settings.value(QStringLiteral("Desktop Entry/Icon"))
                                        .toString().trimmed());
                m_apps.append(info);
            }
        }
        std::sort(m_apps.begin(), m_apps.end(), [](const AppInfo &a, const AppInfo &b) {
            return a.name.toLower() < b.name.toLower();
        });
    }

    void loadApps()
    {
        loadInstalledApps();
        loadDefaultApps();
        loadAutostart();
    }

    void loadInstalledApps()
    {
        m_installedApps.clear();
        m_pathById.clear();
        QSet<QString> usedIds;

        const QString flatpaks =
            runProgram(QStringLiteral("flatpak"),
                       {QStringLiteral("list"), QStringLiteral("--app"),
                        QStringLiteral("--columns=application,name")}, 8000);
        for (const QString &line : flatpaks.split(QLatin1Char('\n'))) {
            if (line.trimmed().isEmpty())
                continue;
            const QStringList parts = line.split(QLatin1Char('\t'));
            QVariantMap item;
            item.insert(QStringLiteral("name"),
                        parts.size() > 1 ? parts.at(1) : parts.at(0));
            item.insert(QStringLiteral("id"), parts.at(0));
            item.insert(QStringLiteral("kind"), QStringLiteral("flatpak"));
            item.insert(QStringLiteral("detail"), QStringLiteral("Flatpak"));
            item.insert(QStringLiteral("removable"), true);
            m_installedApps.append(item);
            usedIds.insert(parts.at(0));
        }

        const QDir tracked(QStringLiteral("/var/lib/elvonos/installed-apps"));
        if (tracked.exists()) {
            const QFileInfoList files = tracked.entryInfoList(
                QDir::Files | QDir::Readable, QDir::Name);
            for (const QFileInfo &file : files) {
                QVariantMap item;
                item.insert(QStringLiteral("name"), file.fileName());
                item.insert(QStringLiteral("id"), file.fileName());
                item.insert(QStringLiteral("kind"), QStringLiteral("deb"));
                item.insert(QStringLiteral("detail"),
                            QStringLiteral("Debian package · ")
                                + readText(file.absoluteFilePath()).trimmed());
                item.insert(QStringLiteral("removable"), true);
                m_installedApps.append(item);
                usedIds.insert(file.fileName());
            }
        }

        auto sortInstalled = [this]() {
            std::sort(m_installedApps.begin(), m_installedApps.end(),
                      [](const QVariant &a, const QVariant &b) {
                          const QVariantMap left = a.toMap();
                          const QVariantMap right = b.toMap();
                          if (left.value(QStringLiteral("removable")).toBool()
                              != right.value(QStringLiteral("removable")).toBool())
                              return left.value(QStringLiteral("removable")).toBool();
                          return left.value(QStringLiteral("name")).toString().toLower()
                                 < right.value(QStringLiteral("name")).toString().toLower();
                      });
        };
        sortInstalled();
        emit changed();

        buildAppIndex();
        for (const AppInfo &app : m_apps) {
            const QString systemPath = QStringLiteral("/usr/share/applications/")
                                       + app.id;
            if (!QFileInfo::exists(systemPath))
                continue;
            QVariantMap item;
            item.insert(QStringLiteral("name"), app.name);
            item.insert(QStringLiteral("id"), app.id);
            item.insert(QStringLiteral("kind"), QStringLiteral("none"));
            item.insert(QStringLiteral("detail"),
                        QStringLiteral("System application"));
            item.insert(QStringLiteral("removable"), false);
            m_installedApps.append(item);
            m_pathById.insert(app.id, systemPath);
        }
        sortInstalled();
        emit changed();
        // Classify packages only after the inventory has been painted.
        QTimer::singleShot(1500, this, &SettingsApi::classifyInstalledApps);
    }

    void classifyInstalledApps()
    {
        const QString manual =
            runProgram(QStringLiteral("apt-mark"),
                       {QStringLiteral("showmanual")}, 10000);
        QSet<QString> manualPackages;
        for (const QString &line : manual.split(QLatin1Char('\n'))) {
            const QString package = line.trimmed();
            if (!package.isEmpty())
                manualPackages.insert(package);
        }

        QHash<QString, QString> ownership;
        const QString ownershipText =
            runProgram(QStringLiteral("/bin/sh"),
                       {QStringLiteral("-c"),
                        QStringLiteral(
                            "dpkg-query -S /usr/share/applications/*.desktop "
                            "/usr/local/share/applications/*.desktop "
                            "2>/dev/null")},
                       15000);
        for (const QString &line : ownershipText.split(QLatin1Char('\n'))) {
            const int separator = line.indexOf(QStringLiteral(": "));
            if (separator <= 0)
                continue;
            const QString package =
                line.left(separator).section(QLatin1Char(','), 0, 0).trimmed();
            const QStringList paths =
                line.mid(separator + 2).split(QStringLiteral(", "));
            for (const QString &path : paths)
                ownership.insert(path.trimmed(), package);
        }

        for (int i = 0; i < m_installedApps.size(); ++i) {
            QVariantMap item = m_installedApps.at(i).toMap();
            if (item.value(QStringLiteral("kind")).toString() != QStringLiteral("none"))
                continue;
            const QString path = m_pathById.value(item.value(QStringLiteral("id")).toString());
            const QString package = ownership.value(path);
            if (package.isEmpty())
                continue;
            item.insert(QStringLiteral("id"), package);
            item.insert(QStringLiteral("kind"), QStringLiteral("deb"));
            item.insert(QStringLiteral("detail"),
                        QStringLiteral("Debian package · ") + package);
            item.insert(QStringLiteral("removable"),
                        manualPackages.contains(package)
                            && !isProtectedPackage(package));
            m_installedApps[i] = item;
        }
        std::sort(m_installedApps.begin(), m_installedApps.end(),
                  [](const QVariant &a, const QVariant &b) {
                      const QVariantMap left = a.toMap();
                      const QVariantMap right = b.toMap();
                      if (left.value(QStringLiteral("removable")).toBool()
                          != right.value(QStringLiteral("removable")).toBool())
                          return left.value(QStringLiteral("removable")).toBool();
                      return left.value(QStringLiteral("name")).toString().toLower()
                             < right.value(QStringLiteral("name")).toString().toLower();
                  });
        emit changed();
    }

    static QString packageFor(const QString &path)
    {
        QProcess process;
        process.start(QStringLiteral("dpkg-query"),
                      {QStringLiteral("-S"), path});
        if (!process.waitForFinished(4000)) {
            process.kill();
            process.waitForFinished(1000);
            return {};
        }
        if (process.exitStatus() != QProcess::NormalExit
            || process.exitCode() != 0)
            return {};
        QString package = QString::fromUtf8(process.readAllStandardOutput())
                              .trimmed().section(QLatin1Char(':'), 0, 0).trimmed();
        if (package.contains(QLatin1Char(',')))
            package = package.section(QLatin1Char(','), 0, 0).trimmed();
        return package;
    }

    static bool isProtectedPackage(const QString &package)
    {
        static const QStringList protectedPrefixes = {
            QStringLiteral("elvonos"), QStringLiteral("labwc"),
            QStringLiteral("thunar"), QStringLiteral("foot"),
            QStringLiteral("flatpak"), QStringLiteral("waybar"),
            QStringLiteral("greetd"), QStringLiteral("plymouth"),
            QStringLiteral("network-manager"), QStringLiteral("cups"),
            QStringLiteral("sane"), QStringLiteral("pipewire"),
            QStringLiteral("wireplumber"), QStringLiteral("xdg-desktop-portal"),
            QStringLiteral("polkit"), QStringLiteral("sudo"),
            QStringLiteral("systemd"), QStringLiteral("lib"),
            QStringLiteral("qt6"), QStringLiteral("gtk"),
            QStringLiteral("waydroid"), QStringLiteral("lxc"),
            QStringLiteral("python3"), QStringLiteral("fonts-"),
            QStringLiteral("adwaita"), QStringLiteral("papirus"),
            QStringLiteral("mesa"), QStringLiteral("gstreamer"),
            QStringLiteral("linux-"), QStringLiteral("bash"),
            QStringLiteral("coreutils"), QStringLiteral("util-linux"),
            QStringLiteral("dbus"), QStringLiteral("wget"),
            QStringLiteral("curl"), QStringLiteral("sway"),
            QStringLiteral("wayland"), QStringLiteral("xwayland"),
            QStringLiteral("fontconfig"), QStringLiteral("webkit"),
            QStringLiteral("electron"),
        };
        for (const QString &prefix : protectedPrefixes) {
            if (package == prefix || package.startsWith(prefix))
                return true;
        }
        return false;
    }

    void loadDefaultApps()
    {
        struct Category {
            const char *mime;
            const char *label;
        };
        static const Category categories[] = {
            {"x-scheme-handler/http", "Web browser"},
            {"x-scheme-handler/mailto", "Email"},
            {"inode/directory", "File manager"},
            {"text/plain", "Text editor"},
            {"image/png", "Image viewer"},
            {"video/mp4", "Video player"},
            {"audio/mpeg", "Audio player"},
            {"application/pdf", "PDF viewer"},
            {"application/zip", "Archive manager"},
            {"application/x-ms-dos-executable", "Windows applications"},
        };
        buildAppIndex();
        m_defaultApps.clear();
        for (const Category &category : categories) {
            const QString mime = QString::fromLatin1(category.mime);
            const QString current =
                runProgram(QStringLiteral("xdg-mime"),
                           {QStringLiteral("query"), QStringLiteral("default"), mime},
                           5000).trimmed();
            QVariantList choices;
            for (const AppInfo &app : m_apps) {
                QVariantMap choice;
                choice.insert(QStringLiteral("id"), app.id);
                choice.insert(QStringLiteral("name"), app.name);
                choices.append(choice);
            }
            QVariantMap entry;
            entry.insert(QStringLiteral("mime"), mime);
            entry.insert(QStringLiteral("label"), QString::fromLatin1(category.label));
            entry.insert(QStringLiteral("current"), current);
            entry.insert(QStringLiteral("choices"), choices);
            m_defaultApps.append(entry);
        }
        emit changed();
    }

    void loadAutostart()
    {
        m_autostartEntries.clear();
        const QString directory =
            QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
            + QStringLiteral("/autostart");
        QDir().mkpath(directory);
        const QFileInfoList files = QDir(directory).entryInfoList(
            {QStringLiteral("*.desktop")}, QDir::Files | QDir::Readable, QDir::Name);
        for (const QFileInfo &file : files) {
            QSettings settings(file.absoluteFilePath(), QSettings::IniFormat);
            settings.beginGroup(QStringLiteral("Desktop Entry"));
            QVariantMap item;
            item.insert(QStringLiteral("name"),
                        settings.value(QStringLiteral("Name"), file.completeBaseName())
                            .toString());
            item.insert(QStringLiteral("path"), file.absoluteFilePath());
            item.insert(QStringLiteral("detail"),
                        settings.value(QStringLiteral("Exec")).toString());
            const bool hidden = settings.value(QStringLiteral("Hidden"), false).toBool();
            const bool enabled =
                !hidden && settings.value(QStringLiteral("X-GNOME-Autostart-enabled"), true)
                               .toBool();
            item.insert(QStringLiteral("enabled"), enabled);
            m_autostartEntries.append(item);
        }
        emit changed();
    }

    void loadWallpapers()
    {
        m_wallpapers.clear();
        QStringList paths;
        const QDir systemDir(QStringLiteral("/usr/share/backgrounds/elvonos"));
        for (const QFileInfo &file : systemDir.entryInfoList(QDir::Files, QDir::Name)) {
            if (file.fileName().startsWith(QStringLiteral("glass-")))
                continue;
            const QString suffix = file.suffix().toLower();
            if (suffix == QStringLiteral("png") || suffix == QStringLiteral("jpg")
                || suffix == QStringLiteral("jpeg") || suffix == QStringLiteral("webp"))
                paths.append(file.absoluteFilePath());
        }
        const QDir pictures(QStandardPaths::writableLocation(
            QStandardPaths::PicturesLocation));
        for (const QFileInfo &file : pictures.entryInfoList(QDir::Files, QDir::Name)) {
            const QString suffix = file.suffix().toLower();
            if (suffix == QStringLiteral("png") || suffix == QStringLiteral("jpg")
                || suffix == QStringLiteral("jpeg") || suffix == QStringLiteral("webp"))
                paths.append(file.absoluteFilePath());
        }
        for (const QString &path : paths) {
            QVariantMap item;
            item.insert(QStringLiteral("name"), QFileInfo(path).fileName());
            item.insert(QStringLiteral("path"), path);
            m_wallpapers.append(item);
        }
        QSettings settings(win8SettingsPath(), QSettings::IniFormat);
        m_wallpaperPath = settings.value(QStringLiteral("Wallpaper/Desktop")).toString();
        loadPanels();
        loadThemeSettings();
        emit changed();
    }

    void loadTime()
    {
        m_currentTimezone = runProgram(QStringLiteral("timedatectl"),
                                       {QStringLiteral("show"), QStringLiteral("-p"),
                                        QStringLiteral("Timezone"), QStringLiteral("--value")},
                                       5000).trimmed();
        if (m_currentTimezone.isEmpty())
            m_currentTimezone = readText(QStringLiteral("/etc/timezone")).trimmed();
        const QString status = runProgram(QStringLiteral("localectl"),
                                          {QStringLiteral("status")}, 5000);
        m_currentLocale = firstMatch(status,
                                     QRegularExpression(QStringLiteral(
                                         "System Locale:\\s*LANG=([^\\s]+)")));
        if (m_currentLocale.isEmpty())
            m_currentLocale = QString::fromLocal8Bit(qgetenv("LANG"));
        if (m_currentLocale.isEmpty())
            m_currentLocale = QStringLiteral("C.UTF-8");

        m_ntpEnabled = runProgram(QStringLiteral("timedatectl"),
                                  {QStringLiteral("show"), QStringLiteral("-p"),
                                   QStringLiteral("NTP"), QStringLiteral("--value")},
                                  5000).trimmed() == QStringLiteral("yes");
        const QString keyboardFile =
            QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
            + QStringLiteral("/environment.d/99-elvonos-keyboard.conf");
        m_keyboardLayout = firstMatch(
            readText(keyboardFile),
            QRegularExpression(QStringLiteral("XKB_DEFAULT_LAYOUT=(\\w+)")));
        if (m_keyboardLayout.isEmpty())
            m_keyboardLayout = QStringLiteral("us");

        m_timezones.clear();
        const QString zoneTab = readText(QStringLiteral("/usr/share/zoneinfo/zone.tab"));
        QStringList zones;
        for (const QString &line : zoneTab.split(QLatin1Char('\n'))) {
            if (line.startsWith(QLatin1Char('#')) || line.trimmed().isEmpty())
                continue;
            const QStringList parts = line.split(QLatin1Char('\t'));
            if (parts.size() >= 3)
                zones.append(parts.at(2));
        }
        zones.append(QStringLiteral("UTC"));
        zones.removeDuplicates();
        zones.sort();
        for (const QString &zone : zones) {
            QVariantMap item;
            item.insert(QStringLiteral("name"), zone);
            m_timezones.append(item);
        }

        m_locales.clear();
        const QString localeOutput = runProgram(QStringLiteral("locale"),
                                               {QStringLiteral("-a")}, 5000);
        QStringList localeNames;
        for (const QString &line : localeOutput.split(QLatin1Char('\n'))) {
            const QString name = line.trimmed();
            if (name.isEmpty())
                continue;
            if (!name.contains(QStringLiteral("utf"), Qt::CaseInsensitive)
                && name != QStringLiteral("C") && name != QStringLiteral("POSIX"))
                continue;
            QString normalized = name;
            normalized.replace(QStringLiteral(".utf8"), QStringLiteral(".UTF-8"));
            normalized.replace(QStringLiteral(".UTF8"), QStringLiteral(".UTF-8"));
            localeNames.append(normalized);
        }
        localeNames.removeDuplicates();
        localeNames.sort();
        for (const QString &name : localeNames) {
            QVariantMap item;
            item.insert(QStringLiteral("name"), name);
            m_locales.append(item);
        }
        emit changed();
    }

    void loadGaming()
    {
        const QString output = runProgram(gamingScript(),
                                          {QStringLiteral("status")}, 15000);
        const QJsonDocument document = QJsonDocument::fromJson(output.toUtf8());
        if (document.isObject())
            m_gamingStatus = document.object().toVariantMap();
        m_gamingStatus.insert(QStringLiteral("handlerActive"),
                              m_gamingStatus.value(QStringLiteral("handler")).toString()
                                  == QStringLiteral("elvonos-wine.desktop"));
        emit changed();
    }

    void loadPrivacy()
    {
        m_privacyRecent = QFileInfo::exists(
            QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
            + QStringLiteral("/recently-used.xbel"));
    }

    void loadUpdates()
    {
        QFile file(QStringLiteral("/etc/elvonos-release"));
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            for (const QString &line :
                 QString::fromUtf8(file.readAll()).split(QLatin1Char('\n'))) {
                if (line.startsWith(QStringLiteral("VERSION="))) {
                    m_elvonosVersion = line.mid(8).trimmed();
                }
            }
        }
        if (m_elvonosVersion.isEmpty())
            m_elvonosVersion = QStringLiteral("1.0.0");
        emit changed();
    }

    void loadBackups()
    {
        m_backups.clear();
        const QDir directory(backupDir());
        const QFileInfoList files = directory.entryInfoList(
            {QStringLiteral("*.tar.gz")}, QDir::Files | QDir::Readable,
            QDir::Time);
        for (const QFileInfo &file : files) {
            QVariantMap item;
            item.insert(QStringLiteral("name"), file.fileName());
            item.insert(QStringLiteral("path"), file.absoluteFilePath());
            item.insert(QStringLiteral("size"), humanSize(file.size()));
            item.insert(QStringLiteral("date"),
                        file.lastModified().toString(QStringLiteral("yyyy-MM-dd HH:mm")));
            m_backups.append(item);
        }
        emit changed();
    }

    /* ---------------- helper actions ---------------- */

    void refreshTune()
    {
        if (m_busy)
            return;
        const QString output =
            runProgram(QStringLiteral("sudo"),
                       {QStringLiteral("-n"), QStringLiteral("elvonos-tune"),
                        QStringLiteral("status")},
                       8000);
        const QJsonDocument document = QJsonDocument::fromJson(output.toUtf8());
        if (!document.isObject())
            return;
        const QJsonObject object = document.object();
        const QString profile = object.value(QStringLiteral("profile")).toString();
        const bool zram = object.value(QStringLiteral("zram")).toBool();
        const bool firewall = object.value(QStringLiteral("firewall")).toBool();
        bool changedAny = false;
        if (profile != m_profile) {
            m_profile = profile;
            changedAny = true;
        }
        if (zram != m_zram) {
            m_zram = zram;
            changedAny = true;
        }
        if (firewall != m_firewallOn) {
            m_firewallOn = firewall;
            changedAny = true;
        }
        if (changedAny)
            emit changed();
    }

    void runTune(const QStringList &arguments, const QString &busyText)
    {
        if (m_busy)
            return;
        setBusy(true);
        setStatus(true, busyText);
        int exitCode = 0;
        const QString output =
            runProgram(QStringLiteral("sudo"),
                       QStringList{QStringLiteral("-n"), QStringLiteral("elvonos-tune")}
                           + arguments,
                       60000, &exitCode);
        appendLog(output);
        setBusy(false);
        setStatus(exitCode == 0, exitCode == 0 ? QStringLiteral("Applied")
                                               : QStringLiteral("Action failed (see log)"));
        refreshTune();
        emit changed();
    }

    QString gamingScript() const
    {
        const QString found = QStandardPaths::findExecutable(
            QStringLiteral("elvonos-gaming-setup"));
        return found.isEmpty() ? QStringLiteral("/usr/bin/elvonos-gaming-setup")
                               : found;
    }

    QString win8SettingsPath() const
    {
        return QStandardPaths::writableLocation(QStandardPaths::ConfigLocation)
               + QStringLiteral("/Win8Settings/settings.ini");
    }

    static QString configPath(const QString &name)
    {
        return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
               + QStringLiteral("/elvonos/") + name;
    }

    QString taskbarConfigPath() const { return configPath(QStringLiteral("taskbar.json")); }
    QString panelsConfigPath() const { return configPath(QStringLiteral("panels.json")); }
    QString inputConfigPath() const { return configPath(QStringLiteral("input.json")); }
    QString powerConfigPath() const { return configPath(QStringLiteral("power.json")); }
    QString formFactorConfigPath() const
    {
        return configPath(QStringLiteral("formfactor.json"));
    }
    QString accessibilityConfigPath() const
    {
        return configPath(QStringLiteral("accessibility.json"));
    }
    QString themeConfigPath() const { return configPath(QStringLiteral("theme.json")); }

    static QJsonObject readJsonObject(const QString &path)
    {
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly))
            return {};
        return QJsonDocument::fromJson(file.readAll()).object();
    }

    static void writeJsonObject(const QString &path, const QJsonObject &object)
    {
        QDir().mkpath(QFileInfo(path).absolutePath());
        QFile file(path);
        if (file.open(QIODevice::WriteOnly | QIODevice::Truncate))
            file.write(QJsonDocument(object).toJson(QJsonDocument::Indented));
    }

    QString backupDir() const
    {
        return QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation)
               + QStringLiteral("/Backups");
    }

    static QString runProgram(const QString &program, const QStringList &arguments,
                              int timeoutMs = 15000, int *exitCode = nullptr)
    {
        QProcess process;
        process.setProcessChannelMode(QProcess::MergedChannels);
        process.start(program, arguments);
        if (!process.waitForFinished(timeoutMs)) {
            process.kill();
            process.waitForFinished(1000);
            if (exitCode)
                *exitCode = -1;
            return QStringLiteral("Timed out: ") + program;
        }
        if (exitCode)
            *exitCode = process.exitStatus() == QProcess::NormalExit
                            ? process.exitCode() : -1;
        return QString::fromUtf8(process.readAll());
    }

    static bool launchFirst(const QStringList &candidates)
    {
        for (const QString &candidate : candidates) {
            const QString executable = QStandardPaths::findExecutable(candidate);
            if (!executable.isEmpty())
                return QProcess::startDetached(executable, {});
        }
        return false;
    }

    static void openExternal(const QString &path)
    {
        const QString opener = QStandardPaths::findExecutable(QStringLiteral("xdg-open"));
        if (!opener.isEmpty())
            QProcess::startDetached(opener, {path});
    }

    void appendLog(const QString &text)
    {
        const QString trimmed = text.trimmed();
        if (trimmed.isEmpty())
            return;
        m_log += trimmed + QLatin1Char('\n');
        if (m_log.size() > 18000)
            m_log = m_log.right(16000);
        emit logChanged();
    }

    QString translateStatus(const QString &message) const
    {
        if (!m_lang)
            return message;
        const QString exact = m_lang->t(message);
        if (exact != message)
            return exact;
        static const QStringList templates = {
            QStringLiteral("%1 installation failed (see log)"),
            QStringLiteral("%1 installed"),
            QStringLiteral("%1 updates available"),
            QStringLiteral("Backup created: %1"),
            QStringLiteral("Backup verified · %1 entries"),
            QStringLiteral("Connected to %1"),
            QStringLiteral("Connecting to %1…"),
            QStringLiteral("Could not connect VPN %1"),
            QStringLiteral("Could not connect to %1"),
            QStringLiteral("Could not disconnect VPN %1"),
            QStringLiteral("Could not remove %1"),
            QStringLiteral("Default input: %1"),
            QStringLiteral("Default output: %1"),
            QStringLiteral("Disconnected %1"),
            QStringLiteral("Hostname set to %1"),
            QStringLiteral("Hotspot %1 is active"),
            QStringLiteral("Installing %1…"),
            QStringLiteral("Keyboard layout set to %1 (applies to new sessions)"),
            QStringLiteral("Language set to %1"),
            QStringLiteral("Removed %1"),
            QStringLiteral("Starting hotspot %1…"),
            QStringLiteral("Test page sent to %1"),
            QStringLiteral("Theme exported to %1"),
            QStringLiteral("Timezone set to %1"),
            QStringLiteral("VPN %1 connected"),
            QStringLiteral("VPN %1 disconnected"),
        };
        for (const QString &templateText : templates) {
            QString pattern = QRegularExpression::escape(templateText);
            pattern.replace(QStringLiteral("%1"), QStringLiteral("(.+)"));
            const QRegularExpression expression(QLatin1Char('^') + pattern
                                                + QLatin1Char('$'));
            const QRegularExpressionMatch match = expression.match(message);
            if (!match.hasMatch())
                continue;
            const QString translated = m_lang->t(templateText);
            if (translated == templateText)
                return message;
            QString result = translated;
            result.replace(QStringLiteral("%1"), match.captured(1));
            return result;
        }
        return message;
    }

    void setStatus(bool ok, const QString &message)
    {
        Q_UNUSED(ok)
        m_status = translateStatus(message);
        emit statusChanged();
    }

    void setBusy(bool busy)
    {
        if (m_busy == busy)
            return;
        m_busy = busy;
        emit busyChanged();
    }

    QVariantList m_systemInfo;
    QVariantList m_networkInfo;
    QVariantList m_deviceInfo;
    QVariantList m_installedApps;
    QVariantList m_defaultApps;
    QVariantList m_autostartEntries;
    QVariantList m_wallpapers;
    QVariantList m_timezones;
    QVariantList m_locales;
    QVariantList m_updates;
    QVariantList m_backups;
    QString m_profile = QStringLiteral("balanced");
    bool m_zram = true;
    bool m_firewallOn = false;
    QString m_firewallRules;
    QString m_currentTimezone;
    QString m_currentLocale;
    QVariantMap m_gamingStatus;
    QString m_wallpaperPath;
    bool m_wifiEnabled = false;
    bool m_networkingEnabled = true;
    QVariantList m_wifiNetworks;
    QVariantList m_audioSinks;
    QVariantList m_audioSources;
    QString m_defaultSink;
    QString m_defaultSource;
    int m_sinkVolume = 0;
    bool m_sinkMuted = false;
    int m_sourceVolume = 0;
    bool m_sourceMuted = false;
    QVariantList m_displayOutputs;
    bool m_ntpEnabled = true;
    QString m_keyboardLayout = QStringLiteral("us");
    QString m_hostname;
    QString m_taskbarPosition = QStringLiteral("top");
    QString m_dockPosition = QStringLiteral("bottom");
    int m_taskbarHeight = 54;
    QVariantList m_vpnConnections;
    bool m_flightMode = false;
    bool m_hotspotActive = false;
    bool m_bluetoothAvailable = false;
    bool m_bluetoothEnabled = false;
    QVariantList m_bluetoothDevices;
    int m_mouseSpeed = 0;
    bool m_naturalScroll = false;
    bool m_tapToClick = true;
    bool m_leftHanded = false;
    int m_screenTimeout = 5;
    int m_suspendTimeout = 0;
    int m_batteryPercent = -1;
    bool m_batteryCharging = false;
    QVariantList m_printers;
    QString m_defaultPrinter;
    bool m_notificationsEnabled = false;
    QString m_themePreset = QStringLiteral("aero");
    QString m_themeAccent = QStringLiteral("#8FD3FF");
    QString m_themeAccent2 = QStringLiteral("#4CC2FF");
    QString m_themeWallpaper;
    int m_themeWallpaperDim = 45;
    QString m_themeWallpaperFill = QStringLiteral("fill");
    QString m_themePanel = QStringLiteral("#15151C");
    QString m_themeBackground = QStringLiteral("#101016");
    QString m_themeSurface = QStringLiteral("#1B1B26");
    QString m_themeText = QStringLiteral("#E9ECF2");
    QString m_themeMuted = QStringLiteral("#8B93A1");
    QString m_formFactor = QStringLiteral("pc");
    QString m_formFactorMode = QStringLiteral("auto");
    QString m_formFactorInfo;
    double m_formFactorScale = 1.0;
    bool m_touchMode = false;
    QString m_storageInfo;
    bool m_largeText = false;
    int m_cursorSize = 24;
    QString m_dnsServers;
    bool m_waydroidRunning = false;
    int m_waydroidApps = 0;
    QVariantList m_waydroidAppList;
    QVariantList m_soundEvents;
    bool m_metroApps = false;
    QString m_elvonosVersion;
    QString m_elvonosLatest;
    bool m_elvonosUpdateAvailable = false;
    int m_elvonosOsUpdates = 0;
    int m_elvonosComponentUpdates = 0;
    QString m_elvonosComponentList;
    bool m_elvonosBusy = false;
    QString m_elvonosLog;
    bool m_elvonosIsoAvailable = false;
    QString m_elvonosCheckedAt;
    QProcess *m_elvonosProcess = nullptr;
    bool m_waydroidAutostart = false;
    bool m_waydroidBridge = false;
    bool m_waydroidMultiwindow = true;
    qint64 m_waydroidStorageUsed = 0;
    qint64 m_waydroidStorageFree = 0;
    qint64 m_waydroidStorageTotal = 0;
    QProcess *m_waydroidProcess = nullptr;
    QProcess *m_waydroidAppsProcess = nullptr;
    QProcess *m_waydroidStorageProcess = nullptr;
    QString m_themeBorder = QStringLiteral("#FFFFFF");
    int m_themeRadius = 14;
    int m_themeGlass = 78;
    Lang *m_lang = nullptr;
    QString m_log;
    QString m_status = QStringLiteral("Ready");
    bool m_busy = false;
    bool m_privacyRecent = false;
    QList<AppInfo> m_apps;
    QHash<QString, QString> m_pathById;
    QTimer m_timer;
};

int main(int argc, char *argv[])
{
    qputenv("QT_QUICK_BACKEND", "software");

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("elvonos-settings"));
    app.setDesktopFileName(QStringLiteral("elvonos-settings"));

    SettingsApi settings;
    Lang language;
    settings.setLang(&language);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("settings"), &settings);
    engine.rootContext()->setContextProperty(QStringLiteral("Lang"), &language);
    engine.load(QUrl(QStringLiteral("qrc:/Settings.qml")));
    if (engine.rootObjects().isEmpty())
        return 1;

    QTimer::singleShot(0, &settings, [&settings]() {
        settings.loadSection(QStringLiteral("system"));
    });

    const QString section = qEnvironmentVariable("ELVONOS_SETTINGS_SECTION");
    if (!section.isEmpty()) {
        static const QStringList keys = {
            QStringLiteral("system"), QStringLiteral("network"),
            QStringLiteral("devices"), QStringLiteral("apps"),
            QStringLiteral("design"), QStringLiteral("time"),
            QStringLiteral("gaming"), QStringLiteral("firewall"),
            QStringLiteral("privacy"), QStringLiteral("updates"),
            QStringLiteral("backups"),
        };
        const int index = keys.indexOf(section);
        if (index >= 0) {
            engine.rootObjects().first()->setProperty("section", index);
            engine.rootObjects().first()->setProperty("selectedSection", index);
        }
        QTimer::singleShot(2200, &settings, [&settings, section]() {
            settings.loadSection(section);
        });
    }
    const QString action = qEnvironmentVariable("ELVONOS_SETTINGS_ACTION");
    if (!action.isEmpty()) {
        QTimer::singleShot(2500, &settings, [&settings, action]() {
            if (action == QStringLiteral("backup"))
                settings.createBackup();
            else if (action == QStringLiteral("updates"))
                settings.checkUpdates();
            else if (action == QStringLiteral("firewall"))
                settings.loadFirewall();
            else if (action.startsWith(QStringLiteral("theme:")))
                settings.applyTheme(action.mid(6));
            else if (action.startsWith(QStringLiteral("theme-color:"))) {
                const QString rest = action.mid(12);
                const int colon = rest.indexOf(QLatin1Char(':'));
                if (colon > 0)
                    settings.setThemeColor(rest.left(colon), rest.mid(colon + 1));
            } else if (action.startsWith(QStringLiteral("theme-radius:"))) {
                settings.setThemeRadius(action.mid(13).toInt());
            } else if (action.startsWith(QStringLiteral("theme-glass:"))) {
                settings.setThemeGlass(action.mid(12).toInt());
            } else if (action.startsWith(QStringLiteral("formfactor:"))) {
                settings.setFormFactorMode(action.mid(11));
            } else if (action.startsWith(QStringLiteral("theme-wallpaper:"))) {
                settings.setThemeWallpaper(action.mid(16));
            } else if (action.startsWith(QStringLiteral("theme-dim:"))) {
                settings.setThemeWallpaperDim(action.mid(10).toInt());
            } else if (action.startsWith(QStringLiteral("theme-fill:"))) {
                settings.setThemeWallpaperFill(action.mid(11));
            } else if (action == QStringLiteral("theme-export")) {
                settings.exportTheme(QString());
            } else if (action == QStringLiteral("theme-import")) {
                settings.importTheme(
                    QStandardPaths::writableLocation(
                        QStandardPaths::DocumentsLocation)
                    + QStringLiteral("/ElvonOS-Theme.json"));
            }
            else if (action.startsWith(QStringLiteral("taskbar:")))
                settings.setTaskbarPosition(action.mid(8));
            else if (action.startsWith(QStringLiteral("dock:")))
                settings.setDockPosition(action.mid(5));
            else if (action == QStringLiteral("notification-test"))
                settings.sendTestNotification();
            else if (action == QStringLiteral("input-test")) {
                settings.setNaturalScroll(true);
                settings.setMouseSpeed(-30);
            } else if (action == QStringLiteral("power-test")) {
                settings.setScreenTimeout(2);
                settings.setSuspendTimeout(0);
            } else if (action == QStringLiteral("flight-on")) {
                settings.setFlightMode(true);
            } else if (action == QStringLiteral("flight-off")) {
                settings.setFlightMode(false);
            } else if (action == QStringLiteral("bt-scan")) {
                settings.scanBluetooth();
            } else if (action == QStringLiteral("printer-test")) {
                settings.testPrinter(QString());
            }
        });
    }

    return app.exec();
}

#include "main.moc"

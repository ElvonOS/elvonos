#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QTimer>
#include "../common/elvonapp.h"

class SettingsModel : public QObject {
    Q_OBJECT
    Q_PROPERTY(int height READ height WRITE setHeight NOTIFY heightChanged)
    Q_PROPERTY(bool groupDuplicates READ groupDuplicates WRITE setGroupDuplicates NOTIFY groupDuplicatesChanged)
    Q_PROPERTY(bool showTray READ showTray WRITE setShowTray NOTIFY showTrayChanged)
    Q_PROPERTY(bool showVolume READ showVolume WRITE setShowVolume NOTIFY showVolumeChanged)
    Q_PROPERTY(bool showNetwork READ showNetwork WRITE setShowNetwork NOTIFY showNetworkChanged)
    Q_PROPERTY(bool showBattery READ showBattery WRITE setShowBattery NOTIFY showBatteryChanged)
    Q_PROPERTY(bool showClock READ showClock WRITE setShowClock NOTIFY showClockChanged)
    Q_PROPERTY(bool showCount READ showCount WRITE setShowCount NOTIFY showCountChanged)
    Q_PROPERTY(bool showTitles READ showTitles WRITE setShowTitles NOTIFY showTitlesChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)

public:
    explicit SettingsModel(QObject *parent = nullptr)
        : QObject(parent)
    {
        m_path = QDir::homePath() + QStringLiteral("/.config/elvonos/taskbar.json");
        QDir().mkpath(QFileInfo(m_path).absolutePath());
        load();
    }

    int height() const { return m_height; }
    bool groupDuplicates() const { return m_groupDuplicates; }
    bool showTray() const { return m_showTray; }
    bool showVolume() const { return m_showVolume; }
    bool showNetwork() const { return m_showNetwork; }
    bool showBattery() const { return m_showBattery; }
    bool showClock() const { return m_showClock; }
    bool showCount() const { return m_showCount; }
    bool showTitles() const { return m_showTitles; }
    QString status() const { return appTr(m_status); }

    void setHeight(int height)
    {
        const int value = qBound(44, height, 72);
        if (value == m_height)
            return;
        m_height = value;
        emit heightChanged();
        save();
    }

    void setGroupDuplicates(bool value) { setBool(value, m_groupDuplicates, &SettingsModel::groupDuplicatesChanged); }
    void setShowTray(bool value) { setBool(value, m_showTray, &SettingsModel::showTrayChanged); }
    void setShowVolume(bool value) { setBool(value, m_showVolume, &SettingsModel::showVolumeChanged); }
    void setShowNetwork(bool value) { setBool(value, m_showNetwork, &SettingsModel::showNetworkChanged); }
    void setShowBattery(bool value) { setBool(value, m_showBattery, &SettingsModel::showBatteryChanged); }
    void setShowClock(bool value) { setBool(value, m_showClock, &SettingsModel::showClockChanged); }
    void setShowCount(bool value) { setBool(value, m_showCount, &SettingsModel::showCountChanged); }
    void setShowTitles(bool value) { setBool(value, m_showTitles, &SettingsModel::showTitlesChanged); }

    Q_INVOKABLE void resetDefaults()
    {
        m_height = 54;
        m_groupDuplicates = true;
        m_showTray = true;
        m_showVolume = true;
        m_showNetwork = true;
        m_showBattery = true;
        m_showClock = true;
        m_showCount = true;
        m_showTitles = true;
        emit heightChanged();
        emit groupDuplicatesChanged();
        emit showTrayChanged();
        emit showVolumeChanged();
        emit showNetworkChanged();
        emit showBatteryChanged();
        emit showClockChanged();
        emit showCountChanged();
        emit showTitlesChanged();
        save();
        m_status = appTr(QStringLiteral("Defaults restored"));
        emit statusChanged();
    }

signals:
    void heightChanged();
    void groupDuplicatesChanged();
    void showTrayChanged();
    void showVolumeChanged();
    void showNetworkChanged();
    void showBatteryChanged();
    void showClockChanged();
    void showCountChanged();
    void showTitlesChanged();
    void statusChanged();

private:
    void setBool(bool value, bool &member, void (SettingsModel::*signal)())
    {
        if (value == member)
            return;
        member = value;
        emit (this->*signal)();
        save();
    }

    void load()
    {
        QJsonObject object;
        QFile file(m_path);
        if (file.open(QIODevice::ReadOnly)) {
            object = QJsonDocument::fromJson(file.readAll()).object();
        }
        m_height = qBound(44, object.value(QStringLiteral("height")).toInt(54), 72);
        m_groupDuplicates = object.value(QStringLiteral("groupDuplicates")).toBool(true);
        m_showTray = object.value(QStringLiteral("showTray")).toBool(true);
        m_showVolume = object.value(QStringLiteral("showVolume")).toBool(true);
        m_showNetwork = object.value(QStringLiteral("showNetwork")).toBool(true);
        m_showBattery = object.value(QStringLiteral("showBattery")).toBool(true);
        m_showClock = object.value(QStringLiteral("showClock")).toBool(true);
        m_showCount = object.value(QStringLiteral("showCount")).toBool(true);
        m_showTitles = object.value(QStringLiteral("showTitles")).toBool(true);
        m_status = appTr(QStringLiteral("Changes are applied immediately"));
    }

    void save()
    {
        QJsonObject object;
        object.insert(QStringLiteral("height"), m_height);
        object.insert(QStringLiteral("groupDuplicates"), m_groupDuplicates);
        object.insert(QStringLiteral("showTray"), m_showTray);
        object.insert(QStringLiteral("showVolume"), m_showVolume);
        object.insert(QStringLiteral("showNetwork"), m_showNetwork);
        object.insert(QStringLiteral("showBattery"), m_showBattery);
        object.insert(QStringLiteral("showClock"), m_showClock);
        object.insert(QStringLiteral("showCount"), m_showCount);
        object.insert(QStringLiteral("showTitles"), m_showTitles);

        QFile file(m_path);
        if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            m_status = appTr(QStringLiteral("Could not write %1")).arg(m_path);
            emit statusChanged();
            return;
        }
        file.write(QJsonDocument(object).toJson(QJsonDocument::Indented));
        file.close();
        m_status = appTr(QStringLiteral("Saved · changes apply immediately"));
        emit statusChanged();
    }

    QString m_path;
    QString m_status;
    int m_height = 54;
    bool m_groupDuplicates = true;
    bool m_showTray = true;
    bool m_showVolume = true;
    bool m_showNetwork = true;
    bool m_showBattery = true;
    bool m_showClock = true;
    bool m_showCount = true;
    bool m_showTitles = true;
};

int main(int argc, char *argv[])
{
    qputenv("QT_QUICK_BACKEND", "software");

    QGuiApplication app(argc, argv);

    AppLang lang;
    AppTheme theme;
    appLangInstance() = &lang;
    app.setApplicationName(QStringLiteral("elvonos-taskbar-settings"));
    app.setDesktopFileName(QStringLiteral("elvonos-taskbar-settings"));

    SettingsModel settings;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("lang"), &lang);
    engine.rootContext()->setContextProperty(QStringLiteral("theme"), &theme);
    engine.rootContext()->setContextProperty(QStringLiteral("settings"), &settings);
    engine.load(QUrl(QStringLiteral("qrc:/TaskbarSettings.qml")));
    if (engine.rootObjects().isEmpty())
        return 1;
    return app.exec();
}

#include "main.moc"

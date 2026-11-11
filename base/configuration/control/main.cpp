#include <QDateTime>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>
#include <QVariantList>

#include <unistd.h>
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

} // namespace

class TuneApi : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString governor READ governor NOTIFY statusChanged)
    Q_PROPERTY(QVariantList governors READ governors NOTIFY statusChanged)
    Q_PROPERTY(QString profile READ profile NOTIFY statusChanged)
    Q_PROPERTY(bool zram READ zram NOTIFY statusChanged)
    Q_PROPERTY(QString zramText READ zramText NOTIFY statusChanged)
    Q_PROPERTY(int swappiness READ swappiness NOTIFY statusChanged)
    Q_PROPERTY(bool firewall READ firewall NOTIFY statusChanged)
    Q_PROPERTY(bool waydroidRunning READ waydroidRunning NOTIFY statusChanged)
    Q_PROPERTY(bool waydroidLimit READ waydroidLimit NOTIFY statusChanged)
    Q_PROPERTY(QString memoryText READ memoryText NOTIFY statusChanged)
    Q_PROPERTY(double memoryPercent READ memoryPercent NOTIFY statusChanged)
    Q_PROPERTY(QString swapText READ swapText NOTIFY statusChanged)
    Q_PROPERTY(double swapPercent READ swapPercent NOTIFY statusChanged)
    Q_PROPERTY(QString loadText READ loadText NOTIFY statusChanged)
    Q_PROPERTY(int cpuCount READ cpuCount NOTIFY statusChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString result READ result NOTIFY resultChanged)
    Q_PROPERTY(bool resultOk READ resultOk NOTIFY resultChanged)
    Q_PROPERTY(bool noiseProtection READ noiseProtection NOTIFY audioChanged)
    Q_PROPERTY(QString audioStatus READ audioStatus NOTIFY audioChanged)
    Q_PROPERTY(QString defaultSource READ defaultSource NOTIFY audioChanged)
    Q_PROPERTY(bool audioBusy READ audioBusy NOTIFY audioBusyChanged)

public:
    explicit TuneApi(QObject *parent = nullptr) : QObject(parent)
    {
        m_timer.setInterval(5000);
        connect(&m_timer, &QTimer::timeout, this, &TuneApi::refresh);
        m_timer.start();
        QTimer::singleShot(400, this, &TuneApi::refresh);
    }

    QString governor() const { return m_governor; }
    QVariantList governors() const { return m_governors; }
    QString profile() const { return m_profile; }
    bool zram() const { return m_zram; }
    QString zramText() const { return m_zramText; }
    int swappiness() const { return m_swappiness; }
    bool firewall() const { return m_firewall; }
    bool waydroidRunning() const { return m_waydroidRunning; }
    bool waydroidLimit() const { return m_waydroidLimit; }
    QString memoryText() const { return m_memoryText; }
    double memoryPercent() const { return m_memoryPercent; }
    QString swapText() const { return m_swapText; }
    double swapPercent() const { return m_swapPercent; }
    QString loadText() const { return m_loadText; }
    int cpuCount() const { return m_cpuCount; }
    bool busy() const { return m_busy; }
    QString result() const { return m_result; }
    bool resultOk() const { return m_resultOk; }
    bool noiseProtection() const { return m_noiseProtection; }
    QString audioStatus() const { return m_audioStatus; }
    QString defaultSource() const { return m_defaultSource; }
    bool audioBusy() const { return m_audioBusy; }

    Q_INVOKABLE void refresh()
    {
        if (m_busy)
            return;
        QProcess process;
        startHelper(process, {"status"});
        if (!process.waitForFinished(6000)) {
            process.kill();
            setResult(false, "Performance helper did not respond.");
            return;
        }
        const QJsonDocument document = QJsonDocument::fromJson(process.readAllStandardOutput());
        if (!document.isObject()) {
            setResult(false, "Performance helper unavailable.");
            return;
        }
        const QJsonObject object = document.object();
        m_governor = object.value("governor").toString("N/A");
        m_governors.clear();
        for (const QJsonValue &value : object.value("governors").toArray())
            m_governors.append(value.toString());
        m_profile = object.value("profile").toString("balanced");
        m_zram = object.value("zram").toBool();
        const qint64 zramSize = object.value("zramSize").toVariant().toLongLong();
        m_zramText = m_zram && zramSize > 0 ? humanSize(zramSize) : (m_zram ? "active" : "off");
        m_swappiness = object.value("swappiness").toInt();
        m_firewall = object.value("firewall").toBool();
        m_waydroidRunning = object.value("waydroidRunning").toBool();
        m_waydroidLimit = object.value("waydroidLimit").toBool();
        const qint64 memTotal = object.value("memTotal").toVariant().toLongLong();
        const qint64 memAvailable = object.value("memAvailable").toVariant().toLongLong();
        const qint64 swapTotal = object.value("swapTotal").toVariant().toLongLong();
        const qint64 swapFree = object.value("swapFree").toVariant().toLongLong();
        m_memoryText = humanSize(memTotal - memAvailable) + " / " + humanSize(memTotal);
        m_memoryPercent = memTotal > 0
                              ? double(memTotal - memAvailable) / double(memTotal) * 100.0
                              : 0.0;
        if (swapTotal > 0)
            m_swapText = humanSize(swapTotal - swapFree) + " / " + humanSize(swapTotal);
        else
            m_swapText = "no swap";
        m_swapPercent = swapTotal > 0
                            ? double(swapTotal - swapFree) / double(swapTotal) * 100.0
                            : 0.0;
        m_loadText = object.value("load").toString("—");
        m_cpuCount = object.value("cpuCount").toInt(1);
        emit statusChanged();
        refreshAudio();
    }

    Q_INVOKABLE void applyProfile(const QString &profile)
    {
        runAction({"profile", profile}, "Profile: " + profile);
    }

    Q_INVOKABLE void setZram(bool enabled)
    {
        runAction({"zram", enabled ? "on" : "off"},
                  enabled ? "Enabling ZRAM swap…" : "Disabling ZRAM swap…");
    }

    Q_INVOKABLE void setFirewall(bool enabled)
    {
        runAction({"firewall", enabled ? "on" : "off"},
                  enabled ? "Enabling firewall…" : "Disabling firewall…");
    }

    Q_INVOKABLE void setWaydroidLimit(bool enabled)
    {
        runAction({"waydroid-limit", enabled ? "on" : "off"},
                  enabled ? "Limiting Waydroid…" : "Removing Waydroid limit…");
    }

    Q_INVOKABLE void setNoiseProtection(bool enabled)
    {
        runAudioAction(enabled ? QStringLiteral("on") : QStringLiteral("off"),
                       enabled ? QStringLiteral("Enabling noise protection…")
                               : QStringLiteral("Disabling noise protection…"));
    }

    Q_INVOKABLE void restartAudio()
    {
        runAudioAction(QStringLiteral("restart"),
                       QStringLiteral("Restarting audio…"));
    }

    Q_INVOKABLE void quit() { QCoreApplication::quit(); }

signals:
    void statusChanged();
    void busyChanged();
    void resultChanged();
    void audioChanged();
    void audioBusyChanged();

private:
    QString helperPath() const
    {
        const QString override = qEnvironmentVariable("ELVONOS_TUNE_BIN");
        if (!override.isEmpty())
            return override;
        const QString found = QStandardPaths::findExecutable("elvonos-tune");
        return found.isEmpty() ? QStringLiteral("/usr/bin/elvonos-tune") : found;
    }

    void startHelper(QProcess &process, const QStringList &arguments) const
    {
        const QString helper = helperPath();
        if (geteuid() == 0) {
            process.start(helper, arguments);
        } else {
            process.start("sudo", QStringList{"-n", helper} + arguments);
        }
    }

    void runAction(const QStringList &arguments, const QString &busyText)
    {
        if (m_busy)
            return;
        setBusy(true);
        setResult(true, busyText);
        QProcess process;
        process.setProcessChannelMode(QProcess::MergedChannels);
        startHelper(process, arguments);
        if (!process.waitForFinished(30000)) {
            process.kill();
            setResult(false, "The action timed out.");
        } else {
            const QString text = QString::fromUtf8(process.readAll()).trimmed();
            const bool ok = process.exitStatus() == QProcess::NormalExit
                            && process.exitCode() == 0;
            setResult(ok, text.isEmpty()
                              ? (ok ? "Done." : "Action failed.")
                              : text);
        }
        setBusy(false);
        refresh();
    }

    QString audioHelperPath() const
    {
        const QString found = QStandardPaths::findExecutable(
            QStringLiteral("elvonos-audio-noise"));
        return found.isEmpty() ? QStringLiteral("/usr/bin/elvonos-audio-noise")
                               : found;
    }

    void refreshAudio()
    {
        QProcess status;
        status.start(audioHelperPath(), {QStringLiteral("status")});
        if (status.waitForFinished(2500)) {
            m_noiseProtection =
                QString::fromUtf8(status.readAllStandardOutput()).trimmed()
                == QStringLiteral("on");
        }
        QProcess source;
        source.start(QStringLiteral("pactl"),
                     {QStringLiteral("get-default-source")});
        if (source.waitForFinished(2000)) {
            const QString name =
                QString::fromUtf8(source.readAllStandardOutput()).trimmed();
            m_defaultSource = name.isEmpty() ? QStringLiteral("—") : name;
        } else {
            m_defaultSource = QStringLiteral("—");
        }
        m_audioStatus = m_noiseProtection
                            ? QStringLiteral("Noise protection active")
                            : QStringLiteral("Noise protection off");
        emit audioChanged();
    }

    void runAudioAction(const QString &action, const QString &busyText)
    {
        if (m_audioBusy)
            return;
        setAudioBusy(true);
        setResult(true, busyText);
        QProcess process;
        process.setProcessChannelMode(QProcess::MergedChannels);
        process.start(audioHelperPath(), {action});
        if (!process.waitForFinished(30000)) {
            process.kill();
            setResult(false, QStringLiteral("The audio action timed out."));
        } else {
            const QString text = QString::fromUtf8(process.readAll()).trimmed();
            const bool ok = process.exitStatus() == QProcess::NormalExit
                            && process.exitCode() == 0;
            setResult(ok, text.isEmpty()
                              ? (ok ? QStringLiteral("Done.")
                                    : QStringLiteral("Audio action failed."))
                              : text);
        }
        setAudioBusy(false);
        refreshAudio();
    }

    void setAudioBusy(bool value)
    {
        if (m_audioBusy == value)
            return;
        m_audioBusy = value;
        emit audioBusyChanged();
    }

    void setBusy(bool value)
    {
        if (m_busy == value)
            return;
        m_busy = value;
        emit busyChanged();
    }

    void setResult(bool ok, const QString &message)
    {
        m_result = message;
        m_resultOk = ok;
        emit resultChanged();
    }

    QTimer m_timer;
    QString m_governor = "N/A";
    QVariantList m_governors;
    QString m_profile = "balanced";
    bool m_zram = false;
    QString m_zramText = "off";
    int m_swappiness = 0;
    bool m_firewall = false;
    bool m_waydroidRunning = false;
    bool m_waydroidLimit = false;
    QString m_memoryText = "—";
    double m_memoryPercent = 0.0;
    QString m_swapText = "—";
    double m_swapPercent = 0.0;
    QString m_loadText = "—";
    int m_cpuCount = 1;
    bool m_busy = false;
    bool m_resultOk = true;
    QString m_result;
    bool m_noiseProtection = false;
    QString m_audioStatus = "Noise protection off";
    QString m_defaultSource = "—";
    bool m_audioBusy = false;
};

int main(int argc, char *argv[])
{
    /* Simple 2D UI: the software renderer avoids slow/one-shot GL first
     * frames on virtualised GPUs. */
    qputenv("QT_QUICK_BACKEND", "software");

    QGuiApplication app(argc, argv);

    AppLang lang;
    AppTheme theme;
    appLangInstance() = &lang;
    app.setApplicationName(QStringLiteral("elvonos-control"));
    app.setApplicationDisplayName(QStringLiteral("Control Center"));
    app.setDesktopFileName(QStringLiteral("elvonos-control"));

    TuneApi tune;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("lang"), &lang);
    engine.rootContext()->setContextProperty(QStringLiteral("theme"), &theme);
    engine.rootContext()->setContextProperty("tune", &tune);

    engine.load(QUrl("qrc:/Control.qml"));
    if (engine.rootObjects().isEmpty())
        return -1;
    if (qEnvironmentVariableIsSet("ELVONOS_CONTROL_TAB")) {
        const int tab = qEnvironmentVariableIntValue("ELVONOS_CONTROL_TAB");
        if (tab >= 0 && tab <= 2)
            engine.rootObjects().constFirst()->setProperty("tab", tab);
    }
    return app.exec();
}

#include "main.moc"

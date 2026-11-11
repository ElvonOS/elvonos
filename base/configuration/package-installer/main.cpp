#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QStandardPaths>
#include "../common/elvonapp.h"

class InstallerModel : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString filePath READ filePath NOTIFY fileChanged)
    Q_PROPERTY(QString fileName READ fileName NOTIFY fileChanged)
    Q_PROPERTY(QString kind READ kind NOTIFY fileChanged)
    Q_PROPERTY(QString sizeText READ sizeText NOTIFY fileChanged)
    Q_PROPERTY(QString packageName READ packageName NOTIFY fileChanged)
    Q_PROPERTY(QString packageVersion READ packageVersion NOTIFY fileChanged)
    Q_PROPERTY(QString description READ description NOTIFY fileChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(bool ok READ ok NOTIFY statusChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString log READ log NOTIFY logChanged)

public:
    explicit InstallerModel(QObject *parent = nullptr)
        : QObject(parent)
    {
    }

    QString filePath() const { return m_filePath; }
    QString fileName() const { return m_fileName; }
    QString kind() const { return m_kind; }
    QString sizeText() const { return m_sizeText; }
    QString packageName() const { return m_packageName; }
    QString packageVersion() const { return m_packageVersion; }
    QString description() const { return m_description; }
    QString status() const { return appTr(m_status); }
    bool ok() const { return m_ok; }
    bool busy() const { return m_busy; }
    QString log() const { return m_log; }

    Q_INVOKABLE void open(const QString &path)
    {
        const QFileInfo info(path);
        if (!info.exists() || !info.isFile()) {
            setStatus(false, appTr(QStringLiteral("File not found: %1")).arg(path));
            return;
        }
        m_filePath = info.absoluteFilePath();
        m_fileName = info.fileName();
        m_sizeText = humanSize(info.size());
        m_packageName.clear();
        m_packageVersion.clear();
        m_description.clear();
        m_log.clear();

        const QString lower = m_fileName.toLower();
        if (lower.endsWith(QStringLiteral(".deb"))) {
            m_kind = QStringLiteral("deb");
            QProcess process;
            process.start(QStringLiteral("dpkg-deb"),
                          {QStringLiteral("-f"), m_filePath,
                           QStringLiteral("Package"), QStringLiteral("Version"),
                           QStringLiteral("Description")});
            if (process.waitForFinished(10000)
                && process.exitStatus() == QProcess::NormalExit
                && process.exitCode() == 0) {
                const QStringList lines =
                    QString::fromUtf8(process.readAllStandardOutput())
                        .split(QLatin1Char('\n'));
                if (lines.size() > 0)
                    m_packageName = lines.at(0).trimmed();
                if (lines.size() > 1)
                    m_packageVersion = lines.at(1).trimmed();
                for (int i = 2; i < lines.size(); ++i) {
                    if (!lines.at(i).trimmed().isEmpty()) {
                        m_description = lines.at(i).trimmed();
                        break;
                    }
                }
            }
            setStatus(true, QStringLiteral("Debian package ready to install"));
        } else if (lower.endsWith(QStringLiteral(".appimage"))) {
            m_kind = QStringLiteral("appimage");
            m_description = QStringLiteral("Portable AppImage application");
            setStatus(true, QStringLiteral("AppImage ready to run"));
        } else {
            m_kind = QStringLiteral("unknown");
            setStatus(false, QStringLiteral("Unsupported file type"));
        }
        emit fileChanged();
    }

    Q_INVOKABLE void installDeb()
    {
        if (m_busy || m_kind != QStringLiteral("deb") || m_filePath.isEmpty())
            return;
        setBusy(true);
        setStatus(true, QStringLiteral("Installing…"));
        m_log = QStringLiteral("$ apt-get install ./%1\n").arg(m_fileName);
        emit logChanged();

        QProcess process;
        process.setProcessChannelMode(QProcess::MergedChannels);
        process.setWorkingDirectory(QFileInfo(m_filePath).absolutePath());
        process.start(QStringLiteral("sudo"),
                      {QStringLiteral("-n"), QStringLiteral("apt-get"),
                       QStringLiteral("install"), QStringLiteral("-y"),
                       QStringLiteral("./") + m_fileName});
        if (!process.waitForFinished(300000)) {
            process.kill();
            setBusy(false);
            setStatus(false, QStringLiteral("Installation timed out"));
            return;
        }
        m_log += QString::fromUtf8(process.readAll());
        emit logChanged();
        const bool success = process.exitStatus() == QProcess::NormalExit
                             && process.exitCode() == 0;
        if (success && !m_packageName.isEmpty()) {
            QProcess prepare;
            prepare.start(QStringLiteral("sudo"),
                          {QStringLiteral("-n"), QStringLiteral("mkdir"),
                           QStringLiteral("-p"),
                           QStringLiteral("/var/lib/elvonos/installed-apps")});
            prepare.waitForFinished(5000);

            QProcess marker;
            marker.start(QStringLiteral("sudo"),
                         {QStringLiteral("-n"), QStringLiteral("tee"),
                          QStringLiteral("/var/lib/elvonos/installed-apps/")
                              + m_packageName});
            if (marker.waitForStarted(3000)) {
                marker.write((m_packageVersion + QStringLiteral(" · ")
                              + m_description).toUtf8());
                marker.closeWriteChannel();
                marker.waitForFinished(5000);
            }
        }
        setBusy(false);
        setStatus(success,
                  success ? QStringLiteral("Package installed")
                          : QStringLiteral("Installation failed"));
    }

    Q_INVOKABLE void runAppImage()
    {
        if (m_filePath.isEmpty() || m_kind != QStringLiteral("appimage"))
            return;
        QFile file(m_filePath);
        if (!file.setPermissions(file.permissions()
                                 | QFileDevice::ExeOwner
                                 | QFileDevice::ExeGroup
                                 | QFileDevice::ExeOther)) {
            setStatus(false, QStringLiteral("Could not make the AppImage executable"));
            return;
        }
        if (!QProcess::startDetached(m_filePath, {}, QFileInfo(m_filePath).absolutePath())) {
            setStatus(false, QStringLiteral("Could not start the AppImage"));
            return;
        }
        setStatus(true, QStringLiteral("AppImage started"));
    }

    Q_INVOKABLE void openFolder()
    {
        if (m_filePath.isEmpty())
            return;
        QString opener = QStandardPaths::findExecutable(QStringLiteral("xdg-open"));
        if (opener.isEmpty())
            opener = QStandardPaths::findExecutable(QStringLiteral("thunar"));
        if (opener.isEmpty())
            return;
        QProcess::startDetached(opener, {QFileInfo(m_filePath).absolutePath()});
    }

signals:
    void fileChanged();
    void statusChanged();
    void busyChanged();
    void logChanged();

private:
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

    void setStatus(bool ok, const QString &message)
    {
        m_ok = ok;
        m_status = appTr(message);
        emit statusChanged();
    }

    void setBusy(bool busy)
    {
        if (m_busy == busy)
            return;
        m_busy = busy;
        emit busyChanged();
    }

    QString m_filePath;
    QString m_fileName;
    QString m_kind;
    QString m_sizeText;
    QString m_packageName;
    QString m_packageVersion;
    QString m_description;
    QString m_status = QStringLiteral("Ready");
    bool m_ok = true;
    bool m_busy = false;
    QString m_log;
};

int main(int argc, char *argv[])
{
    qputenv("QT_QUICK_BACKEND", "software");

    QGuiApplication app(argc, argv);

    AppLang lang;
    AppTheme theme;
    appLangInstance() = &lang;
    app.setApplicationName(QStringLiteral("elvonos-package-installer"));
    app.setDesktopFileName(QStringLiteral("elvonos-package-installer"));

    InstallerModel model;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("lang"), &lang);
    engine.rootContext()->setContextProperty(QStringLiteral("theme"), &theme);
    engine.rootContext()->setContextProperty(QStringLiteral("installer"), &model);
    engine.load(QUrl(QStringLiteral("qrc:/Installer.qml")));
    if (engine.rootObjects().isEmpty())
        return 1;

    const QStringList arguments = app.arguments();
    for (int i = 1; i < arguments.size(); ++i) {
        if (!arguments.at(i).startsWith(QLatin1Char('-'))) {
            model.open(arguments.at(i));
            break;
        }
    }
    return app.exec();
}

#include "main.moc"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include "../common/elvonapp.h"

class PrintScanModel : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList printers READ printers NOTIFY printersChanged)
    Q_PROPERTY(QVariantList jobs READ jobs NOTIFY jobsChanged)
    Q_PROPERTY(QVariantList scanners READ scanners NOTIFY scannersChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(bool ok READ ok NOTIFY statusChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString lastScan READ lastScan NOTIFY lastScanChanged)
    Q_PROPERTY(QString scanDir READ scanDir CONSTANT)

public:
    explicit PrintScanModel(QObject *parent = nullptr)
        : QObject(parent)
    {
    }

    QVariantList printers() const { return m_printers; }
    QVariantList jobs() const { return m_jobs; }
    QVariantList scanners() const { return m_scanners; }
    QString status() const { return appTr(m_status); }
    bool ok() const { return m_ok; }
    bool busy() const { return m_busy; }
    QString lastScan() const { return m_lastScan; }

    QString scanDir() const
    {
        QString path = QStandardPaths::writableLocation(
            QStandardPaths::PicturesLocation);
        if (path.isEmpty())
            path = QStandardPaths::writableLocation(
                QStandardPaths::HomeLocation);
        return path + QStringLiteral("/Scans");
    }

    Q_INVOKABLE void refresh()
    {
        if (m_busy)
            return;
        setBusy(true);

        m_printers.clear();
        QProcess printers;
        printers.start(QStringLiteral("lpstat"), {QStringLiteral("-p"),
                                                  QStringLiteral("-d")});
        if (!printers.waitForFinished(5000)) {
            printers.kill();
            printers.waitForFinished(1000);
        }
        QString defaultPrinter;
        const QString printerOutput =
            QString::fromUtf8(printers.readAllStandardOutput());
        static const QRegularExpression printerRegex(
            QStringLiteral("^printer (\\S+)\\s+(.*)$"));
        static const QRegularExpression defaultRegex(
            QStringLiteral("^system default destination: (\\S+)$"));
        for (const QString &line : printerOutput.split(QLatin1Char('\n'))) {
            const QRegularExpressionMatch defaultMatch = defaultRegex.match(line);
            if (defaultMatch.hasMatch()) {
                defaultPrinter = defaultMatch.captured(1);
                continue;
            }
            const QRegularExpressionMatch match = printerRegex.match(line);
            if (!match.hasMatch())
                continue;
            QVariantMap entry;
            entry.insert(QStringLiteral("name"), match.captured(1));
            entry.insert(QStringLiteral("info"), match.captured(2).trimmed());
            entry.insert(QStringLiteral("isDefault"), match.captured(1) == defaultPrinter);
            m_printers.append(entry);
        }
        // A second pass for the default flag when it appeared after the printers.
        for (int i = 0; i < m_printers.size(); ++i) {
            QVariantMap entry = m_printers.at(i).toMap();
            entry.insert(QStringLiteral("isDefault"),
                         entry.value(QStringLiteral("name")).toString() == defaultPrinter);
            m_printers[i] = entry;
        }
        emit printersChanged();

        m_jobs.clear();
        QProcess jobs;
        jobs.start(QStringLiteral("lpstat"), {QStringLiteral("-o")});
        if (!jobs.waitForFinished(5000)) {
            jobs.kill();
            jobs.waitForFinished(1000);
        }
        static const QRegularExpression jobRegex(
            QStringLiteral("^(\\S+)\\s+(\\S+)\\s+(\\d+)\\s+(.*)$"));
        for (const QString &line :
             QString::fromUtf8(jobs.readAllStandardOutput()).split(QLatin1Char('\n'))) {
            const QRegularExpressionMatch match = jobRegex.match(line);
            if (!match.hasMatch())
                continue;
            QVariantMap entry;
            entry.insert(QStringLiteral("id"), match.captured(1));
            entry.insert(QStringLiteral("owner"), match.captured(2));
            entry.insert(QStringLiteral("size"),
                         QString::number(match.captured(3).toLongLong() / 1024)
                         + QStringLiteral(" KB"));
            entry.insert(QStringLiteral("when"), match.captured(4).trimmed());
            m_jobs.append(entry);
        }
        emit jobsChanged();

        m_scanners.clear();
        QProcess scanners;
        scanners.start(QStringLiteral("scanimage"), {QStringLiteral("-L")});
        if (!scanners.waitForFinished(8000)) {
            scanners.kill();
            scanners.waitForFinished(1000);
        }
        static const QRegularExpression scannerRegex(
            QStringLiteral("device `([^']+)' is a (.+)"));
        for (const QString &line :
             QString::fromUtf8(scanners.readAllStandardOutput()).split(QLatin1Char('\n'))) {
            const QRegularExpressionMatch match = scannerRegex.match(line);
            if (!match.hasMatch())
                continue;
            QVariantMap entry;
            entry.insert(QStringLiteral("device"), match.captured(1));
            entry.insert(QStringLiteral("name"), match.captured(2).trimmed());
            m_scanners.append(entry);
        }
        emit scannersChanged();

        setBusy(false);
        setStatus(true, appTr(QStringLiteral("%1 printers, %2 scanners"))
                            .arg(m_printers.size()).arg(m_scanners.size()));
    }

    Q_INVOKABLE void setDefaultPrinter(const QString &name)
    {
        if (name.isEmpty())
            return;
        runCommand(QStringLiteral("lpoptions"),
                   {QStringLiteral("-d"), name},
                   QStringLiteral("Default printer set to %1").arg(name));
    }

    Q_INVOKABLE void printTestPage(const QString &name)
    {
        if (name.isEmpty()) {
            setStatus(false, QStringLiteral("Select a printer first"));
            return;
        }
        const QString path = QDir::tempPath()
                             + QStringLiteral("/elvonos-print-test.txt");
        QFile file(path);
        if (file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            file.write("ElvonOS printer test page\n\n"
                       "If you can read this, the printer works.\n");
            file.close();
        }
        runCommand(QStringLiteral("lp"),
                   {QStringLiteral("-d"), name, path},
                   QStringLiteral("Test page sent to %1").arg(name));
    }

    Q_INVOKABLE void cancelJob(const QString &id)
    {
        if (id.isEmpty())
            return;
        runCommand(QStringLiteral("cancel"), {id},
                   QStringLiteral("Cancelled %1").arg(id));
    }

    Q_INVOKABLE void scan(const QString &device, int resolution,
                          const QString &mode)
    {
        if (m_busy)
            return;
        if (device.isEmpty()) {
            setStatus(false, QStringLiteral("No scanner selected"));
            return;
        }
        QDir().mkpath(scanDir());
        const QString path = scanDir() + QStringLiteral("/Scan_")
                             + QDateTime::currentDateTime().toString(
                                 QStringLiteral("yyyy-MM-dd_HH-mm-ss"))
                             + QStringLiteral(".png");
        setBusy(true);
        setStatus(true, QStringLiteral("Scanning…"));
        QProcess process;
        process.start(QStringLiteral("scanimage"),
                      {QStringLiteral("--device"), device,
                       QStringLiteral("--format"), QStringLiteral("png"),
                       QStringLiteral("--resolution"), QString::number(resolution),
                       QStringLiteral("--mode"), mode,
                       QStringLiteral("--output-file"), path});
        if (!process.waitForFinished(180000)
            || process.exitStatus() != QProcess::NormalExit
            || process.exitCode() != 0
            || !QFileInfo::exists(path)) {
            process.kill();
            const QString error =
                QString::fromUtf8(process.readAllStandardError()).trimmed();
            setBusy(false);
            setStatus(false, error.isEmpty()
                                ? QStringLiteral("Scan failed")
                                : error);
            return;
        }
        m_lastScan = path;
        emit lastScanChanged();
        setBusy(false);
        setStatus(true, appTr(QStringLiteral("Scan saved: %1"))
                            .arg(QFileInfo(path).fileName()));
    }

    Q_INVOKABLE void openCups()
    {
        openExternal(QStringLiteral("http://localhost:631"));
    }

    Q_INVOKABLE void openScanFolder()
    {
        openExternal(scanDir());
    }

    Q_INVOKABLE void openLastScan()
    {
        if (!m_lastScan.isEmpty())
            openExternal(m_lastScan);
    }

signals:
    void printersChanged();
    void jobsChanged();
    void scannersChanged();
    void statusChanged();
    void busyChanged();
    void lastScanChanged();

private:
    void runCommand(const QString &program, const QStringList &arguments,
                    const QString &success)
    {
        if (m_busy)
            return;
        setBusy(true);
        QProcess process;
        process.start(program, arguments);
        if (!process.waitForFinished(60000)
            || process.exitStatus() != QProcess::NormalExit
            || process.exitCode() != 0) {
            process.kill();
            const QString error =
                QString::fromUtf8(process.readAllStandardError()).trimmed();
            setBusy(false);
            setStatus(false, error.isEmpty()
                                ? QStringLiteral("%1 failed").arg(program)
                                : error);
            return;
        }
        setBusy(false);
        setStatus(true, success);
        refresh();
    }

    void openExternal(const QString &path)
    {
        QString opener = QStandardPaths::findExecutable(QStringLiteral("xdg-open"));
        if (opener.isEmpty())
            opener = QStandardPaths::findExecutable(QStringLiteral("thunar"));
        if (opener.isEmpty())
            return;
        QProcess::startDetached(opener, {path});
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

    QVariantList m_printers;
    QVariantList m_jobs;
    QVariantList m_scanners;
    QString m_status = QStringLiteral("Ready");
    bool m_ok = true;
    bool m_busy = false;
    QString m_lastScan;
};

int main(int argc, char *argv[])
{
    qputenv("QT_QUICK_BACKEND", "software");

    QGuiApplication app(argc, argv);

    AppLang lang;
    AppTheme theme;
    appLangInstance() = &lang;
    app.setApplicationName(QStringLiteral("elvonos-printscan"));
    app.setDesktopFileName(QStringLiteral("elvonos-printscan"));

    PrintScanModel model;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("lang"), &lang);
    engine.rootContext()->setContextProperty(QStringLiteral("theme"), &theme);
    engine.rootContext()->setContextProperty(QStringLiteral("printscan"), &model);
    engine.load(QUrl(QStringLiteral("qrc:/PrintScan.qml")));
    if (engine.rootObjects().isEmpty())
        return 1;
    if (qEnvironmentVariableIsSet("ELVONOS_PRINTSCAN_TAB")) {
        const int tab = qEnvironmentVariableIntValue("ELVONOS_PRINTSCAN_TAB");
        if (tab == 1)
            engine.rootObjects().constFirst()->setProperty("tab", 1);
    }
    QTimer::singleShot(0, &model, &PrintScanModel::refresh);
    return app.exec();
}

#include "main.moc"

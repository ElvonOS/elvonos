#include <QClipboard>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QImage>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include "../common/elvonapp.h"

namespace {

QString humanSize(qint64 bytes)
{
    if (bytes < 1024)
        return QString::number(bytes) + " B";
    const double kb = bytes / 1024.0;
    if (kb < 1024)
        return QString::number(kb, 'f', 0) + " KB";
    return QString::number(kb / 1024.0, 'f', 1) + " MB";
}

} // namespace

class ScreenshotModel : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString saveDir READ saveDir CONSTANT)
    Q_PROPERTY(QString lastPath READ lastPath NOTIFY lastPathChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(bool ok READ ok NOTIFY statusChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QVariantList recent READ recent NOTIFY recentChanged)

public:
    explicit ScreenshotModel(QObject *parent = nullptr)
        : QObject(parent)
    {
        QDir().mkpath(saveDir());
        refresh();
    }

    QString saveDir() const
    {
        return QStandardPaths::writableLocation(QStandardPaths::PicturesLocation)
               + QStringLiteral("/Screenshots");
    }

    QString lastPath() const { return m_lastPath; }
    QString status() const { return appTr(m_status); }
    bool ok() const { return m_ok; }
    bool busy() const { return m_busy; }
    QVariantList recent() const { return m_recent; }

    Q_INVOKABLE void capture(const QString &mode, int delaySeconds,
                             bool includeCursor, bool jpeg)
    {
        if (m_busy)
            return;
        setBusy(true);
        setStatus(true, delaySeconds > 0
                            ? QStringLiteral("Capturing in %1 s…").arg(delaySeconds)
                            : QStringLiteral("Capturing…"));
        const bool region = mode == QStringLiteral("region");
        QTimer::singleShot(delaySeconds * 1000, this,
                           [this, region, includeCursor, jpeg]() {
            runCapture(region, includeCursor, jpeg);
        });
    }

    Q_INVOKABLE void select(const QString &path)
    {
        if (!QFileInfo::exists(path))
            return;
        m_lastPath = path;
        emit lastPathChanged();
        setStatus(true, appTr(QStringLiteral("Selected %1")).arg(QFileInfo(path).fileName()));
    }

    Q_INVOKABLE void copyLast()
    {
        if (m_lastPath.isEmpty() || !QFileInfo::exists(m_lastPath)) {
            setStatus(false, QStringLiteral("No screenshot to copy"));
            return;
        }
        QFile file(m_lastPath);
        if (!file.open(QIODevice::ReadOnly)) {
            setStatus(false, QStringLiteral("Cannot read the screenshot"));
            return;
        }
        QProcess process;
        process.start(QStringLiteral("wl-copy"),
                      {QStringLiteral("-t"), QStringLiteral("image/png")});
        if (!process.waitForStarted(3000)) {
            setStatus(false, QStringLiteral("wl-copy is not available"));
            return;
        }
        process.write(file.readAll());
        process.closeWriteChannel();
        if (process.waitForFinished(3000))
            setStatus(true, QStringLiteral("Copied to clipboard"));
        else
            setStatus(false, QStringLiteral("Clipboard copy timed out"));
    }

    Q_INVOKABLE void openLast()
    {
        if (m_lastPath.isEmpty() || !QFileInfo::exists(m_lastPath)) {
            setStatus(false, QStringLiteral("No screenshot to open"));
            return;
        }
        QString opener = QStandardPaths::findExecutable(
            QStringLiteral("elvonos-gallery"));
        if (opener.isEmpty())
            opener = QStandardPaths::findExecutable(QStringLiteral("xdg-open"));
        if (opener.isEmpty()) {
            setStatus(false, QStringLiteral("No image viewer found"));
            return;
        }
        QProcess::startDetached(opener, {m_lastPath});
        setStatus(true, QStringLiteral("Opening in the Gallery"));
    }

    Q_INVOKABLE void deleteLast()
    {
        if (m_lastPath.isEmpty() || !QFileInfo::exists(m_lastPath)) {
            setStatus(false, QStringLiteral("No screenshot to delete"));
            return;
        }
        const QString name = QFileInfo(m_lastPath).fileName();
        if (QFile::remove(m_lastPath)) {
            m_lastPath.clear();
            emit lastPathChanged();
            setStatus(true, appTr(QStringLiteral("Deleted %1")).arg(name));
            refresh();
        } else {
            setStatus(false, appTr(QStringLiteral("Could not delete %1")).arg(name));
        }
    }

    Q_INVOKABLE void refresh()
    {
        QDir dir(saveDir());
        QFileInfoList files = dir.entryInfoList(
            {QStringLiteral("*.png"), QStringLiteral("*.jpg"),
             QStringLiteral("*.jpeg")},
            QDir::Files | QDir::Readable, QDir::Time);
        QVariantList list;
        for (int i = 0; i < files.size() && i < 24; ++i) {
            const QFileInfo &info = files.at(i);
            QVariantMap entry;
            entry.insert(QStringLiteral("path"), info.absoluteFilePath());
            entry.insert(QStringLiteral("thumb"),
                         QStringLiteral("file://") + info.absoluteFilePath());
            entry.insert(QStringLiteral("name"), info.fileName());
            entry.insert(QStringLiteral("date"),
                         info.lastModified().toString(QStringLiteral("dd MMM yyyy  HH:mm")));
            entry.insert(QStringLiteral("size"), humanSize(info.size()));
            list.append(entry);
        }
        m_recent = list;
        emit recentChanged();

        if (m_lastPath.isEmpty() && !files.isEmpty()) {
            m_lastPath = files.first().absoluteFilePath();
            emit lastPathChanged();
        }
    }

signals:
    void lastPathChanged();
    void statusChanged();
    void busyChanged();
    void recentChanged();

private:
    void runCapture(bool region, bool includeCursor, bool jpeg)
    {
        QDir().mkpath(saveDir());
        const QString extension = jpeg ? QStringLiteral("jpg") : QStringLiteral("png");
        QString base = QStringLiteral("Screenshot_")
                       + QDateTime::currentDateTime().toString(
                           QStringLiteral("yyyy-MM-dd_HH-mm-ss"));
        QString path = QDir(saveDir()).filePath(base + QLatin1Char('.') + extension);
        int suffix = 1;
        while (QFileInfo::exists(path)) {
            path = QDir(saveDir()).filePath(
                base + QStringLiteral("_") + QString::number(suffix++)
                + QLatin1Char('.') + extension);
        }

        QProcess process;
        if (region) {
            QString command = QStringLiteral("grim");
            if (includeCursor)
                command += QStringLiteral(" -c");
            command += jpeg ? QStringLiteral(" -t jpeg -q 92")
                            : QStringLiteral(" -t png");
            command += QStringLiteral(" -g \"$(slurp -d)\" \"") + path + QStringLiteral("\"");
            process.start(QStringLiteral("bash"),
                          {QStringLiteral("-c"), command});
        } else {
            QStringList arguments;
            if (includeCursor)
                arguments << QStringLiteral("-c");
            arguments << QStringLiteral("-t")
                      << (jpeg ? QStringLiteral("jpeg") : QStringLiteral("png"));
            if (jpeg)
                arguments << QStringLiteral("-q") << QStringLiteral("92");
            arguments << path;
            process.start(QStringLiteral("grim"), arguments);
        }

        if (!process.waitForFinished(120000)) {
            process.kill();
            process.waitForFinished(2000);
            setBusy(false);
            setStatus(false, QStringLiteral("Capture timed out"));
            return;
        }

        const QFileInfo info(path);
        if (process.exitStatus() != QProcess::NormalExit
            || process.exitCode() != 0 || !info.exists() || info.size() == 0) {
            const QString error = QString::fromUtf8(process.readAllStandardError()).trimmed();
            setBusy(false);
            setStatus(false, error.isEmpty()
                                ? QStringLiteral("Capture cancelled")
                                : QStringLiteral("Capture failed: %1").arg(error));
            return;
        }

        m_lastPath = path;
        emit lastPathChanged();
        setBusy(false);
        setStatus(true, appTr(QStringLiteral("Saved %1 (%2)"))
                            .arg(info.fileName(), humanSize(info.size())));
        refresh();
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

    QString m_lastPath;
    QString m_status = QStringLiteral("Ready");
    bool m_ok = true;
    bool m_busy = false;
    QVariantList m_recent;
};

int main(int argc, char *argv[])
{
    /* 2D UI; software rendering keeps the first frame fast on virtualised
     * GPUs (the actual capture is done by grim). */
    qputenv("QT_QUICK_BACKEND", "software");

    QGuiApplication app(argc, argv);

    AppLang lang;
    AppTheme theme;
    appLangInstance() = &lang;
    app.setApplicationName(QStringLiteral("elvonos-screenshot"));
    app.setDesktopFileName(QStringLiteral("elvonos-screenshot"));

    ScreenshotModel model;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("lang"), &lang);
    engine.rootContext()->setContextProperty(QStringLiteral("theme"), &theme);
    engine.rootContext()->setContextProperty(QStringLiteral("shot"), &model);
    engine.load(QUrl(QStringLiteral("qrc:/Screenshot.qml")));
    if (engine.rootObjects().isEmpty())
        return 1;
    if (qEnvironmentVariableIsSet("ELVONOS_SCREENSHOT_AUTO"))
        QTimer::singleShot(1500, &model, [&model]() {
            model.capture(QStringLiteral("full"), 0, false, false);
        });
    return app.exec();
}

#include "main.moc"

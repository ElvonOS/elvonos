#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QSettings>
#include <QStandardPaths>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include "../common/elvonapp.h"

namespace {

const QStringList &mediaSuffixes()
{
    static const QStringList suffixes = {
        QStringLiteral("mp4"),  QStringLiteral("mkv"),  QStringLiteral("webm"),
        QStringLiteral("avi"),  QStringLiteral("mov"),  QStringLiteral("m4v"),
        QStringLiteral("mpg"),  QStringLiteral("mpeg"), QStringLiteral("ts"),
        QStringLiteral("flv"),  QStringLiteral("mp3"),  QStringLiteral("flac"),
        QStringLiteral("wav"),  QStringLiteral("ogg"),  QStringLiteral("oga"),
        QStringLiteral("opus"), QStringLiteral("m4a"),  QStringLiteral("aac"),
        QStringLiteral("wma"),  QStringLiteral("mid"),  QStringLiteral("m4b"),
    };
    return suffixes;
}

bool isMediaFile(const QString &path)
{
    return mediaSuffixes().contains(QFileInfo(path).suffix().toLower());
}

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

class MediaModel : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString directory READ directory NOTIFY directoryChanged)
    Q_PROPERTY(QVariantList entries READ entries NOTIFY entriesChanged)

public:
    explicit MediaModel(QObject *parent = nullptr)
        : QObject(parent)
    {
        QString start =
            QStandardPaths::writableLocation(QStandardPaths::MoviesLocation);
        if (start.isEmpty() || !QDir(start).exists())
            start = QStandardPaths::writableLocation(
                QStandardPaths::MusicLocation);
        if (start.isEmpty() || !QDir(start).exists())
            start = QDir::homePath();
        setDirectory(start);
    }

    QString directory() const { return m_directory; }
    QVariantList entries() const { return m_entries; }

    Q_INVOKABLE void setDirectory(const QString &path)
    {
        QDir dir(path);
        if (!dir.exists())
            dir = QDir(QDir::homePath());
        m_directory = dir.absolutePath();

        m_entries.clear();
        const QFileInfoList infos = dir.entryInfoList(
            QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Readable,
            QDir::DirsFirst | QDir::Name | QDir::IgnoreCase);
        for (const QFileInfo &info : infos) {
            if (info.fileName().startsWith(QLatin1Char('.')))
                continue;
            if (!info.isDir() && !isMediaFile(info.fileName()))
                continue;
            QVariantMap entry;
            entry.insert(QStringLiteral("name"), info.fileName());
            entry.insert(QStringLiteral("path"), info.absoluteFilePath());
            entry.insert(QStringLiteral("isDir"), info.isDir());
            entry.insert(QStringLiteral("sizeText"),
                         info.isDir() ? QString() : humanSize(info.size()));
            m_entries.append(entry);
        }
        emit directoryChanged();
        emit entriesChanged();
    }

    Q_INVOKABLE void goUp()
    {
        QDir dir(m_directory);
        if (dir.cdUp())
            setDirectory(dir.absolutePath());
    }

    Q_INVOKABLE void refresh() { setDirectory(m_directory); }

    Q_INVOKABLE QString homePath() const
    {
        return QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
    }

    Q_INVOKABLE QString videosPath() const
    {
        QString path = QStandardPaths::writableLocation(
            QStandardPaths::MoviesLocation);
        return path.isEmpty() ? homePath() : path;
    }

    Q_INVOKABLE QString musicPath() const
    {
        QString path = QStandardPaths::writableLocation(
            QStandardPaths::MusicLocation);
        return path.isEmpty() ? homePath() : path;
    }

    Q_INVOKABLE QString urlFor(const QString &path) const
    {
        return QUrl::fromLocalFile(path).toString();
    }

    Q_INVOKABLE QStringList mediaInDirectory(const QString &path) const
    {
        QStringList result;
        QDir dir(path);
        const QFileInfoList infos = dir.entryInfoList(
            QDir::Files | QDir::Readable, QDir::Name | QDir::IgnoreCase);
        for (const QFileInfo &info : infos) {
            if (isMediaFile(info.fileName()))
                result.append(info.absoluteFilePath());
        }
        return result;
    }

    Q_INVOKABLE QString baseName(const QString &path) const
    {
        return QFileInfo(path).completeBaseName();
    }

    Q_INVOKABLE QVariant loadSetting(const QString &key,
                                     const QVariant &fallback) const
    {
        return QSettings().value(key, fallback);
    }

    Q_INVOKABLE void saveSetting(const QString &key, const QVariant &value)
    {
        QSettings().setValue(key, value);
    }

    Q_INVOKABLE QStringList loadPlaylist() const
    {
        return QSettings().value(QStringLiteral("playlist")).toStringList();
    }

    Q_INVOKABLE void savePlaylist(const QStringList &paths)
    {
        QSettings().setValue(QStringLiteral("playlist"), paths);
    }

signals:
    void directoryChanged();
    void entriesChanged();

private:
    QString m_directory;
    QVariantList m_entries;
};

int main(int argc, char *argv[])
{
    /* On virtualised GPUs the GL scene graph can need many seconds for its
     * first frame (or fail to map at all), so fall back to the software
     * renderer there. Real hardware keeps the GL backend so video frames are
     * presented through VideoOutput normally. */
    QFile vendorFile(QStringLiteral("/sys/class/dmi/id/sys_vendor"));
    if (vendorFile.open(QIODevice::ReadOnly)) {
        const QString vendor = QString::fromLatin1(vendorFile.readAll());
        if (vendor.contains(QLatin1String("QEMU"), Qt::CaseInsensitive)
            || vendor.contains(QLatin1String("VirtualBox"), Qt::CaseInsensitive)
            || vendor.contains(QLatin1String("VMware"), Qt::CaseInsensitive)
            || vendor.contains(QLatin1String("KVM"), Qt::CaseInsensitive))
            qputenv("QT_QUICK_BACKEND", "software");
    }

    QGuiApplication app(argc, argv);

    AppLang lang;
    AppTheme theme;
    appLangInstance() = &lang;
    app.setApplicationName(QStringLiteral("elvonos-media"));
    app.setOrganizationName(QStringLiteral("ElvonOS"));
    app.setDesktopFileName(QStringLiteral("elvonos-media"));

    MediaModel model;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("lang"), &lang);
    engine.rootContext()->setContextProperty(QStringLiteral("theme"), &theme);
    engine.rootContext()->setContextProperty(QStringLiteral("mediaModel"),
                                             &model);
    engine.load(QUrl(QStringLiteral("qrc:/Media.qml")));
    if (engine.rootObjects().isEmpty())
        return 1;

    return app.exec();
}

#include "main.moc"

#include <QDir>
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

QString detectArchiveFormat(const QString &path)
{
    const QString lower = path.toLower();
    if (lower.endsWith(".zip"))
        return QStringLiteral("zip");
    if (lower.endsWith(".tar.gz") || lower.endsWith(".tgz"))
        return QStringLiteral("tar.gz");
    if (lower.endsWith(".tar.xz") || lower.endsWith(".txz"))
        return QStringLiteral("tar.xz");
    if (lower.endsWith(".tar.bz2") || lower.endsWith(".tbz2"))
        return QStringLiteral("tar.bz2");
    if (lower.endsWith(".tar"))
        return QStringLiteral("tar");
    return {};
}

QString extensionFor(const QString &format)
{
    if (format == QStringLiteral("zip"))
        return QStringLiteral(".zip");
    if (format == QStringLiteral("tar.gz"))
        return QStringLiteral(".tar.gz");
    if (format == QStringLiteral("tar.xz"))
        return QStringLiteral(".tar.xz");
    if (format == QStringLiteral("tar.bz2"))
        return QStringLiteral(".tar.bz2");
    return QStringLiteral(".tar");
}

QString archiveBaseName(const QString &path)
{
    QString name = QFileInfo(path).fileName();
    const QString lower = name.toLower();
    for (const QString &suffix : {QStringLiteral(".tar.gz"), QStringLiteral(".tar.xz"),
                                  QStringLiteral(".tar.bz2"), QStringLiteral(".tgz"),
                                  QStringLiteral(".txz"), QStringLiteral(".tbz2"),
                                  QStringLiteral(".zip"), QStringLiteral(".tar")}) {
        if (lower.endsWith(suffix))
            return name.left(name.size() - suffix.size());
    }
    return name;
}

QString commonParent(const QStringList &paths)
{
    if (paths.isEmpty())
        return QDir::homePath();
    QStringList parents;
    for (const QString &path : paths)
        parents.append(QFileInfo(path).absolutePath());
    QString common = parents.first();
    for (const QString &dir : parents) {
        while (common != dir && !dir.startsWith(common + QLatin1Char('/'))) {
            common = QFileInfo(common).absolutePath();
            if (common == QLatin1String("/"))
                return common;
        }
    }
    return common;
}

} // namespace

class ArchiveModel : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString archivePath READ archivePath NOTIFY archiveChanged)
    Q_PROPERTY(QString archiveName READ archiveName NOTIFY archiveChanged)
    Q_PROPERTY(QString archiveFormat READ archiveFormat NOTIFY archiveChanged)
    Q_PROPERTY(QVariantList entries READ entries NOTIFY entriesChanged)
    Q_PROPERTY(QString extractDir READ extractDir NOTIFY extractDirChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(bool ok READ ok NOTIFY statusChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit ArchiveModel(QObject *parent = nullptr)
        : QObject(parent)
    {
        m_extractDir = downloadsPath();
    }

    QString archivePath() const { return m_archivePath; }
    QString archiveName() const { return m_archiveName; }
    QString archiveFormat() const { return m_archiveFormat; }
    QVariantList entries() const { return m_entries; }
    QString extractDir() const { return m_extractDir; }
    QString status() const { return appTr(m_status); }
    bool ok() const { return m_ok; }
    bool busy() const { return m_busy; }

    Q_INVOKABLE QString homePath() const
    {
        return QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
    }

    Q_INVOKABLE QString downloadsPath() const
    {
        QString path = QStandardPaths::writableLocation(
            QStandardPaths::DownloadLocation);
        if (path.isEmpty())
            path = homePath();
        return path;
    }

    Q_INVOKABLE QString documentsPath() const
    {
        QString path = QStandardPaths::writableLocation(
            QStandardPaths::DocumentsLocation);
        if (path.isEmpty())
            path = homePath();
        return path;
    }

    Q_INVOKABLE QString baseName(const QString &path) const
    {
        return QFileInfo(path).completeBaseName();
    }

    Q_INVOKABLE QString joinPath(const QString &dir, const QString &name) const
    {
        return QDir(dir).filePath(name);
    }

    Q_INVOKABLE QString parentDir(const QString &path) const
    {
        return QFileInfo(path).absolutePath();
    }

    Q_INVOKABLE void openArchive(const QString &path)
    {
        if (m_busy)
            return;
        const QFileInfo info(path);
        if (!info.exists() || !info.isFile()) {
            setStatus(false, appTr(QStringLiteral("Archive not found: %1")).arg(path));
            return;
        }
        const QString format = detectArchiveFormat(path);
        if (format.isEmpty()) {
            setStatus(false, QStringLiteral("Unsupported archive format"));
            return;
        }

        setBusy(true);
        QProcess process;
        if (format == QStringLiteral("zip"))
            process.start(QStringLiteral("unzip"),
                          {QStringLiteral("-l"), info.absoluteFilePath()});
        else
            process.start(QStringLiteral("tar"),
                          {QStringLiteral("-tvf"), info.absoluteFilePath()});

        if (!process.waitForFinished(30000)) {
            process.kill();
            setBusy(false);
            setStatus(false, QStringLiteral("Reading the archive timed out"));
            return;
        }
        if (process.exitStatus() != QProcess::NormalExit
            || process.exitCode() != 0) {
            const QString error =
                QString::fromUtf8(process.readAllStandardError()).trimmed();
            setBusy(false);
            setStatus(false, error.isEmpty()
                                ? QStringLiteral("Could not read the archive")
                                : error);
            return;
        }

        const QString output = QString::fromUtf8(process.readAllStandardOutput());
        const QVariantList entries = parseEntries(format, output);
        m_archivePath = info.absoluteFilePath();
        m_archiveName = info.fileName();
        m_archiveFormat = format;
        m_entries = entries;
        m_extractDir = downloadsPath() + QLatin1Char('/') + archiveBaseName(path);
        emit archiveChanged();
        emit entriesChanged();
        emit extractDirChanged();
        setBusy(false);
        setStatus(true, appTr(QStringLiteral("Opened %1 entries in %2"))
                            .arg(entries.size()).arg(info.fileName()));
    }

    Q_INVOKABLE void refresh()
    {
        if (!m_archivePath.isEmpty())
            openArchive(m_archivePath);
    }

    Q_INVOKABLE void closeArchive()
    {
        m_archivePath.clear();
        m_archiveName.clear();
        m_archiveFormat.clear();
        m_entries.clear();
        emit archiveChanged();
        emit entriesChanged();
        setStatus(true, QStringLiteral("Ready"));
    }

    Q_INVOKABLE void extractAll(const QString &destination)
    {
        if (m_busy)
            return;
        if (m_archivePath.isEmpty()) {
            setStatus(false, QStringLiteral("Open an archive first"));
            return;
        }
        QString dest = destination.trimmed();
        if (dest.isEmpty())
            dest = m_extractDir;
        QDir().mkpath(dest);

        setBusy(true);
        QProcess process;
        if (m_archiveFormat == QStringLiteral("zip"))
            process.start(QStringLiteral("unzip"),
                          {QStringLiteral("-o"), m_archivePath, QStringLiteral("-d"), dest});
        else
            process.start(QStringLiteral("tar"),
                          {QStringLiteral("-xf"), m_archivePath, QStringLiteral("-C"), dest});

        if (!process.waitForFinished(300000)) {
            process.kill();
            setBusy(false);
            setStatus(false, QStringLiteral("Extraction timed out"));
            return;
        }
        if (process.exitStatus() != QProcess::NormalExit
            || process.exitCode() != 0) {
            const QString error =
                QString::fromUtf8(process.readAllStandardError()).trimmed();
            setBusy(false);
            setStatus(false, error.isEmpty()
                                ? QStringLiteral("Extraction failed")
                                : error);
            return;
        }
        setBusy(false);
        m_extractDir = dest;
        emit extractDirChanged();
        setStatus(true, appTr(QStringLiteral("Extracted to %1")).arg(dest));
    }

    Q_INVOKABLE void createArchive(const QString &path, const QString &format,
                                   const QStringList &sources)
    {
        if (m_busy)
            return;
        if (sources.isEmpty()) {
            setStatus(false, QStringLiteral("Add files or folders first"));
            return;
        }
        QString target = path.trimmed();
        if (target.isEmpty()) {
            setStatus(false, QStringLiteral("Enter an archive name"));
            return;
        }
        const QString extension = extensionFor(format);
        if (!target.toLower().endsWith(extension))
            target += extension;
        if (!target.contains(QLatin1Char('/')))
            target = downloadsPath() + QLatin1Char('/') + target;

        const QString parent = commonParent(sources);
        QStringList relative;
        for (const QString &source : sources)
            relative.append(QDir(parent).relativeFilePath(source));
        if (relative.isEmpty()) {
            setStatus(false, QStringLiteral("Could not resolve the sources"));
            return;
        }

        setBusy(true);
        QProcess process;
        if (format == QStringLiteral("zip")) {
            process.setWorkingDirectory(parent);
            QStringList arguments{QStringLiteral("-r"), QStringLiteral("-9"),
                                  QFileInfo(target).absoluteFilePath()};
            arguments += relative;
            process.start(QStringLiteral("zip"), arguments);
        } else {
            QString flag = QStringLiteral("-cf");
            if (format == QStringLiteral("tar.gz"))
                flag = QStringLiteral("-czf");
            else if (format == QStringLiteral("tar.xz"))
                flag = QStringLiteral("-cJf");
            else if (format == QStringLiteral("tar.bz2"))
                flag = QStringLiteral("-cjf");
            QStringList arguments{flag, QFileInfo(target).absoluteFilePath(),
                                  QStringLiteral("-C"), parent};
            arguments += relative;
            process.start(QStringLiteral("tar"), arguments);
        }

        if (!process.waitForFinished(300000)) {
            process.kill();
            setBusy(false);
            setStatus(false, QStringLiteral("Creating the archive timed out"));
            return;
        }
        if (process.exitStatus() != QProcess::NormalExit
            || process.exitCode() != 0) {
            const QString error =
                QString::fromUtf8(process.readAllStandardError()).trimmed();
            setBusy(false);
            setStatus(false, error.isEmpty()
                                ? QStringLiteral("Could not create the archive")
                                : error);
            return;
        }
        setBusy(false);
        setStatus(true, appTr(QStringLiteral("Created %1")).arg(QFileInfo(target).fileName()));
        openArchive(target);
    }

    Q_INVOKABLE QVariantList listDirectory(const QString &path, bool archivesOnly) const
    {
        QDir dir(path);
        if (!dir.exists())
            dir = QDir(homePath());
        QVariantList list;
        const QFileInfoList infos = dir.entryInfoList(
            QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Readable,
            QDir::DirsFirst | QDir::Name | QDir::IgnoreCase);
        for (const QFileInfo &info : infos) {
            if (info.fileName().startsWith(QLatin1Char('.')))
                continue;
            if (archivesOnly && !info.isDir()
                && detectArchiveFormat(info.fileName()).isEmpty())
                continue;
            QVariantMap entry;
            entry.insert(QStringLiteral("name"), info.fileName());
            entry.insert(QStringLiteral("path"), info.absoluteFilePath());
            entry.insert(QStringLiteral("isDir"), info.isDir());
            entry.insert(QStringLiteral("sizeText"),
                         info.isDir() ? QString() : humanSize(info.size()));
            list.append(entry);
        }
        return list;
    }

    Q_INVOKABLE void openDir(const QString &path)
    {
        QString opener = QStandardPaths::findExecutable(QStringLiteral("xdg-open"));
        if (opener.isEmpty())
            opener = QStandardPaths::findExecutable(QStringLiteral("thunar"));
        if (opener.isEmpty())
            return;
        QProcess::startDetached(opener, {path});
    }

signals:
    void archiveChanged();
    void entriesChanged();
    void extractDirChanged();
    void statusChanged();
    void busyChanged();

private:
    QVariantList parseEntries(const QString &format, const QString &output) const
    {
        QVariantList list;
        const QStringList lines = output.split(QLatin1Char('\n'));
        if (format == QStringLiteral("zip")) {
            static const QRegularExpression regex(
                QStringLiteral("^\\s*(\\d+)\\s+(\\d{4}-\\d{2}-\\d{2})\\s+(\\d{2}:\\d{2})\\s+(.+)$"));
            for (const QString &line : lines) {
                const QRegularExpressionMatch match = regex.match(line);
                if (!match.hasMatch())
                    continue;
                const QString name = match.captured(4).trimmed();
                const bool isDir = name.endsWith(QLatin1Char('/'));
                QVariantMap entry;
                entry.insert(QStringLiteral("name"), name);
                entry.insert(QStringLiteral("sizeText"), humanSize(match.captured(1).toLongLong()));
                entry.insert(QStringLiteral("date"),
                             match.captured(2) + QLatin1Char(' ') + match.captured(3));
                entry.insert(QStringLiteral("isDir"), isDir);
                list.append(entry);
            }
        } else {
            static const QRegularExpression regex(
                QStringLiteral("^\\S+\\s+\\S+\\s+(\\d+)\\s+(\\d{4}-\\d{2}-\\d{2})\\s+(\\d{2}:\\d{2})\\s+(.+)$"));
            for (const QString &line : lines) {
                const QRegularExpressionMatch match = regex.match(line);
                if (!match.hasMatch())
                    continue;
                QString name = match.captured(4).trimmed();
                if (name.contains(QStringLiteral(" -> ")))
                    name = name.section(QStringLiteral(" -> "), 0, 0);
                const bool isDir = name.endsWith(QLatin1Char('/'));
                QVariantMap entry;
                entry.insert(QStringLiteral("name"), name);
                entry.insert(QStringLiteral("sizeText"), humanSize(match.captured(1).toLongLong()));
                entry.insert(QStringLiteral("date"),
                             match.captured(2) + QLatin1Char(' ') + match.captured(3));
                entry.insert(QStringLiteral("isDir"), isDir);
                list.append(entry);
            }
        }
        return list;
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

    QString m_archivePath;
    QString m_archiveName;
    QString m_archiveFormat;
    QVariantList m_entries;
    QString m_extractDir;
    QString m_status = QStringLiteral("Ready");
    bool m_ok = true;
    bool m_busy = false;
};

int main(int argc, char *argv[])
{
    qputenv("QT_QUICK_BACKEND", "software");

    QGuiApplication app(argc, argv);

    AppLang lang;
    AppTheme theme;
    appLangInstance() = &lang;
    app.setApplicationName(QStringLiteral("elvonos-archiver"));
    app.setDesktopFileName(QStringLiteral("elvonos-archiver"));

    ArchiveModel model;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("lang"), &lang);
    engine.rootContext()->setContextProperty(QStringLiteral("theme"), &theme);
    engine.rootContext()->setContextProperty(QStringLiteral("archiver"), &model);
    engine.load(QUrl(QStringLiteral("qrc:/Archiver.qml")));
    if (engine.rootObjects().isEmpty())
        return 1;
    const QString openPath = qEnvironmentVariable("ELVONOS_ARCHIVER_OPEN");
    if (!openPath.isEmpty()) {
        QTimer::singleShot(400, &model, [&model, openPath]() {
            model.openArchive(openPath);
        });
    }
    if (qEnvironmentVariableIsSet("ELVONOS_ARCHIVER_EXTRACT")) {
        QTimer::singleShot(1600, &model, [&model]() {
            model.extractAll(model.extractDir());
        });
    }
    return app.exec();
}

#include "main.moc"

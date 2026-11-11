#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QSettings>
#include <QStandardPaths>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

class PdfModel : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString filePath READ filePath NOTIFY documentChanged)
    Q_PROPERTY(QString fileName READ fileName NOTIFY documentChanged)
    Q_PROPERTY(int pageCount READ pageCount NOTIFY documentChanged)
    Q_PROPERTY(int page READ page NOTIFY pageChanged)
    Q_PROPERTY(QString renderPath READ renderPath NOTIFY renderChanged)
    Q_PROPERTY(int renderToken READ renderToken NOTIFY renderChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(bool ok READ ok NOTIFY statusChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QVariantList recent READ recent NOTIFY recentChanged)

public:
    explicit PdfModel(QObject *parent = nullptr)
        : QObject(parent)
    {
        QDir().mkpath(cacheDir());
    }

    QString filePath() const { return m_filePath; }
    QString fileName() const { return m_fileName; }
    int pageCount() const { return m_pageCount; }
    int page() const { return m_page; }
    QString renderPath() const { return m_renderPath; }
    int renderToken() const { return m_renderToken; }
    QString status() const { return m_status; }
    bool ok() const { return m_ok; }
    bool busy() const { return m_busy; }

    QVariantList recent() const
    {
        QVariantList result;
        const QStringList paths =
            QSettings().value(QStringLiteral("recentPdfs")).toStringList();
        for (const QString &path : paths) {
            if (QFileInfo::exists(path))
                result.append(path);
        }
        return result;
    }

    Q_INVOKABLE QString homePath() const
    {
        return QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
    }

    Q_INVOKABLE QString documentsPath() const
    {
        QString path = QStandardPaths::writableLocation(
            QStandardPaths::DocumentsLocation);
        if (path.isEmpty())
            path = homePath();
        return path;
    }

    Q_INVOKABLE QString downloadsPath() const
    {
        QString path = QStandardPaths::writableLocation(
            QStandardPaths::DownloadLocation);
        if (path.isEmpty())
            path = homePath();
        return path;
    }

    Q_INVOKABLE QString parentDir(const QString &path) const
    {
        return QFileInfo(path).absolutePath();
    }

    Q_INVOKABLE QString baseName(const QString &path) const
    {
        return QFileInfo(path).completeBaseName();
    }

    Q_INVOKABLE void open(const QString &path)
    {
        if (m_busy)
            return;
        const QFileInfo info(path);
        if (!info.exists() || !info.isFile()) {
            setStatus(false, QStringLiteral("PDF not found: %1").arg(path));
            return;
        }

        setBusy(true);
        QProcess process;
        process.start(QStringLiteral("pdfinfo"), {info.absoluteFilePath()});
        if (!process.waitForFinished(30000)
            || process.exitStatus() != QProcess::NormalExit
            || process.exitCode() != 0) {
            process.kill();
            setBusy(false);
            setStatus(false, QStringLiteral("Could not read the PDF"));
            return;
        }
        const QString output = QString::fromUtf8(process.readAllStandardOutput());
        int pages = 0;
        for (const QString &line : output.split(QLatin1Char('\n'))) {
            if (line.startsWith(QStringLiteral("Pages:"))) {
                pages = line.section(QLatin1Char(':'), 1).trimmed().toInt();
                break;
            }
        }
        if (pages <= 0) {
            setBusy(false);
            setStatus(false, QStringLiteral("No pages found in the PDF"));
            return;
        }

        m_filePath = info.absoluteFilePath();
        m_fileName = info.fileName();
        m_pageCount = pages;
        m_page = 1;
        m_renderPath.clear();
        emit documentChanged();
        emit pageChanged();
        addRecent(m_filePath);
        setBusy(false);
        setStatus(true, QStringLiteral("Opened %1 (%2 pages)")
                            .arg(info.fileName()).arg(pages));
        render();
    }

    Q_INVOKABLE void goToPage(int page)
    {
        if (m_filePath.isEmpty() || m_pageCount <= 0)
            return;
        const int target = qBound(1, page, m_pageCount);
        if (target == m_page && !m_renderPath.isEmpty())
            return;
        m_page = target;
        emit pageChanged();
        render();
    }

    Q_INVOKABLE void nextPage() { goToPage(m_page + 1); }
    Q_INVOKABLE void previousPage() { goToPage(m_page - 1); }

    Q_INVOKABLE void reload()
    {
        if (!m_filePath.isEmpty())
            render();
    }

    Q_INVOKABLE QVariantList listDirectory(const QString &path) const
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
            if (!info.isDir()
                && !info.fileName().toLower().endsWith(QStringLiteral(".pdf")))
                continue;
            QVariantMap entry;
            entry.insert(QStringLiteral("name"), info.fileName());
            entry.insert(QStringLiteral("path"), info.absoluteFilePath());
            entry.insert(QStringLiteral("isDir"), info.isDir());
            entry.insert(QStringLiteral("sizeText"), info.isDir()
                         ? QString()
                         : QString::number(info.size() / 1024) + QStringLiteral(" KB"));
            list.append(entry);
        }
        return list;
    }

signals:
    void documentChanged();
    void pageChanged();
    void renderChanged();
    void statusChanged();
    void busyChanged();
    void recentChanged();

private:
    QString cacheDir() const
    {
        return QDir::tempPath() + QStringLiteral("/elvonos-pdf-cache");
    }

    void addRecent(const QString &path)
    {
        QSettings settings;
        QStringList recent = settings.value(QStringLiteral("recentPdfs")).toStringList();
        recent.removeAll(path);
        recent.prepend(path);
        while (recent.size() > 8)
            recent.removeLast();
        settings.setValue(QStringLiteral("recentPdfs"), recent);
        emit recentChanged();
    }

    void render()
    {
        if (m_busy || m_filePath.isEmpty())
            return;
        setBusy(true);
        QDir().mkpath(cacheDir());
        const QString prefix = cacheDir() + QLatin1Char('/')
                               + QString::number(qHash(m_filePath))
                               + QStringLiteral("-p") + QString::number(m_page);
        const QString target = prefix + QStringLiteral(".png");
        const QFileInfo pdfInfo(m_filePath);
        const QFileInfo pngInfo(target);
        const bool cached = pngInfo.exists() && pngInfo.size() > 0
                            && pngInfo.lastModified() >= pdfInfo.lastModified();

        if (!cached) {
            QProcess process;
            process.start(QStringLiteral("pdftoppm"),
                          {QStringLiteral("-png"), QStringLiteral("-r"),
                           QStringLiteral("140"), QStringLiteral("-f"),
                           QString::number(m_page), QStringLiteral("-l"),
                           QString::number(m_page), QStringLiteral("-singlefile"),
                           m_filePath, prefix});
            if (!process.waitForFinished(60000)
                || process.exitStatus() != QProcess::NormalExit
                || process.exitCode() != 0
                || !QFileInfo::exists(target)) {
                process.kill();
                setBusy(false);
                setStatus(false, QStringLiteral("Could not render page %1").arg(m_page));
                return;
            }
        }

        m_renderPath = target;
        ++m_renderToken;
        emit renderChanged();
        setBusy(false);
        setStatus(true, QStringLiteral("Page %1 of %2").arg(m_page).arg(m_pageCount));
    }

    void setStatus(bool ok, const QString &message)
    {
        m_ok = ok;
        m_status = message;
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
    int m_pageCount = 0;
    int m_page = 1;
    QString m_renderPath;
    int m_renderToken = 0;
    QString m_status = QStringLiteral("Ready");
    bool m_ok = true;
    bool m_busy = false;
};

int main(int argc, char *argv[])
{
    qputenv("QT_QUICK_BACKEND", "software");

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("elvonos-pdf"));
    app.setOrganizationName(QStringLiteral("ElvonOS"));
    app.setDesktopFileName(QStringLiteral("elvonos-pdf"));

    PdfModel model;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("pdf"), &model);
    engine.load(QUrl(QStringLiteral("qrc:/Pdf.qml")));
    if (engine.rootObjects().isEmpty())
        return 1;

    const QString openPath = qEnvironmentVariable("ELVONOS_PDF_OPEN");
    if (!openPath.isEmpty()) {
        QTimer::singleShot(400, &model, [&model, openPath]() {
            model.open(openPath);
        });
    }
    return app.exec();
}

#include "main.moc"

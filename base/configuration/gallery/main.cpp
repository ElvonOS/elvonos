#include <QAbstractListModel>
#include <QDateTime>
#include <QDesktopServices>
#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QGuiApplication>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>
#include <QVariantMap>

#include <algorithm>
#include "../common/elvonapp.h"

namespace {

struct ImageEntry {
    QString name;
    QString path;
    QString url;
    QString folder;
    QString sizeText;
    QString modified;
    qint64 size = 0;
    QDateTime modifiedTime;
};

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

bool isImage(const QFileInfo &info)
{
    static const QStringList suffixes{"png", "jpg", "jpeg", "webp", "gif", "bmp",
                                      "avif", "svg", "tif", "tiff"};
    return info.isFile() && info.size() > 0
           && suffixes.contains(info.suffix().toLower());
}

} // namespace

class ImageModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(QString folder READ folder WRITE setFolder NOTIFY folderChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(QString filter READ filter WRITE setFilter NOTIFY filterChanged)

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        PathRole,
        UrlRole,
        SizeRole,
        ModifiedRole,
        FolderRole,
    };

    explicit ImageModel(QObject *parent = nullptr) : QAbstractListModel(parent)
    {
        m_watcher.setParent(this);
        connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] {
            QTimer::singleShot(200, this, &ImageModel::refresh);
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
        const ImageEntry &entry = m_entries.at(index.row());
        switch (role) {
        case NameRole:
            return entry.name;
        case PathRole:
            return entry.path;
        case UrlRole:
            return entry.url;
        case SizeRole:
            return entry.sizeText;
        case ModifiedRole:
            return entry.modified;
        case FolderRole:
            return entry.folder;
        default:
            return {};
        }
    }

    QHash<int, QByteArray> roleNames() const override
    {
        return {
            {NameRole, "name"},
            {PathRole, "path"},
            {UrlRole, "url"},
            {SizeRole, "sizeText"},
            {ModifiedRole, "modified"},
            {FolderRole, "folder"},
        };
    }

    QString folder() const { return m_folder; }
    QString error() const { return appTr(m_error); }
    QString filter() const { return m_filter; }

    void setFolder(const QString &value)
    {
        const QString clean = QDir::cleanPath(value);
        if (clean == m_folder)
            return;
        m_folder = clean;
        m_filter.clear();
        emit folderChanged();
        emit filterChanged();
        refresh();
    }

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
        m_error.clear();

        QDir dir(m_folder);
        if (m_folder.isEmpty() || !dir.exists()) {
            m_error = appTr(QStringLiteral("This album is not available."));
            rebuild();
            emit errorChanged();
            return;
        }

        QDirIterator iterator(m_folder,
                              {"*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif", "*.bmp",
                               "*.avif", "*.svg", "*.tif", "*.tiff"},
                              QDir::Files | QDir::Readable, QDirIterator::Subdirectories);
        int visited = 0;
        while (iterator.hasNext() && m_all.size() < 1500 && visited < 20000) {
            ++visited;
            const QString path = iterator.next();
            if (path.contains("/.") || path.contains("/.cache/"))
                continue;
            const QFileInfo info(path);
            if (!isImage(info))
                continue;
            ImageEntry entry;
            entry.name = info.fileName();
            entry.path = info.absoluteFilePath();
            entry.url = "file://" + entry.path;
            entry.folder = info.absolutePath();
            entry.size = info.size();
            entry.sizeText = humanSize(info.size());
            entry.modifiedTime = info.lastModified();
            entry.modified = entry.modifiedTime.toString("yyyy-MM-dd HH:mm");
            m_all.append(entry);
        }

        std::sort(m_all.begin(), m_all.end(), [](const ImageEntry &a, const ImageEntry &b) {
            return a.modifiedTime > b.modifiedTime;
        });

        rebuild();
        emit errorChanged();

        const QStringList watched = m_watcher.directories();
        if (!watched.contains(m_folder)) {
            if (!watched.isEmpty())
                m_watcher.removePaths(watched);
            m_watcher.addPath(m_folder);
        }
    }

    Q_INVOKABLE QString urlAt(int index) const
    {
        return index >= 0 && index < m_entries.size() ? m_entries.at(index).url : QString();
    }

    Q_INVOKABLE void clear()
    {
        m_all.clear();
        m_error.clear();
        m_folder.clear();
        rebuild();
        emit folderChanged();
        emit errorChanged();
    }

    Q_INVOKABLE QString nameAt(int index) const
    {
        return index >= 0 && index < m_entries.size() ? m_entries.at(index).name : QString();
    }

    Q_INVOKABLE QString pathAt(int index) const
    {
        return index >= 0 && index < m_entries.size() ? m_entries.at(index).path : QString();
    }

    Q_INVOKABLE QString sizeAt(int index) const
    {
        return index >= 0 && index < m_entries.size() ? m_entries.at(index).sizeText : QString();
    }

    Q_INVOKABLE QString modifiedAt(int index) const
    {
        return index >= 0 && index < m_entries.size() ? m_entries.at(index).modified : QString();
    }

    Q_INVOKABLE void openExternally(int index) const
    {
        if (index >= 0 && index < m_entries.size())
            QDesktopServices::openUrl(QUrl::fromLocalFile(m_entries.at(index).path));
    }

signals:
    void folderChanged();
    void countChanged();
    void errorChanged();
    void filterChanged();

private:
    void rebuild()
    {
        QList<ImageEntry> filtered;
        const QString needle = m_filter.trimmed();
        for (const ImageEntry &entry : std::as_const(m_all)) {
            if (!needle.isEmpty()
                && !entry.name.contains(needle, Qt::CaseInsensitive)
                && !entry.folder.contains(needle, Qt::CaseInsensitive))
                continue;
            filtered.append(entry);
        }
        beginResetModel();
        m_entries = filtered;
        endResetModel();
        emit countChanged();
    }

    QString m_folder;
    QString m_error;
    QString m_filter;
    QList<ImageEntry> m_all;
    QList<ImageEntry> m_entries;
    QFileSystemWatcher m_watcher;
};

class GalleryApi : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString home READ home CONSTANT)
    Q_PROPERTY(QString pictures READ pictures CONSTANT)
    Q_PROPERTY(QString desktop READ desktop CONSTANT)
    Q_PROPERTY(QString downloads READ downloads CONSTANT)
    Q_PROPERTY(QString wallpapers READ wallpapers CONSTANT)
    Q_PROPERTY(QString androidRoot READ androidRoot NOTIFY androidChanged)
    Q_PROPERTY(bool androidReady READ androidReady NOTIFY androidChanged)

public:
    using QObject::QObject;

    QString home() const { return QStandardPaths::writableLocation(QStandardPaths::HomeLocation); }
    QString pictures() const { return QStandardPaths::writableLocation(QStandardPaths::PicturesLocation); }
    QString desktop() const { return QStandardPaths::writableLocation(QStandardPaths::DesktopLocation); }
    QString downloads() const { return QStandardPaths::writableLocation(QStandardPaths::DownloadLocation); }
    QString wallpapers() const { return QStringLiteral("/usr/share/backgrounds/elvonos"); }

    QString androidRoot() const
    {
        const QString mounted = "/run/elvonos/waydroid";
        if (QDir(mounted).exists())
            return mounted;
        const QString raw = "/var/lib/waydroid/data/media/0";
        if (QDir(raw).exists())
            return raw;
        return {};
    }

    bool androidReady() const { return !androidRoot().isEmpty(); }

    Q_INVOKABLE QString ensureAndroidStorage()
    {
        QProcess process;
        process.start("elvonos-waydroid-storage");
        process.waitForFinished(8000);
        emit androidChanged();
        return androidRoot();
    }

    Q_INVOKABLE QString androidPath(const QString &sub) const
    {
        const QString root = androidRoot();
        if (root.isEmpty())
            return {};
        return root + "/" + sub;
    }

    Q_INVOKABLE bool dirExists(const QString &path) const
    {
        return !path.isEmpty() && QDir(path).exists();
    }

    Q_INVOKABLE QString humanSize(qint64 bytes) const { return ::humanSize(bytes); }

    Q_INVOKABLE QVariantMap properties(const QString &path) const
    {
        QVariantMap map;
        const QFileInfo info(path);
        if (!info.exists())
            return map;
        map.insert("name", info.fileName());
        map.insert("size", humanSize(info.size()));
        map.insert("modified", info.lastModified().toString("yyyy-MM-dd HH:mm"));
        map.insert("folder", info.absolutePath());
        return map;
    }

    Q_INVOKABLE void quit() { QCoreApplication::quit(); }

signals:
    void androidChanged();
};

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    AppLang lang;
    AppTheme theme;
    appLangInstance() = &lang;
    app.setApplicationName(QStringLiteral("elvonos-gallery"));
    app.setApplicationDisplayName(QStringLiteral("Gallery"));
    app.setDesktopFileName(QStringLiteral("elvonos-gallery"));

    ImageModel images;
    GalleryApi api;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("lang"), &lang);
    engine.rootContext()->setContextProperty(QStringLiteral("theme"), &theme);
    engine.rootContext()->setContextProperty("imageModel", &images);
    engine.rootContext()->setContextProperty("gallery", &api);

    engine.load(QUrl("qrc:/Gallery.qml"));
    if (engine.rootObjects().isEmpty())
        return -1;
    return app.exec();
}

#include "main.moc"

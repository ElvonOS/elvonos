#include <QAbstractListModel>
#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QStandardPaths>
#include <QUrl>
#include <QVariantMap>

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

qint64 pathSize(const QString &path)
{
    const QFileInfo info(path);
    if (!info.exists() || info.isSymLink())
        return 0;
    if (info.isFile())
        return info.size();
    qint64 total = 0;
    QDirIterator it(path, QDir::Files | QDir::NoSymLinks, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        it.next();
        total += it.fileInfo().size();
    }
    return total;
}

bool removePath(const QString &path)
{
    const QFileInfo info(path);
    if (!info.exists() || info.isSymLink())
        return QFile::remove(path);
    if (info.isDir())
        return QDir(path).removeRecursively();
    return QFile::remove(path);
}

void clearContents(const QString &path)
{
    QDir dir(path);
    if (!dir.exists())
        return;
    const QFileInfoList entries = dir.entryInfoList(
        QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System);
    for (const QFileInfo &entry : entries)
        removePath(entry.absoluteFilePath());
}

} // namespace

class CleanerModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY categoriesChanged)
    Q_PROPERTY(int selectedCount READ selectedCount NOTIFY categoriesChanged)
    Q_PROPERTY(qint64 reclaimable READ reclaimable NOTIFY categoriesChanged)
    Q_PROPERTY(QString reclaimableText READ reclaimableText NOTIFY categoriesChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString output READ output NOTIFY outputChanged)
    Q_PROPERTY(QString result READ result NOTIFY resultChanged)
    Q_PROPERTY(bool resultOk READ resultOk NOTIFY resultChanged)
    Q_PROPERTY(QString lastFreedText READ lastFreedText NOTIFY resultChanged)

public:
    enum Roles {
        LabelRole = Qt::UserRole + 1,
        DescriptionRole,
        SizeRole,
        SizeTextRole,
        CheckedRole,
        IdRole,
    };

    explicit CleanerModel(QObject *parent = nullptr) : QAbstractListModel(parent)
    {
        const QString home = QDir::homePath();
        m_categories = {
            {QStringLiteral("cache"), QStringLiteral("Application cache"),
             QStringLiteral("Contents of ~/.cache (thumbnails, browser and app caches)"),
             0, true},
            {QStringLiteral("trash"), QStringLiteral("Trash"),
             QStringLiteral("Files and metadata in ~/.local/share/Trash"),
             0, true},
            {QStringLiteral("temp"), QStringLiteral("Temporary files"),
             QStringLiteral("Your files in /tmp and /var/tmp older than 24 hours"),
             0, false},
            {QStringLiteral("apt"), QStringLiteral("APT package cache"),
             QStringLiteral("Downloaded .deb packages in /var/cache/apt/archives"),
             0, false},
            {QStringLiteral("logs"), QStringLiteral("Rotated logs"),
             QStringLiteral("Old .gz/.old/rotated log files in /var/log"),
             0, false},
        };
        Q_UNUSED(home);
        scan();
    }

    int rowCount(const QModelIndex &parent = QModelIndex()) const override
    {
        return parent.isValid() ? 0 : m_categories.size();
    }

    QVariant data(const QModelIndex &index, int role) const override
    {
        if (!index.isValid() || index.row() < 0 || index.row() >= m_categories.size())
            return {};
        const Category &c = m_categories.at(index.row());
        switch (role) {
        case LabelRole:
            return appTr(c.label);
        case DescriptionRole:
            return appTr(c.description);
        case SizeRole:
            return c.bytes;
        case SizeTextRole:
            return humanSize(c.bytes);
        case CheckedRole:
            return c.checked;
        case IdRole:
            return c.id;
        default:
            return {};
        }
    }

    QHash<int, QByteArray> roleNames() const override
    {
        return {
            {LabelRole, "label"},
            {DescriptionRole, "description"},
            {SizeRole, "bytes"},
            {SizeTextRole, "sizeText"},
            {CheckedRole, "checked"},
            {IdRole, "id"},
        };
    }

    int selectedCount() const
    {
        int n = 0;
        for (const Category &c : m_categories) {
            if (c.checked)
                ++n;
        }
        return n;
    }

    qint64 reclaimable() const
    {
        qint64 total = 0;
        for (const Category &c : m_categories) {
            if (c.checked)
                total += c.bytes;
        }
        return total;
    }

    QString reclaimableText() const { return humanSize(reclaimable()); }
    bool busy() const { return m_busy; }
    QString output() const { return m_output; }
    QString result() const { return appTr(m_result); }
    bool resultOk() const { return m_resultOk; }
    QString lastFreedText() const { return m_lastFreedText; }

    Q_INVOKABLE void setChecked(int index, bool checked)
    {
        if (index < 0 || index >= m_categories.size())
            return;
        if (m_categories[index].checked == checked)
            return;
        m_categories[index].checked = checked;
        emit dataChanged(this->index(index), this->index(index), {CheckedRole});
        emit categoriesChanged();
    }

    Q_INVOKABLE void scan()
    {
        beginResetModel();
        for (Category &c : m_categories)
            c.bytes = measure(c);
        endResetModel();
        emit categoriesChanged();
        if (m_lastFreedText.isEmpty())
            setResult(true, "");
    }

    Q_INVOKABLE void cleanSelected()
    {
        if (m_busy)
            return;
        setBusy(true);
        m_output.clear();
        emit outputChanged();
        setResult(true, "");

        const QString home = QDir::homePath();
        qint64 freed = 0;
        int cleaned = 0;
        QStringList errors;

        const QList<Category> selected = [this] {
            QList<Category> list;
            for (const Category &c : m_categories) {
                if (c.checked && c.bytes > 0)
                    list.append(c);
            }
            return list;
        }();

        for (const Category &c : selected) {
            appendOutput(appTr(QStringLiteral("Cleaning ")) + c.label + " (" + humanSize(c.bytes) + ")…\n");
            QCoreApplication::processEvents();
            bool ok = false;
            if (c.id == "cache") {
                clearContents(home + "/.cache");
                ok = true;
            } else if (c.id == "trash") {
                clearContents(home + "/.local/share/Trash/files");
                clearContents(home + "/.local/share/Trash/info");
                ok = true;
            } else if (c.id == "temp") {
                ok = cleanTempDirectories();
            } else if (c.id == "apt") {
                ok = runSudo({"find", "/var/cache/apt/archives", "-maxdepth", "1",
                              "-type", "f", "(", "-name", "*.deb", "-o",
                              "-name", "*.partial", ")", "-delete"});
            } else if (c.id == "logs") {
                ok = runSudo({"find", "/var/log", "-maxdepth", "1", "-type", "f",
                              "(", "-name", "*.gz", "-o", "-name", "*.old", "-o",
                              "-name", "*.[0-9]", "-o", "-name", "*.[0-9].gz",
                              ")", "-delete"});
            }
            if (ok) {
                freed += c.bytes;
                ++cleaned;
                appendOutput("  done.\n");
            } else {
                errors.append(c.label);
                appendOutput("  failed.\n");
            }
        }

        scan();
        if (errors.isEmpty()) {
            m_lastFreedText = humanSize(freed);
            setResult(true, cleaned == 0
                             ? "Nothing to clean."
                             : "Freed " + humanSize(freed) + " in " + QString::number(cleaned)
                               + (cleaned == 1 ? " category." : " categories."));
        } else {
            m_lastFreedText = humanSize(freed);
            setResult(false, appTr(QStringLiteral("Some categories could not be cleaned: "))
                              + errors.join(", "));
        }
        setBusy(false);
    }

signals:
    void categoriesChanged();
    void busyChanged();
    void outputChanged();
    void resultChanged();

private:
    struct Category {
        QString id;
        QString label;
        QString description;
        qint64 bytes = 0;
        bool checked = true;
    };

    qint64 measure(const Category &c) const
    {
        const QString home = QDir::homePath();
        if (c.id == "cache")
            return pathSize(home + "/.cache");
        if (c.id == "trash")
            return pathSize(home + "/.local/share/Trash/files")
                   + pathSize(home + "/.local/share/Trash/info");
        if (c.id == "temp")
            return tempSize();
        if (c.id == "apt")
            return aptSize();
        if (c.id == "logs")
            return logSize();
        return 0;
    }

    bool isOld(const QFileInfo &info) const
    {
        return info.lastModified() < QDateTime::currentDateTime().addDays(-1);
    }

    qint64 tempSize() const
    {
        qint64 total = 0;
        for (const QString &dir : {QStringLiteral("/tmp"), QStringLiteral("/var/tmp")}) {
            const QFileInfoList entries = QDir(dir).entryInfoList(
                QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System);
            for (const QFileInfo &entry : entries) {
                if (entry.ownerId() == getuid() && isOld(entry))
                    total += pathSize(entry.absoluteFilePath());
            }
        }
        return total;
    }

    qint64 aptSize() const
    {
        qint64 total = 0;
        const QFileInfoList files = QDir("/var/cache/apt/archives").entryInfoList(
            {"*.deb", "*.partial"}, QDir::Files | QDir::NoSymLinks);
        for (const QFileInfo &file : files)
            total += file.size();
        return total;
    }

    qint64 logSize() const
    {
        qint64 total = 0;
        const QFileInfoList files = QDir("/var/log").entryInfoList(
            QDir::Files | QDir::NoSymLinks);
        for (const QFileInfo &file : files) {
            const QString name = file.fileName();
            if (name.endsWith(".gz") || name.endsWith(".old")
                || (name.lastIndexOf('.') > 0
                    && name.mid(name.lastIndexOf('.') + 1).toInt() > 0))
                total += file.size();
        }
        return total;
    }

    bool cleanTempDirectories()
    {
        bool ok = true;
        for (const QString &dir : {QStringLiteral("/tmp"), QStringLiteral("/var/tmp")}) {
            const QFileInfoList entries = QDir(dir).entryInfoList(
                QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System);
            for (const QFileInfo &entry : entries) {
                if (entry.ownerId() == getuid() && isOld(entry)) {
                    if (!removePath(entry.absoluteFilePath()))
                        ok = false;
                }
            }
        }
        return ok;
    }

    bool runSudo(const QStringList &arguments)
    {
        QProcess process;
        process.setProcessChannelMode(QProcess::MergedChannels);
        process.start("sudo", QStringList{"-n"} + arguments);
        if (!process.waitForFinished(60000)) {
            process.kill();
            return false;
        }
        const QByteArray output = process.readAll();
        if (!output.isEmpty())
            appendOutput(QString::fromUtf8(output));
        return process.exitStatus() == QProcess::NormalExit && process.exitCode() == 0;
    }

    void appendOutput(const QString &text)
    {
        m_output += text;
        if (m_output.size() > 120000)
            m_output = m_output.right(120000);
        emit outputChanged();
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
        if (m_result == message && m_resultOk == ok)
            return;
        m_result = appTr(message);
        m_resultOk = ok;
        emit resultChanged();
    }

    QList<Category> m_categories;
    bool m_busy = false;
    bool m_resultOk = true;
    QString m_output;
    QString m_result;
    QString m_lastFreedText;
};

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    AppLang lang;
    AppTheme theme;
    appLangInstance() = &lang;
    app.setApplicationName(QStringLiteral("elvonos-cleaner"));
    app.setApplicationDisplayName(QStringLiteral("Cleaner"));
    app.setDesktopFileName(QStringLiteral("elvonos-cleaner"));

    CleanerModel cleaner;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("lang"), &lang);
    engine.rootContext()->setContextProperty(QStringLiteral("theme"), &theme);
    engine.rootContext()->setContextProperty("cleanerModel", &cleaner);

    engine.load(QUrl("qrc:/Cleaner.qml"));
    if (engine.rootObjects().isEmpty())
        return -1;
    return app.exec();
}

#include "main.moc"

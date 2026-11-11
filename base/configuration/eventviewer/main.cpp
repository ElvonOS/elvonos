#include <QAbstractListModel>
#include <QClipboard>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QStandardPaths>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include "../common/elvonapp.h"

namespace {

struct Entry {
    QString key;
    QString timeText;
    QString timeFull;
    int priority = 6;
    QString level;
    QString source;
    QString identifier;
    QString unit;
    QString message;
    QString pid;
    QString host;
    QString boot;
    QString code;
    QString exe;
    QString transport;
};

QString stringValue(const QJsonObject &object, const char *key)
{
    const QJsonValue value = object.value(QLatin1String(key));
    if (value.isString())
        return value.toString();
    if (value.isDouble())
        return QString::number(value.toInt());
    return {};
}

int intValue(const QJsonObject &object, const char *key, int fallback)
{
    const QJsonValue value = object.value(QLatin1String(key));
    if (value.isDouble())
        return value.toInt();
    if (value.isString())
        return value.toString().toInt();
    return fallback;
}

QString messageValue(const QJsonValue &value)
{
    if (value.isString())
        return value.toString();
    if (value.isArray()) {
        const QJsonArray bytes = value.toArray();
        QByteArray raw;
        raw.reserve(bytes.size());
        for (const QJsonValue &byte : bytes)
            raw.append(static_cast<char>(byte.toInt()));
        return QString::fromUtf8(raw);
    }
    return {};
}

QString levelFor(int priority)
{
    if (priority <= 3)
        return QStringLiteral("Error");
    if (priority == 4)
        return QStringLiteral("Warning");
    if (priority == 5)
        return QStringLiteral("Notice");
    if (priority == 6)
        return QStringLiteral("Info");
    return QStringLiteral("Debug");
}

bool isAuthIdentifier(const QString &identifier)
{
    static const QStringList identifiers = {
        QStringLiteral("sudo"),       QStringLiteral("su"),
        QStringLiteral("sshd"),       QStringLiteral("login"),
        QStringLiteral("systemd-logind"), QStringLiteral("polkitd"),
        QStringLiteral("gdm"),        QStringLiteral("gdm3"),
        QStringLiteral("greetd"),     QStringLiteral("pam_unix"),
        QStringLiteral("cron"),       QStringLiteral("CRON"),
    };
    return identifiers.contains(identifier);
}

QString sourceFor(const QJsonObject &object)
{
    const QString transport = stringValue(object, "_TRANSPORT");
    const QString identifier = stringValue(object, "SYSLOG_IDENTIFIER");
    const QString unit = stringValue(object, "_SYSTEMD_UNIT");
    if (transport == QStringLiteral("kernel")
        || identifier == QStringLiteral("kernel"))
        return QStringLiteral("Kernel");
    if (isAuthIdentifier(identifier) || isAuthIdentifier(stringValue(object, "_COMM")))
        return QStringLiteral("Auth");
    if (!unit.isEmpty())
        return QStringLiteral("System");
    return QStringLiteral("Apps");
}

bool matchesSource(const Entry &entry, int filter)
{
    switch (filter) {
    case 1:
        return entry.source == QStringLiteral("System");
    case 2:
        return entry.source == QStringLiteral("Kernel");
    case 3:
        return entry.source == QStringLiteral("Auth");
    case 4:
        return entry.source == QStringLiteral("Apps");
    default:
        return true;
    }
}

} // namespace

class EventModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(bool ok READ ok NOTIFY statusChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString lastRefresh READ lastRefresh NOTIFY statusChanged)
    Q_PROPERTY(QString search READ search WRITE setSearch NOTIFY searchChanged)
    Q_PROPERTY(int levelFilter READ levelFilter WRITE setLevelFilter NOTIFY levelFilterChanged)
    Q_PROPERTY(int sourceFilter READ sourceFilter WRITE setSourceFilter NOTIFY sourceFilterChanged)
    Q_PROPERTY(bool currentBoot READ currentBoot WRITE setCurrentBoot NOTIFY currentBootChanged)

public:
    enum Roles {
        KeyRole = Qt::UserRole + 1,
        TimeRole,
        LevelRole,
        SourceRole,
        IdentifierRole,
        UnitRole,
        MessageRole,
        PidRole,
    };

    explicit EventModel(QObject *parent = nullptr)
        : QAbstractListModel(parent)
    {
        m_lastRefresh = QStringLiteral("never");
    }

    int rowCount(const QModelIndex &parent = QModelIndex()) const override
    {
        return parent.isValid() ? 0 : m_visible.size();
    }

    QVariant data(const QModelIndex &index, int role) const override
    {
        if (!index.isValid() || index.row() < 0 || index.row() >= m_visible.size())
            return {};
        const Entry &entry = m_visible.at(index.row());
        switch (role) {
        case KeyRole:
            return entry.key;
        case TimeRole:
            return entry.timeText;
        case LevelRole:
            return entry.level;
        case SourceRole:
            return entry.source;
        case IdentifierRole:
            return entry.identifier;
        case UnitRole:
            return entry.unit;
        case MessageRole:
            return entry.message;
        case PidRole:
            return entry.pid;
        default:
            return {};
        }
    }

    QHash<int, QByteArray> roleNames() const override
    {
        return {
            {KeyRole, "key"},
            {TimeRole, "time"},
            {LevelRole, "level"},
            {SourceRole, "source"},
            {IdentifierRole, "identifier"},
            {UnitRole, "unit"},
            {MessageRole, "message"},
            {PidRole, "pid"},
        };
    }

    bool busy() const { return m_busy; }
    bool ok() const { return m_ok; }
    QString status() const { return appTr(m_status); }
    QString lastRefresh() const { return m_lastRefresh; }
    QString search() const { return m_search; }
    int levelFilter() const { return m_levelFilter; }
    int sourceFilter() const { return m_sourceFilter; }
    bool currentBoot() const { return m_currentBoot; }

    void setSearch(const QString &search)
    {
        if (m_search == search)
            return;
        m_search = search;
        emit searchChanged();
        rebuildVisible();
    }

    void setLevelFilter(int filter)
    {
        if (m_levelFilter == filter)
            return;
        m_levelFilter = filter;
        emit levelFilterChanged();
        rebuildVisible();
    }

    void setSourceFilter(int filter)
    {
        if (m_sourceFilter == filter)
            return;
        m_sourceFilter = filter;
        emit sourceFilterChanged();
        rebuildVisible();
    }

    void setCurrentBoot(bool current)
    {
        if (m_currentBoot == current)
            return;
        m_currentBoot = current;
        emit currentBootChanged();
        QTimer::singleShot(0, this, &EventModel::refresh);
    }

    Q_INVOKABLE void refresh()
    {
        if (m_busy)
            return;
        setBusy(true);
        setStatus(true, QStringLiteral("Reading the journal…"));

        QStringList arguments = {
            QStringLiteral("--no-pager"),
            QStringLiteral("-o"), QStringLiteral("json"),
            QStringLiteral("-r"),
            QStringLiteral("-n"), QStringLiteral("800"),
            QStringLiteral("--output-fields=__REALTIME_TIMESTAMP,PRIORITY,MESSAGE,"
                           "SYSLOG_IDENTIFIER,_COMM,_PID,_SYSTEMD_UNIT,_HOSTNAME,"
                           "_BOOT_ID,_TRANSPORT,_EXE,CODE_FILE,CODE_LINE"),
        };
        if (m_currentBoot)
            arguments << QStringLiteral("-b") << QStringLiteral("0");

        QByteArray output;
        QString error;
        if (!runJournal(arguments, &output, &error)) {
            setBusy(false);
            setStatus(false, error.isEmpty()
                                ? QStringLiteral("Could not read the journal")
                                : error);
            emit refreshed();
            return;
        }

        QList<Entry> entries;
        const QList<QByteArray> lines = output.split('\n');
        entries.reserve(lines.size());
        for (const QByteArray &line : lines) {
            const QByteArray trimmed = line.trimmed();
            if (trimmed.isEmpty())
                continue;
            QJsonParseError parseError{};
            const QJsonDocument document = QJsonDocument::fromJson(trimmed, &parseError);
            if (parseError.error != QJsonParseError::NoError || !document.isObject())
                continue;
            const QJsonObject object = document.object();

            Entry entry;
            const QString usec = stringValue(object, "__REALTIME_TIMESTAMP");
            const qint64 micros = usec.toLongLong();
            const QDateTime timestamp =
                usec.isEmpty() ? QDateTime::currentDateTime()
                               : QDateTime::fromMSecsSinceEpoch(micros / 1000);
            entry.timeText = timestamp.toString(QStringLiteral("HH:mm:ss"));
            entry.timeFull = timestamp.toString(QStringLiteral("yyyy-MM-dd HH:mm:ss"));
            entry.priority = intValue(object, "PRIORITY", 6);
            entry.level = levelFor(entry.priority);
            entry.source = sourceFor(object);
            entry.identifier = stringValue(object, "SYSLOG_IDENTIFIER");
            if (entry.identifier.isEmpty())
                entry.identifier = stringValue(object, "_COMM");
            entry.unit = stringValue(object, "_SYSTEMD_UNIT");
            entry.message = messageValue(object.value(QStringLiteral("MESSAGE"))).trimmed();
            if (entry.message.isEmpty())
                entry.message = QStringLiteral("(no message)");
            entry.pid = stringValue(object, "_PID");
            entry.host = stringValue(object, "_HOSTNAME");
            entry.boot = stringValue(object, "_BOOT_ID");
            entry.transport = stringValue(object, "_TRANSPORT");
            entry.exe = stringValue(object, "_EXE");
            entry.code = stringValue(object, "CODE_FILE");
            const QString codeLine = stringValue(object, "CODE_LINE");
            if (!codeLine.isEmpty()) {
                if (!entry.code.isEmpty())
                    entry.code += QLatin1Char(':');
                entry.code += codeLine;
            }
            entry.key = usec + QLatin1Char('|') + entry.identifier
                        + QLatin1Char('|') + entry.pid;
            entries.append(entry);
        }

        m_all = entries;
        rebuildVisible();
        m_lastRefresh = QDateTime::currentDateTime()
                            .toString(QStringLiteral("HH:mm:ss"));
        emit statusChanged();
        setBusy(false);
        emit refreshed();
    }

    Q_INVOKABLE QVariantMap details(int index) const
    {
        QVariantMap result;
        if (index < 0 || index >= m_visible.size())
            return result;
        const Entry &entry = m_visible.at(index);
        result.insert(QStringLiteral("time"), entry.timeFull);
        result.insert(QStringLiteral("level"), entry.level);
        result.insert(QStringLiteral("priority"), entry.priority);
        result.insert(QStringLiteral("source"), entry.source);
        result.insert(QStringLiteral("unit"), entry.unit);
        result.insert(QStringLiteral("identifier"), entry.identifier);
        result.insert(QStringLiteral("pid"), entry.pid);
        result.insert(QStringLiteral("host"), entry.host);
        result.insert(QStringLiteral("boot"), entry.boot.left(12));
        result.insert(QStringLiteral("transport"), entry.transport);
        result.insert(QStringLiteral("exe"), entry.exe);
        result.insert(QStringLiteral("code"), entry.code);
        result.insert(QStringLiteral("message"), entry.message);
        return result;
    }

    Q_INVOKABLE QString keyAt(int index) const
    {
        if (index < 0 || index >= m_visible.size())
            return {};
        return m_visible.at(index).key;
    }

    Q_INVOKABLE int indexOfKey(const QString &key) const
    {
        if (key.isEmpty())
            return -1;
        for (int i = 0; i < m_visible.size(); ++i) {
            if (m_visible.at(i).key == key)
                return i;
        }
        return -1;
    }

    Q_INVOKABLE void copyMessage(int index)
    {
        if (index < 0 || index >= m_visible.size())
            return;
        QGuiApplication::clipboard()->setText(m_visible.at(index).message);
        setStatus(true, QStringLiteral("Message copied to the clipboard"));
    }

    Q_INVOKABLE QString saveVisible()
    {
        if (m_visible.isEmpty()) {
            setStatus(false, QStringLiteral("No events to save"));
            return {};
        }
        QString directory =
            QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
        if (directory.isEmpty())
            directory = QDir::homePath();
        QDir().mkpath(directory);
        const QString path = directory + QStringLiteral("/ElvonOS-events-")
                             + QDateTime::currentDateTime().toString(
                                 QStringLiteral("yyyy-MM-dd_HH-mm-ss"))
                             + QStringLiteral(".log");
        QFile file(path);
        if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            setStatus(false, appTr(QStringLiteral("Could not write %1")).arg(path));
            return {};
        }
        file.write("ElvonOS Event Viewer export\n");
        file.write(QStringLiteral("Boot mode: %1\n\n")
                       .arg(m_currentBoot ? QStringLiteral("current")
                                          : QStringLiteral("all"))
                       .toUtf8());
        for (const Entry &entry : m_visible) {
            const QString line =
                QStringLiteral("%1  %2  %3  %4  %5  %6\n")
                    .arg(entry.timeFull, entry.level, entry.source,
                         entry.identifier, entry.pid, entry.message);
            file.write(line.toUtf8());
        }
        file.close();
        setStatus(true, appTr(QStringLiteral("Saved %1 events to %2"))
                            .arg(m_visible.size()).arg(path));
        return path;
    }

signals:
    void countChanged();
    void busyChanged();
    void statusChanged();
    void searchChanged();
    void levelFilterChanged();
    void sourceFilterChanged();
    void currentBootChanged();
    void refreshed();

private:
    bool runJournal(const QStringList &arguments, QByteArray *output,
                    QString *error)
    {
        QProcess process;
        process.start(QStringLiteral("sudo"),
                      QStringList{QStringLiteral("-n"), QStringLiteral("journalctl")}
                          + arguments);
        if (!process.waitForFinished(20000)
            || process.exitStatus() != QProcess::NormalExit
            || process.exitCode() != 0) {
            process.kill();
            process.waitForFinished(1000);
            process.start(QStringLiteral("journalctl"), arguments);
            if (!process.waitForFinished(20000)) {
                process.kill();
                process.waitForFinished(1000);
                *error = QStringLiteral("The journal did not answer in time");
                return false;
            }
        }
        if (process.exitStatus() != QProcess::NormalExit
            || process.exitCode() != 0) {
            *error = QString::fromUtf8(process.readAllStandardError()).trimmed();
            if (error->isEmpty())
                *error = QStringLiteral("journalctl is not available");
            return false;
        }
        *output = process.readAllStandardOutput();
        return true;
    }

    bool accepts(const Entry &entry) const
    {
        switch (m_levelFilter) {
        case 1:
            if (entry.priority > 3)
                return false;
            break;
        case 2:
            if (entry.priority != 4)
                return false;
            break;
        case 3:
            if (entry.priority < 5)
                return false;
            break;
        default:
            break;
        }
        if (!matchesSource(entry, m_sourceFilter))
            return false;
        if (!m_search.isEmpty()) {
            const auto contains = [this](const QString &text) {
                return text.contains(m_search, Qt::CaseInsensitive);
            };
            if (!contains(entry.message) && !contains(entry.identifier)
                && !contains(entry.unit) && !contains(entry.source))
                return false;
        }
        return true;
    }

    void rebuildVisible()
    {
        beginResetModel();
        m_visible.clear();
        for (const Entry &entry : m_all) {
            if (accepts(entry))
                m_visible.append(entry);
        }
        endResetModel();
        emit countChanged();
        updateStatus();
    }

    void updateStatus()
    {
        m_status = appTr(QStringLiteral("%1 of %2 events · %3"))
                       .arg(m_visible.size())
                       .arg(m_all.size())
                       .arg(m_currentBoot ? appTr(QStringLiteral("current boot"))
                                          : appTr(QStringLiteral("all boots")));
        emit statusChanged();
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

    QList<Entry> m_all;
    QList<Entry> m_visible;
    QString m_status = QStringLiteral("Ready");
    QString m_lastRefresh;
    QString m_search;
    int m_levelFilter = 0;
    int m_sourceFilter = 0;
    bool m_currentBoot = true;
    bool m_busy = false;
    bool m_ok = true;
};

int main(int argc, char *argv[])
{
    qputenv("QT_QUICK_BACKEND", "software");

    QGuiApplication app(argc, argv);

    AppLang lang;
    AppTheme theme;
    appLangInstance() = &lang;
    app.setApplicationName(QStringLiteral("elvonos-eventviewer"));
    app.setDesktopFileName(QStringLiteral("elvonos-eventviewer"));

    EventModel model;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("lang"), &lang);
    engine.rootContext()->setContextProperty(QStringLiteral("theme"), &theme);
    engine.rootContext()->setContextProperty(QStringLiteral("events"), &model);
    engine.load(QUrl(QStringLiteral("qrc:/EventViewer.qml")));
    if (engine.rootObjects().isEmpty())
        return 1;

    const QString test = qEnvironmentVariable("ELVONOS_EVENTVIEWER_TEST");
    if (!test.isEmpty()) {
        const QStringList parts = test.split(QLatin1Char(':'));
        if (parts.size() == 2) {
            if (parts.at(0) == QStringLiteral("source"))
                model.setSourceFilter(parts.at(1).toInt());
            else if (parts.at(0) == QStringLiteral("level"))
                model.setLevelFilter(parts.at(1).toInt());
        }
    }
    QTimer::singleShot(0, &model, &EventModel::refresh);
    return app.exec();
}

#include "main.moc"

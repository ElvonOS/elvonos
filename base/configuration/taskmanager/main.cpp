#include <QAbstractListModel>
#include <QDateTime>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QHash>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QRegularExpression>
#include <QTimer>
#include <QUrl>

#include <pwd.h>
#include <signal.h>
#include <unistd.h>

#include <algorithm>
#include "../common/elvonapp.h"

namespace {

struct ProcessEntry {
    int pid = 0;
    QString name;
    QString user;
    QString cmdline;
    QString package;
    QString state;
    QString memoryText;
    qint64 rss = 0;
    double cpu = 0.0;
    bool android = false;
};

QString readFile(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return QString::fromUtf8(file.read(4096));
}

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

QString userNameFor(uid_t uid)
{
    static QHash<uint, QString> cache;
    const auto found = cache.constFind(uid);
    if (found != cache.constEnd())
        return found.value();
    QString name;
    if (struct passwd *pw = getpwuid(uid))
        name = QString::fromUtf8(pw->pw_name);
    if (name.isEmpty())
        name = QString::number(uid);
    cache.insert(uid, name);
    return name;
}

QString stateText(const QString &state)
{
    if (state == "R")
        return "Running";
    if (state == "S")
        return "Sleeping";
    if (state == "D")
        return "Waiting";
    if (state == "Z")
        return "Zombie";
    if (state == "T")
        return "Stopped";
    if (state == "I")
        return "Idle";
    return state;
}

QString tidyCommandLine(QString value)
{
    value.replace(QChar('\0'), QChar(' '));
    value = value.simplified();
    if (value.size() > 320)
        value = value.left(320) + "…";
    return value;
}

} // namespace

class ProcessScanner : public QObject {
    Q_OBJECT
    Q_PROPERTY(double cpuPercent READ cpuPercent NOTIFY changed)
    Q_PROPERTY(int cpuCount READ cpuCount CONSTANT)
    Q_PROPERTY(QString memoryText READ memoryText NOTIFY changed)
    Q_PROPERTY(double memoryPercent READ memoryPercent NOTIFY changed)
    Q_PROPERTY(int processCount READ processCount NOTIFY changed)
    Q_PROPERTY(QString loadText READ loadText NOTIFY changed)
    Q_PROPERTY(QString uptimeText READ uptimeText NOTIFY changed)
    Q_PROPERTY(bool waydroidRunning READ waydroidRunning NOTIFY changed)

public:
    explicit ProcessScanner(QObject *parent = nullptr) : QObject(parent)
    {
        m_cpuCount = static_cast<int>(sysconf(_SC_NPROCESSORS_ONLN));
        if (m_cpuCount <= 0)
            m_cpuCount = 1;
        m_timer.setInterval(2000);
        connect(&m_timer, &QTimer::timeout, this, &ProcessScanner::refresh);
        m_timer.start();
        QTimer::singleShot(250, this, &ProcessScanner::refresh);
    }

    const QList<ProcessEntry> &linuxProcesses() const { return m_linux; }
    const QList<ProcessEntry> &androidProcesses() const { return m_android; }

    double cpuPercent() const { return m_cpuPercent; }
    int cpuCount() const { return m_cpuCount; }
    QString memoryText() const
    {
        return humanSize(m_memUsed) + " / " + humanSize(m_memTotal);
    }
    double memoryPercent() const
    {
        return m_memTotal > 0 ? double(m_memUsed) / double(m_memTotal) * 100.0 : 0.0;
    }
    int processCount() const { return m_linux.size() + m_android.size(); }
    QString loadText() const { return m_loadText; }
    QString uptimeText() const { return m_uptimeText; }
    bool waydroidRunning() const { return !m_android.isEmpty(); }

    Q_INVOKABLE QString humanSize(qint64 bytes) const { return ::humanSize(bytes); }

    Q_INVOKABLE void quit() { QCoreApplication::quit(); }

    Q_INVOKABLE void refresh()
    {
        double elapsed = 1.0;
        bool hadSample = false;
        if (m_since.isValid()) {
            hadSample = true;
            elapsed = std::max(0.05, m_since.restart() / 1000.0);
        } else {
            m_since.start();
        }

        updateSummary();

        QList<ProcessEntry> linuxList;
        QList<ProcessEntry> androidList;
        QHash<int, qint64> currentJiffies;

        const QStringList entries = QDir("/proc").entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QString &entry : entries) {
            bool ok = false;
            const int pid = entry.toInt(&ok);
            if (!ok || pid <= 0)
                continue;

            const QString base = "/proc/" + entry;
            const QString stat = readFile(base + "/stat");
            if (stat.isEmpty())
                continue;
            const int close = stat.lastIndexOf(')');
            const int open = stat.indexOf('(');
            if (close <= open)
                continue;
            const QString comm = stat.mid(open + 1, close - open - 1);
            const QStringList fields = stat.mid(close + 2).split(' ', Qt::SkipEmptyParts);
            if (fields.size() < 22)
                continue;

            const QString state = fields.at(0);
            const qint64 jiffies = fields.at(11).toLongLong() + fields.at(12).toLongLong();
            const qint64 total = jiffies;
            double cpu = 0.0;
            if (hadSample) {
                const auto previous = m_lastJiffies.constFind(pid);
                if (previous != m_lastJiffies.constEnd())
                    cpu = std::max(0.0, double(total - previous.value()) / elapsed);
            }
            currentJiffies.insert(pid, total);

            const QString status = readFile(base + "/status");
            qint64 rss = 0;
            uid_t uid = 0;
            for (const QString &line : status.split('\n')) {
                if (line.startsWith("VmRSS:")) {
                    rss = line.mid(6).trimmed().section(' ', 0, 0).toLongLong() * 1024;
                } else if (line.startsWith("Uid:")) {
                    uid = static_cast<uid_t>(line.mid(4).trimmed().section('\t', 0, 0).toInt());
                }
            }
            if (rss == 0)
                rss = fields.at(21).toLongLong() * 4096;

            const QString cmdline = tidyCommandLine(readFile(base + "/cmdline"));
            const QString cgroup = readFile(base + "/cgroup");
            const QString firstArg = cmdline.section(' ', 0, 0);
            const bool android = cgroup.contains("waydroid")
                                 || cgroup.contains("lxc.payload")
                                 || firstArg.startsWith("/system/")
                                 || firstArg.startsWith("/apex/")
                                 || firstArg.startsWith("/vendor/")
                                 || firstArg.contains("app_process");

            QString package;
            if (android) {
                static const QRegularExpression packagePattern(
                    QStringLiteral("\\b([A-Za-z][A-Za-z0-9_]*(?:\\.[A-Za-z0-9_]+)+)\\b"));
                auto matches = packagePattern.globalMatch(cmdline);
                while (matches.hasNext()) {
                    const QString candidate = matches.next().captured(1);
                    if (!candidate.startsWith('/'))
                        package = candidate;
                }
            }

            ProcessEntry process;
            process.pid = pid;
            QString displayName = comm;
            if (!firstArg.isEmpty() && !firstArg.startsWith('['))
                displayName = QFileInfo(firstArg).fileName();
            if (android && !package.isEmpty())
                displayName = package;
            process.name = displayName;
            process.user = android ? QStringLiteral("android") : userNameFor(uid);
            process.cmdline = cmdline;
            process.package = package;
            process.state = stateText(state);
            process.rss = rss;
            process.memoryText = humanSize(rss);
            process.cpu = cpu;
            process.android = android;

            if (android)
                androidList.append(process);
            else
                linuxList.append(process);
        }

        m_lastJiffies = currentJiffies;
        std::sort(linuxList.begin(), linuxList.end(), [](const ProcessEntry &a, const ProcessEntry &b) {
            return a.cpu > b.cpu;
        });
        std::sort(androidList.begin(), androidList.end(), [](const ProcessEntry &a, const ProcessEntry &b) {
            return a.cpu > b.cpu;
        });
        m_linux = linuxList;
        m_android = androidList;
        emit changed();
    }

    Q_INVOKABLE bool killPid(int pid, bool force)
    {
        if (pid <= 1)
            return false;
        QProcess process;
        process.start("sudo", {"-n", "kill", force ? "-KILL" : "-TERM",
                                QString::number(pid)});
        if (process.waitForFinished(5000)) {
            if (process.exitStatus() == QProcess::NormalExit && process.exitCode() == 0)
                return true;
        } else {
            process.kill();
        }
        return ::kill(pid, force ? SIGKILL : SIGTERM) == 0;
    }

    Q_INVOKABLE bool forceStopPackage(const QString &package)
    {
        if (package.isEmpty())
            return false;
        QProcess process;
        process.start("sudo", {"-n", "lxc-attach",
                               "-P", "/var/lib/waydroid/lxc",
                               "-n", "waydroid",
                               "--", "am", "force-stop", package});
        if (!process.waitForFinished(15000)) {
            process.kill();
            return false;
        }
        return process.exitStatus() == QProcess::NormalExit && process.exitCode() == 0;
    }

signals:
    void changed();

private:
    void updateSummary()
    {
        const QString stat = readFile("/proc/stat");
        const QString firstLine = stat.section('\n', 0, 0);
        if (firstLine.startsWith("cpu ")) {
            const QStringList values = firstLine.mid(4).split(' ', Qt::SkipEmptyParts);
            qint64 total = 0;
            qint64 idle = 0;
            for (int i = 0; i < values.size(); ++i) {
                const qint64 value = values.at(i).toLongLong();
                total += value;
                if (i == 3 || i == 4)
                    idle += value;
            }
            if (m_lastTotal > 0 && total > m_lastTotal) {
                const qint64 deltaTotal = total - m_lastTotal;
                const qint64 deltaIdle = idle - m_lastIdle;
                m_cpuPercent = deltaTotal > 0
                                   ? double(deltaTotal - deltaIdle) / double(deltaTotal) * 100.0
                                   : 0.0;
            }
            m_lastTotal = total;
            m_lastIdle = idle;
        }

        const QString meminfo = readFile("/proc/meminfo");
        qint64 total = 0;
        qint64 available = 0;
        qint64 free = 0;
        qint64 buffers = 0;
        qint64 cached = 0;
        for (const QString &line : meminfo.split('\n')) {
            const qint64 value = line.section(':', 1, 1).trimmed().section(' ', 0, 0).toLongLong() * 1024;
            if (line.startsWith("MemTotal:"))
                total = value;
            else if (line.startsWith("MemAvailable:"))
                available = value;
            else if (line.startsWith("MemFree:"))
                free = value;
            else if (line.startsWith("Buffers:"))
                buffers = value;
            else if (line.startsWith("Cached:"))
                cached = value;
        }
        if (available == 0)
            available = free + buffers + cached;
        m_memTotal = total;
        m_memUsed = std::max<qint64>(0, total - available);

        const QString load = readFile("/proc/loadavg");
        const QStringList parts = load.split(' ', Qt::SkipEmptyParts);
        m_loadText = parts.size() >= 3 ? parts.at(0) + "  " + parts.at(1) + "  " + parts.at(2)
                                       : QStringLiteral("—");

        const double uptime = readFile("/proc/uptime").section(' ', 0, 0).toDouble();
        const int days = int(uptime / 86400.0);
        const int hours = int(uptime / 3600.0) % 24;
        const int minutes = int(uptime / 60.0) % 60;
        if (days > 0)
            m_uptimeText = QStringLiteral("%1d %2h %3m").arg(days).arg(hours).arg(minutes);
        else
            m_uptimeText = QStringLiteral("%1h %2m").arg(hours).arg(minutes);
    }

    QTimer m_timer;
    QElapsedTimer m_since = QElapsedTimer();
    QList<ProcessEntry> m_linux;
    QList<ProcessEntry> m_android;
    QHash<int, qint64> m_lastJiffies;
    qint64 m_lastTotal = 0;
    qint64 m_lastIdle = 0;
    qint64 m_memTotal = 0;
    qint64 m_memUsed = 0;
    double m_cpuPercent = 0.0;
    int m_cpuCount = 1;
    QString m_loadText = "—";
    QString m_uptimeText = "—";
};

class ProcessModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(QString filter READ filter WRITE setFilter NOTIFY filterChanged)
    Q_PROPERTY(QString sortMode READ sortMode WRITE setSortMode NOTIFY sortModeChanged)

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        PidRole,
        UserRole,
        CpuRole,
        MemoryRole,
        MemoryTextRole,
        StateRole,
        CmdlineRole,
        PackageRole,
        AndroidRole,
    };

    ProcessModel(ProcessScanner *scanner, bool android, QObject *parent = nullptr)
        : QAbstractListModel(parent), m_scanner(scanner), m_android(android)
    {
        connect(scanner, &ProcessScanner::changed, this, &ProcessModel::reload);
        reload();
    }

    int rowCount(const QModelIndex &parent = QModelIndex()) const override
    {
        return parent.isValid() ? 0 : m_entries.size();
    }

    QVariant data(const QModelIndex &index, int role) const override
    {
        if (!index.isValid() || index.row() < 0 || index.row() >= m_entries.size())
            return {};
        const ProcessEntry &entry = m_entries.at(index.row());
        switch (role) {
        case NameRole:
            return entry.name;
        case PidRole:
            return entry.pid;
        case UserRole:
            return entry.user;
        case CpuRole:
            return entry.cpu;
        case MemoryRole:
            return entry.rss;
        case MemoryTextRole:
            return entry.memoryText;
        case StateRole:
            return entry.state;
        case CmdlineRole:
            return entry.cmdline;
        case PackageRole:
            return entry.package;
        case AndroidRole:
            return entry.android;
        default:
            return {};
        }
    }

    QHash<int, QByteArray> roleNames() const override
    {
        return {
            {NameRole, "name"},
            {PidRole, "pid"},
            {UserRole, "user"},
            {CpuRole, "cpu"},
            {MemoryRole, "memory"},
            {MemoryTextRole, "memoryText"},
            {StateRole, "state"},
            {CmdlineRole, "cmdline"},
            {PackageRole, "packageName"},
            {AndroidRole, "android"},
        };
    }

    QString filter() const { return m_filter; }
    void setFilter(const QString &value)
    {
        if (m_filter == value)
            return;
        m_filter = value;
        emit filterChanged();
        reload();
    }

    QString sortMode() const { return m_sortMode; }
    void setSortMode(const QString &value)
    {
        if (m_sortMode == value)
            return;
        m_sortMode = value;
        emit sortModeChanged();
        reload();
    }

signals:
    void countChanged();
    void filterChanged();
    void sortModeChanged();

private:
    void reload()
    {
        const QList<ProcessEntry> &source = m_android
                                                ? m_scanner->androidProcesses()
                                                : m_scanner->linuxProcesses();

        QList<ProcessEntry> filtered;
        for (const ProcessEntry &entry : source) {
            if (!m_filter.isEmpty()) {
                const QString needle = m_filter.trimmed();
                if (!entry.name.contains(needle, Qt::CaseInsensitive)
                    && !entry.cmdline.contains(needle, Qt::CaseInsensitive)
                    && !entry.user.contains(needle, Qt::CaseInsensitive)
                    && !entry.package.contains(needle, Qt::CaseInsensitive))
                    continue;
            }
            filtered.append(entry);
        }

        if (m_sortMode == "name") {
            std::sort(filtered.begin(), filtered.end(),
                      [](const ProcessEntry &a, const ProcessEntry &b) {
                          return a.name.localeAwareCompare(b.name) < 0;
                      });
        } else if (m_sortMode == "memory") {
            std::sort(filtered.begin(), filtered.end(),
                      [](const ProcessEntry &a, const ProcessEntry &b) {
                          return a.rss > b.rss;
                      });
        } else if (m_sortMode == "pid") {
            std::sort(filtered.begin(), filtered.end(),
                      [](const ProcessEntry &a, const ProcessEntry &b) {
                          return a.pid < b.pid;
                      });
        } else {
            std::sort(filtered.begin(), filtered.end(),
                      [](const ProcessEntry &a, const ProcessEntry &b) {
                          return a.cpu > b.cpu;
                      });
        }

        beginResetModel();
        m_entries = filtered;
        endResetModel();
        emit countChanged();
    }

    ProcessScanner *m_scanner;
    bool m_android = false;
    QString m_filter;
    QString m_sortMode = "cpu";
    QList<ProcessEntry> m_entries;
};

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    AppLang lang;
    AppTheme theme;
    appLangInstance() = &lang;
    app.setApplicationName(QStringLiteral("elvonos-taskmanager"));
    app.setApplicationDisplayName(QStringLiteral("Task Manager"));
    app.setDesktopFileName(QStringLiteral("elvonos-taskmanager"));

    ProcessScanner scanner;
    ProcessModel linuxModel(&scanner, false);
    ProcessModel androidModel(&scanner, true);
    androidModel.setSortMode("memory");

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("lang"), &lang);
    engine.rootContext()->setContextProperty(QStringLiteral("theme"), &theme);
    engine.rootContext()->setContextProperty("processScanner", &scanner);
    engine.rootContext()->setContextProperty("linuxModel", &linuxModel);
    engine.rootContext()->setContextProperty("androidModel", &androidModel);

    engine.load(QUrl("qrc:/TaskManager.qml"));
    if (engine.rootObjects().isEmpty())
        return -1;
    return app.exec();
}

#include "main.moc"

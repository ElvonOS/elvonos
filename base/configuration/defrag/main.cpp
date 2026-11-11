#include <QAbstractListModel>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QTimer>
#include <QUrl>
#include <QVariantMap>

#include <algorithm>
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
    return QString::number(mb / 1024.0, 'f', 1) + " GB";
}

QString findTool(const QStringList &names)
{
    for (const QString &name : names) {
        const QString found = QStandardPaths::findExecutable(name);
        if (!found.isEmpty())
            return found;
    }
    static const QStringList extra{"/usr/sbin", "/sbin", "/usr/bin", "/bin"};
    for (const QString &name : names) {
        for (const QString &dir : extra) {
            const QString candidate = dir + "/" + name;
            if (QFileInfo::exists(candidate))
                return candidate;
        }
    }
    return {};
}

QString iconFor(const QString &fs, bool removable)
{
    Q_UNUSED(fs);
    const QString name = removable ? "drive-removable-media-usb" : "drive-harddisk";
    const QStringList dirs{
        "/usr/share/icons/Papirus/64x64/devices/",
        "/usr/share/icons/Papirus/48x48/devices/",
        "/usr/share/icons/hicolor/scalable/devices/",
        "/usr/share/icons/Adwaita/64x64/devices/",
    };
    for (const QString &dir : dirs) {
        for (const QString &ext : {".svg", ".png"}) {
            const QString candidate = dir + name + ext;
            if (QFileInfo::exists(candidate))
                return "file://" + candidate;
        }
    }
    return {};
}

} // namespace

class DiskModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY volumesChanged)
    Q_PROPERTY(int supportedCount READ supportedCount NOTIFY volumesChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString output READ output NOTIFY outputChanged)
    Q_PROPERTY(QString task READ task NOTIFY busyChanged)
    Q_PROPERTY(QString result READ result NOTIFY resultChanged)
    Q_PROPERTY(bool resultOk READ resultOk NOTIFY resultChanged)
    Q_PROPERTY(bool trimAvailable READ trimAvailable CONSTANT)

public:
    enum Roles {
        LabelRole = Qt::UserRole + 1,
        DeviceRole,
        MountRole,
        FsRole,
        SizeRole,
        FreeRole,
        RemovableRole,
        SupportedRole,
        ToolRole,
        IconRole,
    };

    explicit DiskModel(QObject *parent = nullptr) : QAbstractListModel(parent)
    {
        m_e4defrag = findTool({"e4defrag"});
        m_btrfs = findTool({"btrfs"});
        m_xfsFsr = findTool({"xfs_fsr"});
        m_fstrim = findTool({"fstrim"});
        refresh();
    }

    int rowCount(const QModelIndex &parent = QModelIndex()) const override
    {
        return parent.isValid() ? 0 : m_volumes.size();
    }

    QVariant data(const QModelIndex &index, int role) const override
    {
        if (!index.isValid() || index.row() < 0 || index.row() >= m_volumes.size())
            return {};
        const Volume &v = m_volumes.at(index.row());
        switch (role) {
        case LabelRole:
            return v.label;
        case DeviceRole:
            return v.device;
        case MountRole:
            return v.mountPoint;
        case FsRole:
            return v.fs;
        case SizeRole:
            return v.size;
        case FreeRole:
            return v.free;
        case RemovableRole:
            return v.removable;
        case SupportedRole:
            return v.supported;
        case ToolRole:
            return v.tool;
        case IconRole:
            return v.icon;
        default:
            return {};
        }
    }

    QHash<int, QByteArray> roleNames() const override
    {
        return {
            {LabelRole, "label"},
            {DeviceRole, "device"},
            {MountRole, "mountPoint"},
            {FsRole, "fs"},
            {SizeRole, "size"},
            {FreeRole, "free"},
            {RemovableRole, "removable"},
            {SupportedRole, "supported"},
            {ToolRole, "tool"},
            {IconRole, "icon"},
        };
    }

    int supportedCount() const
    {
        int count = 0;
        for (const Volume &v : m_volumes) {
            if (v.supported)
                ++count;
        }
        return count;
    }

    bool busy() const { return m_busy; }
    QString output() const { return m_output; }
    QString task() const { return appTr(m_task); }
    QString result() const { return m_result; }
    bool resultOk() const { return m_resultOk; }
    bool trimAvailable() const { return !m_fstrim.isEmpty(); }

    Q_INVOKABLE void refresh()
    {
        QProcess process;
        process.start("lsblk", {"-J", "-o",
                                "NAME,LABEL,SIZE,FSTYPE,MOUNTPOINT,TYPE,RM,TRAN,MODEL"});
        if (!process.waitForFinished(2000)) {
            process.kill();
            return;
        }
        const QJsonDocument document = QJsonDocument::fromJson(process.readAllStandardOutput());
        if (!document.isObject())
            return;

        QList<Volume> volumes;
        collect(document.object().value("blockdevices").toArray(), volumes);

        beginResetModel();
        m_volumes = volumes;
        endResetModel();
        emit volumesChanged();
    }

    Q_INVOKABLE QVariantMap volumeInfo(int index) const
    {
        QVariantMap map;
        if (index < 0 || index >= m_volumes.size())
            return map;
        const Volume &v = m_volumes.at(index);
        map.insert("label", v.label);
        map.insert("device", v.device);
        map.insert("mountPoint", v.mountPoint);
        map.insert("fs", v.fs);
        map.insert("size", v.size);
        map.insert("free", v.free);
        map.insert("removable", v.removable);
        map.insert("supported", v.supported);
        map.insert("tool", v.tool);
        map.insert("icon", v.icon);
        map.insert("analyzeSupported", v.fs == "ext4" && !m_e4defrag.isEmpty());
        map.insert("trimSupported", !m_fstrim.isEmpty());
        return map;
    }

    Q_INVOKABLE bool canDefrag(int index) const
    {
        return index >= 0 && index < m_volumes.size() && m_volumes.at(index).supported;
    }

    Q_INVOKABLE bool canAnalyze(int index) const
    {
        return index >= 0 && index < m_volumes.size()
               && m_volumes.at(index).fs == "ext4" && !m_e4defrag.isEmpty();
    }

    Q_INVOKABLE bool canTrim(int index) const
    {
        return index >= 0 && index < m_volumes.size() && !m_fstrim.isEmpty();
    }

    Q_INVOKABLE void defragment(int index)
    {
        if (index < 0 || index >= m_volumes.size() || m_busy)
            return;
        const Volume &v = m_volumes.at(index);
        if (v.fs == "ext4" && !m_e4defrag.isEmpty()) {
            startTool(m_e4defrag, {v.mountPoint}, appTr(QStringLiteral("Defragmenting ")) + v.label);
        } else if (v.fs == "btrfs" && !m_btrfs.isEmpty()) {
            startTool(m_btrfs, {"filesystem", "defragment", "-r", v.mountPoint},
                      appTr(QStringLiteral("Defragmenting ")) + v.label);
        } else if (v.fs == "xfs" && !m_xfsFsr.isEmpty()) {
            startTool(m_xfsFsr, {v.mountPoint}, appTr(QStringLiteral("Defragmenting ")) + v.label);
        } else {
            setResult(false, appTr(QStringLiteral("Defragmentation is not available for "))
                              + v.fs + appTr(QStringLiteral(" on this image.")));
        }
    }

    Q_INVOKABLE void analyze(int index)
    {
        if (index < 0 || index >= m_volumes.size() || m_busy)
            return;
        const Volume &v = m_volumes.at(index);
        if (v.fs != "ext4" || m_e4defrag.isEmpty()) {
            setResult(false, appTr(QStringLiteral("Analysis is only available for ext4 filesystems.")));
            return;
        }
        startTool(m_e4defrag, {"-c", v.mountPoint}, appTr(QStringLiteral("Analyzing ")) + v.label);
    }

    Q_INVOKABLE void trim(int index)
    {
        if (index < 0 || index >= m_volumes.size() || m_busy)
            return;
        if (m_fstrim.isEmpty()) {
            setResult(false, appTr(QStringLiteral("fstrim is not available.")));
            return;
        }
        const Volume &v = m_volumes.at(index);
        startTool(m_fstrim, {"-v", v.mountPoint}, appTr(QStringLiteral("TRIM on ")) + v.label);
    }

    Q_INVOKABLE void cancel()
    {
        if (!m_process)
            return;
        m_cancelled = true;
        m_process->terminate();
        if (!m_process->waitForFinished(1500))
            m_process->kill();
        setResult(false, "Operation cancelled.");
        setBusy(false);
    }

signals:
    void volumesChanged();
    void busyChanged();
    void outputChanged();
    void resultChanged();

private:
    struct Volume {
        QString label;
        QString device;
        QString mountPoint;
        QString fs;
        QString size;
        QString free;
        bool removable = false;
        bool supported = false;
        QString tool;
        QString icon;
    };

    void collect(const QJsonArray &devices, QList<Volume> &out)
    {
        static const QStringList allowed{"ext4", "xfs", "btrfs", "f2fs",
                                         "vfat", "exfat", "ntfs", "ntfs3"};
        for (const QJsonValue &value : devices) {
            const QJsonObject object = value.toObject();
            const QString type = object.value("type").toString();
            const QString fs = object.value("fstype").toString();
            QString mount = object.value("mountpoint").toString();
            const QString name = object.value("name").toString();
            const bool removable = object.value("rm").toBool()
                                   || object.value("tran").toString() == "usb";

            if (!mount.isEmpty() && allowed.contains(fs)
                && (type == "part" || type == "disk")
                && !mount.startsWith("/run/live") && mount != "none") {
                Volume v;
                QString label = object.value("label").toString().trimmed();
                if (label.isEmpty()) {
                    const QString model = object.value("model").toString().trimmed();
                    label = !model.isEmpty() ? model : name;
                }
                v.label = label;
                v.device = "/dev/" + name;
                v.mountPoint = mount;
                v.fs = fs;
                v.size = object.value("size").toString();
                const QStorageInfo storage(mount);
                v.free = storage.isValid() ? humanSize(storage.bytesAvailable()) : "—";
                v.removable = removable;
                v.icon = iconFor(fs, removable);
                if (fs == "ext4" && !m_e4defrag.isEmpty()) {
                    v.supported = true;
                    v.tool = "e4defrag";
                } else if (fs == "btrfs" && !m_btrfs.isEmpty()) {
                    v.supported = true;
                    v.tool = "btrfs";
                } else if (fs == "xfs" && !m_xfsFsr.isEmpty()) {
                    v.supported = true;
                    v.tool = "xfs_fsr";
                } else {
                    v.supported = false;
                    v.tool = fs;
                }
                out.append(v);
            }

            collect(object.value("children").toArray(), out);
        }
    }

    void startTool(const QString &program, const QStringList &arguments, const QString &task)
    {
        if (m_busy)
            return;
        m_process = new QProcess(this);
        m_process->setProcessChannelMode(QProcess::MergedChannels);
        m_cancelled = false;
        setResult(true, "");
        m_output.clear();
        emit outputChanged();
        m_task = task;
        setBusy(true);

        appendOutput("$ " + program + " " + arguments.join(' ') + "\n\n");

        connect(m_process, &QProcess::readyRead, this, [this] {
            appendOutput(QString::fromUtf8(m_process->readAll()));
        });
        connect(m_process, &QProcess::finished, this,
                [this, program](int exitCode, QProcess::ExitStatus status) {
            appendOutput(QString::fromUtf8(m_process->readAll()));
            if (m_cancelled)
                setResult(false, "Cancelled.");
            else if (status == QProcess::NormalExit && exitCode == 0)
                setResult(true, "Finished successfully.");
            else
                setResult(false, program + " exited with code " + QString::number(exitCode) + ".");
            m_process->deleteLater();
            m_process = nullptr;
            setBusy(false);
            refresh();
        });

        m_process->start("sudo", QStringList{"-n", program} + arguments);
    }

    void appendOutput(const QString &text)
    {
        if (text.isEmpty())
            return;
        m_output += text;
        if (m_output.size() > 200000)
            m_output = m_output.right(200000);
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
        m_result = message;
        m_resultOk = ok;
        emit resultChanged();
    }

    QList<Volume> m_volumes;
    QString m_e4defrag;
    QString m_btrfs;
    QString m_xfsFsr;
    QString m_fstrim;
    QProcess *m_process = nullptr;
    bool m_busy = false;
    bool m_cancelled = false;
    bool m_resultOk = true;
    QString m_task;
    QString m_output;
    QString m_result;
};

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    AppLang lang;
    AppTheme theme;
    appLangInstance() = &lang;
    app.setApplicationName(QStringLiteral("elvonos-defrag"));
    app.setApplicationDisplayName(QStringLiteral("Defrag"));
    app.setDesktopFileName(QStringLiteral("elvonos-defrag"));

    DiskModel disks;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("lang"), &lang);
    engine.rootContext()->setContextProperty(QStringLiteral("theme"), &theme);
    engine.rootContext()->setContextProperty("diskModel", &disks);

    engine.load(QUrl("qrc:/Defrag.qml"));
    if (engine.rootObjects().isEmpty())
        return -1;
    return app.exec();
}

#include "main.moc"

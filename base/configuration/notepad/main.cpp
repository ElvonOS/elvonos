#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QSaveFile>
#include <QSettings>
#include <QStandardPaths>
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

} // namespace

class NotepadModel : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString directory READ directory NOTIFY directoryChanged)
    Q_PROPERTY(QVariantList entries READ entries NOTIFY entriesChanged)
    Q_PROPERTY(QVariantList recentFiles READ recentFiles NOTIFY recentFilesChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

public:
    explicit NotepadModel(QObject *parent = nullptr)
        : QObject(parent)
    {
        QString start =
            QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
        if (start.isEmpty() || !QDir(start).exists())
            start = QDir::homePath();
        setDirectory(start);
    }

    QString directory() const { return m_directory; }
    QVariantList entries() const { return m_entries; }
    QString lastError() const { return appTr(m_lastError); }

    QVariantList recentFiles() const
    {
        QVariantList result;
        const QStringList recent =
            QSettings().value(QStringLiteral("recentFiles")).toStringList();
        for (const QString &path : recent) {
            if (QFileInfo::exists(path))
                result.append(path);
        }
        return result;
    }

    Q_INVOKABLE void addRecent(const QString &path)
    {
        QSettings settings;
        QStringList recent =
            settings.value(QStringLiteral("recentFiles")).toStringList();
        recent.removeAll(path);
        recent.prepend(path);
        while (recent.size() > 8)
            recent.removeLast();
        settings.setValue(QStringLiteral("recentFiles"), recent);
        emit recentFilesChanged();
    }

    Q_INVOKABLE void clearRecent()
    {
        QSettings().remove(QStringLiteral("recentFiles"));
        emit recentFilesChanged();
    }

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
            QVariantMap entry;
            entry.insert(QStringLiteral("name"), info.fileName());
            entry.insert(QStringLiteral("path"), info.absoluteFilePath());
            entry.insert(QStringLiteral("isDir"), info.isDir());
            entry.insert(QStringLiteral("sizeText"),
                         info.isDir() ? QString()
                                      : humanSize(info.size()));
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

    Q_INVOKABLE QString documentsPath() const
    {
        QString path = QStandardPaths::writableLocation(
            QStandardPaths::DocumentsLocation);
        if (path.isEmpty())
            path = homePath();
        return path;
    }

    Q_INVOKABLE QString loadFile(const QString &path)
    {
        clearError();
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly)) {
            setError(appTr(QStringLiteral("Cannot open %1: %2"))
                         .arg(QFileInfo(path).fileName(), file.errorString()));
            return {};
        }
        const QByteArray data = file.readAll();
        if (data.contains('\0')) {
            setError(appTr(QStringLiteral("Not a text file: %1"))
                         .arg(QFileInfo(path).fileName()));
            return {};
        }
        return QString::fromUtf8(data);
    }

    Q_INVOKABLE bool saveFile(const QString &path, const QString &text)
    {
        clearError();
        QSaveFile file(path);
        if (!file.open(QIODevice::WriteOnly)) {
            setError(appTr(QStringLiteral("Cannot save %1: %2"))
                         .arg(QFileInfo(path).fileName(), file.errorString()));
            return false;
        }
        const QByteArray data = text.toUtf8();
        if (file.write(data) != data.size()) {
            setError(appTr(QStringLiteral("Cannot write %1"))
                         .arg(QFileInfo(path).fileName()));
            file.cancelWriting();
            return false;
        }
        if (!file.commit()) {
            setError(appTr(QStringLiteral("Cannot save %1: %2"))
                         .arg(QFileInfo(path).fileName(), file.errorString()));
            return false;
        }
        if (QFileInfo(path).absolutePath() == m_directory)
            refresh();
        return true;
    }

    Q_INVOKABLE QString joinPath(const QString &directory,
                                 const QString &name) const
    {
        return QDir(directory).filePath(name);
    }

signals:
    void directoryChanged();
    void entriesChanged();
    void recentFilesChanged();
    void lastErrorChanged();

private:
    void setError(const QString &message)
    {
        m_lastError = appTr(message);
        emit lastErrorChanged();
    }
    void clearError()
    {
        if (m_lastError.isEmpty())
            return;
        m_lastError.clear();
        emit lastErrorChanged();
    }

    QString m_directory;
    QVariantList m_entries;
    QString m_lastError;
};

int main(int argc, char *argv[])
{
    /* The editor is a simple 2D UI; the software renderer avoids the several
     * seconds the OpenGL scene graph needs for its first frame on virtualised
     * GPUs (and works identically on real hardware). */
    qputenv("QT_QUICK_BACKEND", "software");

    QGuiApplication app(argc, argv);

    AppLang lang;
    AppTheme theme;
    appLangInstance() = &lang;
    app.setApplicationName(QStringLiteral("elvonos-notepad"));
    app.setOrganizationName(QStringLiteral("ElvonOS"));
    app.setDesktopFileName(QStringLiteral("elvonos-notepad"));

    NotepadModel model;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("lang"), &lang);
    engine.rootContext()->setContextProperty(QStringLiteral("theme"), &theme);
    engine.rootContext()->setContextProperty(QStringLiteral("notepadModel"),
                                             &model);
    engine.load(QUrl(QStringLiteral("qrc:/Notepad.qml")));
    if (engine.rootObjects().isEmpty()) {
        qWarning("elvonos-notepad: no root objects");
        return 1;
    }
    if (auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst())) {
        qInfo("elvonos-notepad: window visible=%d size=%dx%d screen=%p",
              window->isVisible(), window->width(), window->height(),
              (void *)window->screen());
        if (qEnvironmentVariableIsSet("ELVONOS_NOTEPAD_FIND")) {
            QMetaObject::invokeMethod(
                window, "showFind",
                Q_ARG(QVariant,
                      QVariant(qEnvironmentVariableIntValue("ELVONOS_NOTEPAD_FIND")
                               >= 2)));
        }
        const QStringList args = app.arguments();
        for (int i = 1; i < args.size(); ++i) {
            const QString arg = args.at(i);
            if (arg.startsWith(QLatin1Char('-')))
                continue;
            if (QFileInfo(arg).isFile()) {
                QMetaObject::invokeMethod(window, "openInitial",
                                          Q_ARG(QVariant, arg));
                break;
            }
        }
    } else {
        qWarning("elvonos-notepad: root object is not a QQuickWindow");
    }
    return app.exec();
}

#include "main.moc"

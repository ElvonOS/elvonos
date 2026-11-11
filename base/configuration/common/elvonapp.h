#ifndef ELVONAPP_H
#define ELVONAPP_H

#include <QColor>
#include <QFile>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QHash>
#include <QJsonDocument>
#include <QJsonObject>
#include <QObject>
#include <QStandardPaths>
#include <QStringList>

/* Shared language and theme bridge for the ElvonOS applications.
 *
 * Every app links this header, creates one AppLang and one AppTheme object
 * and publishes them to QML as "lang" and "theme".  The classes are
 * header-only and the header is listed in each CMake target so AUTOMOC
 * generates the meta objects. */

class AppLang : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString language READ language NOTIFY languageChanged)
    Q_PROPERTY(int revision READ revision NOTIFY languageChanged)

public:
    explicit AppLang(QObject *parent = nullptr) : QObject(parent)
    {
        m_path = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
                 + QStringLiteral("/elvonos/language");
        reload();
        m_watcher.addPath(QFileInfo(m_path).absolutePath());
        if (QFileInfo::exists(m_path))
            m_watcher.addPath(m_path);
        connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] {
            if (!m_watcher.files().contains(m_path) && QFileInfo::exists(m_path))
                m_watcher.addPath(m_path);
            reload();
        });
        connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] {
            if (!m_watcher.files().contains(m_path) && QFileInfo::exists(m_path))
                m_watcher.addPath(m_path);
            reload();
        });
    }

    QString language() const { return m_language; }
    int revision() const { return m_revision; }

    Q_INVOKABLE QString tr(const QString &source) const
    {
        return m_dict.value(source, source);
    }

    QString t(const QString &source) const
    {
        return m_dict.value(source, source);
    }

signals:
    void languageChanged();

private:
    static QStringList supported()
    {
        return {QStringLiteral("en"), QStringLiteral("de"), QStringLiteral("fr"),
                QStringLiteral("es"), QStringLiteral("it"), QStringLiteral("pt"),
                QStringLiteral("nl"), QStringLiteral("pl"), QStringLiteral("ru"),
                QStringLiteral("tr"), QStringLiteral("uk"), QStringLiteral("cs"),
                QStringLiteral("sv"), QStringLiteral("zh"), QStringLiteral("ja")};
    }

    void reload()
    {
        QString code;
        QFile file(m_path);
        if (file.open(QIODevice::ReadOnly))
            code = QString::fromUtf8(file.readAll()).trimmed();
        if (code.isEmpty()) {
            const QString environment = qEnvironmentVariable("LANG");
            for (const QString &candidate : supported()) {
                if (environment.startsWith(candidate)) {
                    code = candidate;
                    break;
                }
            }
        }
        if (!supported().contains(code))
            code = QStringLiteral("en");
        if (code == m_language && !m_dict.isEmpty())
            return;
        m_language = code;
        m_dict.clear();
        if (code != QStringLiteral("en")) {
            QFile dictionary(QStringLiteral("/usr/share/elvonos/i18n/")
                             + code + QStringLiteral(".json"));
            if (dictionary.open(QIODevice::ReadOnly)) {
                const QJsonObject object =
                    QJsonDocument::fromJson(dictionary.readAll()).object();
                for (auto it = object.constBegin(); it != object.constEnd(); ++it)
                    m_dict.insert(it.key(), it.value().toString());
            }
        }
        m_revision++;
        emit languageChanged();
    }

    QString m_path;
    QString m_language = QStringLiteral("en");
    int m_revision = 0;
    QHash<QString, QString> m_dict;
    QFileSystemWatcher m_watcher;
};

class AppTheme : public QObject {
    Q_OBJECT
    Q_PROPERTY(QColor accent READ accent NOTIFY changed)
    Q_PROPERTY(QColor accent2 READ accent2 NOTIFY changed)
    Q_PROPERTY(QColor background READ background NOTIFY changed)
    Q_PROPERTY(QColor panel READ panel NOTIFY changed)
    Q_PROPERTY(QColor surface READ surface NOTIFY changed)
    Q_PROPERTY(QColor text READ text NOTIFY changed)
    Q_PROPERTY(QColor muted READ muted NOTIFY changed)
    Q_PROPERTY(QColor border READ border NOTIFY changed)
    Q_PROPERTY(int radius READ radius NOTIFY changed)
    Q_PROPERTY(int glass READ glass NOTIFY changed)
    Q_PROPERTY(bool light READ light NOTIFY changed)

public:
    explicit AppTheme(QObject *parent = nullptr) : QObject(parent)
    {
        m_path = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
                 + QStringLiteral("/elvonos/theme.json");
        reload();
        m_watcher.addPath(QFileInfo(m_path).absolutePath());
        if (QFileInfo::exists(m_path))
            m_watcher.addPath(m_path);
        connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] {
            if (!m_watcher.files().contains(m_path) && QFileInfo::exists(m_path))
                m_watcher.addPath(m_path);
            reload();
        });
        connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] {
            if (!m_watcher.files().contains(m_path) && QFileInfo::exists(m_path))
                m_watcher.addPath(m_path);
            reload();
        });
    }

    QColor accent() const { return m_accent; }
    QColor accent2() const { return m_accent2; }
    QColor background() const { return m_background; }
    QColor panel() const { return m_panel; }
    QColor surface() const { return m_surface; }
    QColor text() const { return m_text; }
    QColor muted() const { return m_muted; }
    QColor border() const { return m_border; }
    int radius() const { return m_radius; }
    int glass() const { return m_glass; }
    bool light() const { return m_light; }

signals:
    void changed();

private:
    void reload()
    {
        QColor accent(QStringLiteral("#8FD3FF"));
        QColor accent2(QStringLiteral("#4CC2FF"));
        QColor background(QStringLiteral("#101016"));
        QColor panel(QStringLiteral("#15151C"));
        QColor surface(QStringLiteral("#1B1B26"));
        QColor text(QStringLiteral("#E9ECF2"));
        QColor muted(QStringLiteral("#8B93A1"));
        QColor border(QStringLiteral("#FFFFFF"));
        int radius = 14;
        int glass = 78;
        QFile file(m_path);
        if (file.open(QIODevice::ReadOnly)) {
            const QJsonObject object =
                QJsonDocument::fromJson(file.readAll()).object();
            auto take = [&object](const QString &key, QColor &value) {
                const QColor configured(object.value(key).toString());
                if (configured.isValid())
                    value = configured;
            };
            take(QStringLiteral("accent"), accent);
            take(QStringLiteral("accent2"), accent2);
            take(QStringLiteral("background"), background);
            take(QStringLiteral("panel"), panel);
            take(QStringLiteral("surface"), surface);
            take(QStringLiteral("text"), text);
            take(QStringLiteral("muted"), muted);
            take(QStringLiteral("border"), border);
            radius = qBound(0, object.value(QStringLiteral("radius")).toInt(radius), 28);
            glass = qBound(0, object.value(QStringLiteral("glass")).toInt(glass), 100);
        }
        const bool light = background.lightness() > 150;
        if (accent == m_accent && accent2 == m_accent2
            && background == m_background && panel == m_panel
            && surface == m_surface && text == m_text
            && muted == m_muted && border == m_border && radius == m_radius
            && glass == m_glass && light == m_light)
            return;
        m_accent = accent;
        m_accent2 = accent2;
        m_background = background;
        m_panel = panel;
        m_surface = surface;
        m_text = text;
        m_muted = muted;
        m_border = border;
        m_radius = radius;
        m_glass = glass;
        m_light = light;
        emit changed();
    }

    QString m_path;
    QFileSystemWatcher m_watcher;
    QColor m_accent = QColor(QStringLiteral("#8FD3FF"));
    QColor m_accent2 = QColor(QStringLiteral("#4CC2FF"));
    QColor m_background = QColor(QStringLiteral("#101016"));
    QColor m_panel = QColor(QStringLiteral("#15151C"));
    QColor m_surface = QColor(QStringLiteral("#1B1B26"));
    QColor m_text = QColor(QStringLiteral("#E9ECF2"));
    QColor m_muted = QColor(QStringLiteral("#8B93A1"));
    QColor m_border = QColor(QStringLiteral("#FFFFFF"));
    int m_radius = 14;
    int m_glass = 78;
    bool m_light = false;
};

/* C++ side translation for status and error messages.  Each app installs its
 * AppLang instance in main() before creating any model. */
inline AppLang *&appLangInstance()
{
    static AppLang *instance = nullptr;
    return instance;
}

inline QString appTr(const QString &text)
{
    AppLang *lang = appLangInstance();
    return lang ? lang->t(text) : text;
}

#endif // ELVONAPP_H

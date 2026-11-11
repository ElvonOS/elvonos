#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QUrl>
#include <QQmlContext>
#include "../common/elvonapp.h"

int main(int argc, char *argv[])
{
    /* A 2D calculator; software rendering avoids slow/one-shot GL first
     * frames on virtualised GPUs. */
    qputenv("QT_QUICK_BACKEND", "software");

    QGuiApplication app(argc, argv);

    AppLang lang;
    AppTheme theme;
    appLangInstance() = &lang;
    app.setApplicationName(QStringLiteral("elvonos-calculator"));
    app.setDesktopFileName(QStringLiteral("elvonos-calculator"));

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("lang"), &lang);
    engine.rootContext()->setContextProperty(QStringLiteral("theme"), &theme);
    engine.load(QUrl(QStringLiteral("qrc:/Calculator.qml")));
    if (engine.rootObjects().isEmpty())
        return 1;
    if (qEnvironmentVariableIsSet("ELVONOS_CALC_SCIENTIFIC"))
        engine.rootObjects().constFirst()->setProperty("scientificMode", true);
    return app.exec();
}

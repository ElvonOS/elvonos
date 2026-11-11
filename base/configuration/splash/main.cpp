#include <QCommandLineParser>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QTimer>

#include <LayerShellQt/Shell>
#include <LayerShellQt/Window>

// Returns true while a process with the exact comm name is running.
static bool processRunning(const QString &name)
{
    const QDir proc(QStringLiteral("/proc"));
    const QStringList entries =
        proc.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &entry : entries) {
        bool isPid = false;
        entry.toInt(&isPid);
        if (!isPid)
            continue;
        QFile comm(QStringLiteral("/proc/") + entry
                   + QStringLiteral("/comm"));
        if (!comm.open(QIODevice::ReadOnly))
            continue;
        if (QString::fromLocal8Bit(comm.readAll()).trimmed() == name)
            return true;
    }
    return false;
}

// ElvonOS splash bridge.
//
// After Plymouth hands the display over to labwc there is still a short gap
// while the Win8DE shell builds its layers. This small Qt Quick client keeps
// the ElvonOS boot artwork on screen until the shell is running, then fades
// out. It uses the software renderer: on virtualised GPUs the OpenGL scene
// graph can need many seconds for its first frame, which would defeat the
// purpose of the splash.
int main(int argc, char *argv[])
{
    bool plainWindow = false;
    for (int i = 1; i < argc; ++i) {
        if (qstrcmp(argv[i], "--plain") == 0)
            plainWindow = true;
    }
    if (!plainWindow)
        LayerShellQt::Shell::useLayerShell();

    qputenv("QT_QUICK_BACKEND", "software");

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("elvonos-splash"));
    app.setDesktopFileName(QStringLiteral("elvonos-splash"));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("ElvonOS boot splash bridge"));
    parser.addHelpOption();

    QCommandLineOption waitFileOption(
        QStringLiteral("wait-file"),
        QStringLiteral("Session marker that signals the desktop is ready."),
        QStringLiteral("path"));
    QCommandLineOption minOption(
        QStringLiteral("min-ms"),
        QStringLiteral("Minimum time the splash stays visible in milliseconds."),
        QStringLiteral("ms"), QStringLiteral("2200"));
    QCommandLineOption graceOption(
        QStringLiteral("grace-ms"),
        QStringLiteral("Delay between the marker and the fade-out in milliseconds."),
        QStringLiteral("ms"), QStringLiteral("1400"));
    QCommandLineOption maxOption(
        QStringLiteral("max-ms"),
        QStringLiteral("Failsafe timeout in milliseconds."),
        QStringLiteral("ms"), QStringLiteral("60000"));
    QCommandLineOption plainOption(
        QStringLiteral("plain"),
        QStringLiteral("Use a normal fullscreen window (debugging aid)."));
    QCommandLineOption qmlOption(
        QStringLiteral("qml"),
        QStringLiteral("Load an alternative QML file (debugging aid)."),
        QStringLiteral("path"));
    parser.addOption(waitFileOption);
    parser.addOption(minOption);
    parser.addOption(graceOption);
    parser.addOption(maxOption);
    parser.addOption(plainOption);
    parser.addOption(qmlOption);
    parser.process(app);

    const QString waitFile = parser.value(waitFileOption);
    const int minMs = parser.value(minOption).toInt();
    const int graceMs = parser.value(graceOption).toInt();
    const int maxMs = parser.value(maxOption).toInt();

    QQmlApplicationEngine engine;
    const QString qmlOverride = parser.value(qmlOption);
    engine.load(qmlOverride.isEmpty() ? QUrl(QStringLiteral("qrc:/Splash.qml"))
                                      : QUrl::fromLocalFile(qmlOverride));
    if (engine.rootObjects().isEmpty())
        return 1;

    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst());
    if (!window)
        return 1;

    window->setFlags(Qt::FramelessWindowHint);
    window->setColor(Qt::transparent);

    if (!plainWindow) {
        if (auto *layerWindow = LayerShellQt::Window::get(window)) {
            layerWindow->setLayer(LayerShellQt::Window::LayerOverlay);
            layerWindow->setAnchors({LayerShellQt::Window::AnchorTop
                                     | LayerShellQt::Window::AnchorBottom
                                     | LayerShellQt::Window::AnchorLeft
                                     | LayerShellQt::Window::AnchorRight});
            layerWindow->setExclusiveZone(-1);
            layerWindow->setKeyboardInteractivity(
                LayerShellQt::Window::KeyboardInteractivityNone);
            layerWindow->setScope(QStringLiteral("elvonos-splash"));
            qInfo("elvonos-splash: layer-shell overlay attached");
        } else {
            qWarning("elvonos-splash: layer-shell unavailable, using a plain window");
        }
    } else {
        qInfo("elvonos-splash: plain window mode");
    }

    // Layer-shell derives the surface size from the anchors, but Qt only
    // forwards a resize to the scene graph after the first configure. Give
    // the QML scene a sane size immediately so the first frame is not empty.
    if (auto *screen = window->screen()) {
        window->setWidth(screen->geometry().width());
        window->setHeight(screen->geometry().height());
    }

    window->show();
    qInfo("elvonos-splash: window %dx%d shown", window->width(), window->height());

    const QString grabPath = qEnvironmentVariable("ELVONOS_SPLASH_GRAB");
    if (!grabPath.isEmpty()) {
        QTimer::singleShot(2000, window, [window, grabPath]() {
            const QImage image = window->grabWindow();
            image.save(grabPath);
            qInfo("elvonos-splash: grabbed %dx%d -> %s",
                  image.width(), image.height(), qPrintable(grabPath));
        });
    }

    QElapsedTimer elapsed;
    elapsed.start();

    auto *timer = new QTimer(&app);
    QObject::connect(timer, &QTimer::timeout, &app, [&]() {
        const qint64 now = elapsed.elapsed();
        const bool markerReady = !waitFile.isEmpty() && QFile::exists(waitFile);
        const bool shellReady = processRunning(QStringLiteral("Win8Running"))
                                && processRunning(QStringLiteral("Win8Start"));
        const bool ready = markerReady || shellReady;
        if ((ready && now >= minMs) || now >= maxMs) {
            timer->stop();
            QTimer::singleShot(graceMs, window, [window]() {
                QMetaObject::invokeMethod(window, "fadeOut");
            });
            QTimer::singleShot(graceMs + 500, &app, &QCoreApplication::quit);
        }
    });
    timer->start(100);

    return app.exec();
}

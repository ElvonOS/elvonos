import QtQuick
import QtQuick.Window

// ElvonOS boot splash. This window bridges the gap between Plymouth and the
// fully rendered labwc/Win8DE desktop: it uses the same artwork as the
// Plymouth theme and stays on the overlay layer until the session is ready.
Window {
    id: root
    visible: false
    color: "transparent"
    flags: Qt.FramelessWindowHint

    property bool fading: false

    Item {
        id: content
        anchors.fill: parent
        opacity: 1.0

        Behavior on opacity {
            NumberAnimation { duration: 450; easing.type: Easing.InOutQuad }
        }

        // Static dark backdrop.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#0b0b12" }
                GradientStop { position: 1.0; color: "#171724" }
            }
        }

        Image {
            anchors.fill: parent
            source: "file:///usr/share/plymouth/themes/elvonos/background.png"
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: true
        }

        // Soft heartbeat halo behind the wordmark.
        Image {
            id: glow
            anchors.fill: parent
            source: "file:///usr/share/plymouth/themes/elvonos/glow.png"
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: true
            opacity: 0.26

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.78; duration: 170; easing.type: Easing.OutQuad }
                NumberAnimation { to: 0.34; duration: 260; easing.type: Easing.InQuad }
                NumberAnimation { to: 0.66; duration: 150; easing.type: Easing.OutQuad }
                NumberAnimation { to: 0.30; duration: 520; easing.type: Easing.InOutQuad }
                PauseAnimation { duration: 1200 }
            }
        }

        Image {
            id: logo
            source: "file:///usr/share/plymouth/themes/elvonos/logo.png"
            width: Math.max(380, root.width * 0.34)
            height: width * (implicitHeight / implicitWidth)
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.height / 2 - height - 16
            asynchronous: false
            cache: true
        }

        Image {
            id: subtitle
            source: "file:///usr/share/plymouth/themes/elvonos/subtitle.png"
            width: Math.max(420, root.width * 0.30)
            height: width * (implicitHeight / implicitWidth)
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.height / 2 + 18
            asynchronous: false
            cache: true
        }

        // Slow orbiting spinner, one revolution every ~2.9 s.
        Item {
            id: spinner
            width: 90
            height: 90
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.height / 2 + 96 - height / 2

            Item {
                id: spinnerRot
                anchors.fill: parent

                Repeater {
                    model: 8
                    Rectangle {
                        required property int index
                        width: 12
                        height: 12
                        radius: 6
                        color: "#7FB4FF"
                        opacity: 1.0 - index * 0.09
                        x: spinnerRot.width / 2
                           + Math.cos(index * Math.PI / 4 - Math.PI / 2) * 36
                           - width / 2
                        y: spinnerRot.height / 2
                           + Math.sin(index * Math.PI / 4 - Math.PI / 2) * 36
                           - height / 2
                    }
                }

                NumberAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 2900
                    loops: Animation.Infinite
                    running: true
                }
            }
        }
    }

    // Called from main.cpp shortly after the desktop session is ready.
    function fadeOut() {
        fading = true;
        fadeAnimation.start();
    }

    NumberAnimation {
        id: fadeAnimation
        target: content
        property: "opacity"
        to: 0
        duration: 450
        easing.type: Easing.InOutQuad
    }
}

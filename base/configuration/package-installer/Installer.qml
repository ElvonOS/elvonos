import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: win

    function tr(text) {
        return lang.revision >= 0 ? lang.tr(text) : text
    }
    width: 760
    height: 560
    minimumWidth: 680
    minimumHeight: 500
    visible: true
    color: theme.background

    title: win.tr("Package Installer")

    Component.onCompleted: {
        win.requestActivate()
        Qt.callLater(function () { win.requestActivate() })
    }

    Shortcut { sequence: "Ctrl+Q"; onActivated: Qt.quit() }
    Shortcut { sequence: "Ctrl+W"; onActivated: Qt.quit() }
    Shortcut { sequence: "Escape"; onActivated: Qt.quit() }

    component ActionButton: Rectangle {
        id: button
        property string label: ""
        property bool active: false
        signal activated()

        width: Math.max(80, buttonText.implicitWidth + 26)
        height: 34
        radius: 9
        color: active ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.18) : (buttonHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086))
        border.width: 1
        border.color: active ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.33) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)

        Text {
            id: buttonText
            anchors.centerIn: parent
            text: button.label
            color: button.active ? theme.accent : theme.text
            font.pixelSize: 10
        }
        HoverHandler { id: buttonHover }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: button.activated()
        }
    }

    component WindowButton: Rectangle {
        id: wb
        property string glyph: "—"
        property string tip: ""
        property color hoverColor: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14)
        signal activated()

        width: 30
        height: 30
        radius: 8
        color: wbHover.hovered ? hoverColor : "transparent"

        Text {
            anchors.centerIn: parent
            text: wb.glyph
            color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.85)
            font.pixelSize: 13
        }
        HoverHandler { id: wbHover }
        ToolTip.visible: wbHover.hovered
        ToolTip.text: wb.tip
        ToolTip.delay: 300
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: wb.activated()
        }
    }

    component SectionLabel: Text {
        color: theme.muted
        font.pixelSize: 9
        font.letterSpacing: 1.2
    }

    Image {
        anchors.fill: parent
        source: "file:///usr/share/backgrounds/elvonos/wallpaper.png"
        fillMode: Image.PreserveAspectCrop
        opacity: theme.light ? 0.18 : 0.55
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.90) }
            GradientStop { position: 1.0; color: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.94) }
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        /* Title bar */
        Rectangle {
            width: parent.width
            height: 64
            radius: 16
            color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.80)
            border.width: 1
            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.15)

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Rectangle {
                    width: 32; height: 32; radius: 9
                    color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.13)
                    border.width: 1
                    border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.33)
                    Text { anchors.centerIn: parent; text: "⤓"; color: theme.accent; font.pixelSize: 16 }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        text: win.tr("PACKAGE INSTALLER")
                        color: theme.text
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.1
                    }
                    Text {
                        text: win.tr("Debian packages and AppImages")
                        color: theme.muted
                        font.pixelSize: 9
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                WindowButton {
                    width: 18
                    glyph: "⠿"
                    tip: win.tr("Drag to move window")
                    hoverColor: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.09)
                    onActivated: win.startSystemMove()
                }
                Rectangle { width: 1; height: 22; color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12) }
                WindowButton { glyph: "—"; tip: win.tr("Minimize"); onActivated: win.showMinimized() }
                WindowButton {
                    glyph: win.visibility === Window.Maximized ? "❐" : "□"
                    tip: win.visibility === Window.Maximized ? win.tr("Restore") : win.tr("Maximize")
                    onActivated: {
                        if (win.visibility === Window.Maximized)
                            win.showNormal()
                        else
                            win.showMaximized()
                    }
                }
                WindowButton {
                    glyph: "✕"
                    tip: win.tr("Close")
                    hoverColor: "#C42B1C"
                    onActivated: Qt.quit()
                }
            }
        }

        /* File card */
        Rectangle {
            width: parent.width
            height: 210
            radius: 16
            color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, theme.glass / 100)
            border.width: 1
            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                Item {
                    width: parent.width
                    height: 34

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Rectangle {
                            width: 64; height: 30; radius: 8
                            color: installer.kind === "deb" ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.10) : theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.14) : "#193326"
                            border.width: 1
                            border.color: installer.kind === "deb" ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.20) : "#557ED6A5"
                            Text {
                                anchors.centerIn: parent
                                text: installer.kind === "deb" ? win.tr("DEB") : win.tr("APPIMAGE")
                                color: installer.kind === "deb" ? theme.accent : theme.text
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.8
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: installer.sizeText
                            color: theme.muted
                            font.pixelSize: 9
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: installer.status
                        color: installer.ok ? theme.light ? "#2E8B57" : "#8FD3A8" : theme.light ? "#B3261E" : "#FFB4B0"
                        font.pixelSize: 9
                        elide: Text.ElideRight
                        width: Math.min(320, parent.width * 0.5)
                        horizontalAlignment: Text.AlignRight
                    }
                }

                Text {
                    text: installer.fileName.length > 0
                          ? installer.fileName : win.tr("No package selected")
                    color: theme.text
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    elide: Text.ElideMiddle
                    width: parent.width
                }

                Text {
                    visible: installer.packageName.length > 0
                    text: installer.packageName + "  " + installer.packageVersion
                    color: theme.accent
                    font.pixelSize: 10
                }

                Text {
                    text: installer.description.length > 0
                          ? installer.description
                          : (installer.kind === "appimage"
                             ? win.tr("Portable application — make it executable and run it.")
                             : win.tr("Double-click a .deb or .AppImage to manage it here."))
                    color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.80)
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    width: parent.width
                }

                Rectangle {
                    width: parent.width
                    height: 34
                    radius: 9
                    color: installer.kind === "deb" ? theme.light ? Qt.rgba(0.70, 0.15, 0.12, 0.12) : "#2A1E1E" : theme.light ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.10) : "#16202A"
                    border.width: 1
                    border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.20)
                    Text {
                        anchors.centerIn: parent
                        text: installer.kind === "deb"
                              ? win.tr("Installing changes the running system. Make sure the package is trusted.")
                              : win.tr("AppImages run without installation and keep their files portable.")
                        color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.85)
                        font.pixelSize: 9
                    }
                }
            }
        }

        /* Actions */
        Row {
            width: parent.width
            height: 40
            spacing: 8

            ActionButton {
                label: installer.kind === "deb" ? win.tr("Install package")
                                               : win.tr("Run application")
                active: true
                opacity: installer.busy || installer.kind === "unknown" ? 0.4 : 1.0
                onActivated: {
                    if (installer.busy)
                        return
                    if (installer.kind === "deb")
                        confirmDialog.open()
                    else if (installer.kind === "appimage")
                        installer.runAppImage()
                }
            }
            ActionButton {
                label: win.tr("Open folder")
                onActivated: installer.openFolder()
            }
            Item { width: parent.width - 2 * 130 - 90 - 24; height: 1 }
            ActionButton {
                label: win.tr("Close")
                width: 90
                onActivated: Qt.quit()
            }
        }

        /* Log */
        Rectangle {
            width: parent.width
            height: parent.height - 64 - 210 - 40 - 24 - 40
            radius: 12
            color: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.60)
            border.width: 1
            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)
            clip: true

            Flickable {
                anchors.fill: parent
                anchors.margins: 10
                clip: true
                contentWidth: width
                contentHeight: logText.implicitHeight

                TextEdit {
                    id: logText
                    width: parent.width
                    text: installer.log
                    color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.80)
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: 9
                    wrapMode: TextEdit.Wrap
                    readOnly: true
                }
            }

            Text {
                anchors.centerIn: parent
                visible: installer.log.length === 0
                text: installer.kind === "deb"
                      ? win.tr("The installation log appears here.")
                      : win.tr("Choose Run application to start the AppImage.")
                color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.60)
                font.pixelSize: 10
            }

            BusyIndicator {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 8
                width: 20; height: 20
                running: installer.busy
                visible: installer.busy
            }
        }
    }

    Dialog {
        id: confirmDialog
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        width: 460
        padding: 16

        background: Rectangle {
            color: theme.surface
            radius: 14
            border.width: 1
            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.20)
        }

        contentItem: Column {
            spacing: 12

            Text {
                text: win.tr("INSTALL PACKAGE")
                color: theme.text
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 1.1
            }
            Text {
                text: win.tr("Install ") + (installer.packageName.length > 0
                                    ? installer.packageName : installer.fileName)
                      + " " + installer.packageVersion + win.tr("?\n\n")
                      + win.tr("Dependencies are resolved with apt. Only install packages you trust.")
                color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.80)
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                width: 420
            }
            Row {
                spacing: 8
                anchors.right: parent.right
                ActionButton {
                    label: win.tr("Cancel")
                    width: 80
                    onActivated: confirmDialog.reject()
                }
                Rectangle {
                    width: 110
                    height: 34
                    radius: 9
                    color: installHover.hovered ? "#2A7ED6A5" : theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.14) : "#193326"
                    border.width: 1
                    border.color: "#557ED6A5"
                    Text {
                        anchors.centerIn: parent
                        text: win.tr("Install")
                        color: theme.text
                        font.pixelSize: 10
                    }
                    HoverHandler { id: installHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            confirmDialog.accept()
                            installer.installDeb()
                        }
                    }
                }
            }
        }
    }
}

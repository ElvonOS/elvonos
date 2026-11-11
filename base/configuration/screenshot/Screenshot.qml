import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: win

    function tr(text) {
        return lang.revision >= 0 ? lang.tr(text) : text
    }
    width: 1120
    height: 610
    minimumWidth: 1000
    minimumHeight: 560
    visible: true
    color: theme.background

    property string mode: "full"
    property int delaySeconds: 0
    property bool includeCursor: false
    property bool jpeg: false

    title: win.tr("Screenshot")

    Component.onCompleted: {
        win.requestActivate()
        Qt.callLater(function () { win.requestActivate() })
    }

    Shortcut { sequence: "Ctrl+Q"; onActivated: Qt.quit() }
    Shortcut { sequence: "Ctrl+W"; onActivated: Qt.quit() }
    Shortcut { sequence: "F5"; onActivated: shot.refresh() }

    /* ---------------- components ---------------- */

    component ToolButton: Rectangle {
        id: button
        property string label: ""
        property bool active: false
        signal activated()

        width: Math.max(56, labelText.implicitWidth + 24)
        height: 30
        radius: 8
        color: active ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.18) : (buttonHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086))
        border.width: active ? 1 : 0
        border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.20)

        Text {
            id: labelText
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

    /* ---------------- background ---------------- */

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

        /* ---------------- Title bar ---------------- */
        Rectangle {
            width: parent.width
            height: 70
            radius: 18
            color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.80)
            border.width: 1
            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.15)

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Rectangle {
                    width: 34; height: 34; radius: 10
                    color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.13)
                    border.width: 1
                    border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.33)
                    Text { anchors.centerIn: parent; text: "▣"; color: theme.accent; font.pixelSize: 15 }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        text: win.tr("SCREENSHOT")
                        color: theme.text
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.2
                    }
                    Text {
                        text: win.tr("Capture  ·  preview  ·  share")
                        color: theme.muted
                        font.pixelSize: 9
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                WindowButton {
                    width: 18
                    glyph: "⠿"
                    tip: win.tr("Drag to move window")
                    hoverColor: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.09)
                    onActivated: win.startSystemMove()
                }

                Rectangle { width: 1; height: 24; color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12) }

                WindowButton {
                    glyph: "—"
                    tip: win.tr("Minimize")
                    onActivated: win.showMinimized()
                }
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

        /* ---------------- Options + preview + history ---------------- */
        Item {
            width: parent.width
            height: parent.height - 70 - 10

            Column {
                anchors.left: parent.left
                anchors.top: parent.top
                width: parent.width - 392
                height: parent.height
                spacing: 10

                /* Capture options */
                Rectangle {
                    width: parent.width
                    height: 232
                    radius: 16
                    color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, theme.glass / 100)
                    border.width: 1
                    border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)

                    Column {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        SectionLabel { text: win.tr("CAPTURE MODE") }
                        Row {
                            spacing: 8
                            ToolButton {
                                label: win.tr("Full screen")
                                active: win.mode === "full"
                                onActivated: win.mode = "full"
                            }
                            ToolButton {
                                label: win.tr("Region")
                                active: win.mode === "region"
                                onActivated: win.mode = "region"
                            }
                            Text {
                                text: win.mode === "region"
                                      ? win.tr("Drag a rectangle with the mouse after capturing")
                                      : win.tr("Captures the whole desktop")
                                color: theme.muted
                                font.pixelSize: 9
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        SectionLabel { text: win.tr("DELAY") }
                        Row {
                            spacing: 8
                            ToolButton { label: win.tr("Now"); active: win.delaySeconds === 0; onActivated: win.delaySeconds = 0 }
                            ToolButton { label: win.tr("3 s"); active: win.delaySeconds === 3; onActivated: win.delaySeconds = 3 }
                            ToolButton { label: win.tr("5 s"); active: win.delaySeconds === 5; onActivated: win.delaySeconds = 5 }
                            ToolButton { label: win.tr("10 s"); active: win.delaySeconds === 10; onActivated: win.delaySeconds = 10 }
                        }

                        SectionLabel { text: win.tr("OPTIONS") }
                        Row {
                            width: parent.width
                            spacing: 8
                            ToolButton {
                                label: win.includeCursor ? win.tr("Cursor: on") : win.tr("Cursor: off")
                                active: win.includeCursor
                                onActivated: win.includeCursor = !win.includeCursor
                            }
                            ToolButton {
                                label: win.tr("PNG")
                                active: !win.jpeg
                                onActivated: win.jpeg = false
                            }
                            ToolButton {
                                label: win.tr("JPEG")
                                active: win.jpeg
                                onActivated: win.jpeg = true
                            }
                            Text {
                                text: shot.saveDir
                                color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.70)
                                font.pixelSize: 9
                                elide: Text.ElideMiddle
                                width: Math.max(60, parent.width - 250)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 46
                            radius: 10
                            color: shot.busy ? theme.light ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.10) : "#16202A" : (captureHover.hovered ? "#2A7ED6A5" : theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.14) : "#193326")
                            border.width: 1
                            border.color: "#557ED6A5"
                            opacity: shot.busy ? 0.6 : 1.0

                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                BusyIndicator {
                                    width: 18; height: 18
                                    running: shot.busy
                                    visible: shot.busy
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: shot.busy
                                          ? win.tr("Capturing…")
                                          : (win.mode === "region"
                                             ? win.tr("Select region & capture")
                                             : win.tr("Capture screenshot"))
                                    color: theme.text
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }
                            }

                            HoverHandler { id: captureHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: !shot.busy
                                onClicked: shot.capture(win.mode, win.delaySeconds,
                                                        win.includeCursor, win.jpeg)
                            }
                        }
                    }
                }

                /* Preview */
                Rectangle {
                    width: parent.width
                    height: parent.height - 232 - 10
                    radius: 16
                    color: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.80)
                    border.width: 1
                    border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.15)
                    clip: true

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Row {
                            width: parent.width
                            height: 22
                            SectionLabel { text: win.tr("PREVIEW"); anchors.verticalCenter: parent.verticalCenter }
                            Item { width: parent.width - 70 - 220; height: 1 }
                            Text {
                                text: shot.lastPath.length > 0
                                      ? shot.lastPath.substring(shot.lastPath.lastIndexOf("/") + 1)
                                      : ""
                                color: theme.muted
                                font.pixelSize: 9
                                elide: Text.ElideMiddle
                                width: 220
                                horizontalAlignment: Text.AlignRight
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: parent.height - 22 - 34 - 16
                            radius: 10
                            color: theme.background
                            clip: true

                            Image {
                                anchors.fill: parent
                                anchors.margins: 6
                                source: shot.lastPath.length > 0
                                        ? win.tr("file://") + shot.lastPath : ""
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                cache: false
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: shot.lastPath.length === 0
                                text: win.tr("No screenshot yet")
                                color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.60)
                                font.pixelSize: 12
                            }
                        }

                        Row {
                            width: parent.width
                            height: 34
                            spacing: 8

                            Text {
                                text: shot.status
                                color: shot.ok ? theme.light ? "#2E8B57" : "#8FD3A8" : theme.light ? "#B3261E" : "#FFB4B0"
                                font.pixelSize: 9
                                elide: Text.ElideRight
                                width: parent.width - 240
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            ToolButton {
                                label: win.tr("Copy")
                                enabled: shot.lastPath.length > 0
                                opacity: enabled ? 1.0 : 0.4
                                onActivated: shot.copyLast()
                            }
                            ToolButton {
                                label: win.tr("Open")
                                enabled: shot.lastPath.length > 0
                                opacity: enabled ? 1.0 : 0.4
                                onActivated: shot.openLast()
                            }
                            ToolButton {
                                label: win.tr("Delete")
                                enabled: shot.lastPath.length > 0
                                opacity: enabled ? 1.0 : 0.4
                                onActivated: deleteDialog.open()
                            }
                        }
                    }
                }
            }

            /* History */
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 382
                radius: 16
                color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.92)
                border.width: 1
                border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14)
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Row {
                        width: parent.width
                        height: 22
                        SectionLabel { text: win.tr("RECENT"); anchors.verticalCenter: parent.verticalCenter }
                        Item { width: parent.width - 80 - 60; height: 1 }
                        Text {
                            text: shot.recent.length + win.tr(" items")
                            color: theme.muted
                            font.pixelSize: 9
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    GridView {
                        width: parent.width
                        height: parent.height - 30
                        clip: true
                        cellWidth: (width - 8) / 2
                        cellHeight: 128
                        model: shot.recent

                        delegate: Rectangle {
                            required property string path
                            required property string thumb
                            required property string name
                            required property string date
                            required property string size

                            width: GridView.view ? GridView.view.cellWidth - 8 : 0
                            height: GridView.view ? GridView.view.cellHeight - 8 : 0
                            radius: 9
                            color: shot.lastPath === path ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.10)
                                                        : (historyHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.08) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.04))
                            border.width: 1
                            border.color: shot.lastPath === path ? "#337ED6A5" : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.08)

                            Column {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 3

                                Rectangle {
                                    width: parent.width
                                    height: parent.height - 30
                                    radius: 6
                                    color: theme.background
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: thumb
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: false
                                    }
                                }
                                Text {
                                    width: parent.width
                                    text: date
                                    color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.85)
                                    font.pixelSize: 8
                                    elide: Text.ElideRight
                                }
                            }

                            HoverHandler { id: historyHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: shot.select(path)
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: shot.recent.length === 0
                            text: win.tr("No screenshots yet")
                            color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.60)
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: deleteDialog
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        width: 430
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
                text: win.tr("DELETE SCREENSHOT")
                color: theme.text
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 1.1
            }
            Text {
                text: win.tr("Remove the selected screenshot permanently?")
                color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.80)
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                width: 390
            }
            Row {
                spacing: 8
                anchors.right: parent.right

                ToolButton {
                    label: win.tr("Cancel")
                    onActivated: deleteDialog.reject()
                }
                Rectangle {
                    width: 90
                    height: 30
                    radius: 9
                    color: deleteHover.hovered ? "#C42B1C" : theme.light ? Qt.rgba(0.70, 0.15, 0.12, 0.12) : "#2A1E1E"
                    border.width: 1
                    border.color: "#55FF6B6B"
                    Text {
                        anchors.centerIn: parent
                        text: win.tr("Delete")
                        color: theme.light ? "#B3261E" : "#FFB4B0"
                        font.pixelSize: 10
                    }
                    HoverHandler { id: deleteHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            shot.deleteLast()
                            deleteDialog.accept()
                        }
                    }
                }
            }
        }
    }
}

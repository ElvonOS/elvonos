import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: win

    function tr(text) {
        return lang.revision >= 0 ? lang.tr(text) : text
    }
    width: 460
    height: 560
    minimumWidth: 420
    minimumHeight: 520
    visible: true
    color: theme.background

    title: win.tr("Taskbar Settings")

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

        width: Math.max(84, buttonText.implicitWidth + 28)
        height: 32
        radius: 9
        color: active ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.18) : (buttonHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086))
        border.width: active ? 1 : 0
        border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.20)

        Text {
            id: buttonText
            anchors.centerIn: parent
            width: button.width - 16
            text: button.label
            color: button.active ? theme.accent : theme.text
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
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

    component ToggleRow: Rectangle {
        id: row
        property string label: ""
        property bool checked: false
        signal toggled()

        width: parent ? parent.width : 0
        height: 32
        radius: 8
        color: rowHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.08) : "transparent"

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            color: theme.text
            font.pixelSize: 10
        }

        Rectangle {
            width: 40
            height: 20
            radius: 10
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            color: row.checked ? "#2A7ED6A5" : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14)
            border.width: 1
            border.color: row.checked ? "#557ED6A5" : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.20)

            Rectangle {
                width: 16
                height: 16
                radius: 8
                anchors.verticalCenter: parent.verticalCenter
                x: row.checked ? 21 : 3
                color: row.checked ? theme.text : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.68)

                Behavior on x { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 130 } }
            }
        }

        HoverHandler { id: rowHover }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: row.toggled()
        }
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
                    Text { anchors.centerIn: parent; text: "▦"; color: theme.accent; font.pixelSize: 16 }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        text: win.tr("TASKBAR SETTINGS")
                        color: theme.text
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.1
                    }
                    Text {
                        text: win.tr("Layout, system tray and window grouping")
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
                    glyph: "✕"
                    tip: win.tr("Close")
                    hoverColor: "#C42B1C"
                    onActivated: Qt.quit()
                }
            }
        }

        /* Bar height */
        Rectangle {
            width: parent.width
            height: 86
            radius: 14
            color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, theme.glass / 100)
            border.width: 1
            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                SectionLabel { text: win.tr("BAR HEIGHT") }
                Row {
                    spacing: 8
                    ActionButton {
                        label: win.tr("Compact")
                        active: settings.height === 44
                        onActivated: settings.height = 44
                    }
                    ActionButton {
                        label: win.tr("Normal")
                        active: settings.height === 54
                        onActivated: settings.height = 54
                    }
                    ActionButton {
                        label: win.tr("Large")
                        active: settings.height === 62
                        onActivated: settings.height = 62
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: settings.height + win.tr(" px")
                        color: theme.muted
                        font.pixelSize: 9
                    }
                }
            }
        }

        /* Behaviour */
        Rectangle {
            width: parent.width
            height: 312
            radius: 14
            color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, theme.glass / 100)
            border.width: 1
            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 2

                SectionLabel { text: win.tr("BEHAVIOUR") }
                Item { width: 1; height: 4 }

                ToggleRow {
                    label: win.tr("Group duplicate windows")
                    checked: settings.groupDuplicates
                    onToggled: settings.groupDuplicates = !settings.groupDuplicates
                }
                ToggleRow {
                    label: win.tr("System tray")
                    checked: settings.showTray
                    onToggled: settings.showTray = !settings.showTray
                }
                ToggleRow {
                    label: win.tr("Volume icon")
                    checked: settings.showVolume
                    onToggled: settings.showVolume = !settings.showVolume
                }
                ToggleRow {
                    label: win.tr("Network icon")
                    checked: settings.showNetwork
                    onToggled: settings.showNetwork = !settings.showNetwork
                }
                ToggleRow {
                    label: win.tr("Battery icon")
                    checked: settings.showBattery
                    onToggled: settings.showBattery = !settings.showBattery
                }
                ToggleRow {
                    label: win.tr("Clock")
                    checked: settings.showClock
                    onToggled: settings.showClock = !settings.showClock
                }
                ToggleRow {
                    label: win.tr("Window count")
                    checked: settings.showCount
                    onToggled: settings.showCount = !settings.showCount
                }
                ToggleRow {
                    label: win.tr("Window titles")
                    checked: settings.showTitles
                    onToggled: settings.showTitles = !settings.showTitles
                }
            }
        }

        /* Footer */
        Row {
            width: parent.width
            height: 32
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: settings.status
                color: theme.light ? "#2E8B57" : "#8FD3A8"
                font.pixelSize: 9
                elide: Text.ElideRight
                width: parent.width - 260
            }
            Item { width: 20; height: 1 }
            ActionButton {
                label: win.tr("Reset defaults")
                width: 118
                onActivated: settings.resetDefaults()
            }
            ActionButton {
                label: win.tr("Close")
                width: 86
                onActivated: Qt.quit()
            }
        }
    }
}

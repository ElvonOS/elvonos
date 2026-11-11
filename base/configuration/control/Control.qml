import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: win

    function tr(text) {
        return lang.revision >= 0 ? lang.tr(text) : text
    }
    width: 1120
    height: 610
    visible: true
    title: win.tr("Control Center")
    color: theme.background

    property int tab: 0

    Component.onCompleted: {
        win.requestActivate()
        Qt.callLater(function () { win.requestActivate() })
    }

    Shortcut { sequence: "F5"; onActivated: tune.refresh() }
    Shortcut { sequence: "Ctrl+1"; onActivated: win.tab = 0 }
    Shortcut { sequence: "Ctrl+2"; onActivated: win.tab = 1 }
    Shortcut { sequence: "Ctrl+3"; onActivated: win.tab = 2 }
    Shortcut { sequence: "Ctrl+Q"; onActivated: tune.quit() }
    Shortcut { sequence: "Ctrl+W"; onActivated: tune.quit() }
    Shortcut { sequence: "Ctrl+M"; onActivated: win.showMinimized() }

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

        /* ---------------- Toolbar ---------------- */
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
                    Text { anchors.centerIn: parent; text: "⚙"; color: theme.accent2; font.pixelSize: 17 }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: win.tr("CONTROL CENTER"); color: theme.text; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1.2 }
                    Text { text: win.tr("Performance & protection"); color: theme.muted; font.pixelSize: 9 }
                }
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 250
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    width: 116; height: 32; radius: 9
                    color: win.tab === 0 ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14) : perfHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.09) : "transparent"
                    border.width: win.tab === 0 ? 1 : 0
                    border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.33)
                    HoverHandler { id: perfHover }
                    Text { anchors.centerIn: parent; text: win.tr("Performance"); color: win.tab === 0 ? theme.text : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.75); font.pixelSize: 10 }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.tab = 0
                    }
                }

                Rectangle {
                    width: 110; height: 32; radius: 9
                    color: win.tab === 1 ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14) : protHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.09) : "transparent"
                    border.width: win.tab === 1 ? 1 : 0
                    border.color: "#557ED6A5"
                    HoverHandler { id: protHover }
                    Text { anchors.centerIn: parent; text: win.tr("Protection"); color: win.tab === 1 ? theme.text : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.75); font.pixelSize: 10 }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.tab = 1
                    }
                }

                Rectangle {
                    width: 86; height: 32; radius: 9
                    color: win.tab === 2 ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14) : audioHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.09) : "transparent"
                    border.width: win.tab === 2 ? 1 : 0
                    border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.33)
                    HoverHandler { id: audioHover }
                    Text { anchors.centerIn: parent; text: win.tr("Audio"); color: win.tab === 2 ? theme.text : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.75); font.pixelSize: 10 }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.tab = 2
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    width: 32; height: 32; radius: 9
                    color: refreshHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : "transparent"
                    Text { anchors.centerIn: parent; text: "⟳"; color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.85); font.pixelSize: 15 }
                    HoverHandler { id: refreshHover }
                    ToolTip.visible: refreshHover.hovered
                    ToolTip.text: win.tr("Refresh status (F5)")
                    ToolTip.delay: 300
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tune.refresh()
                    }
                }

                Rectangle {
                    width: 18; height: 30; radius: 6
                    color: gripHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.09) : "transparent"
                    Text { anchors.centerIn: parent; text: "⠿"; color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.70); font.pixelSize: 13 }
                    HoverHandler { id: gripHover }
                    ToolTip.visible: gripHover.hovered
                    ToolTip.text: win.tr("Drag to move window")
                    ToolTip.delay: 300
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.SizeAllCursor
                        onPressed: win.startSystemMove()
                    }
                }

                Rectangle { width: 1; height: 24; color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12) }

                Rectangle {
                    width: 30; height: 30; radius: 8
                    color: minHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : "transparent"
                    Text { anchors.centerIn: parent; text: "—"; color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.85); font.pixelSize: 14 }
                    HoverHandler { id: minHover }
                    ToolTip.visible: minHover.hovered
                    ToolTip.text: win.tr("Minimize")
                    ToolTip.delay: 300
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.showMinimized() }
                }

                Rectangle {
                    width: 30; height: 30; radius: 8
                    color: maxHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: win.visibility === Window.Maximized ? "❐" : "□"
                        color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.85); font.pixelSize: 12
                    }
                    HoverHandler { id: maxHover }
                    ToolTip.visible: maxHover.hovered
                    ToolTip.text: win.visibility === Window.Maximized ? win.tr("Restore") : win.tr("Maximize")
                    ToolTip.delay: 300
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (win.visibility === Window.Maximized)
                                win.showNormal()
                            else
                                win.showMaximized()
                        }
                    }
                }

                Rectangle {
                    width: 30; height: 30; radius: 8
                    color: closeHover.hovered ? "#C42B1C" : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: closeHover.hovered ? theme.text : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.85)
                        font.pixelSize: 13
                    }
                    HoverHandler { id: closeHover }
                    ToolTip.visible: closeHover.hovered
                    ToolTip.text: win.tr("Close")
                    ToolTip.delay: 300
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tune.quit() }
                }
            }
        }

        /* ---------------- Content ---------------- */
        Rectangle {
            width: parent.width
            height: parent.height - 70 - 10
            radius: 18
            color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.92)
            border.width: 1
            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14)
            clip: true

            /* Performance tab */
            Column {
                visible: win.tab === 0
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: footer.top
                anchors.margins: 14
                spacing: 12

                Row {
                    width: parent.width
                    height: 92
                    spacing: 10

                    Rectangle {
                        width: (parent.width - 30) / 4
                        height: parent.height
                        radius: 15
                        color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.40)
                        border.width: 1
                        border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)
                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 3
                            Text { text: win.tr("CPU GOVERNOR"); color: theme.muted; font.pixelSize: 9; font.letterSpacing: 1.2 }
                            Text { text: tune.governor; color: theme.accent2; font.pixelSize: 17; font.weight: Font.DemiBold }
                            Text { text: tune.cpuCount + win.tr(" cores  ·  swappiness ") + tune.swappiness; color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90); font.pixelSize: 9 }
                        }
                    }

                    Rectangle {
                        width: (parent.width - 30) / 4
                        height: parent.height
                        radius: 15
                        color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.40)
                        border.width: 1
                        border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)
                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4
                            Text { text: win.tr("MEMORY"); color: theme.muted; font.pixelSize: 9; font.letterSpacing: 1.2 }
                            Text { text: Math.round(tune.memoryPercent) + "%"; color: theme.light ? "#1E7A4D" : "#7ED6A5"; font.pixelSize: 17; font.weight: Font.DemiBold }
                            Rectangle {
                                width: parent.width; height: 5; radius: 2.5; color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)
                                Rectangle {
                                    width: parent.width * Math.min(1, tune.memoryPercent / 100)
                                    height: parent.height; radius: 2.5; color: theme.light ? "#1E7A4D" : "#7ED6A5"
                                    Behavior on width { NumberAnimation { duration: 250 } }
                                }
                            }
                            Text { text: tune.memoryText; color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90); font.pixelSize: 9; elide: Text.ElideRight; width: parent.width }
                        }
                    }

                    Rectangle {
                        width: (parent.width - 30) / 4
                        height: parent.height
                        radius: 15
                        color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.40)
                        border.width: 1
                        border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)
                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4
                            Text { text: win.tr("ZRAM / SWAP"); color: theme.muted; font.pixelSize: 9; font.letterSpacing: 1.2 }
                            Text { text: tune.zramText; color: theme.accent2; font.pixelSize: 17; font.weight: Font.DemiBold }
                            Rectangle {
                                width: parent.width; height: 5; radius: 2.5; color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)
                                Rectangle {
                                    width: parent.width * Math.min(1, tune.swapPercent / 100)
                                    height: parent.height; radius: 2.5; color: theme.accent2
                                    Behavior on width { NumberAnimation { duration: 250 } }
                                }
                            }
                            Text { text: tune.swapText; color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90); font.pixelSize: 9; elide: Text.ElideRight; width: parent.width }
                        }
                    }

                    Rectangle {
                        width: (parent.width - 30) / 4
                        height: parent.height
                        radius: 15
                        color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.40)
                        border.width: 1
                        border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)
                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 3
                            Text { text: win.tr("LOAD AVERAGE"); color: theme.muted; font.pixelSize: 9; font.letterSpacing: 1.2 }
                            Text { text: tune.loadText; color: theme.light ? "#8A6A00" : "#F5D67B"; font.pixelSize: 16; font.weight: Font.DemiBold }
                            Text { text: win.tr("1 / 5 / 15 minutes"); color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90); font.pixelSize: 9 }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 168
                    spacing: 12

                    Rectangle {
                        width: 400
                        height: parent.height
                        radius: 15
                        color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.40)
                        border.width: 1
                        border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)

                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8
                            Text { text: win.tr("PERFORMANCE PROFILE"); color: theme.muted; font.pixelSize: 9; font.letterSpacing: 1.3 }
                            Text {
                                text: win.tr("Balanced keeps the system responsive and saves power; Performance prefers clock speed; Powersave reduces energy use.")
                                color: theme.muted
                                font.pixelSize: 9
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                            Row {
                                spacing: 8
                                Repeater {
                                    model: [
                                        { id: "balanced", label: win.tr("Balanced") },
                                        { id: "performance", label: win.tr("Performance") },
                                        { id: "powersave", label: win.tr("Powersave") }
                                    ]
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: 116; height: 34; radius: 9
                                        color: tune.profile === modelData.id ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14)
                                               : profileHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086)
                                        border.width: tune.profile === modelData.id ? 1 : 0
                                        border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.33)
                                        opacity: tune.busy ? 0.5 : 1.0
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            color: tune.profile === modelData.id ? theme.text : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.85)
                                            font.pixelSize: 10
                                        }
                                        HoverHandler { id: profileHover }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: !tune.busy
                                            onClicked: tune.applyProfile(modelData.id)
                                        }
                                    }
                                }
                            }
                            Text {
                                text: win.tr("Applied immediately: CPU governor, energy preference, swappiness and cache pressure.")
                                color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.70)
                                font.pixelSize: 9
                                width: parent.width
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width - 412
                        height: parent.height
                        radius: 15
                        color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.40)
                        border.width: 1
                        border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)

                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10
                            Text { text: win.tr("SYSTEM TUNING"); color: theme.muted; font.pixelSize: 9; font.letterSpacing: 1.3 }

                            Row {
                                width: parent.width
                                spacing: 10
                                Rectangle {
                                    width: 40; height: 22; radius: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: tune.zram ? "#337ED6A5" : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)
                                    border.width: 1
                                    border.color: tune.zram ? theme.light ? "#1E7A4D" : "#7ED6A5" : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.20)
                                    Rectangle {
                                        width: 16; height: 16; radius: 8
                                        y: 2
                                        x: tune.zram ? 21 : 3
                                        color: tune.zram ? theme.light ? "#1E7A4D" : "#7ED6A5" : Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.85)
                                        Behavior on x { NumberAnimation { duration: 120 } }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        enabled: !tune.busy
                                        onClicked: tune.setZram(!tune.zram)
                                    }
                                }
                                Column {
                                    width: parent.width - 50
                                    Text { text: win.tr("ZRAM compressed swap"); color: theme.text; font.pixelSize: 11 }
                                    Text {
                                        text: tune.zram ? win.tr("Active, ") + tune.zramText + win.tr(" compressed RAM")
                                                        : win.tr("Disabled")
                                        color: theme.muted; font.pixelSize: 9
                                    }
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: 10
                                Rectangle {
                                    width: 40; height: 22; radius: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: tune.waydroidLimit ? "#337ED6A5" : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)
                                    border.width: 1
                                    border.color: tune.waydroidLimit ? theme.light ? "#1E7A4D" : "#7ED6A5" : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.20)
                                    Rectangle {
                                        width: 16; height: 16; radius: 8
                                        y: 2
                                        x: tune.waydroidLimit ? 21 : 3
                                        color: tune.waydroidLimit ? theme.light ? "#1E7A4D" : "#7ED6A5" : Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.85)
                                        Behavior on x { NumberAnimation { duration: 120 } }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        enabled: !tune.busy
                                        onClicked: tune.setWaydroidLimit(!tune.waydroidLimit)
                                    }
                                }
                                Column {
                                    width: parent.width - 50
                                    Text { text: win.tr("Waydroid protection"); color: theme.text; font.pixelSize: 11 }
                                    Text {
                                        text: tune.waydroidRunning
                                              ? (tune.waydroidLimit ? win.tr("Memory capped at 75% RAM, higher CPU weight")
                                                                    : win.tr("No memory cap, normal CPU weight"))
                                              : win.tr("Waydroid is not running")
                                        color: tune.waydroidRunning ? theme.muted : Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90)
                                        font.pixelSize: 9
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: parent.height - 92 - 168 - 24
                    radius: 15
                    color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.40)
                    border.width: 1
                    border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)

                    Column {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 6
                        Text { text: win.tr("HOW IT WORKS"); color: theme.muted; font.pixelSize: 9; font.letterSpacing: 1.3 }
                        Text {
                            text: win.tr("The tuning profile is applied by the root helper through passwordless sudo. Balanced uses schedutil (or the closest\navailable governor), enables ZRAM swap and tunes swappiness and cache pressure. The settings are reapplied on every boot\nby elvonos-tune.service. Waydroid protection limits the Android container to 75% of RAM and raises its CPU weight.")
                            color: theme.muted
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                    }
                }
            }

            /* Protection tab */
            Column {
                visible: win.tab === 1
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: footer.top
                anchors.margins: 14
                spacing: 12

                Rectangle {
                    width: parent.width
                    height: 150
                    radius: 15
                    color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.40)
                    border.width: 1
                    border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)

                    Row {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 16

                        Rectangle {
                            width: 56; height: 56; radius: 16
                            anchors.verticalCenter: parent.verticalCenter
                            color: tune.firewall ? theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.14) : "#193326" : theme.light ? Qt.rgba(0.70, 0.15, 0.12, 0.12) : "#2A1E1E"
                            border.width: 1
                            border.color: tune.firewall ? "#557ED6A5" : "#55FF8A80"
                            Text {
                                anchors.centerIn: parent
                                text: tune.firewall ? "✓" : "!"
                                color: tune.firewall ? theme.light ? "#1E7A4D" : "#7ED6A5" : theme.light ? "#B3261E" : "#FFB4B0"
                                font.pixelSize: 24
                            }
                        }

                        Column {
                            width: parent.width - 56 - 16 - 190 - 16
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            Text { text: win.tr("FIREWALL"); color: theme.muted; font.pixelSize: 9; font.letterSpacing: 1.3 }
                            Text {
                                text: tune.firewall ? win.tr("Protection active") : win.tr("Firewall disabled")
                                color: tune.firewall ? theme.light ? "#1E7A4D" : "#7ED6A5" : theme.light ? "#B3261E" : "#FFB4B0"
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: win.tr("Inbound connections are dropped by default. Loopback, established/related traffic, ICMP, DHCP replies and SSH are allowed.")
                                color: theme.muted
                                font.pixelSize: 9
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        Rectangle {
                            width: 190; height: 40; radius: 10
                            anchors.verticalCenter: parent.verticalCenter
                            color: tune.firewall
                                   ? (firewallHover.hovered ? "#C42B1C" : theme.light ? Qt.rgba(0.70, 0.15, 0.12, 0.18) : "#3A1E1E")
                                   : (firewallHover.hovered ? "#2A7ED6A5" : theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.14) : "#193326")
                            border.width: 1
                            border.color: tune.firewall ? "#66FF8A80" : "#557ED6A5"
                            opacity: tune.busy ? 0.5 : 1.0
                            Text {
                                anchors.centerIn: parent
                                text: tune.firewall ? win.tr("Disable protection") : win.tr("Enable protection")
                                color: tune.firewall ? theme.light ? "#B3261E" : "#FFB4B0" : theme.light ? "#256B47" : "#9FE6C0"
                                font.pixelSize: 10
                            }
                            HoverHandler { id: firewallHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: !tune.busy
                                onClicked: tune.setFirewall(!tune.firewall)
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 140
                    spacing: 12

                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: parent.height
                        radius: 15
                        color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.40)
                        border.width: 1
                        border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)

                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 6
                            Text { text: win.tr("WAYDROID"); color: theme.muted; font.pixelSize: 9; font.letterSpacing: 1.3 }
                            Text {
                                text: tune.waydroidRunning ? win.tr("Android container running") : win.tr("Android container stopped")
                                color: tune.waydroidRunning ? theme.light ? "#1E7A4D" : "#7ED6A5" : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.75)
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: tune.waydroidLimit
                                      ? win.tr("Memory capped at 75% of RAM; CPU weight raised for smoother apps.")
                                      : win.tr("No memory cap. Enable protection to keep Android from exhausting the host.")
                                color: theme.muted
                                font.pixelSize: 9
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                            Rectangle {
                                width: 160; height: 30; radius: 9
                                color: tune.waydroidLimit ? theme.light ? Qt.rgba(0.70, 0.15, 0.12, 0.18) : "#3A1E1E" : theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.14) : "#193326"
                                border.width: 1
                                border.color: tune.waydroidLimit ? "#66FF8A80" : "#557ED6A5"
                                opacity: tune.busy ? 0.5 : 1.0
                                Text {
                                    anchors.centerIn: parent
                                    text: tune.waydroidLimit ? win.tr("Remove limit") : win.tr("Apply limit")
                                    color: tune.waydroidLimit ? theme.light ? "#B3261E" : "#FFB4B0" : theme.light ? "#256B47" : "#9FE6C0"
                                    font.pixelSize: 10
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !tune.busy
                                    onClicked: tune.setWaydroidLimit(!tune.waydroidLimit)
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: (parent.width - 12) / 2
                        height: parent.height
                        radius: 15
                        color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.40)
                        border.width: 1
                        border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)

                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 5
                            Text { text: win.tr("ALLOWED INBOUND"); color: theme.muted; font.pixelSize: 9; font.letterSpacing: 1.3 }
                            Text { text: win.tr("✓  Loopback (lo)"); color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.75); font.pixelSize: 10 }
                            Text { text: win.tr("✓  Established / related"); color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.75); font.pixelSize: 10 }
                            Text { text: win.tr("✓  ICMP and ICMPv6 (ping)"); color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.75); font.pixelSize: 10 }
                            Text { text: win.tr("✓  DHCP replies"); color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.75); font.pixelSize: 10 }
                            Text { text: win.tr("✓  SSH (tcp/22)"); color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.75); font.pixelSize: 10 }
                            Text { text: win.tr("✕  Everything else"); color: theme.light ? "#B3261E" : "#FFB4B0"; font.pixelSize: 10 }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: parent.height - 150 - 140 - 24
                    radius: 15
                    color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.40)
                    border.width: 1
                    border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)

                    Column {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 6
                        Text { text: win.tr("LAYERED PROTECTION"); color: theme.muted; font.pixelSize: 9; font.letterSpacing: 1.3 }
                        Text {
                            text: win.tr("The firewall is applied with nftables as the inet elvonos table and cannot be bypassed by unprivileged processes.\nThe performance service applies the saved profile, ZRAM and firewall state on every boot. Use the Protection tab to\ntemporarily disable the firewall for troubleshooting; the setting persists for the current live session.")
                            color: theme.muted
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                    }
                }
            }

            /* Audio tab */
            Column {
                visible: win.tab === 2
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: footer.top
                anchors.margins: 14
                spacing: 12

                Row {
                    width: parent.width
                    height: parent.height
                    spacing: 12

                    Column {
                        width: (parent.width - 12) * 0.58
                        height: parent.height
                        spacing: 12

                        Rectangle {
                            width: parent.width
                            height: 236
                            radius: 15
                            color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.40)
                            border.width: 1
                            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)

                            Column {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 10

                                Text {
                                    text: win.tr("NOISE PROTECTION")
                                    color: theme.muted
                                    font.pixelSize: 9
                                    font.letterSpacing: 1.3
                                }

                                Row {
                                    width: parent.width
                                    spacing: 10

                                    Rectangle {
                                        width: 116; height: 30; radius: 9
                                        color: tune.noiseProtection ? theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.14) : "#193326" : theme.light ? Qt.rgba(0.70, 0.15, 0.12, 0.12) : "#2A1E1E"
                                        border.width: 1
                                        border.color: tune.noiseProtection ? "#557ED6A5" : "#55FF6B6B"
                                        Text {
                                            anchors.centerIn: parent
                                            text: tune.noiseProtection ? win.tr("ACTIVE") : win.tr("OFF")
                                            color: tune.noiseProtection ? theme.text : theme.light ? "#B3261E" : "#FFB4B0"
                                            font.pixelSize: 9
                                            font.weight: Font.DemiBold
                                            font.letterSpacing: 1.0
                                        }
                                    }

                                    Item {
                                        width: Math.max(0, parent.width - 116 - 10 - 150)
                                        height: 1
                                    }

                                    Rectangle {
                                        width: 150; height: 32; radius: 9
                                        color: tune.audioBusy
                                               ? theme.light ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.10) : "#16202A"
                                               : (noiseToggleHover.hovered ? "#2A7ED6A5" : theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.14) : "#193326")
                                        border.width: 1
                                        border.color: "#557ED6A5"
                                        opacity: tune.audioBusy ? 0.4 : 1.0
                                        Text {
                                            anchors.centerIn: parent
                                            text: tune.noiseProtection ? win.tr("Disable") : win.tr("Enable")
                                            color: theme.text
                                            font.pixelSize: 10
                                        }
                                        HoverHandler { id: noiseToggleHover }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: !tune.audioBusy
                                            onClicked: tune.setNoiseProtection(!tune.noiseProtection)
                                        }
                                    }
                                }

                                Text {
                                    text: win.tr("WebRTC noise suppression, high-pass filtering, gain control and echo cancellation run inside PipeWire. Audio applications use the virtual microphone \"ElvonOS Noise-Free Microphone\".")
                                    color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.80)
                                    font.pixelSize: 10
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                                Text {
                                    text: win.tr("Default source: ") + tune.defaultSource
                                    color: theme.muted
                                    font.pixelSize: 9
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                                BusyIndicator {
                                    width: 18; height: 18
                                    running: tune.audioBusy
                                    visible: tune.audioBusy
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: parent.height - 248
                            radius: 15
                            color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.40)
                            border.width: 1
                            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)

                            Column {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 8

                                Text {
                                    text: win.tr("LAPTOP INTERFERENCE")
                                    color: theme.muted
                                    font.pixelSize: 9
                                    font.letterSpacing: 1.3
                                }
                                Text {
                                    text: win.tr("On compact laptops the audio codec sits close to the GPU and CPU power stages. Electrical interference and codec power-save clicks are picked up as hiss, buzzing or crackle.\n\nThis profile keeps the HDA codec powered (no power-save pops), runs stable 1024-frame buffers to avoid underruns, and removes steady background noise from the microphone with WebRTC suppression.")
                                    color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.80)
                                    font.pixelSize: 10
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width - (parent.width - 12) * 0.58 - 12
                        height: parent.height
                        spacing: 12

                        Rectangle {
                            width: parent.width
                            height: 200
                            radius: 15
                            color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.40)
                            border.width: 1
                            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)

                            Column {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 7

                                Text {
                                    text: win.tr("AUDIO ENGINE")
                                    color: theme.muted
                                    font.pixelSize: 9
                                    font.letterSpacing: 1.3
                                }
                                Text {
                                    text: win.tr("48 kHz")
                                    color: theme.accent2
                                    font.pixelSize: 17
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    text: win.tr("PipeWire · WirePlumber")
                                    color: theme.muted
                                    font.pixelSize: 9
                                }
                                Text { text: win.tr("Buffer   1024 frames (~21 ms)"); color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.80); font.pixelSize: 10 }
                                Text { text: win.tr("Suspend on idle   off"); color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.80); font.pixelSize: 10 }
                                Text { text: win.tr("HDA power-save   off"); color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.80); font.pixelSize: 10 }

                                Rectangle {
                                    width: 132; height: 30; radius: 9
                                    color: restartHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086)
                                    opacity: tune.audioBusy ? 0.4 : 1.0
                                    Text {
                                        anchors.centerIn: parent
                                        text: win.tr("Restart audio")
                                        color: theme.text
                                        font.pixelSize: 9
                                    }
                                    HoverHandler { id: restartHover }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        enabled: !tune.audioBusy
                                        onClicked: tune.restartAudio()
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: parent.height - 212
                            radius: 15
                            color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.40)
                            border.width: 1
                            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)

                            Column {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 8

                                Text {
                                    text: win.tr("WHAT THIS CAN AND CANNOT DO")
                                    color: theme.muted
                                    font.pixelSize: 9
                                    font.letterSpacing: 1.3
                                }
                                Text {
                                    text: win.tr("Clean microphone input and fewer crackles/pops are software-fixable. A high-pitched whine that is present even in quiet passages and disappears with headphones connected is electrical coil noise from the board; software cannot remove it. In that case: use headphones or an external USB DAC, keep the charger away from the audio jack, and avoid the lowest CPU power states.")
                                    color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.80)
                                    font.pixelSize: 10
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }
                            }
                        }
                    }
                }
            }

            /* Footer */
            Rectangle {
                id: footer
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 34
                color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.60)

                Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12) }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.right: busyRow.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: tune.result.length > 0
                          ? tune.result
                          : (win.tab === 1
                             ? (tune.firewall ? win.tr("Firewall active") : win.tr("Firewall disabled"))
                             : (win.tab === 2
                                ? tune.audioStatus
                                : win.tr("Profile: ") + tune.profile + win.tr("  ·  ZRAM: ") + (tune.zram ? win.tr("on") : win.tr("off"))))
                    color: tune.result.length > 0
                           ? (tune.resultOk ? theme.light ? "#2E8B57" : "#8FD3A8" : theme.light ? "#B3261E" : "#FFB4B0")
                           : theme.muted
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

                Row {
                    id: busyRow
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    BusyIndicator {
                        width: 20; height: 20
                        running: tune.busy
                        visible: tune.busy
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tune.busy ? win.tr("Applying…") : win.tr("Ready")
                        color: tune.busy ? theme.light ? "#8A6A00" : "#F5D67B" : theme.light ? "#1E7A4D" : "#7ED6A5"
                        font.pixelSize: 10
                    }
                }
            }
        }
    }
}

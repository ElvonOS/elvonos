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
    title: win.tr("Store")
    color: theme.background

    property bool androidTab: false
    property int removeIndex: -1
    property string removeName: ""

    function refreshCurrent() {
        if (androidTab)
            androidModel.refresh()
        else
            flatpakModel.refresh()
    }

    Component.onCompleted: {
        win.requestActivate()
        Qt.callLater(function () { win.requestActivate() })
        flatpakModel.refresh()
        androidModel.refresh()
    }

    Shortcut { sequence: "F5"; onActivated: win.refreshCurrent() }
    Shortcut { sequence: "Ctrl+F"; onActivated: searchField.forceActiveFocus() }
    Shortcut {
        sequence: "Ctrl+1"
        onActivated: { win.androidTab = false; searchField.text = "" }
    }
    Shortcut {
        sequence: "Ctrl+2"
        onActivated: { win.androidTab = true; searchField.text = "" }
    }
    Shortcut { sequence: "Ctrl+Q"; onActivated: Qt.quit() }
    Shortcut { sequence: "Ctrl+W"; onActivated: Qt.quit() }
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
                id: logoRow
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Rectangle {
                    width: 34; height: 34; radius: 10
                    color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.13)
                    border.width: 1
                    border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.33)
                    Text { anchors.centerIn: parent; text: "◈"; color: theme.accent2; font.pixelSize: 17 }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: win.tr("STORE"); color: theme.text; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1.2 }
                    Text { text: win.tr("Linux & Android"); color: theme.muted; font.pixelSize: 9 }
                }
            }

            Row {
                id: tabRow
                anchors.left: logoRow.right
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    width: 104; height: 32; radius: 9
                    color: !win.androidTab ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14) : tabLinux.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.09) : "transparent"
                    border.width: !win.androidTab ? 1 : 0
                    border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.33)
                    HoverHandler { id: tabLinux }
                    Text {
                        anchors.centerIn: parent
                        text: win.tr("Linux (") + flatpakModel.count + ")"
                        color: !win.androidTab ? theme.text : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.75)
                        font.pixelSize: 10
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { win.androidTab = false; searchField.text = "" }
                    }
                }

                Rectangle {
                    width: 112; height: 32; radius: 9
                    color: win.androidTab ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14) : tabAndroid.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.09) : "transparent"
                    border.width: win.androidTab ? 1 : 0
                    border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.33)
                    HoverHandler { id: tabAndroid }
                    Text {
                        anchors.centerIn: parent
                        text: win.tr("Android (") + androidModel.count + ")"
                        color: win.androidTab ? theme.text : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.75)
                        font.pixelSize: 10
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { win.androidTab = true; searchField.text = "" }
                    }
                }
            }

            Rectangle {
                id: searchBox
                anchors.left: tabRow.right
                anchors.leftMargin: 14
                anchors.right: rightControls.left
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                height: 34
                radius: 10
                color: theme.surface
                border.width: 1
                border.color: searchField.activeFocus ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.33) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 6
                    Text { text: "⌕"; color: theme.muted; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                    TextField {
                        id: searchField
                        width: parent.width - 28
                        height: parent.height
                        placeholderText: win.androidTab ? win.tr("Search Android apps…") : win.tr("Search Linux apps…")
                        color: theme.text
                        placeholderTextColor: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90)
                        background: null
                        font.pixelSize: 11
                        onTextChanged: {
                            flatpakModel.filter = text
                            androidModel.filter = text
                        }
                    }
                }
            }

            Row {
                id: rightControls
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
                    ToolTip.text: win.tr("Refresh (F5)")
                    ToolTip.delay: 300
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.refreshCurrent()
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
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Qt.quit() }
                }
            }
        }

        /* ---------------- Flathub setup ---------------- */
        Rectangle {
            visible: !flatpakModel.flathubReady
            width: parent.width
            height: 54
            radius: 14
            color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.10)
            border.width: 1
            border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.30)

            Row {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 10
                spacing: 12

                Text {
                    width: parent.width - 190
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.tr("Flathub is not set up. Enable Flatpak support to browse and install Linux apps.")
                    color: theme.text
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    width: 150; height: 32; radius: 9
                    anchors.verticalCenter: parent.verticalCenter
                    color: setupHover.hovered
                           ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28)
                           : Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.16)
                    border.width: 1
                    border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.45)

                    Text {
                        anchors.centerIn: parent
                        text: win.tr("Set up Flathub")
                        color: theme.text
                        font.pixelSize: 10
                    }
                    HoverHandler { id: setupHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: flatpakModel.setupFlathub()
                    }
                }
            }
        }

        /* ---------------- Content ---------------- */
        Rectangle {
            width: parent.width
            height: parent.height - 70 - 10 - (flatpakModel.flathubReady ? 0 : 64)
            radius: 18
            color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.92)
            border.width: 1
            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14)
            clip: true

            /* Linux list */
            ListView {
                id: linuxList
                visible: !win.androidTab
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: footer.top
                clip: true
                model: flatpakModel
                spacing: 4
                topMargin: 10
                leftMargin: 10
                rightMargin: 10

                delegate: Rectangle {
                    id: linuxRow
                    required property int index
                    required property string appId
                    required property string name
                    required property string summary
                    required property bool installed
                    required property string icon

                    width: linuxList.width - 20
                    height: 74
                    radius: 12
                    color: rowHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.07) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.03)
                    border.width: rowHover.hovered ? 1 : 0
                    border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.20)

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        Rectangle {
                            width: 44; height: 44; radius: 11
                            anchors.verticalCenter: parent.verticalCenter
                            color: theme.surface
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: linuxRow.icon
                                fillMode: Image.PreserveAspectFit
                                visible: linuxRow.icon.length > 0
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: linuxRow.icon.length === 0
                                text: linuxRow.name.length > 0 ? linuxRow.name.charAt(0).toUpperCase() : "?"
                                color: theme.accent2
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                            }
                        }

                        Column {
                            width: parent.width - 44 - 12 - 190
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                text: linuxRow.name
                                color: theme.text
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            Text {
                                text: linuxRow.appId
                                color: theme.muted
                                font.pixelSize: 9
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            Text {
                                text: linuxRow.summary
                                color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.85)
                                font.pixelSize: 9
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        Row {
                            width: 190
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Rectangle {
                                width: 90; height: 30; radius: 9
                                color: linuxRow.installed ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.20) : theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.14) : "#193326"
                                border.width: 1
                                border.color: linuxRow.installed ? Qt.rgba(theme.accent2.r, theme.accent2.g, theme.accent2.b, 0.33) : "#557ED6A5"
                                opacity: flatpakModel.busy ? 0.45 : 1.0
                                Text {
                                    anchors.centerIn: parent
                                    text: linuxRow.installed ? win.tr("Open") : win.tr("Install")
                                    color: linuxRow.installed ? theme.text : theme.light ? "#256B47" : "#9FE6C0"
                                    font.pixelSize: 10
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !flatpakModel.busy
                                    onClicked: {
                                        if (linuxRow.installed)
                                            flatpakModel.launch(linuxRow.index)
                                        else
                                            flatpakModel.install(linuxRow.index)
                                    }
                                }
                            }

                            Rectangle {
                                width: 30; height: 30; radius: 9
                                visible: linuxRow.installed
                                color: removeHover.hovered ? theme.light ? Qt.rgba(0.70, 0.15, 0.12, 0.18) : "#3A1E1E" : "transparent"
                                border.width: visible ? 1 : 0
                                border.color: "#33FF8A80"
                                opacity: flatpakModel.busy ? 0.45 : 1.0
                                Text { anchors.centerIn: parent; text: "⌫"; color: theme.light ? "#B3261E" : "#FFB4B0"; font.pixelSize: 12 }
                                HoverHandler { id: removeHover }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !flatpakModel.busy
                                    onClicked: {
                                        win.removeIndex = linuxRow.index
                                        win.removeName = linuxRow.name
                                        removeDialog.open()
                                    }
                                }
                            }
                        }
                    }

                    HoverHandler { id: rowHover }
                }
            }

            /* Android tab */
            Column {
                visible: win.androidTab
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: footer.top
                anchors.margins: 12
                spacing: 10

                Rectangle {
                    width: parent.width
                    height: 78
                    radius: 14
                    color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.40)
                    border.width: 1
                    border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)

                    Row {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Rectangle {
                            width: 50; height: 50; radius: 13
                            anchors.verticalCenter: parent.verticalCenter
                            color: theme.surface
                            clip: true
                            Image {
                                anchors.fill: parent
                                source: "file:///usr/share/icons/elvonos/metro/aurora-store.png"
                                fillMode: Image.PreserveAspectFit
                            }
                            Text {
                                anchors.centerIn: parent
                                text: win.tr("A")
                                color: theme.accent2
                                font.pixelSize: 20
                                font.weight: Font.DemiBold
                                visible: false
                            }
                        }

                        Column {
                            width: parent.width - 50 - 12 - 170 - 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text { text: win.tr("Aurora Store"); color: theme.text; font.pixelSize: 13; font.weight: Font.DemiBold }
                            Text {
                                text: win.tr("Install Android apps from Google Play through Waydroid. Aurora handles sign-in and updates.")
                                color: theme.muted
                                font.pixelSize: 9
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }

                        Rectangle {
                            width: 160; height: 34; radius: 9
                            anchors.verticalCenter: parent.verticalCenter
                            color: auroraHover.hovered ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14) : Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.20)
                            border.width: 1
                            border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.33)
                            Text { anchors.centerIn: parent; text: win.tr("Open Aurora Store"); color: theme.text; font.pixelSize: 10 }
                            HoverHandler { id: auroraHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: androidModel.openAurora()
                            }
                        }
                    }
                }

                ListView {
                    id: androidList
                    width: parent.width
                    height: parent.height - 88
                    clip: true
                    model: androidModel
                    spacing: 4

                    delegate: Rectangle {
                        id: appRow
                        required property int index
                        required property string name
                        required property string packageName
                        required property string icon

                        width: androidList.width
                        height: 66
                        radius: 11
                        color: appHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.07) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.03)

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12

                            Rectangle {
                                width: 38; height: 38; radius: 10
                                anchors.verticalCenter: parent.verticalCenter
                                color: theme.surface
                                clip: true
                                Image {
                                    anchors.fill: parent
                                    source: appRow.icon
                                    fillMode: Image.PreserveAspectFit
                                }
                            }

                            Column {
                                width: parent.width - 38 - 12 - 90
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Text { text: appRow.name; color: theme.text; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight; width: parent.width }
                                Text { text: appRow.packageName; color: theme.muted; font.pixelSize: 9; elide: Text.ElideRight; width: parent.width }
                            }

                            Rectangle {
                                width: 76; height: 30; radius: 9
                                anchors.verticalCenter: parent.verticalCenter
                                color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.20)
                                border.width: 1
                                border.color: Qt.rgba(theme.accent2.r, theme.accent2.g, theme.accent2.b, 0.33)
                                Text { anchors.centerIn: parent; text: win.tr("Open"); color: theme.text; font.pixelSize: 10 }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: androidModel.launch(appRow.index)
                                }
                            }
                        }

                        HoverHandler { id: appHover }
                    }

                    Column {
                        anchors.centerIn: parent
                        visible: androidModel.count === 0
                        spacing: 6
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: win.tr("No Android apps installed yet.")
                            color: theme.muted
                            font.pixelSize: 12
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: win.tr("Open Aurora Store to install apps, then refresh.")
                            color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.70)
                            font.pixelSize: 10
                        }
                    }
                }
            }

            /* Loading overlay */
            Rectangle {
                anchors.fill: parent
                visible: !win.androidTab && flatpakModel.busy && flatpakModel.count === 0
                color: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.80)

                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    BusyIndicator { anchors.horizontalCenter: parent.horizontalCenter; running: true }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: flatpakModel.status
                        color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.75)
                        font.pixelSize: 12
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
                    text: win.androidTab
                          ? androidModel.count + win.tr(" Android apps  ·  managed through Aurora Store")
                          : flatpakModel.status
                    color: theme.muted
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
                        width: 18; height: 18
                        running: flatpakModel.busy && !win.androidTab
                        visible: running
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (flatpakModel.busy && !win.androidTab)
                              ? win.tr("Working…")
                              : (win.androidTab ? win.tr("Android") : win.tr("Flathub"))
                        color: theme.light ? "#1E7A4D" : "#7ED6A5"
                        font.pixelSize: 10
                    }
                }
            }
        }
    }

    Dialog {
        id: removeDialog
        modal: true
        anchors.centerIn: Overlay.overlay
        width: 440
        title: win.tr("Remove application")
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: flatpakModel.uninstall(win.removeIndex)
        background: Rectangle { color: theme.surface; radius: 16; border.width: 1; border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.20) }
        contentItem: Text {
            text: win.tr("Remove ") + win.removeName + win.tr("?\n\nThe Flatpak application and its data may be removed.")
            color: theme.text
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
    }
}

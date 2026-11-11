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
    title: win.tr("Defrag")
    color: theme.background

    property int selectedIndex: -1
    property var selectedInfo: ({})
    property int confirmIndex: -1

    function selectVolume(index) {
        selectedIndex = index
        selectedInfo = index >= 0 ? diskModel.volumeInfo(index) : ({})
    }

    function refreshVolumes() {
        diskModel.refresh()
        if (dishCount() > 0) {
            const keep = Math.min(selectedIndex, dishCount() - 1)
            selectVolume(keep >= 0 ? keep : 0)
        } else {
            selectVolume(-1)
        }
    }

    function dishCount() { return diskModel.count }

    Component.onCompleted: {
        win.requestActivate()
        Qt.callLater(function () { win.requestActivate() })
        if (diskModel.count > 0)
            selectVolume(0)
    }

    Connections {
        target: diskModel
        function onVolumesChanged() {
            if (win.selectedIndex >= 0 && win.selectedIndex < diskModel.count)
                win.selectedInfo = diskModel.volumeInfo(win.selectedIndex)
            else if (diskModel.count > 0)
                win.selectVolume(0)
            else {
                win.selectedIndex = -1
                win.selectedInfo = ({})
            }
        }
    }

    Shortcut { sequence: "F5"; onActivated: win.refreshVolumes() }
    Shortcut { sequence: "Ctrl+Q"; onActivated: Qt.quit() }
    Shortcut { sequence: "Ctrl+W"; onActivated: Qt.quit() }
    Shortcut { sequence: "Ctrl+M"; onActivated: win.showMinimized() }
    Shortcut {
        sequence: "Up"
        enabled: win.selectedIndex > 0 && !diskModel.busy
        onActivated: win.selectVolume(win.selectedIndex - 1)
    }
    Shortcut {
        sequence: "Down"
        enabled: win.selectedIndex >= 0 && win.selectedIndex < diskModel.count - 1 && !diskModel.busy
        onActivated: win.selectVolume(win.selectedIndex + 1)
    }
    Shortcut {
        sequence: "Ctrl+Shift+D"
        enabled: win.selectedIndex >= 0 && diskModel.canDefrag(win.selectedIndex) && !diskModel.busy
        onActivated: { win.confirmIndex = win.selectedIndex; defragDialog.open() }
    }
    Shortcut {
        sequence: "Ctrl+Shift+A"
        enabled: win.selectedIndex >= 0 && diskModel.canAnalyze(win.selectedIndex) && !diskModel.busy
        onActivated: diskModel.analyze(win.selectedIndex)
    }
    Shortcut {
        sequence: "Ctrl+Shift+T"
        enabled: win.selectedIndex >= 0 && diskModel.canTrim(win.selectedIndex) && !diskModel.busy
        onActivated: diskModel.trim(win.selectedIndex)
    }

    /* ---------------- Glass backdrop ---------------- */
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
                    color: Qt.rgba(theme.accent2.r, theme.accent2.g, theme.accent2.b, 0.13)
                    border.width: 1
                    border.color: Qt.rgba(theme.accent2.r, theme.accent2.g, theme.accent2.b, 0.33)
                    Text { anchors.centerIn: parent; text: "◍"; color: theme.accent2; font.pixelSize: 17 }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: win.tr("DEFRAG"); color: theme.text; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1.2 }
                    Text { text: win.tr("Disk optimizer"); color: theme.muted; font.pixelSize: 9 }
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
                    ToolTip.text: win.tr("Refresh volumes (F5)")
                    ToolTip.delay: 300
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.refreshVolumes()
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

        /* ---------------- Summary ---------------- */
        Row {
            width: parent.width
            height: 78
            spacing: 10

            Rectangle {
                width: (parent.width - 20) / 3
                height: parent.height
                radius: 16
                color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, theme.glass / 100)
                border.width: 1
                border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14)
                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4
                    Text { text: win.tr("VOLUMES"); color: theme.muted; font.pixelSize: 9; font.letterSpacing: 1.3 }
                    Text { text: diskModel.count; color: theme.accent2; font.pixelSize: 18; font.weight: Font.DemiBold }
                    Text { text: win.tr("mounted filesystems"); color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90); font.pixelSize: 9 }
                }
            }

            Rectangle {
                width: (parent.width - 20) / 3
                height: parent.height
                radius: 16
                color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, theme.glass / 100)
                border.width: 1
                border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14)
                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4
                    Text { text: win.tr("SUPPORTED"); color: theme.muted; font.pixelSize: 9; font.letterSpacing: 1.3 }
                    Text { text: diskModel.supportedCount; color: theme.light ? "#1E7A4D" : "#7ED6A5"; font.pixelSize: 18; font.weight: Font.DemiBold }
                    Text { text: win.tr("ready for defrag/TRIM"); color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90); font.pixelSize: 9 }
                }
            }

            Rectangle {
                width: (parent.width - 20) / 3
                height: parent.height
                radius: 16
                color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, theme.glass / 100)
                border.width: 1
                border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14)
                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4
                    Text { text: win.tr("STATUS"); color: theme.muted; font.pixelSize: 9; font.letterSpacing: 1.3 }
                    Text {
                        text: diskModel.busy ? win.tr("Working") : win.tr("Idle")
                        color: diskModel.busy ? theme.light ? "#8A6A00" : "#F5D67B" : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.75)
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: diskModel.busy ? diskModel.task : win.tr("Select a volume")
                        color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90)
                        font.pixelSize: 9
                        width: parent.width
                        elide: Text.ElideRight
                    }
                }
            }
        }

        /* ---------------- Main ---------------- */
        Rectangle {
            width: parent.width
            height: parent.height - 70 - 78 - 20
            radius: 18
            color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.92)
            border.width: 1
            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14)
            clip: true

            Row {
                anchors.fill: parent
                anchors.margins: 12
                anchors.bottomMargin: 36
                spacing: 12

                /* Volume list */
                Rectangle {
                    width: 400
                    height: parent.height
                    radius: 14
                    color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.40)
                    border.width: 1
                    border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)
                    clip: true

                    Rectangle {
                        id: listHeader
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 34
                        radius: 14
                        color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.60)
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: win.tr("MOUNTED FILESYSTEMS")
                            color: theme.muted
                            font.pixelSize: 9
                            font.letterSpacing: 1.3
                        }
                    }

                    ListView {
                        id: volumeList
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: listHeader.bottom
                        anchors.bottom: parent.bottom
                        anchors.margins: 6
                        clip: true
                        model: diskModel
                        currentIndex: win.selectedIndex
                        spacing: 4

                        delegate: Rectangle {
                            id: volumeRow
                            required property int index
                            required property string label
                            required property string device
                            required property string mountPoint
                            required property string fs
                            required property string size
                            required property string free
                            required property bool supported
                            required property string icon

                            width: volumeList.width
                            height: 62
                            radius: 10
                            color: win.selectedIndex === volumeRow.index ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14)
                                   : rowHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.07) : "transparent"
                            border.width: win.selectedIndex === volumeRow.index ? 1 : 0
                            border.color: Qt.rgba(theme.accent2.r, theme.accent2.g, theme.accent2.b, 0.33)

                            Behavior on color { ColorAnimation { duration: 90 } }

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10

                                Image {
                                    width: 26; height: 26
                                    source: volumeRow.icon
                                    fillMode: Image.PreserveAspectFit
                                }

                                Column {
                                    width: 270
                                    spacing: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        text: volumeRow.label
                                        color: theme.text
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                    Text {
                                        text: volumeRow.device + "  ·  " + volumeRow.fs.toUpperCase()
                                              + "  ·  " + volumeRow.size + "  ·  " + volumeRow.free + win.tr(" free")
                                        color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.85)
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                    Text {
                                        text: volumeRow.mountPoint
                                        color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90)
                                        font.pixelSize: 9
                                        elide: Text.ElideMiddle
                                        width: parent.width
                                    }
                                }

                                Rectangle {
                                    width: 58; height: 20; radius: 6
                                    color: volumeRow.supported ? theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.14) : "#193326" : theme.light ? Qt.rgba(0.70, 0.15, 0.12, 0.12) : "#2A1E1E"
                                    border.width: 1
                                    border.color: volumeRow.supported ? "#337ED6A5" : "#33FF8A80"
                                    Text {
                                        anchors.centerIn: parent
                                        text: volumeRow.supported ? win.tr("Ready") : win.tr("N/A")
                                        color: volumeRow.supported ? theme.light ? "#1E7A4D" : "#7ED6A5" : theme.light ? "#B3261E" : "#FFB4B0"
                                        font.pixelSize: 9
                                    }
                                }
                            }

                            HoverHandler { id: rowHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.selectVolume(volumeRow.index)
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        visible: diskModel.count === 0
                        spacing: 6
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: win.tr("No mounted filesystems found.")
                            color: theme.muted
                            font.pixelSize: 12
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: win.tr("Mount a disk or USB stick, then refresh.")
                            color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.70)
                            font.pixelSize: 10
                        }
                    }
                }

                /* Details + log */
                Column {
                    width: parent.width - 400 - 12
                    height: parent.height
                    spacing: 10

                    Rectangle {
                        width: parent.width
                        height: 96
                        radius: 14
                        color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.40)
                        border.width: 1
                        border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)

                        Row {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            Image {
                                width: 38; height: 38
                                anchors.verticalCenter: parent.verticalCenter
                                source: win.selectedInfo.icon !== undefined ? win.selectedInfo.icon : ""
                                fillMode: Image.PreserveAspectFit
                            }

                            Column {
                                width: parent.width - 160
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Text {
                                    text: win.selectedInfo.label !== undefined
                                          ? win.selectedInfo.label : win.tr("No volume selected")
                                    color: theme.text
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                                Text {
                                    text: win.selectedInfo.device !== undefined
                                          ? win.selectedInfo.device + "  ·  "
                                            + win.selectedInfo.fs.toUpperCase() + "  ·  "
                                            + win.selectedInfo.size + "  ·  "
                                            + win.selectedInfo.free + win.tr(" free")
                                          : win.tr("Select a volume on the left.")
                                    color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.85)
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                                Text {
                                    text: win.selectedInfo.mountPoint !== undefined
                                          ? win.selectedInfo.mountPoint
                                          : ""
                                    color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90)
                                    font.pixelSize: 9
                                    elide: Text.ElideMiddle
                                    width: parent.width
                                }
                            }

                            Rectangle {
                                width: 74; height: 24; radius: 8
                                anchors.verticalCenter: parent.verticalCenter
                                color: win.selectedInfo.supported ? theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.14) : "#193326" : theme.light ? Qt.rgba(0.70, 0.15, 0.12, 0.12) : "#2A1E1E"
                                border.width: 1
                                border.color: win.selectedInfo.supported ? "#337ED6A5" : "#33FF8A80"
                                Text {
                                    anchors.centerIn: parent
                                    text: win.selectedInfo.supported ? win.tr("Defrag OK") : win.tr("No defrag")
                                    color: win.selectedInfo.supported ? theme.light ? "#1E7A4D" : "#7ED6A5" : theme.light ? "#B3261E" : "#FFB4B0"
                                    font.pixelSize: 9
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        height: 32
                        spacing: 8

                        Rectangle {
                            width: 92; height: 32; radius: 9
                            color: (diskModel.canAnalyze(win.selectedIndex) && !diskModel.busy && analyzeHover.hovered)
                                   ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086)
                            opacity: (diskModel.canAnalyze(win.selectedIndex) && !diskModel.busy) ? 1.0 : 0.4
                            Text { anchors.centerIn: parent; text: win.tr("Analyze"); color: theme.text; font.pixelSize: 10 }
                            HoverHandler { id: analyzeHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: diskModel.canAnalyze(win.selectedIndex) && !diskModel.busy
                                onClicked: diskModel.analyze(win.selectedIndex)
                            }
                        }

                        Rectangle {
                            width: 108; height: 32; radius: 9
                            color: (diskModel.canDefrag(win.selectedIndex) && !diskModel.busy && defragHover.hovered)
                                   ? Qt.rgba(theme.accent2.r, theme.accent2.g, theme.accent2.b, 0.16) : Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.20)
                            border.width: 1
                            border.color: Qt.rgba(theme.accent2.r, theme.accent2.g, theme.accent2.b, 0.33)
                            opacity: (diskModel.canDefrag(win.selectedIndex) && !diskModel.busy) ? 1.0 : 0.4
                            Text { anchors.centerIn: parent; text: win.tr("Defragment"); color: theme.text; font.pixelSize: 10 }
                            HoverHandler { id: defragHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: diskModel.canDefrag(win.selectedIndex) && !diskModel.busy
                                onClicked: {
                                    win.confirmIndex = win.selectedIndex
                                    defragDialog.open()
                                }
                            }
                        }

                        Rectangle {
                            width: 82; height: 32; radius: 9
                            color: (diskModel.canTrim(win.selectedIndex) && !diskModel.busy && trimHover.hovered)
                                   ? theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.14) : "#193326" : theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.14) : "#193326"
                            border.width: 1
                            border.color: "#337ED6A5"
                            opacity: (diskModel.canTrim(win.selectedIndex) && !diskModel.busy) ? 1.0 : 0.4
                            Text { anchors.centerIn: parent; text: win.tr("TRIM"); color: theme.light ? "#1E7A4D" : "#7ED6A5"; font.pixelSize: 10 }
                            HoverHandler { id: trimHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: diskModel.canTrim(win.selectedIndex) && !diskModel.busy
                                onClicked: diskModel.trim(win.selectedIndex)
                            }
                        }

                        Rectangle {
                            width: 80; height: 32; radius: 9
                            visible: diskModel.busy
                            color: cancelHover.hovered ? "#C42B1C" : theme.light ? Qt.rgba(0.70, 0.15, 0.12, 0.18) : "#3A1E1E"
                            border.width: 1
                            border.color: "#66FF8A80"
                            Text { anchors.centerIn: parent; text: win.tr("Cancel"); color: theme.light ? "#B3261E" : "#FFB4B0"; font.pixelSize: 10 }
                            HoverHandler { id: cancelHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: diskModel.cancel()
                            }
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            visible: diskModel.busy
                            BusyIndicator { width: 22; height: 22; running: diskModel.busy }
                            Text {
                                text: diskModel.task
                                color: theme.light ? "#8A6A00" : "#F5D67B"
                                font.pixelSize: 9
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: parent.height - 96 - 32 - 20
                        radius: 14
                        color: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.60)
                        border.width: 1
                        border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)
                        clip: true

                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: 8
                            clip: true

                            TextArea {
                                id: logArea
                                readOnly: true
                                text: diskModel.output
                                color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.80)
                                font.family: "monospace"
                                font.pixelSize: 10
                                wrapMode: TextEdit.Wrap
                                background: null
                                onTextChanged: cursorPosition = length
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: diskModel.output.length === 0
                            text: win.tr("Select a filesystem, then Analyze, Defragment or TRIM.")
                            color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.70)
                            font.pixelSize: 11
                        }
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 30
                color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.60)

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: diskModel.result.length > 0
                          ? diskModel.result
                          : diskModel.count + win.tr(" filesystem(s)  ·  ")
                            + diskModel.supportedCount + win.tr(" supported")
                    color: diskModel.result.length > 0
                           ? (diskModel.resultOk ? theme.light ? "#2E8B57" : "#8FD3A8" : theme.light ? "#B3261E" : "#FFB4B0")
                           : theme.muted
                    font.pixelSize: 10
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: diskModel.busy ? win.tr("Operation running") : win.tr("Ready")
                    color: diskModel.busy ? theme.light ? "#8A6A00" : "#F5D67B" : theme.light ? "#1E7A4D" : "#7ED6A5"
                    font.pixelSize: 10
                }
            }
        }
    }

    Dialog {
        id: defragDialog
        modal: true
        anchors.centerIn: Overlay.overlay
        width: 440
        title: win.tr("Defragment filesystem")
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: diskModel.defragment(win.confirmIndex)
        background: Rectangle { color: theme.surface; radius: 16; border.width: 1; border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.20) }
        contentItem: Text {
            text: win.tr("Defragment ")
                  + (win.confirmIndex >= 0
                     ? diskModel.volumeInfo(win.confirmIndex).label : "")
                  + win.tr("?\n\nThis can take a while and writes to the disk.")
            color: theme.text
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
    }
}

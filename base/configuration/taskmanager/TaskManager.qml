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
    title: win.tr("Task Manager")
    color: theme.background

    property bool androidTab: false
    property int selectedPid: -1
    property string selectedName: ""
    property string selectedCmdline: ""
    property string selectedPackage: ""
    property string statusMessage: ""
    property int pendingPid: -1
    property string pendingPackage: ""
    property bool pendingForceStop: false
    property bool typing: searchField.activeFocus

    function modelForTab() { return androidTab ? androidModel : linuxModel }

    function clearSelection() {
        selectedPid = -1
        selectedName = ""
        selectedCmdline = ""
        selectedPackage = ""
    }

    function endTask() {
        if (selectedPid <= 0)
            return
        const ok = processScanner.killPid(selectedPid, false)
        win.statusMessage = ok ? win.tr("End signal sent to ") + win.selectedName
                               : win.tr("Could not end ") + win.selectedName
        statusTimer.restart()
        processScanner.refresh()
        win.clearSelection()
    }

    function requestForce() {
        if (selectedPid <= 0)
            return
        pendingPid = selectedPid
        pendingPackage = selectedPackage
        pendingForceStop = androidTab && selectedPackage.length > 0
        forceDialog.open()
    }

    function doForce() {
        if (pendingForceStop) {
            const ok = processScanner.forceStopPackage(pendingPackage)
            win.statusMessage = ok ? pendingPackage + win.tr(" force-stopped")
                                   : win.tr("Could not force-stop ") + pendingPackage
        } else {
            const ok = processScanner.killPid(pendingPid, true)
            win.statusMessage = ok ? win.tr("Killed PID ") + pendingPid
                                   : win.tr("Could not kill PID ") + pendingPid
        }
        statusTimer.restart()
        processScanner.refresh()
        win.clearSelection()
    }

    function sortBy(mode) {
        modelForTab().sortMode = mode
    }

    Component.onCompleted: {
        win.requestActivate()
        Qt.callLater(function () { win.requestActivate() })
    }

    Timer {
        id: statusTimer
        interval: 3500
        onTriggered: win.statusMessage = ""
    }

    Shortcut { sequence: "F5"; onActivated: processScanner.refresh() }
    Shortcut {
        sequence: "Ctrl+1"
        enabled: !forceDialog.visible
        onActivated: { win.androidTab = false; win.clearSelection(); searchField.text = "" }
    }
    Shortcut {
        sequence: "Ctrl+2"
        enabled: !forceDialog.visible
        onActivated: { win.androidTab = true; win.clearSelection(); searchField.text = "" }
    }
    Shortcut { sequence: "Ctrl+Q"; onActivated: explorerQuit() }
    Shortcut { sequence: "Ctrl+W"; onActivated: explorerQuit() }
    Shortcut { sequence: "Ctrl+M"; onActivated: win.showMinimized() }
    Shortcut {
        sequence: "Ctrl+F"
        enabled: !forceDialog.visible
        onActivated: searchField.forceActiveFocus()
    }
    Shortcut {
        sequence: "Escape"
        enabled: !forceDialog.visible
        onActivated: { win.clearSelection(); searchField.text = "" }
    }
    Shortcut {
        sequences: [StandardKey.Delete]
        enabled: !win.typing && !forceDialog.visible && win.selectedPid > 0
        onActivated: win.endTask()
    }

    function explorerQuit() { processScanner.quit() }

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
                    color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.13)
                    border.width: 1
                    border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.33)
                    Text { anchors.centerIn: parent; text: "▦"; color: theme.accent2; font.pixelSize: 17 }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: win.tr("TASK MANAGER"); color: theme.text; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1.2 }
                    Text { text: win.tr("Linux & Android"); color: theme.muted; font.pixelSize: 9 }
                }
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 232
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    width: 108; height: 32; radius: 9
                    color: !win.androidTab ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14) : tabLinux.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.09) : "transparent"
                    border.width: !win.androidTab ? 1 : 0
                    border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.33)
                    HoverHandler { id: tabLinux }
                    Text {
                        anchors.centerIn: parent
                        text: win.tr("Linux (") + linuxModel.count + ")"
                        color: !win.androidTab ? theme.text : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.75)
                        font.pixelSize: 10
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { win.androidTab = false; win.clearSelection(); searchField.text = "" }
                    }
                }

                Rectangle {
                    width: 122; height: 32; radius: 9
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
                        onClicked: { win.androidTab = true; win.clearSelection(); searchField.text = "" }
                    }
                }
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 480
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    width: 230; height: 34; radius: 10
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
                            placeholderText: win.androidTab ? win.tr("Search Android processes…") : win.tr("Search processes…")
                            color: theme.text
                            placeholderTextColor: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90)
                            background: null
                            font.pixelSize: 11
                            onTextChanged: {
                                linuxModel.filter = text
                                androidModel.filter = text
                            }
                        }
                    }
                }

                Rectangle {
                    width: 32; height: 34; radius: 10
                    color: refreshHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : "transparent"
                    Text { anchors.centerIn: parent; text: "⟳"; color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.85); font.pixelSize: 15 }
                    HoverHandler { id: refreshHover }
                    ToolTip.visible: refreshHover.hovered
                    ToolTip.text: win.tr("Refresh (F5)")
                    ToolTip.delay: 300
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: processScanner.refresh()
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

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
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: processScanner.quit() }
                }
            }
        }

        /* ---------------- Summary cards ---------------- */
        Row {
            width: parent.width
            height: 82
            spacing: 10

            Rectangle {
                width: (parent.width - 30) / 4
                height: parent.height
                radius: 16
                color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, theme.glass / 100)
                border.width: 1
                border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14)

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6
                    Row {
                        spacing: 6
                        Text { text: win.tr("CPU"); color: theme.muted; font.pixelSize: 9; font.letterSpacing: 1.3 }
                        Item { width: 1; height: 1 }
                        Text { text: Math.round(processScanner.cpuPercent) + "%"; color: theme.accent2; font.pixelSize: 17; font.weight: Font.DemiBold }
                        Text { text: processScanner.cpuCount + win.tr(" cores"); color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90); font.pixelSize: 9; anchors.baseline: parent.bottom }
                    }
                    Rectangle {
                        width: parent.width; height: 6; radius: 3; color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)
                        Rectangle {
                            width: parent.width * Math.min(1, processScanner.cpuPercent / 100.0)
                            height: parent.height; radius: 3; color: theme.accent2
                            Behavior on width { NumberAnimation { duration: 250 } }
                        }
                    }
                    Text { text: win.tr("Load ") + processScanner.loadText; color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90); font.pixelSize: 9 }
                }
            }

            Rectangle {
                width: (parent.width - 30) / 4
                height: parent.height
                radius: 16
                color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, theme.glass / 100)
                border.width: 1
                border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14)

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6
                    Row {
                        spacing: 6
                        Text { text: win.tr("MEMORY"); color: theme.muted; font.pixelSize: 9; font.letterSpacing: 1.3 }
                        Item { width: 1; height: 1 }
                        Text { text: Math.round(processScanner.memoryPercent) + "%"; color: theme.light ? "#1E7A4D" : "#7ED6A5"; font.pixelSize: 17; font.weight: Font.DemiBold }
                    }
                    Rectangle {
                        width: parent.width; height: 6; radius: 3; color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)
                        Rectangle {
                            width: parent.width * Math.min(1, processScanner.memoryPercent / 100.0)
                            height: parent.height; radius: 3; color: theme.light ? "#1E7A4D" : "#7ED6A5"
                            Behavior on width { NumberAnimation { duration: 250 } }
                        }
                    }
                    Text { text: processScanner.memoryText; color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90); font.pixelSize: 9 }
                }
            }

            Rectangle {
                width: (parent.width - 30) / 4
                height: parent.height
                radius: 16
                color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, theme.glass / 100)
                border.width: 1
                border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14)

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6
                    Text { text: win.tr("PROCESSES"); color: theme.muted; font.pixelSize: 9; font.letterSpacing: 1.3 }
                    Text { text: processScanner.processCount; color: theme.accent2; font.pixelSize: 17; font.weight: Font.DemiBold }
                    Text {
                        text: linuxModel.count + win.tr(" Linux · ") + androidModel.count + win.tr(" Android")
                        color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90); font.pixelSize: 9
                    }
                }
            }

            Rectangle {
                width: (parent.width - 30) / 4
                height: parent.height
                radius: 16
                color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, theme.glass / 100)
                border.width: 1
                border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14)

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6
                    Text { text: win.tr("WAYDROID"); color: theme.muted; font.pixelSize: 9; font.letterSpacing: 1.3 }
                    Text {
                        text: processScanner.waydroidRunning ? win.tr("Running") : win.tr("Stopped")
                        color: processScanner.waydroidRunning ? theme.light ? "#1E7A4D" : "#7ED6A5" : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.75)
                        font.pixelSize: 15; font.weight: Font.DemiBold
                    }
                    Text {
                        text: processScanner.waydroidRunning
                              ? androidModel.count + win.tr(" Android processes")
                              : win.tr("Start an Android app to populate")
                        color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90); font.pixelSize: 9
                        width: parent.width
                        elide: Text.ElideRight
                    }
                }
            }
        }

        /* ---------------- Process list ---------------- */
        Rectangle {
            width: parent.width
            height: parent.height - 70 - 82 - 20
            radius: 18
            color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.92)
            border.width: 1
            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14)
            clip: true

            Rectangle {
                id: tableHeader
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 36
                color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.60)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 8

                    Item {
                        width: parent.width - 16 - 64 - 96 - 76 - 84 - 76 - 5 * 8
                        height: parent.height
                        Text { anchors.verticalCenter: parent.verticalCenter; text: win.tr("NAME"); color: theme.muted; font.pixelSize: 9; font.letterSpacing: 1.4 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.sortBy("name") }
                    }
                    Item {
                        width: 64; height: parent.height
                        Text { anchors.centerIn: parent; text: win.tr("PID"); color: theme.muted; font.pixelSize: 9; font.letterSpacing: 1.2 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.sortBy("pid") }
                    }
                    Item {
                        width: 96; height: parent.height
                        Text { anchors.centerIn: parent; text: win.tr("USER"); color: theme.muted; font.pixelSize: 9; font.letterSpacing: 1.2 }
                    }
                    Item {
                        width: 76; height: parent.height
                        Text { anchors.centerIn: parent; text: win.tr("CPU"); color: theme.muted; font.pixelSize: 9; font.letterSpacing: 1.2 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.sortBy("cpu") }
                    }
                    Item {
                        width: 84; height: parent.height
                        Text { anchors.centerIn: parent; text: win.tr("RAM"); color: theme.muted; font.pixelSize: 9; font.letterSpacing: 1.2 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.sortBy("memory") }
                    }
                    Item {
                        width: 76; height: parent.height
                        Text { anchors.centerIn: parent; text: win.tr("STATE"); color: theme.muted; font.pixelSize: 9; font.letterSpacing: 1.2 }
                    }
                }
            }

            ListView {
                id: list
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: tableHeader.bottom
                anchors.bottom: footer.top
                clip: true
                model: win.androidTab ? androidModel : linuxModel
                cacheBuffer: 400

                delegate: Rectangle {
                    id: row
                    required property int index
                    required property string name
                    required property int pid
                    required property string user
                    required property double cpu
                    required property string memoryText
                    required property string state
                    required property string cmdline
                    required property string packageName
                    required property bool android

                    width: list.width
                    height: 42
                    radius: 10
                    color: win.selectedPid === row.pid ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14)
                           : rowHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.07) : "transparent"
                    border.width: win.selectedPid === row.pid ? 1 : 0
                    border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.33)

                    Behavior on color { ColorAnimation { duration: 90 } }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 8

                        Row {
                            width: parent.width - 16 - 64 - 96 - 76 - 84 - 76 - 5 * 8
                            height: parent.height
                            spacing: 8
                            Image {
                                width: 18; height: 18
                                anchors.verticalCenter: parent.verticalCenter
                                source: row.android
                                        ? win.tr("file:///usr/share/icons/hicolor/512x512/apps/waydroid.png")
                                        : win.tr("file:///usr/share/icons/Papirus/64x64/apps/utilities-system-monitor.svg")
                                fillMode: Image.PreserveAspectFit
                            }
                            Text {
                                width: parent.width - 26
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.name
                                color: theme.text
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            width: 64
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.pid
                            color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.85)
                            font.pixelSize: 10
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            width: 96
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.user
                            color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.85)
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                        Text {
                            width: 76
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.cpu.toFixed(1) + "%"
                            color: row.cpu >= 25 ? theme.light ? "#B3261E" : "#FFB4B0" : row.cpu >= 5 ? theme.light ? "#8A6A00" : "#F5D67B" : Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.85)
                            font.pixelSize: 10
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            width: 84
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.memoryText
                            color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.85)
                            font.pixelSize: 10
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            width: 76
                            anchors.verticalCenter: parent.verticalCenter
                            text: win.tr(row.state)
                            color: row.state === "Running" ? theme.light ? "#1E7A4D" : "#7ED6A5" : Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90)
                            font.pixelSize: 10
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    HoverHandler { id: rowHover }
                    ToolTip.visible: rowHover.hovered
                    ToolTip.delay: 700
                    ToolTip.text: row.name + win.tr("  (PID ") + row.pid + ")"
                                  + (row.cmdline.length > 0 ? win.tr("\n") + row.cmdline : "")
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            win.selectedPid = row.pid
                            win.selectedName = row.name
                            win.selectedCmdline = row.cmdline
                            win.selectedPackage = row.packageName
                        }
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: list.count === 0
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: win.androidTab
                          ? (processScanner.waydroidRunning
                             ? win.tr("No matching Android processes.")
                             : win.tr("Waydroid is not running. Start an Android app first."))
                          : win.tr("No matching processes.")
                    color: theme.muted
                    font.pixelSize: 12
                }
            }

            Rectangle {
                id: footer
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 46
                color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.60)

                Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12) }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.right: actions.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.statusMessage.length > 0
                          ? win.statusMessage
                          : win.selectedPid > 0
                            ? win.selectedName + win.tr("  ·  PID ") + win.selectedPid
                              + (win.selectedPackage.length > 0 ? "  ·  " + win.selectedPackage : "")
                            : list.count + (list.count === 1 ? win.tr(" process") : win.tr(" processes"))
                    color: win.statusMessage.length > 0 ? theme.light ? "#2E8B57" : "#8FD3A8" : theme.muted
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

                Row {
                    id: actions
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        width: 88; height: 28; radius: 9
                        color: (win.selectedPid > 0 && endHover.hovered) ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086)
                        opacity: win.selectedPid > 0 ? 1.0 : 0.4
                        Text { anchors.centerIn: parent; text: win.tr("End task"); color: theme.text; font.pixelSize: 10 }
                        HoverHandler { id: endHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: win.selectedPid > 0
                            onClicked: win.endTask()
                        }
                    }

                    Rectangle {
                        width: win.androidTab && win.selectedPackage.length > 0 ? 100 : 96
                        height: 28; radius: 9
                        color: (win.selectedPid > 0 && forceHover.hovered) ? "#C42B1C" : theme.light ? Qt.rgba(0.70, 0.15, 0.12, 0.18) : "#3A1E1E"
                        border.width: 1
                        border.color: "#66FF8A80"
                        opacity: win.selectedPid > 0 ? 1.0 : 0.4
                        Text {
                            anchors.centerIn: parent
                            text: win.androidTab && win.selectedPackage.length > 0 ? win.tr("Force stop") : win.tr("Force kill")
                            color: theme.light ? "#B3261E" : "#FFB4B0"; font.pixelSize: 10
                        }
                        HoverHandler { id: forceHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: win.selectedPid > 0
                            onClicked: win.requestForce()
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: forceDialog
        modal: true
        anchors.centerIn: Overlay.overlay
        width: 430
        title: win.pendingForceStop ? win.tr("Force stop") : win.tr("Force kill")
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: win.doForce()
        background: Rectangle { color: theme.surface; radius: 16; border.width: 1; border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.20) }
        contentItem: Text {
            text: win.pendingForceStop
                  ? win.tr("Force-stop ") + win.pendingPackage + "?"
                  : win.tr("Kill PID ") + win.pendingPid + win.tr(" without saving?")
            color: theme.text
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
    }
}

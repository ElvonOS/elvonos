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

    property int tab: 0
    property int selectedPrinter: -1
    property int selectedScanner: -1
    property int scanResolution: 300
    property string scanMode: "Color"

    title: win.tr("Print & Scan")

    Component.onCompleted: {
        win.requestActivate()
        Qt.callLater(function () { win.requestActivate() })
    }

    Shortcut { sequence: "F5"; onActivated: printscan.refresh() }
    Shortcut { sequence: "Ctrl+1"; onActivated: win.tab = 0 }
    Shortcut { sequence: "Ctrl+2"; onActivated: win.tab = 1 }
    Shortcut { sequence: "Ctrl+Q"; onActivated: Qt.quit() }
    Shortcut { sequence: "Ctrl+W"; onActivated: Qt.quit() }

    /* ---------------- components ---------------- */

    component ActionButton: Rectangle {
        id: button
        property string label: ""
        property bool active: false
        signal activated()

        width: Math.max(70, buttonText.implicitWidth + 26)
        height: 32
        radius: 9
        color: active ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.18) : (buttonHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086))
        border.width: active ? 1 : 0
        border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.20)

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
                    Text { anchors.centerIn: parent; text: "⎙"; color: theme.accent; font.pixelSize: 16 }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        text: win.tr("PRINT & SCAN")
                        color: theme.text
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.2
                    }
                    Text {
                        text: printscan.printers.length + win.tr(" printers  ·  ")
                              + printscan.scanners.length + win.tr(" scanners")
                        color: theme.muted
                        font.pixelSize: 9
                    }
                }
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 250
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    width: 100; height: 32; radius: 9
                    color: win.tab === 0 ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14) : (printerHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.09) : "transparent")
                    border.width: win.tab === 0 ? 1 : 0
                    border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.33)
                    Text {
                        anchors.centerIn: parent
                        text: win.tr("Printers")
                        color: win.tab === 0 ? theme.text : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.75)
                        font.pixelSize: 10
                    }
                    HoverHandler { id: printerHover }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.tab = 0 }
                }
                Rectangle {
                    width: 100; height: 32; radius: 9
                    color: win.tab === 1 ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14) : (scannerHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.09) : "transparent")
                    border.width: win.tab === 1 ? 1 : 0
                    border.color: "#557ED6A5"
                    Text {
                        anchors.centerIn: parent
                        text: win.tr("Scanner")
                        color: win.tab === 1 ? theme.text : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.75)
                        font.pixelSize: 10
                    }
                    HoverHandler { id: scannerHover }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.tab = 1 }
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

        /* ---------------- Content ---------------- */
        Row {
            width: parent.width
            height: parent.height - 70 - 30 - 20
            spacing: 10

            Column {
                width: parent.width - 392
                height: parent.height
                spacing: 10

                /* Printers */
                Rectangle {
                    visible: win.tab === 0
                    width: parent.width
                    height: parent.height
                    radius: 16
                    color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, theme.glass / 100)
                    border.width: 1
                    border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)
                    clip: true

                    Column {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        Row {
                            width: parent.width
                            height: 26
                            SectionLabel { text: win.tr("PRINTERS"); anchors.verticalCenter: parent.verticalCenter }
                            Item { width: parent.width - 120 - 200; height: 1 }
                            ActionButton { label: win.tr("Refresh"); height: 26; onActivated: printscan.refresh() }
                            ActionButton { label: win.tr("Open CUPS"); height: 26; onActivated: printscan.openCups() }
                        }

                        ListView {
                            width: parent.width
                            height: parent.height - 26 - 44 - 24
                            clip: true
                            model: printscan.printers
                            spacing: 4

                            delegate: Rectangle {
                                required property int index
                                required property var modelData
                                readonly property string name: modelData.name
                                readonly property string info: modelData.info
                                readonly property bool isDefault: modelData.isDefault

                                width: ListView.view ? ListView.view.width : 0
                                height: 58
                                radius: 9
                                color: win.selectedPrinter === index ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.10)
                                       : (printerRowHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.08) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.04))
                                border.width: 1
                                border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.08)

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    Rectangle {
                                        width: 30; height: 30; radius: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.92)
                                        Text { anchors.centerIn: parent; text: "⎙"; color: theme.accent; font.pixelSize: 13 }
                                    }
                                    Column {
                                        width: parent.width - 30 - 10 - 80
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        Text {
                                            text: name
                                            color: theme.text
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                        }
                                        Text {
                                            text: info
                                            color: theme.muted
                                            font.pixelSize: 9
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }
                                    }
                                    Rectangle {
                                        visible: isDefault
                                        width: 80; height: 24; radius: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.14) : "#193326"
                                        border.width: 1
                                        border.color: "#557ED6A5"
                                        Text {
                                            anchors.centerIn: parent
                                            text: win.tr("DEFAULT")
                                            color: theme.text
                                            font.pixelSize: 8
                                            font.letterSpacing: 0.8
                                        }
                                    }
                                }

                                HoverHandler { id: printerRowHover }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.selectedPrinter = index
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: printscan.printers.length === 0
                                text: win.tr("No printers found.\nOpen CUPS to add a printer.")
                                color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.60)
                                font.pixelSize: 11
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        Row {
                            width: parent.width
                            height: 34
                            spacing: 8
                            ActionButton {
                                label: win.tr("Set default")
                                enabled: win.selectedPrinter >= 0
                                opacity: enabled ? 1 : 0.4
                                onActivated: {
                                    if (win.selectedPrinter >= 0)
                                        printscan.setDefaultPrinter(
                                            printscan.printers[win.selectedPrinter].name)
                                }
                            }
                            ActionButton {
                                label: win.tr("Print test page")
                                enabled: win.selectedPrinter >= 0
                                opacity: enabled ? 1 : 0.4
                                onActivated: {
                                    if (win.selectedPrinter >= 0)
                                        printscan.printTestPage(
                                            printscan.printers[win.selectedPrinter].name)
                                }
                            }
                        }
                    }
                }

                /* Scanner */
                Rectangle {
                    visible: win.tab === 1
                    width: parent.width
                    height: parent.height
                    radius: 16
                    color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, theme.glass / 100)
                    border.width: 1
                    border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)
                    clip: true

                    Column {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        SectionLabel { text: win.tr("SCANNER") }

                        ListView {
                            width: parent.width
                            height: printscan.scanners.length > 0 ? 58 * Math.min(3, printscan.scanners.length) + 8 : 58
                            clip: true
                            model: printscan.scanners
                            spacing: 4

                            delegate: Rectangle {
                                required property int index
                                required property var modelData
                                readonly property string name: modelData.name
                                readonly property string device: modelData.device

                                width: ListView.view ? ListView.view.width : 0
                                height: 54
                                radius: 9
                                color: win.selectedScanner === index ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.10)
                                       : (scannerRowHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.08) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.04))
                                border.width: 1
                                border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.08)

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10
                                    Rectangle {
                                        width: 30; height: 30; radius: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.92)
                                        Text { anchors.centerIn: parent; text: "⌗"; color: theme.accent; font.pixelSize: 13 }
                                    }
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        Text { text: name; color: theme.text; font.pixelSize: 11; font.weight: Font.DemiBold }
                                        Text { text: device; color: theme.muted; font.pixelSize: 9; elide: Text.ElideRight; width: parent.width }
                                    }
                                }
                                HoverHandler { id: scannerRowHover }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.selectedScanner = index
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: printscan.scanners.length === 0
                                text: win.tr("No scanner detected")
                                color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.60)
                                font.pixelSize: 11
                            }
                        }

                        SectionLabel { text: win.tr("RESOLUTION") }
                        Row {
                            spacing: 6
                            ActionButton { label: win.tr("100 dpi"); active: win.scanResolution === 100; onActivated: win.scanResolution = 100 }
                            ActionButton { label: win.tr("200 dpi"); active: win.scanResolution === 200; onActivated: win.scanResolution = 200 }
                            ActionButton { label: win.tr("300 dpi"); active: win.scanResolution === 300; onActivated: win.scanResolution = 300 }
                            ActionButton { label: win.tr("600 dpi"); active: win.scanResolution === 600; onActivated: win.scanResolution = 600 }
                        }

                        SectionLabel { text: win.tr("MODE") }
                        Row {
                            spacing: 6
                            ActionButton { label: "Color"; active: win.scanMode === "Color"; onActivated: win.scanMode = "Color" }
                            ActionButton { label: win.tr("Grayscale"); active: win.scanMode === "Gray"; onActivated: win.scanMode = "Gray" }
                        }

                        Rectangle {
                            width: parent.width
                            height: 46
                            radius: 10
                            color: printscan.busy ? theme.light ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.10) : "#16202A" : (scanHover.hovered ? "#2A7ED6A5" : theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.14) : "#193326")
                            border.width: 1
                            border.color: "#557ED6A5"
                            opacity: printscan.busy ? 0.6 : 1.0
                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                BusyIndicator { width: 18; height: 18; running: printscan.busy; visible: printscan.busy }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: printscan.busy ? win.tr("Scanning…") : win.tr("Scan page")
                                    color: theme.text
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }
                            }
                            HoverHandler { id: scanHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: !printscan.busy && win.selectedScanner >= 0
                                onClicked: printscan.scan(
                                    printscan.scanners[win.selectedScanner].device,
                                    win.scanResolution, win.scanMode)
                            }
                        }
                    }
                }
            }

            /* Right side */
            Column {
                width: 382
                height: parent.height
                spacing: 10

                /* Jobs (printers tab) */
                Rectangle {
                    visible: win.tab === 0
                    width: parent.width
                    height: parent.height
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
                            SectionLabel { text: win.tr("PRINT QUEUE"); anchors.verticalCenter: parent.verticalCenter }
                            Item { width: parent.width - 120 - 60; height: 1 }
                            Text {
                                text: printscan.jobs.length + win.tr(" jobs")
                                color: theme.muted
                                font.pixelSize: 9
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        ListView {
                            width: parent.width
                            height: parent.height - 30
                            clip: true
                            model: printscan.jobs
                            spacing: 3

                            delegate: Rectangle {
                                required property var modelData
                                readonly property string id: modelData.id
                                readonly property string owner: modelData.owner
                                readonly property string size: modelData.size
                                readonly property string when: modelData.when

                                width: ListView.view ? ListView.view.width : 0
                                height: 52
                                radius: 8
                                color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.04)
                                border.width: 1
                                border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.08)

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8
                                    Column {
                                        width: parent.width - 80
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        Text { text: id; color: theme.text; font.pixelSize: 10; elide: Text.ElideRight; width: parent.width }
                                        Text { text: owner + "  ·  " + size + "  ·  " + when; color: theme.muted; font.pixelSize: 8; elide: Text.ElideRight; width: parent.width }
                                    }
                                    ActionButton {
                                        label: win.tr("Cancel")
                                        height: 26
                                        anchors.verticalCenter: parent.verticalCenter
                                        onActivated: printscan.cancelJob(id)
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: printscan.jobs.length === 0
                                text: win.tr("No print jobs")
                                color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.60)
                                font.pixelSize: 11
                            }
                        }
                    }
                }

                /* Last scan (scanner tab) */
                Rectangle {
                    visible: win.tab === 1
                    width: parent.width
                    height: parent.height
                    radius: 16
                    color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.92)
                    border.width: 1
                    border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14)
                    clip: true

                    Column {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8
                        SectionLabel { text: win.tr("LAST SCAN") }
                        Rectangle {
                            width: parent.width
                            height: parent.height - 22 - 44 - 24
                            radius: 10
                            color: theme.background
                            clip: true
                            Image {
                                anchors.fill: parent
                                anchors.margins: 6
                                source: printscan.lastScan.length > 0
                                        ? win.tr("file://") + printscan.lastScan + win.tr("?v=") + Date.now() : ""
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                cache: false
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: printscan.lastScan.length === 0
                                text: win.tr("No scan yet")
                                color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.60)
                                font.pixelSize: 11
                            }
                        }
                        Row {
                            width: parent.width
                            height: 34
                            spacing: 8
                            ActionButton {
                                label: win.tr("Open")
                                enabled: printscan.lastScan.length > 0
                                opacity: enabled ? 1 : 0.4
                                onActivated: printscan.openLastScan()
                            }
                            ActionButton {
                                label: win.tr("Open folder")
                                onActivated: printscan.openScanFolder()
                            }
                        }
                    }
                }
            }
        }

        /* ---------------- Footer ---------------- */
        Rectangle {
            width: parent.width
            height: 30
            radius: 10
            color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.60)
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: printscan.status
                color: printscan.ok ? theme.light ? "#2E8B57" : "#8FD3A8" : theme.light ? "#B3261E" : "#FFB4B0"
                font.pixelSize: 10
                elide: Text.ElideRight
                width: parent.width - 140
            }
            BusyIndicator {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 18; height: 18
                running: printscan.busy
                visible: printscan.busy
            }
        }
    }
}

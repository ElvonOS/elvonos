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

    property int selectedIndex: -1
    property string selectedKey: ""
    property var selectedDetails: ({})
    property bool live: false
    property var sourceNames: [win.tr("All events"), win.tr("System services"), win.tr("Kernel"),
                               win.tr("Authentication"), win.tr("Applications")]

    title: win.tr("Event Viewer")

    Component.onCompleted: {
        win.requestActivate()
        Qt.callLater(function () { win.requestActivate() })
    }

    function levelColor(level) {
        if (level === "Error")
            return theme.light ? "#C62828" : "#FF7A7A"
        if (level === "Warning")
            return theme.light ? "#9A5B00" : "#FFC46B"
        if (level === "Notice")
            return theme.light ? "#2E7D32" : "#A0E0A8"
        if (level === "Info")
            return theme.accent
        return theme.muted
    }

    function selectRow(index) {
        if (index < 0 || index >= events.count) {
            selectedIndex = -1
            selectedKey = ""
            selectedDetails = ({})
            return
        }
        selectedIndex = index
        selectedKey = events.keyAt(index)
        selectedDetails = events.details(index)
    }

    function selectFirst() {
        selectRow(events.count > 0 ? 0 : -1)
        Qt.callLater(eventList.positionViewAtBeginning)
    }

    Shortcut { sequence: "F5"; onActivated: events.refresh() }
    Shortcut { sequence: "Ctrl+F"; onActivated: searchField.forceActiveFocus() }
    Shortcut { sequence: "Ctrl+Q"; onActivated: Qt.quit() }
    Shortcut { sequence: "Ctrl+W"; onActivated: Qt.quit() }

    Connections {
        target: events
        function onRefreshed() {
            if (win.selectedKey.length > 0) {
                const found = events.indexOfKey(win.selectedKey)
                if (found >= 0) {
                    win.selectRow(found)
                    return
                }
            }
            win.selectFirst()
        }
        function onCountChanged() {
            if (events.count === 0)
                win.selectRow(-1)
            else if (win.selectedIndex >= events.count)
                win.selectRow(events.count - 1)
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: win.live
        onTriggered: events.refresh()
    }

    /* ---------------- components ---------------- */

    component ActionButton: Rectangle {
        id: button
        property string label: ""
        property bool active: false
        signal activated()

        width: Math.max(70, buttonText.implicitWidth + 26)
        height: 30
        radius: 9
        color: active ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.18) : (buttonHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086))
        border.width: active ? 1 : 0
        border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.20)

        Text {
            id: buttonText
            anchors.centerIn: parent
            text: button.label
            color: button.active ? theme.accent : theme.text
            font.pixelSize: 9
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

    component SourceItem: Rectangle {
        id: sourceItem
        property string label: ""
        property int value: 0
        property bool active: false
        signal activated()

        width: parent ? parent.width : 160
        height: 32
        radius: 8
        color: active ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.10) : (sourceHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.08) : "transparent")
        border.width: active ? 1 : 0
        border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.20)

        Rectangle {
            width: 3
            height: 16
            radius: 1.5
            color: sourceItem.active ? theme.accent : Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.50)
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: sourceItem.label
            color: sourceItem.active ? theme.text : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.75)
            font.pixelSize: 10
        }
        HoverHandler { id: sourceHover }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sourceItem.activated()
        }
    }

    component DetailRow: Row {
        id: detailRow
        property string label: ""
        property string value: ""
        property color valueColor: theme.text

        width: parent ? parent.width : 300
        height: 20

        Text {
            width: 72
            text: detailRow.label
            color: theme.muted
            font.pixelSize: 8
            font.letterSpacing: 0.8
        }
        Text {
            width: detailRow.width - 80
            text: detailRow.value.length > 0 ? detailRow.value : "—"
            color: detailRow.valueColor
            font.pixelSize: 9
            elide: Text.ElideRight
        }
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
                    Text {
                        anchors.centerIn: parent
                        text: "▤"
                        color: theme.accent
                        font.pixelSize: 16
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        text: win.tr("EVENT VIEWER")
                        color: theme.text
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.2
                    }
                    Text {
                        text: win.sourceNames[events.sourceFilter] + "  ·  "
                              + events.count + win.tr(" events  ·  boot ")
                              + (events.currentBoot ? win.tr("current") : win.tr("all"))
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

            /* Sources */
            Rectangle {
                width: 190
                height: parent.height
                radius: 16
                color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, theme.glass / 100)
                border.width: 1
                border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    SectionLabel { text: win.tr("SOURCES") }

                    SourceItem {
                        label: win.tr("All events")
                        active: events.sourceFilter === 0
                        onActivated: { events.sourceFilter = 0; win.selectFirst() }
                    }
                    SourceItem {
                        label: win.tr("System services")
                        active: events.sourceFilter === 1
                        onActivated: { events.sourceFilter = 1; win.selectFirst() }
                    }
                    SourceItem {
                        label: win.tr("Kernel")
                        active: events.sourceFilter === 2
                        onActivated: { events.sourceFilter = 2; win.selectFirst() }
                    }
                    SourceItem {
                        label: win.tr("Authentication")
                        active: events.sourceFilter === 3
                        onActivated: { events.sourceFilter = 3; win.selectFirst() }
                    }
                    SourceItem {
                        label: win.tr("Applications")
                        active: events.sourceFilter === 4
                        onActivated: { events.sourceFilter = 4; win.selectFirst() }
                    }

                    Item { width: 1; height: 6 }
                    SectionLabel { text: win.tr("STATUS") }
                    Text {
                        width: parent.width
                        text: events.busy ? win.tr("Reading journal…")
                                          : (events.ok ? win.tr("Journal ready")
                                                       : win.tr("Journal unavailable"))
                        color: events.ok ? theme.light ? "#2E8B57" : "#8FD3A8" : theme.light ? "#B3261E" : "#FFB4B0"
                        font.pixelSize: 9
                        wrapMode: Text.Wrap
                    }
                }
            }

            /* Event list */
            Rectangle {
                width: parent.width - 190 - 340 - 20
                height: parent.height
                radius: 16
                color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, theme.glass / 100)
                border.width: 1
                border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Row {
                        width: parent.width
                        height: 32
                        spacing: 8

                        TextField {
                            id: searchField
                            width: parent.width - 98
                            height: 32
                            placeholderText: win.tr("Search events…")
                            color: theme.text
                            placeholderTextColor: theme.muted
                            font.pixelSize: 10
                            selectByMouse: true
                            leftPadding: 10
                            background: Rectangle {
                                radius: 8
                                color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086)
                                border.width: 1
                                border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.15)
                            }
                            onTextChanged: {
                                events.search = text
                                win.selectFirst()
                            }
                        }
                        ActionButton {
                            label: win.tr("Refresh")
                            width: 90
                            active: events.busy
                            onActivated: events.refresh()
                        }
                    }

                    Row {
                        width: parent.width
                        height: 30
                        spacing: 6

                        ActionButton {
                            label: win.tr("All")
                            active: events.levelFilter === 0
                            onActivated: { events.levelFilter = 0; win.selectFirst() }
                        }
                        ActionButton {
                            label: win.tr("Errors")
                            active: events.levelFilter === 1
                            onActivated: { events.levelFilter = 1; win.selectFirst() }
                        }
                        ActionButton {
                            label: win.tr("Warnings")
                            active: events.levelFilter === 2
                            onActivated: { events.levelFilter = 2; win.selectFirst() }
                        }
                        ActionButton {
                            label: win.tr("Info")
                            active: events.levelFilter === 3
                            onActivated: { events.levelFilter = 3; win.selectFirst() }
                        }
                        Item { width: Math.max(0, parent.width - 520); height: 1 }
                        ActionButton {
                            label: events.currentBoot ? win.tr("Boot: current") : win.tr("Boot: all")
                            active: events.currentBoot
                            onActivated: events.currentBoot = !events.currentBoot
                        }
                        ActionButton {
                            label: win.tr("Live")
                            active: win.live
                            onActivated: win.live = !win.live
                        }
                    }

                    ListView {
                        id: eventList
                        width: parent.width
                        height: parent.height - 32 - 30 - 16
                        clip: true
                        model: events
                        spacing: 2

                        delegate: Rectangle {
                            required property int index
                            required property string time
                            required property string level
                            required property string source
                            required property string identifier
                            required property string unit
                            required property string message

                            width: ListView.view ? ListView.view.width : 0
                            height: 46
                            radius: 8
                            color: win.selectedIndex === index ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.10)
                                   : (rowHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.08) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.04))
                            border.width: 1
                            border.color: win.selectedIndex === index ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.20) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.08)

                            Row {
                                id: rowContent
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 54
                                    text: time
                                    color: theme.muted
                                    font.pixelSize: 9
                                    font.family: "DejaVu Sans Mono"
                                }
                                Rectangle {
                                    width: 8; height: 8; radius: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: win.levelColor(level)
                                }
                                Column {
                                    width: rowContent.width - 54 - 8 - 76 - 32
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1
                                    Text {
                                        width: parent.width
                                        text: message
                                        color: theme.text
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        text: {
                                            const detail = identifier.length > 0
                                                           ? identifier : source
                                            return unit.length > 0
                                                   ? detail + "  ·  " + unit
                                                   : detail
                                        }
                                        color: theme.muted
                                        font.pixelSize: 8
                                        elide: Text.ElideRight
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 76
                                    text: source
                                    color: theme.muted
                                    font.pixelSize: 8
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            HoverHandler { id: rowHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.selectRow(index)
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: events.count === 0
                            text: events.busy ? win.tr("Reading journal…") : win.tr("No matching events")
                            color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.60)
                            font.pixelSize: 11
                        }
                    }
                }
            }

            /* Details */
            Rectangle {
                width: 340
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

                    SectionLabel { text: win.tr("EVENT DETAILS") }

                    Column {
                        id: metaColumn
                        width: parent.width
                        spacing: 1

                        DetailRow {
                            label: win.tr("LEVEL")
                            value: win.selectedDetails.level !== undefined
                                   ? win.tr(win.selectedDetails.level) : ""
                            valueColor: win.levelColor(win.selectedDetails.level)
                        }
                        DetailRow {
                            label: win.tr("TIME")
                            value: win.selectedDetails.time !== undefined
                                   ? win.selectedDetails.time : ""
                        }
                        DetailRow {
                            label: win.tr("SOURCE")
                            value: win.selectedDetails.source !== undefined
                                   ? win.selectedDetails.source : ""
                        }
                        DetailRow {
                            label: win.tr("UNIT")
                            value: win.selectedDetails.unit !== undefined
                                   ? win.selectedDetails.unit : ""
                        }
                        DetailRow {
                            label: win.tr("IDENTIFIER")
                            value: win.selectedDetails.identifier !== undefined
                                   ? win.selectedDetails.identifier : ""
                        }
                        DetailRow {
                            label: win.tr("PID")
                            value: win.selectedDetails.pid !== undefined
                                   ? win.selectedDetails.pid : ""
                        }
                        DetailRow {
                            label: win.tr("HOST")
                            value: win.selectedDetails.host !== undefined
                                   ? win.selectedDetails.host : ""
                        }
                        DetailRow {
                            label: win.tr("BOOT")
                            value: win.selectedDetails.boot !== undefined
                                   ? win.selectedDetails.boot : ""
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: Math.max(90, parent.height - metaColumn.height - 11 - 32 - 24)
                        radius: 10
                        color: theme.background
                        border.width: 1
                        border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)
                        clip: true

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 8
                            clip: true
                            contentWidth: width
                            contentHeight: messageText.implicitHeight

                            TextEdit {
                                id: messageText
                                width: parent.width
                                text: win.selectedDetails.message !== undefined
                                      ? win.selectedDetails.message : ""
                                color: theme.text
                                font.family: "DejaVu Sans Mono"
                                font.pixelSize: 9
                                wrapMode: TextEdit.Wrap
                                readOnly: true
                                selectByMouse: true
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: win.selectedIndex < 0
                            text: win.tr("Select an event")
                            color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.60)
                            font.pixelSize: 10
                        }
                    }

                    Row {
                        width: parent.width
                        height: 32
                        spacing: 6

                        ActionButton {
                            label: win.tr("Copy")
                            width: 74
                            enabled: win.selectedIndex >= 0
                            opacity: enabled ? 1 : 0.4
                            onActivated: events.copyMessage(win.selectedIndex)
                        }
                        ActionButton {
                            label: win.tr("Save log")
                            width: 90
                            enabled: events.count > 0
                            opacity: enabled ? 1 : 0.4
                            onActivated: events.saveVisible()
                        }
                        Item { width: parent.width - 170; height: 1 }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: events.count + win.tr(" shown")
                            color: theme.muted
                            font.pixelSize: 8
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
                text: events.status
                color: events.ok ? theme.light ? "#2E8B57" : "#8FD3A8" : theme.light ? "#B3261E" : "#FFB4B0"
                font.pixelSize: 10
                elide: Text.ElideRight
                width: parent.width - 240
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.tr("updated ") + events.lastRefresh
                    color: theme.muted
                    font.pixelSize: 9
                }
                BusyIndicator {
                    width: 18
                    height: 18
                    running: events.busy
                    visible: events.busy
                }
            }
        }
    }
}

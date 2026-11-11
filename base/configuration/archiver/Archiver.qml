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

    property string createFormat: "zip"

    title: win.tr("Archiver")

    Component.onCompleted: {
        win.requestActivate()
        Qt.callLater(function () { win.requestActivate() })
    }

    ListModel { id: sourcesModel }

    Connections {
        target: archiver
        function onExtractDirChanged() {
            extractField.text = archiver.extractDir
        }
    }

    Shortcut { sequence: "Ctrl+O"; onActivated: { browser.mode = "open"; browser.open() } }
    Shortcut { sequence: "Ctrl+Q"; onActivated: Qt.quit() }
    Shortcut { sequence: "Ctrl+W"; onActivated: Qt.quit() }
    Shortcut { sequence: "F5"; onActivated: archiver.refresh() }

    function extFor(format) {
        if (format === "zip")
            return ".zip"
        if (format === "tar.gz")
            return ".tar.gz"
        if (format === "tar.xz")
            return ".tar.xz"
        if (format === "tar.bz2")
            return ".tar.bz2"
        return ".tar"
    }

    function setFormat(format) {
        createFormat = format
        let name = nameField.text
        const suffixes = [".zip", ".tar.gz", ".tar.xz", ".tar.bz2", ".tar"]
        for (let i = 0; i < suffixes.length; ++i) {
            if (name.toLowerCase().endsWith(suffixes[i])) {
                name = name.substring(0, name.length - suffixes[i].length)
                break
            }
        }
        nameField.text = name + extFor(format)
    }

    function addSource(path) {
        for (let i = 0; i < sourcesModel.count; ++i) {
            if (sourcesModel.get(i).path === path)
                return
        }
        sourcesModel.append({ path: path, name: archiver.baseName(path) })
    }

    function removeSource(index) {
        if (index >= 0 && index < sourcesModel.count)
            sourcesModel.remove(index)
    }

    function createArchive() {
        const list = []
        for (let i = 0; i < sourcesModel.count; ++i)
            list.push(sourcesModel.get(i).path)
        archiver.createArchive(archiver.joinPath(createDirField.text, nameField.text),
                               createFormat, list)
    }

    /* ---------------- components ---------------- */

    component ActionButton: Rectangle {
        id: button
        property string label: ""
        property bool active: false
        signal activated()

        width: Math.max(64, labelText.implicitWidth + 26)
        height: 32
        radius: 9
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

    component Field: TextField {
        height: 30
        color: theme.text
        font.pixelSize: 10
        selectByMouse: true
        leftPadding: 10
        background: Rectangle {
            radius: 8
            color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14)
            border.width: 1
            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.15)
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
                    Text { anchors.centerIn: parent; text: "▤"; color: theme.accent; font.pixelSize: 15 }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        text: win.tr("ARCHIVER")
                        color: theme.text
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.2
                    }
                    Text {
                        text: archiver.archiveName.length > 0
                              ? archiver.archiveName + "  ·  " + archiver.archiveFormat
                              : win.tr("ZIP  ·  TAR.GZ  ·  TAR.XZ  ·  TAR")
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

        /* ---------------- Toolbar ---------------- */
        Rectangle {
            width: parent.width
            height: 52
            radius: 14
            color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, theme.glass / 100)
            border.width: 1
            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                ActionButton {
                    label: win.tr("Open archive")
                    onActivated: { browser.mode = "open"; browser.open() }
                }
                ActionButton {
                    label: win.tr("Refresh")
                    onActivated: archiver.refresh()
                }
                ActionButton {
                    label: win.tr("Close")
                    onActivated: archiver.closeArchive()
                }

                Rectangle { width: 1; height: 24; color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12) }

                Text {
                    text: archiver.archivePath.length > 0
                          ? archiver.archivePath
                          : win.tr("No archive opened")
                    color: theme.muted
                    font.pixelSize: 9
                    elide: Text.ElideMiddle
                    width: 480
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: archiver.entries.length + win.tr(" entries")
                color: theme.light ? "#2E8B57" : "#8FD3A8"
                font.pixelSize: 9
            }
        }

        /* ---------------- Content ---------------- */
        Row {
            width: parent.width
            height: parent.height - 70 - 52 - 20
            spacing: 10

            /* Entries */
            Rectangle {
                width: parent.width - 392
                height: parent.height
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
                        height: 20
                        SectionLabel { text: win.tr("ARCHIVE CONTENTS"); anchors.verticalCenter: parent.verticalCenter }
                        Item { width: parent.width - 140; height: 1 }
                        Text {
                            text: archiver.archiveFormat.toUpperCase()
                            color: theme.accent
                            font.pixelSize: 9
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 24
                        radius: 6
                        color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.60)
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            Text { width: parent.width - 200; text: win.tr("NAME"); color: theme.muted; font.pixelSize: 8; anchors.verticalCenter: parent.verticalCenter }
                            Text { width: 90; text: win.tr("SIZE"); color: theme.muted; font.pixelSize: 8; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                            Text { width: 110; text: win.tr("DATE"); color: theme.muted; font.pixelSize: 8; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }

                    ListView {
                        width: parent.width
                        height: parent.height - 20 - 24 - 34 - 24
                        clip: true
                        model: archiver.entries
                        spacing: 2

                        delegate: Rectangle {
                            required property string name
                            required property string sizeText
                            required property string date
                            required property bool isDir

                            width: ListView.view ? ListView.view.width : 0
                            height: 30
                            radius: 6
                            color: entryHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.08) : "transparent"

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12

                                Row {
                                    width: parent.width - 200
                                    spacing: 8
                                    Text {
                                        text: isDir ? "▸" : "·"
                                        color: isDir ? theme.accent : Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.70)
                                        font.pixelSize: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: name
                                        color: isDir ? theme.text : theme.text
                                        font.pixelSize: 10
                                        width: parent.width - 20
                                        elide: Text.ElideMiddle
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                Text {
                                    width: 90
                                    text: sizeText
                                    color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.85)
                                    font.pixelSize: 9
                                    horizontalAlignment: Text.AlignRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    width: 110
                                    text: date
                                    color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90)
                                    font.pixelSize: 9
                                    horizontalAlignment: Text.AlignRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            HoverHandler { id: entryHover }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: archiver.entries.length === 0
                            text: win.tr("Open a ZIP or TAR archive to see its contents")
                            color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.60)
                            font.pixelSize: 11
                        }
                    }

                    Row {
                        width: parent.width
                        height: 26
                        Text {
                            text: archiver.status
                            color: archiver.ok ? theme.light ? "#2E8B57" : "#8FD3A8" : theme.light ? "#B3261E" : "#FFB4B0"
                            font.pixelSize: 9
                            elide: Text.ElideRight
                            width: parent.width - 120
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        BusyIndicator {
                            width: 18; height: 18
                            running: archiver.busy
                            visible: archiver.busy
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            /* Actions */
            Column {
                width: 382
                height: parent.height
                spacing: 10

                Rectangle {
                    width: parent.width
                    height: 156
                    radius: 16
                    color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, theme.glass / 100)
                    border.width: 1
                    border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)

                    Column {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        SectionLabel { text: win.tr("EXTRACT TO") }
                        Field {
                            id: extractField
                            width: parent.width
                            text: archiver.extractDir
                            onAccepted: archiver.extractAll(text)
                        }
                        Row {
                            width: parent.width
                            spacing: 8
                            ActionButton {
                                label: win.tr("Extract all")
                                onActivated: archiver.extractAll(extractField.text)
                            }
                            ActionButton {
                                label: win.tr("Open folder")
                                onActivated: archiver.openDir(extractField.text)
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: parent.height - 166
                    radius: 16
                    color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, theme.glass / 100)
                    border.width: 1
                    border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)
                    clip: true

                    Column {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        SectionLabel { text: win.tr("CREATE ARCHIVE") }

                        Row {
                            width: parent.width
                            spacing: 8
                            Field {
                                id: createDirField
                                width: parent.width - 150
                                text: archiver.downloadsPath()
                            }
                            Field {
                                id: nameField
                                width: 142
                                text: win.tr("Archive.zip")
                            }
                        }

                        Row {
                            spacing: 6
                            ActionButton { label: win.tr("ZIP"); active: win.createFormat === "zip"; onActivated: win.setFormat("zip") }
                            ActionButton { label: win.tr("TAR.GZ"); active: win.createFormat === "tar.gz"; onActivated: win.setFormat("tar.gz") }
                            ActionButton { label: win.tr("TAR"); active: win.createFormat === "tar"; onActivated: win.setFormat("tar") }
                        }

                        Row {
                            spacing: 8
                            ActionButton {
                                label: win.tr("Add file")
                                onActivated: { browser.mode = "source"; browser.open() }
                            }
                            ActionButton {
                                label: win.tr("Add folder")
                                onActivated: {
                                    browser.mode = "source"
                                    browser.open()
                                }
                            }
                            ActionButton {
                                label: win.tr("Remove")
                                onActivated: {
                                    if (sourcesView.currentIndex >= 0)
                                        win.removeSource(sourcesView.currentIndex)
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: parent.height - 190
                            radius: 10
                            color: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.60)
                            border.width: 1
                            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)
                            clip: true

                            ListView {
                                id: sourcesView
                                anchors.fill: parent
                                anchors.margins: 6
                                clip: true
                                model: sourcesModel
                                spacing: 2

                                delegate: Rectangle {
                                    required property int index
                                    required property string path
                                    required property string name

                                    width: ListView.view ? ListView.view.width : 0
                                    height: 28
                                    radius: 6
                                    color: sourcesView.currentIndex === index ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.18)
                                           : (sourceHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.08) : "transparent")

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: name
                                        color: theme.text
                                        font.pixelSize: 9
                                        elide: Text.ElideMiddle
                                        width: parent.width - 16
                                    }
                                    HoverHandler { id: sourceHover }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: sourcesView.currentIndex = index
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: sourcesModel.count === 0
                                text: win.tr("Add files or folders")
                                color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.60)
                                font.pixelSize: 10
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 42
                            radius: 9
                            color: archiver.busy ? theme.light ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.10) : "#16202A" : (createHover.hovered ? "#2A7ED6A5" : theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.14) : "#193326")
                            border.width: 1
                            border.color: "#557ED6A5"
                            opacity: archiver.busy ? 0.6 : 1.0
                            Text {
                                anchors.centerIn: parent
                                text: win.tr("Create archive")
                                color: theme.text
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }
                            HoverHandler { id: createHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: !archiver.busy
                                onClicked: win.createArchive()
                            }
                        }
                    }
                }
            }
        }
    }

    /* ---------------- File browser ---------------- */
    Dialog {
        id: browser
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        width: 720
        height: 500
        padding: 0

        property string mode: "open"
        property string currentDir: archiver.downloadsPath()
        property string selectedPath: ""
        property var items: []

        function loadDir(path) {
            currentDir = path
            selectedPath = ""
            items = archiver.listDirectory(path, mode === "open")
        }

        function chooseFile(path) {
            if (mode === "open") {
                selectedPath = path
                accept()
            } else {
                win.addSource(path)
                accept()
            }
        }

        onOpened: {
            selectedPath = ""
            loadDir(mode === "open" ? archiver.downloadsPath() : archiver.homePath())
        }

        onAccepted: {
            if (mode === "open" && selectedPath.length > 0)
                archiver.openArchive(selectedPath)
        }

        background: Rectangle {
            color: theme.panel
            radius: 16
            border.width: 1
            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.20)
        }

        contentItem: Column {
            spacing: 10
            anchors.fill: parent
            anchors.margins: 14

            Text {
                text: browser.mode === "open" ? win.tr("OPEN ARCHIVE") : win.tr("ADD FILE")
                color: theme.text
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2
            }

            Row {
                width: parent.width
                height: 30
                spacing: 8

                ActionButton { label: win.tr("↑ Up"); height: 30; onActivated: browser.loadDir(archiver.parentDir(browser.currentDir)) }
                ActionButton { label: win.tr("Home"); height: 30; onActivated: browser.loadDir(archiver.homePath()) }
                ActionButton { label: win.tr("Downloads"); height: 30; onActivated: browser.loadDir(archiver.downloadsPath()) }
                ActionButton { label: win.tr("Documents"); height: 30; onActivated: browser.loadDir(archiver.documentsPath()) }

                Field {
                    width: parent.width - 76 - 70 - 96 - 106 - 40
                    text: browser.currentDir
                    onAccepted: browser.loadDir(text)
                }
            }

            Rectangle {
                width: parent.width
                height: 320
                radius: 12
                color: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.60)
                border.width: 1
                border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)
                clip: true

                ListView {
                    anchors.fill: parent
                    anchors.margins: 6
                    clip: true
                    model: browser.items
                    spacing: 2

                    delegate: Rectangle {
                        required property var modelData
                        readonly property string name: modelData.name
                        readonly property string path: modelData.path
                        readonly property bool isDir: modelData.isDir
                        readonly property string sizeText: modelData.sizeText

                        width: ListView.view ? ListView.view.width : 0
                        height: 38
                        radius: 8
                        color: browser.selectedPath === path
                               ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.18)
                               : (rowHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.08) : "transparent")

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Rectangle {
                                width: 22; height: 22; radius: 6
                                color: isDir ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.18) : Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.92)
                                Text {
                                    anchors.centerIn: parent
                                    text: isDir ? "▸" : "▤"
                                    color: isDir ? theme.accent : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.80)
                                    font.pixelSize: 11
                                }
                            }
                            Text {
                                text: name
                                color: theme.text
                                font.pixelSize: 11
                                width: 520
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: sizeText
                            color: theme.muted
                            font.pixelSize: 9
                        }

                        HoverHandler { id: rowHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: browser.selectedPath = path
                            onDoubleClicked: {
                                if (isDir)
                                    browser.loadDir(path)
                                else
                                    browser.chooseFile(path)
                            }
                        }
                    }
                }
            }

            Row {
                width: parent.width
                height: 34
                spacing: 8

                ActionButton {
                    label: win.tr("Add this folder")
                    visible: browser.mode === "source"
                    onActivated: {
                        win.addSource(browser.currentDir)
                        browser.accept()
                    }
                }

                Item { width: parent.width - 90 - 130 - 150; height: 1 }

                ActionButton {
                    label: win.tr("Cancel")
                    width: 90
                    onActivated: browser.reject()
                }

                Rectangle {
                    width: 130
                    height: 32
                    radius: 9
                    color: browser.selectedPath.length > 0
                           ? (acceptHover.hovered ? "#2A7ED6A5" : theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.14) : "#193326")
                           : theme.light ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.10) : "#16202A"
                    border.width: 1
                    border.color: "#557ED6A5"
                    opacity: browser.selectedPath.length > 0 ? 1.0 : 0.4
                    Text {
                        anchors.centerIn: parent
                        text: browser.mode === "open" ? win.tr("Open") : win.tr("Add file")
                        color: theme.text
                        font.pixelSize: 10
                    }
                    HoverHandler { id: acceptHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: browser.selectedPath.length > 0
                        onClicked: browser.accept()
                    }
                }
            }
        }
    }
}

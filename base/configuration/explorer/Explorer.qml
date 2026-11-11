import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: win
    width: 1120
    height: 610
    visible: true
    function tr(text) {
        if (lang.revision < 0)
            return text
        return lang.tr(text)
    }

    title: win.tr("Explorer")
    color: theme.background

    onClosing: explorer.quit()

    property var history: []
    property int historyIndex: -1
    property bool appsMode: false
    property bool storageReady: false
    property bool gridMode: true
    property int selectedIndex: -1
    property var selection: []
    property int anchorIndex: -1
    property int contextIndex: -1
    property int renameIndex: -1
    property int deleteIndex: -1
    property var deleteIndices: []
    property bool deletePermanent: false
    property string statusMessage: ""
    property var pathSegments: buildSegments()
    property bool pathEntryVisible: false
    property var propRows: []
    property string propTitle: ""
    property bool dialogOpen: folderDialog.visible || newFileDialog.visible
                                 || renameDialog.visible || deleteDialog.visible
                                 || propertiesDialog.visible
    property bool typing: searchField.activeFocus || pathField.activeFocus
                          || folderField.activeFocus || newFileField.activeFocus
                          || renameField.activeFocus

    function buildSegments() {
        if (appsMode)
            return [{ label: "Android apps", path: "" }]
        const parts = directoryModel.path.split("/").filter(function (p) { return p.length > 0 })
        let result = [{ label: "/", path: "/" }]
        let current = ""
        for (let i = 0; i < parts.length; ++i) {
            current += "/" + parts[i]
            result.push({ label: parts[i], path: current })
        }
        return result
    }

    function navigate(path) {
        if (!path)
            return
        appsMode = false
        if (historyIndex < history.length - 1)
            history = history.slice(0, historyIndex + 1)
        history.push(path)
        historyIndex = history.length - 1
        directoryModel.path = path
        clearSelection()
        statusMessage = ""
        searchField.text = ""
        directoryModel.filter = ""
        waydroidApps.filter = ""
    }

    function goBack() {
        if (historyIndex <= 0)
            return
        historyIndex -= 1
        directoryModel.path = history[historyIndex]
        clearSelection()
    }

    function goForward() {
        if (historyIndex >= history.length - 1)
            return
        historyIndex += 1
        directoryModel.path = history[historyIndex]
        clearSelection()
    }

    function goUp() { navigate(directoryModel.parentPath) }

    function openIndex(index) {
        if (index < 0 || index >= directoryModel.count)
            return
        if (directoryModel.isDirAt(index))
            navigate(directoryModel.pathAt(index))
        else
            directoryModel.openAt(index)
    }

    function openPath(index) { openIndex(index) }

    /* ---------------- Selection ---------------- */
    function isSelected(i) { return selection.indexOf(i) !== -1 }
    function selectOnly(i) {
        selection = i >= 0 ? [i] : []
        selectedIndex = i
        anchorIndex = i
    }
    function toggleSelect(i) {
        const next = selection.slice()
        const at = next.indexOf(i)
        if (at >= 0)
            next.splice(at, 1)
        else
            next.push(i)
        selection = next
        selectedIndex = i
        anchorIndex = i
    }
    function selectRange(i) {
        const start = Math.min(anchorIndex < 0 ? i : anchorIndex, i)
        const end = Math.max(anchorIndex < 0 ? i : anchorIndex, i)
        const next = []
        for (let k = start; k <= end; ++k)
            next.push(k)
        selection = next
        selectedIndex = i
    }
    function selectAll() {
        const next = []
        for (let i = 0; i < directoryModel.count; ++i)
            next.push(i)
        selection = next
    }
    function clearSelection() {
        selection = []
        selectedIndex = -1
        anchorIndex = -1
    }
    function selectedPaths() {
        if (selection.length > 0)
            return selection.map(function (i) { return directoryModel.pathAt(i) })
        if (selectedIndex >= 0)
            return [directoryModel.pathAt(selectedIndex)]
        return []
    }

    /* ---------------- Navigation ---------------- */
    function ensureVisible(i) {
        if (win.appsMode)
            return
        if (win.gridMode)
            grid.positionViewAtIndex(i, GridView.Contain)
        else
            fileList.positionViewAtIndex(i, ListView.Contain)
    }

    function moveSelection(dx, dy) {
        if (directoryModel.count === 0)
            return
        let columns = 1
        if (win.gridMode)
            columns = Math.max(1, Math.floor((grid.width - grid.leftMargin) / grid.cellWidth))
        const current = selectedIndex < 0 ? 0 : selectedIndex
        const next = current + dx + dy * columns
        if (next >= 0 && next < directoryModel.count) {
            selectOnly(next)
            ensureVisible(next)
        }
    }

    function beginPathEntry() {
        pathField.text = directoryModel.path
        pathEntryVisible = true
        pathField.forceActiveFocus()
        pathField.selectAll()
    }

    /* ---------------- File actions ---------------- */
    function copySelection(cut) {
        const paths = selectedPaths()
        if (paths.length === 0)
            return
        explorer.setClipboardPaths(paths, cut)
        statusMessage = (cut ? "Cut " : "Copied ") + paths.length
                        + (paths.length === 1 ? " item" : " items")
        statusTimer.restart()
    }

    function pasteHere() {
        if (!explorer.hasClipboard)
            return
        const done = explorer.pasteInto(directoryModel.path)
        if (done < 0)
            statusMessage = "Cannot paste into this folder."
        else {
            statusMessage = done + (done === 1 ? " item pasted" : " items pasted")
            directoryModel.refresh()
        }
        statusTimer.restart()
    }

    function requestDelete(permanent) {
        const paths = selectedPaths()
        if (paths.length === 0)
            return
        deleteIndices = selection.length > 0 ? selection.slice() : [selectedIndex]
        deletePermanent = permanent
        deleteDialog.open()
    }

    function requestRename() {
        if (selectedIndex < 0)
            return
        renameIndex = selectedIndex
        renameField.text = directoryModel.nameAt(renameIndex)
        renameDialog.open()
    }

    function showProperties() {
        const paths = selectedPaths()
        if (paths.length !== 1) {
            if (paths.length > 1) {
                statusMessage = paths.length + " items selected"
                statusTimer.restart()
            }
            return
        }
        const p = explorer.properties(paths[0])
        if (!p.name)
            return
        const rows = [
            { label: "Name", value: p.name },
            { label: "Type", value: p.type },
            { label: "Location", value: p.path },
            { label: "Size", value: p.size },
            { label: "Modified", value: p.modified },
            { label: "Permissions", value: p.permissions },
            { label: "Owner", value: p.owner },
            { label: "Group", value: p.group }
        ]
        if (p.target)
            rows.push({ label: "Target", value: p.target })
        propRows = rows
        propTitle = p.name
        propertiesDialog.open()
    }

    Component.onCompleted: {
        directoryModel.sortMode = explorer.sortMode
        directoryModel.sortDescending = explorer.sortDescending
        directoryModel.showHidden = explorer.showHidden
        win.gridMode = explorer.gridMode
        navigate(startupPath !== undefined && startupPath.length > 0
                 ? startupPath : explorer.home)
        explorer.ensureStorage()
        win.storageReady = explorer.storageReady()
        if (startupApps !== undefined && startupApps) {
            Qt.callLater(function () {
                win.appsMode = true
                win.clearSelection()
                win.statusMessage = ""
                searchField.text = ""
                waydroidApps.filter = ""
                waydroidApps.refresh()
            })
        }
        win.requestActivate()
        Qt.callLater(function () { win.requestActivate() })
    }

    Connections {
        target: directoryModel
        function onPathChanged() { win.clearSelection() }
        function onCountChanged() {
            if (win.selection.length === 0 && win.selectedIndex >= directoryModel.count)
                win.clearSelection()
        }
    }

    Timer {
        id: statusTimer
        interval: 3200
        onTriggered: win.statusMessage = ""
    }

    /* ---------------- Shortcuts ---------------- */
    Shortcut { sequence: "F5"; onActivated: win.appsMode ? waydroidApps.refresh() : directoryModel.refresh() }
    Shortcut { sequence: "Ctrl+W"; onActivated: explorer.quit() }
    Shortcut { sequence: "Ctrl+Q"; onActivated: explorer.quit() }
    Shortcut { sequence: "Ctrl+M"; onActivated: win.showMinimized() }
    Shortcut { sequence: "Ctrl+H"; onActivated: directoryModel.showHidden = !directoryModel.showHidden }
    Shortcut {
        sequence: "Ctrl+N"
        enabled: !win.typing && !win.dialogOpen && !win.appsMode
        onActivated: { folderField.text = "New Folder"; folderDialog.open() }
    }
    Shortcut {
        sequence: "Ctrl+Shift+N"
        enabled: !win.typing && !win.dialogOpen && !win.appsMode
        onActivated: { newFileField.text = "New File.txt"; newFileDialog.open() }
    }
    Shortcut {
        sequence: "Ctrl+L"
        enabled: !win.dialogOpen
        onActivated: win.beginPathEntry()
    }
    Shortcut {
        sequence: "Ctrl+F"
        enabled: !win.dialogOpen
        onActivated: searchField.forceActiveFocus()
    }
    Shortcut {
        sequences: [StandardKey.Copy]
        enabled: !win.typing && !win.dialogOpen && !win.appsMode
        onActivated: win.copySelection(false)
    }
    Shortcut {
        sequences: [StandardKey.Cut]
        enabled: !win.typing && !win.dialogOpen && !win.appsMode
        onActivated: win.copySelection(true)
    }
    Shortcut {
        sequences: [StandardKey.Paste]
        enabled: !win.typing && !win.dialogOpen && !win.appsMode && explorer.hasClipboard
        onActivated: win.pasteHere()
    }
    Shortcut {
        sequences: [StandardKey.SelectAll]
        enabled: !win.typing && !win.dialogOpen && !win.appsMode
        onActivated: win.selectAll()
    }
    Shortcut {
        sequence: "F2"
        enabled: !win.typing && !win.dialogOpen && !win.appsMode
        onActivated: win.requestRename()
    }
    Shortcut {
        sequences: [StandardKey.Delete]
        enabled: !win.typing && !win.dialogOpen && !win.appsMode
        onActivated: win.requestDelete(false)
    }
    Shortcut {
        sequence: "Shift+Del"
        enabled: !win.typing && !win.dialogOpen && !win.appsMode
        onActivated: win.requestDelete(true)
    }
    Shortcut {
        sequences: [StandardKey.Back]
        enabled: !win.typing && !win.dialogOpen
        onActivated: win.goUp()
    }
    Shortcut {
        sequence: "Alt+Left"
        enabled: !win.typing && !win.dialogOpen
        onActivated: win.goBack()
    }
    Shortcut {
        sequence: "Alt+Right"
        enabled: !win.typing && !win.dialogOpen
        onActivated: win.goForward()
    }
    Shortcut {
        sequence: "Escape"
        enabled: !win.dialogOpen
        onActivated: {
            if (win.pathEntryVisible) { win.pathEntryVisible = false; directoryModel.refresh() }
            else win.clearSelection()
        }
    }
    Shortcut {
        sequence: "Up"
        enabled: !win.typing && !win.dialogOpen && !win.appsMode
        onActivated: win.moveSelection(0, -1)
    }
    Shortcut {
        sequence: "Down"
        enabled: !win.typing && !win.dialogOpen && !win.appsMode
        onActivated: win.moveSelection(0, 1)
    }
    Shortcut {
        sequence: "Left"
        enabled: !win.typing && !win.dialogOpen && !win.appsMode
        onActivated: win.moveSelection(-1, 0)
    }
    Shortcut {
        sequence: "Right"
        enabled: !win.typing && !win.dialogOpen && !win.appsMode
        onActivated: win.moveSelection(1, 0)
    }
    Shortcut {
        sequence: "Home"
        enabled: !win.typing && !win.dialogOpen && !win.appsMode && directoryModel.count > 0
        onActivated: { win.selectOnly(0); win.ensureVisible(0) }
    }
    Shortcut {
        sequence: "End"
        enabled: !win.typing && !win.dialogOpen && !win.appsMode && directoryModel.count > 0
        onActivated: { const last = directoryModel.count - 1; win.selectOnly(last); win.ensureVisible(last) }
    }
    Shortcut {
        sequence: "Return"
        enabled: !win.typing && !win.dialogOpen && !win.appsMode && win.selectedIndex >= 0
        onActivated: win.openIndex(win.selectedIndex)
    }

    /* ---------------- Glass backdrop ---------------- */
    Image {
        anchors.fill: parent
        source: "file:///usr/share/backgrounds/elvonos/wallpaper.png"
        fillMode: Image.PreserveAspectCrop
        opacity: 0.55
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: theme.panel }
            GradientStop { position: 1.0; color: theme.background }
        }
    }

    Row {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        /* ---------------- Sidebar ---------------- */
        Rectangle {
            width: 252
            height: parent.height
            radius: 18
            color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, theme.glass / 100)
            border.width: 1
            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.18)

            Flickable {
                anchors.fill: parent
                anchors.margins: 14
                contentWidth: width
                contentHeight: sideColumn.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                Column {
                    id: sideColumn
                    width: parent.width
                    spacing: 2

                Row {
                    spacing: 9
                    x: 6

                    Rectangle {
                        width: 30
                        height: 30
                        radius: 9
                        color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14)
                        border.width: 1
                        border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.45)

                        Text {
                            anchors.centerIn: parent
                            text: win.tr("▤")
                            color: theme.accent
                            font.pixelSize: 16
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: win.tr("EXPLORER"); color: theme.text; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1.2 }
                        Text { text: win.tr("Files & Android"); color: theme.muted; font.pixelSize: 9 }
                    }
                }

                Text {
                    text: win.tr("PLACES")
                    color: "#6F7682"
                    font.pixelSize: 9
                    font.letterSpacing: 1.5
                    leftPadding: 10
                    topPadding: 12
                    bottomPadding: 6
                }

                Repeater {
                    model: [
                        { label: "Home", path: explorer.home, icon: "user-home" },
                        { label: "Desktop", path: explorer.desktop, icon: "user-desktop" },
                        { label: "Documents", path: explorer.documents, icon: "folder-documents" },
                        { label: "Downloads", path: explorer.downloads, icon: "folder-download" },
                        { label: "Pictures", path: explorer.pictures, icon: "folder-pictures" },
                        { label: "Music", path: explorer.music, icon: "folder-music" },
                        { label: "Videos", path: explorer.videos, icon: "folder-videos" },
                        { label: "File system", path: "/", icon: "folder" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width
                        height: 38
                        radius: 10
                        color: directoryModel.path === modelData.path && !win.appsMode
                               ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14) : sideHover.hovered ? "#16FFFFFF" : "transparent"
                        border.width: directoryModel.path === modelData.path && !win.appsMode ? 1 : 0
                        border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.45)

                        Behavior on color { ColorAnimation { duration: 110 } }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Image {
                                width: 20
                                height: 20
                                source: "file:///usr/share/icons/Papirus/64x64/places/" + modelData.icon + ".svg"
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                text: win.tr(modelData.label)
                                color: directoryModel.path === modelData.path && !win.appsMode ? "#FFFFFF" : theme.muted
                                font.pixelSize: 12
                            }
                        }

                        HoverHandler { id: sideHover }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.navigate(modelData.path)
                        }
                    }
                }

                Text {
                    text: win.tr("DEVICES")
                    visible: volumesModel.count > 0
                    color: "#6F7682"
                    font.pixelSize: 9
                    font.letterSpacing: 1.5
                    leftPadding: 10
                    topPadding: 14
                    bottomPadding: 6
                }

                Repeater {
                    model: volumesModel

                    delegate: Rectangle {
                        id: deviceRow
                        required property int index
                        required property string label
                        required property string device
                        required property string size
                        required property string fs
                        required property string mountPoint
                        required property bool mounted
                        required property bool removable
                        required property string icon

                        width: parent.width
                        height: 46
                        radius: 10
                        color: mounted ? "#1A2A3945" : "transparent"

                        HoverHandler { id: deviceHover }
                        ToolTip.visible: deviceHover.hovered
                        ToolTip.text: device + (mounted ? "\n" + mountPoint : "\nNot mounted")
                        ToolTip.delay: 600

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (deviceRow.mounted) {
                                    win.navigate(deviceRow.mountPoint)
                                } else {
                                    win.statusMessage = "Mounting " + deviceRow.label + "…"
                                    statusTimer.restart()
                                    var path = volumesModel.mountAt(deviceRow.index)
                                    if (path.length > 0) {
                                        win.navigate(path)
                                        win.statusMessage = deviceRow.label + " mounted"
                                    } else {
                                        win.statusMessage = "Could not mount " + deviceRow.label
                                        statusTimer.restart()
                                    }
                                }
                            }
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Image {
                                width: 22
                                height: 22
                                source: deviceRow.icon
                                fillMode: Image.PreserveAspectFit
                            }

                            Column {
                                width: 116
                                spacing: 1
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    width: parent.width
                                    text: deviceRow.label
                                    color: "#E4E8EF"
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: deviceRow.mounted
                                          ? (deviceRow.removable ? "USB · " : "") + deviceRow.fs.toUpperCase()
                                          : deviceRow.size + " · not mounted"
                                    color: deviceRow.mounted ? "#7ED6A5" : theme.muted
                                    font.pixelSize: 9
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                width: 26
                                height: 26
                                radius: 8
                                visible: deviceRow.mounted && deviceRow.removable
                                color: ejectHover.hovered ? "#22FFFFFF" : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: win.tr("⏏")
                                    color: theme.muted
                                    font.pixelSize: 13
                                }

                                HoverHandler { id: ejectHover }
                                ToolTip.visible: ejectHover.hovered
                                ToolTip.text: "Eject " + deviceRow.label
                                ToolTip.delay: 300
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (volumesModel.unmountAt(deviceRow.index))
                                            win.statusMessage = deviceRow.label + " ejected"
                                        else
                                            win.statusMessage = "Could not eject " + deviceRow.label
                                        statusTimer.restart()
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    text: win.tr("WAYDROID")
                    color: "#6F7682"
                    font.pixelSize: 9
                    font.letterSpacing: 1.5
                    leftPadding: 10
                    topPadding: 14
                    bottomPadding: 6
                }

                Rectangle {
                    width: parent.width
                    height: 38
                    radius: 10
                    color: win.appsMode ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14) : androidHover.hovered ? "#16FFFFFF" : "transparent"
                    border.width: win.appsMode ? 1 : 0
                    border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.45)

                    Behavior on color { ColorAnimation { duration: 110 } }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Image { width: 20; height: 20; source: "file:///usr/share/icons/hicolor/512x512/apps/waydroid.png"; fillMode: Image.PreserveAspectFit }
                        Text { text: win.tr("Android apps"); color: win.appsMode ? "#FFFFFF" : theme.muted; font.pixelSize: 12 }
                    }

                    HoverHandler { id: androidHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            win.appsMode = true
                            win.clearSelection()
                            win.statusMessage = ""
                            searchField.text = ""
                            waydroidApps.filter = ""
                            waydroidApps.refresh()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 38
                    radius: 10
                    color: storageHover.hovered ? "#16FFFFFF" : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Image { width: 20; height: 20; source: "file:///usr/share/icons/Papirus/64x64/places/folder.svg"; fillMode: Image.PreserveAspectFit }
                        Text { text: win.tr("Android storage"); color: theme.muted; font.pixelSize: 12 }
                    }

                    HoverHandler { id: storageHover }
                    ToolTip.visible: storageHover.hovered
                    ToolTip.text: win.tr("Mount Android storage")
                    ToolTip.delay: 300
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var path = explorer.ensureStorage()
                            if (path.length > 0)
                                win.navigate(path)
                            else
                                win.statusMessage = "Start Waydroid once to make Android storage available."
                        }
                    }
                }

                Item { width: 1; height: 1 }

                Rectangle {
                    width: parent.width
                    height: 38
                    radius: 10
                    color: "#10FFFFFF"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.storageReady
                              ? "● Android storage ready"
                              : "○ Android storage offline"
                        color: win.storageReady ? "#7ED6A5" : theme.muted
                        font.pixelSize: 9
                    }
                }
                Timer {
                    interval: 2000
                    repeat: true
                    running: !win.storageReady
                    onTriggered: win.storageReady = explorer.storageReady()
                }
                }
            }
        }

        /* ---------------- Main ---------------- */
        Column {
            width: parent.width - 252 - 12
            height: parent.height
            spacing: 12

            /* Toolbar */
            Rectangle {
                width: parent.width
                height: 70
                radius: 18
                color: "#CC1B1B24"
                border.width: 1
                border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.18)

                Row {
                    id: navGroup
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Repeater {
                        model: [
                            { glyph: "‹", action: "back", tip: "Back (Alt+Left)" },
                            { glyph: "›", action: "forward", tip: "Forward (Alt+Right)" },
                            { glyph: "↑", action: "up", tip: "Up (Backspace)" }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            width: 34
                            height: 34
                            radius: 10
                            color: navHover.hovered ? "#22FFFFFF" : "transparent"

                            Behavior on color { ColorAnimation { duration: 100 } }

                            Text { anchors.centerIn: parent; text: modelData.glyph; color: "#E7EAF0"; font.pixelSize: 20 }
                            HoverHandler { id: navHover }
                            ToolTip.visible: navHover.hovered
                            ToolTip.text: modelData.tip
                            ToolTip.delay: 300
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.action === "back") win.goBack()
                                    else if (modelData.action === "forward") win.goForward()
                                    else win.goUp()
                                }
                            }
                        }
                    }
                }

                Row {
                    id: rightGroup
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7

                    Rectangle {
                        width: 180
                        height: 36
                        radius: Math.max(8, theme.radius - 2)
                        color: Qt.rgba(theme.surface.r, theme.surface.g,
                                       theme.surface.b, theme.glass / 100)
                        border.width: 1
                        border.color: searchField.activeFocus
                                      ? Qt.rgba(theme.accent.r, theme.accent.g,
                                                 theme.accent.b, 0.6)
                                      : Qt.rgba(theme.border.r, theme.border.g,
                                                 theme.border.b, 0.22)

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
                                placeholderText: win.appsMode ? win.tr("Search apps…") : win.tr("Search this folder…")
                                color: theme.text
                                placeholderTextColor: theme.muted
                                background: null
                                font.pixelSize: 11
                                onTextChanged: {
                                    win.clearSelection()
                                    if (win.appsMode)
                                        waydroidApps.filter = text
                                    else
                                        directoryModel.filter = text
                                }
                            }
                        }
                    }

                    ComboBox {
                        id: sortBox
                        width: 92
                        height: 36
                        font.pixelSize: 10
                        model: ["Name", "Size", "Modified"]
                        currentIndex: directoryModel.sortMode === "size" ? 1 : directoryModel.sortMode === "modified" ? 2 : 0
                        visible: !win.appsMode
                        onActivated: {
                            const mode = ["name", "size", "modified"][index]
                            directoryModel.sortMode = mode
                            explorer.sortMode = mode
                            win.clearSelection()
                        }

                        background: Rectangle { color: theme.surface; radius: 10; border.width: 1; border.color: "#22FFFFFF" }
                        contentItem: Text {
                            leftPadding: 10
                            text: sortBox.currentText
                            color: theme.muted
                            font.pixelSize: 10
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        width: 30; height: 34; radius: 10
                        visible: !win.appsMode
                        color: dirHover.hovered ? "#22FFFFFF" : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: directoryModel.sortDescending ? "↓" : "↑"
                            color: theme.muted
                            font.pixelSize: 14
                        }
                        HoverHandler { id: dirHover }
                        ToolTip.visible: dirHover.hovered
                        ToolTip.text: directoryModel.sortDescending ? "Descending" : "Ascending"
                        ToolTip.delay: 300
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                directoryModel.sortDescending = !directoryModel.sortDescending
                                explorer.sortDescending = directoryModel.sortDescending
                                win.clearSelection()
                            }
                        }
                    }

                    Rectangle {
                        width: 34; height: 34; radius: 10
                        color: hiddenHover.hovered ? "#22FFFFFF" : directoryModel.showHidden ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14) : "transparent"
                        Text { anchors.centerIn: parent; text: "◉"; color: directoryModel.showHidden ? theme.accent : theme.muted; font.pixelSize: 15 }
                        HoverHandler { id: hiddenHover }
                        ToolTip.visible: hiddenHover.hovered
                        ToolTip.text: win.tr("Show hidden files (Ctrl+H)")
                        ToolTip.delay: 300
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                directoryModel.showHidden = !directoryModel.showHidden
                                explorer.showHidden = directoryModel.showHidden
                            }
                        }
                    }

                    Rectangle {
                        width: 34; height: 34; radius: 10
                        color: viewHover.hovered ? "#22FFFFFF" : "transparent"
                        Text { anchors.centerIn: parent; text: win.gridMode ? "☰" : "▦"; color: theme.muted; font.pixelSize: 15 }
                        HoverHandler { id: viewHover }
                        ToolTip.visible: viewHover.hovered
                        ToolTip.text: win.gridMode ? "List view" : "Grid view"
                        ToolTip.delay: 300
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                win.gridMode = !win.gridMode
                                explorer.gridMode = win.gridMode
                            }
                        }
                    }

                    Rectangle {
                        width: 34; height: 34; radius: 10
                        visible: explorer.hasClipboard && !win.appsMode
                        color: pasteHover.hovered ? "#22FFFFFF" : "#1D3328"
                        border.width: 1
                        border.color: "#337ED6A5"
                        Text { anchors.centerIn: parent; text: "⧉"; color: "#7ED6A5"; font.pixelSize: 15 }
                        HoverHandler { id: pasteHover }
                        ToolTip.visible: pasteHover.hovered
                        ToolTip.text: "Paste " + explorer.clipboardCount + " item(s) (Ctrl+V)"
                        ToolTip.delay: 300
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.pasteHere() }
                    }

                    Rectangle {
                        width: 34; height: 34; radius: 10
                        color: newHover.hovered ? "#22FFFFFF" : "transparent"
                        visible: !win.appsMode
                        Text { anchors.centerIn: parent; text: "＋"; color: theme.muted; font.pixelSize: 18 }
                        HoverHandler { id: newHover }
                        ToolTip.visible: newHover.hovered
                        ToolTip.text: win.tr("New folder (Ctrl+N)")
                        ToolTip.delay: 300
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { folderField.text = "New Folder"; folderDialog.open() } }
                    }

                    Rectangle {
                        width: 34; height: 34; radius: 10
                        color: refreshHover.hovered ? "#22FFFFFF" : "transparent"
                        Text { anchors.centerIn: parent; text: "⟳"; color: theme.muted; font.pixelSize: 16 }
                        HoverHandler { id: refreshHover }
                        ToolTip.visible: refreshHover.hovered
                        ToolTip.text: win.tr("Refresh (F5)")
                        ToolTip.delay: 300
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.appsMode ? waydroidApps.refresh() : directoryModel.refresh()
                        }
                    }

                    Rectangle {
                        width: 18; height: 30; radius: 6
                        color: gripHover.hovered ? "#18FFFFFF" : "transparent"
                        Text { anchors.centerIn: parent; text: "⠿"; color: "#5E646E"; font.pixelSize: 13 }
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

                    Rectangle {
                        width: 1; height: 24; radius: 1
                        color: "#1EFFFFFF"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: 30; height: 30; radius: 8
                        color: minHover.hovered ? "#22FFFFFF" : "transparent"
                        Text { anchors.centerIn: parent; text: "—"; color: theme.muted; font.pixelSize: 14 }
                        HoverHandler { id: minHover }
                        ToolTip.visible: minHover.hovered
                        ToolTip.text: win.tr("Minimize")
                        ToolTip.delay: 300
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.showMinimized()
                        }
                    }

                    Rectangle {
                        width: 30; height: 30; radius: 8
                        color: maxHover.hovered ? "#22FFFFFF" : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: win.visibility === Window.Maximized ? "❐" : "□"
                            color: theme.muted
                            font.pixelSize: 12
                        }
                        HoverHandler { id: maxHover }
                        ToolTip.visible: maxHover.hovered
                        ToolTip.text: win.visibility === Window.Maximized ? "Restore" : "Maximize"
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
                        id: closeButton
                        width: 30; height: 30; radius: 8
                        color: closeHover.hovered ? "#C42B1C" : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: win.tr("✕")
                            color: closeHover.hovered ? "#FFFFFF" : theme.muted
                            font.pixelSize: 13
                        }
                        HoverHandler { id: closeHover }
                        ToolTip.visible: closeHover.hovered
                        ToolTip.text: win.tr("Close")
                        ToolTip.delay: 300
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: explorer.quit()
                        }
                    }
                }

                /* Breadcrumb / path entry */
                Flickable {
                    id: breadcrumb
                    anchors.left: navGroup.right
                    anchors.leftMargin: 10
                    anchors.right: rightGroup.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    height: 36
                    contentWidth: crumbRow.width
                    contentHeight: height
                    clip: true
                    visible: !win.pathEntryVisible
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds

                    Row {
                        id: crumbRow
                        height: parent.height
                        spacing: 2

                        Repeater {
                            model: win.pathSegments

                            delegate: Row {
                                required property var modelData
                                required property int index
                                height: crumbRow.height
                                spacing: 2

                                Rectangle {
                                    height: 30
                                    width: crumbText.implicitWidth + 20
                                    radius: 9
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: crumbHover.hovered ? "#1FFFFFFF" : "transparent"

                                    Text {
                                        id: crumbText
                                        anchors.centerIn: parent
                                        text: win.tr(modelData.label)
                                        color: "#C8CDD6"
                                        font.pixelSize: 11
                                    }

                                    HoverHandler { id: crumbHover }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        enabled: modelData.path.length > 0
                                        onClicked: win.navigate(modelData.path)
                                    }
                                }

                                Text {
                                    text: win.tr("›")
                                    color: "#5E646E"
                                    font.pixelSize: 13
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: index < win.pathSegments.length - 1
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.left: navGroup.right
                    anchors.leftMargin: 10
                    anchors.right: rightGroup.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    height: 36
                    radius: 10
                    color: theme.surface
                    border.width: 1
                    border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.45)
                    visible: win.pathEntryVisible

                    TextField {
                        id: pathField
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        color: theme.text
                        font.pixelSize: 12
                        background: null
                        placeholderText: "~/Documents"
                        onAccepted: {
                            win.navigate(text)
                            win.pathEntryVisible = false
                        }
                        Keys.onEscapePressed: {
                            win.pathEntryVisible = false
                            directoryModel.refresh()
                        }
                    }
                }
            }

            /* Content */
            Rectangle {
                width: parent.width
                height: parent.height - 70 - 12
                radius: 18
                color: "#B3121218"
                border.width: 1
                border.color: "#22FFFFFF"
                clip: true

                WheelHandler {
                    acceptedModifiers: Qt.ControlModifier
                    onWheel: function (event) {
                        explorer.iconSize = explorer.iconSize + (event.angleDelta.y > 0 ? 6 : -6)
                        event.accepted = true
                    }
                }

                GridView {
                    id: grid
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: statusBar.top
                    visible: !win.appsMode && win.gridMode
                    cellWidth: Math.max(120, explorer.iconSize + 90)
                    cellHeight: Math.max(120, explorer.iconSize + 82)
                    leftMargin: 20
                    topMargin: 18
                    clip: true
                    model: directoryModel
                    cacheBuffer: 400

                    delegate: Item {
                        id: gridCell
                        required property int index
                        required property string name
                        required property string path
                        required property bool isDir
                        required property string icon
                        required property string thumbnail
                        required property string size
                        required property string modified

                        width: grid.cellWidth
                        height: grid.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 5
                            radius: 14
                            color: win.isSelected(gridCell.index) ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14)
                                   : gridHover.hovered ? "#16FFFFFF" : "transparent"
                            border.width: win.isSelected(gridCell.index) ? 1 : 0
                            border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.45)

                            Behavior on color { ColorAnimation { duration: 100 } }
                        }

                        Rectangle {
                            id: thumbFrame
                            width: explorer.iconSize
                            height: explorer.iconSize
                            radius: 12
                            clip: true
                            color: "#20202A"
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 16
                            visible: gridCell.thumbnail.length > 0

                            Image {
                                anchors.fill: parent
                                source: gridCell.thumbnail
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 128
                                sourceSize.height: 128
                            }
                        }

                        Rectangle {
                            id: fallback
                            width: explorer.iconSize
                            height: explorer.iconSize
                            radius: 14
                            color: "#24242C"
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 16
                            visible: gridCell.thumbnail.length === 0
                            Text {
                                anchors.centerIn: parent
                                text: gridCell.name.charAt(0).toUpperCase()
                                color: "#9AA1AC"
                                font.pixelSize: Math.round(explorer.iconSize / 3)
                                font.weight: Font.DemiBold
                            }
                        }

                        Image {
                            id: gridImage
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 16
                            width: explorer.iconSize
                            height: explorer.iconSize
                            source: gridCell.icon
                            fillMode: Image.PreserveAspectFit
                            visible: gridCell.thumbnail.length === 0 && status === Image.Ready
                        }

                        Text {
                            anchors.top: parent.top
                            anchors.topMargin: 16 + explorer.iconSize + 8
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - 20
                            text: gridCell.name
                            color: theme.text
                            font.pixelSize: 11
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                        HoverHandler { id: gridHover }
                        ToolTip.visible: gridHover.hovered
                        ToolTip.delay: 800
                        ToolTip.text: gridCell.name
                                      + (gridCell.isDir ? "" : "\n" + gridCell.size)
                                      + "\n" + gridCell.modified
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function (mouse) {
                                if (mouse.button === Qt.RightButton) {
                                    if (!win.isSelected(gridCell.index))
                                        win.selectOnly(gridCell.index)
                                    win.contextIndex = gridCell.index
                                    fileMenu.popup()
                                } else if (mouse.modifiers & Qt.ControlModifier) {
                                    win.toggleSelect(gridCell.index)
                                } else if (mouse.modifiers & Qt.ShiftModifier) {
                                    win.selectRange(gridCell.index)
                                } else {
                                    win.selectOnly(gridCell.index)
                                }
                            }
                            onDoubleClicked: win.openIndex(gridCell.index)
                        }
                    }
                }

                ListView {
                    id: fileList
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: statusBar.top
                    visible: !win.appsMode && !win.gridMode
                    clip: true
                    model: directoryModel
                    cacheBuffer: 400

                    delegate: Rectangle {
                        id: fileRow
                        required property int index
                        required property string name
                        required property bool isDir
                        required property string size
                        required property string modified
                        required property string icon

                        width: fileList.width
                        height: 46
                        radius: 10
                        color: win.isSelected(fileRow.index) ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14)
                               : rowHover.hovered ? "#12FFFFFF" : "transparent"

                        Behavior on color { ColorAnimation { duration: 100 } }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            Image { width: 24; height: 24; source: fileRow.icon; fillMode: Image.PreserveAspectFit }
                            Text { width: 420; text: fileRow.name; color: theme.text; font.pixelSize: 12; elide: Text.ElideRight }
                            Text { width: 100; text: fileRow.isDir ? "" : fileRow.size; color: "#8A909B"; font.pixelSize: 11 }
                            Text { text: fileRow.modified; color: theme.muted; font.pixelSize: 11 }
                        }

                        HoverHandler { id: rowHover }
                        ToolTip.visible: rowHover.hovered
                        ToolTip.delay: 800
                        ToolTip.text: fileRow.name + "\n" + fileRow.modified
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function (mouse) {
                                if (mouse.button === Qt.RightButton) {
                                    if (!win.isSelected(fileRow.index))
                                        win.selectOnly(fileRow.index)
                                    win.contextIndex = fileRow.index
                                    fileMenu.popup()
                                } else if (mouse.modifiers & Qt.ControlModifier) {
                                    win.toggleSelect(fileRow.index)
                                } else if (mouse.modifiers & Qt.ShiftModifier) {
                                    win.selectRange(fileRow.index)
                                } else {
                                    win.selectOnly(fileRow.index)
                                }
                            }
                            onDoubleClicked: win.openIndex(fileRow.index)
                        }
                    }
                }

                ListView {
                    id: appList
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: statusBar.top
                    visible: win.appsMode
                    clip: true
                    model: waydroidApps
                    topMargin: 10

                    delegate: Rectangle {
                        id: appRow
                        required property int index
                        required property string name
                        required property string packageName
                        required property string icon

                        width: appList.width
                        height: 66
                        radius: 12
                        color: appHover.hovered ? "#16FFFFFF" : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12
                            Image { width: 38; height: 38; source: appRow.icon; fillMode: Image.PreserveAspectFit }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Text { text: appRow.name; color: theme.text; font.pixelSize: 13; font.weight: Font.DemiBold }
                                Text { text: appRow.packageName; color: theme.muted; font.pixelSize: 10 }
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.rightMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            width: 64; height: 28; radius: 9
                            color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14)
                            Text { anchors.centerIn: parent; text: win.tr("Open"); color: theme.accent; font.pixelSize: 10 }
                        }

                        HoverHandler { id: appHover }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: waydroidApps.launch(appRow.index) }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: waydroidApps.count === 0
                        text: searchField.text.length > 0
                              ? "No matching Android apps."
                              : "No Android apps yet. Start Waydroid once."
                        color: theme.muted
                        font.pixelSize: 12
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: !win.appsMode && directoryModel.count === 0
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: directoryModel.error.length > 0 ? directoryModel.error : "Empty folder"
                        color: theme.muted
                        font.pixelSize: 13
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: directoryModel.error.length > 0
                        text: win.tr("Start Waydroid once to make Android storage available.")
                        color: "#5E646E"
                        font.pixelSize: 11
                    }
                }

                Rectangle {
                    id: statusBar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 32
                    color: "#9917171E"

                    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: "#1EFFFFFF" }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.statusMessage.length > 0
                              ? win.statusMessage
                              : win.selection.length > 1
                                ? win.selection.length + " selected"
                                : (win.appsMode ? waydroidApps.count
                                                   + (waydroidApps.count === 1 ? " Android app" : " Android apps")
                                                : directoryModel.count + (directoryModel.count === 1 ? " item" : " items"))
                        color: win.statusMessage.length > 0 ? theme.accent : theme.muted
                        font.pixelSize: 10
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.appsMode ? "" : directoryModel.freeSpace() + " free"
                        color: theme.muted
                        font.pixelSize: 10
                    }
                }
            }
        }
    }

    /* Context menu */
    Menu {
        id: fileMenu
        palette.window: "#1E1E28"
        palette.windowText: theme.text
        palette.text: theme.text
        palette.buttonText: theme.text
        palette.highlight: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14)
        palette.highlightedText: "#FFFFFF"
        background: Rectangle {
            implicitWidth: 230
            color: "#1E1E28"
            radius: 12
            border.width: 1
            border.color: "#33FFFFFF"
        }
        MenuItem {
            text: win.tr("Open")
            visible: win.selection.length <= 1 && !win.appsMode
            onTriggered: win.openIndex(win.contextIndex)
        }
        MenuItem {
            text: win.tr("Open in Terminal")
            visible: win.selection.length <= 1 && !win.appsMode && directoryModel.isDirAt(win.contextIndex)
            onTriggered: explorer.openTerminal(directoryModel.pathAt(win.contextIndex))
        }
        MenuItem {
            text: win.tr("Open with Android")
            visible: win.selection.length <= 1 && !win.appsMode
                     && !directoryModel.isDirAt(win.contextIndex)
            onTriggered: explorer.openWithAndroid(directoryModel.pathAt(win.contextIndex))
        }
        MenuItem {
            text: win.tr("Rename…")
            visible: win.selection.length <= 1 && !win.appsMode
            onTriggered: {
                win.renameIndex = win.contextIndex
                renameField.text = directoryModel.nameAt(win.renameIndex)
                renameDialog.open()
            }
        }
        MenuSeparator {}
        MenuItem { text: win.tr("Copy"); enabled: !win.appsMode; onTriggered: win.copySelection(false) }
        MenuItem { text: win.tr("Cut"); enabled: !win.appsMode; onTriggered: win.copySelection(true) }
        MenuItem {
            text: win.tr("Paste")
            enabled: !win.appsMode && explorer.hasClipboard
            onTriggered: win.pasteHere()
        }
        MenuSeparator {}
        MenuItem { text: win.tr("Move to Trash"); enabled: !win.appsMode; onTriggered: win.requestDelete(false) }
        MenuItem { text: win.tr("Delete permanently"); enabled: !win.appsMode; onTriggered: win.requestDelete(true) }
        MenuSeparator {}
        MenuItem {
            text: win.tr("Copy path")
            enabled: !win.appsMode
            onTriggered: explorer.copyText(win.selectedPaths())
        }
        MenuItem {
            text: win.tr("Properties")
            enabled: !win.appsMode && win.selectedPaths().length === 1
            onTriggered: win.showProperties()
        }
    }

    Dialog {
        id: folderDialog
        modal: true
        anchors.centerIn: Overlay.overlay
        width: 380
        title: win.tr("New folder")
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: directoryModel.newFolder(folderField.text)
        background: Rectangle { color: theme.panel; radius: 16; border.width: 1; border.color: "#33FFFFFF" }
        contentItem: TextField {
            id: folderField
            height: 36
            color: theme.text
            placeholderText: win.tr("Folder name")
            background: Rectangle { color: "#121218"; radius: 8; border.width: 1; border.color: "#22FFFFFF" }
        }
    }

    Dialog {
        id: newFileDialog
        modal: true
        anchors.centerIn: Overlay.overlay
        width: 380
        title: win.tr("New file")
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: {
            if (explorer.createFile(directoryModel.path, newFileField.text))
                directoryModel.refresh()
            else
                win.statusMessage = "Could not create the file."
        }
        background: Rectangle { color: theme.panel; radius: 16; border.width: 1; border.color: "#33FFFFFF" }
        contentItem: TextField {
            id: newFileField
            height: 36
            color: theme.text
            placeholderText: win.tr("File name")
            background: Rectangle { color: "#121218"; radius: 8; border.width: 1; border.color: "#22FFFFFF" }
        }
    }

    Dialog {
        id: renameDialog
        modal: true
        anchors.centerIn: Overlay.overlay
        width: 380
        title: win.tr("Rename")
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: directoryModel.renameAt(win.renameIndex, renameField.text)
        background: Rectangle { color: theme.panel; radius: 16; border.width: 1; border.color: "#33FFFFFF" }
        contentItem: TextField {
            id: renameField
            height: 36
            color: theme.text
            background: Rectangle { color: "#121218"; radius: 8; border.width: 1; border.color: "#22FFFFFF" }
        }
    }

    Dialog {
        id: deleteDialog
        modal: true
        anchors.centerIn: Overlay.overlay
        width: 420
        title: win.deletePermanent ? "Delete permanently" : "Move to Trash"
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: {
            if (win.deletePermanent)
                directoryModel.deleteIndices(win.deleteIndices)
            else
                directoryModel.trashIndices(win.deleteIndices)
            win.clearSelection()
        }
        background: Rectangle { color: theme.panel; radius: 16; border.width: 1; border.color: "#33FFFFFF" }
        contentItem: Text {
            text: win.deletePermanent
                  ? "Permanently delete " + win.deleteIndices.length + " item(s)? This cannot be undone."
                  : "Move " + win.deleteIndices.length + " item(s) to Trash?"
            color: theme.text
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
    }

    Dialog {
        id: propertiesDialog
        modal: true
        anchors.centerIn: Overlay.overlay
        width: 470
        title: "Properties — " + win.propTitle
        standardButtons: Dialog.Ok
        background: Rectangle { color: theme.panel; radius: 16; border.width: 1; border.color: "#33FFFFFF" }
        contentItem: Column {
            width: 420
            spacing: 8

            Repeater {
                model: win.propRows
                delegate: Row {
                    required property var modelData
                    width: parent.width
                    spacing: 8

                    Text {
                        width: 104
                        text: win.tr(modelData.label)
                        color: theme.muted
                        font.pixelSize: 11
                    }
                    Text {
                        width: parent.width - 112
                        text: modelData.value
                        color: theme.text
                        font.pixelSize: 11
                        wrapMode: Text.WrapAnywhere
                    }
                }
            }
        }
    }
}

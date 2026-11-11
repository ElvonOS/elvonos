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
    title: win.tr("Gallery")
    color: theme.background

    property bool androidMode: false
    property string sourceLabel: win.tr("Pictures")
    property string sourcePath: ""
    property bool viewerOpen: false
    property int viewerIndex: -1
    property int cursorIndex: -1
    property real zoom: 1.0
    property string statusMessage: ""
    property bool typing: searchField.activeFocus

    function setSource(label, path) {
        sourceLabel = label
        sourcePath = path
        imageModel.folder = path
        searchField.text = ""
        viewerOpen = false
        cursorIndex = -1
    }

    function openLinux(label, path) {
        androidMode = false
        statusMessage = ""
        setSource(label, path)
    }

    function androidAlbum(sub) {
        if (!gallery.androidReady) {
            gallery.ensureAndroidStorage()
        }
        const path = gallery.androidPath(sub)
        if (path.length === 0 || !gallery.dirExists(path)) {
            statusMessage = path.length === 0
                            ? win.tr("Start Waydroid once to make Android photos available.")
                            : win.tr("No photos in this Android album yet.")
            statusTimer.restart()
            return
        }
        androidMode = true
        statusMessage = ""
        setSource(sub, path)
    }

    function switchToAndroid() {
        if (!gallery.androidReady)
            gallery.ensureAndroidStorage()
        const candidates = [
            ["Camera", "DCIM/Camera"],
            ["Pictures", "Pictures"],
            ["Screenshots", "Pictures/Screenshots"],
            ["Download", "Download"],
        ]
        for (let i = 0; i < candidates.length; ++i) {
            const path = gallery.androidPath(candidates[i][1])
            if (path.length > 0 && gallery.dirExists(path)) {
                androidMode = true
                setSource(win.tr(candidates[i][0]), path)
                return
            }
        }
        androidMode = true
        sourceLabel = win.tr("Android")
        const root = gallery.androidRoot
        if (root.length > 0) {
            setSource(win.tr("Android"), root)
        } else {
            imageModel.clear()
            sourcePath = ""
            cursorIndex = -1
            statusMessage = win.tr("Start Waydroid once to make Android photos available.")
            statusTimer.restart()
        }
    }

    function openViewer(index) {
        if (index < 0 || index >= imageModel.count)
            return
        viewerIndex = index
        zoom = 1.0
        viewerOpen = true
    }

    function stepViewer(delta) {
        if (!viewerOpen || imageModel.count === 0)
            return
        viewerIndex = (viewerIndex + delta + imageModel.count) % imageModel.count
        zoom = 1.0
    }

    function moveCursor(dx, dy) {
        if (imageModel.count === 0)
            return
        let columns = 1
        columns = Math.max(1, Math.floor((grid.width - grid.leftMargin * 2) / grid.cellWidth))
        const current = cursorIndex < 0 ? 0 : cursorIndex
        const next = current + dx + dy * columns
        if (next >= 0 && next < imageModel.count) {
            cursorIndex = next
            grid.positionViewAtIndex(next, GridView.Contain)
        }
    }

    function viewerInfo() {
        if (!viewerOpen || viewerIndex < 0)
            return ""
        const props = gallery.properties(imageModel.pathAt(viewerIndex))
        return (props.size ? props.size + "  ·  " : "") + (props.modified ? props.modified : "")
    }

    Component.onCompleted: {
        if (gallery.dirExists(gallery.pictures))
            setSource(win.tr("Pictures"), gallery.pictures)
        else
            setSource(win.tr("Wallpapers"), gallery.wallpapers)
        win.requestActivate()
        Qt.callLater(function () { win.requestActivate() })
        Qt.callLater(function () { gallery.ensureAndroidStorage() })
    }

    Timer {
        id: statusTimer
        interval: 3800
        onTriggered: win.statusMessage = ""
    }

    Shortcut { sequence: "F5"; onActivated: imageModel.refresh() }
    Shortcut {
        sequence: "Ctrl+F"
        enabled: !win.viewerOpen
        onActivated: searchField.forceActiveFocus()
    }
    Shortcut {
        sequence: "Ctrl+1"
        enabled: !win.viewerOpen
        onActivated: win.openLinux(win.tr("Pictures"), gallery.pictures)
    }
    Shortcut {
        sequence: "Ctrl+2"
        enabled: !win.viewerOpen
        onActivated: win.switchToAndroid()
    }
    Shortcut { sequence: "Ctrl+Q"; onActivated: gallery.quit() }
    Shortcut { sequence: "Ctrl+W"; onActivated: gallery.quit() }
    Shortcut { sequence: "Ctrl+M"; onActivated: win.showMinimized() }
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (win.viewerOpen) {
                win.viewerOpen = false
            } else if (win.typing) {
                searchField.text = ""
                searchField.focus = false
            } else {
                imageModel.filter = ""
            }
        }
    }
    Shortcut {
        sequence: "Left"
        enabled: win.viewerOpen
        onActivated: win.stepViewer(-1)
    }
    Shortcut {
        sequence: "Right"
        enabled: win.viewerOpen
        onActivated: win.stepViewer(1)
    }
    Shortcut {
        sequence: "Up"
        enabled: !win.viewerOpen && !win.typing
        onActivated: win.moveCursor(0, -1)
    }
    Shortcut {
        sequence: "Down"
        enabled: !win.viewerOpen && !win.typing
        onActivated: win.moveCursor(0, 1)
    }
    Shortcut {
        sequence: "Left"
        enabled: !win.viewerOpen && !win.typing
        onActivated: win.moveCursor(-1, 0)
    }
    Shortcut {
        sequence: "Right"
        enabled: !win.viewerOpen && !win.typing
        onActivated: win.moveCursor(1, 0)
    }
    Shortcut {
        sequence: "Return"
        enabled: !win.viewerOpen && !win.typing
        onActivated: win.openViewer(win.cursorIndex >= 0 ? win.cursorIndex : 0)
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

    Row {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        /* ---------------- Sidebar ---------------- */
        Rectangle {
            width: 242
            height: parent.height
            radius: 18
            color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, theme.glass / 100)
            border.width: 1
            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.15)

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
                            width: 30; height: 30; radius: 9
                            color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.13)
                            border.width: 1
                            border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.33)
                            Text { anchors.centerIn: parent; text: "▧"; color: theme.accent2; font.pixelSize: 16 }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: win.tr("GALLERY"); color: theme.text; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1.2 }
                            Text { text: win.tr("Photos & Android"); color: theme.muted; font.pixelSize: 9 }
                        }
                    }

                    Text {
                        text: win.androidMode ? win.tr("ANDROID") : win.tr("LIBRARY")
                        color: theme.muted
                        font.pixelSize: 9
                        font.letterSpacing: 1.5
                        leftPadding: 10
                        topPadding: 14
                        bottomPadding: 6
                    }

                    Repeater {
                        model: win.androidMode
                               ? [
                                   { label: win.tr("Camera"), sub: "DCIM/Camera", icon: "folder-pictures" },
                                   { label: win.tr("Pictures"), sub: "Pictures", icon: "folder-pictures" },
                                   { label: win.tr("Screenshots"), sub: "Pictures/Screenshots", icon: "folder-pictures" },
                                   { label: win.tr("Download"), sub: "Download", icon: "folder-download" }
                                 ]
                               : [
                                   { label: win.tr("Pictures"), path: gallery.pictures, icon: "folder-pictures" },
                                   { label: win.tr("Desktop"), path: gallery.desktop, icon: "user-desktop" },
                                   { label: win.tr("Downloads"), path: gallery.downloads, icon: "folder-download" },
                                   { label: win.tr("Wallpapers"), path: gallery.wallpapers, icon: "folder-pictures" }
                                 ]

                        delegate: Rectangle {
                            required property var modelData
                            width: parent.width
                            height: 38
                            radius: 10
                            color: win.sourceLabel === modelData.label ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14)
                                   : sourceHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086) : "transparent"
                            border.width: win.sourceLabel === modelData.label ? 1 : 0
                            border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.33)

                            Behavior on color { ColorAnimation { duration: 110 } }

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10
                                Image {
                                    width: 20; height: 20
                                    source: "file:///usr/share/icons/Papirus/64x64/places/" + modelData.icon + ".svg"
                                    fillMode: Image.PreserveAspectFit
                                }
                                Text {
                                    text: modelData.label
                                    color: win.sourceLabel === modelData.label ? theme.text : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.85)
                                    font.pixelSize: 12
                                }
                            }

                            HoverHandler { id: sourceHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (win.androidMode)
                                        win.androidAlbum(modelData.sub)
                                    else
                                        win.openLinux(modelData.label, modelData.path)
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 36
                        radius: 10
                        color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.06)
                        visible: gallery.androidReady || win.androidMode

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: gallery.androidReady
                                  ? win.tr("● Android storage ready")
                                  : win.tr("○ Android storage offline")
                            color: gallery.androidReady ? theme.light ? "#1E7A4D" : "#7ED6A5" : theme.muted
                            font.pixelSize: 9
                        }
                    }
                }
            }
        }

        /* ---------------- Main ---------------- */
        Column {
            width: parent.width - 242 - 12
            height: parent.height
            spacing: 12

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
                    spacing: 9
                    Rectangle {
                        width: 32; height: 32; radius: 9
                        color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.13)
                        border.width: 1
                        border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.33)
                        Text { anchors.centerIn: parent; text: "▧"; color: theme.accent2; font.pixelSize: 15 }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: win.tr("GALLERY"); color: theme.text; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1.2 }
                        Text { text: win.sourceLabel; color: theme.muted; font.pixelSize: 9 }
                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 200
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        width: 92; height: 32; radius: 9
                        color: !win.androidMode ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14) : tabLinux.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.09) : "transparent"
                        border.width: !win.androidMode ? 1 : 0
                        border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.33)
                        HoverHandler { id: tabLinux }
                        Text { anchors.centerIn: parent; text: win.tr("Linux"); color: !win.androidMode ? theme.text : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.75); font.pixelSize: 10 }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.openLinux(win.tr("Pictures"), gallery.pictures)
                        }
                    }

                    Rectangle {
                        width: 100; height: 32; radius: 9
                        color: win.androidMode ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14) : tabAndroid.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.09) : "transparent"
                        border.width: win.androidMode ? 1 : 0
                        border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.33)
                        HoverHandler { id: tabAndroid }
                        Text { anchors.centerIn: parent; text: win.tr("Android"); color: win.androidMode ? theme.text : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.75); font.pixelSize: 10 }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.switchToAndroid()
                        }
                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 408
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        width: 250; height: 34; radius: 10
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
                                placeholderText: win.tr("Search photos…")
                                color: theme.text
                                placeholderTextColor: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90)
                                background: null
                                font.pixelSize: 11
                                onTextChanged: imageModel.filter = text
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
                            onClicked: imageModel.refresh()
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
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: gallery.quit() }
                    }
                }
            }

            /* Photo grid */
            Rectangle {
                width: parent.width
                height: parent.height - 70 - 12
                radius: 18
                color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.92)
                border.width: 1
                border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14)
                clip: true

                GridView {
                    id: grid
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: statusBar.top
                    clip: true
                    cellWidth: 172
                    cellHeight: 166
                    leftMargin: 18
                    topMargin: 16
                    cacheBuffer: 500
                    model: imageModel

                    delegate: Item {
                        id: cell
                        required property int index
                        required property string name
                        required property string url
                        required property string sizeText
                        required property string modified

                        width: grid.cellWidth
                        height: grid.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 5
                            radius: 12
                            color: win.cursorIndex === cell.index ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14)
                                   : cellHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.04)
                            border.width: win.cursorIndex === cell.index ? 1 : 0
                            border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.33)

                            Behavior on color { ColorAnimation { duration: 100 } }

                            Rectangle {
                                id: thumb
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 6
                                height: 112
                                radius: 9
                                clip: true
                                color: theme.surface

                                Image {
                                    anchors.fill: parent
                                    source: cell.url
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize.width: 360
                                    sourceSize.height: 240
                                }
                            }

                            Text {
                                anchors.top: thumb.bottom
                                anchors.topMargin: 6
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                text: cell.name
                                color: theme.text
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }

                        HoverHandler { id: cellHover }
                        ToolTip.visible: cellHover.hovered
                        ToolTip.delay: 700
                        ToolTip.text: cell.name + win.tr("\n") + cell.sizeText + "  ·  " + cell.modified
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                win.cursorIndex = cell.index
                                win.openViewer(cell.index)
                            }
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: imageModel.count === 0
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: imageModel.error.length > 0 ? imageModel.error : win.tr("No photos in this album.")
                        color: theme.muted
                        font.pixelSize: 13
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: win.androidMode
                        text: gallery.androidReady
                              ? win.tr("Album: ") + win.sourcePath
                              : win.tr("Start Waydroid once, then reopen the Android tab.")
                        color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.70)
                        font.pixelSize: 11
                    }
                }

                Rectangle {
                    id: statusBar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 34
                    color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.60)

                    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12) }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: freeText.left
                        anchors.rightMargin: 12
                        text: win.statusMessage.length > 0
                              ? win.statusMessage
                              : imageModel.count + (imageModel.count === 1 ? win.tr(" photo") : win.tr(" photos"))
                                + (win.sourcePath.length > 0 ? "  ·  " + win.sourcePath : "")
                        color: win.statusMessage.length > 0 ? theme.light ? "#2E8B57" : "#8FD3A8" : theme.muted
                        font.pixelSize: 10
                        elide: Text.ElideMiddle
                    }

                    Text {
                        id: freeText
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.androidMode ? win.tr("Android") : win.tr("Local")
                        color: win.androidMode ? theme.light ? "#1E7A4D" : "#7ED6A5" : Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.85)
                        font.pixelSize: 10
                    }
                }
            }
        }
    }

    /* ---------------- Viewer overlay ---------------- */
    Rectangle {
        anchors.fill: parent
        visible: win.viewerOpen
        color: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.94)

        Image {
            anchors.fill: parent
            source: win.viewerOpen ? imageModel.urlAt(win.viewerIndex) : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            scale: win.zoom
            Behavior on scale { NumberAnimation { duration: 120 } }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 56
            color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.80)

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                Text {
                    text: win.viewerIndex + 1 + " / " + imageModel.count
                    color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.85)
                    font.pixelSize: 10
                }
                Text {
                    text: imageModel.nameAt(win.viewerIndex)
                    color: theme.text
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                Text {
                    text: win.viewerInfo() + "  ·  " + Math.round(win.zoom * 100) + "%"
                    color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90)
                    font.pixelSize: 10
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    width: 34; height: 30; radius: 9
                    color: prevHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086)
                    Text { anchors.centerIn: parent; text: "‹"; color: theme.text; font.pixelSize: 20 }
                    HoverHandler { id: prevHover }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.stepViewer(-1) }
                }
                Rectangle {
                    width: 34; height: 30; radius: 9
                    color: nextHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086)
                    Text { anchors.centerIn: parent; text: "›"; color: theme.text; font.pixelSize: 20 }
                    HoverHandler { id: nextHover }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.stepViewer(1) }
                }
                Rectangle {
                    width: 30; height: 30; radius: 8
                    color: viewerCloseHover.hovered ? "#C42B1C" : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: viewerCloseHover.hovered ? theme.text : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.85)
                        font.pixelSize: 13
                    }
                    HoverHandler { id: viewerCloseHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.viewerOpen = false
                    }
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            height: 30
            width: 190
            radius: 9
            color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.53)
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: win.tr("←/→ browse · wheel zoom · Esc close")
                color: theme.muted
                font.pixelSize: 9
            }
        }

        WheelHandler {
            onWheel: function (event) {
                win.zoom = Math.max(0.5, Math.min(5.0,
                    win.zoom + (event.angleDelta.y > 0 ? 0.15 : -0.15)))
                event.accepted = true
            }
        }
    }
}

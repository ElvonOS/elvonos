import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: root
    visible: false
    width: screen.width
    height: screen.height
    color: "transparent"

    readonly property real uiScale: formFactor.scale
    property int columns: formFactor.type === "tablet" ? 4
                          : formFactor.type === "tv" ? 8 : 6
    property int rows: Math.max(3, Math.floor((height - 62 - 12 - 34 + 10)
                                              / Math.round(110 * uiScale)))
    property int perPage: columns * rows
    property int pageCount: Math.max(1, Math.ceil(desktopModel.count / perPage))
    property int currentPage: Math.round(flick.contentX / Math.max(1, flick.width))
    property int menuIndex: -1
    property bool menuOpen: false
    property real menuX: 0
    property real menuY: 0
    property var propertiesData: ({})
    property string lastMessage: ""
    property string panelMode: ""
    property var propRows: []
    property bool groupOpen: false
    property int groupIndex: -1
    property string groupTitle: ""
    property string groupPath: ""
    property string groupFilter: ""
    property var groupEntries: []

    function tr(text) {
        // Read revision so bindings re-evaluate when the language changes.
        if (desktopLang.revision < 0)
            return text
        return desktopLang.tr(text)
    }

    function openGroup(index) {
        groupIndex = index
        groupTitle = root.tr(desktopModel.nameAt(index))
        groupPath = desktopModel.pathAt(index)
        groupEntries = desktopModel.entriesIn(groupPath)
        groupFilter = ""
        groupOpen = true
        if (groupTitle.toLowerCase().indexOf("system") >= 0)
            Qt.callLater(function () { groupSearch.forceActiveFocus() })
    }

    function closeGroup() {
        groupOpen = false
        groupIndex = -1
        groupFilter = ""
        groupEntries = []
    }

    function filteredGroupEntries() {
        const needle = groupFilter.trim().toLowerCase()
        if (needle.length === 0)
            return groupEntries
        return groupEntries.filter(function (entry) {
            const name = (entry.name || "").toLowerCase()
            const exec = (entry.exec || "").toLowerCase()
            return name.indexOf(needle) >= 0 || exec.indexOf(needle) >= 0
        })
    }

    function openMenu(index, x, y) {
        menuIndex = index
        propertiesData = desktopModel.properties(index)
        menuX = Math.max(8, Math.min(x, width - 248))
        menuY = Math.max(8, Math.min(y, height - 330))
        menuOpen = true
    }

    function closeMenu() {
        menuOpen = false
    }

    function openPanel(mode) {
        panelMode = mode
    }

    function closePanel() {
        panelMode = ""
    }

    function startRename() {
        const current = propertiesData.name !== undefined ? propertiesData.name
                                                         : desktopModel.nameAt(menuIndex)
        closeMenu()
        panelField.text = current
        openPanel("rename")
    }

    function startGroup() {
        closeMenu()
        panelField.text = "Group"
        openPanel("group")
    }

    function startDelete() {
        closeMenu()
        openPanel("delete")
    }

    function startProperties() {
        closeMenu()
        const data = desktopModel.properties(menuIndex)
        let rows = []
        rows.push({ label: root.tr("Name"), value: data.name })
        rows.push({ label: root.tr("Type"), value: data.type })
        rows.push({ label: root.tr("Path"), value: data.path })
        rows.push({ label: root.tr("Size"), value: data.size })
        rows.push({ label: root.tr("Modified"), value: data.modified })
        if (data.exec && data.exec.length > 0)
            rows.push({ label: root.tr("Command"), value: data.exec })
        if (data.categories && data.categories.length > 0)
            rows.push({ label: root.tr("Categories"), value: data.categories })
        if (data.comment && data.comment.length > 0)
            rows.push({ label: root.tr("Comment"), value: data.comment })
        if (data.package && data.package.length > 0)
            rows.push({ label: root.tr("Package"), value: data.package.replace("flatpak:", "flatpak · ") })
        propRows = rows
        openPanel("properties")
    }

    function startUninstall() {
        closeMenu()
        openPanel("uninstall")
    }

    function runPanelAction() {
        const mode = panelMode
        closePanel()
        if (mode === "rename")
            desktopModel.renameEntry(menuIndex, panelField.text)
        else if (mode === "group")
            desktopModel.groupEntry(menuIndex, panelField.text)
        else if (mode === "delete")
            desktopModel.deleteEntry(menuIndex)
        else if (mode === "uninstall")
            desktopModel.uninstallEntry(menuIndex)
    }

    function showToast(text) {
        lastMessage = text
        toastTimer.restart()
    }

    Timer {
        id: toastTimer
        interval: 3200
        onTriggered: root.lastMessage = ""
    }

    Connections {
        target: desktopModel
        function onLastMessageChanged() {
            if (desktopModel.lastMessage.length > 0)
                root.showToast(desktopModel.lastMessage)
        }
    }

    component MenuItem: Rectangle {
        id: item
        property string label: ""
        property bool danger: false
        signal activated()

        width: parent ? parent.width : 230
        height: 30
        radius: 7
        color: itemHover.hovered ? (danger ? "#3A1E1E" : "#1A2A3945") : "transparent"

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: item.label
            color: item.danger ? "#FFB4B0" : "#E9ECF2"
            font.pixelSize: 10
        }
        HoverHandler { id: itemHover }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: item.activated()
        }
    }

    Component.onCompleted: {
        console.log("desktop-extras size", width, height,
                    "screen", screen.width, screen.height,
                    "icons", desktopModel.count)
        if (desktopTest.length > 0) {
            const parts = desktopTest.split(":")
            const index = parseInt(parts[1] !== undefined ? parts[1] : "0")
            root.menuIndex = index
            if (parts[0] === "menu") {
                Qt.callLater(function () { root.openMenu(index, 420, 250) })
            } else if (parts[0] === "properties") {
                Qt.callLater(function () { root.startProperties() })
            } else if (parts[0] === "group") {
                Qt.callLater(function () { root.openGroup(index) })
            }
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.topMargin: 62 + (panelLayout.dockPosition === "top" ? 86 : 0)
        anchors.bottomMargin: 12
        contentWidth: width * root.pageCount
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        interactive: true
        clip: true

        Behavior on contentX {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        onMovementEnded: {
            const page = Math.round(contentX / Math.max(1, width * 0.6))
            contentX = Math.max(0, Math.min(page * width, contentWidth - width))
        }

        WheelHandler {
            onWheel: function (event) {
                const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                if (delta === 0)
                    return
                flick.contentX = Math.max(0,
                    Math.min(flick.contentX - delta,
                             flick.contentWidth - flick.width))
                event.accepted = true
            }
        }

        Repeater {
            model: root.pageCount

            delegate: Item {
                id: pageItem
                required property int index
                x: index * flick.width
                width: flick.width
                height: flick.height

                Grid {
                    columns: root.columns
                    spacing: Math.round(10 * root.uiScale)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 24

                    Repeater {
                        model: root.perPage

                        delegate: Item {
                            id: iconCell

                            required property int index
                            property int modelIndex: pageItem.index * root.perPage + index

                            visible: modelIndex < desktopModel.count
                            width: Math.round(108 * root.uiScale)
                            height: Math.round(110 * root.uiScale)

                            Rectangle {
                                id: hoverBackground
                                anchors.fill: parent
                                radius: 12
                                color: iconMouse.containsMouse ? "#22FFFFFF" : "transparent"
                                border.width: iconMouse.containsMouse ? 1 : 0
                                border.color: "#33FFFFFF"

                                Behavior on color { ColorAnimation { duration: 110 } }
                            }

                            Rectangle {
                                id: iconFallback
                                width: Math.round(48 * root.uiScale)
                                height: Math.round(48 * root.uiScale)
                                radius: 12
                                color: "#2A2A33"
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: Math.round(10 * root.uiScale)
                                visible: iconImage.status !== Image.Ready

                                Text {
                                    anchors.centerIn: parent
                                    text: (desktopModel.nameAt(iconCell.modelIndex) || "?").charAt(0).toUpperCase()
                                    color: "#9AA1AC"
                                    font.pixelSize: 18
                                    font.weight: Font.DemiBold
                                }
                            }

                            Image {
                                id: iconImage
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 10
                                width: Math.round(48 * root.uiScale)
                                height: Math.round(48 * root.uiScale)
                                source: desktopModel.iconAt(iconCell.modelIndex)
                                fillMode: Image.PreserveAspectFit
                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.top: iconImage.bottom
                                anchors.topMargin: 7
                                anchors.left: parent.left
                                anchors.right: parent.right
                                text: desktopModel.isDirAt(iconCell.modelIndex)
                                      ? root.tr(desktopModel.nameAt(iconCell.modelIndex))
                                      : desktopModel.nameAt(iconCell.modelIndex)
                                color: "#F2F4F8"
                                font.pixelSize: Math.round(12 * root.uiScale)
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            MouseArea {
                                id: iconMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onDoubleClicked: {
                                    if (desktopModel.isDirAt(iconCell.modelIndex))
                                        root.openGroup(iconCell.modelIndex)
                                    else
                                        desktopModel.launch(iconCell.modelIndex)
                                }
                                onClicked: function (mouse) {
                                    if (mouse.button === Qt.RightButton) {
                                        const point = iconMouse.mapToItem(overlay, mouse.x, mouse.y)
                                        root.openMenu(iconCell.modelIndex, point.x, point.y)
                                    }
                                }
                            }

                            DragHandler {
                                id: dragHandler
                                target: iconCell
                            }

                            Drag.active: dragHandler.active
                            Drag.mimeData: ({ "text/uri-list": "file://" + desktopModel.pathAt(iconCell.modelIndex) })
                            Drag.dragType: Drag.Automatic
                            Drag.supportedActions: Qt.CopyAction
                            Drag.hotSpot: Qt.point(iconCell.width / 2, iconCell.height / 2)
                        }
                    }
                }
            }
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        spacing: 6
        visible: root.pageCount > 1

        Repeater {
            model: root.pageCount

            Rectangle {
                required property int index
                width: root.currentPage === index ? 18 : 6
                height: 6
                radius: 3
                color: root.currentPage === index ? "#4CC2FF" : "#55FFFFFF"

                Behavior on width { NumberAnimation { duration: 150 } }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: desktopModel.count === 0
        text: root.tr("No desktop icons")
        color: "#8A8F98"
        font.pixelSize: 13
    }

    /* Dropping an application from the dock creates a desktop shortcut.
       Dropping an APK file opens the native APK installer instead. */
    DropArea {
        anchors.fill: parent
        onDropped: function (drop) {
            for (let i = 0; i < drop.urls.length; ++i) {
                const url = drop.urls[i].toString()
                if (url.toLowerCase().endsWith(".apk")) {
                    Qt.openUrlExternally(url)
                } else {
                    desktopModel.addShortcut(drop.urls[i])
                }
            }
        }
    }

    /* ---------------- desktop search ---------------- */
    Item {
        id: searchOverlay
        anchors.fill: parent
        z: 45

        property int selectedIndex: -1
        readonly property bool open: searchField.text.length > 0
                                         || desktopSearch.query.length > 0

        function firstItem() {
            for (let i = 0; i < desktopSearch.results.length; ++i) {
                if (desktopSearch.results[i].kind !== "header")
                    return i
            }
            return -1
        }

        function moveSelection(delta) {
            const count = desktopSearch.results.length
            if (count === 0)
                return
            let index = selectedIndex
            if (index < 0)
                index = firstItem()
            if (index < 0)
                return
            for (let step = 0; step < count; ++step) {
                index = (index + delta + count) % count
                if (desktopSearch.results[index].kind !== "header")
                    break
            }
            selectedIndex = index
        }

        function activateSelected() {
            if (selectedIndex >= 0
                && desktopSearch.results[selectedIndex].kind !== "header")
                desktopSearch.activate(selectedIndex)
            clearSearch()
        }

        function clearSearch() {
            searchField.text = ""
            desktopSearch.clear()
            selectedIndex = -1
        }

        Connections {
            target: desktopSearch
            function onQueryChanged() {
                if (!searchField.activeFocus && searchField.text !== desktopSearch.query)
                    searchField.text = desktopSearch.query
            }
            function onResultsChanged() {
                searchOverlay.selectedIndex = searchOverlay.firstItem()
            }
        }

        Timer {
            id: searchDebounce
            interval: 180
            onTriggered: desktopSearch.setQuery(searchField.text)
        }

        MouseArea {
            anchors.fill: parent
            visible: searchOverlay.open
            onClicked: searchOverlay.clearSearch()
        }

        Rectangle {
            id: searchPill
            width: formFactor.searchWidth
            height: Math.round(40 * root.uiScale)
            radius: Math.max(12, themeSettings.radius + 6)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 10 + formFactor.overscan
                             + (panelLayout.dockPosition === "top"
                                ? formFactor.dockHeight : 0)
            color: searchField.activeFocus
                   ? Qt.rgba(themeSettings.panel.r, themeSettings.panel.g,
                             themeSettings.panel.b, Math.min(0.98, themeSettings.glass / 100))
                   : Qt.rgba(themeSettings.surface.r, themeSettings.surface.g,
                             themeSettings.surface.b, themeSettings.glass / 100)
            border.width: 1
            border.color: searchField.activeFocus
                          ? Qt.rgba(themeSettings.accent.r, themeSettings.accent.g,
                                    themeSettings.accent.b, 0.65)
                          : Qt.rgba(themeSettings.border.r, themeSettings.border.g,
                                    themeSettings.border.b, 0.25)

            Row {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 12
                spacing: 9

                Item {
                    width: 18
                    height: 18
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: "transparent"
                        border.width: 1.6
                        border.color: searchField.activeFocus
                                      ? themeSettings.accent : themeSettings.muted
                        anchors.left: parent.left
                        anchors.top: parent.top
                    }
                    Rectangle {
                        width: 2
                        height: 6
                        radius: 1
                        color: searchField.activeFocus
                               ? themeSettings.accent : themeSettings.muted
                        x: 11
                        y: 11
                        rotation: 45
                        transformOrigin: Item.TopLeft
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.IBeamCursor
                        onClicked: searchField.forceActiveFocus()
                    }
                }

                TextField {
                    id: searchField
                    width: parent.width - 27
                    height: 34
                    anchors.verticalCenter: parent.verticalCenter
                    placeholderText: root.tr("Search apps and files…")
                    color: themeSettings.text
                    placeholderTextColor: themeSettings.muted
                    font.pixelSize: Math.round(11 * root.uiScale)
                    selectByMouse: true
                    leftPadding: 0
                    background: Item {}

                    onTextChanged: searchDebounce.restart()

                    Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_Down) {
                            searchOverlay.moveSelection(1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            searchOverlay.moveSelection(-1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Escape) {
                            searchOverlay.clearSearch()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return
                                   || event.key === Qt.Key_Enter) {
                            searchOverlay.activateSelected()
                            event.accepted = true
                        }
                    }
                }
            }
        }

        Rectangle {
            id: searchPanel
            visible: searchOverlay.open
            anchors.top: searchPill.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: formFactor.searchWidth + 90
            height: desktopSearch.results.length > 0
                    ? Math.min(formFactor.searchWidth + 90,
                               resultsColumn.implicitHeight + 16) : 54
            radius: themeSettings.radius
            color: Qt.rgba(themeSettings.panel.r, themeSettings.panel.g,
                           themeSettings.panel.b, Math.min(0.98, themeSettings.glass / 100))
            border.width: 1
            border.color: Qt.rgba(themeSettings.border.r, themeSettings.border.g,
                                  themeSettings.border.b, 0.25)
            clip: true

            MouseArea { anchors.fill: parent }

            Column {
                id: resultsColumn
                visible: desktopSearch.results.length > 0
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 2

                Repeater {
                    model: desktopSearch.results

                    delegate: Item {
                        required property var modelData
                        required property int index

                        width: resultsColumn.width
                        height: modelData.kind === "header" ? 22 : 44

                        Text {
                            visible: modelData.kind === "header"
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                            text: modelData.name
                            color: themeSettings.muted
                            font.pixelSize: 8
                            font.letterSpacing: 1.2
                        }

                        Rectangle {
                            id: resultRow
                            visible: modelData.kind !== "header"
                            anchors.fill: parent
                            radius: 8
                            color: searchOverlay.selectedIndex === index
                                   ? Qt.rgba(themeSettings.accent.r,
                                             themeSettings.accent.g,
                                             themeSettings.accent.b, 0.16)
                                   : (resultHover.hovered
                                      ? Qt.rgba(themeSettings.text.r,
                                                themeSettings.text.g,
                                                themeSettings.text.b, 0.06)
                                      : "transparent")
                            border.width: searchOverlay.selectedIndex === index ? 1 : 0
                            border.color: Qt.rgba(themeSettings.accent.r,
                                                  themeSettings.accent.g,
                                                  themeSettings.accent.b, 0.45)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 9

                                Rectangle {
                                    id: resultFallback
                                    width: 24
                                    height: 24
                                    radius: 6
                                    color: "#2A2A33"
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: resultIcon.status !== Image.Ready

                                    Text {
                                        anchors.centerIn: parent
                                        text: (modelData.name || "?").charAt(0).toUpperCase()
                                        color: themeSettings.muted
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                    }
                                }

                                Image {
                                    id: resultIcon
                                    width: 24
                                    height: 24
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: modelData.icon !== undefined ? modelData.icon : ""
                                    fillMode: Image.PreserveAspectFit
                                    visible: status === Image.Ready
                                }

                                Column {
                                    width: parent.width - 24 - 64 - 30
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Text {
                                        width: parent.width
                                        text: modelData.name
                                        color: themeSettings.text
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        text: modelData.detail !== undefined ? modelData.detail : ""
                                        color: themeSettings.muted
                                        font.pixelSize: 8
                                        elide: Text.ElideMiddle
                                    }
                                }

                                Text {
                                    width: 40
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.type === "app" ? "APP"
                                          : (modelData.type === "file" ? "FILE" : "")
                                    color: "#8FD3FF"
                                    font.pixelSize: 7
                                    font.letterSpacing: 0.8
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            HoverHandler { id: resultHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    desktopSearch.activate(index)
                                    searchOverlay.clearSearch()
                                }
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: desktopSearch.results.length === 0
                        && desktopSearch.query.length > 0
                text: "No matches for \"" + desktopSearch.query + "\""
                color: "#6F7682"
                font.pixelSize: 10
            }
        }
    }

    /* ---------------- desktop group view ---------------- */
    Item {
        id: groupOverlay
        anchors.fill: parent
        z: 48
        visible: root.groupOpen

        Shortcut {
            sequence: "Escape"
            onActivated: if (root.groupOpen) root.closeGroup()
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeGroup()
        }

        Rectangle {
            anchors.centerIn: parent
            width: 760
            height: 480
            radius: 18
            color: "#FA101017"
            border.width: 1
            border.color: "#33FFFFFF"
            clip: true

            MouseArea { anchors.fill: parent }

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Row {
                    width: parent.width
                    height: 40
                    spacing: 8

                    Column {
                        width: parent.width - 200 - 130 - 70 - 30
                        spacing: 1
                        Text {
                            text: root.tr("GROUP")
                            color: "#6F7682"
                            font.pixelSize: 9
                            font.letterSpacing: 1.2
                        }
                        Text {
                            width: parent.width
                            text: root.groupTitle
                            color: "#F2F4F8"
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        width: 200
                        height: 32
                        radius: 9
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#16FFFFFF"
                        border.width: 1
                        border.color: groupSearch.activeFocus ? "#554CC2FF" : "#22FFFFFF"

                        TextField {
                            id: groupSearch
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            placeholderText: root.tr("Search in group…")
                            color: "#F2F4F8"
                            placeholderTextColor: "#7C8492"
                            background: null
                            font.pixelSize: 10
                            onTextChanged: root.groupFilter = text
                            Keys.onEscapePressed: root.closeGroup()
                        }
                    }

                    Rectangle {
                        width: 130
                        height: 32
                        radius: 9
                        anchors.verticalCenter: parent.verticalCenter
                        color: explorerHover.hovered ? "#22FFFFFF" : "#16FFFFFF"

                        Text {
                            anchors.centerIn: parent
                            text: root.tr("Open in Explorer")
                            color: "#E9ECF2"
                            font.pixelSize: 9
                        }
                        HoverHandler { id: explorerHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                desktopModel.launch(root.groupIndex)
                                root.closeGroup()
                            }
                        }
                    }

                    Rectangle {
                        width: 70
                        height: 32
                        radius: 9
                        anchors.verticalCenter: parent.verticalCenter
                        color: groupCloseHover.hovered ? "#22FFFFFF" : "#16FFFFFF"

                        Text {
                            anchors.centerIn: parent
                            text: root.tr("Close")
                            color: "#E9ECF2"
                            font.pixelSize: 9
                        }
                        HoverHandler { id: groupCloseHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeGroup()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#22FFFFFF"
                }

                Flickable {
                    width: parent.width
                    height: parent.height - 40 - 12 - 1 - 24
                    clip: true
                    contentWidth: width
                    contentHeight: groupGrid.height

                    Grid {
                        id: groupGrid
                        width: parent.width
                        columns: 5
                        spacing: 8

                        Repeater {
                            model: root.filteredGroupEntries()

                            delegate: Item {
                                required property var modelData

                                width: (groupGrid.width - groupGrid.spacing * 4) / 5
                                height: 110

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 12
                                    color: groupTileHover.hovered ? "#1A2A3945" : "transparent"
                                    border.width: groupTileHover.hovered ? 1 : 0
                                    border.color: "#334CC2FF"
                                }

                                Rectangle {
                                    id: groupIconFallback
                                    width: 48
                                    height: 48
                                    radius: 12
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top
                                    anchors.topMargin: 10
                                    color: "#2A2A33"
                                    visible: groupIcon.status !== Image.Ready

                                    Text {
                                        anchors.centerIn: parent
                                        text: (modelData.name || "?").charAt(0).toUpperCase()
                                        color: "#9AA1AC"
                                        font.pixelSize: 18
                                        font.weight: Font.DemiBold
                                    }
                                }

                                Image {
                                    id: groupIcon
                                    width: 48
                                    height: 48
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top
                                    anchors.topMargin: 10
                                    source: modelData.icon !== undefined ? modelData.icon : ""
                                    fillMode: Image.PreserveAspectFit
                                    visible: status === Image.Ready
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 8
                                    width: parent.width - 12
                                    text: modelData.name
                                    color: "#E9ECF2"
                                    font.pixelSize: 9
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }

                                HoverHandler { id: groupTileHover }
                                ToolTip.visible: groupTileHover.hovered
                                ToolTip.text: modelData.name
                                ToolTip.delay: 300

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        desktopModel.launchEntry(modelData.path)
                                        root.closeGroup()
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: root.filteredGroupEntries().length === 0
                    text: root.groupFilter.length > 0
                          ? root.tr("No matches in this group")
                          : root.tr("No applications in this group")
                    color: "#6F7682"
                    font.pixelSize: 11
                }
            }
        }
    }

    /* ---------------- context menu, panels and toast ---------------- */
    Item {
        id: overlay
        anchors.fill: parent
        z: 50

        MouseArea {
            anchors.fill: parent
            visible: root.menuOpen
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: root.closeMenu()
        }

        Rectangle {
            visible: root.menuOpen
            x: root.menuX
            y: root.menuY
            width: 240
            height: menuColumn.implicitHeight + 12
            radius: 10
            color: "#FA101017"
            border.width: 1
            border.color: "#33FFFFFF"

            Column {
                id: menuColumn
                anchors.fill: parent
                anchors.margins: 6
                spacing: 1

                MenuItem {
                    label: root.tr("Open")
                    onActivated: {
                        root.closeMenu()
                        desktopModel.launch(root.menuIndex)
                    }
                }
                MenuItem {
                    label: root.tr("Copy")
                    onActivated: {
                        root.closeMenu()
                        desktopModel.copyEntry(root.menuIndex)
                    }
                }
                MenuItem { label: root.tr("Rename…"); onActivated: root.startRename() }
                MenuItem { label: root.tr("Group into folder…"); onActivated: root.startGroup() }
                Rectangle { width: parent.width; height: 1; color: "#22FFFFFF" }
                MenuItem { label: root.tr("Delete"); danger: true; onActivated: root.startDelete() }
                MenuItem { label: root.tr("Properties"); onActivated: root.startProperties() }
                MenuItem {
                    label: root.tr("Uninstall")
                    danger: true
                    visible: !desktopModel.isDirAt(root.menuIndex)
                    onActivated: root.startUninstall()
                }
            }
        }

        Rectangle {
            visible: root.lastMessage.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 118
            width: Math.min(parent.width - 80, toastText.implicitWidth + 36)
            height: 36
            radius: 10
            color: "#E615151C"
            border.width: 1
            border.color: "#33FFFFFF"

            Text {
                id: toastText
                anchors.centerIn: parent
                text: root.lastMessage
                color: "#CFEEDD"
                font.pixelSize: 10
            }
        }

        Item {
            id: panel
            anchors.fill: parent
            visible: root.panelMode.length > 0

            MouseArea {
                anchors.fill: parent
                onClicked: root.closePanel()
            }

            Rectangle {
                anchors.centerIn: parent
                width: 540
                height: root.panelMode === "properties" ? 500 : 236
                radius: 16
                color: "#FA101017"
                border.width: 1
                border.color: "#33FFFFFF"

                MouseArea { anchors.fill: parent }

                Column {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    Text {
                        text: root.panelMode === "rename" ? "RENAME ICON"
                              : (root.panelMode === "group" ? "GROUP INTO FOLDER"
                              : (root.panelMode === "delete" ? "DELETE ICON"
                              : (root.panelMode === "uninstall" ? "UNINSTALL APPLICATION"
                              : "PROPERTIES")))
                        color: "#F2F4F8"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.1
                    }

                    Text {
                        visible: root.panelMode === "delete" || root.panelMode === "uninstall"
                        text: root.panelMode === "delete"
                              ? "Move \"" + (root.propertiesData.name || "") + "\" to the Trash?"
                              : (root.propertiesData.package && root.propertiesData.package.length > 0
                                 ? "Uninstall " + root.propertiesData.package.replace("flatpak:", "flatpak · ")
                                   + "?\n\nThis removes the application from the system."
                                 : "No installed package was found for this shortcut.")
                        color: "#B9C0CA"
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }

                    TextField {
                        id: panelField
                        visible: root.panelMode === "rename" || root.panelMode === "group"
                        width: parent.width
                        height: 32
                        color: "#E9ECF2"
                        font.pixelSize: 11
                        selectByMouse: true
                        leftPadding: 10
                        placeholderText: root.panelMode === "rename"
                                         ? "New name" : "Group folder name"
                        background: Rectangle {
                            radius: 8
                            color: "#22FFFFFF"
                            border.width: 1
                            border.color: "#26FFFFFF"
                        }
                    }

                    Flickable {
                        visible: root.panelMode === "properties"
                        width: parent.width
                        height: 330
                        clip: true
                        contentWidth: width
                        contentHeight: propColumn.height

                        Column {
                            id: propColumn
                            width: parent.width
                            spacing: 8

                            Repeater {
                                model: root.propRows

                                delegate: Row {
                                    required property var modelData
                                    width: propColumn.width

                                    Text {
                                        width: 104
                                        text: modelData.label
                                        color: "#6F7682"
                                        font.pixelSize: 9
                                        wrapMode: Text.Wrap
                                    }
                                    Text {
                                        width: propColumn.width - 112
                                        text: modelData.value
                                        color: "#E9ECF2"
                                        font.pixelSize: 10
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: 8

                        Rectangle {
                            width: 90; height: 32; radius: 9
                            color: closeHover.hovered ? "#22FFFFFF" : "#16FFFFFF"
                            Text {
                                anchors.centerIn: parent
                                text: root.panelMode === "properties" ? "Close" : "Cancel"
                                color: "#E9ECF2"
                                font.pixelSize: 10
                            }
                            HoverHandler { id: closeHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.closePanel()
                            }
                        }

                        Rectangle {
                            width: 110; height: 32; radius: 9
                            visible: root.panelMode !== "properties"
                            color: (root.panelMode === "delete" || root.panelMode === "uninstall")
                                   ? (dangerHover.hovered ? "#C42B1C" : "#2A1B1E")
                                   : (actionHover.hovered ? "#2A7ED6A5" : "#193326")
                            border.width: 1
                            border.color: (root.panelMode === "delete" || root.panelMode === "uninstall")
                                          ? "#55FF6B6B" : "#557ED6A5"
                            opacity: enabled ? 1.0 : 0.4
                            enabled: !(root.panelMode === "uninstall"
                                       && (!root.propertiesData.package
                                           || root.propertiesData.package.length === 0))

                            Text {
                                anchors.centerIn: parent
                                text: root.panelMode === "rename" ? "Save"
                                      : (root.panelMode === "group" ? "Group"
                                      : (root.panelMode === "delete" ? "Delete"
                                      : "Uninstall"))
                                color: (root.panelMode === "delete" || root.panelMode === "uninstall")
                                       ? "#FFB4B0" : "#CFEEDD"
                                font.pixelSize: 10
                            }
                            HoverHandler { id: actionHover }
                            HoverHandler { id: dangerHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: parent.enabled
                                onClicked: root.runPanelAction()
                            }
                        }
                    }
                }
            }
        }
    }
}

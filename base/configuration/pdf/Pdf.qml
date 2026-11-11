import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: win
    width: 1120
    height: 610
    minimumWidth: 900
    minimumHeight: 520
    visible: true
    color: "#101016"

    property real zoomFactor: 1.0
    property bool autoFit: true

    title: "PDF Reader"

    Component.onCompleted: {
        win.requestActivate()
        Qt.callLater(function () { win.requestActivate() })
    }

    Connections {
        target: pdf
        function onPageChanged() {
            pageField.text = pdf.page
            viewer.contentX = 0
            viewer.contentY = 0
        }
        function onDocumentChanged() {
            pageField.text = pdf.page
            win.autoFit = true
            win.zoomFactor = 1.0
            viewer.contentX = 0
            viewer.contentY = 0
        }
    }

    Shortcut { sequence: "Left"; onActivated: pdf.previousPage() }
    Shortcut { sequence: "Right"; onActivated: pdf.nextPage() }
    Shortcut { sequence: "Home"; onActivated: pdf.goToPage(1) }
    Shortcut { sequence: "End"; onActivated: pdf.goToPage(pdf.pageCount) }
    Shortcut { sequence: "Ctrl+O"; onActivated: browser.open() }
    Shortcut { sequence: "Ctrl+Q"; onActivated: Qt.quit() }
    Shortcut { sequence: "Ctrl+W"; onActivated: Qt.quit() }
    Shortcut { sequence: "F5"; onActivated: pdf.reload() }
    Shortcut { sequence: "+"; onActivated: win.zoomIn() }
    Shortcut { sequence: "-"; onActivated: win.zoomOut() }

    function zoomIn() {
        autoFit = false
        zoomFactor = Math.min(3.0, zoomFactor + 0.1)
    }

    function zoomOut() {
        autoFit = false
        zoomFactor = Math.max(0.25, zoomFactor - 0.1)
    }

    function fitWidth() {
        if (pageImage.implicitWidth > 0)
            zoomFactor = Math.max(0.25, Math.min(3.0,
                        (viewer.width - 40) / pageImage.implicitWidth))
    }

    function fitPage() {
        if (pageImage.implicitWidth > 0 && pageImage.implicitHeight > 0) {
            const horizontal = (viewer.width - 40) / pageImage.implicitWidth
            const vertical = (viewer.height - 60) / pageImage.implicitHeight
            zoomFactor = Math.max(0.25, Math.min(3.0,
                        Math.min(horizontal, vertical)))
        }
    }

    /* ---------------- components ---------------- */

    component ActionButton: Rectangle {
        id: button
        property string label: ""
        property string glyph: ""
        property bool active: false
        signal activated()

        width: glyph !== "" && label === "" ? 34
                                            : Math.max(64, labelText.implicitWidth + 26)
        height: 32
        radius: 9
        color: active ? "#20364A" : (buttonHover.hovered ? "#22FFFFFF" : "#16FFFFFF")
        border.width: active ? 1 : 0
        border.color: "#334CC2FF"

        Row {
            anchors.centerIn: parent
            spacing: 5
            Text {
                visible: button.glyph !== ""
                text: button.glyph
                color: button.active ? "#8FD3FF" : "#C3C9D2"
                font.pixelSize: 13
            }
            Text {
                id: labelText
                visible: button.label !== ""
                text: button.label
                color: button.active ? "#8FD3FF" : "#E9ECF2"
                font.pixelSize: 10
            }
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
        property color hoverColor: "#22FFFFFF"
        signal activated()

        width: 30
        height: 30
        radius: 8
        color: wbHover.hovered ? hoverColor : "transparent"

        Text {
            anchors.centerIn: parent
            text: wb.glyph
            color: "#C3C9D2"
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

    component Field: TextField {
        height: 30
        color: "#E9ECF2"
        font.pixelSize: 10
        selectByMouse: true
        horizontalAlignment: TextInput.AlignHCenter
        background: Rectangle {
            radius: 8
            color: "#22FFFFFF"
            border.width: 1
            border.color: "#26FFFFFF"
        }
    }

    /* ---------------- background ---------------- */

    Image {
        anchors.fill: parent
        source: "file:///usr/share/backgrounds/elvonos/wallpaper.png"
        fillMode: Image.PreserveAspectCrop
        opacity: 0.55
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#E615151C" }
            GradientStop { position: 1.0; color: "#F00D0D13" }
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
            color: "#CC1B1B24"
            border.width: 1
            border.color: "#26FFFFFF"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Rectangle {
                    width: 34; height: 34; radius: 10
                    color: "#228FD3FF"
                    border.width: 1
                    border.color: "#558FD3FF"
                    Text { anchors.centerIn: parent; text: "▤"; color: "#8FD3FF"; font.pixelSize: 15 }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        text: "PDF READER"
                        color: "#F2F4F8"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.2
                    }
                    Text {
                        text: pdf.fileName.length > 0
                              ? pdf.fileName + "  ·  " + pdf.pageCount + " pages"
                              : "No document"
                        color: "#7D8490"
                        font.pixelSize: 9
                        elide: Text.ElideRight
                        width: 600
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
                    tip: "Drag to move window"
                    hoverColor: "#18FFFFFF"
                    onActivated: win.startSystemMove()
                }

                Rectangle { width: 1; height: 24; color: "#1EFFFFFF" }

                WindowButton {
                    glyph: "—"
                    tip: "Minimize"
                    onActivated: win.showMinimized()
                }
                WindowButton {
                    glyph: win.visibility === Window.Maximized ? "❐" : "□"
                    tip: win.visibility === Window.Maximized ? "Restore" : "Maximize"
                    onActivated: {
                        if (win.visibility === Window.Maximized)
                            win.showNormal()
                        else
                            win.showMaximized()
                    }
                }
                WindowButton {
                    glyph: "✕"
                    tip: "Close"
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
            color: "#B315151E"
            border.width: 1
            border.color: "#1EFFFFFF"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                ActionButton { label: "Open"; onActivated: browser.open() }

                Rectangle { width: 1; height: 24; color: "#1EFFFFFF" }

                ActionButton { glyph: "◀"; onActivated: pdf.previousPage() }
                Field {
                    id: pageField
                    width: 52
                    text: "1"
                    onAccepted: pdf.goToPage(parseInt(text))
                }
                Text {
                    text: "/ " + pdf.pageCount
                    color: "#7D8490"
                    font.pixelSize: 10
                    anchors.verticalCenter: parent.verticalCenter
                }
                ActionButton { glyph: "▶"; onActivated: pdf.nextPage() }

                Rectangle { width: 1; height: 24; color: "#1EFFFFFF" }

                ActionButton { glyph: "−"; onActivated: win.zoomOut() }
                Text {
                    text: Math.round(win.zoomFactor * 100) + "%"
                    color: "#E9ECF2"
                    font.pixelSize: 10
                    width: 48
                    horizontalAlignment: Text.AlignHCenter
                    anchors.verticalCenter: parent.verticalCenter
                }
                ActionButton { glyph: "+"; onActivated: win.zoomIn() }
                ActionButton { label: "Fit width"; onActivated: { win.autoFit = false; win.fitWidth() } }
                ActionButton { label: "Fit page"; onActivated: { win.autoFit = false; win.fitPage() } }
                ActionButton { label: "Reload"; onActivated: pdf.reload() }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                BusyIndicator {
                    width: 20; height: 20
                    running: pdf.busy
                    visible: pdf.busy
                }
                Text {
                    text: pdf.busy ? "Rendering…" : pdf.status
                    color: pdf.ok ? "#8FD3A8" : "#FFB4B0"
                    font.pixelSize: 9
                    elide: Text.ElideRight
                    width: 280
                    horizontalAlignment: Text.AlignRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        /* ---------------- Viewer ---------------- */
        Rectangle {
            width: parent.width
            height: parent.height - 70 - 52 - 20
            radius: 16
            color: "#0A0A0F"
            border.width: 1
            border.color: "#26FFFFFF"
            clip: true

            Flickable {
                id: viewer
                anchors.fill: parent
                anchors.margins: 10
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: Math.max(width, pageImage.width + 24)
                contentHeight: Math.max(height, pageImage.height + 24)

                Image {
                    id: pageImage
                    source: pdf.renderPath.length > 0
                            ? "file://" + pdf.renderPath + "?v=" + pdf.renderToken
                            : ""
                    width: implicitWidth * win.zoomFactor
                    height: implicitHeight * win.zoomFactor
                    x: Math.max(12, (viewer.width - width) / 2)
                    y: Math.max(12, (viewer.height - height) / 2)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                    smooth: true
                    onStatusChanged: {
                        if (status === Image.Ready && win.autoFit)
                            win.fitPage()
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: pdf.renderPath.length === 0 && !pdf.busy
                    text: "Open a PDF document to start reading"
                    color: "#4E5560"
                    font.pixelSize: 12
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 28
                color: "#9917171E"
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: pdf.filePath.length > 0 ? pdf.filePath : "PDF Reader"
                    color: "#7D8490"
                    font.pixelSize: 9
                    elide: Text.ElideMiddle
                    width: parent.width - 200
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: pdf.pageCount > 0
                          ? "Page " + pdf.page + " / " + pdf.pageCount
                          : ""
                    color: "#8A909B"
                    font.pixelSize: 9
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

        property string currentDir: pdf.documentsPath()
        property string selectedPath: ""
        property var items: []

        function loadDir(path) {
            currentDir = path
            selectedPath = ""
            items = pdf.listDirectory(path)
        }

        onOpened: {
            selectedPath = ""
            loadDir(pdf.documentsPath())
        }

        onAccepted: {
            if (selectedPath.length > 0)
                pdf.open(selectedPath)
        }

        background: Rectangle {
            color: "#15151C"
            radius: 16
            border.width: 1
            border.color: "#33FFFFFF"
        }

        contentItem: Column {
            spacing: 10
            anchors.fill: parent
            anchors.margins: 14

            Text {
                text: "OPEN PDF"
                color: "#F2F4F8"
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2
            }

            Row {
                width: parent.width
                height: 30
                spacing: 8

                ActionButton { label: "↑ Up"; height: 30; onActivated: browser.loadDir(pdf.parentDir(browser.currentDir)) }
                ActionButton { label: "Home"; height: 30; onActivated: browser.loadDir(pdf.homePath()) }
                ActionButton { label: "Documents"; height: 30; onActivated: browser.loadDir(pdf.documentsPath()) }
                ActionButton { label: "Downloads"; height: 30; onActivated: browser.loadDir(pdf.downloadsPath()) }

                Field {
                    width: parent.width - 76 - 70 - 96 - 96 - 40
                    text: browser.currentDir
                    horizontalAlignment: TextInput.AlignLeft
                    onAccepted: browser.loadDir(text)
                }
            }

            Row {
                visible: pdf.recent.length > 0
                width: parent.width
                height: 26
                spacing: 6

                Text {
                    text: "RECENT"
                    color: "#6F7682"
                    font.pixelSize: 8
                    font.letterSpacing: 1.2
                    anchors.verticalCenter: parent.verticalCenter
                }

                Repeater {
                    model: pdf.recent

                    delegate: ActionButton {
                        required property string modelData
                        height: 26
                        width: Math.min(180, label.length * 6 + 20)
                        label: pdf.baseName(modelData).length > 20
                               ? pdf.baseName(modelData).substring(0, 19) + "…"
                               : pdf.baseName(modelData)
                        onActivated: {
                            pdf.open(modelData)
                            browser.reject()
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 320 - (pdf.recent.length > 0 ? 34 : 0)
                radius: 12
                color: "#99101016"
                border.width: 1
                border.color: "#1EFFFFFF"
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
                               ? "#20364A"
                               : (rowHover.hovered ? "#14FFFFFF" : "transparent")

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Rectangle {
                                width: 22; height: 22; radius: 6
                                color: isDir ? "#20364A" : "#1A2430"
                                Text {
                                    anchors.centerIn: parent
                                    text: isDir ? "▸" : "▤"
                                    color: isDir ? "#8FD3FF" : "#B9C0CA"
                                    font.pixelSize: 11
                                }
                            }
                            Text {
                                text: name
                                color: "#E9ECF2"
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
                            color: "#7D8490"
                            font.pixelSize: 9
                        }

                        HoverHandler { id: rowHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: browser.selectedPath = path
                            onDoubleClicked: {
                                if (isDir) {
                                    browser.loadDir(path)
                                } else {
                                    browser.selectedPath = path
                                    browser.accept()
                                }
                            }
                        }
                    }
                }
            }

            Row {
                width: parent.width
                height: 34
                spacing: 8

                Item { width: parent.width - 90 - 110; height: 1 }

                ActionButton {
                    label: "Cancel"
                    width: 90
                    onActivated: browser.reject()
                }
                Rectangle {
                    width: 110
                    height: 32
                    radius: 9
                    color: browser.selectedPath.length > 0
                           ? (acceptHover.hovered ? "#2A7ED6A5" : "#193326")
                           : "#16202A"
                    border.width: 1
                    border.color: "#557ED6A5"
                    opacity: browser.selectedPath.length > 0 ? 1.0 : 0.4
                    Text {
                        anchors.centerIn: parent
                        text: "Open"
                        color: "#CFEEDD"
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

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import ElvonOS.Paint 1.0

ApplicationWindow {
    id: win

    function tr(text) {
        return lang.revision >= 0 ? lang.tr(text) : text
    }
    width: 1120
    height: 610
    visible: true
    title: win.tr("Paint")
    color: theme.background

    property bool typing: saveNameField.activeFocus || textField.activeFocus
                          || renameField.activeFocus || resizeWidth.activeFocus
                          || resizeHeight.activeFocus
    property bool dialogOpen: saveDialog.visible || openDialog.visible
                                || clearDialog.visible || colorDialog.visible
                                || textDialog.visible || renameDialog.visible
                                || resizeDialog.visible
    property string statusMessage: ""
    property var openFiles: []
    property string lastSaved: ""
    property bool openAsLayer: false
    property bool layersTab: false
    property var recentColors: []
    property int renameIndex: -1

    function setTool(tool) {
        paintCanvas.tool = tool
        statusMessage = ""
    }

    function openFileDialog(asLayer) {
        openAsLayer = asLayer === true
        openFiles = paintApi.pictures()
        openDialog.open()
    }

    function openSaveDialog() {
        saveNameField.text = paintApi.suggestedName()
        saveDialog.open()
    }

    function saveToPictures(name) {
        let file = name.trim()
        if (file.length === 0)
            return
        if (file.indexOf(".") < 0)
            file += saveFormatBox.currentIndex === 1 ? ".jpg" : ".png"
        const path = paintApi.picturesPath + "/" + file
        if (paintCanvas.save(path)) {
            lastSaved = path
            statusMessage = win.tr("Saved to ") + path
        } else {
            statusMessage = win.tr("Could not save the image.")
        }
        statusTimer.restart()
    }

    function pushRecent(value) {
        for (let i = 0; i < recentColors.length; ++i) {
            if (Qt.colorEqual(recentColors[i], value))
                return
        }
        recentColors = [value].concat(recentColors).slice(0, 8)
    }

    Component.onCompleted: {
        win.requestActivate()
        Qt.callLater(function () { win.requestActivate() })
    }

    Timer {
        id: statusTimer
        interval: 4500
        onTriggered: win.statusMessage = ""
    }

    Connections {
        target: paintCanvas
        function onSaved(path) {
            win.lastSaved = path
            win.statusMessage = win.tr("Saved to ") + path
            statusTimer.restart()
        }
        function onLoaded(path) {
            win.statusMessage = win.tr("Opened ") + path
            statusTimer.restart()
        }
        function onColorChanged() {
            win.pushRecent(paintCanvas.color)
        }
        function onTextRequested(x, y) {
            textField.text = ""
            textDialog.open()
        }
    }

    Shortcut { sequence: "Ctrl+Z"; onActivated: paintCanvas.undo() }
    Shortcut { sequence: "Ctrl+Shift+Z"; onActivated: paintCanvas.redo() }
    Shortcut { sequence: "Ctrl+Y"; onActivated: paintCanvas.redo() }
    Shortcut { sequence: "Ctrl+S"; enabled: !win.typing; onActivated: paintCanvas.save("") }
    Shortcut { sequence: "Ctrl+Shift+S"; enabled: !win.typing; onActivated: win.openSaveDialog() }
    Shortcut { sequence: "Ctrl+O"; enabled: !win.typing; onActivated: win.openFileDialog(false) }
    Shortcut { sequence: "Ctrl+Shift+N"; enabled: !win.typing; onActivated: paintCanvas.addLayer() }
    Shortcut { sequence: "Ctrl+Shift+D"; enabled: !win.typing; onActivated: paintCanvas.duplicateLayer() }
    Shortcut { sequence: "Ctrl+Shift+L"; enabled: !win.typing; onActivated: win.layersTab = !win.layersTab }
    Shortcut { sequence: "Ctrl+Q"; onActivated: paintApi.quit() }
    Shortcut { sequence: "Ctrl+W"; onActivated: paintApi.quit() }
    Shortcut { sequence: "Ctrl+M"; onActivated: win.showMinimized() }
    Shortcut { sequence: "Escape"; enabled: !win.dialogOpen; onActivated: win.statusMessage = "" }
    Shortcut { sequence: "B"; enabled: !win.typing && !win.dialogOpen; onActivated: win.setTool("brush") }
    Shortcut { sequence: "E"; enabled: !win.typing && !win.dialogOpen; onActivated: win.setTool("eraser") }
    Shortcut { sequence: "L"; enabled: !win.typing && !win.dialogOpen; onActivated: win.setTool("line") }
    Shortcut { sequence: "R"; enabled: !win.typing && !win.dialogOpen; onActivated: win.setTool("rectangle") }
    Shortcut { sequence: "O"; enabled: !win.typing && !win.dialogOpen; onActivated: win.setTool("ellipse") }
    Shortcut { sequence: "F"; enabled: !win.typing && !win.dialogOpen; onActivated: win.setTool("fill") }
    Shortcut { sequence: "I"; enabled: !win.typing && !win.dialogOpen; onActivated: win.setTool("eyedropper") }
    Shortcut { sequence: "T"; enabled: !win.typing && !win.dialogOpen; onActivated: win.setTool("text") }
    Shortcut { sequence: "Ctrl+0"; enabled: !win.typing; onActivated: paintCanvas.resetView() }
    Shortcut { sequence: "Ctrl+Alt+R"; enabled: !win.typing; onActivated: paintCanvas.rotateCanvas() }
    Shortcut { sequence: "Ctrl+Shift+H"; enabled: !win.typing; onActivated: paintCanvas.flipHorizontal() }
    Shortcut { sequence: "Ctrl+Shift+V"; enabled: !win.typing; onActivated: paintCanvas.flipVertical() }

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
                            color: Qt.rgba(theme.accent2.r, theme.accent2.g, theme.accent2.b, 0.13)
                            border.width: 1
                            border.color: Qt.rgba(theme.accent2.r, theme.accent2.g, theme.accent2.b, 0.33)
                            Text { anchors.centerIn: parent; text: "✎"; color: theme.light ? "#9A5B00" : "#FFC46B"; font.pixelSize: 15 }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: win.tr("PAINT"); color: theme.text; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1.2 }
                            Text { text: win.tr("Canvas & shapes"); color: theme.muted; font.pixelSize: 9 }
                        }
                    }

                    Row {
                        spacing: 6
                        leftPadding: 6
                        topPadding: 8
                        bottomPadding: 2

                        Rectangle {
                            width: 102; height: 26; radius: 8
                            color: !win.layersTab ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14) : tabTools.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086) : "transparent"
                            border.width: !win.layersTab ? 1 : 0
                            border.color: Qt.rgba(theme.accent2.r, theme.accent2.g, theme.accent2.b, 0.33)
                            Text { anchors.centerIn: parent; text: win.tr("Tools"); color: !win.layersTab ? theme.text : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.75); font.pixelSize: 10 }
                            HoverHandler { id: tabTools }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.layersTab = false }
                        }

                        Rectangle {
                            width: 102; height: 26; radius: 8
                            color: win.layersTab ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14) : tabLayers.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086) : "transparent"
                            border.width: win.layersTab ? 1 : 0
                            border.color: Qt.rgba(theme.accent2.r, theme.accent2.g, theme.accent2.b, 0.33)
                            Text {
                                anchors.centerIn: parent
                                text: win.tr("Layers (") + paintCanvas.layerCount + ")"
                                color: win.layersTab ? theme.text : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.75)
                                font.pixelSize: 10
                            }
                            HoverHandler { id: tabLayers }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.layersTab = true }
                        }
                    }

                    Text {
                        text: win.tr("TOOLS")
                        visible: !win.layersTab
                        color: theme.muted
                        font.pixelSize: 9
                        font.letterSpacing: 1.5
                        leftPadding: 10
                        topPadding: 8
                        bottomPadding: 4
                    }

                    Grid {
                        columns: 2
                        visible: !win.layersTab
                        spacing: 4
                        leftPadding: 6

                        Repeater {
                            model: [
                                { id: "brush", label: win.tr("Brush"), glyph: "✎" },
                                { id: "eraser", label: win.tr("Eraser"), glyph: "⌫" },
                                { id: "line", label: win.tr("Line"), glyph: "╱" },
                                { id: "rectangle", label: win.tr("Rectangle"), glyph: "▭" },
                                { id: "ellipse", label: win.tr("Ellipse"), glyph: "◯" },
                                { id: "fill", label: win.tr("Fill"), glyph: "▨" },
                                { id: "eyedropper", label: win.tr("Picker"), glyph: "⊙" },
                                { id: "text", label: win.tr("Text"), glyph: win.tr("T") }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                width: 104
                                height: 30
                                radius: 9
                                color: paintCanvas.tool === modelData.id ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14)
                                       : toolHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086) : "transparent"
                                border.width: paintCanvas.tool === modelData.id ? 1 : 0
                                border.color: Qt.rgba(theme.accent2.r, theme.accent2.g, theme.accent2.b, 0.33)

                                Behavior on color { ColorAnimation { duration: 100 } }

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6
                                    Text {
                                        width: 16
                                        text: modelData.glyph
                                        color: paintCanvas.tool === modelData.id ? theme.light ? "#9A5B00" : "#FFC46B" : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.75)
                                        font.pixelSize: 13
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    Text {
                                        width: 72
                                        text: modelData.label
                                        color: paintCanvas.tool === modelData.id ? theme.text : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.85)
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }
                                }

                                HoverHandler { id: toolHover }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.setTool(modelData.id)
                                }
                            }
                        }
                    }

                    Text {
                        text: win.tr("COLOR")
                        visible: !win.layersTab
                        color: theme.muted
                        font.pixelSize: 9
                        font.letterSpacing: 1.5
                        leftPadding: 10
                        topPadding: 8
                        bottomPadding: 5
                    }

                    Grid {
                        columns: 6
                        visible: !win.layersTab
                        spacing: 6
                        leftPadding: 8

                        Repeater {
                            model: [theme.surface, theme.text, "#FF5A5E", "#FFA24C", "#FFD84C", theme.light ? "#1E7A4D" : "#7ED6A5",
                                    theme.accent2, "#6C8CFF", theme.accent2, "#FF7AD9", "#8A5A3C", Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.68)]

                            delegate: Rectangle {
                                required property string modelData
                                width: 22; height: 22; radius: 11
                                color: modelData
                                border.width: Qt.colorEqual(paintCanvas.color, modelData) ? 2 : 1
                                border.color: Qt.colorEqual(paintCanvas.color, modelData) ? theme.light ? "#9A5B00" : "#FFC46B" : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.20)

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: paintCanvas.color = modelData
                                }
                            }
                        }

                        Rectangle {
                            width: 22; height: 22; radius: 11
                            color: paintCanvas.color
                            border.width: 2
                            border.color: theme.light ? "#9A5B00" : "#FFC46B"

                            Text {
                                anchors.centerIn: parent
                                text: "+"
                                color: theme.text
                                font.pixelSize: 14
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: colorDialog.open()
                            }
                        }
                    }

                    Row {
                        visible: !win.layersTab && win.recentColors.length > 0
                        leftPadding: 8
                        spacing: 4

                        Repeater {
                            model: win.recentColors

                            delegate: Rectangle {
                                required property var modelData
                                width: 18; height: 18; radius: 9
                                color: modelData
                                border.width: 1
                                border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.20)

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: paintCanvas.color = modelData
                                }
                            }
                        }
                    }

                    Text {
                        text: win.tr("BRUSH SIZE")
                        visible: !win.layersTab
                        color: theme.muted
                        font.pixelSize: 9
                        font.letterSpacing: 1.5
                        leftPadding: 10
                        topPadding: 8
                        bottomPadding: 4
                    }

                    Row {
                        visible: !win.layersTab
                        leftPadding: 8
                        spacing: 8

                        Slider {
                            id: sizeSlider
                            width: 150
                            from: 1
                            to: 60
                            value: paintCanvas.brushSize
                            onMoved: paintCanvas.brushSize = Math.round(value)
                        }

                        Rectangle {
                            width: 26; height: 26; radius: 13
                            color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.06)
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.min(20, paintCanvas.brushSize)
                                height: width
                                radius: width / 2
                                color: paintCanvas.tool === "eraser" ? theme.text : paintCanvas.color
                                border.width: 1
                                border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.33)
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: paintCanvas.brushSize + win.tr(" px")
                            color: theme.muted
                            font.pixelSize: 9
                        }
                    }

                    Rectangle {
                        width: 210; height: 24; radius: 9
                        visible: !win.layersTab
                        x: 8
                        color: paintCanvas.shapeFill ? theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.14) : "#193326" : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.06)
                        border.width: 1
                        border.color: paintCanvas.shapeFill ? "#337ED6A5" : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            Text {
                                text: paintCanvas.shapeFill ? "◉" : "○"
                                color: paintCanvas.shapeFill ? theme.light ? "#1E7A4D" : "#7ED6A5" : Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.85)
                                font.pixelSize: 12
                            }
                            Text {
                                text: win.tr("Filled shapes")
                                color: paintCanvas.shapeFill ? theme.light ? "#1E6B45" : "#B7E8C9" : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.75)
                                font.pixelSize: 10
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: paintCanvas.shapeFill = !paintCanvas.shapeFill
                        }
                    }

                    Text {
                        text: win.tr("ACTIONS")
                        visible: !win.layersTab
                        color: theme.muted
                        font.pixelSize: 9
                        font.letterSpacing: 1.5
                        leftPadding: 10
                        topPadding: 8
                        bottomPadding: 5
                    }

                    Grid {
                        columns: 3
                        visible: !win.layersTab
                        spacing: 6
                        leftPadding: 8

                        Rectangle {
                            width: 66; height: 30; radius: 9
                            color: (paintCanvas.canUndo && undoHover.hovered) ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086)
                            opacity: paintCanvas.canUndo ? 1.0 : 0.4
                            Text { anchors.centerIn: parent; text: win.tr("Undo"); color: theme.text; font.pixelSize: 9 }
                            HoverHandler { id: undoHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: paintCanvas.canUndo
                                onClicked: paintCanvas.undo()
                            }
                        }

                        Rectangle {
                            width: 66; height: 30; radius: 9
                            color: (paintCanvas.canRedo && redoHover.hovered) ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086)
                            opacity: paintCanvas.canRedo ? 1.0 : 0.4
                            Text { anchors.centerIn: parent; text: win.tr("Redo"); color: theme.text; font.pixelSize: 9 }
                            HoverHandler { id: redoHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: paintCanvas.canRedo
                                onClicked: paintCanvas.redo()
                            }
                        }

                        Rectangle {
                            width: 66; height: 30; radius: 9
                            color: clearHover.hovered ? "#C42B1C" : theme.light ? Qt.rgba(0.70, 0.15, 0.12, 0.18) : "#3A1E1E"
                            border.width: 1
                            border.color: "#66FF8A80"
                            Text { anchors.centerIn: parent; text: win.tr("Clear"); color: theme.light ? "#B3261E" : "#FFB4B0"; font.pixelSize: 9 }
                            HoverHandler { id: clearHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: clearDialog.open()
                            }
                        }

                        Rectangle {
                            width: 66; height: 30; radius: 9
                            color: openHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086)
                            Text { anchors.centerIn: parent; text: win.tr("Open"); color: theme.text; font.pixelSize: 9 }
                            HoverHandler { id: openHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.openFileDialog(false)
                            }
                        }

                        Rectangle {
                            width: 66; height: 30; radius: 9
                            color: saveHover.hovered ? theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.14) : "#193326" : theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.20) : "#163326"
                            border.width: 1
                            border.color: "#337ED6A5"
                            Text { anchors.centerIn: parent; text: win.tr("Save"); color: theme.light ? "#1E7A4D" : "#7ED6A5"; font.pixelSize: 9 }
                            HoverHandler { id: saveHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: paintCanvas.save("")
                            }
                        }

                        Rectangle {
                            width: 66; height: 30; radius: 9
                            color: saveAsHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086) : "transparent"
                            border.width: 1
                            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14)
                            Text { anchors.centerIn: parent; text: win.tr("Save as"); color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.85); font.pixelSize: 9 }
                            HoverHandler { id: saveAsHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.openSaveDialog()
                            }
                        }
                    }

                    Text {
                        text: win.tr("LAYERS")
                        visible: win.layersTab
                        color: theme.muted
                        font.pixelSize: 9
                        font.letterSpacing: 1.5
                        leftPadding: 10
                        topPadding: 8
                        bottomPadding: 5
                    }

                    Row {
                        visible: win.layersTab
                        leftPadding: 8
                        spacing: 4

                        Repeater {
                            model: [
                                { glyph: "+", tip: win.tr("New layer"), action: win.tr("add") },
                                { glyph: "⧉", tip: win.tr("Duplicate layer"), action: win.tr("duplicate") },
                                { glyph: "⌫", tip: win.tr("Delete layer"), action: win.tr("remove") },
                                { glyph: "↑", tip: win.tr("Move layer up"), action: win.tr("up") },
                                { glyph: "↓", tip: win.tr("Move layer down"), action: win.tr("down") },
                                { glyph: "▣", tip: win.tr("Add image as layer"), action: win.tr("image") }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                width: 32; height: 28; radius: 8
                                color: layerActHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.07)

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.glyph
                                    color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.85)
                                    font.pixelSize: 12
                                }

                                HoverHandler { id: layerActHover }
                                ToolTip.visible: layerActHover.hovered
                                ToolTip.text: modelData.tip
                                ToolTip.delay: 300
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.action === "add")
                                            paintCanvas.addLayer()
                                        else if (modelData.action === "duplicate")
                                            paintCanvas.duplicateLayer()
                                        else if (modelData.action === "remove")
                                            paintCanvas.removeLayer()
                                        else if (modelData.action === "up")
                                            paintCanvas.moveLayerUp()
                                        else if (modelData.action === "down")
                                            paintCanvas.moveLayerDown()
                                        else
                                            win.openFileDialog(true)
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        width: 224
                        visible: win.layersTab
                        leftPadding: 8
                        topPadding: 6
                        spacing: 3

                        Repeater {
                            model: paintCanvas.layerList

                            delegate: Rectangle {
                                required property var modelData
                                width: 208
                                height: 30
                                radius: 8
                                color: modelData.active ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14)
                                       : layerRowHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.04)
                                border.width: modelData.active ? 1 : 0
                                border.color: Qt.rgba(theme.accent2.r, theme.accent2.g, theme.accent2.b, 0.33)

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: paintCanvas.setActiveLayer(modelData.index)
                                }

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    Rectangle {
                                        width: 20; height: 20; radius: 6
                                        color: eyeHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.visible ? "●" : "○"
                                            color: modelData.visible ? theme.light ? "#1E7A4D" : "#7ED6A5" : Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.70)
                                            font.pixelSize: 10
                                        }

                                        HoverHandler { id: eyeHover }
                                        ToolTip.visible: eyeHover.hovered
                                        ToolTip.text: modelData.visible ? win.tr("Hide layer") : win.tr("Show layer")
                                        ToolTip.delay: 300
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: paintCanvas.toggleLayerVisible(modelData.index)
                                        }
                                    }

                                    Text {
                                        id: layerNameText
                                        width: 132
                                        text: modelData.name
                                        color: modelData.active ? theme.text : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.85)
                                        font.pixelSize: 10
                                        elide: Text.ElideRight

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: paintCanvas.setActiveLayer(modelData.index)
                                            onDoubleClicked: {
                                                win.renameIndex = modelData.index
                                                renameField.text = modelData.name
                                                renameDialog.open()
                                            }
                                        }
                                    }

                                    Text {
                                        text: Math.round(modelData.opacity * 100) + "%"
                                        color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90)
                                        font.pixelSize: 9
                                    }
                                }

                                HoverHandler { id: layerRowHover }
                            }
                        }
                    }

                    Row {
                        visible: win.layersTab
                        leftPadding: 8
                        topPadding: 4
                        spacing: 8

                        Slider {
                            width: 150
                            from: 0
                            to: 100
                            value: paintCanvas.layerOpacity * 100
                            onMoved: paintCanvas.layerOpacity = value / 100
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(paintCanvas.layerOpacity * 100) + "%"
                            color: theme.muted
                            font.pixelSize: 9
                        }
                    }

                    Text {
                        text: win.tr("CANVAS")
                        visible: win.layersTab
                        color: theme.muted
                        font.pixelSize: 9
                        font.letterSpacing: 1.5
                        leftPadding: 10
                        topPadding: 10
                        bottomPadding: 5
                    }

                    Grid {
                        columns: 2
                        visible: win.layersTab
                        spacing: 6
                        leftPadding: 8

                        Rectangle {
                            width: 103; height: 28; radius: 8
                            color: rotateHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086)
                            Text { anchors.centerIn: parent; text: win.tr("Rotate 90°"); color: theme.text; font.pixelSize: 9 }
                            HoverHandler { id: rotateHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: paintCanvas.rotateCanvas()
                            }
                        }

                        Rectangle {
                            width: 103; height: 28; radius: 8
                            color: flipHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086)
                            Text { anchors.centerIn: parent; text: win.tr("Flip H"); color: theme.text; font.pixelSize: 9 }
                            HoverHandler { id: flipHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: paintCanvas.flipHorizontal()
                            }
                        }

                        Rectangle {
                            width: 103; height: 28; radius: 8
                            color: flipVHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086)
                            Text { anchors.centerIn: parent; text: win.tr("Flip V"); color: theme.text; font.pixelSize: 9 }
                            HoverHandler { id: flipVHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: paintCanvas.flipVertical()
                            }
                        }

                        Rectangle {
                            width: 103; height: 28; radius: 8
                            color: resizeHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086)
                            Text { anchors.centerIn: parent; text: win.tr("Resize…"); color: theme.text; font.pixelSize: 9 }
                            HoverHandler { id: resizeHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    resizeWidth.text = paintCanvas.imageWidth
                                    resizeHeight.text = paintCanvas.imageHeight
                                    resizeDialog.open()
                                }
                            }
                        }
                    }
                }
            }
        }

        /* ---------------- Canvas ---------------- */
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
                    spacing: 10

                    Rectangle {
                        width: 32; height: 32; radius: 9
                        color: Qt.rgba(theme.accent2.r, theme.accent2.g, theme.accent2.b, 0.13)
                        border.width: 1
                        border.color: Qt.rgba(theme.accent2.r, theme.accent2.g, theme.accent2.b, 0.33)
                        Text { anchors.centerIn: parent; text: "✎"; color: theme.light ? "#9A5B00" : "#FFC46B"; font.pixelSize: 15 }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: win.tr("PAINT"); color: theme.text; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1.2 }
                        Text {
                            text: paintCanvas.dirty ? win.tr("Unsaved changes") : (win.lastSaved.length > 0 ? win.lastSaved : win.tr("New canvas"))
                            color: paintCanvas.dirty ? theme.light ? "#8A6A00" : "#F5D67B" : theme.muted
                            font.pixelSize: 9
                            elide: Text.ElideMiddle
                            width: 330
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
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: paintApi.quit() }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: parent.height - 70 - 12
                radius: 18
                color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.92)
                border.width: 1
                border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14)
                clip: true

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: canvasStatus.top
                    anchors.margins: 14
                    radius: 8
                    color: theme.surface
                    border.width: 1
                    border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.20)
                    clip: true

                    PaintCanvas {
                        id: paintCanvas
                        anchors.fill: parent
                        backgroundColor: theme.surface
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 8
                        height: 22
                        width: toolHint.width + 16
                        radius: 7
                        color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.53)
                        Text {
                            id: toolHint
                            anchors.centerIn: parent
                            text: paintCanvas.tool.charAt(0).toUpperCase() + paintCanvas.tool.slice(1)
                                  + " · " + paintCanvas.brushSize + win.tr(" px")
                            color: theme.text
                            font.pixelSize: 9
                        }
                    }
                }

                Rectangle {
                    id: canvasStatus
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 34
                    color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.60)

                    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12) }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.right: zoomRow.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.statusMessage.length > 0
                              ? win.statusMessage
                              : paintCanvas.imageWidth + " × " + paintCanvas.imageHeight
                                + "  ·  " + paintCanvas.tool
                                + "  ·  " + paintCanvas.brushSize + win.tr(" px")
                                + "  ·  " + paintCanvas.cursorX + ", " + paintCanvas.cursorY
                        color: win.statusMessage.length > 0 ? theme.light ? "#2E8B57" : "#8FD3A8" : theme.muted
                        font.pixelSize: 10
                        elide: Text.ElideMiddle
                    }

                    Row {
                        id: zoomRow
                        anchors.right: statusRight.left
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5

                        Rectangle {
                            width: 24; height: 22; radius: 7
                            color: zoomOutHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086)
                            Text { anchors.centerIn: parent; text: "−"; color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.85); font.pixelSize: 12 }
                            HoverHandler { id: zoomOutHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: paintCanvas.zoomOut()
                            }
                        }

                        Text {
                            width: 46
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(paintCanvas.viewZoom * 100) + "%"
                            color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.75)
                            font.pixelSize: 9
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Rectangle {
                            width: 24; height: 22; radius: 7
                            color: zoomInHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086)
                            Text { anchors.centerIn: parent; text: "+"; color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.85); font.pixelSize: 12 }
                            HoverHandler { id: zoomInHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: paintCanvas.zoomIn()
                            }
                        }

                        Rectangle {
                            width: 34; height: 22; radius: 7
                            color: fitHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086)
                            Text { anchors.centerIn: parent; text: win.tr("Fit"); color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.85); font.pixelSize: 9 }
                            HoverHandler { id: fitHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: paintCanvas.resetView()
                            }
                        }
                    }

                    Text {
                        id: statusRight
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: paintCanvas.dirty ? win.tr("Unsaved") : win.tr("Saved")
                        color: paintCanvas.dirty ? theme.light ? "#8A6A00" : "#F5D67B" : theme.light ? "#1E7A4D" : "#7ED6A5"
                        font.pixelSize: 10
                    }
                }
            }
        }
    }

    ColorDialog {
        id: colorDialog
        title: win.tr("Pick a color")
        onAccepted: paintCanvas.color = selectedColor
    }

    Dialog {
        id: saveDialog
        modal: true
        anchors.centerIn: Overlay.overlay
        width: 440
        title: win.tr("Save image")
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: win.saveToPictures(saveNameField.text)
        onOpened: {
            saveNameField.forceActiveFocus()
            saveNameField.selectAll()
        }
        background: Rectangle { color: theme.surface; radius: 16; border.width: 1; border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.20) }
        contentItem: Column {
            width: 380
            spacing: 8
            Text { text: win.tr("Folder: ") + paintApi.picturesPath; color: theme.muted; font.pixelSize: 10 }
            TextField {
                id: saveNameField
                width: parent.width
                height: 36
                color: theme.text
                placeholderText: win.tr("File name (without extension)")
                onAccepted: saveDialog.accept()
                background: Rectangle { color: theme.surface; radius: 8; border.width: 1; border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) }
            }
            Row {
                spacing: 8
                Text { text: win.tr("Format"); color: theme.muted; font.pixelSize: 10; width: 60; anchors.verticalCenter: parent.verticalCenter }
                ComboBox {
                    id: saveFormatBox
                    width: 130
                    height: 32
                    model: ["PNG", "JPEG"]
                    font.pixelSize: 10
                    background: Rectangle { color: theme.surface; radius: 8; border.width: 1; border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) }
                    contentItem: Text {
                        leftPadding: 10
                        text: saveFormatBox.currentText
                        color: theme.text
                        font.pixelSize: 10
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                Text { text: win.tr("Quick save (Ctrl+S) always writes PNG."); color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.70); font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    Dialog {
        id: openDialog
        modal: true
        anchors.centerIn: Overlay.overlay
        width: 560
        height: 440
        title: win.tr("Open image")
        standardButtons: Dialog.Cancel
        background: Rectangle { color: theme.surface; radius: 16; border.width: 1; border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.20) }
        contentItem: ListView {
            clip: true
            model: win.openFiles
            spacing: 4

            delegate: Rectangle {
                required property string modelData
                width: ListView.view ? ListView.view.width : 500
                height: 58
                radius: 9
                color: fileHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086) : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Rectangle {
                        width: 46; height: 46; radius: 7
                        color: theme.surface
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: "file://" + modelData.replace(/ /g, "%20")
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 120
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: modelData.split("/").pop()
                            color: theme.text
                            font.pixelSize: 11
                        }
                        Text {
                            text: modelData
                            color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90)
                            font.pixelSize: 9
                            elide: Text.ElideMiddle
                            width: 430
                        }
                    }
                }

                HoverHandler { id: fileHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (win.openAsLayer)
                            paintCanvas.addImageLayer(modelData)
                        else
                            paintCanvas.load(modelData)
                        openDialog.close()
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                visible: win.openFiles.length === 0
                Text {
                    text: win.tr("No images in ~/Pictures")
                    color: theme.muted
                    font.pixelSize: 12
                }
            }
        }
    }

    Dialog {
        id: clearDialog
        modal: true
        anchors.centerIn: Overlay.overlay
        width: 420
        title: win.tr("Clear canvas")
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: paintCanvas.clearCanvas()
        background: Rectangle { color: theme.surface; radius: 16; border.width: 1; border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.20) }
        contentItem: Text {
            text: win.tr("Clear the whole canvas? Undo is available afterwards.")
            color: theme.text
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
    }

    Dialog {
        id: textDialog
        modal: true
        anchors.centerIn: Overlay.overlay
        width: 420
        title: win.tr("Insert text")
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: paintCanvas.insertText(textField.text)
        onOpened: textField.forceActiveFocus()
        background: Rectangle { color: theme.surface; radius: 16; border.width: 1; border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.20) }
        contentItem: Column {
            width: 370
            spacing: 8
            Text { text: win.tr("Text (size follows the brush size)"); color: theme.muted; font.pixelSize: 10 }
            TextField {
                id: textField
                width: parent.width
                height: 36
                color: theme.text
                placeholderText: win.tr("Hello ElvonOS")
                onAccepted: textDialog.accept()
                background: Rectangle { color: theme.surface; radius: 8; border.width: 1; border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) }
            }
        }
    }

    Dialog {
        id: renameDialog
        modal: true
        anchors.centerIn: Overlay.overlay
        width: 420
        title: win.tr("Rename layer")
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: paintCanvas.renameLayer(win.renameIndex, renameField.text)
        onOpened: {
            renameField.forceActiveFocus()
            renameField.selectAll()
        }
        background: Rectangle { color: theme.surface; radius: 16; border.width: 1; border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.20) }
        contentItem: TextField {
            id: renameField
            width: 370
            height: 36
            color: theme.text
            onAccepted: renameDialog.accept()
            background: Rectangle { color: theme.surface; radius: 8; border.width: 1; border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) }
        }
    }

    Dialog {
        id: resizeDialog
        modal: true
        anchors.centerIn: Overlay.overlay
        width: 420
        title: win.tr("Resize canvas")
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: paintCanvas.resizeCanvas(parseInt(resizeWidth.text), parseInt(resizeHeight.text))
        onOpened: resizeWidth.forceActiveFocus()
        background: Rectangle { color: theme.surface; radius: 16; border.width: 1; border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.20) }
        contentItem: Column {
            width: 370
            spacing: 8
            Row {
                spacing: 10
                Text { text: win.tr("Width"); color: theme.muted; font.pixelSize: 10; width: 60; anchors.verticalCenter: parent.verticalCenter }
                TextField {
                    id: resizeWidth
                    width: 120
                    height: 34
                    color: theme.text
                    inputMethodHints: Qt.ImhDigitsOnly
                    onAccepted: resizeDialog.accept()
                    background: Rectangle { color: theme.surface; radius: 8; border.width: 1; border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) }
                }
                Text { text: win.tr("px"); color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90); font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
            }
            Row {
                spacing: 10
                Text { text: win.tr("Height"); color: theme.muted; font.pixelSize: 10; width: 60; anchors.verticalCenter: parent.verticalCenter }
                TextField {
                    id: resizeHeight
                    width: 120
                    height: 34
                    color: theme.text
                    inputMethodHints: Qt.ImhDigitsOnly
                    onAccepted: resizeDialog.accept()
                    background: Rectangle { color: theme.surface; radius: 8; border.width: 1; border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) }
                }
                Text { text: win.tr("px"); color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90); font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
            }
            Text { text: win.tr("All layers are scaled to the new size."); color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.70); font.pixelSize: 9 }
        }
    }
}

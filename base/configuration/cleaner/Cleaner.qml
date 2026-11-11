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
    title: win.tr("Cleaner")
    color: theme.background

    Component.onCompleted: {
        win.requestActivate()
        Qt.callLater(function () { win.requestActivate() })
    }

    Shortcut { sequence: "F5"; onActivated: cleanerModel.scan() }
    Shortcut { sequence: "Ctrl+Q"; onActivated: Qt.quit() }
    Shortcut { sequence: "Ctrl+W"; onActivated: Qt.quit() }
    Shortcut { sequence: "Ctrl+M"; onActivated: win.showMinimized() }
    Shortcut {
        sequence: "Ctrl+Shift+C"
        enabled: !cleanerModel.busy && cleanerModel.reclaimable > 0
        onActivated: cleanDialog.open()
    }
    Shortcut {
        sequence: "Return"
        enabled: cleanDialog.visible
        onActivated: {
            cleanerModel.cleanSelected()
            cleanDialog.close()
        }
    }

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
                    color: "#227ED6A5"
                    border.width: 1
                    border.color: "#557ED6A5"
                    Text { anchors.centerIn: parent; text: "✦"; color: theme.light ? "#1E7A4D" : "#7ED6A5"; font.pixelSize: 16 }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: win.tr("CLEANER"); color: theme.text; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1.2 }
                    Text { text: win.tr("Free up space"); color: theme.muted; font.pixelSize: 9 }
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
                    ToolTip.text: win.tr("Scan again (F5)")
                    ToolTip.delay: 300
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cleanerModel.scan()
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
                    Text { text: win.tr("SELECTED"); color: theme.muted; font.pixelSize: 9; font.letterSpacing: 1.3 }
                    Text { text: cleanerModel.selectedCount; color: theme.light ? "#1E7A4D" : "#7ED6A5"; font.pixelSize: 18; font.weight: Font.DemiBold }
                    Text { text: win.tr("of ") + cleanerModel.count + win.tr(" categories"); color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90); font.pixelSize: 9 }
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
                    Text { text: win.tr("RECLAIMABLE"); color: theme.muted; font.pixelSize: 9; font.letterSpacing: 1.3 }
                    Text { text: cleanerModel.reclaimableText; color: theme.accent2; font.pixelSize: 18; font.weight: Font.DemiBold }
                    Text { text: win.tr("estimated"); color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90); font.pixelSize: 9 }
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
                    Text { text: win.tr("LAST CLEANED"); color: theme.muted; font.pixelSize: 9; font.letterSpacing: 1.3 }
                    Text {
                        text: cleanerModel.lastFreedText.length > 0 ? cleanerModel.lastFreedText : "—"
                        color: theme.accent2
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                    }
                    Text { text: win.tr("this session"); color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.90); font.pixelSize: 9 }
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

                /* Category list */
                Rectangle {
                    width: 470
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
                            text: win.tr("CATEGORIES")
                            color: theme.muted
                            font.pixelSize: 9
                            font.letterSpacing: 1.3
                        }
                    }

                    ListView {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: listHeader.bottom
                        anchors.bottom: parent.bottom
                        anchors.margins: 6
                        clip: true
                        model: cleanerModel
                        spacing: 4

                        delegate: Rectangle {
                            id: categoryRow
                            required property int index
                            required property string label
                            required property string description
                            required property string sizeText
                            required property bool checked

                            width: ListView.view ? ListView.view.width : 0
                            height: 64
                            radius: 10
                            color: categoryRow.checked ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.10) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.04)
                            border.width: categoryRow.checked ? 1 : 0
                            border.color: "#337ED6A5"

                            Behavior on color { ColorAnimation { duration: 90 } }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                Rectangle {
                                    width: 22; height: 22; radius: 7
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: categoryRow.checked ? "#337ED6A5" : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.06)
                                    border.width: 1
                                    border.color: categoryRow.checked ? theme.light ? "#1E7A4D" : "#7ED6A5" : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.20)
                                    Text {
                                        anchors.centerIn: parent
                                        text: categoryRow.checked ? "✓" : ""
                                        color: theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.08) : "#0E1A14"
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                    }
                                }

                                Column {
                                    width: parent.width - 22 - 10 - 80 - 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text {
                                        text: categoryRow.label
                                        color: theme.text
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                    Text {
                                        text: categoryRow.description
                                        color: theme.muted
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                }

                                Text {
                                    width: 80
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: categoryRow.sizeText
                                    color: categoryRow.checked ? theme.text : Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.85)
                                    font.pixelSize: 11
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            HoverHandler { id: rowHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cleanerModel.setChecked(categoryRow.index, !categoryRow.checked)
                            }
                        }
                    }
                }

                /* Actions + log */
                Column {
                    width: parent.width - 470 - 12
                    height: parent.height
                    spacing: 10

                    Rectangle {
                        width: parent.width
                        height: 96
                        radius: 14
                        color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.40)
                        border.width: 1
                        border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)

                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4
                            Text {
                                text: win.tr("CLEANUP")
                                color: theme.muted
                                font.pixelSize: 9
                                font.letterSpacing: 1.3
                            }
                            Text {
                                text: cleanerModel.selectedCount + win.tr(" categories selected  ·  ")
                                      + cleanerModel.reclaimableText + win.tr(" reclaimable")
                                color: theme.text
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: win.tr("Files are deleted permanently; the Trash and application caches are emptied.")
                                color: theme.muted
                                font.pixelSize: 9
                                width: parent.width
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        height: 34
                        spacing: 8

                        Rectangle {
                            width: 150; height: 34; radius: 9
                            color: (cleanerModel.reclaimable > 0 && !cleanerModel.busy && cleanHover.hovered)
                                   ? "#2A7ED6A5" : theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.14) : "#193326"
                            border.width: 1
                            border.color: "#557ED6A5"
                            opacity: (cleanerModel.reclaimable > 0 && !cleanerModel.busy) ? 1.0 : 0.4
                            Text { anchors.centerIn: parent; text: win.tr("Clean selected"); color: theme.text; font.pixelSize: 10 }
                            HoverHandler { id: cleanHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: cleanerModel.reclaimable > 0 && !cleanerModel.busy
                                onClicked: cleanDialog.open()
                            }
                        }

                        Rectangle {
                            width: 86; height: 34; radius: 9
                            color: rescanHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086)
                            opacity: cleanerModel.busy ? 0.4 : 1.0
                            Text { anchors.centerIn: parent; text: win.tr("Rescan"); color: theme.text; font.pixelSize: 10 }
                            HoverHandler { id: rescanHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: !cleanerModel.busy
                                onClicked: cleanerModel.scan()
                            }
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            visible: cleanerModel.busy
                            BusyIndicator { width: 22; height: 22; running: cleanerModel.busy }
                            Text { text: win.tr("Cleaning…"); color: theme.light ? "#8A6A00" : "#F5D67B"; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: parent.height - 96 - 34 - 20
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
                                text: cleanerModel.output
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
                            visible: cleanerModel.output.length === 0
                            text: win.tr("Select categories and press Clean selected.")
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
                    text: cleanerModel.result.length > 0
                          ? cleanerModel.result
                          : cleanerModel.count + win.tr(" categories  ·  ")
                            + cleanerModel.reclaimableText + win.tr(" selected")
                    color: cleanerModel.result.length > 0
                           ? (cleanerModel.resultOk ? theme.light ? "#2E8B57" : "#8FD3A8" : theme.light ? "#B3261E" : "#FFB4B0")
                           : theme.muted
                    font.pixelSize: 10
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: cleanerModel.busy ? win.tr("Cleaning") : win.tr("Ready")
                    color: cleanerModel.busy ? theme.light ? "#8A6A00" : "#F5D67B" : theme.light ? "#1E7A4D" : "#7ED6A5"
                    font.pixelSize: 10
                }
            }
        }
    }

    Dialog {
        id: cleanDialog
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        width: 460
        title: win.tr("Clean selected categories")
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: cleanerModel.cleanSelected()
        background: Rectangle { color: theme.surface; radius: 16; border.width: 1; border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.20) }
        contentItem: Text {
            text: win.tr("Delete ") + cleanerModel.reclaimableText + win.tr(" in ")
                  + cleanerModel.selectedCount + win.tr(" categories?\n\n")
                  + win.tr("Application caches and the Trash will be emptied. This cannot be undone.")
            color: theme.text
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
    }
}

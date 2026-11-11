import QtQuick
import QtQuick.Controls
import QtQuick.Effects

ApplicationWindow {
    id: root
    visible: false
    width: screen.width
    height: formFactor.dockHeight
    color: "transparent"

    property real dragOffset: 0
    readonly property bool atTop: panelLayout.dockPosition === "top"
    readonly property int dockRadius: Math.max(8, themeSettings.radius + 6)
    readonly property real uiScale: formFactor.scale
    readonly property int itemSize: Math.round(56 * uiScale)
    readonly property int itemIconSize: Math.round(40 * uiScale)

    Behavior on dragOffset {
        enabled: !dockDrag.active
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: dock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: root.atTop ? undefined : parent.bottom
        anchors.top: root.atTop ? parent.top : undefined
        anchors.bottomMargin: root.atTop ? 0 : 10 + root.dragOffset
        anchors.topMargin: root.atTop ? 10 + root.dragOffset : 0
        height: Math.max(56, formFactor.dockHeight - 18)
        width: Math.max(140, Math.min(parent.width - 40, itemsRow.implicitWidth + 28))
        radius: root.dockRadius
        color: "#00000000"
        border.width: 1
        border.color: dropArea.containsDrag
                      ? Qt.rgba(themeSettings.accent.r, themeSettings.accent.g,
                                themeSettings.accent.b, 0.65)
                      : Qt.rgba(themeSettings.border.r, themeSettings.border.g,
                                themeSettings.border.b, 0.32)

        Behavior on border.color { ColorAnimation { duration: 120 } }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 5
            radius: root.dockRadius
            color: Qt.rgba(themeSettings.background.r, themeSettings.background.g,
                           themeSettings.background.b, 0.55)
            z: -1
        }

        Item {
            anchors.fill: parent
            clip: true

            Image {
                id: dockGlass
                anchors.fill: parent
                source: root.atTop
                        ? "file:///usr/share/backgrounds/elvonos/glass-top.png"
                        : "file:///usr/share/backgrounds/elvonos/glass-bottom.png"
                fillMode: Image.Stretch
                visible: false
                layer.enabled: true
            }

            MultiEffect {
                anchors.fill: parent
                source: dockGlass
                opacity: themeSettings.glass / 100 * 0.7
                maskEnabled: true
                maskSource: dockMask
            }

            Rectangle {
                id: dockMask
                anchors.fill: parent
                radius: root.dockRadius
                visible: false
                layer.enabled: true
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: root.dockRadius
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Qt.rgba(themeSettings.surface.r, themeSettings.surface.g,
                                   themeSettings.surface.b, themeSettings.glass / 100)
                }
                GradientStop {
                    position: 1.0
                    color: Qt.rgba(themeSettings.background.r, themeSettings.background.g,
                                   themeSettings.background.b,
                                   Math.min(1, themeSettings.glass / 100 + 0.12))
                }
            }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Qt.rgba(themeSettings.border.r, themeSettings.border.g,
                           themeSettings.border.b, 0.4)
        }

        // Aero-style gloss band
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 22
            radius: root.dockRadius
            color: Qt.rgba(themeSettings.text.r, themeSettings.text.g,
                           themeSettings.text.b, 0.05)
            opacity: 0.9
        }

        DropArea {
            id: dropArea
            anchors.fill: parent
            onDropped: function (drop) {
                for (let i = 0; i < drop.urls.length; ++i)
                    dockModel.addFile(drop.urls[i])
            }
        }

        /* Drag the dock downwards to reveal the desktop (minimise all
         * windows), then it springs back into place. */
        DragHandler {
            id: dockDrag
            xAxis.enabled: false
            grabPermissions: PointerHandler.ApprovesTakeOverByAnything
            onActiveTranslationChanged: {
                if (!dockDrag.active)
                    return
                const delta = root.atTop ? -dockDrag.activeTranslation.y
                                         : dockDrag.activeTranslation.y
                root.dragOffset = Math.max(0, Math.min(70, delta))
            }
            onActiveChanged: {
                if (dockDrag.active)
                    return
                if (root.dragOffset > 26)
                    dockModel.showDesktop()
                root.dragOffset = 0
            }
        }

        Rectangle {
            width: 44
            height: 4
            radius: 2
            color: dockDrag.active
                   ? Qt.rgba(themeSettings.accent2.r, themeSettings.accent2.g,
                             themeSettings.accent2.b, 0.8)
                   : Qt.rgba(themeSettings.text.r, themeSettings.text.g,
                             themeSettings.text.b, 0.25)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 6
        }

        Row {
            id: itemsRow
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                model: dockModel

                delegate: Item {
                    id: dockItem

                    required property int index
                    required property string name
                    required property string icon
                    required property string path

                    width: root.itemSize
                    height: root.itemSize

                    Rectangle {
                        anchors.fill: parent
                        radius: 13
                        color: itemHover.hovered ? "#24FFFFFF" : "transparent"
                        border.width: itemHover.hovered ? 1 : 0
                        border.color: "#33FFFFFF"

                        Behavior on color { ColorAnimation { duration: 110 } }
                    }

                    Rectangle {
                        id: dockFallback
                        width: Math.round(38 * root.uiScale)
                        height: Math.round(38 * root.uiScale)
                        radius: 10
                        color: "#2A2A33"
                        anchors.centerIn: parent
                        visible: dockImage.status !== Image.Ready

                        Text {
                            anchors.centerIn: parent
                            text: (dockItem.name || "?").charAt(0).toUpperCase()
                            color: "#9AA1AC"
                            font.pixelSize: Math.round(15 * root.uiScale)
                            font.weight: Font.DemiBold
                        }
                    }

                    Image {
                        id: dockImage
                        anchors.centerIn: parent
                        width: root.itemIconSize
                        height: root.itemIconSize
                        source: dockItem.icon
                        fillMode: Image.PreserveAspectFit
                        visible: status === Image.Ready
                        scale: itemHover.hovered ? 1.12 : 1

                        Behavior on scale {
                            NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
                        }
                    }

                    HoverHandler {
                        id: itemHover
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function (mouse) {
                            if (mouse.button === Qt.RightButton)
                                dockModel.removeAt(dockItem.index)
                            else
                                dockModel.launch(dockItem.index)
                        }
                    }

                    DragHandler {
                        id: itemDrag
                        target: dockItem
                        grabPermissions: PointerHandler.CanTakeOverFromAnything
                    }
                    Drag.active: itemDrag.active
                    Drag.mimeData: ({ "text/uri-list": "file://" + dockItem.path })
                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.CopyAction
                    Drag.hotSpot: Qt.point(dockItem.width / 2, dockItem.height / 2)

                    ToolTip.visible: itemHover.hovered
                    ToolTip.text: dockItem.name + "\nRight-click to remove · drag down to the desktop"
                    ToolTip.delay: 350
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: dockModel.count === 0
            text: "Drag apps here"
            color: "#6B7280"
            font.pixelSize: 12
        }
    }
}

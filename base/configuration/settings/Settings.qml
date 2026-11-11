import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: root
    width: Math.min(1400, Math.max(1000, screen.width - 120))
    height: Math.min(820, Math.max(560, screen.height - 120))
    minimumWidth: 1000
    minimumHeight: 560
    visible: true
    color: settings.themeBackground

    property color accent: settings.themeAccent
    property color accent2: settings.themeAccent2
    property string backgroundImage: settings.themeWallpaper.length > 0
                                     ? "file://" + settings.themeWallpaper
                                     : "file:///usr/share/backgrounds/elvonos/wallpaper.png"
    property int backgroundFillMode: settings.themeWallpaperFill === "fit"
                                     ? Image.PreserveAspectFit
                                     : settings.themeWallpaperFill === "stretch"
                                       ? Image.Stretch : Image.PreserveAspectCrop
    property color panelColor: settings.themePanel
    property color backgroundColor: settings.themeBackground
    property color surfaceColor: settings.themeSurface
    property color textColor: settings.themeText
    property color mutedColor: settings.themeMuted
    property color borderColor: settings.themeBorder
    property color secondaryColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.74)
    property real glassOpacity: settings.themeGlass / 100
    property int cardRadius: settings.themeRadius
    readonly property bool touchMode: settings.touchMode
    property int section: 0
    property int appsTab: 0
    property int selectedSection: 0
    property var commonTimezones: [
        { "name": "UTC" },
        { "name": "Europe/Berlin" },
        { "name": "Europe/London" },
        { "name": "Europe/Paris" },
        { "name": "Europe/Madrid" },
        { "name": "Europe/Rome" },
        { "name": "Europe/Vienna" },
        { "name": "Europe/Warsaw" },
        { "name": "America/New_York" },
        { "name": "America/Chicago" },
        { "name": "America/Los_Angeles" },
        { "name": "Asia/Tokyo" },
        { "name": "Asia/Shanghai" },
        { "name": "Australia/Sydney" }
    ]
    property string appFilter: ""
    property int langRevision: Lang.revision
    property var sectionTitles: [root.tr("System"), root.tr("Network"),
                                 root.tr("Devices"), root.tr("Apps"),
                                 root.tr("Design"), root.tr("Time & Language"),
                                 root.tr("Gaming & VR"), root.tr("Firewall"),
                                 root.tr("Privacy"), root.tr("Updates"),
                                 root.tr("Backups & Restore")]
    property var sectionKeys: ["system", "network", "devices", "apps",
                               "design", "time", "gaming", "firewall",
                               "privacy", "updates", "backups"]
    property var sectionDescriptions: [
        root.tr("Hardware, operating system and performance"),
        root.tr("Connections, interfaces and addresses"),
        root.tr("Audio, input and display devices"),
        root.tr("Installed applications, defaults and autostart"),
        root.tr("Wallpaper and visual appearance"),
        root.tr("Timezone and system language"),
        root.tr("Wine, Monado and WayVR support"),
        root.tr("Network protection and nftables rules"),
        root.tr("Recent activity, clipboard and caches"),
        root.tr("Package updates for the running system"),
        root.tr("Create, restore and manage backups")
    ]

    title: root.tr("Settings")
    palette.window: settings.themePanel
    palette.windowText: settings.themeText
    palette.base: settings.themeBackground
    palette.alternateBase: settings.themePanel
    palette.text: settings.themeText
    palette.button: settings.themePanel
    palette.buttonText: settings.themeText
    palette.highlight: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)
    palette.highlightedText: "#FFFFFF"

    Component.onCompleted: {
        root.requestActivate()
        Qt.callLater(function () { root.requestActivate() })
    }

    function themeValue(prop) {
        if (prop === "themeAccent") return settings.themeAccent
        if (prop === "themeAccent2") return settings.themeAccent2
        if (prop === "themeBackground") return settings.themeBackground
        if (prop === "themePanel") return settings.themePanel
        if (prop === "themeSurface") return settings.themeSurface
        if (prop === "themeText") return settings.themeText
        if (prop === "themeMuted") return settings.themeMuted
        if (prop === "themeBorder") return settings.themeBorder
        return "#000000"
    }

    function tr(text) {
        // Reading langRevision makes every binding re-evaluate on a language change.
        if (langRevision < 0)
            return ""
        return Lang.t(text)
    }

    function trCount(shown, total) {
        return root.tr("%1 of %2 applications")
                .replace("%1", shown).replace("%2", total)
    }

    function detailText(detail) {
        if (!detail)
            return ""
        if (detail === "System application")
            return root.tr("System application")
        if (detail === "Flatpak")
            return root.tr("Flatpak")
        if (detail.indexOf("Debian package · ") === 0)
            return root.tr("Debian package") + " · " + detail.substring(17)
        return detail
    }

    function infoDetail(detail) {
        if (!detail)
            return ""
        if (detail === "input" || detail === "Network interface")
            return root.tr(detail)
        return detail.replace("Connection: ", root.tr("Connection: "))
    }

    function networkValue(value) {
        const parts = value ? value.split(" · ") : []
        if (parts.length !== 2)
            return value
        let state = parts[1]
        let suffix = ""
        const bracket = state.indexOf(" (")
        if (bracket >= 0) {
            suffix = " " + root.tr(state.substring(bracket + 1))
            state = state.substring(0, bracket)
        }
        return parts[0] + " · " + root.tr(state) + suffix
    }

    function uptimeText(raw) {
        if (!raw)
            return raw
        let text = raw.replace(/^up\s+/, "")
        text = text.replace(/(\d+)\s+weeks?/g, function (m, n) {
            return root.tr("%1 weeks").replace("%1", n)
        })
        text = text.replace(/(\d+)\s+days?/g, function (m, n) {
            return root.tr("%1 days").replace("%1", n)
        })
        text = text.replace(/(\d+)\s+hours?/g, function (m, n) {
            return root.tr("%1 hours").replace("%1", n)
        })
        text = text.replace(/(\d+)\s+minutes?/g, function (m, n) {
            return root.tr("%1 minutes").replace("%1", n)
        })
        return text
    }

    function statusText(value) {
        if (!value || value.length === 0 || value === "Not installed")
            return root.tr("Not installed")
        if (value === "installed")
            return root.tr("installed")
        if (value === "flatpak")
            return root.tr("Flatpak")
        if (value === "Ready")
            return root.tr("Ready")
        return value
    }

    function selectSection(index) {
        root.section = index
        root.selectedSection = index
        settings.loadSection(root.sectionKeys[index])
        sectionFlick.contentY = 0
    }

    Connections {
        target: settings
        function onChanged() {
            for (let i = 0; i < root.commonTimezones.length; ++i) {
                if (root.commonTimezones[i].name === settings.currentTimezone
                        && timezoneCombo.currentIndex !== i) {
                    timezoneCombo.currentIndex = i
                    break
                }
            }
            for (let i = 0; i < settings.locales.length; ++i) {
                if (settings.locales[i].name === settings.currentLocale
                        && localeCombo.currentIndex !== i) {
                    localeCombo.currentIndex = i
                    break
                }
            }
            for (let i = 0; i < settings.audioSinks.length; ++i) {
                if (settings.audioSinks[i].name === settings.defaultSink
                        && sinkCombo.currentIndex !== i) {
                    sinkCombo.currentIndex = i
                    break
                }
            }
            for (let i = 0; i < settings.audioSources.length; ++i) {
                if (settings.audioSources[i].name === settings.defaultSource
                        && sourceCombo.currentIndex !== i) {
                    sourceCombo.currentIndex = i
                    break
                }
            }
        }
    }

    function confirm(message, action) {
        confirmDialog.message = message
        confirmDialog.confirmAction = action
        confirmDialog.open()
    }

    property var filteredApps: {
        if (appFilter.length === 0)
            return settings.installedApps
        const needle = appFilter.toLowerCase()
        return settings.installedApps.filter(function (app) {
            return app.name.toLowerCase().indexOf(needle) >= 0
                || (app.detail !== undefined
                    && app.detail.toLowerCase().indexOf(needle) >= 0)
        })
    }

    Shortcut { sequence: "Ctrl+Q"; onActivated: Qt.quit() }
    Shortcut { sequence: "Ctrl+W"; onActivated: Qt.quit() }

    /* ---------------- components ---------------- */

    component ActionButton: Rectangle {
        id: button
        property string label: root.tr("")
        property bool active: false
        property bool danger: false
        property bool usable: true
        signal activated()

        width: Math.max(76, buttonText.implicitWidth + 28)
        height: root.touchMode ? 38 : 32
        radius: 9
        opacity: usable ? 1.0 : 0.4
        color: active ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16)
                      : (danger ? (buttonHover.hovered ? "#3A1E1E" : "#241A1A")
                                : (buttonHover.hovered ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.08) : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.06)))
        border.width: 1
        border.color: active ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55)
                             : (danger ? "#33FF6B6B" : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.08))

        Text {
            id: buttonText
            anchors.centerIn: parent
            text: button.label
            color: button.danger ? "#FFB4B0"
                                 : (button.active ? root.accent : root.textColor)
            font.pixelSize: root.touchMode ? 10 : 9
        }
        HoverHandler { id: buttonHover }
        MouseArea {
            anchors.fill: parent
            enabled: button.usable
            cursorShape: Qt.PointingHandCursor
            onClicked: button.activated()
        }
    }

    component VolumeSlider: Slider {
        id: slider
        height: 28

        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: 4
            radius: 2
            color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.08)

            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                radius: 2
                color: root.accent
            }
        }

        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition
               * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: 16
            height: 16
            radius: 8
            color: slider.pressed ? "#FFFFFF" : root.accent
            border.width: 1
            border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)
        }
    }

    component WindowButton: Rectangle {
        id: wb
        property string glyph: "—"
        property string tip: root.tr("")
        property color hoverColor: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.08)
        signal activated()

        width: 30
        height: 30
        radius: 8
        color: wbHover.hovered ? hoverColor : "transparent"

        Text {
            anchors.centerIn: parent
            text: wb.glyph
            color: root.secondaryColor
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
        color: root.mutedColor
        font.pixelSize: root.touchMode ? 10 : 9
        font.letterSpacing: 1.2
    }

    component Card: Rectangle {
        id: card
        default property alias content: cardColumn.data
        implicitHeight: cardColumn.implicitHeight + 24
        width: parent ? parent.width : 0
        radius: root.cardRadius
        color: Qt.rgba(root.surfaceColor.r, root.surfaceColor.g,
                       root.surfaceColor.b, root.glassOpacity)
        border.width: 1
        border.color: Qt.rgba(root.borderColor.r, root.borderColor.g,
                              root.borderColor.b, 0.22)

        Column {
            id: cardColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 6
        }
    }

    component InfoRow: Column {
        property string label: root.tr("")
        property string value: ""
        property string detail: ""
        width: parent ? parent.width : 0
        spacing: 1

        Row {
            width: parent.width
            spacing: 8
            Text {
                width: 150
                text: parent.parent.label
                color: root.mutedColor
                font.pixelSize: 9
                elide: Text.ElideRight
            }
            Text {
                width: parent.width - 158
                text: parent.parent.value
                color: root.textColor
                font.pixelSize: 10
                wrapMode: Text.Wrap
            }
        }
        Text {
            visible: parent.detail.length > 0
            text: parent.detail
            color: root.mutedColor
            font.pixelSize: 8
            leftPadding: 158
            width: parent.width
            wrapMode: Text.Wrap
        }
    }

    component ToggleRow: Rectangle {
        id: row
        property string label: root.tr("")
        property string description: root.tr("")
        property bool checked: false
        signal toggled()

        width: parent ? parent.width : 0
        height: root.touchMode
                ? (description.length > 0 ? 52 : 40)
                : (description.length > 0 ? 44 : 34)
        radius: 8
        color: rowHover.hovered ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.05) : "transparent"

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                text: row.label
                color: root.textColor
                font.pixelSize: root.touchMode ? 11 : 10
            }
            Text {
                visible: row.description.length > 0
                text: row.description
                color: root.mutedColor
                font.pixelSize: root.touchMode ? 9 : 8
            }
        }

        Rectangle {
            width: 40
            height: 20
            radius: 10
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            color: row.checked ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)
                               : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.08)
            border.width: 1
            border.color: row.checked ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.6)
                                      : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.15)

            Rectangle {
                width: 16
                height: 16
                radius: 8
                anchors.verticalCenter: parent.verticalCenter
                x: row.checked ? 21 : 3
                color: row.checked ? root.accent : root.mutedColor

                Behavior on x { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 130 } }
            }
        }

        HoverHandler { id: rowHover }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: row.toggled()
        }
    }

    component ThemeColorRow: Row {
        id: colorRow
        property string role: ""
        property string label: ""
        property string value: ""
        signal submitted(string value)
        width: parent ? parent.width : 0
        spacing: 6

        Text {
            width: 92
            text: colorRow.label
            color: root.mutedColor
            font.pixelSize: 9
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
        }
        Rectangle {
            width: 22
            height: 22
            radius: 6
            color: colorRow.value
            border.width: 1
            border.color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.25)
            anchors.verticalCenter: parent.verticalCenter
        }
        TextField {
            id: colorField
            width: 92
            height: 28
            text: colorRow.value
            color: root.textColor
            font.pixelSize: 9
            leftPadding: 6
            selectByMouse: true
            background: Rectangle {
                radius: 7
                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.06)
                border.width: 1
                border.color: Qt.rgba(root.borderColor.r, root.borderColor.g, root.borderColor.b, 0.22)
            }
            onEditingFinished: colorRow.submitted(text)
        }
        ActionButton {
            label: root.tr("Apply")
            height: 28
            onActivated: colorRow.submitted(colorField.text)
        }
        Connections {
            target: settings
            function onThemeChanged() { colorField.text = colorRow.value }
        }
    }

    component SidebarItem: Rectangle {
        id: nav
        property string label: root.tr("")
        property int value: 0
        property bool active: false
        signal activated()

        width: parent ? parent.width : 180
        height: 32
        radius: 8
        color: active ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.14)
                      : (navHover.hovered ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.05) : "transparent")
        border.width: active ? 1 : 0
        border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.35)

        Rectangle {
            width: 3
            height: 16
            radius: 1.5
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            color: nav.active ? root.accent : root.mutedColor
        }
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: nav.label
            color: nav.active ? "#FFFFFF" : root.secondaryColor
            font.pixelSize: 10
        }
        HoverHandler { id: navHover }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: nav.activated()
        }
    }

    component SubTab: Rectangle {
        id: sub
        property string label: root.tr("")
        property bool active: false
        signal activated()

        width: Math.max(92, subText.implicitWidth + 30)
        height: 30
        radius: 9
        color: active ? "#20364A" : (subHover.hovered ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.08) : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.06))
        border.width: active ? 1 : 0
        border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.35)

        Text {
            id: subText
            anchors.centerIn: parent
            text: sub.label
            color: sub.active ? root.accent : root.textColor
            font.pixelSize: 9
        }
        HoverHandler { id: subHover }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sub.activated()
        }
    }

    component DarkComboBox: ComboBox {
        id: combo
        implicitHeight: 32
        font.pixelSize: 10

        background: Rectangle {
            radius: 8
            color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.06)
            border.width: 1
            border.color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
        }
        contentItem: Text {
            leftPadding: 10
            rightPadding: 24
            text: combo.displayText
            color: root.textColor
            font.pixelSize: 10
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        delegate: ItemDelegate {
            width: combo.width
            contentItem: Text {
                leftPadding: 8
                text: modelData !== undefined && modelData.name !== undefined
                      ? modelData.name : model.display
                color: highlighted ? "#FFFFFF" : root.textColor
                font.pixelSize: 10
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: highlighted ? "#2A3945" : "transparent"
            }
        }
        popup: Popup {
            y: combo.height + 2
            width: combo.width
            implicitHeight: Math.min(340, contentItem.implicitHeight + 8)
            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: combo.popup.visible ? combo.delegateModel : null
                currentIndex: combo.highlightedIndex
                ScrollBar.vertical: ScrollBar {}
            }
            background: Rectangle {
                radius: Math.max(6, root.cardRadius - 4)
                color: Qt.rgba(root.surfaceColor.r, root.surfaceColor.g,
                               root.surfaceColor.b, 0.98)
                border.width: 1
                border.color: Qt.rgba(root.borderColor.r, root.borderColor.g,
                                      root.borderColor.b, 0.24)
            }
        }
    }

    component LogCard: Rectangle {
        width: parent ? parent.width : 0
        height: settings.log.length > 0 ? 170 : 0
        visible: height > 0
        radius: 10
        color: root.backgroundColor
        border.width: 1
        border.color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.08)
        clip: true

        Flickable {
            anchors.fill: parent
            anchors.margins: 8
            clip: true
            contentWidth: width
            contentHeight: logText.implicitHeight

            TextEdit {
                id: logText
                width: parent.width
                text: settings.log
                color: root.secondaryColor
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 9
                wrapMode: TextEdit.Wrap
                readOnly: true
                selectByMouse: true
            }
        }

        ActionButton {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 6
            label: root.tr("Clear")
            width: 64
            height: 24
            onActivated: settings.clearLog()
        }
    }

    /* ---------------- background ---------------- */

    Image {
        anchors.fill: parent
        source: root.backgroundImage
        fillMode: root.backgroundFillMode
        opacity: 0.9
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Qt.rgba(root.panelColor.r, root.panelColor.g,
                               root.panelColor.b,
                               0.35 + settings.themeWallpaperDim / 100 * 0.6)
            }
            GradientStop {
                position: 1.0
                color: Qt.rgba(root.backgroundColor.r, root.backgroundColor.g,
                               root.backgroundColor.b,
                               0.35 + settings.themeWallpaperDim / 100 * 0.6)
            }
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        /* ---------------- title bar ---------------- */

        Rectangle {
            width: parent.width
            height: 64
            radius: root.cardRadius + 2
            color: Qt.rgba(root.panelColor.r, root.panelColor.g,
                           root.panelColor.b, 0.82)
            border.width: 1
            border.color: Qt.rgba(root.borderColor.r, root.borderColor.g,
                                  root.borderColor.b, 0.18)

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Rectangle {
                    width: 32; height: 32; radius: 9
                    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)
                    border.width: 1
                    border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.35)
                    Text { anchors.centerIn: parent; text: root.tr("⚙"); color: root.accent; font.pixelSize: 16 }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        text: root.tr("SETTINGS")
                        color: root.textColor
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.1
                    }
                    Text {
                        text: root.tr("System, apps, privacy and support")
                        color: root.mutedColor
                        font.pixelSize: 9
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                WindowButton {
                    width: 18
                    glyph: "⠿"
                    tip: root.tr("Drag to move window")
                    hoverColor: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.06)
                    onActivated: root.startSystemMove()
                }
                Rectangle { width: 1; height: 22; color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.08) }
                WindowButton { glyph: "—"; tip: root.tr("Minimize"); onActivated: root.showMinimized() }
                WindowButton {
                    glyph: root.visibility === Window.Maximized ? "❐" : "□"
                    tip: root.visibility === Window.Maximized ? "Restore" : "Maximize"
                    onActivated: {
                        if (root.visibility === Window.Maximized)
                            root.showNormal()
                        else
                            root.showMaximized()
                    }
                }
                WindowButton {
                    glyph: "✕"
                    tip: root.tr("Close")
                    hoverColor: "#C42B1C"
                    onActivated: Qt.quit()
                }
            }
        }

        /* ---------------- content ---------------- */

        Row {
            width: parent.width
            height: parent.height - 64 - 30 - 20
            spacing: 10

            /* Sidebar */
            Rectangle {
                width: 210
                height: parent.height
                radius: root.cardRadius + 2
                color: Qt.rgba(root.surfaceColor.r, root.surfaceColor.g,
                               root.surfaceColor.b, root.glassOpacity)
                border.width: 1
                border.color: Qt.rgba(root.borderColor.r, root.borderColor.g,
                                      root.borderColor.b, 0.18)

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 3

                    SectionLabel { text: root.tr("SECTIONS") }
                    Item { width: 1; height: 4 }

                    Repeater {
                        model: root.sectionTitles
                        delegate: SidebarItem {
                            required property int index
                            required property string modelData
                            label: modelData
                            value: index
                            active: root.section === index
                            onActivated: root.selectSection(index)
                        }
                    }
                }
            }

            /* Content */
            Rectangle {
                width: parent.width - 210 - 10
                height: parent.height
                radius: root.cardRadius + 2
                color: Qt.rgba(root.panelColor.r, root.panelColor.g,
                               root.panelColor.b, 0.58)
                border.width: 1
                border.color: Qt.rgba(root.borderColor.r, root.borderColor.g,
                                      root.borderColor.b, 0.16)
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Row {
                        width: parent.width
                        height: 42
                        spacing: 10
                        Column {
                            width: parent.width - 130
                            spacing: 1
                            Text {
                                text: root.sectionTitles[root.section]
                                color: root.textColor
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: root.sectionDescriptions[root.section]
                                color: root.mutedColor
                                font.pixelSize: 9
                            }
                        }
                        ActionButton {
                            y: 5
                            label: root.tr("Refresh")
                            width: 100
                            onActivated: settings.loadSection(root.sectionKeys[root.section])
                        }
                    }

                    Flickable {
                        id: sectionFlick
                        width: parent.width
                        height: parent.height - 52
                        clip: true
                        contentWidth: width
                        contentHeight: sectionsColumn.height
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: sectionsColumn
                            width: sectionFlick.width
                            spacing: 10

                            /* ---------------- System ---------------- */
                            Column {
                                width: parent.width
                                visible: root.section === 0
                                spacing: 10

                                Card {
                                    SectionLabel { text: root.tr("SYSTEM INFORMATION") }
                                    Repeater {
                                        model: settings.systemInfo
                                        delegate: InfoRow {
                                            required property var modelData
                                            label: root.tr(modelData.label)
                                            value: modelData.label === "Uptime"
                                                   ? root.uptimeText(modelData.value)
                                                   : modelData.value
                                        }
                                    }
                                }

                                Card {
                                    id: healthCard
                                    SectionLabel { text: root.tr("HEALTH") }
                                    property var data: ({})
                                    function refresh() {
                                        try {
                                            data = JSON.parse(settings.readHealth())
                                        } catch (error) {
                                            data = ({})
                                        }
                                    }
                                    function percent(name) {
                                        if (!data || !data[name] || data[name].used_pct === undefined)
                                            return "–"
                                        return data[name].used_pct + " %"
                                    }
                                    Component.onCompleted: refresh()
                                    InfoRow { label: root.tr("Memory"); value: healthCard.percent("memory") }
                                    InfoRow { label: root.tr("Disk"); value: healthCard.percent("disk") }
                                    InfoRow {
                                        label: root.tr("Load")
                                        value: healthCard.data.load
                                               ? healthCard.data.load.load1 + " / "
                                                 + healthCard.data.load.load5 + " / "
                                                 + healthCard.data.load.load15
                                               : "–"
                                    }
                                    InfoRow {
                                        label: root.tr("Failed services")
                                        value: healthCard.data.units
                                               ? "" + healthCard.data.units.count : "–"
                                    }
                                    InfoRow {
                                        label: root.tr("Waydroid")
                                        value: {
                                            const waydroid = healthCard.data.waydroid
                                            if (!waydroid || !waydroid.available)
                                                return root.tr("not running")
                                            const state = waydroid.frozen ? root.tr("frozen")
                                                        : waydroid.booted ? root.tr("booted")
                                                        : root.tr("not booted")
                                            return state + " · " + waydroid.apps + " " + root.tr("Apps")
                                        }
                                    }
                                    InfoRow {
                                        label: root.tr("Clipboard bridge")
                                        value: healthCard.data.waydroid
                                               ? (healthCard.data.waydroid.bridge
                                                  ? root.tr("running") : root.tr("stopped"))
                                               : "–"
                                    }
                                    Text {
                                        width: parent.width
                                        text: root.tr("Warnings") + ": "
                                              + (healthCard.data.alerts
                                                 && healthCard.data.alerts.length > 0
                                                 ? healthCard.data.alerts.join(", ")
                                                 : root.tr("none"))
                                        color: healthCard.data.alerts
                                               && healthCard.data.alerts.length > 0
                                               ? root.accent : root.mutedColor
                                        font.pixelSize: 9
                                        wrapMode: Text.WordWrap
                                    }
                                    Timer {
                                        interval: 15000
                                        repeat: true
                                        running: root.section === 0
                                        onTriggered: healthCard.refresh()
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("STORAGE") }
                                    Text {
                                        text: settings.storageInfo
                                        color: root.textColor
                                        font.pixelSize: 9
                                        wrapMode: Text.WordWrap
                                        width: parent.width
                                    }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Open Cleaner")
                                            onActivated: settings.openCleaner()
                                        }
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("DEVICE NAME") }
                                    Row {
                                        spacing: 8
                                        TextField {
                                            id: hostnameField
                                            width: 260
                                            height: 32
                                            text: settings.hostname
                                            color: root.textColor
                                            font.pixelSize: 10
                                            selectByMouse: true
                                            leftPadding: 8
                                            background: Rectangle {
                                                radius: 8
                                                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.06)
                                                border.width: 1
                                                border.color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
                                            }
                                        }
                                        ActionButton {
                                            label: root.tr("Apply hostname")
                                            onActivated: settings.setHostname(hostnameField.text)
                                        }
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("DEVICE PROFILE") }
                                    Text {
                                        text: root.tr("Detected device") + ": "
                                              + (settings.formFactor === "tv"
                                                 ? root.tr("TV")
                                                 : settings.formFactor === "tablet"
                                                   ? root.tr("Tablet")
                                                   : settings.formFactor === "laptop"
                                                     ? root.tr("Laptop")
                                                     : root.tr("PC"))
                                              + "  ·  " + settings.formFactorInfo
                                        color: root.textColor
                                        font.pixelSize: 10
                                    }
                                    Text {
                                        text: root.tr("The interface adapts automatically to the detected device class.")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                        wrapMode: Text.WordWrap
                                        width: parent.width
                                    }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Automatic")
                                            active: settings.formFactorMode === "auto"
                                            onActivated: settings.setFormFactorMode("auto")
                                        }
                                        ActionButton {
                                            label: root.tr("PC")
                                            active: settings.formFactorMode === "pc"
                                            onActivated: settings.setFormFactorMode("pc")
                                        }
                                        ActionButton {
                                            label: root.tr("Laptop")
                                            active: settings.formFactorMode === "laptop"
                                            onActivated: settings.setFormFactorMode("laptop")
                                        }
                                        ActionButton {
                                            label: root.tr("Tablet")
                                            active: settings.formFactorMode === "tablet"
                                            onActivated: settings.setFormFactorMode("tablet")
                                        }
                                        ActionButton {
                                            label: root.tr("TV")
                                            active: settings.formFactorMode === "tv"
                                            onActivated: settings.setFormFactorMode("tv")
                                        }
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("ACCESSIBILITY") }
                                    ToggleRow {
                                        label: root.tr("Large text")
                                        description: root.tr("Increases UI scale for new sessions")
                                        checked: settings.largeText
                                        onToggled: settings.setLargeText(!settings.largeText)
                                    }
                                    Text {
                                        text: root.tr("Cursor size")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                    }
                                    DarkComboBox {
                                        id: cursorSizeCombo
                                        width: 160
                                        model: [16, 24, 32, 48, 64]
                                        Component.onCompleted: {
                                            for (let i = 0; i < model.length; ++i) {
                                                if (model[i] === settings.cursorSize) {
                                                    currentIndex = i
                                                    break
                                                }
                                            }
                                        }
                                        onActivated: settings.setCursorSize(model[currentIndex])
                                    }
                                    Text {
                                        text: root.tr("Accessibility changes apply to new sessions.")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                        wrapMode: Text.WordWrap
                                        width: parent.width
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("PERFORMANCE") }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Power saver")
                                            active: settings.profile === "powersave"
                                            onActivated: settings.setProfile("powersave")
                                        }
                                        ActionButton {
                                            label: root.tr("Balanced")
                                            active: settings.profile === "balanced"
                                            onActivated: settings.setProfile("balanced")
                                        }
                                        ActionButton {
                                            label: root.tr("Performance")
                                            active: settings.profile === "performance"
                                            onActivated: settings.setProfile("performance")
                                        }
                                    }
                                    ToggleRow {
                                        label: root.tr("ZRAM swap")
                                        description: root.tr("Compressed memory swap for low-memory systems")
                                        checked: settings.zram
                                        onToggled: settings.setZram(!settings.zram)
                                    }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Open Control Center")
                                            onActivated: settings.openControlCenter()
                                        }
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("POWER") }
                                    Text {
                                        text: root.tr("Screen timeout")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                    }
                                    DarkComboBox {
                                        id: screenTimeoutCombo
                                        width: parent.width - 20
                                        model: [
                                            { "label": root.tr("Never"), "value": 0 },
                                            { "label": "2 min", "value": 2 },
                                            { "label": "5 min", "value": 5 },
                                            { "label": "10 min", "value": 10 },
                                            { "label": "15 min", "value": 15 },
                                            { "label": "30 min", "value": 30 },
                                            { "label": "60 min", "value": 60 }
                                        ]
                                        textRole: "label"
                                        Component.onCompleted: {
                                            for (let i = 0; i < model.length; ++i) {
                                                if (model[i].value === settings.screenTimeout) {
                                                    currentIndex = i
                                                    break
                                                }
                                            }
                                        }
                                        onActivated: settings.setScreenTimeout(model[currentIndex].value)
                                    }
                                    Text {
                                        text: root.tr("Suspend timeout")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                    }
                                    DarkComboBox {
                                        id: suspendTimeoutCombo
                                        width: parent.width - 20
                                        model: [
                                            { "label": root.tr("Never"), "value": 0 },
                                            { "label": "15 min", "value": 15 },
                                            { "label": "30 min", "value": 30 },
                                            { "label": "60 min", "value": 60 },
                                            { "label": "120 min", "value": 120 }
                                        ]
                                        textRole: "label"
                                        Component.onCompleted: {
                                            for (let i = 0; i < model.length; ++i) {
                                                if (model[i].value === settings.suspendTimeout) {
                                                    currentIndex = i
                                                    break
                                                }
                                            }
                                        }
                                        onActivated: settings.setSuspendTimeout(model[currentIndex].value)
                                    }
                                    Text {
                                        visible: settings.batteryPercent >= 0
                                        text: root.tr("Battery") + ": " + settings.batteryPercent
                                              + "%" + (settings.batteryCharging
                                                       ? "  ·  " + root.tr("Charging") : "")
                                        color: root.secondaryColor
                                        font.pixelSize: 9
                                    }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Suspend now")
                                            onActivated: settings.suspendNow()
                                        }
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("NOTIFICATIONS") }
                                    ToggleRow {
                                        label: root.tr("Desktop notifications")
                                        description: root.tr("Show notification popups in the top-right corner")
                                        checked: settings.notificationsEnabled
                                        onToggled: settings.setNotificationsEnabled(!settings.notificationsEnabled)
                                    }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Send test notification")
                                            onActivated: settings.sendTestNotification()
                                        }
                                        ActionButton {
                                            label: root.tr("Clear notifications")
                                            onActivated: settings.clearNotifications()
                                        }
                                        ActionButton {
                                            label: root.tr("Refresh")
                                            onActivated: settings.loadSection("system")
                                        }
                                    }
                                }
                            }

                            /* ---------------- Network ---------------- */
                            Column {
                                width: parent.width
                                visible: root.section === 1
                                spacing: 10

                                Card {
                                    SectionLabel { text: root.tr("CONNECTIONS") }
                                    Repeater {
                                        model: settings.networkInfo
                                        delegate: InfoRow {
                                            required property var modelData
                                            label: root.tr(modelData.label)
                                            value: root.networkValue(modelData.value)
                                            detail: root.infoDetail(modelData.detail)
                                        }
                                    }
                                    Text {
                                        visible: settings.networkInfo.length === 0
                                        text: root.tr("No network interfaces found")
                                        color: root.mutedColor
                                        font.pixelSize: 10
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("WI-FI") }
                                    ToggleRow {
                                        label: root.tr("Wi-Fi")
                                        checked: settings.wifiEnabled
                                        onToggled: settings.setWifiEnabled(!settings.wifiEnabled)
                                    }
                                    ToggleRow {
                                        label: root.tr("Networking")
                                        description: root.tr("Enable all wired and wireless connections")
                                        checked: settings.networkingEnabled
                                        onToggled: settings.setNetworkingEnabled(!settings.networkingEnabled)
                                    }

                                    Repeater {
                                        model: settings.wifiNetworks
                                        delegate: Row {
                                            required property var modelData
                                            width: parent.width
                                            height: 38
                                            spacing: 8

                                            Column {
                                                width: parent.width - 130
                                                y: 4
                                                spacing: 1
                                                Text {
                                                    text: modelData.ssid
                                                    color: root.textColor
                                                    font.pixelSize: 10
                                                    elide: Text.ElideRight
                                                    width: parent.width
                                                }
                                                Text {
                                                    text: modelData.security + "  ·  "
                                                          + modelData.signal + root.tr("% signal")
                                                    color: root.mutedColor
                                                    font.pixelSize: 8
                                                }
                                            }

                                            Rectangle {
                                                visible: modelData.active
                                                width: 84
                                                height: 24
                                                radius: 6
                                                y: 6
                                                color: "#193326"
                                                border.width: 1
                                                border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.tr("CONNECTED")
                                                    color: root.accent
                                                    font.pixelSize: 8
                                                    font.letterSpacing: 0.8
                                                }
                                            }
                                            ActionButton {
                                                visible: !modelData.active
                                                label: root.tr("Connect")
                                                width: 88
                                                y: 4
                                                onActivated: {
                                                    wifiDialog.ssid = modelData.ssid
                                                    wifiPassword.text = ""
                                                    wifiDialog.open()
                                                }
                                            }
                                        }
                                    }
                                    Text {
                                        visible: settings.wifiNetworks.length === 0
                                        text: root.tr("No Wi-Fi networks found. Use Scan networks to refresh.")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                    }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Scan networks")
                                            onActivated: settings.refreshWifi()
                                        }
                                        ActionButton {
                                            label: root.tr("Disconnect")
                                            onActivated: settings.disconnectWifi()
                                        }
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("DNS SERVERS") }
                                    TextField {
                                        id: dnsField
                                        width: parent.width - 20
                                        height: 32
                                        text: settings.dnsServers
                                        placeholderText: root.tr("Empty = automatic DNS")
                                        color: root.textColor
                                        placeholderTextColor: root.mutedColor
                                        font.pixelSize: 9
                                        leftPadding: 8
                                        selectByMouse: true
                                        background: Rectangle {
                                            radius: 8
                                            color: Qt.rgba(root.textColor.r, root.textColor.g,
                                                           root.textColor.b, 0.06)
                                            border.width: 1
                                            border.color: Qt.rgba(root.borderColor.r,
                                                                  root.borderColor.g,
                                                                  root.borderColor.b, 0.22)
                                        }
                                    }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Apply DNS")
                                            onActivated: settings.setDnsServers(dnsField.text)
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: root.tr("Comma-separated IPv4 addresses")
                                            color: root.mutedColor
                                            font.pixelSize: 8
                                        }
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("HOTSPOT") }
                                    Text {
                                        text: root.tr("Share the Wi-Fi connection with other devices")
                                        color: root.secondaryColor
                                        font.pixelSize: 9
                                        wrapMode: Text.WordWrap
                                        width: parent.width
                                    }
                                    TextField {
                                        id: hotspotSsid
                                        width: parent.width - 20
                                        height: 32
                                        placeholderText: root.tr("Hotspot name")
                                        color: root.textColor
                                        placeholderTextColor: root.mutedColor
                                        font.pixelSize: 10
                                        leftPadding: 8
                                        background: Rectangle {
                                            radius: 8
                                            color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.06)
                                            border.width: 1
                                            border.color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
                                        }
                                    }
                                    TextField {
                                        id: hotspotPassword
                                        width: parent.width - 20
                                        height: 32
                                        placeholderText: root.tr("Password (min. 8 characters)")
                                        echoMode: TextInput.Password
                                        color: root.textColor
                                        placeholderTextColor: root.mutedColor
                                        font.pixelSize: 10
                                        leftPadding: 8
                                        background: Rectangle {
                                            radius: 8
                                            color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.06)
                                            border.width: 1
                                            border.color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
                                        }
                                    }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Start hotspot")
                                            usable: !settings.hotspotActive
                                            onActivated: settings.startHotspot(
                                                hotspotSsid.text, hotspotPassword.text)
                                        }
                                        ActionButton {
                                            label: root.tr("Stop hotspot")
                                            usable: settings.hotspotActive
                                            danger: settings.hotspotActive
                                            onActivated: settings.stopHotspot()
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: settings.hotspotActive
                                                  ? root.tr("Active") : root.tr("Inactive")
                                            color: settings.hotspotActive
                                                   ? root.accent : root.mutedColor
                                            font.pixelSize: 9
                                        }
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("FLIGHT MODE") }
                                    ToggleRow {
                                        label: root.tr("Flight mode")
                                        description: root.tr("Disable Wi-Fi, mobile data and Bluetooth")
                                        checked: settings.flightMode
                                        onToggled: settings.setFlightMode(!settings.flightMode)
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("VPN") }
                                    Repeater {
                                        model: settings.vpnConnections
                                        delegate: Row {
                                            required property var modelData
                                            width: parent.width
                                            height: 34
                                            spacing: 8
                                            Text {
                                                width: parent.width - 120
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.name + "  ·  " + modelData.type
                                                color: root.textColor
                                                font.pixelSize: 10
                                                elide: Text.ElideRight
                                            }
                                            ActionButton {
                                                label: modelData.active
                                                       ? root.tr("Disconnect")
                                                       : root.tr("Connect")
                                                active: modelData.active
                                                onActivated: modelData.active
                                                             ? settings.disconnectVpn(modelData.name)
                                                             : settings.connectVpn(modelData.name)
                                            }
                                        }
                                    }
                                    Text {
                                        visible: settings.vpnConnections.length === 0
                                        text: root.tr("No VPN profiles configured")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                    }
                                    TextField {
                                        id: vpnPath
                                        width: parent.width - 20
                                        height: 32
                                        placeholderText: root.tr("Path to .ovpn or WireGuard .conf file")
                                        color: root.textColor
                                        placeholderTextColor: root.mutedColor
                                        font.pixelSize: 10
                                        leftPadding: 8
                                        background: Rectangle {
                                            radius: 8
                                            color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.06)
                                            border.width: 1
                                            border.color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
                                        }
                                    }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Import VPN")
                                            onActivated: settings.importVpn(vpnPath.text)
                                        }
                                        ActionButton {
                                            label: root.tr("VPN settings")
                                            onActivated: settings.openVpnSettings()
                                        }
                                    }
                                }

                                Row {
                                    spacing: 8
                                    ActionButton {
                                        label: root.tr("Network settings")
                                        onActivated: settings.openNetworkSettings()
                                    }
                                    ActionButton {
                                        label: root.tr("Refresh")
                                        onActivated: settings.loadSection("network")
                                    }
                                }
                            }

                            /* ---------------- Devices ---------------- */
                            Column {
                                width: parent.width
                                visible: root.section === 2
                                spacing: 10

                                Card {
                                    SectionLabel { text: root.tr("SOUND") }
                                    Text {
                                        text: root.tr("Output device")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                    }
                                    DarkComboBox {
                                        id: sinkCombo
                                        width: parent.width - 20
                                        model: settings.audioSinks
                                        textRole: "name"
                                        Component.onCompleted: {
                                            for (let i = 0; i < settings.audioSinks.length; ++i) {
                                                if (settings.audioSinks[i].name === settings.defaultSink) {
                                                    currentIndex = i
                                                    break
                                                }
                                            }
                                        }
                                        onActivated: {
                                            if (currentIndex >= 0)
                                                settings.setDefaultSink(settings.audioSinks[currentIndex].name)
                                        }
                                    }
                                    Row {
                                        width: parent.width
                                        spacing: 8
                                        VolumeSlider {
                                            id: sinkSlider
                                            width: parent.width - 70
                                            from: 0
                                            to: 100
                                            value: settings.sinkVolume
                                            onMoved: sinkVolumeTimer.restart()
                                            onPressedChanged: {
                                                if (!pressed)
                                                    settings.setSinkVolume(Math.round(value))
                                            }
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: Math.round(sinkSlider.value) + "%"
                                            color: root.textColor
                                            font.pixelSize: 9
                                        }
                                    }
                                    Timer {
                                        id: sinkVolumeTimer
                                        interval: 140
                                        onTriggered: settings.setSinkVolume(Math.round(sinkSlider.value))
                                    }
                                    ToggleRow {
                                        label: root.tr("Mute output")
                                        checked: settings.sinkMuted
                                        onToggled: settings.setSinkMuted(!settings.sinkMuted)
                                    }

                                    Text {
                                        text: root.tr("Input device")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                    }
                                    DarkComboBox {
                                        id: sourceCombo
                                        width: parent.width - 20
                                        model: settings.audioSources
                                        textRole: "name"
                                        Component.onCompleted: {
                                            for (let i = 0; i < settings.audioSources.length; ++i) {
                                                if (settings.audioSources[i].name === settings.defaultSource) {
                                                    currentIndex = i
                                                    break
                                                }
                                            }
                                        }
                                        onActivated: {
                                            if (currentIndex >= 0)
                                                settings.setDefaultSource(settings.audioSources[currentIndex].name)
                                        }
                                    }
                                    Row {
                                        width: parent.width
                                        spacing: 8
                                        VolumeSlider {
                                            id: sourceSlider
                                            width: parent.width - 70
                                            from: 0
                                            to: 100
                                            value: settings.sourceVolume
                                            onMoved: sourceVolumeTimer.restart()
                                            onPressedChanged: {
                                                if (!pressed)
                                                    settings.setSourceVolume(Math.round(value))
                                            }
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: Math.round(sourceSlider.value) + "%"
                                            color: root.textColor
                                            font.pixelSize: 9
                                        }
                                    }
                                    Timer {
                                        id: sourceVolumeTimer
                                        interval: 140
                                        onTriggered: settings.setSourceVolume(Math.round(sourceSlider.value))
                                    }
                                    ToggleRow {
                                        label: root.tr("Mute input")
                                        checked: settings.sourceMuted
                                        onToggled: settings.setSourceMuted(!settings.sourceMuted)
                                    }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Sound settings")
                                            onActivated: settings.openSoundSettings()
                                        }
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("DISPLAY") }
                                    Repeater {
                                        model: settings.displayOutputs
                                        delegate: Column {
                                            required property var modelData
                                            width: parent.width
                                            spacing: 4

                                            Text {
                                                text: modelData.label
                                                color: root.textColor
                                                font.pixelSize: 10
                                                elide: Text.ElideRight
                                                width: parent.width
                                            }
                                            Text {
                                                text: root.tr("Current: ")
                                                      + (modelData.current.length > 0
                                                         ? modelData.current : root.tr("unknown"))
                                                color: root.mutedColor
                                                font.pixelSize: 9
                                            }
                                            Row {
                                                spacing: 6
                                                Repeater {
                                                    model: modelData.modes
                                                    delegate: ActionButton {
                                                        required property var modelData
                                                        label: modelData.name
                                                        active: modelData.name === parent.parent.modelData.current
                                                        height: 28
                                                        onActivated: settings.setDisplayMode(
                                                            parent.parent.modelData.name, modelData.name)
                                                    }
                                                }
                                            }
                                            Item { width: 1; height: 4 }
                                        }
                                    }
                                    Text {
                                        visible: settings.displayOutputs.length === 0
                                        text: root.tr("No display information available")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("INPUT DEVICES") }
                                    Repeater {
                                        model: settings.deviceInfo
                                        delegate: InfoRow {
                                            required property var modelData
                                            label: root.tr(modelData.label)
                                            value: modelData.value
                                            detail: root.infoDetail(modelData.detail)
                                        }
                                    }
                                    Text {
                                        visible: settings.deviceInfo.length === 0
                                        text: root.tr("No input devices detected")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("MOUSE & TOUCHPAD") }
                                    Row {
                                        width: parent.width
                                        spacing: 8
                                        VolumeSlider {
                                            id: mouseSpeedSlider
                                            width: parent.width - 80
                                            from: -100
                                            to: 100
                                            stepSize: 5
                                            value: settings.mouseSpeed
                                            onPressedChanged: {
                                                if (!pressed)
                                                    settings.setMouseSpeed(Math.round(value))
                                            }
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: Math.round(mouseSpeedSlider.value)
                                            color: root.textColor
                                            font.pixelSize: 9
                                        }
                                    }
                                    ToggleRow {
                                        label: root.tr("Natural scrolling")
                                        description: root.tr("Scroll in the direction of your fingers")
                                        checked: settings.naturalScroll
                                        onToggled: settings.setNaturalScroll(!settings.naturalScroll)
                                    }
                                    ToggleRow {
                                        label: root.tr("Tap to click")
                                        description: root.tr("Tap the touchpad to click")
                                        checked: settings.tapToClick
                                        onToggled: settings.setTapToClick(!settings.tapToClick)
                                    }
                                    ToggleRow {
                                        label: root.tr("Left-handed mouse")
                                        description: root.tr("Swap the primary and secondary buttons")
                                        checked: settings.leftHanded
                                        onToggled: settings.setLeftHanded(!settings.leftHanded)
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("BLUETOOTH") }
                                    Text {
                                        visible: !settings.bluetoothAvailable
                                        text: root.tr("No Bluetooth adapter available")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                    }
                                    ToggleRow {
                                        visible: settings.bluetoothAvailable
                                        label: root.tr("Bluetooth")
                                        checked: settings.bluetoothEnabled
                                        onToggled: settings.setBluetoothEnabled(!settings.bluetoothEnabled)
                                    }
                                    Repeater {
                                        model: settings.bluetoothDevices
                                        delegate: Row {
                                            required property var modelData
                                            width: parent.width
                                            height: 34
                                            spacing: 8
                                            Column {
                                                width: parent.width - 150
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 1
                                                Text {
                                                    text: modelData.name
                                                    color: root.textColor
                                                    font.pixelSize: 10
                                                    elide: Text.ElideRight
                                                    width: parent.width
                                                }
                                                Text {
                                                    text: modelData.address
                                                          + (modelData.connected
                                                             ? "  ·  " + root.tr("Connected")
                                                             : modelData.paired
                                                               ? "  ·  " + root.tr("Paired") : "")
                                                    color: root.mutedColor
                                                    font.pixelSize: 8
                                                }
                                            }
                                            ActionButton {
                                                visible: !modelData.connected
                                                label: modelData.paired
                                                       ? root.tr("Connect")
                                                       : root.tr("Pair")
                                                onActivated: modelData.paired
                                                             ? settings.connectBluetooth(modelData.address)
                                                             : settings.pairBluetooth(modelData.address)
                                            }
                                        }
                                    }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Scan for devices")
                                            usable: settings.bluetoothAvailable
                                            onActivated: settings.scanBluetooth()
                                        }
                                        ActionButton {
                                            label: root.tr("Refresh")
                                            onActivated: settings.loadSection("devices")
                                        }
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("PRINTERS & SCANNERS") }
                                    Text {
                                        text: root.tr("Manage CUPS printers, print queues and SANE scanners.")
                                        color: root.secondaryColor
                                        font.pixelSize: 9
                                        wrapMode: Text.WordWrap
                                        width: parent.width
                                    }
                                    Repeater {
                                        model: settings.printers
                                        delegate: Row {
                                            required property var modelData
                                            width: parent.width
                                            height: 32
                                            spacing: 8
                                            Text {
                                                width: parent.width - 150
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.name
                                                      + (modelData.name === settings.defaultPrinter
                                                         ? "  ·  " + root.tr("Default") : "")
                                                color: root.textColor
                                                font.pixelSize: 10
                                                elide: Text.ElideRight
                                            }
                                            ActionButton {
                                                label: root.tr("Test page")
                                                onActivated: settings.testPrinter(modelData.name)
                                            }
                                        }
                                    }
                                    Text {
                                        visible: settings.printers.length === 0
                                        text: root.tr("No printers configured")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                    }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Add printer")
                                            onActivated: settings.openPrinterSettings()
                                        }
                                        ActionButton {
                                            label: root.tr("Open Print & Scan")
                                            onActivated: settings.openPrintScan()
                                        }
                                        ActionButton {
                                            label: root.tr("Refresh")
                                            onActivated: settings.loadSection("devices")
                                        }
                                    }
                                }
                            }

                            /* ---------------- Apps ---------------- */
                            Column {
                                width: parent.width
                                visible: root.section === 3
                                spacing: 10

                                Row {
                                    spacing: 8
                                    SubTab { label: root.tr("Installed"); active: root.appsTab === 0; onActivated: root.appsTab = 0 }
                                    SubTab { label: root.tr("Default apps"); active: root.appsTab === 1; onActivated: root.appsTab = 1 }
                                    SubTab { label: root.tr("Autostart"); active: root.appsTab === 2; onActivated: root.appsTab = 2 }
                                }

                                Card {
                                    SectionLabel { text: root.tr("WAYDROID") }
                                    Text {
                                        width: parent.width
                                        text: settings.waydroidRunning
                                              ? root.tr("Waydroid is running") + " · "
                                                + settings.waydroidApps + " "
                                                + root.tr("Android apps")
                                              : root.tr("Waydroid is not running")
                                        color: settings.waydroidRunning
                                               ? root.accent
                                               : root.mutedColor
                                        font.pixelSize: 10
                                        wrapMode: Text.WordWrap
                                    }
                                    Text {
                                        width: parent.width
                                        text: root.tr("Android apps from Waydroid appear in the Start menu.")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                        wrapMode: Text.WordWrap
                                    }
                                    Text {
                                        width: parent.width
                                        visible: settings.waydroidStorageTotal > 0
                                        text: root.tr("Storage") + ": "
                                              + (settings.waydroidStorageUsed < 1073741824
                                                 ? (settings.waydroidStorageUsed / 1048576).toFixed(1) + " MiB"
                                                 : (settings.waydroidStorageUsed / 1073741824).toFixed(1) + " GiB")
                                              + " · "
                                              + (settings.waydroidStorageFree / 1073741824).toFixed(1)
                                              + " GiB " + root.tr("free")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                        wrapMode: Text.WordWrap
                                    }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Start Waydroid")
                                            onActivated: settings.startWaydroid()
                                        }
                                        ActionButton {
                                            label: root.tr("Restart Waydroid")
                                            onActivated: settings.restartWaydroid()
                                        }
                                        ActionButton {
                                            label: root.tr("Sync Android apps")
                                            onActivated: settings.syncWaydroid()
                                        }
                                        ActionButton {
                                            label: root.tr("Android settings")
                                            onActivated: settings.openAndroidSettings()
                                        }
                                        ActionButton {
                                            label: root.tr("Install APK")
                                            onActivated: settings.installWaydroidApk()
                                        }
                                    }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Back up Android data")
                                            onActivated: settings.backupWaydroid()
                                        }
                                        ActionButton {
                                            label: root.tr("Restore Android data")
                                            onActivated: settings.restoreWaydroid()
                                        }
                                    }
                                    ToggleRow {
                                        label: root.tr("Start Waydroid at login")
                                        description: root.tr("Warms up the Android container after login.")
                                        checked: settings.waydroidAutostart
                                        onToggled: settings.setWaydroidAutostart(
                                            !settings.waydroidAutostart)
                                    }
                                    ToggleRow {
                                        label: root.tr("Clipboard and notifications")
                                        description: root.tr("Forwards the clipboard and Android notifications to the desktop.")
                                        checked: settings.waydroidBridge
                                        onToggled: settings.setWaydroidBridge(
                                            !settings.waydroidBridge)
                                    }
                                    ToggleRow {
                                        label: root.tr("Multi-Window")
                                        description: root.tr("Android apps open in their own desktop window.")
                                        checked: settings.waydroidMultiwindow
                                        onToggled: settings.setWaydroidMultiwindow(
                                            !settings.waydroidMultiwindow)
                                    }
                                    TextField {
                                        id: androidSearch
                                        width: parent.width
                                        height: 32
                                        visible: settings.waydroidAppList.length > 0
                                        placeholderText: root.tr("Search Android apps…")
                                        color: root.textColor
                                        font.pixelSize: 10
                                        selectByMouse: true
                                        leftPadding: 8
                                        background: Rectangle {
                                            radius: 8
                                            color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.06)
                                            border.width: 1
                                            border.color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
                                        }
                                    }
                                    Text {
                                        visible: settings.waydroidAppList.length === 0
                                        text: root.tr("No Android apps installed.")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                    }
                                    Repeater {
                                        model: {
                                            settings.waydroidAppList
                                            const needle = androidSearch.text.toLowerCase()
                                            if (needle.length === 0)
                                                return settings.waydroidAppList
                                            return settings.waydroidAppList.filter(function (app) {
                                                return app.label.toLowerCase().indexOf(needle) >= 0
                                                    || app.package.toLowerCase().indexOf(needle) >= 0
                                            })
                                        }
                                        delegate: Row {
                                            required property var modelData
                                            width: parent.width
                                            height: 30
                                            spacing: 8
                                            Image {
                                                width: 22
                                                height: 22
                                                source: modelData.icon.length > 0
                                                        ? "file://" + modelData.icon : ""
                                                visible: modelData.icon.length > 0
                                                fillMode: Image.PreserveAspectFit
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            Text {
                                                width: parent.width - 480
                                                text: modelData.label
                                                color: root.textColor
                                                font.pixelSize: 10
                                                elide: Text.ElideRight
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            Text {
                                                width: 120
                                                text: modelData.package
                                                color: root.mutedColor
                                                font.pixelSize: 8
                                                elide: Text.ElideRight
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            ActionButton {
                                                label: root.tr("Open")
                                                onActivated: settings.openWaydroidApp(
                                                    modelData.package)
                                            }
                                            ActionButton {
                                                label: root.tr("Clear data")
                                                onActivated: settings.clearWaydroidAppData(
                                                    modelData.package)
                                            }
                                            ActionButton {
                                                label: root.tr("Uninstall")
                                                onActivated: settings.removeWaydroidApp(
                                                    modelData.package)
                                            }
                                        }
                                    }
                                    Component.onCompleted: {
                                        settings.refreshWaydroid()
                                        settings.refreshWaydroidApps()
                                    }

                                    Timer {
                                        interval: 15000
                                        repeat: true
                                        running: root.section === 3
                                        onTriggered: {
                                            settings.refreshWaydroid()
                                            settings.refreshWaydroidApps()
                                        }
                                    }
                                }

                                Card {
                                    visible: root.appsTab === 0
                                    SectionLabel { text: root.tr("INSTALLED APPLICATIONS") }
                                    Row {
                                        width: parent.width
                                        spacing: 8
                                        TextField {
                                            id: appSearch
                                            width: parent.width - 180
                                            height: 32
                                            placeholderText: root.tr("Search installed applications…")
                                            color: root.textColor
                                            font.pixelSize: 10
                                            selectByMouse: true
                                            leftPadding: 8
                                            background: Rectangle {
                                                radius: 8
                                                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.06)
                                                border.width: 1
                                                border.color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
                                            }
                                            onTextChanged: root.appFilter = text
                                        }
                                        ActionButton {
                                            label: root.tr("Package Installer")
                                            width: 164
                                            onActivated: settings.openPackageInstaller()
                                        }
                                    }
                                    Text {
                                        text: root.trCount(root.filteredApps.length,
                                                           settings.installedApps.length)
                                        color: root.mutedColor
                                        font.pixelSize: 8
                                    }
                                    Repeater {
                                        model: root.filteredApps
                                        delegate: Row {
                                            required property var modelData
                                            width: parent.width
                                            height: 40
                                            spacing: 10

                                            Column {
                                                width: parent.width - 110
                                                y: 6
                                                spacing: 1
                                                Text {
                                                    text: modelData.name
                                                    color: root.textColor
                                                    font.pixelSize: 10
                                                }
                                                Text {
                                                    text: root.detailText(modelData.detail)
                                                    color: root.mutedColor
                                                    font.pixelSize: 8
                                                    elide: Text.ElideRight
                                                    width: parent.width
                                                }
                                            }
                                            Rectangle {
                                                visible: modelData.removable !== true
                                                width: 70
                                                height: 22
                                                radius: 6
                                                y: 9
                                                color: "#1A1A22"
                                                border.width: 1
                                                border.color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.08)
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.tr("SYSTEM")
                                                    color: root.mutedColor
                                                    font.pixelSize: 7
                                                    font.letterSpacing: 0.8
                                                }
                                            }
                                            ActionButton {
                                                visible: modelData.removable === true
                                                label: root.tr("Uninstall")
                                                danger: true
                                                height: 28
                                                width: 86
                                                y: 6
                                                onActivated: root.confirm(
                                                    "Remove \"" + modelData.name + "\"?",
                                                    function () {
                                                        settings.uninstallApp(modelData.kind, modelData.id)
                                                    })
                                            }
                                        }
                                    }
                                    Text {
                                        visible: settings.installedApps.length === 0
                                        text: root.tr("No applications found. Flatpaks and packages installed with the Package Installer appear here.")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                        wrapMode: Text.WordWrap
                                    }
                                    Text {
                                        visible: settings.installedApps.length > 0
                                                 && root.filteredApps.length === 0
                                        text: root.tr("No applications match the search.")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                    }
                                }

                                Card {
                                    visible: root.appsTab === 1
                                    SectionLabel { text: root.tr("DEFAULT APPLICATIONS") }
                                    Repeater {
                                        model: settings.defaultApps
                                        delegate: Column {
                                            id: defaultRow
                                            required property var modelData
                                            width: parent.width
                                            spacing: 4

                                            Row {
                                                width: parent.width
                                                spacing: 8
                                                Text {
                                                    width: 140
                                                    text: defaultRow.modelData.label
                                                    color: root.textColor
                                                    font.pixelSize: 10
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    elide: Text.ElideRight
                                                }
                                                DarkComboBox {
                                                    id: defaultCombo
                                                    width: parent.width - 150
                                                    model: defaultRow.modelData.choices
                                                    textRole: "name"
                                                    Component.onCompleted: {
                                                        for (let i = 0; i < defaultRow.modelData.choices.length; ++i) {
                                                            if (defaultRow.modelData.choices[i].id === defaultRow.modelData.current) {
                                                                currentIndex = i
                                                                break
                                                            }
                                                        }
                                                    }
                                                    onActivated: settings.setDefaultApp(
                                                        defaultRow.modelData.mime,
                                                        defaultRow.modelData.choices[currentIndex].id)
                                                }
                                            }
                                            Item { width: 1; height: 2 }
                                        }
                                    }
                                }

                                Card {
                                    visible: root.appsTab === 2
                                    SectionLabel { text: root.tr("AUTOSTART") }
                                    Repeater {
                                        model: settings.autostartEntries
                                        delegate: ToggleRow {
                                            required property var modelData
                                            label: modelData.name
                                            description: modelData.detail
                                            checked: modelData.enabled
                                            onToggled: settings.setAutostart(
                                                modelData.path, !modelData.enabled)
                                        }
                                    }
                                    Text {
                                        visible: settings.autostartEntries.length === 0
                                        text: root.tr("No user autostart entries. Applications can add them to ~/.config/autostart.")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                        wrapMode: Text.WordWrap
                                    }
                                }

                            }

                            /* ---------------- Design ---------------- */
                            Column {
                                width: parent.width
                                visible: root.section === 4
                                spacing: 10

                                Card {
                                    SectionLabel { text: root.tr("SYSTEM SOUNDS") }
                                    Text {
                                        width: parent.width
                                        text: root.tr("Sounds for login, notifications, errors and the lock screen. Custom audio files can be selected per event.")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                        wrapMode: Text.WordWrap
                                    }
                                    Component.onCompleted: settings.loadSounds()
                                    Repeater {
                                        model: settings.soundEvents
                                        delegate: Row {
                                            required property var modelData
                                            width: parent.width
                                            height: 30
                                            spacing: 8
                                            Text {
                                                width: parent.width - 480
                                                text: root.tr(modelData.key === "startup" ? "Startup"
                                                              : modelData.key === "notification" ? "Notification"
                                                              : modelData.key === "error" ? "Error"
                                                              : modelData.key === "complete" ? "Complete"
                                                              : "Lock")
                                                color: root.textColor
                                                font.pixelSize: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            Text {
                                                width: 190
                                                text: modelData.path.split("/").pop()
                                                color: root.mutedColor
                                                font.pixelSize: 8
                                                elide: Text.ElideMiddle
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            ActionButton {
                                                label: root.tr("Test")
                                                onActivated: settings.playSoundEvent(modelData.key)
                                            }
                                            ActionButton {
                                                label: root.tr("Choose…")
                                                onActivated: settings.chooseSoundFile(modelData.key)
                                            }
                                            ActionButton {
                                                label: root.tr("Reset")
                                                onActivated: settings.resetSound(modelData.key)
                                            }
                                        }
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("APP WINDOWS") }
                                    Component.onCompleted: settings.loadAppMode()
                                    ToggleRow {
                                        label: root.tr("Metro app windows")
                                        description: root.tr("Applications open fullscreen like the Windows 8.1 Metro surface. Disable to use normal desktop windows.")
                                        checked: settings.metroApps
                                        onToggled: settings.setMetroApps(!settings.metroApps)
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("WALLPAPER") }
                                    Text {
                                        width: parent.width
                                        text: settings.wallpaperPath.length > 0
                                              ? settings.wallpaperPath
                                              : "System default"
                                        color: root.mutedColor
                                        font.pixelSize: 8
                                        elide: Text.ElideMiddle
                                    }
                                    Grid {
                                        width: parent.width
                                        columns: 4
                                        spacing: 8
                                        Repeater {
                                            model: settings.wallpapers
                                            delegate: Item {
                                                required property var modelData
                                                width: (parent.width - 24) / 4
                                                height: 100
                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: 10
                                                    color: root.backgroundColor
                                                    border.width: settings.wallpaperPath === modelData.path ? 1 : 0
                                                    border.color: root.accent
                                                    clip: true
                                                    Image {
                                                        anchors.fill: parent
                                                        anchors.margins: 3
                                                        source: "file://" + modelData.path
                                                        fillMode: Image.PreserveAspectCrop
                                                        asynchronous: true
                                                    }
                                                }
                                                Text {
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    anchors.bottom: parent.bottom
                                                    anchors.bottomMargin: 4
                                                    text: modelData.name
                                                    color: root.textColor
                                                    font.pixelSize: 8
                                                    elide: Text.ElideRight
                                                    width: parent.width - 10
                                                    horizontalAlignment: Text.AlignHCenter
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: settings.applyWallpaper(modelData.path)
                                                }
                                            }
                                        }
                                    }
                                    Text {
                                        visible: settings.wallpapers.length === 0
                                        text: root.tr("No wallpapers found in /usr/share/backgrounds/elvonos or ~/Pictures.")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                        wrapMode: Text.WordWrap
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("BACKGROUND IMAGE") }
                                    Text {
                                        text: settings.themeWallpaper.length > 0
                                              ? settings.themeWallpaper
                                              : root.tr("System wallpaper")
                                        color: root.mutedColor
                                        font.pixelSize: 8
                                        elide: Text.ElideMiddle
                                        width: parent.width
                                    }
                                    Row {
                                        width: parent.width
                                        spacing: 10
                                        Rectangle {
                                            width: 120
                                            height: 62
                                            radius: Math.max(4, settings.themeRadius - 4)
                                            color: root.backgroundColor
                                            clip: true
                                            border.width: 1
                                            border.color: Qt.rgba(root.borderColor.r,
                                                                  root.borderColor.g,
                                                                  root.borderColor.b, 0.22)
                                            Image {
                                                anchors.fill: parent
                                                source: root.backgroundImage
                                                fillMode: root.backgroundFillMode
                                            }
                                        }
                                        Column {
                                            width: parent.width - 130
                                            spacing: 6
                                            TextField {
                                                id: themeImagePath
                                                width: parent.width
                                                height: 30
                                                placeholderText: root.tr("Path to a background image")
                                                text: settings.themeWallpaper
                                                color: root.textColor
                                                placeholderTextColor: root.mutedColor
                                                font.pixelSize: 9
                                                leftPadding: 8
                                                selectByMouse: true
                                                background: Rectangle {
                                                    radius: 8
                                                    color: Qt.rgba(root.textColor.r, root.textColor.g,
                                                                   root.textColor.b, 0.06)
                                                    border.width: 1
                                                    border.color: Qt.rgba(root.borderColor.r,
                                                                          root.borderColor.g,
                                                                          root.borderColor.b, 0.22)
                                                }
                                                Connections {
                                                    target: settings
                                                    function onThemeChanged() {
                                                        themeImagePath.text = settings.themeWallpaper
                                                    }
                                                }
                                            }
                                            Row {
                                                spacing: 6
                                                ActionButton {
                                                    label: root.tr("Apply image")
                                                    height: 28
                                                    onActivated: settings.setThemeWallpaper(themeImagePath.text)
                                                }
                                                ActionButton {
                                                    label: root.tr("Current wallpaper")
                                                    height: 28
                                                    onActivated: settings.setThemeWallpaper(settings.wallpaperPath)
                                                }
                                                ActionButton {
                                                    label: root.tr("System wallpaper")
                                                    height: 28
                                                    onActivated: settings.setThemeWallpaper("")
                                                }
                                            }
                                        }
                                    }
                                    Row {
                                        width: parent.width
                                        spacing: 8
                                        Text {
                                            width: 110
                                            text: root.tr("Image fit")
                                            color: root.mutedColor
                                            font.pixelSize: 9
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        DarkComboBox {
                                            id: imageFillCombo
                                            width: 150
                                            model: [
                                                { "label": root.tr("Fill"), "value": "fill" },
                                                { "label": root.tr("Fit"), "value": "fit" },
                                                { "label": root.tr("Stretch"), "value": "stretch" }
                                            ]
                                            textRole: "label"
                                            Component.onCompleted: {
                                                for (let i = 0; i < model.length; ++i) {
                                                    if (model[i].value === settings.themeWallpaperFill) {
                                                        currentIndex = i
                                                        break
                                                    }
                                                }
                                            }
                                            onActivated: settings.setThemeWallpaperFill(model[currentIndex].value)
                                        }
                                        Text {
                                            text: root.tr("Background dim")
                                            color: root.mutedColor
                                            font.pixelSize: 9
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        VolumeSlider {
                                            id: dimSlider
                                            width: Math.max(80, parent.width - 430)
                                            from: 0
                                            to: 90
                                            stepSize: 5
                                            value: settings.themeWallpaperDim
                                            onPressedChanged: {
                                                if (!pressed)
                                                    settings.setThemeWallpaperDim(Math.round(value))
                                            }
                                        }
                                        Text {
                                            text: Math.round(dimSlider.value) + "%"
                                            color: root.textColor
                                            font.pixelSize: 9
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("THEME") }
                                    Grid {
                                        width: parent.width
                                        columns: 4
                                        spacing: 8
                                        Repeater {
                                            model: [
                                                { "code": "aero", "label": "Aero", "color": "#4CC2FF", "color2": "#8FD3FF" },
                                                { "code": "aurora", "label": "Aurora", "color": "#A06BFF", "color2": "#FF8FD8" },
                                                { "code": "emerald", "label": "Emerald", "color": "#35E0A0", "color2": "#A8FF7D" },
                                                { "code": "sunset", "label": "Sunset", "color": "#FF8A4C", "color2": "#FF5C8A" },
                                                { "code": "light", "label": "Light", "color": "#2A7ED6", "color2": "#6FB6FF" },
                                                { "code": "rose", "label": "Rose", "color": "#FF5CA8", "color2": "#FFD36E" },
                                                { "code": "mono", "label": "Mono", "color": "#D8DEE9", "color2": "#8C95A3" },
                                                { "code": "cyber", "label": "Cyber", "color": "#39FF14", "color2": "#00C8FF" }
                                            ]
                                            delegate: Column {
                                                required property var modelData
                                                spacing: 4
                                                Rectangle {
                                                    width: (parent.parent.width - 24) / 4
                                                    height: 46
                                                    radius: Math.max(4, settings.themeRadius - 5)
                                                    color: root.backgroundColor
                                                    clip: true
                                                    border.width: settings.themePreset === modelData.code ? 2 : 1
                                                    border.color: settings.themePreset === modelData.code
                                                                  ? "#FFFFFF" : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.15)
                                                    Image {
                                                        anchors.fill: parent
                                                        source: root.backgroundImage
                                                        fillMode: Image.PreserveAspectCrop
                                                        opacity: 0.7
                                                    }
                                                    Rectangle {
                                                        anchors.fill: parent
                                                        color: modelData.color
                                                        opacity: 0.32
                                                    }
                                                    Rectangle {
                                                        anchors.left: parent.left
                                                        anchors.right: parent.right
                                                        anchors.bottom: parent.bottom
                                                        height: 5
                                                        gradient: Gradient {
                                                            GradientStop { position: 0.0; color: modelData.color }
                                                            GradientStop { position: 1.0; color: modelData.color2 }
                                                        }
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: settings.applyTheme(modelData.code)
                                                    }
                                                }
                                                Text {
                                                    text: modelData.label
                                                    color: settings.themePreset === modelData.code
                                                           ? root.textColor : root.mutedColor
                                                    font.pixelSize: 8
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                }
                                            }
                                        }
                                    }
                                    Text {
                                        text: root.tr("Changes accent, panel, surface, text, borders, GTK applications, the Start mark and the dock.")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                        wrapMode: Text.WordWrap
                                        width: parent.width
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("CUSTOM COLOURS") }
                                    Grid {
                                        width: parent.width
                                        columns: 2
                                        spacing: 6
                                        Repeater {
                                            model: [
                                                { "role": "accent", "label": root.tr("Accent"), "prop": "themeAccent" },
                                                { "role": "accent2", "label": root.tr("Accent 2"), "prop": "themeAccent2" },
                                                { "role": "background", "label": root.tr("Background"), "prop": "themeBackground" },
                                                { "role": "panel", "label": root.tr("Panel"), "prop": "themePanel" },
                                                { "role": "surface", "label": root.tr("Surface"), "prop": "themeSurface" },
                                                { "role": "text", "label": root.tr("Text"), "prop": "themeText" },
                                                { "role": "muted", "label": root.tr("Muted text"), "prop": "themeMuted" },
                                                { "role": "border", "label": root.tr("Borders"), "prop": "themeBorder" }
                                            ]
                                            delegate: ThemeColorRow {
                                                required property var modelData
                                                width: (parent.width - 6) / 2
                                                role: modelData.role
                                                label: modelData.label
                                                value: root.themeValue(modelData.prop)
                                                onSubmitted: settings.setThemeColor(role, value)
                                            }
                                        }
                                    }
                                    Row {
                                        width: parent.width
                                        spacing: 8
                                        Text {
                                            width: 90
                                            text: root.tr("Corner radius")
                                            color: root.mutedColor
                                            font.pixelSize: 9
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        VolumeSlider {
                                            id: radiusSlider
                                            width: parent.width - 160
                                            from: 0
                                            to: 28
                                            stepSize: 1
                                            value: settings.themeRadius
                                            onPressedChanged: {
                                                if (!pressed)
                                                    settings.setThemeRadius(Math.round(value))
                                            }
                                        }
                                        Text {
                                            text: Math.round(radiusSlider.value)
                                            color: root.textColor
                                            font.pixelSize: 9
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    Row {
                                        width: parent.width
                                        spacing: 8
                                        Text {
                                            width: 90
                                            text: root.tr("Glass strength")
                                            color: root.mutedColor
                                            font.pixelSize: 9
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        VolumeSlider {
                                            id: glassSlider
                                            width: parent.width - 160
                                            from: 0
                                            to: 100
                                            stepSize: 5
                                            value: settings.themeGlass
                                            onPressedChanged: {
                                                if (!pressed)
                                                    settings.setThemeGlass(Math.round(value))
                                            }
                                        }
                                        Text {
                                            text: Math.round(glassSlider.value) + "%"
                                            color: root.textColor
                                            font.pixelSize: 9
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    Rectangle {
                                        width: parent.width
                                        height: 70
                                        radius: settings.themeRadius
                                        color: Qt.rgba(root.surfaceColor.r,
                                                       root.surfaceColor.g,
                                                       root.surfaceColor.b,
                                                       root.glassOpacity)
                                        border.width: 1
                                        border.color: Qt.rgba(root.borderColor.r,
                                                              root.borderColor.g,
                                                              root.borderColor.b, 0.28)
                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 10
                                            Rectangle {
                                                width: 30
                                                height: 30
                                                radius: Math.max(4, settings.themeRadius - 6)
                                                gradient: Gradient {
                                                    GradientStop { position: 0.0; color: root.accent }
                                                    GradientStop { position: 1.0; color: root.accent2 }
                                                }
                                            }
                                            Column {
                                                spacing: 2
                                                Text {
                                                    text: root.tr("Live preview")
                                                    color: root.textColor
                                                    font.pixelSize: 12
                                                    font.weight: Font.DemiBold
                                                }
                                                Text {
                                                    text: root.tr("Surface, text and accent sample")
                                                    color: root.mutedColor
                                                    font.pixelSize: 9
                                                }
                                            }
                                        }
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("THEME FILE") }
                                    TextField {
                                        id: themePath
                                        width: parent.width - 20
                                        height: 32
                                        placeholderText: root.tr("Path for import/export (empty = ~/Documents/ElvonOS-Theme.json)")
                                        color: root.textColor
                                        placeholderTextColor: root.mutedColor
                                        font.pixelSize: 9
                                        leftPadding: 8
                                        background: Rectangle {
                                            radius: 8
                                            color: Qt.rgba(root.textColor.r, root.textColor.g,
                                                           root.textColor.b, 0.06)
                                            border.width: 1
                                            border.color: Qt.rgba(root.borderColor.r,
                                                                  root.borderColor.g,
                                                                  root.borderColor.b, 0.22)
                                        }
                                    }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Export theme")
                                            onActivated: settings.exportTheme(themePath.text)
                                        }
                                        ActionButton {
                                            label: root.tr("Import theme")
                                            onActivated: settings.importTheme(themePath.text)
                                        }
                                        ActionButton {
                                            label: root.tr("Reset theme")
                                            onActivated: settings.resetTheme()
                                        }
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("PANELS") }
                                    Text {
                                        text: root.tr("Taskbar position")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                    }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Top")
                                            active: settings.taskbarPosition === "top"
                                            onActivated: settings.setTaskbarPosition("top")
                                        }
                                        ActionButton {
                                            label: root.tr("Bottom")
                                            active: settings.taskbarPosition === "bottom"
                                            onActivated: settings.setTaskbarPosition("bottom")
                                        }
                                    }
                                    Text {
                                        text: root.tr("Dock position")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                    }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Bottom")
                                            active: settings.dockPosition === "bottom"
                                            onActivated: settings.setDockPosition("bottom")
                                        }
                                        ActionButton {
                                            label: root.tr("Top")
                                            active: settings.dockPosition === "top"
                                            onActivated: settings.setDockPosition("top")
                                        }
                                    }
                                    Row {
                                        width: parent.width
                                        spacing: 8
                                        Text {
                                            text: root.tr("Taskbar height")
                                            color: root.mutedColor
                                            font.pixelSize: 9
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        VolumeSlider {
                                            id: taskbarHeightSlider
                                            width: parent.width - 170
                                            from: 44
                                            to: 72
                                            stepSize: 2
                                            value: settings.taskbarHeight
                                            onPressedChanged: {
                                                if (!pressed)
                                                    settings.setTaskbarHeight(Math.round(value))
                                            }
                                        }
                                        Text {
                                            text: Math.round(taskbarHeightSlider.value)
                                            color: root.textColor
                                            font.pixelSize: 9
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("STYLE") }
                                    Row {
                                        spacing: 10
                                        Rectangle {
                                            width: 28; height: 28; radius: 8
                                            color: settings.themeAccent; border.width: 1
                                            border.color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.25)
                                        }
                                        Column {
                                            Text { text: root.tr("ElvonOS Aero glass"); color: root.textColor; font.pixelSize: 10 }
                                            Text {
                                                text: root.tr("Dark translucent panels, cyan accents and frosted wallpaper strips.")
                                                color: root.mutedColor
                                                font.pixelSize: 9
                                            }
                                        }
                                    }
                                    Text {
                                        text: root.tr("The frosted taskbar and dock strips are generated from the boot wallpaper. A new wallpaper is shown immediately; the strips keep the original blur until the next boot.")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                        wrapMode: Text.WordWrap
                                        width: parent.width
                                    }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Open Pictures")
                                            onActivated: settings.openPath(
                                                settings.wallpaperPath.length > 0
                                                ? "/home/elvon/Pictures" : "/usr/share/backgrounds/elvonos")
                                        }
                                    }
                                }
                            }

                            /* ---------------- Time & Language ---------------- */
                            Column {
                                width: parent.width
                                visible: root.section === 5
                                spacing: 10

                                Card {
                                    SectionLabel { text: root.tr("TIMEZONE") }
                                    Text {
                                        text: root.tr("Current: ") + settings.currentTimezone
                                        color: root.textColor
                                        font.pixelSize: 10
                                    }
                                    Row {
                                        spacing: 8
                                        TextField {
                                            id: timezoneField
                                            width: 260
                                            height: 32
                                            text: settings.currentTimezone
                                            color: root.textColor
                                            font.pixelSize: 10
                                            selectByMouse: true
                                            leftPadding: 8
                                            placeholderText: root.tr("Continent/City")
                                            background: Rectangle {
                                                radius: 8
                                                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.06)
                                                border.width: 1
                                                border.color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
                                            }
                                        }
                                        ActionButton {
                                            label: root.tr("Apply timezone")
                                            onActivated: settings.setTimezone(timezoneField.text)
                                        }
                                    }
                                    Row {
                                        spacing: 8
                                        DarkComboBox {
                                            id: timezoneCombo
                                            width: 240
                                            model: root.commonTimezones
                                            textRole: "name"
                                            Component.onCompleted: {
                                                for (let i = 0; i < root.commonTimezones.length; ++i) {
                                                    if (root.commonTimezones[i].name === settings.currentTimezone) {
                                                        currentIndex = i
                                                        break
                                                    }
                                                }
                                            }
                                            onActivated: settings.setTimezone(
                                                root.commonTimezones[currentIndex].name)
                                        }
                                        ActionButton {
                                            label: root.tr("Apply")
                                            onActivated: settings.setTimezone(
                                                root.commonTimezones[timezoneCombo.currentIndex].name)
                                        }
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("LANGUAGE") }
                                    Text {
                                        text: root.tr("Current: ") + settings.currentLocale
                                        color: root.textColor
                                        font.pixelSize: 10
                                    }
                                    Row {
                                        spacing: 8
                                        DarkComboBox {
                                            id: localeCombo
                                            width: 240
                                            model: settings.locales
                                            textRole: "name"
                                            Component.onCompleted: {
                                                for (let i = 0; i < settings.locales.length; ++i) {
                                                    if (settings.locales[i].name === settings.currentLocale) {
                                                        currentIndex = i
                                                        break
                                                    }
                                                }
                                            }
                                            onActivated: settings.setLocale(
                                                settings.locales[currentIndex].name)
                                        }
                                        ActionButton {
                                            label: root.tr("Apply language")
                                            onActivated: settings.setLocale(
                                                settings.locales[localeCombo.currentIndex].name)
                                        }
                                    }
                                    Text {
                                        text: root.tr("The language is applied to new sessions and programs that read the system locale.")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                        wrapMode: Text.WordWrap
                                        width: parent.width
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("INTERFACE LANGUAGE") }
                                    Text {
                                        text: root.tr("The Settings interface changes immediately; the system locale is set above.")
                                        color: root.secondaryColor
                                        font.pixelSize: 9
                                        wrapMode: Text.WordWrap
                                        width: parent.width
                                    }
                                    Row {
                                        spacing: 8
                                        DarkComboBox {
                                            id: languageCombo
                                            width: 220
                                            model: [
                                                { "code": "en", "name": "English" },
                                                { "code": "de", "name": "Deutsch" },
                                                { "code": "fr", "name": "Français" },
                                                { "code": "es", "name": "Español" },
                                                { "code": "it", "name": "Italiano" },
                                                { "code": "pt", "name": "Português" },
                                                { "code": "nl", "name": "Nederlands" },
                                                { "code": "pl", "name": "Polski" },
                                                { "code": "ru", "name": "Русский" },
                                                { "code": "tr", "name": "Türkçe" },
                                                { "code": "uk", "name": "Українська" },
                                                { "code": "cs", "name": "Čeština" },
                                                { "code": "sv", "name": "Svenska" },
                                                { "code": "zh", "name": "简体中文" },
                                                { "code": "ja", "name": "日本語" }
                                            ]
                                            textRole: "name"
                                            Component.onCompleted: {
                                                for (let i = 0; i < model.length; ++i) {
                                                    if (model[i].code === Lang.language) {
                                                        currentIndex = i
                                                        break
                                                    }
                                                }
                                            }
                                            onActivated: Lang.setLanguage(model[currentIndex].code)
                                        }
                                        ActionButton {
                                            label: root.tr("Apply language")
                                            onActivated: Lang.setLanguage(languageCombo.model[languageCombo.currentIndex].code)
                                        }
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("CLOCK") }
                                    ToggleRow {
                                        label: root.tr("Automatic time (NTP)")
                                        description: root.tr("Keep the clock in sync with network time servers")
                                        checked: settings.ntpEnabled
                                        onToggled: settings.setNtp(!settings.ntpEnabled)
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("KEYBOARD") }
                                    Text {
                                        text: root.tr("Current layout: ") + settings.keyboardLayout
                                        color: root.textColor
                                        font.pixelSize: 10
                                    }
                                    Row {
                                        spacing: 8
                                        DarkComboBox {
                                            id: keyboardCombo
                                            width: 220
                                            model: ["us", "gb", "de", "fr", "es", "it",
                                                    "nl", "pt", "se", "dk", "no", "fi",
                                                    "pl", "cz", "hu", "gr", "tr", "ru",
                                                    "ua", "jp", "kr", "cn", "br", "ch",
                                                    "be", "at"]
                                            Component.onCompleted: {
                                                const index = model.indexOf(settings.keyboardLayout)
                                                if (index >= 0)
                                                    currentIndex = index
                                            }
                                            onActivated: settings.setKeyboardLayout(currentText)
                                        }
                                        ActionButton {
                                            label: root.tr("Apply layout")
                                            onActivated: settings.setKeyboardLayout(keyboardCombo.currentText)
                                        }
                                    }
                                    Text {
                                        text: root.tr("The layout is stored in environment.d and applies to new sessions.")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                        wrapMode: Text.WordWrap
                                        width: parent.width
                                    }
                                }
                            }

                            /* ---------------- Gaming & VR ---------------- */
                            Column {
                                width: parent.width
                                visible: root.section === 6
                                spacing: 10

                                Card {
                                    SectionLabel { text: root.tr("WINE / WINDOWS APPLICATIONS") }
                                    InfoRow {
                                        label: root.tr("Wine")
                                        value: root.statusText(settings.gamingStatus.wine || "")
                                    }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Install WineHQ")
                                            active: true
                                            onActivated: settings.gamingInstall("wine")
                                        }
                                        ActionButton {
                                            label: root.tr("Wine configuration")
                                            onActivated: settings.openWineConfig()
                                        }
                                        ActionButton {
                                            label: root.tr("Wine prefix")
                                            onActivated: settings.openWinePrefix()
                                        }
                                        ActionButton {
                                            label: root.tr("Refresh")
                                            onActivated: settings.refreshGaming()
                                        }
                                    }
                                    ToggleRow {
                                        label: root.tr("Open .exe files with Wine")
                                        description: root.tr("Registers Wine as the default handler for .exe/.msi and integrates with the Explorer via xdg-open")
                                        checked: settings.gamingStatus.handlerActive === true
                                        onToggled: settings.setWineHandler(
                                            settings.gamingStatus.handlerActive !== true)
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("VR RUNTIME") }
                                    InfoRow {
                                        label: root.tr("Monado")
                                        value: root.statusText(settings.gamingStatus.monado || "")
                                    }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Install Monado")
                                            active: true
                                            onActivated: settings.gamingInstall("monado")
                                        }
                                    }
                                    InfoRow {
                                        label: root.tr("WayVR")
                                        value: root.statusText(settings.gamingStatus.wayvr || "")
                                    }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Install WayVR")
                                            active: true
                                            onActivated: settings.gamingInstall("wayvr")
                                        }
                                    }
                                    Text {
                                        text: root.tr("Installations need an internet connection. Monado is the OpenXR runtime; WayVR provides a VR desktop overlay. The buttons use apt/Flatpak and show their full output in the log below.")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                        wrapMode: Text.WordWrap
                                        width: parent.width
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("GAMING TOOLS") }
                                    InfoRow {
                                        label: root.tr("Steam")
                                        value: root.statusText(settings.gamingStatus.steam || "")
                                    }
                                    ActionButton {
                                        label: root.tr("Install Steam")
                                        onActivated: settings.gamingInstall("steam")
                                    }
                                    InfoRow {
                                        label: root.tr("Lutris")
                                        value: root.statusText(settings.gamingStatus.lutris || "")
                                    }
                                    ActionButton {
                                        label: root.tr("Install Lutris")
                                        onActivated: settings.gamingInstall("lutris")
                                    }
                                    InfoRow {
                                        label: root.tr("MangoHud / GameMode")
                                        value: {
                                            const mh = settings.gamingStatus.mangohud !== undefined
                                                       && settings.gamingStatus.mangohud.length > 0
                                            const gm = settings.gamingStatus.gamemode !== undefined
                                                       && settings.gamingStatus.gamemode.length > 0
                                            if (!mh && !gm)
                                                return root.tr("Not installed")
                                            return (mh ? "MangoHud " : "") + (gm ? "GameMode" : "")
                                        }
                                    }
                                    InfoRow {
                                        label: root.tr("Winetricks")
                                        value: root.statusText(settings.gamingStatus.winetricks || "")
                                    }
                                    ActionButton {
                                        label: root.tr("Install MangoHud, GameMode & Winetricks")
                                        active: true
                                        onActivated: settings.gamingInstall("tools")
                                    }
                                }

                                LogCard {}
                            }

                            /* ---------------- Firewall ---------------- */
                            Column {
                                width: parent.width
                                visible: root.section === 7
                                spacing: 10

                                Card {
                                    SectionLabel { text: root.tr("NETWORK PROTECTION") }
                                    ToggleRow {
                                        label: root.tr("Firewall enabled")
                                        description: root.tr("The ElvonOS nftables protection layer (input filtering)")
                                        checked: settings.firewallOn
                                        onToggled: settings.setFirewall(!settings.firewallOn)
                                    }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Refresh rules")
                                            onActivated: settings.loadFirewall()
                                        }
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("NFTABLES RULESET") }
                                    Rectangle {
                                        width: parent.width
                                        height: 250
                                        radius: 10
                                        color: root.backgroundColor
                                        border.width: 1
                                        border.color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.08)
                                        clip: true

                                        Flickable {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            clip: true
                                            contentWidth: width
                                            contentHeight: rulesText.implicitHeight

                                            TextEdit {
                                                id: rulesText
                                                width: parent.width
                                                text: settings.firewallRules
                                                color: root.secondaryColor
                                                font.family: "DejaVu Sans Mono"
                                                font.pixelSize: 8
                                                wrapMode: TextEdit.Wrap
                                                readOnly: true
                                            }
                                        }
                                    }
                                }
                            }

                            /* ---------------- Privacy ---------------- */
                            Column {
                                width: parent.width
                                visible: root.section === 8
                                spacing: 10

                                Card {
                                    SectionLabel { text: root.tr("RECENT ACTIVITY") }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Clear recent files")
                                            onActivated: settings.clearRecentFiles()
                                        }
                                        ActionButton {
                                            label: root.tr("Clear clipboard")
                                            onActivated: settings.clearClipboard()
                                        }
                                    }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Clear thumbnails")
                                            onActivated: settings.clearThumbnails()
                                        }
                                        ActionButton {
                                            label: root.tr("Clear shell history")
                                            danger: true
                                            onActivated: settings.clearShellHistory()
                                        }
                                    }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Clear package cache")
                                            danger: true
                                            onActivated: root.confirm(
                                                "Clear the APT package cache? Downloads will need to be fetched again.",
                                                function () { settings.clearPackageCache() })
                                        }
                                        ActionButton {
                                            label: root.tr("Clear application cache")
                                            danger: true
                                            onActivated: root.confirm(
                                                "Clear all application caches in ~/.cache? Running applications may reload their data.",
                                                function () { settings.clearApplicationCache() })
                                        }
                                    }
                                    Text {
                                        text: root.tr("These actions remove the local recent-documents list, the clipboard contents, cached thumbnails, the bash history, APT archives and application caches.")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                        wrapMode: Text.WordWrap
                                        width: parent.width
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("PRIVACY INFORMATION") }
                                    Text {
                                        text: root.tr("ElvonOS does not run telemetry or analytics services. The Store and Aurora are separate applications; Android apps run inside Waydroid with microG. Search queries on the desktop stay local and are not stored.")
                                        color: root.secondaryColor
                                        font.pixelSize: 9
                                        wrapMode: Text.WordWrap
                                        width: parent.width
                                    }
                                }
                            }

                            /* ---------------- Updates ---------------- */
                            Column {
                                width: parent.width
                                visible: root.section === 9
                                spacing: 10

                                Card {
                                    SectionLabel { text: root.tr("ELVONOS UPDATES") }
                                    InfoRow {
                                        label: root.tr("Installed version")
                                        value: settings.elvonosVersion.length > 0
                                               ? settings.elvonosVersion : "–"
                                    }
                                    InfoRow {
                                        label: root.tr("Available version")
                                        value: settings.elvonosLatest.length > 0
                                               ? settings.elvonosLatest : "–"
                                    }
                                    InfoRow {
                                        label: root.tr("Last check")
                                        value: settings.elvonosCheckedAt.length > 0
                                               ? settings.elvonosCheckedAt : "–"
                                    }
                                    InfoRow {
                                        label: root.tr("OS package updates")
                                        value: String(settings.elvonosOsUpdates)
                                    }
                                    InfoRow {
                                        label: root.tr("Component updates")
                                        value: String(settings.elvonosComponentUpdates)
                                    }
                                    InfoRow {
                                        label: root.tr("Install updates on shutdown")
                                        value: settings.elvonosAutoShutdown
                                               ? root.tr("On") : root.tr("Off")
                                    }
                                    ActionButton {
                                        label: settings.elvonosAutoShutdown
                                               ? root.tr("Disable automatic shutdown updates")
                                               : root.tr("Enable automatic shutdown updates")
                                        onActivated: settings.setElvonosAutoShutdown(
                                                         !settings.elvonosAutoShutdown)
                                    }
                                    Text {
                                        visible: settings.elvonosComponentList.length > 0
                                        width: parent.width
                                        text: root.tr("Pending components: ")
                                              + settings.elvonosComponentList
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                        wrapMode: Text.WordWrap
                                    }
                                    Text {
                                        width: parent.width
                                        text: root.tr("The ElvonOS feed delivers signed system images and release notes; package updates stay in the system update card below.")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                        wrapMode: Text.WordWrap
                                    }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Check ElvonOS updates")
                                            active: true
                                            usable: !settings.elvonosBusy
                                            onActivated: settings.checkElvonosUpdate()
                                        }
                                        ActionButton {
                                            label: root.tr("Download update")
                                            usable: !settings.elvonosBusy
                                            onActivated: settings.downloadElvonosUpdate()
                                        }
                                        ActionButton {
                                            label: root.tr("Apply update")
                                            danger: true
                                            usable: !settings.elvonosBusy
                                            onActivated: settings.applyElvonosUpdate()
                                        }
                                    }
                                    Text {
                                        visible: settings.elvonosIsoAvailable
                                        width: parent.width
                                        text: root.tr("A new ISO is available. Use Download update to fetch it.")
                                        color: root.accent
                                        font.pixelSize: 9
                                        wrapMode: Text.WordWrap
                                    }
                                    Text {
                                        visible: settings.elvonosUpdateAvailable
                                        text: root.tr("An ElvonOS update is available.")
                                        color: root.accent
                                        font.pixelSize: 9
                                    }
                                    Rectangle {
                                        visible: settings.elvonosLog.length > 0
                                        width: parent.width
                                        height: 120
                                        radius: 7
                                        color: "#0c1117"
                                        border.width: 1
                                        border.color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
                                        Flickable {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            clip: true
                                            contentHeight: updateLogText.height
                                            Text {
                                                id: updateLogText
                                                width: parent.width
                                                text: settings.elvonosLog
                                                color: "#C9D1D9"
                                                font.family: "monospace"
                                                font.pixelSize: 8
                                                wrapMode: Text.WrapAnywhere
                                            }
                                        }
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("SYSTEM UPDATES") }
                                    Text {
                                        text: root.tr("This live system uses an ephemeral overlay. Updates apply to the running session and are lost on reboot; installed systems keep them.")
                                        color: root.secondaryColor
                                        font.pixelSize: 9
                                        wrapMode: Text.WordWrap
                                        width: parent.width
                                    }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Check for updates")
                                            active: true
                                            onActivated: settings.checkUpdates()
                                        }
                                        ActionButton {
                                            label: root.tr("Install updates")
                                            danger: true
                                            onActivated: root.confirm(
                                                "Install all available package updates now?",
                                                function () { settings.installUpdates() })
                                        }
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("AVAILABLE UPDATES") }
                                    Repeater {
                                        model: settings.updates
                                        delegate: Row {
                                            required property var modelData
                                            width: parent.width
                                            height: 26
                                            spacing: 8
                                            Text {
                                                width: parent.width - 160
                                                text: modelData.name
                                                color: root.textColor
                                                font.pixelSize: 10
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                width: 150
                                                text: modelData.version
                                                color: root.mutedColor
                                                font.pixelSize: 9
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                    Text {
                                        visible: settings.updates.length === 0
                                        text: root.tr("No update check has been run yet, or the system is up to date.")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                    }
                                }

                                LogCard {}
                            }

                            /* ---------------- Backups ---------------- */
                            Column {
                                width: parent.width
                                visible: root.section === 10
                                spacing: 10

                                Card {
                                    SectionLabel { text: root.tr("CREATE A BACKUP") }
                                    Text {
                                        text: root.tr("Archives Desktop, Documents, Downloads, Pictures, Music, Videos and the ElvonOS configuration into ~/Documents/Backups.")
                                        color: root.secondaryColor
                                        font.pixelSize: 9
                                        wrapMode: Text.WordWrap
                                        width: parent.width
                                    }
                                    Row {
                                        spacing: 8
                                        ActionButton {
                                            label: root.tr("Create backup")
                                            active: true
                                            onActivated: settings.createBackup()
                                        }
                                        ActionButton {
                                            label: root.tr("Open backups folder")
                                            onActivated: settings.openBackups()
                                        }
                                    }
                                }

                                Card {
                                    SectionLabel { text: root.tr("SAVED BACKUPS") }
                                    Repeater {
                                        model: settings.backups
                                        delegate: Column {
                                            required property var modelData
                                            width: parent.width
                                            spacing: 4

                                            Row {
                                                width: parent.width
                                                spacing: 8
                                                Column {
                                                    width: parent.width - 280
                                                    spacing: 1
                                                    Text {
                                                        text: modelData.name
                                                        color: root.textColor
                                                        font.pixelSize: 10
                                                        elide: Text.ElideRight
                                                        width: parent.width
                                                    }
                                                    Text {
                                                        text: modelData.date + "  ·  " + modelData.size
                                                        color: root.mutedColor
                                                        font.pixelSize: 8
                                                    }
                                                }
                                                ActionButton {
                                                    label: root.tr("Verify")
                                                    height: 28
                                                    width: 76
                                                    y: 6
                                                    onActivated: settings.verifyBackup(modelData.path)
                                                }
                                                ActionButton {
                                                    label: root.tr("Restore")
                                                    height: 28
                                                    width: 82
                                                    y: 6
                                                    onActivated: root.confirm(
                                                        "Restore \"" + modelData.name + "\"? Existing files may be overwritten.",
                                                        function () { settings.restoreBackup(modelData.path) })
                                                }
                                                ActionButton {
                                                    label: root.tr("Delete")
                                                    danger: true
                                                    height: 28
                                                    width: 76
                                                    y: 6
                                                    onActivated: root.confirm(
                                                        "Delete \"" + modelData.name + "\"?",
                                                        function () { settings.deleteBackup(modelData.path) })
                                                }
                                            }
                                            Rectangle { width: parent.width; height: 1; color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.05) }
                                        }
                                    }
                                    Text {
                                        visible: settings.backups.length === 0
                                        text: root.tr("No backups yet.")
                                        color: root.mutedColor
                                        font.pixelSize: 9
                                    }
                                }

                                LogCard {}
                            }
                        }
                    }
                }
            }
        }

        /* ---------------- footer ---------------- */

        Rectangle {
            width: parent.width
            height: 30
            radius: Math.max(6, root.cardRadius - 4)
            color: Qt.rgba(root.panelColor.r, root.panelColor.g,
                           root.panelColor.b, 0.68)

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: root.statusText(settings.status)
                color: root.accent
                font.pixelSize: 10
                elide: Text.ElideRight
                width: parent.width - 80
            }
            BusyIndicator {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                running: settings.busy
                visible: settings.busy
            }
        }
    }

    Dialog {
        id: wifiDialog
        property string ssid: ""
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        width: 430
        padding: 16

        background: Rectangle {
            color: Qt.rgba(root.surfaceColor.r, root.surfaceColor.g,
                           root.surfaceColor.b, 0.98)
            radius: root.cardRadius
            border.width: 1
            border.color: Qt.rgba(root.borderColor.r, root.borderColor.g,
                                  root.borderColor.b, 0.24)
        }

        contentItem: Column {
            spacing: 12

            Text {
                text: root.tr("CONNECT TO WI-FI")
                color: root.textColor
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 1.1
            }
            Text {
                text: wifiDialog.ssid
                color: root.accent
                font.pixelSize: 11
            }
            TextField {
                id: wifiPassword
                width: parent.width
                height: 32
                placeholderText: root.tr("Password (leave empty for open networks)")
                echoMode: TextInput.Password
                color: root.textColor
                font.pixelSize: 10
                selectByMouse: true
                leftPadding: 8
                background: Rectangle {
                    radius: 8
                    color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.06)
                    border.width: 1
                    border.color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.10)
                }
            }
            Row {
                width: parent.width
                spacing: 8
                layoutDirection: Qt.RightToLeft
                ActionButton {
                    label: root.tr("Connect")
                    active: true
                    width: 90
                    onActivated: {
                        wifiDialog.accept()
                        settings.connectWifi(wifiDialog.ssid, wifiPassword.text)
                    }
                }
                ActionButton {
                    label: root.tr("Cancel")
                    width: 84
                    onActivated: wifiDialog.reject()
                }
            }
        }
    }

    Dialog {
        id: confirmDialog
        property string message: ""
        property var confirmAction: null
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        width: 470
        padding: 16

        background: Rectangle {
            color: Qt.rgba(root.surfaceColor.r, root.surfaceColor.g,
                           root.surfaceColor.b, 0.98)
            radius: root.cardRadius
            border.width: 1
            border.color: Qt.rgba(root.borderColor.r, root.borderColor.g,
                                  root.borderColor.b, 0.24)
        }

        contentItem: Column {
            spacing: 12

            Text {
                text: root.tr("CONFIRM")
                color: root.textColor
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 1.1
            }
            Text {
                text: confirmDialog.message
                color: root.secondaryColor
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                width: 430
            }
            Row {
                width: parent.width
                spacing: 8
                layoutDirection: Qt.RightToLeft

                ActionButton {
                    label: root.tr("Confirm")
                    danger: true
                    width: 96
                    onActivated: {
                        const action = confirmDialog.confirmAction
                        confirmDialog.accept()
                        if (action)
                            action()
                    }
                }
                ActionButton {
                    label: root.tr("Cancel")
                    width: 84
                    onActivated: confirmDialog.reject()
                }
            }
        }
    }
}

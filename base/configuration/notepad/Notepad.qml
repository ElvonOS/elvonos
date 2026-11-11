import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: win

    function tr(text) {
        return lang.revision >= 0 ? lang.tr(text) : text
    }
    width: 1120
    height: 610
    minimumWidth: 900
    minimumHeight: 500
    visible: true
    color: theme.background

    property string currentPath: ""
    property string savedText: ""
    readonly property bool dirty: editor.text !== savedText
    readonly property string fileName: currentPath.length > 0
                                           ? currentPath.substring(currentPath.lastIndexOf("/") + 1)
                                           : win.tr("Untitled")
    property string statusMessage: ""
    property bool wordWrap: true
    property int fontSize: 15
    property int cursorLine: 1
    property int cursorColumn: 1
    property int wordCount: 0
    property string pendingAction: ""
    property bool saveThenPending: false
    property bool findVisible: false
    property bool replaceMode: false
    property bool caseSensitive: false
    property int matchCount: 0

    title: win.tr("Notepad — ") + fileName + (dirty ? " •" : "")

    Component.onCompleted: {
        win.requestActivate()
        Qt.callLater(function () { win.requestActivate() })
    }

    onClosing: function (close) {
        if (dirty) {
            close.accepted = false
            requestClose()
        }
    }

    Shortcut { sequence: "Ctrl+N"; onActivated: requestNew() }
    Shortcut { sequence: "Ctrl+O"; onActivated: requestOpen() }
    Shortcut { sequence: "Ctrl+S"; onActivated: saveDocument() }
    Shortcut { sequence: "Ctrl+Shift+S"; onActivated: showSave() }
    Shortcut { sequence: "Ctrl+Q"; onActivated: requestClose() }
    Shortcut { sequence: "Ctrl+W"; onActivated: requestClose() }
    Shortcut { sequence: "Ctrl+F"; onActivated: showFind(false) }
    Shortcut { sequence: "Ctrl+H"; onActivated: showFind(true) }
    Shortcut { sequence: "Ctrl+G"; onActivated: goToDialog.open() }
    Shortcut { sequence: "F5"; onActivated: insertDateTime() }
    Shortcut {
        sequence: "Escape"
        enabled: win.findVisible
        onActivated: closeFind()
    }
    Shortcut { sequence: "Ctrl+="; onActivated: fontSize = Math.min(40, fontSize + 1) }
    Shortcut { sequence: "Ctrl+-"; onActivated: fontSize = Math.max(9, fontSize - 1) }

    /* ---------------- helpers ---------------- */

    function resetDocument() {
        editor.text = ""
        savedText = ""
        currentPath = ""
        statusMessage = ""
        editor.cursorPosition = 0
    }

    function requestNew() {
        if (dirty) {
            pendingAction = "new"
            unsavedDialog.open()
        } else {
            resetDocument()
        }
    }

    function requestOpen() {
        if (dirty) {
            pendingAction = "open"
            unsavedDialog.open()
        } else {
            showOpen()
        }
    }

    function requestClose() {
        if (dirty) {
            pendingAction = "close"
            unsavedDialog.open()
        } else {
            Qt.quit()
        }
    }

    function performPending() {
        const action = pendingAction
        pendingAction = ""
        if (action === "new")
            resetDocument()
        else if (action === "open")
            showOpen()
        else if (action === "close")
            Qt.quit()
    }

    function showOpen() {
        browser.mode = "open"
        browser.selectedPath = ""
        browser.fileName = ""
        notepadModel.setDirectory(currentPath.length > 0
                                  ? currentPath.substring(0, currentPath.lastIndexOf("/"))
                                  : notepadModel.documentsPath())
        browser.open()
    }

    function showSave() {
        browser.mode = "save"
        browser.selectedPath = ""
        browser.fileName = currentPath.length > 0 ? fileName : "Untitled.txt"
        notepadModel.setDirectory(currentPath.length > 0
                                  ? currentPath.substring(0, currentPath.lastIndexOf("/"))
                                  : notepadModel.documentsPath())
        browser.open()
    }

    function openInitial(path) {
        if (path && path.length > 0)
            openFile(path)
    }

    function openFile(path) {
        const content = notepadModel.loadFile(path)
        if (notepadModel.lastError.length > 0) {
            statusMessage = notepadModel.lastError
            return
        }
        editor.text = content
        savedText = content
        currentPath = path
        statusMessage = win.tr("Opened ") + fileName
        editor.cursorPosition = 0
        notepadModel.addRecent(path)
    }

    function saveTo(path) {
        if (notepadModel.saveFile(path, editor.text)) {
            currentPath = path
            savedText = editor.text
            statusMessage = win.tr("Saved ") + fileName
            if (saveThenPending) {
                saveThenPending = false
                performPending()
            }
        } else {
            statusMessage = notepadModel.lastError
        }
    }

    function saveDocument() {
        if (currentPath.length === 0) {
            saveThenPending = false
            showSave()
            return
        }
        saveTo(currentPath)
    }

    function unsavedSave() {
        saveThenPending = true
        unsavedDialog.close()
        saveDocument()
    }

    function unsavedDiscard() {
        savedText = editor.text
        unsavedDialog.close()
        performPending()
    }

    function unsavedCancel() {
        pendingAction = ""
        saveThenPending = false
        unsavedDialog.close()
    }

    function updateStats() {
        const text = editor.text
        const position = Math.min(editor.cursorPosition, text.length)
        const before = text.substring(0, position)
        const lines = before.split("\n")
        cursorLine = lines.length
        cursorColumn = lines[lines.length - 1].length + 1
        const trimmed = text.trim()
        wordCount = trimmed.length === 0 ? 0 : trimmed.split(/\s+/).length
    }

    /* ---------------- find / replace ---------------- */

    function showFind(replace) {
        findVisible = true
        replaceMode = replace
        findField.forceActiveFocus()
        findField.selectAll()
        updateMatches()
    }

    function closeFind() {
        findVisible = false
        editor.forceActiveFocus()
    }

    function escapeRegExp(value) {
        return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
    }

    function matchRegex() {
        return new RegExp(escapeRegExp(findField.text),
                          caseSensitive ? "g" : "gi")
    }

    function updateMatches() {
        if (findField.text.length === 0) {
            matchCount = 0
            return
        }
        const matches = editor.text.match(matchRegex())
        matchCount = matches ? matches.length : 0
    }

    function selectMatch(position, length) {
        editor.cursorPosition = position
        editor.select(position, position + length)
    }

    function findNext(backwards) {
        const query = findField.text
        if (query.length === 0)
            return
        updateMatches()
        if (matchCount === 0) {
            statusMessage = win.tr("No matches for \"") + query + "\""
            return
        }
        if (backwards) {
            const before = editor.text.substring(0, editor.cursorPosition)
            let position = caseSensitive
                           ? before.lastIndexOf(query)
                           : before.toLowerCase().lastIndexOf(query.toLowerCase())
            if (position < 0) {
                const all = editor.text
                position = caseSensitive
                           ? all.lastIndexOf(query)
                           : all.toLowerCase().lastIndexOf(query.toLowerCase())
            }
            if (position >= 0)
                selectMatch(position, query.length)
            return
        }
        const flags = caseSensitive ? TextEdit.FindCaseSensitively : 0
        let position = editor.find(query, editor.cursorPosition, flags)
        if (position < 0)
            position = editor.find(query, 0, flags)
        if (position >= 0)
            selectMatch(position, query.length)
    }

    function replaceCurrent() {
        const query = findField.text
        if (query.length === 0)
            return
        if (editor.selectedText.length > 0
                && (caseSensitive
                    ? editor.selectedText === query
                    : editor.selectedText.toLowerCase() === query.toLowerCase())) {
            editor.insert(editor.cursorPosition, replaceField.text)
        }
        findNext(false)
    }

    function replaceAll() {
        const query = findField.text
        if (query.length === 0)
            return
        const regex = matchRegex()
        const replacement = replaceField.text
        let count = 0
        const result = editor.text.replace(regex, function () {
            ++count
            return replacement
        })
        if (count === 0) {
            statusMessage = win.tr("No matches for \"") + query + "\""
            return
        }
        editor.text = result
        updateMatches()
        statusMessage = win.tr("Replaced ") + count + win.tr(" matches")
    }

    function insertDateTime() {
        editor.insert(editor.cursorPosition,
                      Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm"))
        editor.forceActiveFocus()
    }

    function fileNameOf(path) {
        return path.substring(path.lastIndexOf("/") + 1)
    }

    /* ---------------- components ---------------- */

    component ActionButton: Rectangle {
        id: button
        property string label: ""
        property string glyph: ""
        property bool active: false
        signal activated()

        width: Math.max(70, labelText.implicitWidth + 30)
        height: 32
        radius: 9
        color: active ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.18) : (buttonHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086))
        border.width: active ? 1 : 0
        border.color: "#337ED6A5"

        Row {
            anchors.centerIn: parent
            spacing: 6
            Text {
                visible: button.glyph !== ""
                text: button.glyph
                color: button.active ? theme.accent : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.80)
                font.pixelSize: 12
            }
            Text {
                id: labelText
                text: button.label
                color: theme.text
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
        property color hoverColor: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14)
        property color glyphColor: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.85)
        signal activated()

        width: 30
        height: 30
        radius: 8
        color: wbHover.hovered ? hoverColor : "transparent"

        Text {
            anchors.centerIn: parent
            text: wb.glyph
            color: wbHover.hovered ? theme.text : wb.glyphColor
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

    component SmallButton: Rectangle {
        id: sb
        property string label: ""
        signal activated()

        width: Math.max(46, sbText.implicitWidth + 18)
        height: 30
        radius: 8
        color: sbHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086)

        Text {
            id: sbText
            anchors.centerIn: parent
            text: sb.label
            color: theme.text
            font.pixelSize: 10
        }
        HoverHandler { id: sbHover }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sb.activated()
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
                    color: "#227ED6A5"
                    border.width: 1
                    border.color: "#557ED6A5"
                    Text { anchors.centerIn: parent; text: "✎"; color: theme.light ? "#1E7A4D" : "#7ED6A5"; font.pixelSize: 17 }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        text: win.tr("NOTEPAD")
                        color: theme.text
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.2
                    }
                    Text {
                        text: fileName + (dirty ? win.tr(" • modified") : "")
                        color: dirty ? theme.accent : theme.muted
                        font.pixelSize: 9
                        elide: Text.ElideRight
                        width: 520
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
                    glyphColor: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.70)
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
                    onActivated: requestClose()
                }
            }
        }

        /* ---------------- Action bar ---------------- */
        Rectangle {
            width: parent.width
            height: 46
            radius: 14
            color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, theme.glass / 100)
            border.width: 1
            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                ActionButton { label: win.tr("New"); glyph: "＋"; onActivated: requestNew() }
                ActionButton { label: win.tr("Open"); glyph: "▸"; onActivated: requestOpen() }
                ActionButton {
                    label: win.tr("Save")
                    glyph: "▣"
                    active: dirty
                    onActivated: saveDocument()
                }
                ActionButton { label: win.tr("Save As"); glyph: "⇩"; onActivated: showSave() }

                Rectangle { width: 1; height: 24; color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12) }

                ActionButton {
                    label: win.tr("Find")
                    glyph: "⌕"
                    active: win.findVisible
                    onActivated: showFind(false)
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                ActionButton {
                    label: win.tr("Wrap")
                    active: win.wordWrap
                    onActivated: win.wordWrap = !win.wordWrap
                }

                Rectangle { width: 1; height: 24; color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12) }

                ActionButton {
                    width: 34
                    label: win.tr("A−")
                    onActivated: win.fontSize = Math.max(9, win.fontSize - 1)
                }
                Text {
                    text: win.fontSize
                    color: theme.muted
                    font.pixelSize: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    horizontalAlignment: Text.AlignHCenter
                }
                ActionButton {
                    width: 34
                    label: win.tr("A+")
                    onActivated: win.fontSize = Math.min(40, win.fontSize + 1)
                }
            }
        }

        /* ---------------- Editor ---------------- */
        Rectangle {
            width: parent.width
            height: parent.height - 70 - 46 - 30 - 30
            radius: 18
            color: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.80)
            border.width: 1
            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.15)
            clip: true

            Rectangle {
                id: findBar
                visible: win.findVisible
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 10
                height: 44
                radius: 10
                color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.93)
                border.width: 1
                border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.18)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    anchors.topMargin: 5
                    anchors.bottomMargin: 5
                    spacing: 6

                    Text {
                        text: "⌕"
                        color: theme.accent
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextField {
                        id: findField
                        width: 230
                        height: 30
                        placeholderText: win.tr("Find")
                        color: theme.text
                        font.pixelSize: 10
                        selectByMouse: true
                        leftPadding: 8
                        background: Rectangle {
                            radius: 7
                            color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14)
                            border.width: 1
                            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.15)
                        }
                        onTextChanged: win.updateMatches()
                        onAccepted: win.findNext(false)
                        Keys.onPressed: function (event) {
                            if (event.key === Qt.Key_Escape) {
                                win.closeFind()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return
                                       && (event.modifiers & Qt.ShiftModifier)) {
                                win.findNext(true)
                                event.accepted = true
                            }
                        }
                    }

                    Text {
                        width: 52
                        text: win.matchCount === 0
                              ? "—"
                              : win.matchCount + win.tr(" found")
                        color: win.matchCount === 0 ? theme.muted : theme.light ? "#2E8B57" : "#8FD3A8"
                        font.pixelSize: 9
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    SmallButton {
                        width: 32
                        label: win.tr("Aa")
                        onActivated: {
                            win.caseSensitive = !win.caseSensitive
                            win.updateMatches()
                        }
                    }

                    SmallButton {
                        width: 30
                        label: "↑"
                        onActivated: win.findNext(true)
                    }
                    SmallButton {
                        width: 30
                        label: "↓"
                        onActivated: win.findNext(false)
                    }

                    TextField {
                        id: replaceField
                        visible: win.replaceMode
                        width: 200
                        height: 30
                        placeholderText: win.tr("Replace with")
                        color: theme.text
                        font.pixelSize: 10
                        selectByMouse: true
                        leftPadding: 8
                        background: Rectangle {
                            radius: 7
                            color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14)
                            border.width: 1
                            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.15)
                        }
                        onAccepted: win.replaceCurrent()
                    }

                    SmallButton {
                        visible: win.replaceMode
                        width: 76
                        label: win.tr("Replace")
                        onActivated: win.replaceCurrent()
                    }
                    SmallButton {
                        visible: win.replaceMode
                        width: 94
                        label: win.tr("Replace All")
                        onActivated: win.replaceAll()
                    }

                    Item {
                        width: Math.max(0, parent.width
                                        - (win.replaceMode ? 866 : 478))
                        height: 1
                    }

                    SmallButton {
                        width: 30
                        label: "✕"
                        onActivated: win.closeFind()
                    }
                }
            }

            ScrollView {
                id: scroll
                anchors.fill: parent
                anchors.margins: 10
                anchors.topMargin: win.findVisible ? 64 : 10
                clip: true

                TextArea {
                    id: editor
                    text: ""
                    color: theme.text
                    selectionColor: "#337ED6A5"
                    selectedTextColor: theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.08) : "#0E1A14"
                    font.family: "DejaVu Sans Mono"
                    font.pixelSize: win.fontSize
                    leftPadding: 8
                    topPadding: 6
                    rightPadding: 8
                    bottomPadding: 6
                    wrapMode: win.wordWrap ? TextEdit.Wrap : TextEdit.NoWrap
                    width: win.wordWrap
                           ? scroll.availableWidth
                           : Math.max(scroll.availableWidth, implicitWidth)
                    background: null
                    selectByMouse: true
                    onTextChanged: win.updateStats()
                    onCursorPositionChanged: win.updateStats()

                    Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_Tab) {
                            editor.insert(editor.cursorPosition, "    ")
                            event.accepted = true
                        }
                    }
                }
            }

            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 22
                visible: editor.text.length === 0 && !win.findVisible
                text: win.tr("Start typing…")
                color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.60)
                font.family: "DejaVu Sans Mono"
                font.pixelSize: win.fontSize
            }
        }

        /* ---------------- Status bar ---------------- */
        Rectangle {
            width: parent.width
            height: 30
            radius: 10
            color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.60)

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 430
                text: statusMessage.length > 0
                      ? statusMessage
                      : (currentPath.length > 0 ? currentPath : win.tr("Plain Text · UTF-8"))
                color: statusMessage.length > 0 ? theme.light ? "#2E8B57" : "#8FD3A8" : theme.muted
                font.pixelSize: 10
                elide: Text.ElideMiddle
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: win.tr("Ln ") + cursorLine + win.tr(", Col ") + cursorColumn
                      + "   ·   " + wordCount + win.tr(" words")
                      + "   ·   " + editor.length + win.tr(" chars")
                      + (dirty ? win.tr("   ·   unsaved") : "")
                color: dirty ? theme.accent : theme.muted
                font.pixelSize: 10
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
        height: 520
        padding: 0

        property string mode: "open"
        property string selectedPath: ""
        property string fileName: ""

        background: Rectangle {
            color: theme.panel
            radius: 16
            border.width: 1
            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.20)
        }

        onAccepted: {
            if (mode === "open") {
                if (selectedPath.length > 0)
                    win.openFile(selectedPath)
            } else {
                const name = fileNameField.text.trim()
                if (name.length > 0)
                    win.saveTo(notepadModel.joinPath(notepadModel.directory, name))
            }
        }

        contentItem: Column {
            spacing: 10
            anchors.fill: parent
            anchors.margins: 14

            Text {
                text: browser.mode === "open" ? win.tr("OPEN FILE") : win.tr("SAVE FILE")
                color: theme.text
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2
            }

            Row {
                width: parent.width
                height: 30
                spacing: 8

                SmallButton { label: win.tr("↑ Up"); onActivated: notepadModel.goUp() }
                SmallButton { label: win.tr("Home"); onActivated: notepadModel.setDirectory(notepadModel.homePath()) }
                SmallButton { label: win.tr("Documents"); onActivated: notepadModel.setDirectory(notepadModel.documentsPath()) }

                TextField {
                    id: pathField
                    width: parent.width - 66 - 64 - 96 - 44 - 32
                    height: 30
                    text: notepadModel.directory
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
                    onAccepted: notepadModel.setDirectory(text)
                }

                SmallButton { label: win.tr("Go"); onActivated: notepadModel.setDirectory(pathField.text) }
            }

            Row {
                visible: browser.mode === "save"
                width: parent.width
                height: 30
                spacing: 8

                Text {
                    width: 70
                    height: parent.height
                    text: win.tr("File name")
                    color: theme.muted
                    font.pixelSize: 10
                    verticalAlignment: Text.AlignVCenter
                }
                TextField {
                    id: fileNameField
                    width: parent.width - 78
                    height: 30
                    text: browser.fileName
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
            }

            Row {
                visible: browser.mode === "open"
                         && notepadModel.recentFiles.length > 0
                width: parent.width
                height: 28
                spacing: 6

                Text {
                    text: win.tr("RECENT")
                    color: theme.muted
                    font.pixelSize: 8
                    font.letterSpacing: 1.2
                    anchors.verticalCenter: parent.verticalCenter
                }

                Repeater {
                    model: notepadModel.recentFiles

                    delegate: SmallButton {
                        required property string modelData
                        height: 26
                        width: Math.min(180, label.length * 6 + 20)
                        label: win.fileNameOf(modelData).length > 20
                               ? win.fileNameOf(modelData).substring(0, 19) + "…"
                               : win.fileNameOf(modelData)
                        onActivated: {
                            win.openFile(modelData)
                            browser.reject()
                        }
                    }
                }

                SmallButton {
                    width: 52
                    height: 26
                    label: win.tr("Clear")
                    onActivated: notepadModel.clearRecent()
                }
            }

            Rectangle {
                width: parent.width
                height: 330 - (browser.mode === "open"
                              && notepadModel.recentFiles.length > 0 ? 34 : 0)
                radius: 12
                color: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.60)
                border.width: 1
                border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)
                clip: true

                ListView {
                    anchors.fill: parent
                    anchors.margins: 6
                    clip: true
                    model: notepadModel.entries
                    spacing: 2

                    delegate: Rectangle {
                        required property string name
                        required property string path
                        required property bool isDir
                        required property string sizeText

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
                                    font.pixelSize: 12
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
                                if (isDir) {
                                    notepadModel.setDirectory(path)
                                    browser.selectedPath = ""
                                } else if (browser.mode === "save") {
                                    browser.fileName = name
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

                Item { width: parent.width - 206; height: 1 }

                SmallButton {
                    width: 90
                    label: win.tr("Cancel")
                    onActivated: browser.reject()
                }
                Rectangle {
                    width: 100
                    height: 32
                    radius: 9
                    color: (browser.mode === "open"
                            ? browser.selectedPath.length > 0
                            : fileNameField.text.trim().length > 0)
                           ? (acceptHover.hovered ? "#2A7ED6A5" : theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.14) : "#193326") : theme.light ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.10) : "#16202A"
                    border.width: 1
                    border.color: "#557ED6A5"
                    opacity: (browser.mode === "open"
                              ? browser.selectedPath.length > 0
                              : fileNameField.text.trim().length > 0) ? 1.0 : 0.4

                    Text {
                        anchors.centerIn: parent
                        text: browser.mode === "open" ? win.tr("Open") : win.tr("Save")
                        color: theme.text
                        font.pixelSize: 10
                    }
                    HoverHandler { id: acceptHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: browser.mode === "open"
                                 ? browser.selectedPath.length > 0
                                 : fileNameField.text.trim().length > 0
                        onClicked: browser.accept()
                    }
                }
            }
        }
    }

    /* ---------------- Unsaved changes ---------------- */
    Dialog {
        id: unsavedDialog
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        width: 470
        padding: 18

        background: Rectangle {
            color: theme.surface
            radius: 16
            border.width: 1
            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.20)
        }

        contentItem: Column {
            spacing: 14

            Text {
                text: win.tr("UNSAVED CHANGES")
                color: theme.text
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.letterSpacing: 1.1
            }
            Text {
                text: win.tr("Save the changes to \"") + fileName + win.tr("\" before continuing?")
                color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.80)
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                width: 420
            }

            Row {
                spacing: 8
                anchors.right: parent.right

                SmallButton { width: 90; label: win.tr("Cancel"); onActivated: win.unsavedCancel() }
                SmallButton { width: 110; label: win.tr("Discard"); onActivated: win.unsavedDiscard() }
                Rectangle {
                    width: 100
                    height: 30
                    radius: 9
                    color: saveHover.hovered ? "#2A7ED6A5" : theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.14) : "#193326"
                    border.width: 1
                    border.color: "#557ED6A5"
                    Text { anchors.centerIn: parent; text: win.tr("Save"); color: theme.text; font.pixelSize: 10 }
                    HoverHandler { id: saveHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.unsavedSave()
                    }
                }
            }
        }
    }

    /* ---------------- Go to line ---------------- */
    Dialog {
        id: goToDialog
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        width: 320
        padding: 16

        background: Rectangle {
            color: theme.surface
            radius: 14
            border.width: 1
            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.20)
        }

        contentItem: Column {
            spacing: 12

            Text {
                text: win.tr("GO TO LINE")
                color: theme.text
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 1.1
            }
            TextField {
                id: goToField
                width: parent.width
                height: 32
                placeholderText: win.tr("Line number")
                color: theme.text
                font.pixelSize: 11
                selectByMouse: true
                leftPadding: 10
                background: Rectangle {
                    radius: 8
                    color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14)
                    border.width: 1
                    border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.15)
                }
                onAccepted: goToDialog.accept()
            }
            Row {
                spacing: 8
                anchors.right: parent.right

                SmallButton {
                    width: 80
                    label: win.tr("Cancel")
                    onActivated: goToDialog.reject()
                }
                Rectangle {
                    width: 80
                    height: 30
                    radius: 9
                    color: goHover.hovered ? "#2A7ED6A5" : theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.14) : "#193326"
                    border.width: 1
                    border.color: "#557ED6A5"
                    Text { anchors.centerIn: parent; text: win.tr("Go"); color: theme.text; font.pixelSize: 10 }
                    HoverHandler { id: goHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: goToDialog.accept()
                    }
                }
            }
        }

        onOpened: {
            goToField.text = ""
            goToField.forceActiveFocus()
        }

        onAccepted: {
            let number = parseInt(goToField.text)
            if (isNaN(number))
                return
            const lines = editor.text.split("\n")
            number = Math.max(1, Math.min(number, lines.length))
            let position = 0
            for (let i = 0; i < number - 1; ++i)
                position += lines[i].length + 1
            editor.cursorPosition = position
            editor.forceActiveFocus()
            statusMessage = win.tr("Line ") + number
        }
    }
}

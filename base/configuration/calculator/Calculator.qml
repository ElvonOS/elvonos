import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: win

    function tr(text) {
        return lang.revision >= 0 ? lang.tr(text) : text
    }
    width: 1120
    height: 610
    minimumWidth: 960
    minimumHeight: 560
    visible: true
    color: theme.background

    property string displayText: "0"
    property string expressionText: ""
    property real accumulator: 0
    property string pendingOp: ""
    property bool replaceDisplay: true
    property real memoryValue: 0
    property bool hasMemory: false
    property string lastError: ""
    property bool scientificMode: false
    property bool secondFunction: false
    property bool radians: false

    title: win.tr("Calculator")

    Component.onCompleted: {
        win.requestActivate()
        Qt.callLater(function () {
            win.requestActivate()
            keyInput.forceActiveFocus()
        })
    }

    onActiveChanged: {
        if (active)
            keyInput.forceActiveFocus()
    }

    ListModel { id: historyModel }

    /* ---------------- calculator logic ---------------- */

    function opSymbol(op) {
        if (op === "*")
            return "×"
        if (op === "/")
            return "÷"
        if (op === "-")
            return "−"
        if (op === "^")
            return "^"
        return "+"
    }

    function formatNumber(value) {
        if (!isFinite(value))
            return win.tr("Error")
        const absolute = Math.abs(value)
        if (absolute !== 0 && (absolute >= 1e15 || absolute < 1e-9))
            return value.toExponential(8).replace(".", ",")
        let text = String(Number(value.toPrecision(12)))
        return text.replace(".", ",")
    }

    function parseDisplay() {
        const value = parseFloat(displayText.replace(",", "."))
        return isNaN(value) ? 0 : value
    }

    function clearAll() {
        displayText = "0"
        expressionText = ""
        accumulator = 0
        pendingOp = ""
        replaceDisplay = true
        lastError = ""
    }

    function fail() {
        displayText = win.tr("Error")
        expressionText = ""
        pendingOp = ""
        accumulator = 0
        replaceDisplay = true
        lastError = "1"
    }

    function inputDigit(digit) {
        if (lastError.length > 0)
            clearAll()
        if (replaceDisplay) {
            displayText = digit === "," ? "0," : digit
            replaceDisplay = false
            return
        }
        if (digit === ",") {
            if (!displayText.includes(","))
                displayText += ","
            return
        }
        if (displayText === "0")
            displayText = digit
        else
            displayText += digit
    }

    function compute(a, b, op) {
        if (op === "+")
            return a + b
        if (op === "-")
            return a - b
        if (op === "*")
            return a * b
        if (op === "/")
            return b === 0 ? NaN : a / b
        if (op === "^")
            return Math.pow(a, b)
        return b
    }

    function toRadians(value) {
        return radians ? value : value * Math.PI / 180
    }

    function fromRadians(value) {
        return radians ? value : value * 180 / Math.PI
    }

    function trig(kind) {
        applyUnary(kind, function (value) {
            if (kind === "sin")
                return Math.sin(toRadians(value))
            if (kind === "cos")
                return Math.cos(toRadians(value))
            if (kind === "tan")
                return Math.tan(toRadians(value))
            if (kind === "asin")
                return (value < -1 || value > 1)
                        ? NaN : fromRadians(Math.asin(value))
            if (kind === "acos")
                return (value < -1 || value > 1)
                        ? NaN : fromRadians(Math.acos(value))
            return fromRadians(Math.atan(value))
        })
    }

    function naturalLog() {
        applyUnary("ln", function (value) {
            return value <= 0 ? NaN : Math.log(value)
        })
    }

    function commonLog() {
        applyUnary("log", function (value) {
            return value <= 0 ? NaN : Math.log(value) / Math.LN10
        })
    }

    function exponential() {
        applyUnary("e^", function (value) {
            return Math.exp(value)
        })
    }

    function powerOfTen() {
        applyUnary("10^", function (value) {
            return Math.pow(10, value)
        })
    }

    function cubeRoot() {
        applyUnary("∛", function (value) {
            return Math.cbrt(value)
        })
    }

    function factorialValue(value) {
        if (value < 0 || value > 170 || value !== Math.floor(value))
            return NaN
        let result = 1
        for (let i = 2; i <= value; ++i)
            result *= i
        return result
    }

    function factorial() {
        applyUnary("x!", factorialValue)
    }

    function inputOperator(op) {
        if (lastError.length > 0)
            return
        const current = parseDisplay()
        if (pendingOp !== "" && !replaceDisplay) {
            const result = compute(accumulator, current, pendingOp)
            if (!isFinite(result)) {
                fail()
                return
            }
            accumulator = result
            displayText = formatNumber(result)
        } else if (pendingOp === "") {
            accumulator = current
        }
        pendingOp = op
        replaceDisplay = true
        expressionText = formatNumber(accumulator) + " " + opSymbol(op)
    }

    function equals() {
        if (lastError.length > 0 || pendingOp === "")
            return
        const current = parseDisplay()
        const result = compute(accumulator, current, pendingOp)
        if (!isFinite(result)) {
            fail()
            return
        }
        const expression = formatNumber(accumulator) + " "
                           + opSymbol(pendingOp) + " " + formatNumber(current)
        historyModel.insert(0, { expression: expression + " =",
                                 result: formatNumber(result) })
        while (historyModel.count > 60)
            historyModel.remove(historyModel.count - 1)
        expressionText = expression + " ="
        displayText = formatNumber(result)
        accumulator = result
        pendingOp = ""
        replaceDisplay = true
    }

    function backspace() {
        if (lastError.length > 0) {
            clearAll()
            return
        }
        if (replaceDisplay)
            return
        displayText = displayText.slice(0, -1)
        if (displayText.length === 0 || displayText === "-")
            displayText = "0"
    }

    function toggleSign() {
        if (lastError.length > 0)
            return
        if (displayText === "0")
            return
        displayText = displayText.startsWith("-")
                       ? displayText.substring(1)
                       : "-" + displayText
    }

    function applyUnary(label, functionValue) {
        if (lastError.length > 0)
            return
        const value = parseDisplay()
        const result = functionValue(value)
        if (!isFinite(result)) {
            fail()
            return
        }
        expressionText = label + "(" + formatNumber(value) + ") ="
        displayText = formatNumber(result)
        accumulator = result
        pendingOp = ""
        replaceDisplay = true
    }

    function percent() {
        applyUnary("%", function (value) { return value / 100 })
    }

    function squareRoot() {
        applyUnary("√", function (value) { return value < 0 ? NaN : Math.sqrt(value) })
    }

    function square() {
        applyUnary("sqr", function (value) { return value * value })
    }

    function reciprocal() {
        applyUnary("1/", function (value) { return value === 0 ? NaN : 1 / value })
    }

    function insertPi() {
        if (lastError.length > 0)
            clearAll()
        displayText = formatNumber(Math.PI)
        replaceDisplay = true
    }

    function insertE() {
        if (lastError.length > 0)
            clearAll()
        displayText = formatNumber(Math.E)
        replaceDisplay = true
    }

    /* ---------------- memory ---------------- */

    function memoryStore() {
        memoryValue = parseDisplay()
        hasMemory = true
    }

    function memoryRecall() {
        if (!hasMemory)
            return
        displayText = formatNumber(memoryValue)
        replaceDisplay = true
    }

    function memoryAdd() {
        memoryValue += parseDisplay()
        hasMemory = true
    }

    function memorySubtract() {
        memoryValue -= parseDisplay()
        hasMemory = true
    }

    function memoryClear() {
        memoryValue = 0
        hasMemory = false
    }

    function useHistoryResult(result) {
        displayText = result
        replaceDisplay = true
        lastError = ""
    }

    /* ---------------- components ---------------- */

    component Key: Rectangle {
        id: key
        property string label: ""
        property string hint: ""
        property bool accent: false
        property bool primary: false
        signal activated()

        radius: 12
        color: primary ? theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.14) : "#193326"
                        : (accent ? (keyHover.hovered ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.20) : Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.92))
                                  : (keyHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.125) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.08)))
        border.width: 1
        border.color: primary ? "#557ED6A5" : (accent ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.20) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12))

        Column {
            anchors.centerIn: parent
            spacing: 1
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: key.label
                color: key.primary ? theme.text : (key.accent ? theme.accent : theme.text)
                font.pixelSize: 16
                font.weight: key.primary ? Font.DemiBold : Font.Normal
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: key.hint !== ""
                text: key.hint
                color: theme.muted
                font.pixelSize: 8
            }
        }

        HoverHandler { id: keyHover }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: key.activated()
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

    Item {
        id: keyInput
        anchors.fill: parent
        focus: true
        z: -1

        Keys.onPressed: function (event) {
            const text = event.text
            if (text >= "0" && text <= "9") {
                win.inputDigit(text)
                event.accepted = true
                return
            }
            if (text === "." || text === ",") {
                win.inputDigit(",")
                event.accepted = true
                return
            }
            if (text === "+" || text === "-" || text === "*" || text === "/") {
                win.inputOperator(text)
                event.accepted = true
                return
            }
            if (text === "%") {
                win.percent()
                event.accepted = true
                return
            }
            if (text === "^") {
                win.inputOperator("^")
                event.accepted = true
                return
            }
            if (text === "!") {
                win.factorial()
                event.accepted = true
                return
            }
            switch (event.key) {
            case Qt.Key_Return:
            case Qt.Key_Enter:
                win.equals()
                event.accepted = true
                break
            case Qt.Key_Backspace:
                win.backspace()
                event.accepted = true
                break
            case Qt.Key_Escape:
            case Qt.Key_Delete:
                win.clearAll()
                event.accepted = true
                break
            }
        }
    }

    Shortcut { sequence: "Ctrl+Q"; onActivated: Qt.quit() }
    Shortcut { sequence: "Ctrl+W"; onActivated: Qt.quit() }
    Shortcut { sequence: "F9"; onActivated: toggleSign() }
    Shortcut { sequence: "Ctrl+E"; onActivated: win.scientificMode = !win.scientificMode }

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
                    Text { anchors.centerIn: parent; text: "="; color: theme.accent; font.pixelSize: 18; font.weight: Font.DemiBold }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        text: win.tr("CALCULATOR")
                        color: theme.text
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.2
                    }
                    Text {
                        text: (scientificMode ? win.tr("Scientific") : win.tr("Standard"))
                              + "  ·  " + (radians ? win.tr("RAD") : win.tr("DEG"))
                              + (hasMemory ? win.tr("  ·  memory ") + formatNumber(memoryValue) : "")
                        color: theme.muted
                        font.pixelSize: 9
                    }
                }

                Rectangle {
                    width: 72; height: 28; radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: scientificMode ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.18) : (sciHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.09) : "transparent")
                    border.width: scientificMode ? 1 : 0
                    border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.20)
                    Text {
                        anchors.centerIn: parent
                        text: win.tr("SCIENTIFIC")
                        color: scientificMode ? theme.accent : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.75)
                        font.pixelSize: 8
                        font.letterSpacing: 0.8
                    }
                    HoverHandler { id: sciHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.scientificMode = !win.scientificMode
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

        /* ---------------- Display + keypad + history ---------------- */
        Row {
            width: parent.width
            height: parent.height - 70 - 10
            spacing: 10

            Column {
                width: parent.width - 392
                height: parent.height
                spacing: 10

                /* Display */
                Rectangle {
                    width: parent.width
                    height: 128
                    radius: 16
                    color: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.80)
                    border.width: 1
                    border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.15)

                    Column {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 4

                        Row {
                            width: parent.width
                            height: 18

                            Text {
                                text: expressionText
                                color: theme.muted
                                font.pixelSize: 11
                                width: parent.width - 40
                                elide: Text.ElideLeft
                                horizontalAlignment: Text.AlignRight
                            }
                            Item { width: 8; height: 1 }
                            Rectangle {
                                visible: hasMemory
                                width: 22; height: 18; radius: 5
                                color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.92)
                                border.width: 1
                                border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.20)
                                Text { anchors.centerIn: parent; text: win.tr("M"); color: theme.accent; font.pixelSize: 9; font.weight: Font.DemiBold }
                            }
                        }

                        Text {
                            width: parent.width
                            text: displayText
                            color: lastError.length > 0 ? theme.light ? "#B3261E" : "#FFB4B0" : theme.text
                            font.pixelSize: displayText.length > 16 ? 28
                                          : (displayText.length > 11 ? 34 : 42)
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideLeft
                            maximumLineCount: 1
                        }
                    }
                }

                /* Keypad */
                Column {
                    id: keypad
                    width: parent.width
                    height: parent.height - 128 - 10
                    spacing: 8

                    readonly property real keyWidth: (width - 3 * 8) / 4
                    readonly property real sciWidth: (width - 5 * 8) / 6
                    readonly property real keyHeight: (height - (win.scientificMode ? 9 : 6) * 8)
                                                        / (win.scientificMode ? 10 : 7)

                    Row {
                        visible: win.scientificMode
                        spacing: 8
                        Key {
                            width: keypad.sciWidth; height: keypad.keyHeight
                            label: win.tr("2nd"); accent: win.secondFunction
                            onActivated: win.secondFunction = !win.secondFunction
                        }
                        Key {
                            width: keypad.sciWidth; height: keypad.keyHeight
                            label: win.radians ? win.tr("RAD") : win.tr("DEG")
                            onActivated: win.radians = !win.radians
                        }
                        Key {
                            width: keypad.sciWidth; height: keypad.keyHeight
                            label: win.secondFunction ? "asin" : "sin"
                            onActivated: trig(win.secondFunction ? "asin" : "sin")
                        }
                        Key {
                            width: keypad.sciWidth; height: keypad.keyHeight
                            label: win.secondFunction ? "acos" : "cos"
                            onActivated: trig(win.secondFunction ? "acos" : "cos")
                        }
                        Key {
                            width: keypad.sciWidth; height: keypad.keyHeight
                            label: win.secondFunction ? "atan" : "tan"
                            onActivated: trig(win.secondFunction ? "atan" : "tan")
                        }
                        Key {
                            width: keypad.sciWidth; height: keypad.keyHeight
                            label: win.tr("x^y"); accent: true
                            onActivated: inputOperator("^")
                        }
                    }

                    Row {
                        visible: win.scientificMode
                        spacing: 8
                        Key {
                            width: keypad.sciWidth; height: keypad.keyHeight
                            label: win.secondFunction ? win.tr("e^x") : "ln"
                            onActivated: win.secondFunction ? exponential() : naturalLog()
                        }
                        Key {
                            width: keypad.sciWidth; height: keypad.keyHeight
                            label: win.secondFunction ? win.tr("10^x") : "log"
                            onActivated: win.secondFunction ? powerOfTen() : commonLog()
                        }
                        Key {
                            width: keypad.sciWidth; height: keypad.keyHeight
                            label: win.secondFunction ? "∛" : "√"
                            onActivated: win.secondFunction ? cubeRoot() : squareRoot()
                        }
                        Key {
                            width: keypad.sciWidth; height: keypad.keyHeight
                            label: win.tr("x!")
                            onActivated: factorial()
                        }
                        Key {
                            width: keypad.sciWidth; height: keypad.keyHeight
                            label: "π"
                            onActivated: insertPi()
                        }
                        Key {
                            width: keypad.sciWidth; height: keypad.keyHeight
                            label: win.tr("e")
                            onActivated: insertE()
                        }
                    }

                    Row {
                        spacing: 8
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: win.tr("MC"); onActivated: memoryClear() }
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: win.tr("MR"); onActivated: memoryRecall() }
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: win.tr("M+"); onActivated: memoryAdd() }
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: win.tr("M−"); onActivated: memorySubtract() }
                    }
                    Row {
                        spacing: 8
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: win.tr("C"); accent: true; onActivated: clearAll() }
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: "⌫"; accent: true; onActivated: backspace() }
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: "%"; onActivated: percent() }
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: "÷"; accent: true; onActivated: inputOperator("/") }
                    }
                    Row {
                        spacing: 8
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: "7"; onActivated: inputDigit("7") }
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: "8"; onActivated: inputDigit("8") }
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: "9"; onActivated: inputDigit("9") }
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: "×"; accent: true; onActivated: inputOperator("*") }
                    }
                    Row {
                        spacing: 8
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: "4"; onActivated: inputDigit("4") }
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: "5"; onActivated: inputDigit("5") }
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: "6"; onActivated: inputDigit("6") }
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: "−"; accent: true; onActivated: inputOperator("-") }
                    }
                    Row {
                        spacing: 8
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: "1"; onActivated: inputDigit("1") }
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: "2"; onActivated: inputDigit("2") }
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: "3"; onActivated: inputDigit("3") }
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: "+"; accent: true; onActivated: inputOperator("+") }
                    }
                    Row {
                        spacing: 8
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: "±"; onActivated: toggleSign() }
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: "0"; onActivated: inputDigit("0") }
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: ","; onActivated: inputDigit(",") }
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: "="; primary: true; onActivated: equals() }
                    }
                    Row {
                        spacing: 8
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: "√"; onActivated: squareRoot() }
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: win.tr("x²"); onActivated: square() }
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: win.tr("1/x"); onActivated: reciprocal() }
                        Key { width: keypad.keyWidth; height: keypad.keyHeight; label: "π"; onActivated: insertPi() }
                    }
                }
            }

            /* History */
            Rectangle {
                width: 382
                height: parent.height
                radius: 18
                color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.92)
                border.width: 1
                border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14)
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Row {
                        width: parent.width
                        height: 26

                        Text {
                            text: win.tr("HISTORY")
                            color: theme.muted
                            font.pixelSize: 9
                            font.letterSpacing: 1.3
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Item { width: parent.width - 60 - 70; height: 1 }
                        Text {
                            text: historyModel.count + win.tr(" entries")
                            color: theme.muted
                            font.pixelSize: 9
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        width: parent.width
                        height: 32
                        spacing: 8

                        Rectangle {
                            width: 80; height: 30; radius: 8
                            color: clearHistoryHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.14) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.086)
                            Text { anchors.centerIn: parent; text: win.tr("Clear"); color: theme.text; font.pixelSize: 10 }
                            HoverHandler { id: clearHistoryHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: historyModel.clear()
                            }
                        }

                        Text {
                            text: win.tr("Click a result to reuse it")
                            color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.70)
                            font.pixelSize: 9
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    ListView {
                        width: parent.width
                        height: parent.height - 26 - 32 - 16
                        clip: true
                        model: historyModel
                        spacing: 4

                        delegate: Rectangle {
                            required property string expression
                            required property string result

                            width: ListView.view ? ListView.view.width : 0
                            height: 52
                            radius: 9
                            color: historyHover.hovered ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.10) : Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.08)

                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Text {
                                    text: expression
                                    color: theme.muted
                                    font.pixelSize: 9
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                                Text {
                                    text: result
                                    color: theme.text
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                            }

                            HoverHandler { id: historyHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.useHistoryResult(result)
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: historyModel.count === 0
                            text: win.tr("No calculations yet")
                            color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.60)
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }
}

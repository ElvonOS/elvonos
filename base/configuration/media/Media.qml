import QtQuick
import QtQuick.Controls
import QtMultimedia

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

    property bool fullscreenMode: false
    property int selectedIndex: -1
    property real volumeLevel: 0.8
    property bool muted: false
    property string nowTitle: ""
    property string nowSubtitle: ""
    property string statusMessage: ""
    property int repeatMode: 0     // 0 off, 1 all, 2 one
    property bool shuffle: false
    property real playbackSpeed: 1.0
    property int sleepMinutes: 0
    property int sleepRemaining: 0

    ListModel { id: playlist }

    Timer {
        id: sleepTimer
        interval: 1000
        repeat: true
        running: win.sleepRemaining > 0
        onTriggered: {
            win.sleepRemaining = win.sleepRemaining - 1
            if (win.sleepRemaining <= 0) {
                win.sleepRemaining = 0
                win.sleepMinutes = 0
                player.pause()
                win.statusMessage = win.tr("Sleep timer finished")
            }
        }
    }

    title: win.tr("Media Player — ") + (nowTitle.length > 0 ? nowTitle : win.tr("No media"))

    Component.onCompleted: {
        win.requestActivate()
        win.volumeLevel = mediaModel.loadSetting("volume", 0.8)
        win.muted = mediaModel.loadSetting("muted", false)
        win.repeatMode = mediaModel.loadSetting("repeat", 0)
        win.shuffle = mediaModel.loadSetting("shuffle", false)
        win.playbackSpeed = mediaModel.loadSetting("speed", 1.0)

        const saved = mediaModel.loadPlaylist()
        for (let i = 0; i < saved.length; ++i) {
            if (saved[i].length > 0)
                playlist.append({ path: saved[i],
                                  name: mediaModel.baseName(saved[i]),
                                  url: mediaModel.urlFor(saved[i]) })
        }
        if (playlist.count > 0) {
            const savedIndex = Math.min(mediaModel.loadSetting("index", 0),
                                        playlist.count - 1)
            win.selectedIndex = savedIndex
            const item = playlist.get(savedIndex)
            player.source = item.url
            win.nowTitle = item.name
            win.nowSubtitle = win.tr("Press play to resume")
        }

        Qt.callLater(function () {
            win.requestActivate()
            const args = Qt.application.arguments
            for (let i = 1; i < args.length; ++i) {
                if (!args[i].startsWith("-")) {
                    win.addPath(args[i], true)
                    break
                }
            }
        })
    }

    onVolumeLevelChanged: mediaModel.saveSetting("volume", volumeLevel)
    onMutedChanged: mediaModel.saveSetting("muted", muted)
    onRepeatModeChanged: mediaModel.saveSetting("repeat", repeatMode)
    onShuffleChanged: mediaModel.saveSetting("shuffle", shuffle)
    onPlaybackSpeedChanged: mediaModel.saveSetting("speed", playbackSpeed)
    onSelectedIndexChanged: mediaModel.saveSetting("index", selectedIndex)

    Shortcut { sequence: "Space"; onActivated: togglePlay() }
    Shortcut { sequence: "Left"; onActivated: seekBy(-5000) }
    Shortcut { sequence: "Right"; onActivated: seekBy(5000) }
    Shortcut { sequence: "Up"; onActivated: changeVolume(0.05) }
    Shortcut { sequence: "Down"; onActivated: changeVolume(-0.05) }
    Shortcut { sequence: "M"; onActivated: win.muted = !win.muted }
    Shortcut { sequence: "R"; onActivated: cycleRepeat() }
    Shortcut { sequence: "S"; onActivated: win.shuffle = !win.shuffle }
    Shortcut { sequence: "["; onActivated: speedStep(-1) }
    Shortcut { sequence: "]"; onActivated: speedStep(1) }
    Shortcut { sequence: "F"; onActivated: toggleFullscreen() }
    Shortcut { sequence: "Ctrl+O"; onActivated: browser.open() }
    Shortcut { sequence: "Ctrl+Q"; onActivated: Qt.quit() }
    Shortcut { sequence: "Ctrl+W"; onActivated: Qt.quit() }

    /* ---------------- playback helpers ---------------- */

    function formatTime(ms) {
        if (!isFinite(ms) || ms <= 0)
            return "0:00"
        let total = Math.floor(ms / 1000)
        const seconds = total % 60
        total = Math.floor(total / 60)
        const minutes = total % 60
        const hours = Math.floor(total / 60)
        if (hours > 0)
            return hours + ":" + (minutes < 10 ? "0" : "") + minutes
                   + ":" + (seconds < 10 ? "0" : "") + seconds
        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds
    }

    function addPath(path, playNow) {
        const url = mediaModel.urlFor(path)
        let existing = -1
        for (let i = 0; i < playlist.count; ++i) {
            if (playlist.get(i).path === path) {
                existing = i
                break
            }
        }
        if (existing < 0) {
            playlist.append({ path: path, name: mediaModel.baseName(path), url: url })
            existing = playlist.count - 1
            persistPlaylist()
        }
        if (playNow)
            playIndex(existing)
    }

    function persistPlaylist() {
        const paths = []
        for (let i = 0; i < playlist.count; ++i)
            paths.push(playlist.get(i).path)
        mediaModel.savePlaylist(paths)
    }

    function addUrl(url) {
        if (url.length === 0)
            return
        playlist.append({ path: url, name: url, url: url })
        persistPlaylist()
        playIndex(playlist.count - 1)
    }

    function cycleSpeed() {
        const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
        let index = speeds.indexOf(playbackSpeed)
        if (index < 0)
            index = 2
        playbackSpeed = speeds[(index + 1) % speeds.length]
    }

    function cycleRepeat() {
        repeatMode = (repeatMode + 1) % 3
    }

    function speedStep(delta) {
        const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
        let index = speeds.indexOf(playbackSpeed)
        if (index < 0)
            index = 2
        index = Math.max(0, Math.min(speeds.length - 1, index + delta))
        playbackSpeed = speeds[index]
    }

    function cycleSleep() {
        const options = [0, 15, 30, 60, 90]
        let index = options.indexOf(sleepMinutes)
        if (index < 0)
            index = 0
        sleepMinutes = options[(index + 1) % options.length]
        sleepRemaining = sleepMinutes * 60
        statusMessage = sleepMinutes > 0
                        ? win.tr("Sleep timer: ") + sleepMinutes + win.tr(" min")
                        : win.tr("Sleep timer off")
    }

    function moveSelected(delta) {
        if (selectedIndex < 0)
            return
        const target = selectedIndex + delta
        if (target < 0 || target >= playlist.count)
            return
        playlist.move(selectedIndex, target)
        selectedIndex = target
        persistPlaylist()
    }

    function playPath(path) {
        addPath(path, true)
    }

    function playIndex(index) {
        if (index < 0 || index >= playlist.count)
            return
        selectedIndex = index
        const item = playlist.get(index)
        player.source = item.url
        nowTitle = item.name
        nowSubtitle = ""
        player.play()
        playlistView.positionViewAtIndex(index, ListView.Contain)
    }

    function togglePlay() {
        if (playlist.count === 0) {
            browser.open()
            return
        }
        if (player.playbackState === MediaPlayer.PlayingState)
            player.pause()
        else
            player.play()
    }

    function seekBy(delta) {
        if (player.duration > 0)
            player.position = Math.max(0, Math.min(player.duration,
                                                   player.position + delta))
    }

    function changeVolume(delta) {
        win.volumeLevel = Math.max(0, Math.min(1, win.volumeLevel + delta))
        win.muted = false
    }

    function next() {
        if (playlist.count === 0)
            return
        if (repeatMode === 2) {
            player.position = 0
            player.play()
            return
        }
        if (shuffle && playlist.count > 1) {
            let pick = selectedIndex
            while (pick === selectedIndex)
                pick = Math.floor(Math.random() * playlist.count)
            playIndex(pick)
            return
        }
        let index = selectedIndex + 1
        if (index >= playlist.count) {
            if (repeatMode === 1) {
                index = 0
            } else {
                player.stop()
                return
            }
        }
        playIndex(index)
    }

    function previous() {
        if (playlist.count === 0)
            return
        if (player.position > 3000) {
            player.position = 0
            return
        }
        if (shuffle && playlist.count > 1) {
            let pick = selectedIndex
            while (pick === selectedIndex)
                pick = Math.floor(Math.random() * playlist.count)
            playIndex(pick)
            return
        }
        let index = selectedIndex - 1
        if (index < 0)
            index = repeatMode === 1 ? playlist.count - 1 : 0
        playIndex(index)
    }

    function removeSelected() {
        if (selectedIndex < 0 || selectedIndex >= playlist.count)
            return
        const wasPlaying = selectedIndex
        playlist.remove(selectedIndex)
        persistPlaylist()
        if (playlist.count === 0) {
            player.stop()
            player.source = ""
            selectedIndex = -1
            nowTitle = ""
            nowSubtitle = ""
        } else {
            playIndex(Math.min(wasPlaying, playlist.count - 1))
        }
    }

    function addAllInDirectory(path) {
        const files = mediaModel.mediaInDirectory(path)
        for (let i = 0; i < files.length; ++i)
            addPath(files[i], false)
        if (files.length > 0 && selectedIndex < 0)
            statusMessage = win.tr("Added ") + files.length + win.tr(" files")
        else if (files.length === 0)
            statusMessage = win.tr("No media files in this folder")
    }

    function refreshNowPlaying() {
        let title = ""
        try {
            title = player.metaData.stringValue(MediaMetaData.Title)
        } catch (error) {
            title = ""
        }
        if (title.length > 0)
            nowTitle = title
        let artist = ""
        try {
            artist = player.metaData.stringValue(MediaMetaData.ContributingArtist)
        } catch (error) {
            artist = ""
        }
        if (artist.length === 0) {
            try {
                artist = player.metaData.stringValue(MediaMetaData.AlbumArtist)
            } catch (error) {
                artist = ""
            }
        }
        nowSubtitle = artist
    }

    function toggleFullscreen() {
        fullscreenMode = !fullscreenMode
        if (fullscreenMode)
            win.showFullScreen()
        else
            win.showNormal()
    }

    MediaPlayer {
        id: player
        audioOutput: AudioOutput {
            volume: win.muted ? 0 : win.volumeLevel
        }
        videoOutput: videoOut

        playbackRate: win.playbackSpeed

        onMediaStatusChanged: {
            if (mediaStatus !== MediaPlayer.EndOfMedia)
                return
            if (win.repeatMode === 2) {
                player.position = 0
                player.play()
            } else {
                win.next()
            }
        }
        onMetaDataChanged: win.refreshNowPlaying()
        onErrorOccurred: function (error, message) {
            win.statusMessage = message
        }
        onSourceChanged: win.refreshNowPlaying()
    }

    /* ---------------- components ---------------- */

    component ActionButton: Rectangle {
        id: button
        property string label: ""
        property string glyph: ""
        property bool active: false
        property bool compact: false
        signal activated()

        width: compact ? 34 : Math.max(70, labelText.implicitWidth + 30)
        height: compact ? 32 : 32
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
                font.pixelSize: 14
            }
            Text {
                id: labelText
                visible: button.label !== ""
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

    /* ---------------- shared seek/volume slider ---------------- */

    component SeekBar: Slider {
        id: bar
        property color fillColor: theme.accent2
        signal seeked(real ratio)

        from: 0
        to: 1
        stepSize: 0
        onMoved: bar.seeked(bar.value)

        background: Rectangle {
            x: 0
            y: (parent.height - 4) / 2
            width: parent.width
            height: 4
            radius: 2
            color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.15)

            Rectangle {
                width: Math.max(0, Math.min(1, bar.visualPosition)) * parent.width
                height: parent.height
                radius: 2
                color: bar.fillColor
            }
        }

        handle: Rectangle {
            x: bar.leftPadding + bar.visualPosition * (bar.availableWidth - width)
            y: (bar.height - height) / 2
            width: 12
            height: 12
            radius: 6
            color: theme.text
            border.width: bar.pressed ? 2 : 1
            border.color: bar.fillColor
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
        anchors.margins: win.fullscreenMode ? 0 : 14
        spacing: win.fullscreenMode ? 0 : 10

        /* ---------------- Title bar ---------------- */
        Rectangle {
            id: titleBar
            visible: !win.fullscreenMode
            width: parent.width
            height: visible ? 70 : 0
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
                    Text { anchors.centerIn: parent; text: "▶"; color: theme.accent; font.pixelSize: 15 }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        text: win.tr("MEDIA PLAYER")
                        color: theme.text
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.2
                    }
                    Text {
                        text: nowTitle.length > 0
                              ? nowTitle + (nowSubtitle.length > 0 ? "  ·  " + nowSubtitle : "")
                              : win.tr("Music and video")
                        color: theme.muted
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

        /* ---------------- Stage + playlist ---------------- */
        Row {
            width: parent.width
            height: parent.height - (titleBar.visible ? 70 : 0)
                    - controlBar.height
                    - (win.fullscreenMode ? 0 : 20)
            spacing: win.fullscreenMode ? 0 : 10

            Rectangle {
                width: win.fullscreenMode ? parent.width
                                          : parent.width - 316
                height: parent.height
                radius: win.fullscreenMode ? 0 : 18
                color: theme.background
                border.width: win.fullscreenMode ? 0 : 1
                border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.15)
                clip: true

                VideoOutput {
                    id: videoOut
                    anchors.fill: parent
                    fillMode: VideoOutput.PreserveAspectFit
                }

                Column {
                    visible: !player.hasVideo
                    anchors.centerIn: parent
                    spacing: 10

                    Rectangle {
                        width: 92; height: 92; radius: 46
                        color: Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.92)
                        border.width: 1
                        border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.16)
                        anchors.horizontalCenter: parent.horizontalCenter
                        Text {
                            anchors.centerIn: parent
                            text: "♫"
                            color: theme.accent
                            font.pixelSize: 40
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: nowTitle.length > 0 ? nowTitle : win.tr("No media loaded")
                        color: nowTitle.length > 0 ? theme.text : Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.70)
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: nowSubtitle.length > 0
                              ? nowSubtitle
                              : (nowTitle.length > 0 ? win.tr("Audio") : win.tr("Add music or video from the playlist"))
                        color: theme.muted
                        font.pixelSize: 10
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 12
                    width: 68; height: 24; radius: 7
                    color: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.60)
                    border.width: 1
                    border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.15)
                    Text {
                        anchors.centerIn: parent
                        text: player.hasVideo ? win.tr("VIDEO") : win.tr("AUDIO")
                        color: theme.accent
                        font.pixelSize: 8
                        font.letterSpacing: 1.1
                    }
                }
            }

            Rectangle {
                visible: !win.fullscreenMode
                width: 306
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
                        spacing: 6

                        Text {
                            text: win.tr("PLAYLIST")
                            color: theme.muted
                            font.pixelSize: 9
                            font.letterSpacing: 1.3
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Item {
                            width: Math.max(0, parent.width - 60 - 26 - 26 - 46 - 40 - 24)
                            height: 1
                        }
                        ActionButton {
                            width: 26
                            height: 26
                            label: "↑"
                            onActivated: moveSelected(-1)
                        }
                        ActionButton {
                            width: 26
                            height: 26
                            label: "↓"
                            onActivated: moveSelected(1)
                        }
                        ActionButton {
                            width: 46
                            height: 26
                            label: win.tr("URL")
                            onActivated: urlDialog.open()
                        }
                        Text {
                            text: playlist.count + win.tr(" items")
                            color: theme.muted
                            font.pixelSize: 9
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        width: parent.width
                        height: 32
                        spacing: 6

                        ActionButton {
                            label: win.tr("Add")
                            width: 56
                            onActivated: browser.open()
                        }
                        ActionButton {
                            label: win.tr("Folder")
                            width: 70
                            onActivated: addAllInDirectory(mediaModel.directory)
                        }
                        ActionButton {
                            label: win.tr("Remove")
                            width: 74
                            onActivated: removeSelected()
                        }
                        ActionButton {
                            label: win.tr("Clear")
                            width: 56
                            onActivated: {
                                playlist.clear()
                                persistPlaylist()
                                player.stop()
                                player.source = ""
                                selectedIndex = -1
                                nowTitle = ""
                                nowSubtitle = ""
                            }
                        }
                    }

                    ListView {
                        id: playlistView
                        width: parent.width
                        height: parent.height - 26 - 32 - 16
                        clip: true
                        model: playlist
                        spacing: 3

                        delegate: Rectangle {
                            required property int index
                            required property string name
                            required property string path

                            width: ListView.view ? ListView.view.width : 0
                            height: 40
                            radius: 8
                            color: index === win.selectedIndex
                                   ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.18)
                                   : (itemHover.hovered ? Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.08) : "transparent")

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Rectangle {
                                    width: 22; height: 22; radius: 6
                                    color: index === win.selectedIndex ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.20) : Qt.rgba(theme.surface.r, theme.surface.g, theme.surface.b, 0.92)
                                    Text {
                                        anchors.centerIn: parent
                                        text: index === win.selectedIndex
                                              && player.playbackState === MediaPlayer.PlayingState
                                              ? "❚❚" : "▶"
                                        color: index === win.selectedIndex ? theme.accent : theme.muted
                                        font.pixelSize: 9
                                    }
                                }
                                Column {
                                    spacing: 1
                                    Text {
                                        text: name
                                        color: index === win.selectedIndex ? theme.text : theme.text
                                        font.pixelSize: 10
                                        width: 220
                                        elide: Text.ElideMiddle
                                    }
                                    Text {
                                        text: path.substring(0, path.lastIndexOf("/"))
                                        color: Qt.rgba(theme.muted.r, theme.muted.g, theme.muted.b, 0.70)
                                        font.pixelSize: 8
                                        width: 220
                                        elide: Text.ElideMiddle
                                    }
                                }
                            }

                            HoverHandler { id: itemHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.playIndex(index)
                            }
                        }
                    }
                }
            }
        }

        /* ---------------- Controls ---------------- */
        Rectangle {
            id: controlBar
            width: parent.width
            height: 92
            radius: 16
            color: Qt.rgba(theme.panel.r, theme.panel.g, theme.panel.b, 0.80)
            border.width: 1
            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.15)

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                Slider {
                    id: seekSlider
                    width: parent.width
                    height: 20
                    from: 0
                    to: 1
                    stepSize: 0
                    value: 0
                    // Keep the thumb in sync with playback unless the user is
                    // currently dragging it.
                    Binding {
                        target: seekSlider
                        property: "value"
                        value: player.duration > 0 ? player.position / player.duration : 0
                        when: !seekSlider.pressed
                    }
                    onMoved: {
                        if (player.duration > 0)
                            player.position = value * player.duration
                    }

                    background: Rectangle {
                        x: 0
                        y: (parent.height - 4) / 2
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.15)

                        Rectangle {
                            width: Math.max(0, Math.min(1, seekSlider.visualPosition)) * parent.width
                            height: parent.height
                            radius: 2
                            color: theme.accent2
                        }
                    }

                    handle: Rectangle {
                        x: seekSlider.leftPadding
                           + seekSlider.visualPosition
                             * (seekSlider.availableWidth - width)
                        y: (seekSlider.height - height) / 2
                        width: 14
                        height: 14
                        radius: 7
                        color: theme.text
                        border.width: seekSlider.pressed ? 2 : 1
                        border.color: theme.accent2
                    }
                }

                Row {
                    width: parent.width
                    height: 34
                    spacing: 8

                    ActionButton {
                        compact: true
                        glyph: "⏮"
                        onActivated: previous()
                    }
                    ActionButton {
                        compact: true
                        glyph: player.playbackState === MediaPlayer.PlayingState
                               ? "❚❚" : "▶"
                        active: player.playbackState === MediaPlayer.PlayingState
                        onActivated: togglePlay()
                    }
                    ActionButton {
                        compact: true
                        glyph: "■"
                        onActivated: player.stop()
                    }
                    ActionButton {
                        compact: true
                        glyph: "⏭"
                        onActivated: next()
                    }

                    Text {
                        text: formatTime(player.position) + " / "
                              + formatTime(player.duration)
                        color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.80)
                        font.pixelSize: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 96
                    }

                    Text {
                        visible: win.statusMessage.length > 0
                        text: win.statusMessage
                        color: theme.light ? "#2E8B57" : "#8FD3A8"
                        font.pixelSize: 9
                        width: 180
                        elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item {
                        width: Math.max(0, parent.width
                                        - (win.statusMessage.length > 0 ? 1030 : 842))
                        height: 1
                    }

                    ActionButton {
                        width: 54
                        label: "" + win.playbackSpeed + "×"
                        onActivated: cycleSpeed()
                    }

                    ActionButton {
                        width: 62
                        label: win.tr("Shuffle")
                        active: win.shuffle
                        onActivated: win.shuffle = !win.shuffle
                    }

                    ActionButton {
                        width: 64
                        label: win.repeatMode === 0
                               ? win.tr("Repeat")
                               : (win.repeatMode === 1 ? win.tr("All") : win.tr("One"))
                        active: win.repeatMode > 0
                        onActivated: cycleRepeat()
                    }

                    ActionButton {
                        width: 62
                        label: win.sleepMinutes > 0
                               ? formatTime(win.sleepRemaining * 1000)
                               : win.tr("Sleep")
                        active: win.sleepMinutes > 0
                        onActivated: cycleSleep()
                    }

                    ActionButton {
                        label: win.muted ? win.tr("Unmute") : win.tr("Mute")
                        onActivated: win.muted = !win.muted
                    }

                    SeekBar {
                        width: 120
                        height: 18
                        value: win.muted ? 0 : win.volumeLevel
                        fillColor: theme.light ? "#1E7A4D" : "#7ED6A5"
                        onSeeked: function (ratio) {
                            win.volumeLevel = ratio
                            win.muted = false
                        }
                    }

                    Text {
                        text: Math.round((win.muted ? 0 : win.volumeLevel) * 100) + "%"
                        color: theme.muted
                        font.pixelSize: 9
                        width: 32
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    ActionButton {
                        compact: true
                        glyph: win.fullscreenMode ? "⤡" : "⛶"
                        onActivated: win.toggleFullscreen()
                    }
                }
            }
        }
    }

    /* ---------------- URL dialog ---------------- */
    Dialog {
        id: urlDialog
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        width: 520
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
                text: win.tr("OPEN URL")
                color: theme.text
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 1.1
            }
            TextField {
                id: urlField
                width: parent.width
                height: 32
                placeholderText: "https://… or file:///…"
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
                onAccepted: urlDialog.accept()
            }
            Row {
                spacing: 8
                anchors.right: parent.right

                ActionButton {
                    width: 80
                    height: 30
                    label: win.tr("Cancel")
                    onActivated: urlDialog.reject()
                }
                Rectangle {
                    width: 80
                    height: 30
                    radius: 9
                    color: urlHover.hovered ? "#2A7ED6A5" : theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.14) : "#193326"
                    border.width: 1
                    border.color: "#557ED6A5"
                    Text { anchors.centerIn: parent; text: win.tr("Open"); color: theme.text; font.pixelSize: 10 }
                    HoverHandler { id: urlHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: urlDialog.accept()
                    }
                }
            }
        }

        onOpened: {
            urlField.text = ""
            urlField.forceActiveFocus()
        }
        onAccepted: win.addUrl(urlField.text.trim())
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

        property string selectedPath: ""

        background: Rectangle {
            color: theme.panel
            radius: 16
            border.width: 1
            border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.20)
        }

        onOpened: {
            selectedPath = ""
            mediaModel.setDirectory(mediaModel.videosPath())
        }

        contentItem: Column {
            spacing: 10
            anchors.fill: parent
            anchors.margins: 14

            Text {
                text: win.tr("ADD MEDIA")
                color: theme.text
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2
            }

            Row {
                width: parent.width
                height: 30
                spacing: 8

                ActionButton {
                    label: win.tr("↑ Up")
                    height: 30
                    onActivated: mediaModel.goUp()
                }
                ActionButton {
                    label: win.tr("Home")
                    height: 30
                    onActivated: mediaModel.setDirectory(mediaModel.homePath())
                }
                ActionButton {
                    label: win.tr("Videos")
                    height: 30
                    onActivated: mediaModel.setDirectory(mediaModel.videosPath())
                }
                ActionButton {
                    label: win.tr("Music")
                    height: 30
                    onActivated: mediaModel.setDirectory(mediaModel.musicPath())
                }

                TextField {
                    id: pathField
                    width: parent.width - 76 - 70 - 76 - 76 - 40
                    height: 30
                    text: mediaModel.directory
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
                    onAccepted: mediaModel.setDirectory(text)
                }
            }

            Rectangle {
                width: parent.width
                height: 300
                radius: 12
                color: Qt.rgba(theme.background.r, theme.background.g, theme.background.b, 0.60)
                border.width: 1
                border.color: Qt.rgba(theme.border.r, theme.border.g, theme.border.b, 0.12)
                clip: true

                ListView {
                    anchors.fill: parent
                    anchors.margins: 6
                    clip: true
                    model: mediaModel.entries
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
                                    text: isDir ? "▸" : "♫"
                                    color: isDir ? theme.accent : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.80)
                                    font.pixelSize: 11
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
                                    mediaModel.setDirectory(path)
                                    browser.selectedPath = ""
                                } else {
                                    win.addPath(path, true)
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

                ActionButton {
                    label: win.tr("Add all in folder")
                    width: 150
                    onActivated: win.addAllInDirectory(mediaModel.directory)
                }

                Item { width: parent.width - 150 - 120 - 90 - 16; height: 1 }

                ActionButton {
                    label: win.tr("Cancel")
                    width: 90
                    onActivated: browser.reject()
                }

                Rectangle {
                    width: 120
                    height: 32
                    radius: 9
                    color: (browser.selectedPath.length > 0
                            ? (addHover.hovered ? "#2A7ED6A5" : theme.light ? Qt.rgba(0.12, 0.45, 0.29, 0.14) : "#193326")
                            : theme.light ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.10) : "#16202A")
                    border.width: 1
                    border.color: "#557ED6A5"
                    opacity: browser.selectedPath.length > 0 ? 1.0 : 0.4

                    Text {
                        anchors.centerIn: parent
                        text: win.tr("Add & play")
                        color: theme.text
                        font.pixelSize: 10
                    }
                    HoverHandler { id: addHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: browser.selectedPath.length > 0
                        onClicked: {
                            win.addPath(browser.selectedPath, true)
                            browser.accept()
                        }
                    }
                }
            }
        }
    }
}

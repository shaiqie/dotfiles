import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../widgets"
import "../../services" as Services

Column {
    id: root

    property var theme
    property bool hasPlayer: false
    property string title: ""
    property string artist: ""
    property string album: ""
    property string artUrl: ""
    property string status: "Stopped"
    property real positionSeconds: 0
    property real durationSeconds: 0
    property real sinkVolume: 0
    property real sourceVolume: 0
    property bool sinkMuted: false
    property bool sourceMuted: false
    property string mediaError: ""
    property string volumeError: ""
    property bool mediaLoading: false
    property var outputDevices: []
    property var inputDevices: []
    property bool outputExpanded: false
    property bool inputExpanded: false
    property string currentSink: ""
    property string currentSource: ""
    property int motionToken: 0
    property int stage: -1
    property real cardOffset: 6
    property real sinkOffset: 6
    property real sourceOffset: 6
    readonly property color surface: theme.withAlpha(theme.foreground, 0.052)
    readonly property color secondary: theme.withAlpha(theme.foreground, 0.62)
    readonly property color cardTint: theme.withAlpha(theme.color4, 0.10)
    readonly property string audioIconDir: Quickshell.env("HOME") + "/.config/shells/assets/icons/panel/audio/"

    width: parent ? parent.width : 360
    leftPadding: 4
    rightPadding: 4
    topPadding: 4
    bottomPadding: 4
    spacing: theme ? theme.itemSpacing + 2 : 12
    focus: true

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
            const step = event.angleDelta.y > 0 ? 3 : -3
            root.setVolume("sink", root.sinkVolume + step)
            event.accepted = true
        }
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Tab)
            event.accepted = true
    }

    Behavior on cardOffset { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.4; damping: 0.78; mass: 0.9; epsilon: 0.001 } }
    Behavior on sinkOffset { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.4; damping: 0.78; mass: 0.9; epsilon: 0.001 } }
    Behavior on sourceOffset { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.4; damping: 0.78; mass: 0.9; epsilon: 0.001 } }

    Component.onCompleted: {
        refreshMedia()
        refreshVolume()
        restartStagger()
    }

    onMotionTokenChanged: restartStagger()

    Timer {
        id: staggerTimer
        interval: 35
        repeat: true
        onTriggered: {
            root.stage++
            if (root.stage === 0)
                root.cardOffset = 0
            else if (root.stage === 1)
                root.sinkOffset = 0
            else if (root.stage === 2)
                root.sourceOffset = 0
            if (root.stage >= 2)
                stop()
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.refreshMedia()
    }

    Timer {
        interval: 500
        repeat: true
        running: root.hasPlayer && root.status === "Playing"
        onTriggered: positionProbe.exec(positionProbe.command)
    }

    Timer {
        interval: 1500
        repeat: true
        running: true
        onTriggered: root.refreshVolume()
    }

    AudioMediaCard {
        width: parent.width - root.leftPadding - root.rightPadding
        theme: root.theme
        hasPlayer: root.hasPlayer
        title: root.title
        artist: root.artist
        artUrl: root.artUrl
        status: root.status
        loading: root.mediaLoading
        positionSeconds: root.positionSeconds
        durationSeconds: root.durationSeconds
        motionToken: root.motionToken
        opacity: root.stage >= 0 ? 1 : 0
        transform: Translate { y: root.cardOffset }
        Behavior on opacity { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 230; spring: 4.8; damping: 0.88; mass: 0.9; epsilon: 0.001 } }
        onSeek: function(fraction) { root.seek(fraction) }
        onControl: function(command) { root.control(command) }
    }

    Text {
        width: parent.width
        visible: root.mediaError.length > 0
        text: root.mediaError
        color: root.theme.color1
        font.pixelSize: 12
        elide: Text.ElideRight
    }

    DeviceVolumeSection {
        width: parent.width - root.leftPadding - root.rightPadding
        theme: root.theme
        title: "Output"
        sectionIcon: root.sinkMuted ? "󰝟" : "󰕾"
        mutedIcon: "󰝟"
        sliderIcon: ""
        sectionIconSource: root.audioIconDir + (root.sinkMuted ? "audio_muted.svg" : "audio.svg")
        mutedIconSource: root.audioIconDir + "audio_muted.svg"
        sliderIconSource: root.audioIconDir + "audio.svg"
        checkedIconSource: root.audioIconDir + "device_checked.svg"
        expanded: root.outputExpanded
        devices: root.outputDevices
        value: root.sinkVolume
        muted: root.sinkMuted
        defaultDevice: root.currentSink
        emptyText: "No output devices"
        opacity: root.stage >= 1 ? 1 : 0
        transform: Translate { y: root.sinkOffset }
        Behavior on opacity { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 230; spring: 4.8; damping: 0.88; mass: 0.9; epsilon: 0.001 } }
        onExpandedChangedByUser: function(expanded) { root.outputExpanded = expanded }
        onVolumeMoved: function(value) { root.setVolume("sink", value) }
        onMuteClicked: root.toggleMute("sink")
        onDeviceSelected: function(deviceId) { root.setDefaultSink(deviceId) }
    }

    DeviceVolumeSection {
        width: parent.width - root.leftPadding - root.rightPadding
        theme: root.theme
        title: "Input"
        sectionIcon: root.sourceMuted ? "󰍭" : "󰍬"
        mutedIcon: "󰍭"
        sliderIcon: "󰍬"
        sectionIconSource: root.audioIconDir + (root.sourceMuted ? "mic_muted.svg" : "mic.svg")
        mutedIconSource: root.audioIconDir + "mic_muted.svg"
        sliderIconSource: root.audioIconDir + "mic.svg"
        checkedIconSource: root.audioIconDir + "device_checked.svg"
        expanded: root.inputExpanded
        devices: root.inputDevices
        value: root.sourceVolume
        muted: root.sourceMuted
        defaultDevice: root.currentSource
        emptyText: "No input devices"
        opacity: root.stage >= 2 ? 1 : 0
        transform: Translate { y: root.sourceOffset }
        Behavior on opacity { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 230; spring: 4.8; damping: 0.88; mass: 0.9; epsilon: 0.001 } }
        onExpandedChangedByUser: function(expanded) { root.inputExpanded = expanded }
        onVolumeMoved: function(value) { root.setVolume("source", value) }
        onMuteClicked: root.toggleMute("source")
        onDeviceSelected: function(deviceId) { root.setDefaultSource(deviceId) }
    }

    Text {
        width: parent.width
        visible: root.volumeError.length > 0
        text: root.volumeError
        color: root.theme.color1
        font.pixelSize: 12
        elide: Text.ElideRight
    }

    Process {
        id: metadataProbe
        command: [Services.Config.playerctlBin, "metadata", "--format", "{{title}}|{{artist}}|{{album}}|{{mpris:artUrl}}|{{position}}|{{mpris:length}}|{{status}}"]
        stdout: StdioCollector { id: metadataOut; waitForEnd: true }
        stderr: StdioCollector { id: metadataErr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            root.mediaLoading = false
            if (exitCode !== 0) {
                root.hasPlayer = false
                root.mediaError = root.processError(metadataErr.text, "No active media player")
                return
            }
            root.mediaError = ""
            root.parseMetadata(metadataOut.text)
        }
    }

    Process {
        id: positionProbe
        command: [Services.Config.playerctlBin, "position"]
        stdout: StdioCollector { id: positionOut; waitForEnd: true }
        stderr: StdioCollector { id: positionErr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                const value = Number(positionOut.text.trim())
                if (isFinite(value))
                    root.positionSeconds = value
            } else {
                root.mediaError = root.processError(positionErr.text, "Failed to read media position")
            }
        }
    }

    Process {
        id: controlProcess
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { id: controlErr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0)
                root.mediaError = root.processError(controlErr.text, "Media command failed")
            root.refreshMedia()
        }
    }

    Process {
        id: sinkVolumeProbe
        command: [Services.Config.pactlBin, "get-sink-volume", "@DEFAULT_SINK@"]
        stdout: StdioCollector { id: sinkVolumeOut; waitForEnd: true }
        stderr: StdioCollector { id: sinkVolumeErr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                root.sinkVolume = root.parsePercent(sinkVolumeOut.text)
                root.volumeError = ""
            } else {
                root.volumeError = root.processError(sinkVolumeErr.text, "Failed to read output volume")
            }
        }
    }

    Process {
        id: sinkMuteProbe
        command: [Services.Config.pactlBin, "get-sink-mute", "@DEFAULT_SINK@"]
        stdout: StdioCollector { id: sinkMuteOut; waitForEnd: true }
        stderr: StdioCollector { id: sinkMuteErr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                root.sinkMuted = sinkMuteOut.text.toLowerCase().indexOf("yes") >= 0
                root.volumeError = ""
            } else {
                root.volumeError = root.processError(sinkMuteErr.text, "Failed to read output mute state")
            }
        }
    }

    Process {
        id: sourceVolumeProbe
        command: [Services.Config.pactlBin, "get-source-volume", "@DEFAULT_SOURCE@"]
        stdout: StdioCollector { id: sourceVolumeOut; waitForEnd: true }
        stderr: StdioCollector { id: sourceVolumeErr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                root.sourceVolume = root.parsePercent(sourceVolumeOut.text)
                root.volumeError = ""
            } else {
                root.volumeError = root.processError(sourceVolumeErr.text, "Failed to read microphone volume")
            }
        }
    }

    Process {
        id: sourceMuteProbe
        command: [Services.Config.pactlBin, "get-source-mute", "@DEFAULT_SOURCE@"]
        stdout: StdioCollector { id: sourceMuteOut; waitForEnd: true }
        stderr: StdioCollector { id: sourceMuteErr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                root.sourceMuted = sourceMuteOut.text.toLowerCase().indexOf("yes") >= 0
                root.volumeError = ""
            } else {
                root.volumeError = root.processError(sourceMuteErr.text, "Failed to read microphone mute state")
            }
        }
    }

    Process {
        id: volumeSetter
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { id: volumeSetterErr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0)
                root.volumeError = root.processError(volumeSetterErr.text, "Volume command failed")
            root.refreshVolume()
            root.refreshDevices()
        }
    }

    Process {
        id: sinkListProbe
        command: [Services.Config.pactlBin, "list", "sinks"]
        stdout: StdioCollector { id: sinkListOut; waitForEnd: true }
        stderr: StdioCollector { id: sinkListErr; waitForEnd: true }
        onExited: function(code) {
            if (code === 0)
                root.outputDevices = root.parseVerboseDeviceList(sinkListOut.text, root.currentSink)
            else
                root.volumeError = root.processError(sinkListErr.text, "Output devices unavailable")
        }
    }

    Process {
        id: sourceListProbe
        command: [Services.Config.pactlBin, "list", "sources"]
        stdout: StdioCollector { id: sourceListOut; waitForEnd: true }
        stderr: StdioCollector { id: sourceListErr; waitForEnd: true }
        onExited: function(code) {
            if (code === 0)
                root.inputDevices = root.parseVerboseDeviceList(sourceListOut.text, root.currentSource)
            else
                root.volumeError = root.processError(sourceListErr.text, "Input devices unavailable")
        }
    }

    Process {
        id: defaultSinkProbe
        command: [Services.Config.pactlBin, "get-default-sink"]
        stdout: StdioCollector { id: defaultSinkOut; waitForEnd: true }
        stderr: StdioCollector { id: defaultSinkErr; waitForEnd: true }
        onExited: function(code) {
            if (code !== 0) {
                root.volumeError = root.processError(defaultSinkErr.text, "Default output unavailable")
                return
            }
            root.currentSink = defaultSinkOut.text.trim()
            if (!sinkListProbe.running)
                sinkListProbe.exec(sinkListProbe.command)
        }
    }

    Process {
        id: defaultSourceProbe
        command: [Services.Config.pactlBin, "get-default-source"]
        stdout: StdioCollector { id: defaultSourceOut; waitForEnd: true }
        stderr: StdioCollector { id: defaultSourceErr; waitForEnd: true }
        onExited: function(code) {
            if (code !== 0) {
                root.volumeError = root.processError(defaultSourceErr.text, "Default input unavailable")
                return
            }
            root.currentSource = defaultSourceOut.text.trim()
            if (!sourceListProbe.running)
                sourceListProbe.exec(sourceListProbe.command)
        }
    }

    function refreshMedia() {
        if (!metadataProbe.running) {
            mediaLoading = true
            metadataProbe.exec(metadataProbe.command)
        }
    }

    function restartStagger() {
        stage = -1
        cardOffset = 6
        sinkOffset = 6
        sourceOffset = 6
        refreshDevices()
        staggerTimer.restart()
    }

    function refreshVolume() {
        if (!sinkVolumeProbe.running)
            sinkVolumeProbe.exec(sinkVolumeProbe.command)
        if (!sinkMuteProbe.running)
            sinkMuteProbe.exec(sinkMuteProbe.command)
        if (!sourceVolumeProbe.running)
            sourceVolumeProbe.exec(sourceVolumeProbe.command)
        if (!sourceMuteProbe.running)
            sourceMuteProbe.exec(sourceMuteProbe.command)
    }

    function control(command) {
        controlProcess.exec(command)
    }

    function seek(fraction) {
        if (durationSeconds <= 0)
            return

        const clamped = Math.max(0, Math.min(1, fraction))
        const seconds = clamped * durationSeconds
        positionSeconds = seconds
        control([Services.Config.playerctlBin, "position", String(seconds)])
    }

    function setVolume(kind, value) {
        const pct = Math.max(0, Math.min(150, Math.round(value)))
        if (kind === "sink") {
            sinkVolume = pct
            volumeSetter.exec([Services.Config.pactlBin, "set-sink-volume", "@DEFAULT_SINK@", pct + "%"])
        } else {
            sourceVolume = pct
            volumeSetter.exec([Services.Config.pactlBin, "set-source-volume", "@DEFAULT_SOURCE@", pct + "%"])
        }
    }

    function toggleMute(kind) {
        if (kind === "sink")
            volumeSetter.exec([Services.Config.pactlBin, "set-sink-mute", "@DEFAULT_SINK@", "toggle"])
        else
            volumeSetter.exec([Services.Config.pactlBin, "set-source-mute", "@DEFAULT_SOURCE@", "toggle"])
    }

    function refreshDevices() {
        if (!defaultSinkProbe.running)
            defaultSinkProbe.exec(defaultSinkProbe.command)
        if (!defaultSourceProbe.running)
            defaultSourceProbe.exec(defaultSourceProbe.command)
    }

    function parseVerboseDeviceList(text, defaultDevice) {
        const devices = []
        const blocks = String(text || "").split(/\n(?=Source #|Sink #)/)
        for (let i = 0; i < blocks.length; i++) {
            const block = blocks[i]
            const nameMatch = /^\s*Name:\s*(.+)$/m.exec(block)
            if (!nameMatch)
                continue

            const name = nameMatch[1].trim()
            if (name.indexOf(".monitor") >= 0 || name.indexOf("auto_null") >= 0)
                continue

            const descMatch = /^\s*Description:\s*(.+)$/m.exec(block)
            devices.push({
                deviceId: name,
                deviceName: descMatch ? descMatch[1].trim() : name,
                isDefault: name === defaultDevice
            })
        }
        return devices
    }

    function setDefaultSink(deviceId) {
        outputExpanded = false
        volumeSetter.exec([Services.Config.pactlBin, "set-default-sink", deviceId])
        Qt.callLater(function() {
            root.refreshDevices()
        })
    }

    function setDefaultSource(deviceId) {
        inputExpanded = false
        volumeSetter.exec([Services.Config.pactlBin, "set-default-source", deviceId])
        Qt.callLater(function() {
            root.refreshDevices()
        })
    }

    function parseMetadata(text) {
        const parts = text.trim().split("|")
        if (parts.length < 7) {
            hasPlayer = false
            return
        }

        title = parts[0]
        artist = parts[1]
        album = parts[2]
        artUrl = parts[3]
        positionSeconds = normalizeSeconds(parts[4])
        durationSeconds = normalizeSeconds(parts[5])
        status = parts[6]
        hasPlayer = true
        mediaError = ""
    }

    function normalizeSeconds(value) {
        const n = Number(value)
        if (!isFinite(n))
            return 0
        return n > 100000 ? n / 1000000 : n
    }

    function parsePercent(text) {
        const match = /(\d+)%/.exec(text)
        return match ? Number(match[1]) : 0
    }

    function processError(text, fallback) {
        const msg = String(text || "").trim()
        return msg.length > 0 ? msg : fallback
    }

    function formatSeconds(value) {
        const total = Math.max(0, Math.floor(Number(value) || 0))
        const m = Math.floor(total / 60)
        const s = total % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    component DeviceVolumeSection: Rectangle {
        id: section

        property var theme
        property string title: ""
        property string sectionIcon: ""
        property string sliderIcon: ""
        property string mutedIcon: ""
        property string sectionIconSource: ""
        property string sliderIconSource: ""
        property string mutedIconSource: ""
        property string checkedIconSource: ""
        property bool expanded: false
        property var devices: []
        property real value: 0
        property bool muted: false
        property string defaultDevice: ""
        property string emptyText: "No devices"

        signal expandedChangedByUser(bool expanded)
        signal volumeMoved(real value)
        signal muteClicked()
        signal deviceSelected(string deviceId)

        radius: section.theme.panelRadius
        color: section.theme.withAlpha(section.theme.foreground, 0.045)
        border.width: section.theme.outerBorder ? section.theme.borderWidth : 0
        border.color: section.theme.withAlpha(section.theme.color1, 0.18)
        height: sectionContent.implicitHeight + 28
        clip: true

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: "transparent"
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: section.theme.withAlpha(section.muted ? section.theme.color1 : section.theme.color4, 0.10) }
                GradientStop { position: 0.58; color: section.theme.withAlpha(section.theme.color2, 0.030) }
                GradientStop { position: 1.0; color: section.theme.withAlpha(section.theme.background, 0) }
            }
        }

        Behavior on height {
            SpringAnimation {
                duration: section.theme && section.theme.reducedMotion ? 0 : 250
                spring: 4.5
                damping: 0.78
                mass: 0.9
                epsilon: 0.001
            }
        }

        Column {
            id: sectionContent
            width: parent.width - section.theme.panelPadding * 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: section.theme.panelPadding
            spacing: section.theme.itemSpacing

            RowLayout {
                width: parent.width
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    radius: section.theme.controlRadius
                    color: section.theme.withAlpha(section.muted ? section.theme.color1 : section.theme.color4, 0.10)

                    AudioSvgIcon {
                        anchors.centerIn: parent
                        theme: section.theme
                        sourcePath: section.sectionIconSource
                        iconColor: section.muted ? section.theme.color1 : section.theme.color4
                        iconSize: 21
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        width: parent.width
                        text: section.title
                        color: section.theme.foreground
                        font.family: section.theme.fontFamily
                        font.pixelSize: 14 * section.theme.fontScale
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: section.devices.length > 0 ? (section.defaultDevice.length > 0 ? "Default device selected" : "Choose device") : section.emptyText
                        color: section.theme.withAlpha(section.theme.foreground, 0.46)
                        font.family: section.theme.fontFamily
                        font.pixelSize: 10 * section.theme.fontScale
                        elide: Text.ElideRight
                    }
                }

                Text {
                    Layout.preferredWidth: 46
                    text: Math.round(section.value) + "%"
                    color: section.muted ? section.theme.withAlpha(section.theme.foreground, 0.36) : section.theme.foreground
                    font.family: section.theme.fontFamily
                    font.pixelSize: 16 * section.theme.fontScale
                    font.bold: true
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                }

                Item {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 32

                    AudioSvgIcon {
                        anchors.centerIn: parent
                        theme: section.theme
                        sourcePath: section.muted ? section.mutedIconSource : section.sliderIconSource
                        iconColor: section.muted ? section.theme.color1 : section.theme.withAlpha(section.theme.foreground, 0.56)
                        iconSize: 17
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: section.muteClicked()
                    }
                }

                Text {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 32
                    text: "󰅀"
                    color: section.theme.withAlpha(section.theme.foreground, 0.52)
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    rotation: section.expanded ? 180 : 0

                    Behavior on rotation {
                        SpringAnimation {
                            duration: section.theme && section.theme.reducedMotion ? 0 : 250
                            spring: 5.0
                            damping: 0.75
                            mass: 0.9
                            epsilon: 0.001
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: section.expandedChangedByUser(!section.expanded)
                    }
                }
            }

            AudioVolumeSlider {
                width: parent.width
                theme: section.theme
                label: section.title
                icon: section.sliderIcon
                mutedIcon: section.mutedIcon
                iconSource: section.sliderIconSource
                mutedIconSource: section.mutedIconSource
                value: section.value
                muted: section.muted
                showHeader: false
                percentInTrack: false
                trackBaseHeight: 34
                trackHoverHeight: 38
                trackDragHeight: 42
                onVolumeMoved: function(v) { section.volumeMoved(v) }
                onMuteClicked: section.muteClicked()
            }

            Column {
                width: parent.width
                height: section.expanded ? implicitHeight : 0
                clip: true
                spacing: 4
                opacity: section.expanded ? 1 : 0

                Behavior on height {
                    SpringAnimation {
                        duration: section.theme && section.theme.reducedMotion ? 0 : 250
                        spring: 4.5
                        damping: 0.78
                        mass: 0.9
                        epsilon: 0.001
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: section.theme && section.theme.reducedMotion ? Math.round(180 / 2) : 180
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: section.theme.withAlpha(section.theme.color4, 0.15)
                }

                Text {
                    text: section.title.toUpperCase() + " DEVICES"
                    color: section.theme.color6
                    font.family: section.theme.fontFamily
                    font.pixelSize: 9 * section.theme.fontScale
                    font.bold: section.theme.fontBold
                    leftPadding: 4
                }

                Text {
                    width: parent.width
                    visible: section.devices.length === 0
                    text: section.emptyText
                    color: section.theme.withAlpha(section.theme.foreground, 0.62)
                    font.family: section.theme.fontFamily
                    font.pixelSize: 12 * section.theme.fontScale
                    leftPadding: 4
                }

                Repeater {
                    model: section.devices

                    Rectangle {
                        id: deviceRow
                        property var device: modelData
                        property bool isDefault: device && device.isDefault === true

                        width: parent.width
                        height: 36
                        radius: section.theme.itemRadius
                        color: isDefault ? section.theme.withAlpha(section.theme.color4, 0.12) : "transparent"
                        scale: deviceArea.pressed ? 0.97 : 1

                        Behavior on color { ColorAnimation { duration: section.theme && section.theme.reducedMotion ? Math.round(150 / 2) : 150 } }
                        Behavior on scale { SpringAnimation { duration: section.theme && section.theme.reducedMotion ? 0 : 250; spring: 6.0; damping: 0.7; mass: 0.9; epsilon: 0.001 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10

                            Text {
                                Layout.fillWidth: true
                                text: device ? device.deviceName : ""
                                color: deviceRow.isDefault ? section.theme.color4 : section.theme.foreground
                                font.family: section.theme.fontFamily
                                font.pixelSize: 12 * section.theme.fontScale
                                font.bold: deviceRow.isDefault || section.theme.fontBold
                                elide: Text.ElideRight
                            }

                            AudioSvgIcon {
                                visible: deviceRow.isDefault
                                theme: section.theme
                                sourcePath: section.checkedIconSource
                                iconColor: section.theme.color4
                                iconSize: 15
                            }
                        }

                        MouseArea {
                            id: deviceArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (device) section.deviceSelected(device.deviceId)
                        }
                    }
                }
            }
        }
    }

    component AudioSvgIcon: Item {
        id: audioIcon

        property var theme
        property string sourcePath: ""
        property color iconColor: "white"
        property int iconSize: 24

        width: iconSize
        height: iconSize

        Behavior on width { NumberAnimation { duration: audioIcon.theme && audioIcon.theme.reducedMotion ? 0 : 140; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: audioIcon.theme && audioIcon.theme.reducedMotion ? 0 : 140; easing.type: Easing.OutCubic } }

        Image {
            id: svgSource
            anchors.fill: parent
            source: audioIcon.sourcePath
            sourceSize.width: width
            sourceSize.height: height
            smooth: true
            mipmap: true
            visible: false
        }

        MultiEffect {
            anchors.fill: svgSource
            source: svgSource
            colorization: 1
            colorizationColor: audioIcon.iconColor

            Behavior on colorizationColor { ColorAnimation { duration: audioIcon.theme && audioIcon.theme.reducedMotion ? 0 : 170; easing.type: Easing.OutCubic } }
        }
    }
}

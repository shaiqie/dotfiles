import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../bar/widgets"
import "../services" as Services

PanelWindow {
    id: root

    property var theme
    property var notificationStore
    property var stateService
    property real barBottomEdge: 70
    property bool isSettingsOpen: false
    property bool stoppingRequested: false
    property bool closing: false
    property int closePhase: 0
    property bool islandHovered: false
    property bool compactDebounced: false
    property bool recordingHidden: false
    property real compactBreath: 0
    property int settingsStage: 0
    property bool settingsSelectionMotionReady: false
    property string resolution: "1080p"
    property int fps: 60
    property string videoFormat: "mkv"
    property string videoCodec: "h264"
    property string audioCodec: "aac"
    property string quality: "High"
    property string captureTarget: "screen"
    property bool captureAudio: true
    property bool captureMic: false
    property bool showCursor: true
    property var outputDevices: []
    property var inputDevices: []
    property string currentSink: ""
    property string currentSource: ""
    property string selectedOutputDevice: ""
    property string selectedInputDevice: ""
    property string saveDir: Quickshell.env("HOME") + "/Videos"
    property string filenameFormat: "recording_%Y-%m-%d_%H-%M-%S"
    property string lastError: ""
    property bool loadingSettings: false
    readonly property string pidFile: "/tmp/shells-recorder.pid"

    readonly property bool active: Services.RecorderState.isRecording || Services.RecorderState.isPaused
    readonly property bool compact: active && compactDebounced
    readonly property string recordingTimeText: formatDuration(Services.RecorderState.elapsedSeconds)
    readonly property bool shown: Services.RecorderState.isVisible || root.active || root.closing
    readonly property int baseWidth: 176
    readonly property int hoverWidth: 204
    readonly property int activeWidth: 220
    readonly property int compactWidth: 168
    readonly property int settingsWidth: 360
    readonly property int settingsHeight: 420
    readonly property int windowPadding: 40
    readonly property int panelTop: Math.max(0, Math.round(root.barBottomEdge + (root.theme ? root.theme.islandGap + 8 : 16)))
    readonly property color recordRed: "#ff3b30"
    readonly property color pauseAmber: "#ff9500"

    anchors {
        top: true
    }

    margins {
        top: root.panelTop
        left: Math.max(0, Math.round((Screen.width - root.implicitWidth) / 2))
    }
    implicitWidth: root.settingsWidth + root.windowPadding
    implicitHeight: root.isSettingsOpen ? (44 + root.settingsHeight + 20) : 64
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    focusable: root.isSettingsOpen || root.active
    color: "transparent"
    surfaceFormat.opaque: false
    visible: Services.RecorderState.isVisible || root.active || root.closing
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.isSettingsOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.namespace: "shells-recorder"
    WlrLayershell.anchors.top: true
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.exclusiveZone: 0

    Component.onCompleted: root.loadRecorderSettings()
    onStateServiceChanged: root.loadRecorderSettings()
    onResolutionChanged: root.scheduleRecorderSettingsSave()
    onFpsChanged: root.scheduleRecorderSettingsSave()
    onVideoFormatChanged: root.scheduleRecorderSettingsSave()
    onVideoCodecChanged: root.scheduleRecorderSettingsSave()
    onAudioCodecChanged: root.scheduleRecorderSettingsSave()
    onQualityChanged: root.scheduleRecorderSettingsSave()
    onCaptureTargetChanged: root.scheduleRecorderSettingsSave()
    onCaptureAudioChanged: root.scheduleRecorderSettingsSave()
    onCaptureMicChanged: root.scheduleRecorderSettingsSave()
    onShowCursorChanged: root.scheduleRecorderSettingsSave()
    onSelectedOutputDeviceChanged: root.scheduleRecorderSettingsSave()
    onSelectedInputDeviceChanged: root.scheduleRecorderSettingsSave()
    onSaveDirChanged: root.scheduleRecorderSettingsSave()
    onFilenameFormatChanged: root.scheduleRecorderSettingsSave()

    onActiveChanged: if (!active) root.recordingHidden = false

    onIsSettingsOpenChanged: {
        if (isSettingsOpen) {
            root.settingsStage = 99
            root.settingsSelectionMotionReady = false
            settingsSelectionMotionTimer.restart()
            root.refreshAudioDevices()
        } else {
            settingsStagger.stop()
            settingsSelectionMotionTimer.stop()
            root.settingsStage = 0
            root.settingsSelectionMotionReady = false
        }
    }

    Connections {
        target: root.stateService

        function onStateLoaded() {
            root.loadRecorderSettings()
        }
    }

    onVisibleChanged: {
        if (visible && root.isSettingsOpen)
            focusCatcher.forceActiveFocus()
    }

    Item {
        id: focusCatcher
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.closeAnimated()
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        onActivated: root.closeAnimated()
    }

    IpcHandler {
        target: "recorder"

        function toggle() { root.toggleRecorderIsland() }
        function open() { root.showRecorderIsland() }
        function close() { root.closeAnimated() }
        function start() { root.startRecording() }
        function stop() { root.stopRecording() }
        function pause() { root.pauseRecording() }
        function resume() { root.resumeRecording() }
    }

    Timer {
        interval: 1000
        repeat: true
        running: Services.RecorderState.isRecording && !Services.RecorderState.isPaused
        onTriggered: Services.RecorderState.elapsedSeconds++
    }

    Timer {
        id: recorderSettingsSaveDebounce
        interval: 500
        repeat: false
        onTriggered: root.saveRecorderSettings()
    }

    Process {
        id: recorderProcess
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { id: recorderErr; waitForEnd: true }
        onExited: function(code) {
            const savedPath = Services.RecorderState.outputPath
            const elapsed = Services.RecorderState.elapsedSeconds
            const expected = root.stoppingRequested
            root.stoppingRequested = false
            Services.RecorderState.stop()

            if (expected || code === 0)
                root.notifySuccess(savedPath, elapsed)
            else
                root.notifyError(String(recorderErr.text || "gpu-screen-recorder failed"))
        }
    }

    Process { id: pauseProcess }
    Process { id: resumeProcess }
    Process { id: stopProcess }

    Process {
        id: folderPicker
        stdout: StdioCollector { id: folderPickerOut; waitForEnd: true }
        stderr: StdioCollector { id: folderPickerErr; waitForEnd: true }
        onExited: function(code) {
            if (code !== 0) {
                const err = root.processError(folderPickerErr.text, "")
                if (err.length > 0)
                    root.lastError = err
                return
            }

            const picked = String(folderPickerOut.text || "").trim()
            if (picked.length > 0)
                root.saveDir = picked
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
                root.lastError = root.processError(sinkListErr.text, "Output devices unavailable")
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
                root.lastError = root.processError(sourceListErr.text, "Input devices unavailable")
        }
    }

    Process {
        id: defaultSinkProbe
        command: [Services.Config.pactlBin, "get-default-sink"]
        stdout: StdioCollector { id: defaultSinkOut; waitForEnd: true }
        stderr: StdioCollector { id: defaultSinkErr; waitForEnd: true }
        onExited: function(code) {
            if (code !== 0) {
                root.lastError = root.processError(defaultSinkErr.text, "Default output unavailable")
                return
            }
            root.currentSink = defaultSinkOut.text.trim()
            if (root.selectedOutputDevice.length === 0)
                root.selectedOutputDevice = root.currentSink
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
                root.lastError = root.processError(defaultSourceErr.text, "Default input unavailable")
                return
            }
            root.currentSource = defaultSourceOut.text.trim()
            if (root.selectedInputDevice.length === 0)
                root.selectedInputDevice = root.currentSource
            if (!sourceListProbe.running)
                sourceListProbe.exec(sourceListProbe.command)
        }
    }

    Timer {
        id: compactDebounce
        interval: 80
        repeat: false
        onTriggered: root.compactDebounced = root.active && !root.islandHovered
    }

    SequentialAnimation on compactBreath {
        running: root.compact && Services.RecorderState.isRecording && !Services.RecorderState.isPaused && !root.theme.reducedMotion
        loops: Animation.Infinite
        NumberAnimation { to: 2; duration: 2000; easing.type: Easing.InOutSine }
        NumberAnimation { to: -2; duration: 2000; easing.type: Easing.InOutSine }
    }

    Timer {
        id: settingsStagger
        interval: 25
        repeat: true
        onTriggered: {
            root.settingsStage++
            if (root.settingsStage >= 99)
                stop()
        }
    }

    Timer {
        id: settingsSelectionMotionTimer
        interval: 560
        repeat: false
        onTriggered: root.settingsSelectionMotionReady = root.isSettingsOpen
    }

    Rectangle {
        id: island

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.shown ? 0 : -8
        width: root.closing ? (root.closePhase >= 1 ? 28 : root.baseWidth) : (root.isSettingsOpen ? root.settingsWidth : (root.compact ? root.compactWidth : (root.active ? root.activeWidth : (root.islandHovered ? root.hoverWidth : root.baseWidth))))
        height: root.closing ? (root.closePhase >= 1 ? 28 : 46) : (root.isSettingsOpen ? 44 + root.settingsHeight : (root.compact ? 40 : 46))
        radius: 22
        antialiasing: true
        clip: true
        opacity: root.closing && root.closePhase >= 2 ? 0 : (root.recordingHidden ? (hover.hovered ? 1 : 0) : (root.shown ? 1 : 0))
        scale: root.closing && root.closePhase >= 2 ? 0.08 : (root.shown ? 1 : 0.94)
        color: root.recordingHidden && !hover.hovered ? "transparent" : root.theme.withAlpha(root.theme.color0, root.theme.panelOpacity)
        border.width: root.recordingHidden && !hover.hovered ? 0 : (root.theme.outerBorder ? root.theme.borderWidth : 0)
        border.color: root.theme.withAlpha(root.theme.color1, root.theme.borderOpacity)

        Behavior on y { NumberAnimation { duration: root.theme.reducedMotion ? 0 : 240; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: root.theme.reducedMotion ? 0 : 380; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: root.theme.reducedMotion ? 0 : 380; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: root.theme.reducedMotion ? 0 : 260; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: root.theme.reducedMotion ? 0 : 420; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: root.theme.reducedMotion ? 0 : 400; easing.type: Easing.OutCubic } }

        HoverHandler {
            id: hover
            onHoveredChanged: {
                root.islandHovered = hovered
                compactDebounce.restart()
            }
        }

        Item {
            id: topBar
            width: parent.width
            height: root.compact ? 36 : 44

            Behavior on height { NumberAnimation { duration: root.theme.reducedMotion ? 0 : 280; easing.type: Easing.OutCubic } }

            Row {
                id: idleControls
                anchors.centerIn: parent
                spacing: root.closing ? -32 : (root.islandHovered && !root.active ? 12 : 8)
                opacity: root.active ? 0 : 1
                enabled: !root.active
                scale: root.closing && root.closePhase >= 2 ? 0.35 : (root.closing && root.closePhase >= 1 ? 0.72 : 1)

                Behavior on spacing { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 320; spring: 4.8; damping: 0.76; mass: 0.9; epsilon: 0.001 } }
                Behavior on scale { NumberAnimation { duration: root.theme.reducedMotion ? 0 : 380; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: root.theme.reducedMotion ? 0 : 120; easing.type: Easing.InCubic } }

                RoundIconButton {
                    z: 10
                    theme: root.theme
                    text: "󰑊"
                    iconColor: "white"
                    fillColor: root.recordRed
                    size: 32
                    rippleEnabled: true
                    lockFillColor: true
                    ambientPulse: !root.active && !root.isSettingsOpen
                    scatterOpacity: root.active ? 0 : 1
                    slideX: root.closing ? 0 : (root.active ? -26 : (root.islandHovered ? -2 : 0))
                    tooltipText: "Record"
                    onClicked: root.startRecording()
                }

                RoundIconButton {
                    id: micButton
                    theme: root.theme
                    text: root.captureMic ? "󰍬" : "󰍭"
                    iconColor: root.captureMic ? root.theme.color4 : root.theme.color6
                    fillColor: root.captureMic ? root.theme.withAlpha(root.theme.color4, 0.16) : "transparent"
                    accentGradient: root.captureMic
                    size: 32
                    scatterOpacity: root.active ? 0 : 1
                    slideX: root.closing ? 0 : (root.active ? -12 : 0)
                    tooltipText: root.captureMic ? "Microphone on" : "Microphone off"
                    onClicked: {
                        root.playClickedSound()
                        root.captureMic = !root.captureMic
                        micButton.swingIcon()
                    }
                }

                RoundIconButton {
                    theme: root.theme
                    text: "󰒓"
                    iconColor: root.theme.foreground
                    fillColor: "transparent"
                    size: 32
                    rotation: root.isSettingsOpen ? 90 : 0
                    scatterOpacity: root.active ? 0 : 1
                    slideX: root.closing ? 0 : (root.active ? 12 : 0)
                    tooltipText: "Settings"
                    onClicked: root.isSettingsOpen = !root.isSettingsOpen

                    Behavior on rotation { SpringAnimation { spring: root.theme.springStrength; damping: root.theme.springDamping; mass: 0.9; epsilon: 0.001 } }
                }

                RoundIconButton {
                    theme: root.theme
                    text: "󰅖"
                    iconColor: root.theme.color6
                    fillColor: "transparent"
                    size: 32
                    scatterOpacity: root.active ? 0 : 1
                    slideX: root.closing ? 0 : (root.active ? 26 : (root.islandHovered ? 2 : 0))
                    tooltipText: "Close"
                    onClicked: root.closeAnimated()
                }
            }

            Item {
                id: activeContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                opacity: root.active && (!root.recordingHidden || hover.hovered) ? 1 : 0
                enabled: root.active && (!root.recordingHidden || hover.hovered)

                Behavior on opacity {
                    SequentialAnimation {
                        PauseAnimation { duration: root.active && !root.theme.reducedMotion ? 80 : 0 }
                        NumberAnimation { duration: root.theme.reducedMotion ? 0 : 200; easing.type: Easing.OutCubic }
                    }
                }

                Rectangle {
                    id: recordDot
                    property real pulseScale: 1
                    property real popScale: 0
                    property real glowPulse: 0.45

                    anchors.left: parent.left
                    anchors.leftMargin: hover.hovered ? 14 : 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: 10
                    height: 10
                    radius: 5
                    color: Services.RecorderState.isPaused ? root.pauseAmber : root.recordRed
                    scale: pulseScale * popScale
                    layer.enabled: root.active
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowBlur: recordDot.glowPulse
                        shadowColor: Qt.rgba(1, 0.23, 0.19, 0.32)
                    }

                    Behavior on anchors.leftMargin { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 320; spring: 4.8; damping: 0.70; mass: 0.9; epsilon: 0.001 } }

                    onVisibleChanged: if (visible) dotPop.restart()

                    SequentialAnimation {
                        id: dotPop
                        running: root.active
                        PauseAnimation { duration: root.theme.reducedMotion ? 0 : 180 }
                        SpringAnimation { target: recordDot; property: "popScale"; from: 0; to: 1.0; duration: root.theme.reducedMotion ? 0 : 420; spring: 7.0; damping: 0.46; mass: 0.85; epsilon: 0.001 }
                    }

                    SequentialAnimation on pulseScale {
                        running: Services.RecorderState.isRecording && !Services.RecorderState.isPaused
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.3; duration: root.theme.reducedMotion ? 0 : 500; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: root.theme.reducedMotion ? 0 : 500; easing.type: Easing.InOutSine }
                    }

                    SequentialAnimation on glowPulse {
                        running: Services.RecorderState.isRecording && !Services.RecorderState.isPaused && !root.theme.reducedMotion
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.90; duration: 500; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.45; duration: 500; easing.type: Easing.InOutSine }
                    }
                }

                RoundIconButton {
                    anchors.left: parent.left
                    anchors.leftMargin: 30
                    anchors.verticalCenter: parent.verticalCenter
                    theme: root.theme
                    text: root.recordingHidden ? "󰈉" : "󰈈"
                    iconColor: root.theme.color6
                    fillColor: root.theme.withAlpha(root.theme.color1, 0.18)
                    size: 24
                    revealProgress: hover.hovered ? 1 : 0
                    slideX: hover.hovered ? 0 : 8
                    tooltipText: root.recordingHidden ? "Show island" : "Hide island"
                    onClicked: root.recordingHidden ? root.showRecorderIsland() : root.hideRecorderIsland()
                }

                Item {
                    anchors.centerIn: parent
                    width: Math.min(72, Math.max(40, parent.width - 112))
                    height: 18

                    Row {
                        anchors.centerIn: parent
                        height: parent.height
                        spacing: 0
                        layoutDirection: Qt.LeftToRight

                        Repeater {
                            model: root.recordingTimeText.length

                            FlipDigit {
                                theme: root.theme
                                value: root.recordingTimeText[index]
                            }
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    width: 76
                    clip: true
                    enabled: hover.hovered

                    RoundIconButton {
                        theme: root.theme
                        text: Services.RecorderState.isPaused ? "󰐊" : "󰏤"
                        iconColor: root.theme.foreground
                        fillColor: root.theme.withAlpha(root.theme.color1, 0.35)
                        size: 28
                        revealProgress: hover.hovered ? 1 : 0
                        slideX: hover.hovered ? 0 : 8
                        tooltipText: Services.RecorderState.isPaused ? "Resume" : "Pause"
                        onClicked: Services.RecorderState.isPaused ? root.resumeRecording() : root.pauseRecording()
                    }

                    RoundIconButton {
                        theme: root.theme
                        text: "󰓛"
                        iconColor: root.recordRed
                        fillColor: root.theme.withAlpha(root.recordRed, 0.14)
                        size: 28
                        revealProgress: hover.hovered ? 1 : 0
                        revealDelay: hover.hovered ? 50 : 0
                        slideX: hover.hovered ? 0 : 8
                        tooltipText: "Stop"
                        onClicked: root.stopRecording()
                    }
                }
            }
        }

        Flickable {
            id: settingsViewport
            width: parent.width - 28
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 52
            height: root.isSettingsOpen ? root.settingsHeight - 20 : 0
            contentWidth: width
            contentHeight: settingsContent.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            interactive: root.isSettingsOpen && !root.closing
            opacity: root.isSettingsOpen ? 1 : 0
            enabled: root.isSettingsOpen && !root.closing

            Behavior on opacity { NumberAnimation { duration: root.theme.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic } }

            Column {
                id: settingsContent
                width: settingsViewport.width
                spacing: 12

                SectionLabel { theme: root.theme; text: "Video"; staggerIndex: 1 }
                SegmentPicker {
                    theme: root.theme
                    staggerIndex: 2
                    label: "Resolution"
                    options: ["2160p", "1440p", "1080p", "720p"]
                    value: root.resolution
                    onSelected: function(v) { root.resolution = v }
                }
                SegmentPicker {
                    theme: root.theme
                    staggerIndex: 3
                    label: "FPS"
                    options: ["24", "30", "60", "120"]
                    value: String(root.fps)
                    onSelected: function(v) { root.fps = Number(v) }
                }
                OptionDropdown {
                    theme: root.theme
                    staggerIndex: 4
                    label: "Format"
                    options: ["mkv", "mp4", "mov", "flv", "webm"]
                    value: root.videoFormat
                    onSelected: function(v) { root.videoFormat = v }
                }

                SectionLabel { theme: root.theme; text: "Codec"; staggerIndex: 5 }
                SegmentPicker {
                    theme: root.theme
                    staggerIndex: 6
                    label: "Video"
                    options: ["h264", "hevc", "av1", "vp9"]
                    value: root.videoCodec
                    onSelected: function(v) { root.videoCodec = v }
                }
                SegmentPicker {
                    theme: root.theme
                    staggerIndex: 7
                    label: "Audio"
                    options: ["aac", "opus", "flac"]
                    value: root.audioCodec
                    onSelected: function(v) { root.audioCodec = v }
                }
                SegmentPicker {
                    theme: root.theme
                    staggerIndex: 8
                    label: "Quality"
                    options: ["Low", "Medium", "High", "Lossless"]
                    value: root.quality
                    onSelected: function(v) { root.quality = v }
                }

                SectionLabel { theme: root.theme; text: "Capture"; staggerIndex: 9 }
                SegmentPicker {
                    theme: root.theme
                    staggerIndex: 10
                    label: "Target"
                    options: ["screen", "window", "region"]
                    value: root.captureTarget
                    onSelected: function(v) { root.captureTarget = v }
                }
                ToggleRow { theme: root.theme; staggerIndex: 11; label: "Audio"; checked: root.captureAudio; onChanged: function(v) { root.captureAudio = v } }
                ToggleRow { theme: root.theme; staggerIndex: 12; label: "Microphone"; checked: root.captureMic; onChanged: function(v) { root.captureMic = v } }
                ToggleRow { theme: root.theme; staggerIndex: 13; label: "Show cursor"; checked: root.showCursor; onChanged: function(v) { root.showCursor = v } }
                DevicePicker {
                    theme: root.theme
                    staggerIndex: 14
                    label: "Output"
                    icon: "󰕾"
                    enabled: root.captureAudio
                    devices: root.outputDevices
                    selectedDevice: root.selectedOutputDevice
                    emptyText: "No output devices"
                    onSelected: function(deviceId) { root.selectedOutputDevice = deviceId }
                }
                DevicePicker {
                    theme: root.theme
                    staggerIndex: 15
                    label: "Input"
                    icon: root.captureMic ? "󰍬" : "󰍭"
                    enabled: root.captureMic
                    devices: root.inputDevices
                    selectedDevice: root.selectedInputDevice
                    emptyText: "No input devices"
                    onSelected: function(deviceId) { root.selectedInputDevice = deviceId }
                }

                SectionLabel { theme: root.theme; text: "Output"; staggerIndex: 16 }
                OutputRow {
                    theme: root.theme
                    staggerIndex: 17
                    saveDir: root.saveDir
                    filenameFormat: root.filenameFormat
                    onOpenFolder: root.chooseSaveDir()
                    onFilenameChanged: function(v) { root.filenameFormat = v }
                }
            }
        }
    }

    function startRecording() {
        if (Services.RecorderState.isRecording)
            return

        root.isSettingsOpen = false
        root.lastError = ""
        const output = root.saveDir + "/" + root.formatFilename(root.filenameFormat, new Date()) + "." + root.videoFormat
        Services.RecorderState.start(output)
        root.notifyStarted(output)
        recorderProcess.exec(["bash", "-lc", root.buildShellCommand(output)])
    }

    function pauseRecording() {
        if (!Services.RecorderState.isRecording || Services.RecorderState.isPaused)
            return
        pauseProcess.exec(["bash", "-lc", root.signalCommand("USR2")])
        Services.RecorderState.pause()
    }

    function resumeRecording() {
        if (!Services.RecorderState.isRecording || !Services.RecorderState.isPaused)
            return
        resumeProcess.exec(["bash", "-lc", root.signalCommand("USR2")])
        Services.RecorderState.resume()
    }

    function stopRecording() {
        if (!Services.RecorderState.isRecording)
            return
        root.stoppingRequested = true
        stopProcess.exec(["bash", "-lc", root.signalCommand("INT")])
    }

    function hideRecorderIsland() {
        if (!root.active)
            return
        root.recordingHidden = true
        Services.RecorderState.isVisible = false
    }

    function showRecorderIsland() {
        root.recordingHidden = false
        Services.RecorderState.isVisible = true
    }

    function chooseSaveDir() {
        if (folderPicker.running)
            return

        folderPicker.exec([
            "bash",
            "-lc",
            "start=\"$1\"; if command -v zenity >/dev/null 2>&1; then zenity --file-selection --directory --title='Choose recording folder' --filename=\"$start/\"; elif command -v kdialog >/dev/null 2>&1; then kdialog --getexistingdirectory \"$start\" 'Choose recording folder'; elif command -v yad >/dev/null 2>&1; then yad --file-selection --directory --title='Choose recording folder' --filename=\"$start/\"; else printf 'No folder picker found: install zenity, kdialog, or yad.\\n' >&2; exit 2; fi",
            "folder-picker",
            root.saveDir
        ])
    }

    function toggleRecorderIsland() {
        if (root.active) {
            if (root.recordingHidden)
                root.showRecorderIsland()
            else
                root.hideRecorderIsland()
            return
        }
        Services.RecorderState.toggle()
    }

    function closeAnimated() {
        if (root.active) {
            root.hideRecorderIsland()
            return
        }
        if (root.closing || !Services.RecorderState.isVisible)
            return
        root.closePhase = 0
        root.isSettingsOpen = false
        root.closing = true
        settingsStagger.stop()
        closeCircleTimer.restart()
        closeFadeTimer.restart()
        closeTimer.restart()
    }

    Timer {
        id: closeCircleTimer
        interval: 190
        repeat: false
        onTriggered: root.closePhase = 1
    }

    Timer {
        id: closeFadeTimer
        interval: 520
        repeat: false
        onTriggered: root.closePhase = 2
    }

    Timer {
        id: closeTimer
        interval: 940
        repeat: false
        onTriggered: {
            Services.RecorderState.isVisible = false
            root.closing = false
            root.closePhase = 0
            root.settingsStage = 0
        }
    }

    function buildShellCommand(output) {
        const command = root.buildCommand(output).map(function(arg) {
            return root.shellQuote(arg)
        }).join(" ")
        const pidFile = root.shellQuote(root.pidFile)
        const saveDir = root.shellQuote(root.saveDir)
        return "mkdir -p " + saveDir
            + "; rm -f " + pidFile
            + "; " + command + " & recorder_pid=$!"
            + "; printf '%s\\n' \"$recorder_pid\" > " + pidFile
            + "; wait \"$recorder_pid\"; status=$?"
            + "; rm -f " + pidFile
            + "; exit \"$status\""
    }

    function signalCommand(signalName) {
        const pidFile = root.shellQuote(root.pidFile)
        return "recorder_pid=$(cat " + pidFile + " 2>/dev/null)"
            + "; if [ -n \"$recorder_pid\" ]; then kill -" + signalName + " \"$recorder_pid\"; else pkill -" + signalName + " -f '^gpu-screen-recorder( |$)'; fi"
    }

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'"
    }

    function buildCommand(output) {
        const container = root.videoFormat
        const cmd = [
            Services.Config.gpuScreenRecorderBin,
            "-w", captureTarget === "screen" ? "screen" : captureTarget,
            "-f", fps.toString(),
            "-c", container,
            "-k", videoCodec,
            "-ac", audioCodec,
            "-q", quality.toLowerCase(),
            "-o", output
        ]

        const audio = root.audioSources()
        if (audio.length > 0)
            cmd.push("-a", audio)
        if (!showCursor)
            cmd.push("-cursor", "no")

        return cmd
    }

    function audioSources() {
        const sources = []
        if (captureAudio)
            sources.push(root.outputAudioDevice())
        if (captureMic)
            sources.push(root.inputAudioDevice())
        return sources.join("|")
    }

    function outputAudioDevice() {
        if (selectedOutputDevice.length === 0)
            return "default_output"
        if (selectedOutputDevice.indexOf(".monitor") >= 0)
            return "device:" + selectedOutputDevice
        return "device:" + selectedOutputDevice + ".monitor"
    }

    function inputAudioDevice() {
        if (selectedInputDevice.length === 0)
            return "default_input"
        return "device:" + selectedInputDevice
    }

    function refreshAudioDevices() {
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

    function deviceLabel(devices, selectedDevice, fallback) {
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].deviceId === selectedDevice)
                return devices[i].deviceName
        }
        return fallback
    }

    function settingAccent(index) {
        if (!root.theme)
            return "white"
        const palette = [
            root.theme.color4,
            root.theme.color6,
            root.theme.color2,
            root.theme.color3,
            root.theme.color5,
            root.theme.color1
        ]
        return palette[Math.abs(index) % palette.length]
    }

    function settingAccentSecondary(index) {
        if (!root.theme)
            return "white"
        const palette = [
            root.theme.color2,
            root.theme.color5,
            root.theme.color6,
            root.theme.color4,
            root.theme.color1,
            root.theme.color3
        ]
        return palette[Math.abs(index + 2) % palette.length]
    }

    function processError(stderrText, fallback) {
        const text = String(stderrText || "").trim()
        return text.length > 0 ? text.split("\n")[0] : fallback
    }

    function formatFilename(format, date) {
        function pad(v) { return v < 10 ? "0" + v : String(v) }
        return format
            .replace(/%Y/g, String(date.getFullYear()))
            .replace(/%m/g, pad(date.getMonth() + 1))
            .replace(/%d/g, pad(date.getDate()))
            .replace(/%H/g, pad(date.getHours()))
            .replace(/%M/g, pad(date.getMinutes()))
            .replace(/%S/g, pad(date.getSeconds()))
    }

    function formatDuration(seconds) {
        const m = Math.floor(seconds / 60)
        const s = seconds % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    function durationBody(seconds) {
        const minutes = Math.floor(seconds / 60)
        const sec = seconds % 60
        return (minutes > 0 ? minutes + "m " : "") + sec + "s"
    }

    function scheduleRecorderSettingsSave() {
        if (loadingSettings || !stateService || !stateService.ready)
            return
        recorderSettingsSaveDebounce.restart()
    }

    function loadRecorderSettings() {
        if (!stateService || !stateService.ready)
            return

        const saved = stateService.value("recorderSettings", ({}))
        if (!saved || typeof saved !== "object")
            return

        loadingSettings = true
        resolution = saved.resolution !== undefined ? String(saved.resolution) : resolution
        fps = saved.fps !== undefined ? Number(saved.fps) : fps
        videoFormat = saved.videoFormat !== undefined ? String(saved.videoFormat) : videoFormat
        videoCodec = saved.videoCodec !== undefined ? String(saved.videoCodec) : videoCodec
        audioCodec = saved.audioCodec !== undefined ? String(saved.audioCodec) : audioCodec
        quality = saved.quality !== undefined ? String(saved.quality) : quality
        captureTarget = saved.captureTarget !== undefined ? String(saved.captureTarget) : captureTarget
        captureAudio = saved.captureAudio !== undefined ? saved.captureAudio === true : captureAudio
        captureMic = saved.captureMic !== undefined ? saved.captureMic === true : captureMic
        showCursor = saved.showCursor !== undefined ? saved.showCursor === true : showCursor
        selectedOutputDevice = saved.selectedOutputDevice !== undefined ? String(saved.selectedOutputDevice) : selectedOutputDevice
        selectedInputDevice = saved.selectedInputDevice !== undefined ? String(saved.selectedInputDevice) : selectedInputDevice
        saveDir = saved.saveDir !== undefined ? String(saved.saveDir) : saveDir
        filenameFormat = saved.filenameFormat !== undefined ? String(saved.filenameFormat) : filenameFormat
        loadingSettings = false
    }

    function saveRecorderSettings() {
        if (!stateService || !stateService.ready)
            return

        stateService.setValue("recorderSettings", {
            resolution: resolution,
            fps: fps,
            videoFormat: videoFormat,
            videoCodec: videoCodec,
            audioCodec: audioCodec,
            quality: quality,
            captureTarget: captureTarget,
            captureAudio: captureAudio,
            captureMic: captureMic,
            showCursor: showCursor,
            selectedOutputDevice: selectedOutputDevice,
            selectedInputDevice: selectedInputDevice,
            saveDir: saveDir,
            filenameFormat: filenameFormat
        })
    }

    function notifySuccess(path, seconds) {
        const file = path.split("/").pop()
        root.sendDesktopNotification(
            "Recording landed clean",
            file + " saved after " + root.durationBody(seconds) + ". The moment is packed away."
        )
    }

    function notifyError(message) {
        root.sendDesktopNotification("Recording broke mid-flight", message)
    }

    function notifyStarted(path) {
        const file = path.split("/").pop()
        root.sendDesktopNotification(
            "Recording started",
            "Shells is watching the screen now. Saving as " + file + "."
        )
    }

    function sendDesktopNotification(summary, body) {
        Quickshell.execDetached([
            Services.Config.notifySendBin,
            "-a", "Screen Recorder",
            "-i", "media-record",
            summary,
            body
        ])
    }

    function playClickedSound() {
        Quickshell.execDetached([
            "sh",
            "-c",
            "if command -v pw-play >/dev/null 2>&1; then pw-play \"$1\"; elif command -v paplay >/dev/null 2>&1; then paplay \"$1\"; elif command -v mpv >/dev/null 2>&1; then mpv --no-terminal --really-quiet \"$1\"; fi",
            "recorder-clicked-sound",
            Services.Config.clickedSoundPath
        ])
    }

    component RoundIconButton: Rectangle {
        id: button

        property var theme
        property string text: ""
        property color iconColor: "white"
        property color fillColor: "transparent"
        property int size: 32
        property string tooltipText: ""
        property bool rippleEnabled: false
        property bool ambientPulse: false
        property bool lockFillColor: false
        property bool accentGradient: false
        property real pressScale: 1
        property real ambientScale: 1
        property real slideX: 0
        property real scatterOpacity: 1
        property real revealProgress: 1
        property real iconRotation: 0
        property int revealDelay: 0
        signal clicked()

        width: size
        height: size
        radius: size / 2
        color: lockFillColor ? fillColor : (area.containsMouse ? theme.withAlpha(iconColor, fillColor === "transparent" ? 0.12 : 0.22) : fillColor)
        opacity: button.scatterOpacity * button.revealProgress
        scale: pressScale * ambientScale * (area.pressed ? 0.92 : (area.containsMouse ? 1.08 : 1))
        transform: Translate { x: button.slideX }

        Behavior on color { ColorAnimation { duration: theme.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { spring: theme.springStrength; damping: theme.springDamping; mass: 0.9; epsilon: 0.001 } }
        Behavior on slideX { SpringAnimation { duration: theme.reducedMotion ? 0 : 360; spring: 4.4; damping: 0.66; mass: 0.95; epsilon: 0.001 } }
        Behavior on revealProgress {
            SequentialAnimation {
                PauseAnimation { duration: button.theme.reducedMotion ? 0 : button.revealDelay }
                SpringAnimation { duration: button.theme.reducedMotion ? 0 : 360; spring: 5.6; damping: 0.68; mass: 0.85; epsilon: 0.001 }
            }
        }

        SequentialAnimation {
            id: pressAnim
            NumberAnimation { target: button; property: "pressScale"; to: 0.85; duration: button.theme.reducedMotion ? 0 : 70; easing.type: Easing.OutCubic }
            SpringAnimation { target: button; property: "pressScale"; to: 1.0; duration: button.theme.reducedMotion ? 0 : 320; spring: 6.0; damping: 0.5; mass: 0.9; epsilon: 0.001 }
        }

        SequentialAnimation on ambientScale {
            running: button.ambientPulse && !button.theme.reducedMotion
            loops: Animation.Infinite
            NumberAnimation { to: 1.04; duration: 1500; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 1500; easing.type: Easing.InOutSine }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            opacity: button.accentGradient ? 1 : 0
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: button.theme.withAlpha(button.iconColor, 0.26) }
                GradientStop { position: 0.58; color: button.theme.withAlpha(button.theme.color2, 0.13) }
                GradientStop { position: 1.0; color: button.theme.withAlpha(button.theme.background, 0) }
            }

            Behavior on opacity { NumberAnimation { duration: button.theme.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic } }
        }

        SequentialAnimation {
            id: iconSwing
            NumberAnimation { target: button; property: "iconRotation"; to: -14; duration: button.theme.reducedMotion ? 0 : 70; easing.type: Easing.OutCubic }
            NumberAnimation { target: button; property: "iconRotation"; to: 12; duration: button.theme.reducedMotion ? 0 : 90; easing.type: Easing.InOutCubic }
            NumberAnimation { target: button; property: "iconRotation"; to: -7; duration: button.theme.reducedMotion ? 0 : 80; easing.type: Easing.InOutCubic }
            NumberAnimation { target: button; property: "iconRotation"; to: 4; duration: button.theme.reducedMotion ? 0 : 70; easing.type: Easing.InOutCubic }
            SpringAnimation { target: button; property: "iconRotation"; to: 0; duration: button.theme.reducedMotion ? 0 : 240; spring: 5.8; damping: 0.72; mass: 0.9; epsilon: 0.001 }
        }

        function swingIcon() {
            iconSwing.restart()
        }

        Rectangle {
            id: ripple
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            radius: width / 2
            color: "transparent"
            border.color: button.iconColor
            border.width: 2
            opacity: 0
            scale: 1

            ParallelAnimation {
                id: rippleAnim
                NumberAnimation { target: ripple; property: "scale"; from: 1; to: 2.2; duration: button.theme.reducedMotion ? 0 : 400; easing.type: Easing.OutCubic }
                NumberAnimation { target: ripple; property: "opacity"; from: 0.4; to: 0; duration: button.theme.reducedMotion ? 0 : 400; easing.type: Easing.OutCubic }
            }
        }

        Text {
            anchors.centerIn: parent
            text: button.text
            color: button.iconColor
            font.family: button.theme.fontFamily
            font.pixelSize: 15 * button.theme.fontScale
            font.bold: button.theme.fontBold
            rotation: button.iconRotation
            transformOrigin: Item.Center
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (button.rippleEnabled)
                    rippleAnim.restart()
                pressAnim.restart()
                button.clicked()
            }
        }
    }

    component FlipDigit: Item {
        id: digit

        property var theme
        property string value: ""
        property string shownValue: value
        property string nextValue: value
        property real progress: 0
        property bool ready: false

        width: value === ":" ? 5 : 8
        height: 18
        clip: true

        Component.onCompleted: {
            shownValue = value
            nextValue = value
            ready = true
        }

        onValueChanged: {
            if (!ready) {
                shownValue = value
                nextValue = value
                return
            }
            if (value === shownValue)
                return
            nextValue = value
            flip.restart()
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: -digit.progress * digit.height
            opacity: 1 - digit.progress
            text: digit.shownValue
            color: digit.theme.foreground
            font.family: digit.theme.fontFamily
            font.pixelSize: 12 * digit.theme.fontScale
            font.bold: digit.theme.fontBold
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: digit.height - digit.progress * digit.height
            opacity: digit.progress
            text: digit.nextValue
            color: digit.theme.foreground
            font.family: digit.theme.fontFamily
            font.pixelSize: 12 * digit.theme.fontScale
            font.bold: digit.theme.fontBold
        }

        SequentialAnimation {
            id: flip
            NumberAnimation { target: digit; property: "progress"; from: 0; to: 1; duration: digit.theme.reducedMotion ? 0 : 210; easing.type: Easing.OutCubic }
            ScriptAction {
                script: {
                    digit.shownValue = digit.nextValue
                    digit.progress = 0
                }
            }
        }
    }

    component SectionLabel: RowLayout {
        id: sectionLabel
        property var theme
        property int staggerIndex: 0
        property color accent: root.settingAccent(staggerIndex)
        property string text: ""
        property real revealOffset: root.isSettingsOpen && root.settingsStage >= staggerIndex ? 0 : 6
        opacity: root.isSettingsOpen && root.settingsStage >= staggerIndex ? 1 : 0
        transform: Translate { y: revealOffset }
        width: parent ? parent.width : implicitWidth
        height: 24
        spacing: 8

        Text {
            text: sectionLabel.text.toUpperCase()
            color: sectionLabel.accent
            font.family: sectionLabel.theme.fontFamily
            font.pixelSize: 9 * sectionLabel.theme.fontScale
            font.bold: true
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            radius: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: sectionLabel.theme.withAlpha(sectionLabel.accent, 0.34) }
                GradientStop { position: 1.0; color: sectionLabel.theme.withAlpha(sectionLabel.theme.color1, 0.10) }
            }
        }

        Behavior on opacity { NumberAnimation { duration: theme.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic } }
        Behavior on revealOffset { NumberAnimation { duration: theme.reducedMotion ? 0 : 220; easing.type: Easing.OutCubic } }
    }

    component SegmentPicker: Column {
        id: picker

        property var theme
        property int staggerIndex: 0
        property real revealOffset: root.isSettingsOpen && root.settingsStage >= staggerIndex ? 0 : 6
        property string label: ""
        property var options: []
        property string value: ""
        property color accent: root.settingAccent(staggerIndex)
        property color secondary: root.settingAccentSecondary(staggerIndex)
        readonly property int rawSelectedIndex: options.indexOf(value)
        readonly property int selectedIndex: rawSelectedIndex < 0 ? 0 : rawSelectedIndex
        signal selected(string value)

        width: parent ? parent.width : implicitWidth
        height: 58
        spacing: 7
        opacity: root.isSettingsOpen && root.settingsStage >= staggerIndex ? 1 : 0
        scale: pickerHover.hovered ? 1.006 : 1
        transform: Translate { y: revealOffset }

        Behavior on scale { SpringAnimation { duration: picker.theme.reducedMotion ? 0 : 260; spring: 5.2; damping: 0.82; mass: 0.9; epsilon: 0.001 } }
        Behavior on opacity { NumberAnimation { duration: picker.theme.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic } }
        Behavior on revealOffset { NumberAnimation { duration: picker.theme.reducedMotion ? 0 : 220; easing.type: Easing.OutCubic } }

        HoverHandler {
            id: pickerHover
        }

        Text {
            width: parent.width
            text: picker.label
            color: picker.theme.color6
            font.family: picker.theme.fontFamily
            font.pixelSize: 9 * picker.theme.fontScale
            font.bold: true
            elide: Text.ElideRight
        }

        Rectangle {
            width: parent.width
            height: 34
            radius: 13
            color: pickerHover.hovered ? picker.theme.withAlpha(picker.theme.color1, 0.24) : picker.theme.withAlpha(picker.theme.color1, 0.18)
            clip: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: picker.theme.withAlpha(picker.accent, pickerHover.hovered ? 0.13 : 0.065) }
                GradientStop { position: 0.52; color: picker.theme.withAlpha(picker.secondary, pickerHover.hovered ? 0.075 : 0.035) }
                GradientStop { position: 1.0; color: picker.theme.withAlpha(picker.theme.color1, 0.10) }
            }

            Behavior on color { ColorAnimation { duration: picker.theme.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic } }

            Rectangle {
                id: segmentBloom
                x: segmentHighlight.x - 9
                y: segmentHighlight.y - 4
                width: segmentHighlight.width + 18
                height: segmentHighlight.height + 8
                radius: 15
                opacity: picker.rawSelectedIndex >= 0 ? 0.45 : 0
                color: picker.theme.withAlpha(picker.accent, 0.13)

                Behavior on opacity { NumberAnimation { duration: picker.theme.reducedMotion || !root.settingsSelectionMotionReady ? 0 : 120; easing.type: Easing.OutCubic } }
            }

            Rectangle {
                id: segmentHighlight
                x: 3 + picker.selectedIndex * (width + 3)
                y: 3
                width: Math.max(1, ((parent.width - 6) - 3 * Math.max(0, picker.options.length - 1)) / Math.max(1, picker.options.length))
                height: parent.height - 6
                radius: 10
                opacity: picker.rawSelectedIndex >= 0 ? 1 : 0
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: picker.theme.withAlpha(picker.accent, 0.30) }
                    GradientStop { position: 0.55; color: picker.theme.withAlpha(picker.secondary, 0.16) }
                    GradientStop { position: 1.0; color: picker.theme.withAlpha(picker.accent, 0.12) }
                }

                Behavior on x { NumberAnimation { duration: picker.theme.reducedMotion || !root.settingsSelectionMotionReady ? 0 : 190; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: picker.theme.reducedMotion || !root.settingsSelectionMotionReady ? 0 : 190; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: picker.theme.reducedMotion || !root.settingsSelectionMotionReady ? 0 : 120; easing.type: Easing.OutCubic } }
            }

            Row {
                id: segmentRow
                anchors.fill: parent
                anchors.margins: 3
                spacing: 3
                z: 2

                Repeater {
                    model: picker.options

                    Rectangle {
                        width: Math.max(1, (segmentRow.width - segmentRow.spacing * Math.max(0, picker.options.length - 1)) / Math.max(1, picker.options.length))
                        height: segmentRow.height
                        radius: 10
                        color: optionArea.containsMouse && modelData !== picker.value ? picker.theme.withAlpha(picker.theme.foreground, 0.06) : "transparent"
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: optionArea.containsMouse && modelData !== picker.value ? picker.theme.withAlpha(picker.accent, 0.06) : "transparent" }
                            GradientStop { position: 0.55; color: "transparent" }
                            GradientStop { position: 1.0; color: optionArea.containsMouse ? picker.theme.withAlpha(picker.theme.foreground, 0.035) : "transparent" }
                        }
                        scale: optionArea.pressed ? 0.96 : (optionArea.containsMouse ? 1.025 : (modelData === picker.value ? 1.018 : 1))

                        Behavior on color { ColorAnimation { duration: picker.theme.reducedMotion ? 0 : 170; easing.type: Easing.OutCubic } }
                        Behavior on scale { SpringAnimation { duration: picker.theme.reducedMotion || !root.settingsSelectionMotionReady ? 0 : 180; spring: 5.0; damping: 0.80; mass: 0.9; epsilon: 0.001 } }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            height: 2
                            radius: 1
                            color: picker.accent
                            opacity: modelData === picker.value ? 1 : 0
                            scale: modelData === picker.value ? 1 : 0.2
                            Behavior on opacity { NumberAnimation { duration: picker.theme.reducedMotion || !root.settingsSelectionMotionReady ? 0 : 150; easing.type: Easing.OutCubic } }
                            Behavior on scale { SpringAnimation { duration: picker.theme.reducedMotion || !root.settingsSelectionMotionReady ? 0 : 260; spring: 5.0; damping: 0.78; mass: 0.9; epsilon: 0.001 } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: modelData === picker.value ? picker.theme.foreground : picker.theme.color7
                            font.family: picker.theme.fontFamily
                            font.pixelSize: 10 * picker.theme.fontScale
                            font.bold: modelData === picker.value
                            scale: modelData === picker.value ? 1.035 : 1

                            Behavior on color { ColorAnimation { duration: picker.theme.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic } }
                            Behavior on scale { SpringAnimation { duration: picker.theme.reducedMotion || !root.settingsSelectionMotionReady ? 0 : 170; spring: 5.0; damping: 0.82; mass: 0.9; epsilon: 0.001 } }
                        }

                        MouseArea {
                            id: optionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: picker.selected(modelData)
                        }
                    }
                }
            }
        }
    }

    component ToggleRow: Rectangle {
        id: toggleRow

        property var theme
        property int staggerIndex: 0
        property real revealOffset: root.isSettingsOpen && root.settingsStage >= staggerIndex ? 0 : 6
        property string label: ""
        property bool checked: false
        property color accent: root.settingAccent(staggerIndex)
        property color secondary: root.settingAccentSecondary(staggerIndex)
        signal changed(bool checked)

        width: parent ? parent.width : implicitWidth
        height: 42
        radius: 14
        clip: true
        color: rowArea.containsMouse ? toggleRow.theme.withAlpha(toggleRow.accent, 0.10) : toggleRow.theme.withAlpha(toggleRow.theme.color1, 0.14)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: toggleRow.checked ? toggleRow.theme.withAlpha(toggleRow.accent, 0.13) : toggleRow.theme.withAlpha(toggleRow.theme.color1, 0.12) }
            GradientStop { position: 0.58; color: rowArea.containsMouse ? toggleRow.theme.withAlpha(toggleRow.secondary, 0.075) : toggleRow.theme.withAlpha(toggleRow.secondary, 0.030) }
            GradientStop { position: 1.0; color: toggleRow.theme.withAlpha(toggleRow.theme.background, 0) }
        }
        opacity: root.isSettingsOpen && root.settingsStage >= staggerIndex ? 1 : 0
        scale: rowArea.pressed ? 0.985 : (rowArea.containsMouse ? 1.012 : 1)
        transform: Translate { y: revealOffset }

        Behavior on scale { SpringAnimation { duration: toggleRow.theme.reducedMotion ? 0 : 260; spring: 5.2; damping: 0.82; mass: 0.9; epsilon: 0.001 } }
        Behavior on color { ColorAnimation { duration: toggleRow.theme.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: toggleRow.theme.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic } }
        Behavior on revealOffset { NumberAnimation { duration: toggleRow.theme.reducedMotion ? 0 : 220; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 4
            width: toggleRow.checked ? parent.width - 8 : 0
            height: parent.height - 8
            radius: 11
            opacity: toggleRow.checked ? 0.9 : 0
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: toggleRow.theme.withAlpha(toggleRow.accent, 0.16) }
                GradientStop { position: 0.64; color: toggleRow.theme.withAlpha(toggleRow.secondary, 0.08) }
                GradientStop { position: 1.0; color: toggleRow.theme.withAlpha(toggleRow.theme.background, 0) }
            }

            Behavior on width { SpringAnimation { duration: toggleRow.theme.reducedMotion || !root.settingsSelectionMotionReady ? 0 : 340; spring: 4.5; damping: 0.78; mass: 0.9; epsilon: 0.001 } }
            Behavior on opacity { NumberAnimation { duration: toggleRow.theme.reducedMotion || !root.settingsSelectionMotionReady ? 0 : 170; easing.type: Easing.OutCubic } }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 10
            spacing: 4

            Rectangle {
                width: 26
                height: 26
                radius: 9
                color: toggleRow.checked ? toggleRow.theme.withAlpha(toggleRow.accent, 0.20) : toggleRow.theme.withAlpha(toggleRow.theme.color1, 0.18)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: toggleRow.checked ? toggleRow.theme.withAlpha(toggleRow.accent, 0.28) : toggleRow.theme.withAlpha(toggleRow.theme.color1, 0.18) }
                    GradientStop { position: 1.0; color: toggleRow.checked ? toggleRow.theme.withAlpha(toggleRow.secondary, 0.14) : toggleRow.theme.withAlpha(toggleRow.theme.background, 0) }
                }
                scale: toggleRow.checked ? 1.06 : 1

                Behavior on color { ColorAnimation { duration: toggleRow.theme.reducedMotion ? 0 : 170; easing.type: Easing.OutCubic } }
                Behavior on scale { SpringAnimation { duration: toggleRow.theme.reducedMotion || !root.settingsSelectionMotionReady ? 0 : 300; spring: 5.8; damping: 0.70; mass: 0.85; epsilon: 0.001 } }

                Text {
                    anchors.centerIn: parent
                    text: toggleRow.checked ? "󰄵" : "󰅖"
                    color: toggleRow.checked ? toggleRow.accent : toggleRow.theme.color6
                    font.family: toggleRow.theme.fontFamily
                    font.pixelSize: 12 * toggleRow.theme.fontScale
                }
            }

            Text {
                Layout.fillWidth: true
                text: toggleRow.label
                color: toggleRow.theme.foreground
                font.family: toggleRow.theme.fontFamily
                font.pixelSize: 11 * toggleRow.theme.fontScale
                font.bold: toggleRow.theme.fontBold
            }

            M3Switch {
                theme: toggleRow.theme
                primary: toggleRow.accent
                checked: toggleRow.checked
                width: 46
                height: 26
                onToggled: toggleRow.changed(checked)
            }
        }

        MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleRow.changed(!toggleRow.checked)
        }
    }

    component OptionDropdown: Column {
        id: dropdown

        property var theme
        property int staggerIndex: 0
        property real revealOffset: root.isSettingsOpen && root.settingsStage >= staggerIndex ? 0 : 6
        property string label: ""
        property var options: []
        property string value: ""
        property bool expanded: false
        property color accent: root.settingAccent(staggerIndex)
        property color secondary: root.settingAccentSecondary(staggerIndex)
        signal selected(string value)

        width: parent ? parent.width : implicitWidth
        height: header.height + (expanded ? optionsList.implicitHeight + 6 : 0)
        spacing: 6
        clip: true
        opacity: root.isSettingsOpen && root.settingsStage >= staggerIndex ? 1 : 0
        scale: headerArea.containsMouse ? 1.006 : 1
        transform: Translate { y: revealOffset }

        Behavior on scale { SpringAnimation { duration: dropdown.theme.reducedMotion ? 0 : 260; spring: 5.2; damping: 0.82; mass: 0.9; epsilon: 0.001 } }
        Behavior on height { NumberAnimation { duration: dropdown.theme.reducedMotion ? 0 : 220; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: dropdown.theme.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic } }
        Behavior on revealOffset { NumberAnimation { duration: dropdown.theme.reducedMotion ? 0 : 220; easing.type: Easing.OutCubic } }

        Rectangle {
            id: header
            width: parent.width
            height: 42
            radius: 14
            color: dropdown.expanded
                ? dropdown.theme.withAlpha(dropdown.accent, 0.14)
                : (headerArea.containsMouse ? dropdown.theme.withAlpha(dropdown.accent, 0.10) : dropdown.theme.withAlpha(dropdown.theme.color1, 0.16))
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: dropdown.expanded ? dropdown.theme.withAlpha(dropdown.accent, 0.16) : dropdown.theme.withAlpha(dropdown.theme.color1, 0.14) }
                GradientStop { position: 0.62; color: headerArea.containsMouse ? dropdown.theme.withAlpha(dropdown.secondary, 0.075) : dropdown.theme.withAlpha(dropdown.secondary, 0.030) }
                GradientStop { position: 1.0; color: dropdown.theme.withAlpha(dropdown.theme.background, 0) }
            }
            border.width: 0

            Behavior on color { ColorAnimation { duration: dropdown.theme.reducedMotion ? 0 : 150; easing.type: Easing.OutCubic } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 10
                spacing: 8

                Text {
                    Layout.preferredWidth: 74
                    text: dropdown.label
                    color: dropdown.theme.color6
                    font.family: dropdown.theme.fontFamily
                    font.pixelSize: 9 * dropdown.theme.fontScale
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: dropdown.value
                    color: dropdown.theme.foreground
                    font.family: dropdown.theme.fontFamily
                    font.pixelSize: 12 * dropdown.theme.fontScale
                    font.bold: true
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }

                Text {
                    text: "󰅀"
                    color: dropdown.theme.color6
                    font.family: dropdown.theme.fontFamily
                    font.pixelSize: 12 * dropdown.theme.fontScale
                    rotation: dropdown.expanded ? 180 : 0

                    Behavior on rotation { NumberAnimation { duration: dropdown.theme.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic } }
                }
            }

            MouseArea {
                id: headerArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: dropdown.expanded = !dropdown.expanded
            }
        }

        Column {
            id: optionsList
            width: parent.width
            spacing: 4

            Repeater {
                model: dropdown.options

                Rectangle {
                    property real rowOffset: dropdown.expanded ? 0 : -4
                    readonly property bool selected: modelData === dropdown.value
                    width: parent.width
                    height: 34
                    radius: 12
                    color: selected
                        ? dropdown.theme.withAlpha(dropdown.accent, 0.20)
                        : (optionArea.containsMouse ? dropdown.theme.withAlpha(dropdown.accent, 0.08) : "transparent")
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: selected ? dropdown.theme.withAlpha(dropdown.accent, 0.18) : "transparent" }
                        GradientStop { position: 0.70; color: optionArea.containsMouse ? dropdown.theme.withAlpha(dropdown.secondary, 0.060) : "transparent" }
                        GradientStop { position: 1.0; color: dropdown.theme.withAlpha(dropdown.theme.background, 0) }
                    }
                    scale: optionArea.pressed ? 0.98 : 1
                    opacity: dropdown.expanded ? 1 : 0
                    transform: Translate { y: rowOffset }

                    Behavior on color { ColorAnimation { duration: dropdown.theme.reducedMotion ? 0 : 140; easing.type: Easing.OutCubic } }
                    Behavior on scale { SpringAnimation { duration: dropdown.theme.reducedMotion ? 0 : 200; spring: 4.8; damping: 0.76; mass: 0.9; epsilon: 0.001 } }
                    Behavior on opacity { NumberAnimation { duration: dropdown.theme.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }
                    Behavior on rowOffset { SpringAnimation { duration: dropdown.theme.reducedMotion ? 0 : 260; spring: 5.0; damping: 0.76; mass: 0.9; epsilon: 0.001 } }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: selected ? 3 : 0
                        height: selected ? parent.height - 12 : 4
                        radius: 2
                        opacity: selected ? 1 : 0
                        color: dropdown.accent

                        Behavior on width { SpringAnimation { duration: dropdown.theme.reducedMotion || !root.settingsSelectionMotionReady ? 0 : 240; spring: 5.4; damping: 0.76; mass: 0.9; epsilon: 0.001 } }
                        Behavior on height { SpringAnimation { duration: dropdown.theme.reducedMotion || !root.settingsSelectionMotionReady ? 0 : 240; spring: 5.4; damping: 0.76; mass: 0.9; epsilon: 0.001 } }
                        Behavior on opacity { NumberAnimation { duration: dropdown.theme.reducedMotion || !root.settingsSelectionMotionReady ? 0 : 140; easing.type: Easing.OutCubic } }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10

                        Text {
                            Layout.fillWidth: true
                            text: modelData
                            color: selected ? dropdown.accent : dropdown.theme.foreground
                            font.family: dropdown.theme.fontFamily
                            font.pixelSize: 11 * dropdown.theme.fontScale
                            font.bold: selected

                            Behavior on color { ColorAnimation { duration: dropdown.theme.reducedMotion ? 0 : 150; easing.type: Easing.OutCubic } }
                        }

                        Text {
                            opacity: selected ? 1 : 0
                            scale: selected ? 1 : 0.55
                            text: "󰄵"
                            color: dropdown.accent
                            font.family: dropdown.theme.fontFamily
                            font.pixelSize: 13 * dropdown.theme.fontScale

                            Behavior on opacity { NumberAnimation { duration: dropdown.theme.reducedMotion || !root.settingsSelectionMotionReady ? 0 : 150; easing.type: Easing.OutCubic } }
                            Behavior on scale { SpringAnimation { duration: dropdown.theme.reducedMotion || !root.settingsSelectionMotionReady ? 0 : 260; spring: 5.4; damping: 0.70; mass: 0.85; epsilon: 0.001 } }
                        }
                    }

                    MouseArea {
                        id: optionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            dropdown.selected(modelData)
                            dropdown.expanded = false
                        }
                    }
                }
            }
        }
    }

    component DevicePicker: Column {
        id: devicePicker

        property var theme
        property int staggerIndex: 0
        property real revealOffset: root.isSettingsOpen && root.settingsStage >= staggerIndex ? 0 : 6
        property string label: ""
        property string icon: ""
        property var devices: []
        property string selectedDevice: ""
        property string emptyText: ""
        property bool expanded: false
        property color accent: root.settingAccent(staggerIndex)
        property color secondary: root.settingAccentSecondary(staggerIndex)
        signal selected(string deviceId)

        width: parent ? parent.width : implicitWidth
        height: header.height + (expanded ? deviceList.implicitHeight + 6 : 0)
        opacity: (enabled ? 1 : 0.48) * (root.isSettingsOpen && root.settingsStage >= staggerIndex ? 1 : 0)
        scale: headerArea.containsMouse && devicePicker.enabled ? 1.006 : 1
        spacing: 6
        clip: true
        transform: Translate { y: revealOffset }

        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 260; spring: 5.2; damping: 0.82; mass: 0.9; epsilon: 0.001 } }
        Behavior on height { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250; spring: 4.4; damping: 0.76; mass: 0.9; epsilon: 0.001 } }
        Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? 0 : 150; easing.type: Easing.OutCubic } }
        Behavior on revealOffset { NumberAnimation { duration: theme && theme.reducedMotion ? 0 : 220; easing.type: Easing.OutCubic } }

        Rectangle {
            id: header
            width: parent.width
            height: 44
            radius: 15
            color: headerArea.containsMouse && devicePicker.enabled
                ? devicePicker.theme.withAlpha(devicePicker.accent, 0.12)
                : devicePicker.theme.withAlpha(devicePicker.theme.color1, 0.16)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: devicePicker.enabled ? devicePicker.theme.withAlpha(devicePicker.accent, devicePicker.expanded ? 0.15 : 0.085) : devicePicker.theme.withAlpha(devicePicker.theme.color1, 0.10) }
                GradientStop { position: 0.56; color: headerArea.containsMouse && devicePicker.enabled ? devicePicker.theme.withAlpha(devicePicker.secondary, 0.080) : devicePicker.theme.withAlpha(devicePicker.secondary, 0.030) }
                GradientStop { position: 1.0; color: devicePicker.theme.withAlpha(devicePicker.theme.background, 0) }
            }
            border.width: 0

            Behavior on color { ColorAnimation { duration: devicePicker.theme.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 10
                spacing: 8

                Rectangle {
                    width: 28
                    height: 28
                    radius: 10
                    color: devicePicker.enabled ? devicePicker.theme.withAlpha(devicePicker.accent, 0.18) : devicePicker.theme.withAlpha(devicePicker.theme.color1, 0.14)
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: devicePicker.enabled ? devicePicker.theme.withAlpha(devicePicker.accent, 0.24) : devicePicker.theme.withAlpha(devicePicker.theme.color1, 0.14) }
                        GradientStop { position: 1.0; color: devicePicker.enabled ? devicePicker.theme.withAlpha(devicePicker.secondary, 0.10) : devicePicker.theme.withAlpha(devicePicker.theme.background, 0) }
                    }
                    scale: devicePicker.expanded ? 1.08 : 1

                    Behavior on scale { SpringAnimation { duration: devicePicker.theme.reducedMotion ? 0 : 300; spring: 5.8; damping: 0.70; mass: 0.85; epsilon: 0.001 } }

                    Text {
                        anchors.centerIn: parent
                        text: devicePicker.icon
                        color: devicePicker.enabled ? devicePicker.accent : devicePicker.theme.color6
                        font.family: devicePicker.theme.fontFamily
                        font.pixelSize: 13 * devicePicker.theme.fontScale
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        width: parent.width
                        text: devicePicker.label.toUpperCase()
                        color: devicePicker.theme.color6
                        font.family: devicePicker.theme.fontFamily
                        font.pixelSize: 8 * devicePicker.theme.fontScale
                        font.bold: true
                    }
                    Text {
                        width: parent.width
                        text: root.deviceLabel(devicePicker.devices, devicePicker.selectedDevice, devicePicker.emptyText)
                        color: devicePicker.theme.foreground
                        font.family: devicePicker.theme.fontFamily
                        font.pixelSize: 11 * devicePicker.theme.fontScale
                        font.bold: devicePicker.theme.fontBold
                        elide: Text.ElideRight
                    }
                }

                Text {
                    text: "󰅀"
                    color: devicePicker.theme.color6
                    font.family: devicePicker.theme.fontFamily
                    font.pixelSize: 12 * devicePicker.theme.fontScale
                    rotation: devicePicker.expanded ? 180 : 0

                    Behavior on rotation { SpringAnimation { duration: devicePicker.theme.reducedMotion ? 0 : 250; spring: devicePicker.theme.springStrength; damping: devicePicker.theme.springDamping; mass: 0.9; epsilon: 0.001 } }
                }
            }

            MouseArea {
                id: headerArea
                anchors.fill: parent
                enabled: devicePicker.enabled
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: devicePicker.expanded = !devicePicker.expanded
            }
        }

        Column {
            id: deviceList
            width: parent.width
            spacing: 4

            Repeater {
                model: devicePicker.devices.length > 0 ? devicePicker.devices : [{ deviceId: "", deviceName: devicePicker.emptyText, isDefault: false }]

                Rectangle {
                    property real rowOffset: devicePicker.expanded ? 0 : -4
                    readonly property bool selected: modelData.deviceId === devicePicker.selectedDevice
                    readonly property bool defaultDevice: modelData.isDefault
                    width: parent.width
                    height: 36
                    radius: 12
                    color: selected
                        ? devicePicker.theme.withAlpha(devicePicker.accent, 0.18)
                        : (rowArea.containsMouse ? devicePicker.theme.withAlpha(devicePicker.theme.foreground, 0.05) : "transparent")
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: selected ? devicePicker.theme.withAlpha(devicePicker.accent, 0.16) : "transparent" }
                        GradientStop { position: 0.70; color: rowArea.containsMouse ? devicePicker.theme.withAlpha(devicePicker.secondary, 0.055) : "transparent" }
                        GradientStop { position: 1.0; color: devicePicker.theme.withAlpha(devicePicker.theme.background, 0) }
                    }
                    scale: rowArea.pressed ? 0.98 : 1
                    opacity: devicePicker.expanded ? 1 : 0
                    transform: Translate { y: rowOffset }

                    Behavior on color { ColorAnimation { duration: devicePicker.theme.reducedMotion ? 0 : 140; easing.type: Easing.OutCubic } }
                    Behavior on scale { SpringAnimation { duration: devicePicker.theme.reducedMotion ? 0 : 200; spring: 4.8; damping: 0.76; mass: 0.9; epsilon: 0.001 } }
                    Behavior on opacity { NumberAnimation { duration: devicePicker.theme.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }
                    Behavior on rowOffset { SpringAnimation { duration: devicePicker.theme.reducedMotion ? 0 : 260; spring: 5.0; damping: 0.76; mass: 0.9; epsilon: 0.001 } }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: selected ? 3 : 0
                        height: selected ? parent.height - 12 : 4
                        radius: 2
                        opacity: selected ? 1 : 0
                        color: devicePicker.accent

                        Behavior on width { SpringAnimation { duration: devicePicker.theme.reducedMotion || !root.settingsSelectionMotionReady ? 0 : 240; spring: 5.4; damping: 0.76; mass: 0.9; epsilon: 0.001 } }
                        Behavior on height { SpringAnimation { duration: devicePicker.theme.reducedMotion || !root.settingsSelectionMotionReady ? 0 : 240; spring: 5.4; damping: 0.76; mass: 0.9; epsilon: 0.001 } }
                        Behavior on opacity { NumberAnimation { duration: devicePicker.theme.reducedMotion || !root.settingsSelectionMotionReady ? 0 : 140; easing.type: Easing.OutCubic } }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: modelData.deviceName
                            color: selected ? devicePicker.accent : devicePicker.theme.foreground
                            font.family: devicePicker.theme.fontFamily
                            font.pixelSize: 11 * devicePicker.theme.fontScale
                            font.bold: selected
                            elide: Text.ElideRight

                            Behavior on color { ColorAnimation { duration: devicePicker.theme.reducedMotion ? 0 : 150; easing.type: Easing.OutCubic } }
                        }

                        Text {
                            opacity: selected || defaultDevice ? 1 : 0
                            scale: selected ? 1 : 0.72
                            text: selected ? "󰄵" : "default"
                            color: devicePicker.accent
                            font.family: devicePicker.theme.fontFamily
                            font.pixelSize: selected ? 13 * devicePicker.theme.fontScale : 9 * devicePicker.theme.fontScale
                            font.bold: true

                            Behavior on opacity { NumberAnimation { duration: devicePicker.theme.reducedMotion || !root.settingsSelectionMotionReady ? 0 : 150; easing.type: Easing.OutCubic } }
                            Behavior on scale { SpringAnimation { duration: devicePicker.theme.reducedMotion || !root.settingsSelectionMotionReady ? 0 : 260; spring: 5.4; damping: 0.70; mass: 0.85; epsilon: 0.001 } }
                        }
                    }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        enabled: modelData.deviceId.length > 0
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            devicePicker.selected(modelData.deviceId)
                            devicePicker.expanded = false
                        }
                    }
                }
            }
        }
    }

    component OutputRow: Column {
        id: outputRow

        property var theme
        property int staggerIndex: 0
        property real revealOffset: root.isSettingsOpen && root.settingsStage >= staggerIndex ? 0 : 6
        property string saveDir: ""
        property string filenameFormat: ""
        property color accent: root.settingAccent(staggerIndex)
        property color secondary: root.settingAccentSecondary(staggerIndex)
        signal openFolder()
        signal filenameChanged(string value)

        width: parent ? parent.width : implicitWidth
        spacing: 8
        opacity: root.isSettingsOpen && root.settingsStage >= staggerIndex ? 1 : 0
        scale: outputHover.hovered ? 1.006 : 1
        transform: Translate { y: revealOffset }

        Behavior on scale { SpringAnimation { duration: outputRow.theme.reducedMotion ? 0 : 260; spring: 5.2; damping: 0.82; mass: 0.9; epsilon: 0.001 } }
        Behavior on opacity { NumberAnimation { duration: outputRow.theme.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic } }
        Behavior on revealOffset { NumberAnimation { duration: outputRow.theme.reducedMotion ? 0 : 220; easing.type: Easing.OutCubic } }

        HoverHandler {
            id: outputHover
        }

        Rectangle {
            width: parent.width
            height: 48
            radius: 15
            color: outputHover.hovered ? outputRow.theme.withAlpha(outputRow.accent, 0.10) : outputRow.theme.withAlpha(outputRow.theme.color1, 0.15)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: outputRow.theme.withAlpha(outputRow.accent, outputHover.hovered ? 0.13 : 0.075) }
                GradientStop { position: 0.58; color: outputRow.theme.withAlpha(outputRow.secondary, outputHover.hovered ? 0.075 : 0.035) }
                GradientStop { position: 1.0; color: outputRow.theme.withAlpha(outputRow.theme.background, 0) }
            }

            Behavior on color { ColorAnimation { duration: outputRow.theme.reducedMotion ? 0 : 170; easing.type: Easing.OutCubic } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 10
                spacing: 8

                Rectangle {
                    width: 28
                    height: 28
                    radius: 10
                    color: outputRow.theme.withAlpha(outputRow.accent, 0.17)
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: outputRow.theme.withAlpha(outputRow.accent, 0.24) }
                        GradientStop { position: 1.0; color: outputRow.theme.withAlpha(outputRow.secondary, 0.10) }
                    }
                    scale: outputHover.hovered ? 1.08 : 1

                    Behavior on scale { SpringAnimation { duration: outputRow.theme.reducedMotion ? 0 : 300; spring: 5.8; damping: 0.70; mass: 0.85; epsilon: 0.001 } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰉋"
                        color: outputRow.accent
                        font.family: outputRow.theme.fontFamily
                        font.pixelSize: 13 * outputRow.theme.fontScale
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        width: parent.width
                        text: "SAVE TO"
                        color: outputRow.theme.color6
                        font.family: outputRow.theme.fontFamily
                        font.pixelSize: 8 * outputRow.theme.fontScale
                        font.bold: true
                    }

                    Text {
                        width: parent.width
                        text: outputRow.saveDir.replace(Quickshell.env("HOME"), "~")
                        color: outputRow.theme.foreground
                        font.family: outputRow.theme.fontFamily
                        font.pixelSize: 11 * outputRow.theme.fontScale
                        font.bold: outputRow.theme.fontBold
                        elide: Text.ElideRight
                    }
                }

                RoundIconButton {
                    theme: outputRow.theme
                    text: "󰢞"
                    iconColor: outputRow.theme.foreground
                    fillColor: outputRow.theme.withAlpha(outputRow.accent, 0.14)
                    size: 28
                    onClicked: outputRow.openFolder()
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 40
            radius: 14
            color: filenameInput.activeFocus ? outputRow.theme.withAlpha(outputRow.accent, 0.12) : outputRow.theme.withAlpha(outputRow.theme.color1, 0.14)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: filenameInput.activeFocus ? outputRow.theme.withAlpha(outputRow.accent, 0.12) : outputRow.theme.withAlpha(outputRow.theme.color1, 0.12) }
                GradientStop { position: 1.0; color: outputRow.theme.withAlpha(outputRow.theme.background, 0) }
            }
            border.width: 0

            Behavior on color { ColorAnimation { duration: outputRow.theme.reducedMotion ? 0 : 170; easing.type: Easing.OutCubic } }

            TextInput {
                id: filenameInput
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                text: outputRow.filenameFormat
                color: outputRow.theme.foreground
                selectionColor: outputRow.accent
                selectedTextColor: outputRow.theme.color0
                font.family: outputRow.theme.fontFamily
                font.pixelSize: 11 * outputRow.theme.fontScale
                onTextChanged: outputRow.filenameChanged(text)
            }
        }
    }
}

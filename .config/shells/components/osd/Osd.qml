import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../services" as Services

PanelWindow {
    id: root

    property var theme
    property bool expanded: false
    property bool presenting: false
    property bool vanishing: false
    property bool closing: false
    property string kind: "volume"
    property string headerText: "Volume"
    property string subtitle: "Ready"
    property string iconSource: iconPath("audio.svg")
    property real value: 0
    property bool showMeter: true
    property color accent: theme ? theme.withAlpha(theme.color4, 1) : "#8aadf4"
    property color accentSoft: theme ? theme.withAlpha(theme.color4, 0.18) : Qt.rgba(0.5, 0.7, 1, 0.18)
    property int circleSize: 52
    property int pillWidth: showMeter ? 312 : Math.max(238, Math.min(312, 100 + Math.max(headerText.length, subtitle.length) * 7))
    property int pillHeight: showMeter ? 82 : 66
    property int windowPadding: 28
    property real islandScale: 1

    anchors.bottom: true
    margins.bottom: 88
    margins.left: Math.max(0, Math.round((Screen.width - root.implicitWidth) / 2))
    implicitWidth: root.pillWidth + root.windowPadding
    implicitHeight: 118
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    visible: root.presenting || root.closing || root.vanishing
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "shells-osd"
    WlrLayershell.anchors.bottom: true
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.exclusiveZone: 0

    IpcHandler {
        target: "osd"

        function volumeUp() { root.changeVolume("+5%") }
        function volumeDown() { root.changeVolume("-5%") }
        function volumeMute() { root.toggleVolumeMute() }
        function micMute() { root.toggleMicMute() }
        function brightnessUp() { root.changeBrightness("5%+") }
        function brightnessDown() { root.changeBrightness("5%-") }
        function capsLock() { root.refreshCapsLock() }
        function caps() { root.refreshCapsLock() }
    }

    Process {
        id: actionProcess
        property string after: ""
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { id: actionErr; waitForEnd: true }
        onExited: function(code) {
            if (code !== 0) {
                root.showMessage("error", "OSD command failed", String(actionErr.text || "Command returned " + code), 0, false, root.iconPath("capslock.svg"))
                return
            }

            if (after === "volume")
                root.refreshVolume()
            else if (after === "mic")
                root.refreshMic()
            else if (after === "brightness")
                root.refreshBrightness()
            else if (after === "caps")
                root.refreshCapsLock()
        }
    }

    Process {
        id: volumeProbe
        stdout: StdioCollector { id: volumeOut; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            if (code !== 0)
                return
            root.pendingVolume = root.parsePercent(volumeOut.text)
            muteProbe.exec(muteProbe.command)
        }
    }

    Process {
        id: muteProbe
        command: [Services.Config.pactlBin, "get-sink-mute", "@DEFAULT_SINK@"]
        stdout: StdioCollector { id: muteOut; waitForEnd: true }
        onExited: function(code) {
            const muted = code === 0 && String(muteOut.text).toLowerCase().includes("yes")
            root.showVolume(root.pendingVolume, muted)
        }
    }

    Process {
        id: micProbe
        command: [Services.Config.pactlBin, "get-source-mute", "@DEFAULT_SOURCE@"]
        stdout: StdioCollector { id: micOut; waitForEnd: true }
        onExited: function(code) {
            const muted = code === 0 && String(micOut.text).toLowerCase().includes("yes")
            root.showMessage("mic", muted ? "Microphone muted" : "Microphone live", muted ? "Input is silenced" : "Input capture enabled", muted ? 0 : 100, false, root.iconPath(muted ? "audio_muted.svg" : "audio.svg"))
        }
    }

    Process {
        id: brightnessProbe
        stdout: StdioCollector { id: brightnessOut; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            if (code !== 0)
                return
            const pct = root.parsePercent(brightnessOut.text)
            root.showBrightness(pct)
        }
    }

    Process {
        id: capsProbe
        stdout: StdioCollector { id: capsOut; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            const on = code === 0 && String(capsOut.text).trim() === "1"
            root.showMessage("caps", on ? "Caps Lock on" : "Caps Lock off", on ? "Uppercase input enabled" : "Normal typing restored", on ? 100 : 0, false, root.iconPath("capslock.svg"))
        }
    }

    property real pendingVolume: 0

    function iconPath(name) {
        return Quickshell.env("HOME") + "/.config/shells/assets/icons/osd/" + name
    }

    function runThen(command, after) {
        actionProcess.after = after
        actionProcess.exec(command)
    }

    function changeVolume(delta) {
        root.runThen([Services.Config.pactlBin, "set-sink-volume", "@DEFAULT_SINK@", delta], "volume")
    }

    function toggleVolumeMute() {
        root.runThen([Services.Config.pactlBin, "set-sink-mute", "@DEFAULT_SINK@", "toggle"], "volume")
    }

    function toggleMicMute() {
        root.runThen([Services.Config.pactlBin, "set-source-mute", "@DEFAULT_SOURCE@", "toggle"], "mic")
    }

    function changeBrightness(delta) {
        root.runThen([Services.Config.brightnessctlBin, "-e4", "-n2", "set", delta], "brightness")
    }

    function refreshVolume() {
        volumeProbe.exec([Services.Config.pactlBin, "get-sink-volume", "@DEFAULT_SINK@"])
    }

    function refreshMic() {
        micProbe.exec(micProbe.command)
    }

    function refreshBrightness() {
        brightnessProbe.exec([Services.Config.brightnessctlBin, "-m"])
    }

    function refreshCapsLock() {
        capsDelayTimer.restart()
    }

    function parsePercent(text) {
        const match = /([0-9]+)%/.exec(String(text))
        if (!match)
            return 0
        return Math.max(0, Math.min(100, parseInt(match[1], 10)))
    }

    function setPalette(nextKind) {
        if (!theme)
            return

        if (nextKind === "brightness") {
            accent = theme.withAlpha(theme.color3, 1)
            accentSoft = theme.withAlpha(theme.color3, 0.18)
        } else if (nextKind === "muted" || nextKind === "error") {
            accent = theme.withAlpha(theme.color1, 1)
            accentSoft = theme.withAlpha(theme.color1, 0.20)
        } else if (nextKind === "caps") {
            accent = theme.withAlpha(theme.color6, 1)
            accentSoft = theme.withAlpha(theme.color6, 0.18)
        } else if (nextKind === "mic") {
            accent = theme.withAlpha(theme.color5, 1)
            accentSoft = theme.withAlpha(theme.color5, 0.18)
        } else {
            accent = theme.withAlpha(theme.color4, 1)
            accentSoft = theme.withAlpha(theme.color4, 0.18)
        }
    }

    function showVolume(percent, muted) {
        root.showMessage(muted ? "muted" : "volume", muted ? "Volume muted" : "Volume", muted ? "Output silenced" : Math.round(percent) + "% output level", percent, true, root.iconPath(muted ? "audio_muted.svg" : "audio.svg"))
    }

    function showBrightness(percent) {
        root.showMessage("brightness", "Brightness", Math.round(percent) + "% display backlight", percent, true, root.iconPath(percent <= 2 ? "backlight_off.svg" : "brightness.svg"))
    }

    function showMessage(nextKind, nextTitle, nextSubtitle, nextValue, meter, nextIcon) {
        root.kind = nextKind
        root.headerText = nextTitle
        root.subtitle = nextSubtitle
        root.value = nextValue
        root.showMeter = meter
        root.iconSource = nextIcon
        root.setPalette(nextKind)
        root.playAppearSound()
        root.openAnimated()
    }

    function playAppearSound() {
        Quickshell.execDetached([
            "sh",
            "-c",
            "if command -v pw-play >/dev/null 2>&1; then pw-play \"$1\"; elif command -v paplay >/dev/null 2>&1; then paplay \"$1\"; elif command -v mpv >/dev/null 2>&1; then mpv --no-terminal --really-quiet \"$1\"; fi",
            "osd-appear-sound",
            Services.Config.osdAppearSoundPath
        ])
    }

    function openAnimated() {
        closeTimer.stop()
        vanishTimer.stop()
        doneTimer.stop()
        if (root.expanded && !root.closing && !root.vanishing) {
            closeTimer.restart()
            iconPop.restart()
            return
        }
        root.presenting = true
        root.closing = false
        root.vanishing = false
        root.expanded = false
        root.islandScale = 0.82
        Qt.callLater(function() {
            root.expanded = true
            root.islandScale = 1
            closeTimer.restart()
            iconPop.restart()
        })
    }

    function closeAnimated() {
        if (root.closing)
            return
        root.closing = true
        root.expanded = false
        vanishTimer.restart()
    }

    Timer {
        id: closeTimer
        interval: 1500
        repeat: false
        onTriggered: root.closeAnimated()
    }

    Timer {
        id: capsDelayTimer
        interval: 150
        repeat: false
        onTriggered: capsProbe.exec(["sh", "-c", "for f in /sys/class/leds/*::capslock/brightness; do [ \"$(cat \"$f\")\" = 1 ] && echo 1 && exit 0; done; echo 0"])
    }

    Timer {
        id: vanishTimer
        interval: root.theme && root.theme.reducedMotion ? 0 : 300
        repeat: false
        onTriggered: {
            root.vanishing = true
            root.islandScale = 0.88
            doneTimer.restart()
        }
    }

    Timer {
        id: doneTimer
        interval: root.theme && root.theme.reducedMotion ? 0 : 190
        repeat: false
        onTriggered: {
            root.expanded = false
            root.presenting = false
            root.vanishing = false
            root.closing = false
            root.islandScale = 1
        }
    }

    Rectangle {
        id: island
        width: root.vanishing ? 12 : (root.expanded ? root.pillWidth : root.circleSize)
        height: root.vanishing ? 12 : (root.expanded ? root.pillHeight : root.circleSize)
        anchors.centerIn: parent
        radius: height / 2
        antialiasing: true
        opacity: root.presenting && !root.vanishing ? 1 : 0
        scale: root.islandScale
        clip: true
        color: root.theme ? root.theme.withAlpha(root.theme.color0, root.theme.panelOpacity) : Qt.rgba(0.05, 0.05, 0.06, 0.96)

        Behavior on width {
            SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 480; spring: 6.2; damping: 0.64; mass: 0.75; epsilon: 0.001 }
        }

        Behavior on height {
            SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 480; spring: 4.6; damping: 0.72; mass: 0.9; epsilon: 0.001 }
        }

        Behavior on opacity {
            NumberAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic }
        }

        Behavior on scale {
            SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 260; spring: 6.8; damping: 0.58; mass: 0.8; epsilon: 0.001 }
        }

        Item {
            id: iconPlate
            width: 44
            height: 44
            x: root.expanded ? 12 : (parent.width - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            scale: 1

            Behavior on x {
                SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 340; spring: 4.6; damping: 0.78; mass: 0.9; epsilon: 0.001 }
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: root.accentSoft
            }

            Image {
                id: iconImage
                anchors.centerIn: parent
                width: 24
                height: 24
                source: root.iconSource
                sourceSize.width: 24
                sourceSize.height: 24
                visible: false
            }

            MultiEffect {
                anchors.fill: iconImage
                source: iconImage
                colorization: 1
                colorizationColor: root.accent
            }

            SequentialAnimation {
                id: iconPop
                NumberAnimation { target: iconPlate; property: "scale"; from: 0.72; to: 1.13; duration: root.theme && root.theme.reducedMotion ? 0 : 130; easing.type: Easing.OutCubic }
                SpringAnimation { target: iconPlate; property: "scale"; to: 1.0; duration: root.theme && root.theme.reducedMotion ? 0 : 290; spring: 6.0; damping: 0.58; mass: 0.9; epsilon: 0.001 }
            }
        }

        Column {
            id: copy
            x: 64
            y: root.showMeter ? 16 : 13
            width: parent.width - 78
            spacing: 1
            opacity: root.expanded ? 1 : 0

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 60 }
                    NumberAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic }
                }
            }

            Text {
                width: parent.width
                text: root.headerText
                color: root.accent
                font.family: root.theme ? root.theme.fontFamily : "Adwaita Sans"
                font.pixelSize: root.theme ? 14 * root.theme.fontScale : 14
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.subtitle
                color: root.theme ? root.theme.withAlpha(root.theme.foreground, 0.78) : Qt.rgba(1, 1, 1, 0.78)
                font.family: root.theme ? root.theme.fontFamily : "Adwaita Sans"
                font.pixelSize: root.theme ? 11 * root.theme.fontScale : 11
                elide: Text.ElideRight
            }
        }

        Item {
            id: meter
            x: 64
            y: 56
            width: parent.width - 78
            height: 10
            opacity: root.expanded && root.showMeter ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic }
            }

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: root.theme ? root.theme.withAlpha(root.theme.color1, 0.46) : Qt.rgba(1, 1, 1, 0.12)
            }

            Rectangle {
                width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, root.value / 100)))
                height: parent.height
                radius: height / 2
                color: root.accent

                Behavior on width {
                    SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 300; spring: 4.8; damping: 0.76; mass: 0.9; epsilon: 0.001 }
                }
            }
        }
    }
}

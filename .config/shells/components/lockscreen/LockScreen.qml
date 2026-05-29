import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../services" as Services

Item {
    id: root

    property var theme
    property var networkState
    property var lockSession
    property date now: new Date()
    property string wallpaperPath: ""
    property real pointerX: width / 2
    property real pointerY: height / 2
    property real blurAmount: 0
    property real overlayOpacity: 0
    property real uiOpacity: 1
    property real uiScale: 1
    property int blurDuration: 600
    property int overlayDuration: 600
    property int uiOpacityDuration: 220
    property int uiScaleDuration: 150
    property int blurEasingType: Easing.OutCubic
    property int overlayEasingType: Easing.OutCubic
    property real clockOpacity: 0
    property real clockOffsetY: -60
    property real dateOpacity: 0
    property real dateOffsetY: -14
    property real avatarOpacity: 0
    property real avatarScale: 0.85
    property real mediaOpacity: 0
    property real mediaOffsetY: 30
    property real passwordOpacity: 0
    property real passwordOffsetY: 48
    property real actionsOpacity: 0
    property real borderReveal: 0
    property int displayDotCount: 0
    property int dotClearToken: 0
    property int dotSuccessToken: 0
    property bool dotClearing: false
    property bool unlocked: false
    property bool dimmed: false
    property bool wrong: false
    property bool verifying: false
    property bool success: false
    property bool mediaVisible: false
    property bool mediaLoading: false
    property string passwordText: passwordInput.text
    property string weatherText: "--"
    property string mediaTitle: ""
    property string mediaArtist: ""
    property string mediaArt: ""
    property string mediaStatus: "Stopped"
    property string audioOutput: ""
    property string avatarSource: ""
    property bool miniPowerOpen: false
    property real parallaxX: width > 0 ? ((pointerX / width) - 0.5) * 16 : 0
    property real parallaxY: height > 0 ? ((pointerY / height) - 0.5) * 16 : 0
    readonly property string username: Quickshell.env("USER")
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: sink ? sink.audio : null
    readonly property string networkLabel: networkState && networkState.connected ? networkState.name : "Offline"

    focus: true

    Component.onCompleted: {
        forceActiveFocus()
        startEntrance()
        refreshWeather()
        refreshMedia()
        refreshAudioOutput()
        avatarProbe.exec(avatarProbe.command)
        idleDimTimer.restart()
    }

    Keys.onPressed: function(event) {
        wake()
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            submitPassword()
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            passwordInput.text = ""
            miniPowerOpen = false
            event.accepted = true
        }
    }

    Behavior on blurAmount { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? Math.round(root.blurDuration / 2) : root.blurDuration; easing.type: root.blurEasingType } }
    Behavior on overlayOpacity { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? Math.round(root.overlayDuration / 2) : root.overlayDuration; easing.type: root.overlayEasingType } }
    Behavior on uiOpacity { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? Math.round(root.uiOpacityDuration / 2) : root.uiOpacityDuration; easing.type: Easing.OutCubic } }
    Behavior on uiScale { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? Math.round(root.uiScaleDuration / 2) : root.uiScaleDuration; easing.type: Easing.OutCubic } }
    Behavior on clockOffsetY { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 250; spring: 4.5; damping: 0.75; mass: 0.9; epsilon: 0.001 } }
    Behavior on dateOffsetY { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 250; spring: 4.5; damping: 0.75; mass: 0.9; epsilon: 0.001 } }
    Behavior on avatarScale { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 250; spring: 5.0; damping: 0.72; mass: 0.9; epsilon: 0.001 } }
    Behavior on mediaOffsetY { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 250; spring: 5.0; damping: 0.72; mass: 0.9; epsilon: 0.001 } }
    Behavior on passwordOffsetY { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 250; spring: 5.0; damping: 0.72; mass: 0.9; epsilon: 0.001 } }

    FileView {
        id: walFile
        path: Quickshell.env("HOME") + "/.cache/wal/wal"
        preload: true
        watchChanges: true
        blockLoading: true
        printErrors: false

        onLoaded: root.wallpaperPath = walFile.text().trim()
        onFileChanged: {
            reload()
            root.wallpaperPath = walFile.text().trim()
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: {
            root.refreshMedia()
            root.refreshAudioOutput()
        }
    }

    Timer {
        id: idleDimTimer
        interval: 30000
        repeat: false
        onTriggered: root.startIdleDim()
    }

    Timer {
        id: errorHideTimer
        interval: 2000
        repeat: false
        onTriggered: root.wrong = false
    }

    Timer {
        id: unlockTimer
        interval: root.theme && root.theme.reducedMotion ? Math.round(800 / 2) : 800
        repeat: false
        onTriggered: {
            if (root.lockSession)
                root.lockSession.unlock()
        }
    }

    Timer { id: clockRevealTimer; interval: root.theme && root.theme.reducedMotion ? Math.round(300 / 2) : 300; repeat: false; onTriggered: { root.clockOpacity = 1; root.clockOffsetY = 0 } }
    Timer { id: dateRevealTimer; interval: root.theme && root.theme.reducedMotion ? Math.round(400 / 2) : 400; repeat: false; onTriggered: { root.dateOpacity = 1; root.dateOffsetY = 0 } }
    Timer { id: avatarRevealTimer; interval: root.theme && root.theme.reducedMotion ? Math.round(500 / 2) : 500; repeat: false; onTriggered: { root.avatarOpacity = 1; root.avatarScale = 1 } }
    Timer { id: mediaRevealTimer; interval: root.theme && root.theme.reducedMotion ? Math.round(600 / 2) : 600; repeat: false; onTriggered: { root.mediaOpacity = 1; root.mediaOffsetY = 0 } }
    Timer { id: passwordRevealTimer; interval: root.theme && root.theme.reducedMotion ? Math.round(700 / 2) : 700; repeat: false; onTriggered: { root.passwordOpacity = 1; root.passwordOffsetY = 0; root.borderReveal = 1 } }
    Timer { id: actionsRevealTimer; interval: root.theme && root.theme.reducedMotion ? Math.round(800 / 2) : 800; repeat: false; onTriggered: root.actionsOpacity = 1 }
    Timer { id: unlockScaleTimer; interval: root.theme && root.theme.reducedMotion ? Math.round(100 / 2) : 100; repeat: false; onTriggered: { root.uiScaleDuration = 150; root.uiScale = 1.06 } }
    Timer { id: unlockUiFadeTimer; interval: root.theme && root.theme.reducedMotion ? Math.round(200 / 2) : 200; repeat: false; onTriggered: { root.uiOpacityDuration = 250; root.uiOpacity = 0 } }
    Timer { id: unlockBlurTimer; interval: root.theme && root.theme.reducedMotion ? Math.round(300 / 2) : 300; repeat: false; onTriggered: { root.blurDuration = 500; root.blurEasingType = Easing.OutExpo; root.blurAmount = 0 } }
    Timer { id: unlockOverlayTimer; interval: root.theme && root.theme.reducedMotion ? Math.round(350 / 2) : 350; repeat: false; onTriggered: { root.overlayDuration = 400; root.overlayEasingType = Easing.OutCubic; root.overlayOpacity = 0 } }
    Timer { id: wrongDotClearTimer; interval: 240; repeat: false; onTriggered: { passwordInput.text = ""; root.displayDotCount = 0; root.dotClearing = false; passwordInput.forceActiveFocus() } }

    Image {
        id: wallpaper
        anchors.fill: parent
        anchors.margins: -24
        x: -root.parallaxX
        y: -root.parallaxY
        source: root.wallpaperPath.length > 0 ? "file://" + root.wallpaperPath : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false

        Behavior on x { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? Math.round(220 / 2) : 220; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? Math.round(220 / 2) : 220; easing.type: Easing.OutCubic } }
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        blurEnabled: root.theme.enableBlur && root.blurAmount > 0
        blur: root.theme.enableBlur && root.blurAmount > 0 ? root.theme.blurStrength : 0
        blurMax: Math.max(1, root.blurAmount)
        blurMultiplier: root.theme.blurStrength
        saturation: 0.95
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, root.overlayOpacity)
    }

    Canvas {
        anchors.fill: parent
        opacity: 0.03
        onPaint: {
            const ctx = getContext("2d")
            const size = 3
            for (let y = 0; y < height; y += size) {
                for (let x = 0; x < width; x += size) {
                    const v = Math.random() * 255
                    ctx.fillStyle = "rgba(" + v + "," + v + "," + v + ",0.55)"
                    ctx.fillRect(x, y, size, size)
                }
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onPositionChanged: function(mouse) {
            root.pointerX = mouse.x
            root.pointerY = mouse.y
            root.wake()
        }
    }

    Item {
        id: ui
        anchors.fill: parent
        opacity: root.uiOpacity
        scale: root.uiScale

        Column {
            id: topZone
            anchors.top: parent.top
            anchors.topMargin: Math.max(54, parent.height * 0.08)
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            opacity: root.clockOpacity
            transform: Translate { y: root.clockOffsetY }

            Behavior on opacity { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? Math.round(240 / 2) : 240; easing.type: Easing.OutCubic } }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter

                FlipText { theme: root.theme; value: Qt.formatDateTime(root.now, "hh") }
                Text {
                    text: ":"
                    color: root.theme.foreground
                    font.pixelSize: 120
                    font.bold: true
                    SequentialAnimation on opacity {
                        running: true
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.2; duration: root.theme && root.theme.reducedMotion ? Math.round(500 / 2) : 500; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: root.theme && root.theme.reducedMotion ? Math.round(500 / 2) : 500; easing.type: Easing.InOutSine }
                    }
                }
                FlipText { theme: root.theme; value: Qt.formatDateTime(root.now, "mm") }
            }

            Row {
                id: dateRow
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                opacity: root.dateOpacity
                transform: Translate { y: root.dateOffsetY }

                Behavior on opacity { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? Math.round(240 / 2) : 240; easing.type: Easing.OutCubic } }

                Text {
                    text: Qt.formatDateTime(root.now, "dddd, dd MMMM")
                    color: root.theme.withAlpha(root.theme.foreground, 0.85)
                    font.pixelSize: 22
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: weatherRow.implicitWidth + 22
                    height: 32
                    radius: root.theme.pillRadius
                    color: root.theme.withAlpha(root.theme.color0, 0.62)
                    border.width: root.theme.outerBorder ? root.theme.borderWidth : 0
                    border.color: root.theme.withAlpha(root.theme.color1, root.theme.borderOpacity)

                    Row {
                        id: weatherRow
                        anchors.centerIn: parent
                        spacing: 7
                        Text { text: "󰖕"; color: root.theme.color4; font.pixelSize: 14 }
                        Text { text: root.weatherText; color: root.theme.foreground; font.pixelSize: 12; font.bold: true }
                    }
                }
            }
        }

        Column {
            id: userZone
            anchors.centerIn: parent
            spacing: 10
            opacity: root.avatarOpacity
            scale: root.avatarScale

            Behavior on opacity { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? Math.round(220 / 2) : 220; easing.type: Easing.OutCubic } }

            Rectangle {
                width: 94
                height: 94
                radius: 47
                color: root.theme.color4
                opacity: 0.18 + avatarPulse * 0.10
                anchors.horizontalCenter: parent.horizontalCenter
                property real avatarPulse: 0
                SequentialAnimation on avatarPulse {
                    running: true
                    loops: Animation.Infinite
                    NumberAnimation { to: 1; duration: root.theme && root.theme.reducedMotion ? Math.round(1300 / 2) : 1300; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0; duration: root.theme && root.theme.reducedMotion ? Math.round(1300 / 2) : 1300; easing.type: Easing.InOutSine }
                }
            }

            Rectangle {
                width: 80
                height: 80
                radius: 40
                clip: true
                anchors.horizontalCenter: parent.horizontalCenter
                border.width: 2
                border.color: root.theme.color4
                color: root.theme.withAlpha(root.theme.color0, 0.78)

                Image {
                    anchors.fill: parent
                    source: root.avatarSource.length > 0 ? "file://" + root.avatarSource : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: source.toString().length > 0 ? 1 : 0
                }

                Text {
                    anchors.centerIn: parent
                    opacity: root.avatarSource.length === 0 ? 1 : 0
                    text: root.username.length > 0 ? root.username[0].toUpperCase() : "?"
                    color: root.theme.color4
                    font.pixelSize: 32
                    font.bold: true
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.username
                color: root.theme.foreground
                font.pixelSize: 20
                font.bold: true
            }

            Rectangle {
                width: uptimeText.implicitWidth + 24
                height: 28
                radius: root.theme.pillRadius
                color: root.theme.withAlpha(root.theme.color0, 0.58)
                border.width: root.theme.outerBorder ? root.theme.borderWidth : 0
                border.color: root.theme.withAlpha(root.theme.color1, root.theme.borderOpacity)
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    id: uptimeText
                    anchors.centerIn: parent
                    text: "Locked session"
                    color: root.theme.color6
                    font.pixelSize: 12
                    font.bold: true
                }
            }
        }

        MediaPill {
            id: mediaPill
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 200
            theme: root.theme
            title: root.mediaTitle
            artist: root.mediaArtist
            artUrl: root.mediaArt
            status: root.mediaStatus
            visibleMedia: root.mediaVisible
            opacity: root.mediaOpacity
            transform: Translate { y: root.mediaOffsetY }
            Behavior on opacity { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? Math.round(220 / 2) : 220; easing.type: Easing.OutCubic } }
            onControl: function(command) { root.controlMedia(command) }
        }

        Column {
            id: passwordZone
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 54
            spacing: 12
            opacity: root.passwordOpacity
            transform: Translate { y: root.passwordOffsetY }

            Behavior on opacity { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? Math.round(220 / 2) : 220; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: errorText.implicitWidth + 28
                height: 34
                radius: 17
                opacity: root.wrong ? 1 : 0
                color: root.theme.withAlpha(root.theme.color1, 0.72)

                Behavior on opacity { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? Math.round(160 / 2) : 160; easing.type: Easing.OutCubic } }

                Text {
                    id: errorText
                    anchors.centerIn: parent
                    text: "Incorrect password"
                    color: root.theme.foreground
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            Rectangle {
                id: passwordPill
                width: 340
                height: 56
                radius: root.theme.pillRadius
                color: root.theme.withAlpha(root.theme.color0, 0.80)
                border.width: root.success || root.wrong || root.theme.outerBorder ? root.theme.borderWidth : 0
                border.color: root.success ? root.theme.color4 : (root.wrong ? root.theme.color1 : root.theme.withAlpha(root.theme.color1, 0.70 * root.borderReveal))
                x: 0
                scale: root.success ? 1.05 : 1

                Behavior on scale { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 250; spring: 6.0; damping: 0.62; mass: 0.9; epsilon: 0.001 } }
                Behavior on border.color { ColorAnimation { duration: root.theme && root.theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic } }

                SequentialAnimation on x {
                    id: shakeAnim
                    NumberAnimation { to: 8; duration: 55; easing.type: Easing.OutCubic }
                    NumberAnimation { to: -8; duration: 65; easing.type: Easing.InOutCubic }
                    NumberAnimation { to: 6; duration: 60; easing.type: Easing.InOutCubic }
                    NumberAnimation { to: -6; duration: 60; easing.type: Easing.InOutCubic }
                    NumberAnimation { to: 4; duration: 55; easing.type: Easing.InOutCubic }
                    NumberAnimation { to: -4; duration: 55; easing.type: Easing.InOutCubic }
                    NumberAnimation { to: 2; duration: 45; easing.type: Easing.InOutCubic }
                    NumberAnimation { to: -2; duration: 45; easing.type: Easing.InOutCubic }
                    NumberAnimation { to: 0; duration: 60; easing.type: Easing.OutCubic }
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 12

                    Text {
                        width: 22
                        height: parent.height
                        text: root.success ? "󰄵" : "󰌾"
                        color: root.success ? root.theme.color4 : root.theme.foreground
                        font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    Item {
                        width: parent.width - 34
                        height: parent.height

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: passwordInput.text.length === 0 && !passwordInput.activeFocus ? 1 : 0
                            text: "Enter password"
                            color: root.theme.color6
                            font.pixelSize: 14
                            Behavior on opacity { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? Math.round(120 / 2) : 120; easing.type: Easing.OutCubic } }
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Repeater {
                                model: root.displayDotCount

                                Rectangle {
                                    id: dot
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: root.success ? root.theme.foreground : root.theme.color4
                                    scale: dotScale
                                    property real dotScale: 0
                                    property int dotIndex: index
                                    property int clearToken: root.dotClearToken
                                    property int successToken: root.dotSuccessToken
                                    Component.onCompleted: dotIn.restart()
                                    onClearTokenChanged: clearDelay.restart()
                                    onSuccessTokenChanged: successAnim.restart()
                                    SpringAnimation on dotScale {
                                        id: dotIn
                                        to: 1
                                        spring: 7
                                        damping: 0.6
                                        mass: 0.9
                                        epsilon: 0.001
                                    }
                                    Timer {
                                        id: clearDelay
                                        interval: (dotIndex % 4) * 30
                                        repeat: false
                                        onTriggered: dotOut.restart()
                                    }
                                    SpringAnimation {
                                        id: dotOut
                                        target: dot
                                        property: "dotScale"
                                        to: 0
                                        spring: 7
                                        damping: 0.6
                                        mass: 0.9
                                        epsilon: 0.001
                                    }
                                    SequentialAnimation {
                                        id: successAnim
                                        NumberAnimation { target: dot; property: "dotScale"; to: 1.3; duration: root.theme && root.theme.reducedMotion ? Math.round(120 / 2) : 120; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: dot; property: "dotScale"; to: 0; duration: root.theme && root.theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.InCubic }
                                    }
                                }
                            }
                        }

                        TextInput {
                            id: passwordInput
                            anchors.fill: parent
                            color: "transparent"
                            selectedTextColor: "transparent"
                            selectionColor: "transparent"
                            cursorVisible: true
                            echoMode: TextInput.Password
                            focus: true
                            enabled: !root.verifying && !root.unlocked
                            onAccepted: root.submitPassword()
                            onTextChanged: if (!root.dotClearing && !root.success) root.displayDotCount = text.length
                            Keys.onPressed: function(event) { root.wake() }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onClicked: {
                        root.wake()
                        passwordInput.forceActiveFocus()
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                opacity: root.actionsOpacity
                Behavior on opacity { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? Math.round(220 / 2) : 220; easing.type: Easing.OutCubic } }

                ActionCircle {
                    theme: root.theme
                    icon: "󰐥"
                    label: "Power"
                    onClicked: root.miniPowerOpen = !root.miniPowerOpen
                }
                ActionCircle {
                    theme: root.theme
                    icon: "󰒲"
                    label: "Sleep"
                    onClicked: Quickshell.execDetached(["systemctl", "suspend"])
                }
                InfoChip {
                    theme: root.theme
                    icon: "󰖪"
                    text: root.networkLabel
                }
                InfoChip {
                    theme: root.theme
                    icon: "󰋋"
                    text: root.mediaVisible ? root.audioOutput : "Audio"
                }
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: passwordZone.top
            anchors.bottomMargin: 10
            width: powerMiniRow.implicitWidth + 22
            height: 48
            radius: root.theme.pillRadius
            opacity: root.miniPowerOpen ? 1 : 0
            color: root.theme.withAlpha(root.theme.color0, 0.82)
            border.width: root.theme.outerBorder ? root.theme.borderWidth : 0
            border.color: root.theme.withAlpha(root.theme.color1, root.theme.borderOpacity)

            Behavior on opacity { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? Math.round(150 / 2) : 150; easing.type: Easing.OutCubic } }

            Row {
                id: powerMiniRow
                anchors.centerIn: parent
                spacing: 8

                MiniPowerButton { theme: root.theme; icon: "󰜉"; label: "Restart"; command: ["systemctl", "reboot"] }
                MiniPowerButton { theme: root.theme; icon: "󰐥"; label: "Shutdown"; command: ["systemctl", "poweroff"] }
            }
        }
    }

    Process {
        id: weatherProcess
        command: [Services.Config.curlBin, "-fsS", "https://wttr.in/?format=%c+%t"]
        stdout: StdioCollector { id: weatherOut; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            if (code === 0)
                root.weatherText = weatherOut.text.trim()
        }
    }

    Process {
        id: mediaProbe
        command: [Services.Config.playerctlBin, "metadata", "--format", "{{title}}|{{artist}}|{{mpris:artUrl}}|{{status}}"]
        stdout: StdioCollector { id: mediaOut; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            if (code !== 0) {
                root.mediaVisible = false
                return
            }
            const parts = mediaOut.text.trim().split("|")
            if (parts.length < 4 || parts[0].length === 0) {
                root.mediaVisible = false
                return
            }
            root.mediaTitle = parts[0]
            root.mediaArtist = parts[1]
            root.mediaArt = parts[2]
            root.mediaStatus = parts[3]
            root.mediaVisible = true
        }
    }

    Process {
        id: mediaControl
        stderr: StdioCollector { waitForEnd: true }
        onExited: root.refreshMedia()
    }

    Process {
        id: audioProbe
        command: [Services.Config.pactlBin, "get-default-sink"]
        stdout: StdioCollector { id: audioOut; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            if (code === 0)
                root.audioOutput = root.shortDeviceName(audioOut.text.trim())
        }
    }

    Process {
        id: avatarProbe
        command: ["sh", "-c", "for f in \"$HOME/.face\" \"/usr/share/pixmaps/faces/$USER.png\" \"/usr/share/pixmaps/faces/$USER.jpg\" /usr/share/pixmaps/faces/default.png; do [ -f \"$f\" ] && { printf '%s' \"$f\"; exit 0; }; done"]
        stdout: StdioCollector { id: avatarOut; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            root.avatarSource = avatarOut.text.trim()
        }
    }

    Process {
        id: authProcess
        stdout: StdioCollector { id: authOut; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            root.verifying = false
            if (authOut.text.trim() === "0") {
                root.playUnlockAnimation()
            } else {
                root.playWrongPasswordAnimation()
            }
        }
    }

    function startEntrance() {
        unlocked = false
        success = false
        dimmed = false
        wrong = false
        uiOpacityDuration = 0
        uiOpacity = 1
        uiScale = 1
        blurDuration = 0
        overlayDuration = 0
        blurEasingType = Easing.OutCubic
        overlayEasingType = Easing.OutCubic
        blurAmount = 0
        overlayOpacity = 0
        clockOpacity = 0
        clockOffsetY = -60
        dateOpacity = 0
        dateOffsetY = -14
        avatarOpacity = 0
        avatarScale = 0.85
        mediaOpacity = 0
        mediaOffsetY = 30
        passwordOpacity = 0
        passwordOffsetY = 48
        actionsOpacity = 0
        borderReveal = 0
        Qt.callLater(function() {
            root.blurDuration = 600
            root.overlayDuration = 600
            root.blurAmount = 64
            root.overlayOpacity = 0.45
            root.uiOpacityDuration = 220
        })
        clockRevealTimer.restart()
        dateRevealTimer.restart()
        avatarRevealTimer.restart()
        mediaRevealTimer.restart()
        passwordRevealTimer.restart()
        actionsRevealTimer.restart()
    }

    function wake() {
        if (unlocked)
            return
        dimmed = false
        uiOpacityDuration = 400
        overlayDuration = 400
        overlayEasingType = Easing.OutCubic
        uiOpacity = 1
        overlayOpacity = 0.45
        idleDimTimer.restart()
        passwordInput.forceActiveFocus()
    }

    function startIdleDim() {
        if (unlocked)
            return
        dimmed = true
        uiOpacityDuration = 3000
        overlayDuration = 3000
        overlayEasingType = Easing.OutCubic
        uiOpacity = 0
        overlayOpacity = 0.75
    }

    function submitPassword() {
        if (verifying || passwordInput.text.length === 0)
            return
        verifying = true
        wrong = false
        authProcess.exec([Services.Config.checkPasswordScript, passwordInput.text])
    }

    function playWrongPasswordAnimation() {
        wrong = true
        success = false
        dotClearing = true
        displayDotCount = Math.max(displayDotCount, passwordInput.text.length)
        dotClearToken++
        shakeAnim.restart()
        errorHideTimer.restart()
        wrongDotClearTimer.restart()
    }

    function playUnlockAnimation() {
        success = true
        unlocked = true
        dotSuccessToken++
        unlockScaleTimer.restart()
        unlockUiFadeTimer.restart()
        unlockBlurTimer.restart()
        unlockOverlayTimer.restart()
        unlockTimer.restart()
    }

    function refreshWeather() {
        if (!weatherProcess.running)
            weatherProcess.exec(weatherProcess.command)
    }

    function refreshMedia() {
        if (!mediaProbe.running)
            mediaProbe.exec(mediaProbe.command)
    }

    function refreshAudioOutput() {
        if (!audioProbe.running)
            audioProbe.exec(audioProbe.command)
    }

    function controlMedia(command) {
        mediaControl.exec([Services.Config.playerctlBin, command])
    }

    function shortDeviceName(raw) {
        const name = String(raw || "")
        const parts = name.split(".")
        return parts.length > 0 ? parts[parts.length - 1].replace(/-/g, " ") : "Audio"
    }

    component FlipText: Text {
        id: flip
        property var theme
        property string value: ""
        text: value
        color: theme.foreground
        font.pixelSize: 120
        font.bold: true
        onValueChanged: flipAnim.restart()
        SequentialAnimation {
            id: flipAnim
            NumberAnimation { target: flip; property: "y"; to: -16; duration: theme && theme.reducedMotion ? Math.round(90 / 2) : 90; easing.type: Easing.OutCubic }
            NumberAnimation { target: flip; property: "opacity"; to: 0.35; duration: theme && theme.reducedMotion ? Math.round(50 / 2) : 50 }
            PropertyAction { target: flip; property: "y"; value: 16 }
            NumberAnimation { target: flip; property: "opacity"; to: 1; duration: theme && theme.reducedMotion ? Math.round(70 / 2) : 70 }
            NumberAnimation { target: flip; property: "y"; to: 0; duration: theme && theme.reducedMotion ? Math.round(120 / 2) : 120; easing.type: Easing.OutCubic }
        }
    }

    component MediaPill: Rectangle {
        id: pill
        property var theme
        property string title: ""
        property string artist: ""
        property string artUrl: ""
        property string status: "Stopped"
        property bool visibleMedia: false
        signal control(string command)
        width: 480
        height: visibleMedia ? 90 : 0
        radius: 45
        clip: true
        color: theme.withAlpha(theme.color0, 0.72)
        Behavior on height { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250; spring: 5.0; damping: 0.72; mass: 0.9; epsilon: 0.001 } }

        Image { id: mediaBg; anchors.fill: parent; source: pill.artUrl; fillMode: Image.PreserveAspectCrop; visible: false; asynchronous: true }
        MultiEffect { anchors.fill: parent; source: mediaBg; blurEnabled: theme.enableBlur; blur: theme.enableBlur ? theme.blurStrength : 0; blurMax: 64; blurMultiplier: theme.blurStrength * 1.4; opacity: pill.artUrl.length > 0 && theme.enableBlur ? 1 : 0 }
        Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.55) }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 65
                Layout.preferredHeight: 65
                radius: 32
                clip: true
                color: pill.theme.withAlpha(pill.theme.color4, 0.16)
                Image { anchors.fill: parent; source: pill.artUrl; fillMode: Image.PreserveAspectCrop; asynchronous: true }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text { Layout.fillWidth: true; text: pill.title; color: pill.theme.foreground; font.pixelSize: 15; font.bold: true; elide: Text.ElideRight }
                Text { Layout.fillWidth: true; text: pill.artist; color: pill.theme.color6; font.pixelSize: 12; elide: Text.ElideRight }
            }

            Row {
                spacing: 12
                MediaButton { theme: pill.theme; icon: "󰒮"; onClicked: pill.control("previous") }
                MediaButton { theme: pill.theme; icon: pill.status === "Playing" ? "󰏤" : "󰐊"; onClicked: pill.control("play-pause") }
                MediaButton { theme: pill.theme; icon: "󰒭"; onClicked: pill.control("next") }
            }
        }
    }

    component MediaButton: Text {
        id: btn
        property var theme
        property string icon: ""
        signal clicked()
        text: icon
        color: theme.foreground
        font.pixelSize: 22
        scale: area.pressed ? 0.9 : (area.containsMouse ? 1.12 : 1)
        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250; spring: 7; damping: 0.65; mass: 0.9; epsilon: 0.001 } }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: btn.clicked() }
    }

    component ActionCircle: Rectangle {
        id: action
        property var theme
        property string icon: ""
        property string label: ""
        signal clicked()
        width: 36
        height: 36
        radius: 18
        color: theme.withAlpha(theme.color0, area.containsMouse ? 0.82 : 0.60)
        scale: area.pressed ? 0.94 : (area.containsMouse ? 1.10 : 1)
        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250; spring: 7; damping: 0.65; mass: 0.9; epsilon: 0.001 } }
        Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(160 / 2) : 160; easing.type: Easing.OutCubic } }
        Text { anchors.centerIn: parent; text: action.icon; color: action.theme.foreground; font.pixelSize: 16 }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: action.clicked() }
    }

    component InfoChip: Rectangle {
        id: chip
        property var theme
        property string icon: ""
        property string text: ""
        width: Math.min(190, label.implicitWidth + 52)
        height: 36
        radius: 18
        color: theme.withAlpha(theme.color0, 0.60)
        Row {
            anchors.centerIn: parent
            spacing: 7
            Text { text: chip.icon; color: chip.theme.foreground; font.pixelSize: 15 }
            Text { id: label; text: chip.text; color: chip.theme.foreground; font.pixelSize: 12; elide: Text.ElideRight; width: Math.min(130, implicitWidth) }
        }
    }

    component MiniPowerButton: Rectangle {
        id: mini
        property var theme
        property string icon: ""
        property string label: ""
        property var command: []
        width: labelText.implicitWidth + 44
        height: 34
        radius: 17
        color: area.containsMouse ? theme.withAlpha(theme.color4, 0.18) : "transparent"
        Text { anchors.centerIn: parent; id: labelText; text: mini.icon + "  " + mini.label; color: mini.theme.foreground; font.pixelSize: 12; font.bold: true }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(mini.command) }
    }
}

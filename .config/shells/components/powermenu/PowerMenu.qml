import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property var theme
    property bool menuVisible: false
    property bool closing: false
    property bool backgroundShown: false
    property bool clockShown: false
    property bool idlePulse: false
    property int idleCountdown: 10
    property int focusIndex: 0
    property int confirmIndex: -1
    property int enterToken: 0
    property int exitToken: 0
    property date now: new Date()
    property string wallpaperPath: ""
    readonly property bool anyConfirming: confirmIndex >= 0
    readonly property var actions: [
        { icon: "󰐥", label: "Lock", shortcut: "L", command: ["quickshell", "ipc", "--path", Quickshell.env("HOME") + "/.config/shells", "call", "lockScreen", "lock"], confirm: false },
        { icon: "󰍃", label: "Logout", shortcut: "E", command: ["hyprctl", "dispatch", "exit"], confirm: true },
        { icon: "󰒲", label: "Sleep", shortcut: "S", command: ["systemctl", "suspend"], confirm: false },
        { icon: "󰜉", label: "Restart", shortcut: "R", command: ["systemctl", "reboot"], confirm: true },
        { icon: "󰐥", label: "Shutdown", shortcut: "P", command: ["systemctl", "poweroff"], confirm: true },
        { icon: "󰤄", label: "Hibernate", shortcut: "H", command: ["systemctl", "hibernate"], confirm: true }
    ]

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    visible: menuVisible || closing
    aboveWindows: true
    focusable: true
    exclusiveZone: -1
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "shells-power-menu"
    WlrLayershell.anchors.top: true
    WlrLayershell.anchors.left: true
    WlrLayershell.anchors.right: true
    WlrLayershell.anchors.bottom: true
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.exclusiveZone: -1

    IpcHandler {
        target: "powerMenu"

        function toggle() { root.toggle() }
        function open() { root.open() }
        function close() { root.closeAnimated() }
    }

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
        running: root.visible
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Timer {
        id: idleTimer
        interval: 30000
        repeat: false
        onTriggered: {
            root.idlePulse = true
            root.idleCountdown = 10
            idleCloseTimer.restart()
        }
    }

    Timer {
        id: idleCloseTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.idleCountdown--
            if (root.idleCountdown <= 0) {
                stop()
                root.closeAnimated()
            }
        }
    }

    Timer { id: clockTimer; interval: 400; repeat: false; onTriggered: root.clockShown = true }
    Timer { id: backgroundExitTimer; interval: 240; repeat: false; onTriggered: root.backgroundShown = false }
    Timer {
        id: hideTimer
        interval: 480
        repeat: false
        onTriggered: {
            root.closing = false
            root.menuVisible = false
            root.confirmIndex = -1
            root.idlePulse = false
            idleTimer.stop()
            idleCloseTimer.stop()
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: root.handleEscape()
    }

    Item {
        id: scene
        anchors.fill: parent
        opacity: root.backgroundShown ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: root.theme && root.theme.reducedMotion ? Math.round((root.closing ? 200 : 200) / 2) : (root.closing ? 200 : 200)
                easing.type: Easing.OutCubic
            }
        }

        Image {
            id: wallpaper
            anchors.fill: parent
            source: root.wallpaperPath.length > 0 ? "file://" + root.wallpaperPath : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: wallpaper
            blurEnabled: root.theme.enableBlur
            blur: root.theme.enableBlur ? root.theme.blurStrength : 0
            blurMax: 64
            blurMultiplier: root.theme.blurStrength
            saturation: 0.9
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.55)
        }

        Canvas {
            anchors.fill: parent
            opacity: 0.76
            onPaint: {
                const ctx = getContext("2d")
                const cx = width * 0.5
                const cy = height * 0.48
                const radius = Math.max(width, height) * 0.72
                const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, radius)
                g.addColorStop(0, "rgba(0,0,0,0)")
                g.addColorStop(0.62, "rgba(0,0,0,0.10)")
                g.addColorStop(1, "rgba(0,0,0,0.70)")
                ctx.fillStyle = g
                ctx.fillRect(0, 0, width, height)
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.visible
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: root.noteInteraction()
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) { root.handleKey(event) }
    }

    Column {
        id: stack
        anchors.centerIn: parent
        spacing: 28

        Column {
            id: clockBlock
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            opacity: root.clockShown ? 1 : 0
            y: root.clockShown ? 0 : -8

            Behavior on opacity { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? Math.round(200 / 2) : 200; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? Math.round(200 / 2) : 200; easing.type: Easing.OutCubic } }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                Text {
                    text: Qt.formatDateTime(root.now, "hh")
                    color: root.theme.foreground
                    font.pixelSize: 72
                    font.bold: true
                }
                Text {
                    text: ":"
                    color: root.theme.foreground
                    font.pixelSize: 72
                    font.bold: true
                    SequentialAnimation on opacity {
                        running: root.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: root.theme && root.theme.reducedMotion ? Math.round(500 / 2) : 500; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: root.theme && root.theme.reducedMotion ? Math.round(500 / 2) : 500; easing.type: Easing.InOutSine }
                    }
                }
                Text {
                    text: Qt.formatDateTime(root.now, "mm")
                    color: root.theme.foreground
                    font.pixelSize: 72
                    font.bold: true
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(root.now, "dddd, MMMM d yyyy")
                color: root.theme.color6
                font.pixelSize: 16
            }
        }

        Rectangle {
            id: buttonGrid
            anchors.horizontalCenter: parent.horizontalCenter
            width: 360
            height: 510
            radius: 32
            color: root.theme.withAlpha(root.theme.color0, 0.94)
            border.width: root.theme.outerBorder ? root.theme.borderWidth : 0
            border.color: root.theme.withAlpha(root.theme.color1, 0.2)
            scale: root.menuVisible && !root.closing ? 1 : 0.92
            opacity: root.menuVisible && !root.closing ? 1 : 0

            Behavior on scale { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 520; spring: 4.4; damping: 0.72; mass: 0.9; epsilon: 0.001 } }
            Behavior on opacity { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? Math.round(220 / 2) : 220; easing.type: Easing.OutCubic } }

            Column {
                anchors.centerIn: parent
                spacing: 14

                Repeater {
                    model: [0, 2, 4]

                    Row {
                        spacing: root.anyConfirming ? 0 : 18

                        Repeater {
                            model: [modelData, modelData + 1]

                            PowerActionButton {
                                property var action: root.actions[modelData]

                                theme: root.theme
                                actionIndex: modelData
                                iconText: action.icon
                                labelText: action.label
                                shortcutText: action.shortcut
                                focused: root.focusIndex === modelData
                                confirming: root.confirmIndex === modelData
                                dimmed: root.anyConfirming && root.confirmIndex !== modelData
                                idlePulse: root.idlePulse
                                enterToken: root.enterToken
                                exitToken: root.exitToken
                                onHoverEntered: {
                                    root.focusIndex = modelData
                                    root.noteInteraction()
                                }
                                onActivated: {
                                    root.noteInteraction()
                                    root.activateIndex(modelData)
                                }
                                onCanceled: {
                                    root.noteInteraction()
                                    root.cancelConfirm()
                                }
                                onConfirmed: {
                                    root.noteInteraction()
                                    root.confirmAction(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 38
        width: countdownText.implicitWidth + 28
        height: 34
        radius: root.theme.pillRadius
        visible: opacity > 0
        opacity: root.idlePulse ? 1 : 0
        color: root.theme.withAlpha(root.theme.color0, 0.82)
        border.width: root.theme.outerBorder ? root.theme.borderWidth : 0
        border.color: root.theme.withAlpha(root.theme.color1, root.theme.borderOpacity)

        Behavior on opacity { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic } }

        Text {
            id: countdownText
            anchors.centerIn: parent
            text: "Closing in " + root.idleCountdown + "s"
            color: root.theme.color6
            font.pixelSize: 12
            font.bold: true
        }
    }

    function toggle() {
        if (menuVisible && !closing)
            closeAnimated()
        else
            open()
    }

    function open() {
        closing = false
        menuVisible = true
        backgroundShown = true
        clockShown = false
        confirmIndex = -1
        focusIndex = 0
        idlePulse = false
        idleCloseTimer.stop()
        hideTimer.stop()
        backgroundExitTimer.stop()
        enterToken++
        keyCatcher.forceActiveFocus()
        clockTimer.restart()
        idleTimer.restart()
    }

    function closeAnimated() {
        if (!menuVisible || closing)
            return
        closing = true
        clockShown = false
        confirmIndex = -1
        idlePulse = false
        idleTimer.stop()
        idleCloseTimer.stop()
        exitToken++
        clockTimer.stop()
        backgroundExitTimer.restart()
        hideTimer.restart()
    }

    function noteInteraction() {
        if (!menuVisible || closing)
            return
        idlePulse = false
        idleCloseTimer.stop()
        idleCountdown = 10
        keyCatcher.forceActiveFocus()
        idleTimer.restart()
    }

    function handleEscape() {
        noteInteraction()
        if (confirmIndex >= 0)
            cancelConfirm()
        else
            closeAnimated()
    }

    function handleKey(event) {
        if (!visible || closing)
            return

        noteInteraction()
        if (event.key === Qt.Key_Escape) {
            handleEscape()
            event.accepted = true
            return
        }

        if (confirmIndex >= 0) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                confirmAction(confirmIndex)
                event.accepted = true
            }
            return
        }

        if (event.key === Qt.Key_Left) {
            focusIndex = Math.max(0, focusIndex - 1)
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            focusIndex = Math.min(actions.length - 1, focusIndex + 1)
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            focusIndex = Math.max(0, focusIndex - 2)
            event.accepted = true
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
            focusIndex = Math.min(actions.length - 1, focusIndex + 2)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            activateIndex(focusIndex)
            event.accepted = true
        } else {
            const key = String(event.text || "").toUpperCase()
            for (let i = 0; i < actions.length; i++) {
                if (key === actions[i].shortcut) {
                    activateIndex(i)
                    event.accepted = true
                    return
                }
            }
        }
    }

    function activateIndex(index) {
        if (index < 0 || index >= actions.length)
            return
        focusIndex = index
        const action = actions[index]
        if (action.confirm) {
            confirmIndex = index
        } else {
            runAction(index)
        }
    }

    function cancelConfirm() {
        confirmIndex = -1
    }

    function confirmAction(index) {
        runAction(index)
    }

    function runAction(index) {
        if (index < 0 || index >= actions.length)
            return
        Quickshell.execDetached(actions[index].command)
        closeAnimated()
    }

    component PowerActionButton: Item {
        id: button

        property var theme
        property int actionIndex: 0
        property string iconText: ""
        property string labelText: ""
        property string shortcutText: ""
        property bool focused: false
        property bool confirming: false
        property bool dimmed: false
        property bool idlePulse: false
        property int enterToken: 0
        property int exitToken: 0
        property bool entered: false
        property real idleOpacity: 1
        property bool hovered: area.containsMouse
        property bool pressed: area.pressed
        property real labelOffset: hovered ? -2 : 0
        readonly property color accent: actionIndex === 4 ? theme.color1
            : actionIndex === 3 ? theme.color4
            : actionIndex === 2 ? theme.color6
            : actionIndex === 1 ? theme.color5
            : actionIndex === 5 ? theme.color13
            : theme.color7

        signal activated()
        signal canceled()
        signal confirmed()
        signal hoverEntered()

        width: confirming ? 312 : (dimmed ? 0 : 126)
        height: confirming ? 206 : (dimmed ? 0 : 144)
        z: confirming ? 40 : (dimmed ? -1 : (hovered || focused ? 30 : 0))
        clip: dimmed
        scale: entered ? (pressed ? 0.94 : (dimmed ? 0.94 : (hovered || focused ? 1.05 : 1))) : 0.68
        opacity: entered ? idleOpacity * (dimmed ? 0 : 1) : 0
        y: entered ? 0 : 28

        onEnterTokenChanged: {
            entered = false
            enterTimer.restart()
        }

        onExitTokenChanged: exitTimer.restart()
        onIdlePulseChanged: {
            idleOpacity = 1
            if (idlePulse)
                idleAnim.restart()
            else
                idleAnim.stop()
        }

        Behavior on width {
            enabled: !button.dimmed
            SpringAnimation { duration: button.theme && button.theme.reducedMotion ? 0 : 250; spring: 4.5; damping: 0.75; mass: 0.9; epsilon: 0.001 }
        }
        Behavior on height {
            enabled: !button.dimmed
            SpringAnimation { duration: button.theme && button.theme.reducedMotion ? 0 : 250; spring: 4.5; damping: 0.75; mass: 0.9; epsilon: 0.001 }
        }
        Behavior on opacity { NumberAnimation { duration: button.theme && button.theme.reducedMotion ? Math.round(200 / 2) : 200; easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { duration: button.theme && button.theme.reducedMotion ? 0 : 250; spring: pressed ? 8 : (hovered ? 7 : 5); damping: pressed ? 0.5 : (hovered ? 0.65 : 0.75); mass: 0.9; epsilon: 0.001 } }
        Behavior on y { SpringAnimation { duration: button.theme && button.theme.reducedMotion ? 0 : 250; spring: 5.0; damping: 0.72; mass: 0.9; epsilon: 0.001 } }
        Behavior on labelOffset { SpringAnimation { duration: button.theme && button.theme.reducedMotion ? 0 : 250; spring: 7; damping: 0.65; mass: 0.9; epsilon: 0.001 } }

        Timer {
            id: enterTimer
            interval: button.actionIndex * 50
            repeat: false
            onTriggered: button.entered = true
        }

        Timer {
            id: exitTimer
            interval: (5 - button.actionIndex) * 30
            repeat: false
            onTriggered: button.entered = false
        }

        SequentialAnimation {
            id: idleAnim
            loops: Animation.Infinite
            NumberAnimation { target: button; property: "idleOpacity"; to: 0.7; duration: button.theme && button.theme.reducedMotion ? Math.round(1000 / 2) : 1000; easing.type: Easing.InOutSine }
            NumberAnimation { target: button; property: "idleOpacity"; to: 1.0; duration: button.theme && button.theme.reducedMotion ? Math.round(1000 / 2) : 1000; easing.type: Easing.InOutSine }
        }

        Rectangle {
            id: card
            anchors.fill: parent
            radius: button.confirming ? 28 : (button.dimmed ? 0 : 20)
            color: button.confirming ? button.theme.withAlpha(button.theme.color0, 0.98) : "transparent"
            border.width: button.confirming && button.focused ? 1 : 0
            border.color: button.theme.withAlpha(button.accent, 0.38)

            Behavior on color { ColorAnimation { duration: button.theme && button.theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic } }
            Behavior on border.color { ColorAnimation { duration: button.theme && button.theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic } }
            Behavior on radius { NumberAnimation { duration: button.theme && button.theme.reducedMotion ? Math.round(220 / 2) : 220; easing.type: Easing.OutCubic } }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: !button.dimmed
                onEntered: button.hoverEntered()
                onClicked: button.activated()
            }

            Item {
                anchors.fill: parent
                z: 2

                Rectangle {
                    id: glow
                    anchors.horizontalCenter: circle.horizontalCenter
                    anchors.verticalCenter: circle.verticalCenter
                    width: circle.width + 18
                    height: width
                    radius: width / 2
                    color: button.theme.withAlpha(button.accent, button.hovered || button.focused ? 0.18 : 0.08)
                    scale: button.hovered || button.focused ? 1.08 : 0.94
                    opacity: button.confirming ? 0 : 1

                    Behavior on scale { SpringAnimation { duration: button.theme && button.theme.reducedMotion ? 0 : 360; spring: 4.8; damping: 0.78; mass: 0.9; epsilon: 0.001 } }
                    Behavior on color { ColorAnimation { duration: button.theme && button.theme.reducedMotion ? Math.round(220 / 2) : 220; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: button.theme && button.theme.reducedMotion ? Math.round(140 / 2) : 140; easing.type: Easing.OutCubic } }
                }

                Rectangle {
                    id: circle
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: button.confirming ? 24 : 8
                    width: button.confirming ? 72 : 92
                    height: width
                    radius: width / 2
                    color: button.hovered || button.focused || button.confirming
                        ? button.theme.withAlpha(button.accent, actionIndex === 4 ? 0.95 : 0.62)
                        : button.theme.withAlpha(button.theme.foreground, 0.12)
                    scale: button.pressed ? 0.9 : 1

                    Behavior on width { SpringAnimation { duration: button.theme && button.theme.reducedMotion ? 0 : 420; spring: 4.8; damping: 0.76; mass: 0.9; epsilon: 0.001 } }
                    Behavior on color { ColorAnimation { duration: button.theme && button.theme.reducedMotion ? Math.round(220 / 2) : 220; easing.type: Easing.OutCubic } }
                    Behavior on scale { SpringAnimation { duration: button.theme && button.theme.reducedMotion ? 0 : 260; spring: 7; damping: 0.64; mass: 0.85; epsilon: 0.001 } }
                }

                Text {
                    id: actionIcon
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.centerIn: circle
                    text: button.iconText
                    color: button.hovered || button.focused || button.confirming ? button.theme.color0 : button.theme.foreground
                    opacity: 1
                    font.pixelSize: button.confirming ? 30 : 38
                    horizontalAlignment: Text.AlignHCenter
                    scale: button.hovered || button.focused ? 1.08 : 1

                    Behavior on color { ColorAnimation { duration: button.theme && button.theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic } }
                    Behavior on font.pixelSize { NumberAnimation { duration: button.theme && button.theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic } }
                    Behavior on scale { SpringAnimation { duration: button.theme && button.theme.reducedMotion ? 0 : 260; spring: 6.2; damping: 0.64; mass: 0.85; epsilon: 0.001 } }
                }

                Text {
                    id: actionLabel
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: circle.bottom
                    anchors.topMargin: button.confirming ? 14 : 13
                    text: button.labelText
                    color: button.theme.foreground
                    font.pixelSize: button.confirming ? 17 : 15
                    font.bold: false
                    transform: Translate { y: button.labelOffset }
                    opacity: button.dimmed ? 0.55 : 1

                    Behavior on font.pixelSize { NumberAnimation { duration: button.theme && button.theme.reducedMotion ? Math.round(160 / 2) : 160; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: button.theme && button.theme.reducedMotion ? Math.round(120 / 2) : 120; easing.type: Easing.OutCubic } }
                }

                Text {
                    id: shortcutLabel
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: actionLabel.bottom
                    anchors.topMargin: 4
                    text: button.shortcutText
                    color: button.accent
                    font.pixelSize: 11
                    opacity: button.confirming ? 0 : 1

                    Behavior on opacity { NumberAnimation { duration: button.theme && button.theme.reducedMotion ? Math.round(120 / 2) : 120; easing.type: Easing.OutCubic } }
                }

                Column {
                    id: confirmBox
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: actionLabel.bottom
                    anchors.topMargin: 18
                    spacing: 10
                    opacity: button.confirming ? 1 : 0
                    y: button.confirming ? 0 : 8
                    visible: opacity > 0

                    Behavior on opacity { NumberAnimation { duration: button.theme && button.theme.reducedMotion ? Math.round(150 / 2) : 150; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: button.theme && button.theme.reducedMotion ? Math.round(150 / 2) : 150; easing.type: Easing.OutCubic } }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10

                        ConfirmPill {
                            theme: button.theme
                            label: "Cancel"
                            filled: false
                            onClicked: button.canceled()
                        }

                        ConfirmPill {
                            theme: button.theme
                            label: "Confirm"
                            filled: true
                            onClicked: button.confirmed()
                        }
                    }
                }
            }
        }
    }

    component ConfirmPill: Rectangle {
        id: pill

        property var theme
        property string label: ""
        property bool filled: false
        property bool hovered: area.containsMouse

        signal clicked()

        width: 92
        height: 32
        radius: theme.pillRadius
        color: filled ? theme.color4 : "transparent"
        border.width: filled || !theme.outerBorder ? 0 : theme.borderWidth
        border.color: theme.withAlpha(theme.color1, theme.borderOpacity)
        scale: area.pressed ? 0.94 : (hovered ? 1.04 : 1)

        Behavior on scale { SpringAnimation { duration: pill.theme && pill.theme.reducedMotion ? 0 : 250; spring: 7; damping: 0.65; mass: 0.9; epsilon: 0.001 } }

        Text {
            anchors.centerIn: parent
            text: pill.label
            color: pill.filled ? pill.theme.color0 : pill.theme.foreground
            font.pixelSize: 12
            font.bold: true
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }
}

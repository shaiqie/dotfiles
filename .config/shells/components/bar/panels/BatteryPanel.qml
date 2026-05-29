import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../widgets"
import "../../services" as Services

ColumnLayout {
    id: root

    property var theme
    property int motionToken: 0
    property var battery: UPower.displayDevice
    property int pct: battery && battery.isPresent ? Math.round((battery.percentage <= 1 ? battery.percentage * 100 : battery.percentage)) : 0
    property bool charging: battery && battery.state === UPowerDeviceState.Charging
    property int secondsLeft: battery ? Number((charging ? battery.timeToFull : battery.timeToEmpty) || 0) : 0
    property real arcSweep: 0
    property real displayPct: 0
    property real arcPulseOpacity: 1
    property real graphReveal: 1
    property real graphFillOpacity: 1
    property bool statsReady: false
    property bool graphReady: false
    property bool modesReady: false
    property string successText: ""
    property bool graphHover: false
    property real graphHoverX: 0
    property color arcColor: levelColor(pct)
    property string powerMode: "balanced"
    property real currentDraw: 0
    property string cycleCount: "N/A"
    property string batteryPath: "/sys/class/power_supply/BAT0"
    property string historyPath: Quickshell.env("HOME") + "/.cache/quickshell/battery-history.json"
    property string settingsPath: Quickshell.env("HOME") + "/.cache/quickshell/battery-settings.json"
    property string batteryStatus: ""
    property string remainingText: "Calculating..."
    property int selectedModeIndex: powerMode === "power-saver" ? 0 : (powerMode === "performance" ? 2 : 1)
    readonly property string batteryIconDir: Quickshell.env("HOME") + "/.config/shells/assets/icons/panel/battery/"

    width: parent ? parent.width : 360
    spacing: theme ? theme.itemSpacing + 2 : 14
    focus: true

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
            selectedModeIndex = Math.min(2, selectedModeIndex + 1)
            setPowerMode(modeForIndex(selectedModeIndex))
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            selectedModeIndex = Math.max(0, selectedModeIndex - 1)
            setPowerMode(modeForIndex(selectedModeIndex))
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            setPowerMode(modeForIndex(selectedModeIndex))
            event.accepted = true
        }
    }

    onPctChanged: {
        arcColor = levelColor(pct)
        batteryArc.requestPaint()
        historyGraph.requestPaint()
    }

    onChargingChanged: batteryArc.requestPaint()
    onArcSweepChanged: batteryArc.requestPaint()
    onArcPulseOpacityChanged: batteryArc.requestPaint()
    onGraphRevealChanged: historyGraph.requestPaint()
    onGraphFillOpacityChanged: historyGraph.requestPaint()
    onMotionTokenChanged: restartArc()

    Component.onCompleted: {
        ensureCache.exec(["mkdir", "-p", Quickshell.env("HOME") + "/.cache/quickshell"])
        refresh()
        restartArc()
        sampleHistory()
    }

    Behavior on arcColor { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(600 / 2) : 600; easing.type: Easing.OutCubic } }

    NumberAnimation on arcSweep {
        id: arcAnim
        duration: theme && theme.reducedMotion ? Math.round(900 / 2) : 900
        easing.type: Easing.OutExpo
        onStopped: batteryArc.requestPaint()
    }

    NumberAnimation on displayPct {
        id: pctAnim
        duration: theme && theme.reducedMotion ? Math.round(800 / 2) : 800
        easing.type: Easing.OutCubic
    }

    NumberAnimation on graphReveal {
        id: graphRevealAnim
        duration: theme && theme.reducedMotion ? Math.round(700 / 2) : 700
        easing.type: Easing.OutCubic
        onStopped: {
            graphFillDelay.restart()
            historyGraph.requestPaint()
        }
    }

    NumberAnimation on graphFillOpacity {
        id: graphFillAnim
        from: 0
        to: 1
        duration: theme && theme.reducedMotion ? Math.round(220 / 2) : 220
        easing.type: Easing.OutCubic
        onStopped: historyGraph.requestPaint()
    }

    SequentialAnimation on arcPulseOpacity {
        running: root.charging
        loops: Animation.Infinite
        NumberAnimation { to: 0.7; duration: theme && theme.reducedMotion ? Math.round(750 / 2) : 750; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: theme && theme.reducedMotion ? Math.round(750 / 2) : 750; easing.type: Easing.InOutSine }
    }

    Timer { id: statsDelay; interval: 80; repeat: false; onTriggered: root.statsReady = true }
    Timer { id: graphDelay; interval: 150; repeat: false; onTriggered: { root.graphReady = true; root.restartGraph() } }
    Timer { id: modesDelay; interval: 350; repeat: false; onTriggered: root.modesReady = true }
    Timer { id: graphFillDelay; interval: 200; repeat: false; onTriggered: graphFillAnim.restart() }
    Timer { id: successTimer; interval: 2000; repeat: false; onTriggered: root.successText = "" }

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: refresh()
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: sysProbe.exec(sysProbe.command)
    }

    Timer {
        interval: 300000
        repeat: true
        running: true
        onTriggered: sampleHistory()
    }

    FileView {
        id: historyFile
        path: root.historyPath
        preload: true
        blockLoading: true
        printErrors: false
        onLoaded: root.loadHistory(historyFile.text())
        onLoadFailed: root.sampleHistory()
    }

    FileView {
        id: settingsFile
        path: root.settingsPath
        preload: true
        blockLoading: true
        printErrors: false
        onLoaded: root.loadSettings(settingsFile.text())
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 154
        width: parent.width
        height: 154
        radius: theme.panelRadius
        color: theme.withAlpha(theme.foreground, 0.045)
        border.width: 0

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: "transparent"
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.theme.withAlpha(root.arcColor, 0.12) }
                GradientStop { position: 0.52; color: root.theme.withAlpha(root.theme.color4, 0.045) }
                GradientStop { position: 1.0; color: root.theme.withAlpha(root.theme.background, 0) }
            }
        }

        Canvas {
            id: batteryArc
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 126
            height: 126
            onPaint: {
                const ctx = getContext("2d")
                const pctSweep = Math.max(0, Math.min(100, root.arcSweep))
                ctx.reset()
                ctx.lineWidth = 10
                ctx.lineCap = "round"
                ctx.strokeStyle = root.theme.withAlpha(root.theme.foreground, 0.14)
                ctx.beginPath()
                ctx.arc(63, 63, 46, Math.PI * 0.75, Math.PI * 2.25)
                ctx.stroke()

                ctx.lineWidth = 14
                ctx.strokeStyle = root.theme.withAlpha(root.arcColor, 0.18 * root.arcPulseOpacity)
                ctx.beginPath()
                ctx.arc(63, 63, 48, Math.PI * 0.75, Math.PI * 0.75 + Math.PI * 1.5 * pctSweep / 100)
                ctx.stroke()

                ctx.lineWidth = 10
                ctx.strokeStyle = root.arcColor
                ctx.globalAlpha = root.arcPulseOpacity
                ctx.beginPath()
                ctx.arc(63, 63, 46, Math.PI * 0.75, Math.PI * 0.75 + Math.PI * 1.5 * pctSweep / 100)
                ctx.stroke()
                ctx.globalAlpha = 1
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.right: batteryArc.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Row {
                width: parent.width
                height: 48
                spacing: 10

                BatterySvgIcon {
                    theme: root.theme
                    sourcePath: root.batteryIconSource(root.pct)
                    iconColor: root.arcColor
                    iconSize: 34
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: Math.round(root.displayPct) + "%"
                    color: theme.foreground
                    font.pixelSize: 42
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Text {
                width: parent.width
                text: root.charging ? "Charging" : root.remainingText
                color: theme.withAlpha(theme.foreground, 0.62)
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Rectangle {
                width: statusText.implicitWidth + 18
                height: 26
                radius: theme.controlRadius
                color: theme.withAlpha(root.arcColor, 0.13)
                border.width: 0

                Text {
                    id: statusText
                    anchors.centerIn: parent
                    text: root.charging ? " Live power" : root.powerMode
                    color: root.arcColor
                    font.pixelSize: 11
                    font.bold: true
                }
            }

            Text {
                visible: false
                scale: chargePulse.running ? 1.0 : 1.0

                SequentialAnimation on scale {
                    id: chargePulse
                    running: root.charging
                    loops: Animation.Infinite
                    SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  to: 1.15; spring: 4.4; damping: 0.72; mass: 0.9; epsilon: 0.001 }
                    SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  to: 1.0; spring: 4.4; damping: 0.78; mass: 0.9; epsilon: 0.001 }
                    PauseAnimation { duration: theme && theme.reducedMotion ? Math.round(360 / 2) : 360 }
                }
            }
        }
    }

    Row {
        Layout.fillWidth: true
        Layout.preferredHeight: 58
        width: parent.width
        height: 58
        spacing: 8

        BatteryStatChip {
            theme: root.theme
            width: (parent.width - 16) / 3
            icon: "󰥔"
            value: root.remainingText
            label: "Remaining"
            motionToken: root.motionToken
            stagger: 0
            active: root.statsReady
        }

        BatteryStatChip {
            theme: root.theme
            width: (parent.width - 16) / 3
            icon: "󰚥"
            value: root.formatCurrent(root.currentDraw)
            label: "Draw"
            motionToken: root.motionToken
            stagger: 60
            active: root.statsReady
        }

        BatteryStatChip {
            theme: root.theme
            width: (parent.width - 16) / 3
            icon: "󰔟"
            value: root.cycleCount
            label: "Cycles"
            motionToken: root.motionToken
            stagger: 120
            active: root.statsReady
        }
    }

    Rectangle {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: successLabel.implicitWidth + 24
        Layout.preferredHeight: root.successText.length > 0 ? 30 : 0
        width: successLabel.implicitWidth + 24
        height: root.successText.length > 0 ? 30 : 0
        radius: 15
        color: theme.withAlpha(theme.color4, 0.18)
        border.width: 0
        opacity: root.successText.length > 0 ? 1 : 0
        clip: true
        Behavior on height { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.2; damping: 0.76; mass: 0.9; epsilon: 0.001 } }
        Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic } }
        Text { id: successLabel; anchors.centerIn: parent; text: root.successText; color: theme.color4; font.pixelSize: 12; font.bold: true }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 130
        width: parent.width
        height: 130
        radius: 18
        color: theme.withAlpha(theme.foreground, 0.045)
        border.width: 0
        opacity: root.graphReady ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic } }

        Canvas {
            id: historyGraph
            anchors.fill: parent
            anchors.margins: 12
            onPaint: root.paintHistory(getContext("2d"), width, height)
        }

        Canvas {
            id: graphDot
            anchors.fill: historyGraph
            anchors.margins: 12
            onPaint: root.paintGraphDot(getContext("2d"), width, height)
        }

        MouseArea {
            id: graphMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onPositionChanged: function(mouse) {
                root.graphHoverX = mouse.x
                historyGraph.requestPaint()
            }
            onEntered: { root.graphHover = true; historyGraph.requestPaint() }
            onExited: { root.graphHover = false; historyGraph.requestPaint() }
        }

        Rectangle {
            visible: graphMouse.containsMouse
            width: graphTip.implicitWidth + 16
            height: 28
            radius: theme.pillRadius
            color: theme.withAlpha(theme.background, 0.90)
            border.width: 0
            x: Math.max(6, Math.min(parent.width - width - 6, root.graphHoverX - width / 2))
            y: 8
            Text { id: graphTip; anchors.centerIn: parent; text: root.graphTooltip(root.graphHoverX, parent.parent.width); color: theme.color4; font.pixelSize: 11; font.bold: true }
        }
    }

    Rectangle {
        id: modeContainer
        z: 10
        Layout.fillWidth: true
        Layout.preferredHeight: 132
        width: parent.width
        height: 132
        radius: 20
        color: theme.withAlpha(theme.foreground, 0.045)
        border.width: 0
        clip: true
        opacity: root.modesReady ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic } }

        readonly property int selectedIndex: root.powerMode === "power-saver" ? 0 : (root.powerMode === "performance" ? 2 : 1)

        Rectangle {
            width: parent.width * 0.68
            height: 92
            radius: 46
            x: parent.width * (parent.selectedIndex === 0 ? -0.42 : (parent.selectedIndex === 1 ? 0.16 : 0.74))
            y: -26
            color: theme.withAlpha(parent.selectedIndex === 2 ? theme.color1 : (parent.selectedIndex === 0 ? theme.color6 : theme.color4), 0.105)
            Behavior on x { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.8; mass: 0.9; epsilon: 0.001 } }
            Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(220 / 2) : 220; easing.type: Easing.OutCubic } }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Row {
                width: parent.width
                height: 24
                spacing: 8

                Text {
                    width: parent.width - modeLive.implicitWidth - 8
                    text: "POWER PROFILE"
                    color: theme.withAlpha(theme.foreground, 0.48)
                    font.pixelSize: 9
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                }

                Text {
                    id: modeLive
                    text: root.modeLabel(root.powerMode).toUpperCase()
                    color: theme.color4
                    font.pixelSize: 9
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                width: parent.width
                height: parent.height - 34
                spacing: 8

                Repeater {
                    model: [
                        { label: "Saver", detail: "QUIET DRAW", iconSource: root.batteryIconDir + "power_saver.svg", mode: "power-saver" },
                        { label: "Balanced", detail: "DAILY FLOW", iconSource: root.batteryIconDir + "power_balanced.svg", mode: "balanced" },
                        { label: "Performance", detail: "FULL POWER", iconSource: root.batteryIconDir + "power_performance.svg", mode: "performance" }
                    ]
                    Item {
                        id: segment
                        property bool hovered: segmentMouse.containsMouse
                        property bool selected: root.powerMode === modelData.mode
                        property real iconRotation: 0
                        property real sweepX: -0.28
                        property color accent: modelData.mode === "performance" ? theme.color1 : (modelData.mode === "power-saver" ? theme.color6 : theme.color4)
                        width: (parent.width - 16) / 3
                        height: parent.height
                        scale: segmentMouse.pressed ? 0.96 : (segment.hovered ? 1.025 : 1.0)
                        clip: true

                        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 270; spring: 5.0; damping: 0.78; mass: 0.85; epsilon: 0.001 } }

                        Rectangle {
                            anchors.fill: parent
                            radius: 16
                            color: segment.selected ? "transparent" : root.theme.withAlpha(root.theme.foreground, segment.hovered ? 0.065 : 0.036)
                            clip: true

                            Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic } }

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                visible: segment.selected
                                opacity: segment.selected ? 1 : 0
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: root.theme.withAlpha(segment.accent, segment.hovered ? 0.28 : 0.22) }
                                    GradientStop { position: 0.58; color: root.theme.withAlpha(root.theme.color4, segment.hovered ? 0.16 : 0.11) }
                                    GradientStop { position: 1.0; color: root.theme.withAlpha(root.theme.foreground, 0.050) }
                                }
                                Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(160 / 2) : 160; easing.type: Easing.OutCubic } }
                            }

                            Canvas {
                                id: shineCanvas
                                anchors.fill: parent
                                opacity: segment.selected ? 1 : (segment.hovered ? 0.7 : 0)
                                onPaint: {
                                    const ctx = getContext("2d")
                                    const r = 16
                                    ctx.reset()
                                    ctx.save()
                                    ctx.beginPath()
                                    ctx.moveTo(r, 0)
                                    ctx.lineTo(width - r, 0)
                                    ctx.quadraticCurveTo(width, 0, width, r)
                                    ctx.lineTo(width, height - r)
                                    ctx.quadraticCurveTo(width, height, width - r, height)
                                    ctx.lineTo(r, height)
                                    ctx.quadraticCurveTo(0, height, 0, height - r)
                                    ctx.lineTo(0, r)
                                    ctx.quadraticCurveTo(0, 0, r, 0)
                                    ctx.closePath()
                                    ctx.clip()

                                    const bandWidth = width * 0.72
                                    ctx.translate(width * segment.sweepX, height / 2)
                                    ctx.rotate(18 * Math.PI / 180)
                                    const grad = ctx.createLinearGradient(-bandWidth / 2, 0, bandWidth / 2, 0)
                                    grad.addColorStop(0, "transparent")
                                    grad.addColorStop(0.5, root.theme.withAlpha(root.theme.foreground, 0.085))
                                    grad.addColorStop(1, "transparent")
                                    ctx.fillStyle = grad
                                    ctx.fillRect(-bandWidth / 2, -height, bandWidth, height * 2)
                                    ctx.restore()
                                }
                                Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(140 / 2) : 140; easing.type: Easing.OutCubic } }
                            }

                        }

                        NumberAnimation on sweepX {
                            running: segment.hovered || segment.selected
                            loops: Animation.Infinite
                            from: -0.28
                            to: 1.10
                            duration: theme && theme.reducedMotion ? Math.round(1500 / 2) : 1500
                            easing.type: Easing.InOutSine
                        }
                        onSweepXChanged: shineCanvas.requestPaint()

                        Column {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 3

                            BatterySvgIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                sourcePath: modelData.iconSource
                                iconColor: segment.selected ? segment.accent : theme.withAlpha(theme.foreground, 0.62)
                                iconSize: segment.selected ? 22 : 19
                                theme: root.theme
                                rotation: segment.iconRotation + (segment.selected && modelData.mode === "power-saver" ? leafSway : 0)
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width
                                text: modelData.label
                                color: segment.selected ? theme.foreground : theme.withAlpha(theme.foreground, 0.70)
                                font.pixelSize: 12
                                font.bold: segment.selected
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width
                                text: modelData.detail
                                color: segment.selected ? root.theme.withAlpha(segment.accent, 0.86) : theme.withAlpha(theme.foreground, 0.42)
                                font.pixelSize: 8
                                font.bold: true
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        SequentialAnimation {
                            id: wiggle
                            NumberAnimation { target: segment; property: "iconRotation"; to: 13; duration: theme && theme.reducedMotion ? Math.round(80 / 2) : 80; easing.type: Easing.OutCubic }
                            SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250; target: segment; property: "iconRotation"; to: 0; spring: 5.0; damping: 0.55; mass: 0.9; epsilon: 0.001 }
                        }

                        SequentialAnimation on leafSway {
                            running: segment.selected && modelData.mode === "power-saver"
                            loops: Animation.Infinite
                            NumberAnimation { to: 4; duration: theme && theme.reducedMotion ? Math.round(900 / 2) : 900; easing.type: Easing.InOutSine }
                            NumberAnimation { to: -4; duration: theme && theme.reducedMotion ? Math.round(900 / 2) : 900; easing.type: Easing.InOutSine }
                        }
                        property real leafSway: 0

                        MouseArea {
                            id: segmentMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.setPowerMode(modelData.mode)
                                wiggle.restart()
                            }
                        }
                    }
                }
            }
        }
    }

    ListModel { id: historyModel }

    Process {
        id: ensureCache
    }

    Process {
        id: profileGet
        command: [Services.Config.powerProfilesCtlBin, "get"]
        stdout: StdioCollector { id: profileOut; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            if (code === 0) {
                root.powerMode = profileOut.text.trim()
                root.persistSettings()
            }
        }
    }

    Process {
        id: profileSet
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(code) { profileGet.exec(profileGet.command) }
    }

    Process {
        id: sysProbe
        command: ["sh", "-c", "BAT=/sys/class/power_supply/BAT0; for f in status current_now power_now voltage_now energy_now energy_full charge_now charge_full cycle_count; do v=$(cat \"$BAT/$f\" 2>/dev/null); printf '%s=%s\\n' \"$f\" \"$v\"; done"]
        stdout: StdioCollector { id: sysOut; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: root.parseSys(sysOut.text)
    }

    function refresh() {
        profileGet.exec(profileGet.command)
        sysProbe.exec(sysProbe.command)
    }

    function restartArc() {
        arcAnim.stop()
        pctAnim.stop()
        arcSweep = 0
        displayPct = 0
        arcAnim.to = pct
        pctAnim.to = pct
        arcAnim.restart()
        pctAnim.restart()
        statsReady = false
        graphReady = false
        modesReady = false
        statsDelay.restart()
        graphDelay.restart()
        modesDelay.restart()
    }

    function restartGraph() {
        graphRevealAnim.stop()
        graphFillAnim.stop()
        graphReveal = 0
        graphFillOpacity = 0
        graphRevealAnim.to = 1
        graphRevealAnim.restart()
        historyGraph.requestPaint()
    }

    function setPowerMode(mode) {
        selectedModeIndex = mode === "power-saver" ? 0 : (mode === "performance" ? 2 : 1)
        powerMode = mode
        persistSettings()
        successText = modeLabel(mode) + " mode enabled"
        successTimer.restart()
        profileSet.exec([Services.Config.powerProfilesCtlBin, "set", mode])
    }

    function modeForIndex(index) {
        if (index <= 0)
            return "power-saver"
        if (index >= 2)
            return "performance"
        return "balanced"
    }

    function parseSys(text) {
        const data = ({})
        const lines = text.split("\n")
        for (let i = 0; i < lines.length; i++) {
            const eq = lines[i].indexOf("=")
            if (eq > 0)
                data[lines[i].slice(0, eq)] = lines[i].slice(eq + 1).trim()
        }

        batteryStatus = data.status || ""

        const currentUa = Number(data.current_now || NaN)
        const powerUw = Number(data.power_now || NaN)
        const voltageUv = Number(data.voltage_now || NaN)
        const energyNow = Number(data.energy_now || data.charge_now || NaN)
        const energyFull = Number(data.energy_full || data.charge_full || NaN)

        let amps = 0
        if (isFinite(currentUa) && currentUa > 0)
            amps = currentUa / 1000000
        else if (isFinite(powerUw) && powerUw > 0 && isFinite(voltageUv) && voltageUv > 0)
            amps = powerUw / voltageUv

        currentDraw = (batteryStatus === "Charging" ? 1 : -1) * Math.abs(amps)
        cycleCount = data.cycle_count && data.cycle_count.length > 0 ? data.cycle_count : "N/A"

        remainingText = computeRemainingText(energyNow, energyFull, powerUw)
    }

    function computeRemainingText(nowValue, fullValue, powerUw) {
        if (batteryStatus === "Full" || pct >= 100)
            return "Full"
        if (secondsLeft > 0)
            return secondsToHours(secondsLeft)
        if (!isFinite(powerUw) || powerUw <= 0 || !isFinite(nowValue) || nowValue <= 0)
            return "Calculating..."
        const target = batteryStatus === "Charging" && isFinite(fullValue) ? Math.max(0, fullValue - nowValue) : nowValue
        if (target <= 0)
            return batteryStatus === "Charging" ? "Full" : "Calculating..."
        return secondsToHours(target / powerUw * 3600)
    }

    function loadSettings(text) {
        try {
            const data = JSON.parse(text)
            if (data.powerMode)
                powerMode = data.powerMode
        } catch (e) {
        }
    }

    function persistSettings() {
        settingsFile.setText(JSON.stringify({ powerMode: powerMode }))
    }

    function sampleHistory() {
        const now = Date.now()
        const cutoff = now - 2 * 60 * 60 * 1000
        const entries = []
        for (let i = 0; i < historyModel.count; i++) {
            const item = historyModel.get(i)
            if (item.t >= cutoff)
                entries.push({ t: item.t, p: item.p })
        }
        entries.push({ t: now, p: pct })
        historyModel.clear()
        for (let j = 0; j < entries.length; j++)
            historyModel.append(entries[j])
        persistHistory()
        restartGraph()
        historyGraph.requestPaint()
    }

    function loadHistory(text) {
        try {
            const arr = JSON.parse(text)
            const cutoff = Date.now() - 2 * 60 * 60 * 1000
            historyModel.clear()
            for (let i = 0; i < arr.length; i++) {
                if (arr[i].t >= cutoff)
                    historyModel.append({ t: Number(arr[i].t), p: Number(arr[i].p) })
            }
        } catch (e) {
            historyModel.clear()
        }
        sampleHistory()
    }

    function persistHistory() {
        const arr = []
        for (let i = 0; i < historyModel.count; i++)
            arr.push(historyModel.get(i))
        historyFile.setText(JSON.stringify(arr))
    }

    function paintHistory(ctx, w, h) {
        ctx.reset()
        ctx.clearRect(0, 0, w, h)
        const pad = 8
        const left = pad
        const right = w - pad
        const top = pad
        const bottom = h - 18
        const now = Date.now()
        const start = now - 2 * 60 * 60 * 1000

        ctx.strokeStyle = theme.withAlpha(theme.foreground, 0.10)
        ctx.lineWidth = 1
        ctx.setLineDash([4, 5])
        const curY = bottom - (pct / 100) * (bottom - top)
        ctx.beginPath()
        ctx.moveTo(left, curY)
        ctx.lineTo(right, curY)
        ctx.stroke()
        ctx.setLineDash([])

        const points = []
        if (historyModel.count < 2) {
            const y = bottom - Math.max(0, Math.min(100, pct)) / 100 * (bottom - top)
            points.push({ x: left, y: y })
            points.push({ x: right, y: y })
        } else {
            for (let i = 0; i < historyModel.count; i++) {
                const item = historyModel.get(i)
                points.push({
                    x: left + Math.max(0, Math.min(1, (item.t - start) / (now - start))) * (right - left),
                    y: bottom - Math.max(0, Math.min(100, item.p)) / 100 * (bottom - top)
                })
            }
        }

        ctx.save()
        ctx.beginPath()
        ctx.rect(0, 0, w * Math.max(0, Math.min(1, graphReveal)), h)
        ctx.clip()

        ctx.beginPath()
        ctx.moveTo(points[0].x, points[0].y)
        for (let j = 0; j < points.length - 1; j++) {
            const p0 = points[j]
            const p1 = points[j + 1]
            const midX = (p0.x + p1.x) / 2
            ctx.bezierCurveTo(midX, p0.y, midX, p1.y, p1.x, p1.y)
        }

        const pathEnd = points[points.length - 1]
        const gradient = ctx.createLinearGradient(0, top, 0, bottom)
        gradient.addColorStop(0, theme.withAlpha(levelColor(pct), 0.30 * graphFillOpacity))
        gradient.addColorStop(1, theme.withAlpha(levelColor(pct), 0.00))
        ctx.lineTo(pathEnd.x, bottom)
        ctx.lineTo(points[0].x, bottom)
        ctx.closePath()
        ctx.fillStyle = gradient
        ctx.fill()

        ctx.beginPath()
        ctx.moveTo(points[0].x, points[0].y)
        for (let k = 0; k < points.length - 1; k++) {
            const a = points[k]
            const b = points[k + 1]
            const mid = (a.x + b.x) / 2
            ctx.bezierCurveTo(mid, a.y, mid, b.y, b.x, b.y)
        }
        ctx.strokeStyle = levelColor(pct)
        ctx.lineWidth = 3
        ctx.lineCap = "round"
        ctx.stroke()
        ctx.restore()

        if (graphHover) {
            const hx = Math.max(left, Math.min(right, graphHoverX - 12))
            ctx.strokeStyle = theme.withAlpha(theme.color4, 0.45)
            ctx.lineWidth = 1
            ctx.beginPath()
            ctx.moveTo(hx, top)
            ctx.lineTo(hx, bottom)
            ctx.stroke()
        }
    }

    function paintGraphDot(ctx, w, h) {
        ctx.reset()
        ctx.clearRect(0, 0, w, h)
        if (historyModel.count < 1 || graphReveal < 1)
            return

        const pad = 8
        const left = pad
        const right = w - pad
        const top = pad
        const bottom = h - 18
        const y = bottom - pct / 100 * (bottom - top)
        const pulse = 1 + 0.4 * (0.5 + 0.5 * Math.sin(Date.now() / 280))
        ctx.fillStyle = theme.withAlpha(theme.color4, 0.28)
        ctx.beginPath()
        ctx.arc(right, y, 8 * pulse, 0, Math.PI * 2)
        ctx.fill()
        ctx.fillStyle = theme.color4
        ctx.beginPath()
        ctx.arc(right, y, 4, 0, Math.PI * 2)
        ctx.fill()
        dotTimer.restart()
    }

    Timer { id: dotTimer; interval: 120; repeat: false; onTriggered: graphDot.requestPaint() }

    function graphTooltip(x, widthValue) {
        const pctAtX = Math.max(0, Math.min(100, Math.round(pct)))
        return pctAtX + "% now"
    }

    function modeLabel(mode) {
        if (mode === "power-saver")
            return "Saver"
        if (mode === "performance")
            return "Performance"
        return "Balanced"
    }

    function levelColor(value) {
        return value < 20 ? theme.color1 : (value < 50 ? theme.color3 : theme.color2)
    }

    function batteryIconSource(value) {
        const safePct = Math.max(0, Math.min(100, Math.round(Number(value) || 0)))
        if (safePct <= 15 && !root.charging)
            return batteryIconDir + "battery_state_alert.svg"
        if (safePct >= 100 || (root.battery && root.battery.state === UPowerDeviceState.FullyCharged))
            return batteryIconDir + "battery_full.svg"
        return batteryIconDir + "battery_state_" + batteryState(safePct) + ".svg"
    }

    function batteryState(value) {
        if (value >= 90)
            return 6
        if (value >= 75)
            return 5
        if (value >= 60)
            return 4
        if (value >= 45)
            return 3
        if (value >= 30)
            return 2
        return 1
    }

    function secondsToHours(seconds) {
        const h = Math.floor(seconds / 3600)
        const m = Math.round((seconds % 3600) / 60)
        return h > 0 ? h + "h " + m + "m" : m + "m"
    }

    function formatCurrent(value) {
        if (!isFinite(value) || Math.abs(value) < 0.01)
            return "0.0A"
        return (value > 0 ? "+" : "") + value.toFixed(1) + "A"
    }

    component BatterySvgIcon: Item {
        id: batteryIcon

        property var theme
        property string sourcePath: ""
        property color iconColor: "white"
        property int iconSize: 24

        width: iconSize
        height: iconSize

        Behavior on width { NumberAnimation { duration: batteryIcon.theme && batteryIcon.theme.reducedMotion ? 0 : 140; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: batteryIcon.theme && batteryIcon.theme.reducedMotion ? 0 : 140; easing.type: Easing.OutCubic } }

        Image {
            id: svgSource
            anchors.fill: parent
            source: batteryIcon.sourcePath
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
            colorizationColor: batteryIcon.iconColor

            Behavior on colorizationColor { ColorAnimation { duration: batteryIcon.theme && batteryIcon.theme.reducedMotion ? 0 : 170; easing.type: Easing.OutCubic } }
        }
    }
}

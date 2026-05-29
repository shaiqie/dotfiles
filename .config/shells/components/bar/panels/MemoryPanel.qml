import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: root

    property var theme
    property int motionToken: 0
    property real totalGiB: 0
    property real usedGiB: 0
    property real cachedGiB: 0
    property real freeGiB: 0
    property real displayUsedGiB: 0
    property real displayCachedGiB: 0
    property real displayFreeGiB: 0
    property int percentage: 0
    property real currentAngle: 0
    property real arcUsedGiB: 0
    property real displayPercent: 0
    property string expandedProcess: ""
    property string exitingProcess: ""
    property string failedProcess: ""
    property string toastText: ""
    property int pendingPid: 0
    property int pendingSignal: 15
    property string pendingName: ""
    property real processBarReveal: 0
    property bool processLoading: false
    readonly property color usageColor: levelColor(percentage)
    readonly property string ramIconDir: Quickshell.env("HOME") + "/.config/shells/assets/icons/panel/ram/"

    width: parent ? parent.width : 360
    height: Math.min(implicitHeight, 520)
    spacing: theme ? theme.itemSpacing + 2 : 14

    onPercentageChanged: sparkline.requestPaint()
    onCurrentAngleChanged: memoryArc.requestPaint()

    onMotionTokenChanged: {
        restartArc()
        restartProcessBars()
    }

    Component.onCompleted: {
        seedHistory()
        refreshMemory()
        refreshProcesses()
        restartArc()
        restartProcessBars()
    }

    ParallelAnimation {
        id: arcAnim
        NumberAnimation { target: root; property: "currentAngle"; from: 0; to: root.percentage; duration: theme && theme.reducedMotion ? Math.round(900 / 2) : 900; easing.type: Easing.OutExpo }
        NumberAnimation { target: root; property: "displayPercent"; from: 0; to: root.percentage; duration: theme && theme.reducedMotion ? Math.round(900 / 2) : 900; easing.type: Easing.OutExpo }
        NumberAnimation { target: root; property: "arcUsedGiB"; from: 0; to: root.usedGiB; duration: theme && theme.reducedMotion ? Math.round(900 / 2) : 900; easing.type: Easing.OutExpo }
        onStopped: memoryArc.requestPaint()
    }

    Behavior on displayUsedGiB { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(400 / 2) : 400; easing.type: Easing.OutCubic } }
    Behavior on displayCachedGiB { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(400 / 2) : 400; easing.type: Easing.OutCubic } }
    Behavior on displayFreeGiB { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(400 / 2) : 400; easing.type: Easing.OutCubic } }
    Behavior on processBarReveal { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(560 / 2) : 560; easing.type: Easing.OutCubic } }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: refreshMemory()
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: refreshProcesses()
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        blockLoading: true
        printErrors: false
    }

    Process {
        id: processProbe
        command: ["ps", "aux", "--sort=-%mem"]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.parseProcesses(text)
                root.processLoading = false
            }
        }
        onExited: function(exitCode) { if (exitCode !== 0) root.processLoading = false }
    }

    Process {
        id: killProbe
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { id: killErr; waitForEnd: true }
        onExited: function(exitCode) {
            if (exitCode === 0) {
                root.failedProcess = ""
                root.exitingProcess = root.pendingName
                root.expandedProcess = ""
                root.toastText = root.pendingName + (root.pendingSignal === 9 ? " killed" : " terminated")
                toastTimer.restart()
                refreshMemory()
                exitClearTimer.restart()
            } else {
                root.failedProcess = root.pendingName
                failClearTimer.restart()
            }
        }
    }

    Timer {
        id: toastTimer
        interval: 2000
        repeat: false
        onTriggered: root.toastText = ""
    }

    Timer {
        id: exitClearTimer
        interval: 260
        repeat: false
        onTriggered: {
            root.exitingProcess = ""
            processProbe.exec(processProbe.command)
        }
    }

    Timer {
        id: failClearTimer
        interval: 900
        repeat: false
        onTriggered: root.failedProcess = ""
    }

    ListModel { id: processModel }
    ListModel { id: historyModel }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 154
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
                GradientStop { position: 0.0; color: root.theme.withAlpha(root.usageColor, 0.12) }
                GradientStop { position: 0.55; color: root.theme.withAlpha(root.theme.color4, 0.045) }
                GradientStop { position: 1.0; color: root.theme.withAlpha(root.theme.background, 0) }
            }
        }

        Canvas {
            id: memoryArc
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 126
            height: 126
            onPaint: {
                const ctx = getContext("2d")
                const sweep = Math.max(0, Math.min(100, root.currentAngle))
                ctx.reset()
                ctx.lineWidth = 10
                ctx.lineCap = "round"
                ctx.strokeStyle = root.theme.withAlpha(root.theme.foreground, 0.14)
                ctx.beginPath()
                ctx.arc(63, 63, 46, Math.PI * 0.75, Math.PI * 2.25)
                ctx.stroke()

                const grad = ctx.createLinearGradient(18, 22, width - 18, height - 22)
                grad.addColorStop(0, root.usageColor)
                grad.addColorStop(1, root.theme.color4)
                ctx.strokeStyle = grad
                ctx.beginPath()
                ctx.arc(63, 63, 46, Math.PI * 0.75, Math.PI * 0.75 + Math.PI * 1.5 * sweep / 100)
                ctx.stroke()
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.right: memoryArc.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Row {
                width: parent.width
                height: 46
                spacing: 10

                RamSvgIcon {
                    theme: root.theme
                    sourcePath: root.ramIconDir + "ram.svg"
                    iconColor: root.usageColor
                    iconSize: 32
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: root.arcUsedGiB.toFixed(1) + "G"
                    color: theme.foreground
                    font.pixelSize: 40
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Text {
                width: parent.width
                text: "of " + root.totalGiB.toFixed(1) + "G"
                color: theme.withAlpha(theme.foreground, 0.66)
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Rectangle {
                width: chipLabel.implicitWidth + 22
                height: 26
                radius: theme.controlRadius
                color: theme.withAlpha(root.usageColor, 0.18)
                border.width: 0

                Text {
                    id: chipLabel
                    anchors.centerIn: parent
                    text: Math.round(root.displayPercent) + "% used"
                    color: root.usageColor
                    font.pixelSize: 12
                    font.bold: true
                }
            }
        }
    }

    Row {
        Layout.fillWidth: true
        Layout.preferredHeight: 54
        height: 54
        spacing: 8

        StatChip {
            theme: root.theme
            width: (parent.width - 16) / 3
            label: "Used"
            value: root.displayUsedGiB.toFixed(1) + "G"
            tint: root.theme.color6
        }

        StatChip {
            theme: root.theme
            width: (parent.width - 16) / 3
            label: "Cached"
            value: root.displayCachedGiB.toFixed(1) + "G"
            tint: root.theme.color4
        }

        StatChip {
            theme: root.theme
            width: (parent.width - 16) / 3
            label: "Free"
            value: root.displayFreeGiB.toFixed(1) + "G"
            tint: root.theme.foreground
        }
    }

    Rectangle {
        Layout.preferredWidth: toastLabel.implicitWidth + 24
        Layout.preferredHeight: root.toastText.length > 0 ? 30 : 0
        width: toastLabel.implicitWidth + 24
        height: root.toastText.length > 0 ? 30 : 0
        radius: 15
        color: theme.withAlpha(theme.color4, 0.18)
        border.width: 0
        opacity: root.toastText.length > 0 ? 1 : 0
        clip: true
        Layout.alignment: Qt.AlignHCenter

        Behavior on height { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.0; damping: 0.8; mass: 0.9; epsilon: 0.001 } }
        Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(160 / 2) : 160; easing.type: Easing.OutCubic } }

        Text {
            id: toastLabel
            anchors.centerIn: parent
            text: root.toastText
            color: theme.color4
            font.pixelSize: 12
            font.bold: true
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 72
        height: 72
        radius: 18
        color: theme.withAlpha(theme.foreground, 0.045)
        border.width: 0

        Canvas {
            id: sparkline
            anchors.fill: parent
            anchors.margins: 10
            onPaint: root.paintSparkline(getContext("2d"), width, height)
        }
    }

    Flickable {
        id: processList
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.minimumHeight: 286
        Layout.preferredHeight: 286
        Layout.maximumHeight: 286
        height: 286
        width: parent.width
        contentWidth: width
        contentHeight: processColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            opacity: processList.moving || listHover.containsMouse ? 0.6 : 0.2
            width: processList.moving || listHover.containsMouse ? 4 : 2
            Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(200 / 2) : 200; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(200 / 2) : 200; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            id: listHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        Column {
            id: processColumn
            width: parent.width
            spacing: 6
            clip: false

            Repeater {
                model: root.processLoading && processModel.count === 0 ? 5 : 0
                Rectangle {
                    width: processColumn.width
                    height: 42
                    radius: root.theme.itemRadius
                    color: root.theme.withAlpha(root.theme.foreground, 0.075)
                    opacity: 0.55
                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * (0.40 + index * 0.07)
                        height: 10
                        radius: 5
                        color: root.theme.withAlpha(root.theme.foreground, 0.12)
                    }
                }
            }

            Repeater {
                model: processModel

                Rectangle {
                    id: row
                    property bool expanded: root.expandedProcess === name
                    property bool exiting: root.exitingProcess === name
                    property bool contentReady: false
                    property bool confirming: false
                    property int confirmSignal: 15
                    property bool busy: false
                    property bool flash: false
                    property real pressScale: pressArea.pressed ? 0.97 : 1.0
                    property real targetHeight: exiting ? 0 : rowContent.implicitHeight + 20
                    property bool hovered: hover.containsMouse
                    property color rowTint: root.avatarTint(name)
                    property real usageFraction: Math.min(1, memValue / Math.max(root.usedGiB, 0.1))
                    property real sweepX: -0.25

                    width: processColumn.width
                    height: targetHeight
                    radius: 18
                    color: flash ? root.theme.withAlpha(root.theme.color4, 0.16) : (hovered ? root.theme.withAlpha(rowTint, 0.12) : root.theme.withAlpha(root.theme.foreground, 0.045))
                    border.width: 0
                    opacity: exiting ? 0 : 1
                    x: exiting ? -width : (root.failedProcess === name ? shakeOffset.x : 0)
                    scale: pressScale
                    clip: true

                    Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(120 / 2) : 120; easing.type: Easing.OutCubic } }
                    Behavior on height { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.0; damping: 0.8; mass: 0.9; epsilon: 0.001 } }
                    Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(150 / 2) : 150; easing.type: Easing.OutCubic } }
                    Behavior on x { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.78; mass: 0.9; epsilon: 0.001 } }
                    Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.74; mass: 0.9; epsilon: 0.001 } }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: root.theme.withAlpha(row.rowTint, row.hovered ? 0.105 : 0.045) }
                            GradientStop { position: 0.42; color: root.theme.withAlpha(root.theme.foreground, 0.020) }
                            GradientStop { position: 1.0; color: root.theme.withAlpha(root.theme.background, 0) }
                        }
                    }

                    Rectangle {
                        width: 92
                        height: 92
                        radius: 46
                        x: parent.width - 52
                        y: -28
                        color: root.theme.withAlpha(row.rowTint, row.hovered ? 0.12 : 0.055)
                        scale: row.hovered ? 1.10 : 1
                        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 320; spring: 4.6; damping: 0.82; mass: 0.9; epsilon: 0.001 } }
                        Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(160 / 2) : 160; easing.type: Easing.OutCubic } }
                    }

                    Rectangle {
                        width: 40
                        height: parent.height * 1.6
                        x: parent.width * row.sweepX
                        y: -parent.height * 0.30
                        rotation: 18
                        color: root.theme.withAlpha(root.theme.foreground, 0.035)
                        opacity: row.hovered ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(140 / 2) : 140; easing.type: Easing.OutCubic } }
                    }

                    NumberAnimation on sweepX {
                        running: row.hovered
                        loops: Animation.Infinite
                        from: -0.25
                        to: 1.08
                        duration: theme && theme.reducedMotion ? Math.round(1500 / 2) : 1500
                        easing.type: Easing.InOutSine
                    }

                    onExpandedChanged: {
                        confirming = false
                        busy = false
                        contentReady = false
                        if (expanded)
                            contentDelay.restart()
                    }

                    Timer {
                        id: contentDelay
                        interval: 50
                        repeat: false
                        onTriggered: row.contentReady = row.expanded
                    }

                    SequentialAnimation {
                        id: flashAnim
                        PropertyAction { target: row; property: "flash"; value: true }
                        PauseAnimation { duration: theme && theme.reducedMotion ? Math.round(90 / 2) : 90 }
                        PropertyAction { target: row; property: "flash"; value: false }
                    }

                    SequentialAnimation {
                        id: shakeOffset
                        property real x: 0
                        NumberAnimation { target: shakeOffset; property: "x"; to: -4; duration: theme && theme.reducedMotion ? Math.round(45 / 2) : 45; easing.type: Easing.OutCubic }
                        NumberAnimation { target: shakeOffset; property: "x"; to: 4; duration: theme && theme.reducedMotion ? Math.round(45 / 2) : 45; easing.type: Easing.OutCubic }
                        NumberAnimation { target: shakeOffset; property: "x"; to: -4; duration: theme && theme.reducedMotion ? Math.round(45 / 2) : 45; easing.type: Easing.OutCubic }
                        NumberAnimation { target: shakeOffset; property: "x"; to: 0; duration: theme && theme.reducedMotion ? Math.round(55 / 2) : 55; easing.type: Easing.OutCubic }
                    }

                    onXChanged: {
                        if (root.failedProcess === name && !shakeOffset.running)
                            shakeOffset.restart()
                    }

                    Connections {
                        target: root
                        function onFailedProcessChanged() {
                            if (root.failedProcess === name)
                                shakeOffset.restart()
                        }
                    }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }

                    MouseArea {
                        id: pressArea
                        z: 1
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onPressed: function(mouse) {
                            ripple.x = mouse.x - ripple.width / 2
                            ripple.y = mouse.y - ripple.height / 2
                            rippleAnim.restart()
                            flashAnim.restart()
                        }
                        onClicked: {
                            root.expandedProcess = row.expanded ? "" : name
                        }
                    }

                    Rectangle {
                        id: ripple
                        z: 2
                        width: 18
                        height: 18
                        radius: 9
                        color: root.theme.withAlpha(root.theme.color4, 0.16)
                        opacity: 0
                        scale: 0
                    }

                    ParallelAnimation {
                        id: rippleAnim
                        NumberAnimation { target: ripple; property: "scale"; from: 0; to: 9; duration: theme && theme.reducedMotion ? Math.round(420 / 2) : 420; easing.type: Easing.OutCubic }
                        NumberAnimation { target: ripple; property: "opacity"; from: 0.6; to: 0; duration: theme && theme.reducedMotion ? Math.round(420 / 2) : 420; easing.type: Easing.OutCubic }
                    }

                    Column {
                        id: rowContent
                        z: 3
                        x: 12
                        y: 10
                        width: parent.width - 24
                        spacing: 10

                        RowLayout {
                            width: parent.width
                            height: 50
                            spacing: 12

                            Rectangle {
                                id: avatar
                                width: 42
                                height: 42
                                radius: 15
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 42
                                Layout.alignment: Qt.AlignVCenter
                                color: root.theme.withAlpha(row.rowTint, row.hovered ? 0.24 : 0.15)
                                scale: row.hovered ? 1.08 : 1.0
                                clip: true
                                Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.5; damping: 0.72; mass: 0.9; epsilon: 0.001 } }
                                Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(150 / 2) : 150; easing.type: Easing.OutCubic } }

                                Rectangle {
                                    width: 24
                                    height: 24
                                    radius: 12
                                    anchors.centerIn: parent
                                    color: root.theme.withAlpha(root.theme.background, 0.18)
                                }

                                RamSvgIcon {
                                    anchors.centerIn: parent
                                    theme: root.theme
                                    sourcePath: root.ramIconDir + "process_item.svg"
                                    iconColor: row.rowTint
                                    iconSize: 21
                                }

                                Rectangle {
                                    width: 7
                                    height: 7
                                    radius: 4
                                    anchors.right: parent.right
                                    anchors.rightMargin: 6
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 6
                                    color: row.usageFraction > 0.22 ? root.theme.color1 : root.theme.color4
                                    opacity: row.hovered || row.expanded ? 1 : 0.62
                                    Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(130 / 2) : 130; easing.type: Easing.OutCubic } }
                                }
                            }

                            Column {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 6

                                Row {
                                    width: parent.width
                                    height: 18
                                    spacing: 8

                                    Text {
                                        width: parent.width - metaPid.implicitWidth - 8
                                        text: name
                                        color: root.theme.foreground
                                        font.pixelSize: 15
                                        font.bold: row.hovered || row.expanded
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        id: metaPid
                                        text: "PID " + pid
                                        color: root.theme.withAlpha(root.theme.foreground, 0.42)
                                        font.pixelSize: 8
                                        font.bold: true
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 8
                                    radius: 4
                                    color: root.theme.withAlpha(root.theme.background, 0.26)
                                    clip: true

                                    Rectangle {
                                        anchors.fill: barFill
                                        radius: 4
                                        color: root.theme.withAlpha(row.rowTint, row.hovered ? 0.32 : 0.08)
                                        scale: 1.7
                                        Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(140 / 2) : 140; easing.type: Easing.OutCubic } }
                                    }

                                    Rectangle {
                                        id: barFill
                                        height: parent.height
                                        radius: 4
                                        width: Math.max(3, parent.width * row.usageFraction * (row.expanded ? 1.08 : 1.0) * root.processBarReveal)
                                        color: root.theme.withAlpha(row.rowTint, row.hovered ? 1.0 : 0.82)
                                        opacity: row.hovered ? 1 : 0.82
                                        Behavior on width { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(120 / 2) : 120; easing.type: Easing.OutCubic } }
                                        Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(120 / 2) : 120; easing.type: Easing.OutCubic } }
                                        Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(120 / 2) : 120; easing.type: Easing.OutCubic } }
                                    }
                                }
                            }

                            Item {
                                width: 76
                                height: 42
                                Layout.preferredWidth: 76
                                Layout.preferredHeight: 42
                                Layout.alignment: Qt.AlignVCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 14
                                    color: root.theme.withAlpha(row.rowTint, row.hovered ? 0.18 : 0.10)
                                    Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(140 / 2) : 140; easing.type: Easing.OutCubic } }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 1

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: memNumber + "G"
                                        color: row.rowTint
                                        font.pixelSize: 14
                                        font.bold: true
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: Math.round(row.usageFraction * 100) + "% used"
                                        color: root.theme.withAlpha(root.theme.foreground, 0.46)
                                        font.pixelSize: 8
                                        font.bold: true
                                    }
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: row.expanded ? expandedContent.implicitHeight : 0
                            clip: true

                            Behavior on height { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.0; damping: 0.8; mass: 0.9; epsilon: 0.001 } }

                            Column {
                                id: expandedContent
                                width: parent.width
                                spacing: 8
                                opacity: row.expanded && row.contentReady ? 1 : 0
                                y: row.expanded && row.contentReady ? 0 : 6

                                Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(140 / 2) : 140; easing.type: Easing.OutCubic } }
                                Behavior on y { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.0; damping: 0.8; mass: 0.9; epsilon: 0.001 } }

                                Row {
                                    width: parent.width
                                    spacing: 6

                                    DetailChip { theme: root.theme; width: (parent.width - 12) / 3; label: "PID"; value: String(pid); tint: root.theme.color4 }
                                    DetailChip { theme: root.theme; width: (parent.width - 12) / 3; label: "CPU"; value: cpu.toFixed(1) + "%"; tint: root.theme.color6 }
                                    DetailChip { theme: root.theme; width: (parent.width - 12) / 3; label: "MEM"; value: memMb.toFixed(0) + " MB"; tint: root.theme.color5 }
                                }

                                Loader {
                                    width: parent.width
                                    height: 34
                                    sourceComponent: row.confirming ? confirmButtons : actionButtons
                                }
                            }
                        }
                    }

                    Component {
                        id: actionButtons
                        Row {
                            spacing: 8
                            width: parent.width

                            ProcessActionButton {
                                theme: root.theme
                                width: (parent.width - 8) / 2
                                label: "Terminate"
                                tint: root.theme.color3
                                filled: false
                                busy: row.busy && row.confirmSignal === 15
                                onPressedAction: {
                                    row.confirmSignal = 15
                                    row.confirming = true
                                }
                            }

                            ProcessActionButton {
                                theme: root.theme
                                width: (parent.width - 8) / 2
                                label: "Kill"
                                tint: root.theme.color1
                                filled: true
                                busy: row.busy && row.confirmSignal === 9
                                onPressedAction: {
                                    row.confirmSignal = 9
                                    row.confirming = true
                                }
                            }
                        }
                    }

                    Component {
                        id: confirmButtons
                        Row {
                            spacing: 8
                            width: parent.width

                            Text {
                                width: parent.width - 144
                                text: "Are you sure?"
                                color: root.theme.foreground
                                font.pixelSize: 14
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            ProcessActionButton {
                                theme: root.theme
                                width: 66
                                label: "No"
                                tint: root.theme.color4
                                filled: false
                                entryDelay: 0
                                entryFrom: -8
                                pressDamping: 0.5
                                onPressedAction: row.confirming = false
                            }

                            ProcessActionButton {
                                theme: root.theme
                                width: 66
                                label: "Yes"
                                tint: row.confirmSignal === 9 ? root.theme.color1 : root.theme.color3
                                filled: true
                                busy: row.busy
                                entryDelay: 80
                                entryFrom: 8
                                onPressedAction: {
                                    row.busy = true
                                    executeDelay.restart()
                                }
                            }

                            Timer {
                                id: executeDelay
                                interval: 300
                                repeat: false
                                onTriggered: {
                                    row.busy = false
                                    root.executeKill(pid, row.confirmSignal, name)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function refreshMemory() {
        const text = memFile.text()
        const total = readKb(text, "MemTotal")
        const available = readKb(text, "MemAvailable")
        const cached = readKb(text, "Cached") + readKb(text, "SReclaimable")
        const free = readKb(text, "MemFree")
        if (total <= 0)
            return

        const used = total - available
        totalGiB = total / 1048576
        usedGiB = used / 1048576
        cachedGiB = cached / 1048576
        freeGiB = free / 1048576
        displayUsedGiB = usedGiB
        displayCachedGiB = cachedGiB
        displayFreeGiB = freeGiB
        percentage = Math.round((used / total) * 100)
        appendHistory(percentage)
    }

    function refreshProcesses() {
        if (processProbe.running)
            return
        processLoading = true
        processProbe.exec(processProbe.command)
    }

    function readKb(text, key) {
        const match = new RegExp("^" + key + ":\\s+(\\d+)", "m").exec(text)
        return match ? Number(match[1]) : 0
    }

    function appendHistory(value) {
        historyModel.append({ p: value })
        while (historyModel.count > 60)
            historyModel.remove(0)
        sparkline.requestPaint()
    }

    function seedHistory() {
        if (historyModel.count >= 2)
            return
        const base = percentage > 0 ? percentage : 42
        historyModel.clear()
        for (let i = 0; i < 12; i++) {
            const wave = Math.sin(i * 0.9) * 2.8
            const drift = (i - 6) * 0.22
            historyModel.append({ p: Math.max(1, Math.min(100, base + wave + drift)) })
        }
    }

    function parseProcesses(text) {
        const rows = {}
        const lines = text.trim().split("\n").slice(1)

        for (let i = 0; i < lines.length; i++) {
            const parts = lines[i].trim().split(/\s+/)
            if (parts.length < 11)
                continue

            const pid = Number(parts[1])
            const cpu = Number(parts[2])
            const rssKb = Number(parts[5])
            if (!Number.isFinite(rssKb) || rssKb <= 0)
                continue

            const command = parts.slice(10).join(" ")
            const name = normalizeProcess(command)
            if (name.length === 0)
                continue

            if (!rows[name])
                rows[name] = { rss: 0, pid: pid, cpu: 0, topRss: 0 }
            rows[name].rss += rssKb
            rows[name].cpu += Number.isFinite(cpu) ? cpu : 0
            if (rssKb > rows[name].topRss) {
                rows[name].topRss = rssKb
                rows[name].pid = pid
            }
        }

        const list = []
        for (const key in rows) {
            const gib = rows[key].rss / 1024 / 1024
            if (gib > 0)
                list.push({ name: key, value: gib, pid: rows[key].pid, cpu: rows[key].cpu, mb: rows[key].rss / 1024 })
        }

        list.sort((a, b) => b.value - a.value)
        processModel.clear()
        for (let j = 0; j < Math.min(10, list.length); j++) {
            processModel.append({
                name: list[j].name,
                memValue: list[j].value,
                memNumber: list[j].value.toFixed(1),
                memMb: list[j].mb,
                pid: list[j].pid,
                cpu: list[j].cpu
            })
        }
    }

    function executeKill(pid, signal, name) {
        if (!Number.isFinite(Number(pid)) || Number(pid) <= 0)
            return
        pendingPid = Number(pid)
        pendingSignal = signal
        pendingName = name
        killProbe.exec(["kill", "-" + signal, String(pid)])
    }

    function normalizeProcess(command) {
        let raw = String(command || "").trim()
        if (raw.length === 0)
            return ""

        if (raw.indexOf("Isolated") >= 0)
            return "Firefox"

        raw = raw.split(/\s+/)[0]
        raw = raw.split("/").pop()
        raw = raw.replace(/^["']|["']$/g, "")

        const lower = raw.toLowerCase()
        if (lower.indexOf("chrome") >= 0 || lower.indexOf("chromium") >= 0 || lower.indexOf("zygote") >= 0)
            return "Chromium"
        if (lower.indexOf("firefox") >= 0 || lower.indexOf("webcontent") >= 0)
            return "Firefox"
        if (lower.indexOf("vesktop") >= 0 || lower.indexOf("discord") >= 0)
            return "Vesktop"
        if (lower.indexOf("electron") >= 0)
            return "Electron"

        return raw.length > 24 ? raw.slice(0, 24) : raw
    }

    function restartArc() {
        arcAnim.stop()
        currentAngle = 0
        displayPercent = 0
        arcUsedGiB = 0
        memoryArc.requestPaint()
        arcAnim.restart()
    }

    function restartProcessBars() {
        processBarReveal = 0
        Qt.callLater(function() { root.processBarReveal = 1 })
    }

    function levelColor(value) {
        if (value >= 80)
            return theme.color1
        if (value >= 50)
            return theme.color3
        return theme.color6
    }

    function avatarTint(text) {
        const palette = [theme.color2, theme.color3, theme.color4, theme.color5, theme.color6]
        const s = String(text || "")
        const code = s.length > 0 ? s.charCodeAt(0) : 0
        return palette[code % palette.length]
    }

    function paintSparkline(ctx, w, h) {
        ctx.reset()
        if (historyModel.count < 2)
            return

        const pad = 4
        let maxValue = 1
        for (let m = 0; m < historyModel.count; m++)
            maxValue = Math.max(maxValue, Number(historyModel.get(m).p))
        maxValue = Math.min(100, Math.max(1, maxValue))
        const canvasHeight = h - pad * 2
        const points = []
        for (let i = 0; i < historyModel.count; i++) {
            const x = pad + (w - pad * 2) * i / Math.max(1, historyModel.count - 1)
            const value = Math.max(0, Math.min(maxValue, Number(historyModel.get(i).p)))
            const y = pad + canvasHeight - (value / maxValue * canvasHeight)
            points.push({ x: x, y: y })
        }

        ctx.lineWidth = 2.4
        ctx.lineCap = "round"
        ctx.strokeStyle = usageColor
        ctx.beginPath()
        ctx.moveTo(points[0].x, points[0].y)
        for (let j = 1; j < points.length; j++) {
            const prev = points[j - 1]
            const cur = points[j]
            const midX = (prev.x + cur.x) / 2
            ctx.bezierCurveTo(midX, prev.y, midX, cur.y, cur.x, cur.y)
        }
        ctx.stroke()

        const fill = ctx.createLinearGradient(0, 0, 0, h)
        fill.addColorStop(0, theme.withAlpha(usageColor, 0.24))
        fill.addColorStop(1, theme.withAlpha(usageColor, 0))
        ctx.lineTo(points[points.length - 1].x, h - pad)
        ctx.lineTo(points[0].x, h - pad)
        ctx.closePath()
        ctx.fillStyle = fill
        ctx.fill()
    }

    component StatChip: Item {
        id: statChip
        property var theme
        property string label: ""
        property string value: ""
        property color tint: theme.color6
        property bool hovered: chipHover.containsMouse

        height: 54
        scale: hovered ? 1.025 : 1.0

        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 260; spring: 5.0; damping: 0.82; mass: 0.85; epsilon: 0.001 } }

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: statChip.theme.withAlpha(statChip.hovered ? statChip.tint : statChip.theme.foreground, statChip.hovered ? 0.125 : 0.045)
            clip: true
            Behavior on color { ColorAnimation { duration: statChip.theme.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }

            Rectangle {
                width: 3
                height: parent.height - 18
                radius: 2
                x: 9
                anchors.verticalCenter: parent.verticalCenter
                color: statChip.tint
                opacity: statChip.hovered ? 1 : 0.58
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: statChip.value
                color: statChip.tint
                font.pixelSize: 17
                font.bold: true
            }

            Text {
                text: statChip.label.toUpperCase()
                color: statChip.theme.withAlpha(statChip.theme.foreground, 0.48)
                font.pixelSize: 8
                font.bold: true
            }
        }

        MouseArea { id: chipHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
    }

    component RamSvgIcon: Item {
        id: ramIcon

        property var theme
        property string sourcePath: ""
        property color iconColor: "white"
        property int iconSize: 24

        width: iconSize
        height: iconSize

        Behavior on width { NumberAnimation { duration: ramIcon.theme && ramIcon.theme.reducedMotion ? 0 : 140; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: ramIcon.theme && ramIcon.theme.reducedMotion ? 0 : 140; easing.type: Easing.OutCubic } }

        Image {
            id: svgSource
            anchors.fill: parent
            source: ramIcon.sourcePath
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
            colorizationColor: ramIcon.iconColor

            Behavior on colorizationColor { ColorAnimation { duration: ramIcon.theme && ramIcon.theme.reducedMotion ? 0 : 170; easing.type: Easing.OutCubic } }
        }
    }

    component DetailChip: Item {
        id: detailChip

        property var theme
        property string label: ""
        property string value: ""
        property color tint: theme.color6
        property bool hovered: chipHover.containsMouse
        property bool valueFlash: false

        height: 32
        scale: hovered ? 1.05 : 1.0

        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.4; damping: 0.72; mass: 0.9; epsilon: 0.001 } }

        onValueChanged: flashAnim.restart()

        MouseArea {
            id: chipHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        Rectangle {
            anchors.fill: parent
            radius: 13
            color: detailChip.theme.withAlpha(detailChip.tint, detailChip.hovered ? 0.18 : 0.10)
            Behavior on color { ColorAnimation { duration: detailChip.theme.reducedMotion ? 0 : 140; easing.type: Easing.OutCubic } }
        }

        SequentialAnimation {
            id: flashAnim
            PropertyAction { target: detailChip; property: "valueFlash"; value: true }
            NumberAnimation { target: valueText; property: "opacity"; from: 1.0; to: 0.5; duration: theme && theme.reducedMotion ? Math.round(150 / 2) : 150; easing.type: Easing.OutCubic }
            NumberAnimation { target: valueText; property: "opacity"; from: 0.5; to: 1.0; duration: theme && theme.reducedMotion ? Math.round(150 / 2) : 150; easing.type: Easing.OutCubic }
            PropertyAction { target: detailChip; property: "valueFlash"; value: false }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Text {
                text: detailChip.label.toUpperCase()
                color: detailChip.theme.withAlpha(detailChip.theme.foreground, 0.52)
                font.pixelSize: 8
                font.bold: true
            }

            Text {
                id: valueText
                text: detailChip.value
                color: detailChip.valueFlash ? detailChip.theme.color4 : detailChip.tint
                font.pixelSize: 11
                font.bold: true
                Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(120 / 2) : 120; easing.type: Easing.OutCubic } }
            }
        }
    }

    component ProcessActionButton: Item {
        id: actionButton

        signal pressedAction()

        property var theme
        property string label: ""
        property color tint: theme.color6
        property bool filled: false
        property bool busy: false
        property bool down: click.pressed
        property bool hovered: click.containsMouse
        property bool successFlash: false
        property int entryDelay: 0
        property real entryFrom: 0
        property real pressDamping: 0.74
        property real pulseOpacity: 1.0
        property real contentOffset: 0

        height: 34
        scale: down ? 0.93 : (hovered ? 1.03 : 1.0)
        opacity: 0

        Component.onCompleted: entryTimer.restart()

        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: actionButton.pressDamping; mass: 0.9; epsilon: 0.001 } }
        Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(150 / 2) : 150; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: 13
            color: actionButton.successFlash ? actionButton.theme.withAlpha(actionButton.theme.color4, 0.24)
                : (actionButton.filled ? actionButton.theme.withAlpha(actionButton.tint, actionButton.hovered ? 0.30 : 0.20)
                : actionButton.theme.withAlpha(actionButton.hovered ? actionButton.tint : actionButton.theme.foreground, actionButton.hovered ? 0.10 : 0.040))
            clip: true
            Behavior on color { ColorAnimation { duration: actionButton.theme.reducedMotion ? 0 : 120; easing.type: Easing.OutCubic } }

            Rectangle {
                width: actionButton.hovered ? parent.width : 0
                height: parent.height
                color: actionButton.theme.withAlpha(actionButton.tint, 0.07)
                Behavior on width { SpringAnimation { duration: actionButton.theme.reducedMotion ? 0 : 240; spring: 4.8; damping: 0.84; mass: 0.8; epsilon: 0.001 } }
            }
        }

        Timer {
            id: entryTimer
            interval: actionButton.entryDelay
            repeat: false
            onTriggered: {
                actionButton.opacity = 1
                actionButton.contentOffset = 0
            }
        }

        SequentialAnimation on pulseOpacity {
            running: actionButton.hovered && actionButton.filled
            loops: Animation.Infinite
            NumberAnimation { to: 0.75; duration: theme && theme.reducedMotion ? Math.round(420 / 2) : 420; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: theme && theme.reducedMotion ? Math.round(420 / 2) : 420; easing.type: Easing.InOutSine }
        }

        Row {
            x: actionButton.contentOffset
            anchors.centerIn: parent
            spacing: 7
            opacity: actionButton.pulseOpacity

            Component.onCompleted: actionButton.contentOffset = actionButton.entryFrom
            Behavior on x { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(150 / 2) : 150; easing.type: Easing.OutCubic } }

            BusyIndicator {
                width: 14
                height: 14
                visible: actionButton.busy
                running: actionButton.busy
            }

            Text {
                text: actionButton.label
                color: actionButton.filled ? actionButton.theme.foreground : (actionButton.hovered ? actionButton.theme.color3 : actionButton.tint)
                font.pixelSize: 13
                font.bold: true
                Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(120 / 2) : 120; easing.type: Easing.OutCubic } }
            }
        }

        MouseArea {
            id: click
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            onClicked: actionButton.pressedAction()
        }
    }
}

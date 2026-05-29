import QtQuick

Rectangle {
    id: root

    property var theme
    property var entry
    property bool selected: false
    property bool pinned: false
    property int appearDelay: 0
    property int entryIndex: 0
    property bool appeared: false
    property bool hovered: hover.containsMouse
    property bool exiting: false
    property bool dimmed: false
    property bool pasting: false
    property bool fresh: false
    property bool hasAnimatedIn: false
    property bool confirmingDelete: false
    property real confirmProgress: 1
    property real rippleX: 0
    property real rippleY: 0
    property bool rippleRun: false
    property bool pasteFloat: false
    property real enterOpacity: hasAnimatedIn ? 1 : 0
    property real enterScale: hasAnimatedIn ? 1 : 0.92
    property real enterXOffset: hasAnimatedIn ? 0 : enterX
    property real pulseScale: 1
    readonly property bool code: entry && entry.type === "Code"
    readonly property int lineCount: entry ? Math.max(1, String(entry.content).split("\\n").length) : 1
    readonly property int enterX: entryIndex % 2 === 0 ? 8 : -8

    signal clicked()
    signal deleteRequested()
    signal pinRequested()
    signal appearedOnce()

    height: exiting ? 0 : 82
    radius: 18
    color: pasting ? theme.withAlpha(theme.color4, 0.26) : (selected || hovered ? theme.withAlpha(theme.color4, 0.105) : theme.withAlpha(theme.foreground, 0.045))
    opacity: exiting ? 0 : (enterOpacity * (dimmed && !pasting ? 0.3 : 1))
    scale: (pasting ? 1.04 : (hover.pressed ? 0.97 : enterScale)) * pulseScale
    x: exiting ? width + 40 : enterXOffset
    clip: true
    border.width: 0
    transform: Translate { y: hover.pressed ? 1 : (hovered ? -2 : 0) }

    Behavior on height { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.78; mass: 0.9; epsilon: 0.001 } }
    Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic } }
    Behavior on x { NumberAnimation { duration: root.exiting ? 250 : 200; easing.type: root.exiting ? Easing.OutCubic : Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root.theme.withAlpha(root.theme.color4, root.selected || root.hovered ? 0.075 : 0.025) }
            GradientStop { position: 0.48; color: "transparent" }
            GradientStop { position: 1.0; color: root.theme.withAlpha(root.theme.background, 0) }
        }
    }

    Timer {
        id: appearTimer
        interval: root.appearDelay
        repeat: false
        onTriggered: {
            if (!root.hasAnimatedIn)
                enterAnim.restart()
        }
    }
    Timer { id: deleteTimer; interval: 250; repeat: false; onTriggered: root.deleteRequested() }
    Timer {
        id: confirmCancelTimer
        interval: 4000
        repeat: false
        onTriggered: root.cancelDeleteConfirm()
    }
    Timer {
        id: firstPulseTimer
        interval: root.appearDelay + 210
        repeat: false
        onTriggered: if (root.entryIndex === 0) firstPulse.start()
    }
    Component.onCompleted: {
        prepareEntrance()
    }

    ParallelAnimation {
        id: enterAnim
        NumberAnimation { target: root; property: "enterOpacity"; from: 0; to: 1; duration: theme && theme.reducedMotion ? Math.round(200 / 2) : 200; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "enterXOffset"; from: root.enterX; to: 0; duration: theme && theme.reducedMotion ? Math.round(200 / 2) : 200; easing.type: Easing.OutCubic }
        SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  target: root; property: "enterScale"; from: 0.92; to: 1.0; spring: 5.0; damping: 0.72; mass: 0.9; epsilon: 0.001 }
        onStarted: root.appeared = true
        onFinished: root.appearedOnce()
    }

    SequentialAnimation {
        id: firstPulse
        NumberAnimation { target: root; property: "pulseScale"; to: 1.03; duration: theme && theme.reducedMotion ? Math.round(120 / 2) : 120; easing.type: Easing.OutCubic }
        SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  target: root; property: "pulseScale"; to: 1.0; spring: 5.0; damping: 0.72; mass: 0.9; epsilon: 0.001 }
    }

    Rectangle {
        width: 3
        height: root.selected || root.hovered || root.code ? parent.height - 18 : 18
        radius: 2
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        color: root.theme.color4
        opacity: root.code ? codeBreath : (root.selected || root.hovered ? 1 : 0.40)
        Behavior on height { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 6.0; damping: 0.7; mass: 0.9; epsilon: 0.001 } }
        SequentialAnimation on codeBreath {
            running: root.code
            loops: Animation.Infinite
            NumberAnimation { to: 0.5; duration: theme && theme.reducedMotion ? Math.round(1500 / 2) : 1500; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: theme && theme.reducedMotion ? Math.round(1500 / 2) : 1500; easing.type: Easing.InOutSine }
        }
        property real codeBreath: 1
    }

    Text {
        visible: root.pinned
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 8
        text: "󰐃"
        color: root.theme.color4
        font.family: root.theme.fontFamily
        font.pixelSize: 12 * root.theme.fontScale
        z: 4
        scale: root.pinned ? pinPulse : 1
        SequentialAnimation on pinPulse {
            running: root.pinned
            loops: Animation.Infinite
            NumberAnimation { to: 1.2; duration: theme && theme.reducedMotion ? Math.round(1000 / 2) : 1000; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: theme && theme.reducedMotion ? Math.round(1000 / 2) : 1000; easing.type: Easing.InOutSine }
        }
        property real pinPulse: 1
    }

    Rectangle {
        id: shimmer
        visible: root.entryIndex === 0 && root.appeared && !root.exiting
        width: 54
        height: parent.height * 1.6
        y: -parent.height * 0.3
        x: -width
        rotation: 18
        opacity: 0
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.04) }
            GradientStop { position: 1.0; color: "transparent" }
        }
        SequentialAnimation {
            running: shimmer.visible
            loops: Animation.Infinite
            PauseAnimation { duration: theme && theme.reducedMotion ? Math.round(5000 / 2) : 5000 }
            ParallelAnimation {
                NumberAnimation { target: shimmer; property: "x"; from: -shimmer.width; to: root.width + shimmer.width; duration: theme && theme.reducedMotion ? Math.round(800 / 2) : 800; easing.type: Easing.OutCubic }
                SequentialAnimation {
                    NumberAnimation { target: shimmer; property: "opacity"; to: 1; duration: theme && theme.reducedMotion ? Math.round(180 / 2) : 180 }
                    PauseAnimation { duration: theme && theme.reducedMotion ? Math.round(360 / 2) : 360 }
                    NumberAnimation { target: shimmer; property: "opacity"; to: 0; duration: theme && theme.reducedMotion ? Math.round(260 / 2) : 260 }
                }
            }
            ScriptAction { script: shimmer.x = -shimmer.width }
        }
    }

    Text {
        id: preview
        x: 24
        y: 14
        width: parent.width - 128
        height: 42
        text: root.entry ? root.entry.preview : ""
        color: root.hovered || root.selected || root.pasting ? root.theme.foreground : root.theme.color6
        font.family: root.theme.fontFamily
        font.pixelSize: (root.code ? 12 : 14) * root.theme.fontScale
        font.bold: root.selected || root.hovered
        maximumLineCount: 2
        wrapMode: Text.WordWrap
        elide: Text.ElideRight
        Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(200 / 2) : 200; easing.type: Easing.OutCubic } }
        opacity: root.confirmingDelete ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(140 / 2) : 140; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        visible: root.fresh
        anchors.right: parent.right
        anchors.rightMargin: 44
        anchors.top: parent.top
        anchors.topMargin: 8
        width: freshText.implicitWidth + 14
        height: 18
        radius: root.theme.pillRadius
        color: root.theme.withAlpha(root.theme.color4, 0.18)
        Text { id: freshText; anchors.centerIn: parent; text: "New"; color: root.theme.color4; font.family: root.theme.fontFamily; font.pixelSize: 10 * root.theme.fontScale; font.bold: root.theme.fontBold }
    }

    Rectangle {
        visible: root.code
        x: 24
        y: 58
        width: langText.implicitWidth + 14
        height: 18
        radius: root.theme.pillRadius
        color: root.theme.withAlpha(root.theme.color4, 0.16)
        Text { id: langText; anchors.centerIn: parent; text: "code"; color: root.theme.color4; font.family: root.theme.fontFamily; font.pixelSize: 10 * root.theme.fontScale; font.bold: root.theme.fontBold }
        opacity: root.confirmingDelete ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(140 / 2) : 140; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        visible: root.lineCount > 2 && !root.code
        x: 24
        y: 58
        width: linesText.implicitWidth + 14
        height: 18
        radius: root.theme.pillRadius
        color: root.theme.withAlpha(root.theme.color6, 0.14)
        Text { id: linesText; anchors.centerIn: parent; text: "+" + (root.lineCount - 2) + " lines"; color: root.theme.color6; font.family: root.theme.fontFamily; font.pixelSize: 10 * root.theme.fontScale }
        opacity: root.confirmingDelete ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(140 / 2) : 140; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        id: timeChip
        anchors.right: deleteButton.left
        anchors.rightMargin: root.hovered ? 9 : 6
        anchors.verticalCenter: parent.verticalCenter
        width: timeText.implicitWidth + 14
        height: 22
        radius: 11
        color: root.theme.withAlpha(root.theme.foreground, 0.055)
        opacity: root.hovered ? 0.72 : 1
        Behavior on anchors.rightMargin { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.8; mass: 0.9; epsilon: 0.001 } }
        Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(160 / 2) : 160; easing.type: Easing.OutCubic } }
        Text { id: timeText; anchors.centerIn: parent; text: root.timeAgo(root.entry ? root.entry.timestamp : Date.now()); color: root.theme.color6; font.family: root.theme.fontFamily; font.pixelSize: 10 * root.theme.fontScale }
        visible: !root.confirmingDelete
    }

    Rectangle {
        id: deleteButton
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        radius: 11
        color: deleteHover.containsMouse ? root.theme.withAlpha(root.theme.color1, 0.24) : root.theme.withAlpha(root.theme.foreground, 0.055)
        opacity: root.hovered ? 1 : 0
        scale: deleteHover.containsMouse ? 1.1 : 1
        Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(120 / 2) : 120; easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.72; mass: 0.9; epsilon: 0.001 } }
        transform: Translate { x: root.hovered ? 0 : 8 }
        visible: !root.confirmingDelete
        z: 30
        Text { anchors.centerIn: parent; text: "×"; color: root.theme.color1; font.family: root.theme.fontFamily; font.pixelSize: 15 * root.theme.fontScale; font.bold: root.theme.fontBold }
        MouseArea {
            id: deleteHover
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            propagateComposedEvents: false
            onClicked: function(mouse) {
                mouse.accepted = true
                root.showDeleteConfirm()
            }
        }
    }

    Item {
        id: confirmLayer
        anchors.fill: parent
        z: 35
        opacity: root.confirmingDelete ? 1 : 0
        transform: Translate { x: root.confirmingDelete ? 0 : 18 }
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(160 / 2) : 160; easing.type: Easing.OutCubic } }
        Behavior on x { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(160 / 2) : 160; easing.type: Easing.OutCubic } }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                text: "Delete clipboard entry?"
                color: root.theme.foreground
                font.family: root.theme.fontFamily
                font.pixelSize: 13 * root.theme.fontScale
                font.bold: root.theme.fontBold
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                width: 66
                height: 30
                radius: root.theme.pillRadius
                color: noArea.containsMouse ? root.theme.withAlpha(root.theme.color6, 0.18) : root.theme.withAlpha(root.theme.color1, 0.20)
                border.width: 0
                scale: noArea.pressed ? 0.92 : 1
                Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(140 / 2) : 140; easing.type: Easing.OutCubic } }
                Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.65; mass: 0.9; epsilon: 0.001 } }
                Text { anchors.centerIn: parent; text: "No"; color: root.theme.color6; font.family: root.theme.fontFamily; font.pixelSize: 11 * root.theme.fontScale; font.bold: root.theme.fontBold }
                MouseArea {
                    id: noArea
                    anchors.fill: parent
                    hoverEnabled: true
                    preventStealing: true
                    propagateComposedEvents: false
                    onClicked: function(mouse) {
                        mouse.accepted = true
                        root.cancelDeleteConfirm()
                    }
                }
            }

            Rectangle {
                width: 74
                height: 30
                radius: root.theme.pillRadius
                color: yesArea.containsMouse ? root.theme.withAlpha(root.theme.color1, 0.40) : root.theme.withAlpha(root.theme.color1, 0.26)
                border.width: 0
                scale: yesArea.pressed ? 0.92 : 1
                Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(140 / 2) : 140; easing.type: Easing.OutCubic } }
                Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.65; mass: 0.9; epsilon: 0.001 } }
                Text { anchors.centerIn: parent; text: "Delete"; color: root.theme.color1; font.family: root.theme.fontFamily; font.pixelSize: 11 * root.theme.fontScale; font.bold: root.theme.fontBold }
                MouseArea {
                    id: yesArea
                    anchors.fill: parent
                    hoverEnabled: true
                    preventStealing: true
                    propagateComposedEvents: false
                    onClicked: function(mouse) {
                        mouse.accepted = true
                        root.confirmDeleteNow()
                    }
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: parent.width * root.confirmProgress
            height: 2
            color: root.theme.color4
            opacity: 0.85
        }
    }

    Rectangle {
        id: ripple
        width: 90
        height: 90
        radius: 45
        x: root.rippleX - width / 2
        y: root.rippleY - height / 2
        color: root.theme.withAlpha(root.theme.color4, 0.20)
        opacity: 0
        scale: 0.2
        z: 3
    }

    Text {
        anchors.centerIn: parent
        text: ""
        color: root.theme.color4
        font.family: root.theme.fontFamily
        font.pixelSize: 32 * root.theme.fontScale
        font.bold: root.theme.fontBold
        opacity: root.pasting ? 1 : 0
        scale: root.pasting ? 1 : 0
        z: 5
        Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(120 / 2) : 120; easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.65; mass: 0.9; epsilon: 0.001 } }
    }

    Rectangle {
        width: copiedText.implicitWidth + 24
        height: 28
        radius: root.theme.pillRadius
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.pasteFloat ? parent.height - 48 : parent.height - 26
        opacity: root.pasteFloat ? 0 : (root.pasting ? 1 : 0)
        color: root.theme.withAlpha(root.theme.color4, 0.24)
        border.width: 0
        z: 6
        Behavior on y { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(420 / 2) : 420; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(420 / 2) : 420; easing.type: Easing.OutCubic } }
        Text { id: copiedText; anchors.centerIn: parent; text: "Copied!"; color: root.theme.color4; font.family: root.theme.fontFamily; font.pixelSize: 11 * root.theme.fontScale; font.bold: root.theme.fontBold }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: 1
        onPressed: function(mouse) {
            root.rippleX = mouse.x
            root.rippleY = mouse.y
            rippleAnim.restart()
        }
        onClicked: function(mouse) {
            if (root.confirmingDelete) {
                mouse.accepted = true
                return
            }
            if (mouse.button === Qt.RightButton) {
                mouse.accepted = true
                root.pinRequested()
            } else {
                mouse.accepted = true
                root.clicked()
            }
        }
        onPressAndHold: root.pinRequested()
    }

    ParallelAnimation {
        id: rippleAnim
        NumberAnimation { target: ripple; property: "opacity"; from: 0.2; to: 0; duration: theme && theme.reducedMotion ? Math.round(400 / 2) : 400; easing.type: Easing.OutCubic }
        NumberAnimation { target: ripple; property: "scale"; from: 0.25; to: 2.5; duration: theme && theme.reducedMotion ? Math.round(400 / 2) : 400; easing.type: Easing.OutCubic }
    }

    onPastingChanged: {
        if (pasting) {
            pasteFloat = false
            pasteFloatTimer.restart()
        }
    }

    Timer {
        id: pasteFloatTimer
        interval: 120
        repeat: false
        onTriggered: root.pasteFloat = true
    }

    NumberAnimation {
        id: confirmCountdown
        target: root
        property: "confirmProgress"
        from: 1
        to: 0
        duration: theme && theme.reducedMotion ? Math.round(4000 / 2) : 4000
        easing.type: Easing.Linear
    }

    function prepareEntrance() {
        appearTimer.stop()
        firstPulseTimer.stop()
        pulseScale = 1
        if (hasAnimatedIn) {
            enterOpacity = 1
            enterScale = 1
            enterXOffset = 0
            appeared = true
            return
        }
        enterOpacity = 0
        enterScale = 0.92
        enterXOffset = enterX
        appeared = false
        appearTimer.restart()
        firstPulseTimer.restart()
    }

    onEntryChanged: prepareEntrance()

    function showDeleteConfirm() {
        confirmCountdown.stop()
        confirmCancelTimer.stop()
        confirmingDelete = true
        confirmProgress = 1
        confirmCountdown.restart()
        confirmCancelTimer.restart()
    }

    function cancelDeleteConfirm() {
        confirmCountdown.stop()
        confirmCancelTimer.stop()
        confirmingDelete = false
        confirmProgress = 1
    }

    function confirmDeleteNow() {
        confirmCountdown.stop()
        confirmCancelTimer.stop()
        confirmingDelete = false
        exiting = true
        deleteTimer.restart()
    }

    function timeAgo(ts) {
        const sec = Math.max(1, Math.floor((Date.now() - ts) / 1000))
        if (sec < 60)
            return "now"
        const min = Math.floor(sec / 60)
        if (min < 60)
            return min + "m"
        const hr = Math.floor(min / 60)
        return hr + "h"
    }
}

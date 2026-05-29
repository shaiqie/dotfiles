import QtQuick

Rectangle {
    id: root

    property var theme
    property var itemData
    property int cellIndex: 0
    property int appearDelay: 0
    property bool hasAnimatedIn: false
    property bool selected: false
    property bool compact: false
    property bool idlePaused: false
    property real enterOpacity: hasAnimatedIn ? 1 : 0
    property real enterScale: hasAnimatedIn ? 1 : 0.5
    property real pressScale: mouse.pressed ? 0.85 : 1
    property real hoverScale: mouse.containsMouse || selected ? (compact ? 1.18 : 1.35) : 1
    property real bobY: 0
    property real launchScale: 1
    property real launchY: 0
    property bool launching: false
    property real rippleX: width / 2
    property real rippleY: height / 2

    signal chosen()

    width: compact ? 36 : 48
    height: compact ? 36 : 48
    radius: compact ? 13 : 16
    color: mouse.containsMouse || selected ? theme.withAlpha(theme.color4, 0.105) : theme.withAlpha(theme.foreground, compact ? 0.030 : 0.020)
    opacity: launching ? 0 : enterOpacity
    scale: enterScale * pressScale
    border.width: 0
    clip: true

    Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(140 / 2) : 140; easing.type: Easing.OutCubic } }
    Behavior on pressScale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 7.0; damping: mouse.pressed ? 1.0 : 0.45; mass: 0.9; epsilon: 0.001 } }
    Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic } }

    Timer {
        id: appearTimer
        interval: root.appearDelay
        repeat: false
        onTriggered: if (!root.hasAnimatedIn) enterAnim.restart()
    }

    Component.onCompleted: {
        if (root.hasAnimatedIn) {
            enterOpacity = 1
            enterScale = 1
        } else {
            appearTimer.restart()
        }
    }

    ParallelAnimation {
        id: enterAnim
        NumberAnimation { target: root; property: "enterOpacity"; from: 0; to: 1; duration: theme && theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic }
        SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  target: root; property: "enterScale"; from: 0.5; to: 1; spring: 6.0; damping: 0.65; mass: 0.9; epsilon: 0.001 }
        onFinished: root.hasAnimatedIn = true
    }

    Rectangle {
        id: flood
        anchors.fill: parent
        radius: parent.radius
        color: root.theme.withAlpha(root.theme.color4, 0.40)
        opacity: 0
        z: 2
    }

    Rectangle {
        width: selected ? parent.width - 14 : 0
        height: 3
        radius: 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 7
        color: root.theme.color4
        opacity: selected ? 1 : 0
        Behavior on width { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 260; spring: 5.0; damping: 0.82; mass: 0.8; epsilon: 0.001 } }
        Behavior on opacity { NumberAnimation { duration: root.theme.reducedMotion ? 0 : 140; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        id: ripple
        width: compact ? 44 : 64
        height: width
        radius: width / 2
        x: root.rippleX - width / 2
        y: root.rippleY - height / 2
        color: root.theme.withAlpha(root.theme.color4, 0.30)
        opacity: 0
        scale: 0.2
        z: 3
    }

    Text {
        id: emojiText
        anchors.centerIn: parent
        text: root.itemData ? root.itemData.emoji : ""
        font.family: root.theme.fontFamily
        font.pixelSize: (compact ? 20 : 25) * root.theme.fontScale
        y: root.bobY + root.launchY
        scale: root.hoverScale * root.launchScale
        rotation: idleSpin.running ? 360 * idleSpin.progress : 0
        z: 4
        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 7.0; damping: 0.6; mass: 0.9; epsilon: 0.001 } }
        Behavior on y { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.75; mass: 0.9; epsilon: 0.001 } }
    }

    Rectangle {
        id: tooltip
        visible: !root.compact && mouse.containsMouse && root.itemData
        width: tipText.implicitWidth + 18
        height: 26
        radius: root.theme.pillRadius
        x: Math.max(0, Math.min(parent.width - width, parent.width / 2 - width / 2))
        y: parent.height + (visible ? 4 : 8)
        color: root.theme.withAlpha(root.theme.color0, 0.95)
        border.width: 0
        opacity: visible ? 1 : 0
        z: 20
        Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(120 / 2) : 120; easing.type: Easing.OutCubic } }
        Behavior on y { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.75; mass: 0.9; epsilon: 0.001 } }
        Text {
            id: tipText
            anchors.centerIn: parent
            text: root.itemData ? root.itemData.name : ""
            color: root.theme.foreground
            font.family: root.theme.fontFamily
            font.pixelSize: 10 * root.theme.fontScale
            elide: Text.ElideRight
            width: Math.min(190, implicitWidth)
        }
    }

    Timer {
        interval: 2200 + (root.cellIndex % 7) * 260
        running: root.enterOpacity === 1 && !root.idlePaused && !mouse.containsMouse
        repeat: true
        triggeredOnStart: false
        onTriggered: bobAnim.restart()
    }

    SequentialAnimation {
        id: bobAnim
        NumberAnimation { target: root; property: "bobY"; to: -2; duration: theme && theme.reducedMotion ? Math.round(800 / 2) : 800; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "bobY"; to: 0; duration: theme && theme.reducedMotion ? Math.round(900 / 2) : 900; easing.type: Easing.InOutSine }
    }

    SequentialAnimation {
        id: idleSpin
        property real progress: 0
        running: root.enterOpacity === 1 && !root.compact && !root.idlePaused && !mouse.containsMouse && root.cellIndex % 19 === 0
        loops: Animation.Infinite
        PauseAnimation { duration: theme && theme.reducedMotion ? Math.round(8000 / 2) : 8000 }
        NumberAnimation { target: idleSpin; property: "progress"; from: 0; to: 1; duration: theme && theme.reducedMotion ? Math.round(600 / 2) : 600; easing.type: Easing.OutExpo }
        ScriptAction { script: idleSpin.progress = 0 }
    }

    ParallelAnimation {
        id: rippleAnim
        NumberAnimation { target: ripple; property: "opacity"; from: 0.3; to: 0; duration: theme && theme.reducedMotion ? Math.round(350 / 2) : 350; easing.type: Easing.OutCubic }
        NumberAnimation { target: ripple; property: "scale"; from: 0.25; to: 3; duration: theme && theme.reducedMotion ? Math.round(350 / 2) : 350; easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        id: chooseAnim
        ParallelAnimation {
            SequentialAnimation {
                NumberAnimation { target: flood; property: "opacity"; to: 0.4; duration: theme && theme.reducedMotion ? Math.round(100 / 2) : 100; easing.type: Easing.OutCubic }
                NumberAnimation { target: flood; property: "opacity"; to: 0; duration: theme && theme.reducedMotion ? Math.round(300 / 2) : 300; easing.type: Easing.OutCubic }
            }
            NumberAnimation { target: root; property: "launchScale"; to: 1.8; duration: theme && theme.reducedMotion ? Math.round(300 / 2) : 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "launchY"; to: -20; duration: theme && theme.reducedMotion ? Math.round(300 / 2) : 300; easing.type: Easing.OutCubic }
        }
        ScriptAction { script: root.chosen() }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onPressed: function(ev) {
            root.rippleX = ev.x
            root.rippleY = ev.y
            rippleAnim.restart()
        }
        onClicked: {
            root.launching = true
            chooseAnim.restart()
        }
    }
}

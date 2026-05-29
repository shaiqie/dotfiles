import QtQuick

Rectangle {
    id: root

    default property alias contentData: contentHost.data

    property var theme
    property bool expanded: false
    property bool contentReady: false
    property real panelY: 0
    property real scaleOriginX: width / 2
    property real scaleOriginY: 0
    property real scaleValue: 0.92
    property real panelOpacity: 0
    property real motionYOffset: -8
    property real contentOpacity: 0
    property real contentYOffset: 6
    property bool hasOpened: false

    signal enterFinished()
    signal exitFinished()

    y: panelY + motionYOffset
    radius: theme ? theme.panelRadius : 20
    color: theme ? theme.surface(0) : "transparent"
    border.width: theme && theme.outerBorder ? theme.borderWidth : 0
    border.color: theme ? theme.withAlpha(theme.gradientBorder ? theme.color4 : theme.color1, theme.borderOpacity) : "transparent"
    opacity: panelOpacity
    clip: true
    antialiasing: true
    transform: Scale {
        origin.x: root.scaleOriginX
        origin.y: root.scaleOriginY
        xScale: root.scaleValue
        yScale: root.scaleValue
    }

    onExpandedChanged: {
        if (expanded)
            openAnim.restart()
        else if (hasOpened)
            closeAnim.restart()
    }

    onContentReadyChanged: {
        if (contentReady)
            contentIn.restart()
        else
            contentOut.restart()
    }

    function resetEntrance() {
        openAnim.stop()
        closeAnim.stop()
        contentIn.stop()
        contentOut.stop()
        hasOpened = false
        scaleValue = 0.92
        panelOpacity = 0
        motionYOffset = -8
        contentOpacity = 0
        contentYOffset = 6
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        antialiasing: true
        color: root.theme ? root.theme.withAlpha(root.theme.mix(root.theme.color0, root.theme.background, root.theme.frostedGlass && root.theme.enableBlur ? Math.max(0.02, 0.12 - root.theme.blurStrength * 0.10) : 0.12), root.theme.panelOpacity) : "transparent"
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * 0.24
        radius: root.radius
        color: root.theme ? root.theme.withAlpha(root.theme.background, root.theme.enableShadows ? root.theme.shadowOpacity * 0.18 : 0) : "transparent"
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        radius: root.radius
        color: root.theme && root.theme.enableGlow ? root.theme.withAlpha(root.theme.foreground, 0.08) : "transparent"
    }

    Rectangle {
        width: parent.width * 0.72
        height: 120
        x: root.scaleOriginX - width / 2
        y: -70
        radius: height / 2
        color: root.theme && root.theme.enableGlow ? root.theme.withAlpha(root.theme.color4, root.expanded ? 0.07 : 0) : "transparent"
        Behavior on color { ColorAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 220; easing.type: Easing.OutCubic } }
    }

    Item {
        id: contentHost
        anchors.fill: parent
        opacity: root.contentOpacity
        transform: Translate { y: root.contentYOffset }
    }

    ParallelAnimation {
        id: openAnim
        PropertyAction { target: root; property: "hasOpened"; value: true }
        SpringAnimation { target: root; property: "scaleValue"; from: 0.92; to: 1.0; spring: root.theme ? root.theme.springStrength : 4.5; damping: root.theme ? root.theme.springDamping : 0.72; mass: 0.9; epsilon: 0.001; duration: root.theme ? root.theme.motionDuration(320) : 320 }
        SpringAnimation { target: root; property: "motionYOffset"; from: -8; to: 0; spring: root.theme ? root.theme.springStrength : 4.5; damping: root.theme ? root.theme.springDamping : 0.72; mass: 0.9; epsilon: 0.001; duration: root.theme ? root.theme.motionDuration(320) : 320 }
        NumberAnimation { target: root; property: "panelOpacity"; from: 0; to: 1; duration: root.theme ? root.theme.motionDuration(220) : 220; easing.type: Easing.OutCubic }
        onStopped: root.enterFinished()
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation { target: root; property: "contentOpacity"; to: 0; duration: root.theme ? root.theme.motionDuration(120) : 120; easing.type: Easing.InCubic }
        NumberAnimation { target: root; property: "contentYOffset"; to: 6; duration: root.theme ? root.theme.motionDuration(120) : 120; easing.type: Easing.InCubic }
        NumberAnimation { target: root; property: "scaleValue"; to: 0.94; duration: root.theme ? root.theme.motionDuration(180) : 180; easing.type: Easing.InCubic }
        NumberAnimation { target: root; property: "motionYOffset"; to: -6; duration: root.theme ? root.theme.motionDuration(180) : 180; easing.type: Easing.InCubic }
        NumberAnimation { target: root; property: "panelOpacity"; to: 0; duration: root.theme ? root.theme.motionDuration(180) : 180; easing.type: Easing.InCubic }
        onStopped: {
            root.hasOpened = false
            root.exitFinished()
        }
    }

    SequentialAnimation {
        id: contentIn
        PauseAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 20 }
        ParallelAnimation {
            NumberAnimation { target: root; property: "contentOpacity"; to: 1; duration: root.theme ? root.theme.motionDuration(170) : 170; easing.type: Easing.OutCubic }
            SpringAnimation { target: root; property: "contentYOffset"; to: 0; spring: root.theme ? root.theme.springStrength : 4.4; damping: root.theme ? root.theme.springDamping : 0.78; mass: 0.9; epsilon: 0.001; duration: root.theme ? root.theme.motionDuration(260) : 260 }
        }
    }

    ParallelAnimation {
        id: contentOut
        NumberAnimation { target: root; property: "contentOpacity"; to: 0; duration: root.theme ? root.theme.motionDuration(120) : 120; easing.type: Easing.InCubic }
        NumberAnimation { target: root; property: "contentYOffset"; to: 6; duration: root.theme ? root.theme.motionDuration(120) : 120; easing.type: Easing.InCubic }
    }
}

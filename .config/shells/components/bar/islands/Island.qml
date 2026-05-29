import QtQuick

Item {
    id: root

    property var theme
    property int paddingX: theme ? theme.islandPadding : 15
    property int paddingY: 4
    property int spacing: 0
    property int pulseToken: 0
    property bool pulseCritical: false
    property real pulseScale: 1
    property bool expandedHover: hover.hovered
    property real hoverStretch: expandedHover ? ((root.baseWidth + (theme && theme.islandHoverGlow ? 6 : 0)) / Math.max(1, root.baseWidth)) : 1
    readonly property real baseWidth: row.implicitWidth + paddingX * 2
    default property alias content: row.data

    implicitWidth: baseWidth
    implicitHeight: 36 + (expandedHover && theme && theme.islandHoverGlow ? 2 : 0)
    width: implicitWidth
    height: implicitHeight
    y: expandedHover && theme && theme.islandHoverLift ? -2 : 0
    transform: Scale {
        origin.x: root.width / 2
        origin.y: root.height / 2
        xScale: root.pulseScale * root.hoverStretch * (expandedHover && root.theme ? root.theme.islandHoverScale : 1)
        yScale: root.pulseScale * (expandedHover && root.theme ? root.theme.islandHoverScale : 1)
    }

    HoverHandler { id: hover }

    onPulseTokenChanged: pulseAnim.restart()

    SequentialAnimation {
        id: pulseAnim
        SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  target: root; property: "pulseScale"; to: 1.03; spring: 5.0; damping: 0.70; mass: 0.9; epsilon: 0.001 }
        SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  target: root; property: "pulseScale"; to: 1.0; spring: 5.0; damping: 0.75; mass: 0.9; epsilon: 0.001 }
    }

    Behavior on y { SpringAnimation { duration: theme ? theme.motionDuration(250) : 250; spring: theme ? theme.springStrength : 5.0; damping: theme ? theme.springDamping : 0.75; mass: 0.9; epsilon: 0.001 } }
    Behavior on hoverStretch { SpringAnimation { duration: theme ? theme.motionDuration(250) : 250; spring: theme ? theme.springStrength : 5.0; damping: theme ? theme.springDamping : 0.75; mass: 0.9; epsilon: 0.001 } }
    Behavior on width { SpringAnimation { duration: theme ? theme.motionDuration(250) : 250; spring: theme ? theme.springStrength : 4.8; damping: theme ? theme.springDamping : 0.74; mass: 0.9; epsilon: 0.001 } }
    Behavior on height { SpringAnimation { duration: theme ? theme.motionDuration(250) : 250; spring: theme ? theme.springStrength : 4.8; damping: theme ? theme.springDamping : 0.74; mass: 0.9; epsilon: 0.001 } }

    Rectangle {
        anchors.fill: parent
        radius: root.theme ? root.theme.pillRadius : height / 2
        color: pulseAnim.running && root.pulseCritical
            ? root.theme.withAlpha(root.theme.color1, 0.22)
            : root.theme.withAlpha(root.theme.color4, expandedHover && root.theme.islandHoverGlow ? 0.12 : 0.04)
        opacity: (expandedHover && root.theme.islandHoverGlow) || pulseAnim.running ? 1 : 0.7
        scale: expandedHover ? 1.035 : 1.0

        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.75; mass: 0.9; epsilon: 0.001 } }
        Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.theme ? root.theme.pillRadius : height / 2
        visible: root.theme.outerBorder && root.theme.gradientBorder
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root.theme.color4 }
            GradientStop { position: 1.0; color: root.theme.color6 }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.theme.outerBorder && root.theme.gradientBorder ? root.theme.borderWidth : 0
        radius: root.theme ? root.theme.pillRadius : height / 2
        color: root.theme.withAlpha(expandedHover && root.theme.islandHoverGlow ? root.theme.mix(root.theme.color0, root.theme.color1, 0.10) : root.theme.color0, root.theme.panelOpacity)
        border.width: root.theme.outerBorder && !root.theme.gradientBorder ? root.theme.borderWidth : 0
        border.color: root.theme.withAlpha(root.theme.gradientBorder ? root.theme.color4 : root.theme.color1, root.theme.borderOpacity)

        Behavior on border.color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(240 / 2) : 240; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(220 / 2) : 220; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        width: hover.hovered && root.theme.islandHoverGlow ? parent.width - 30 : 0
        height: 1
        radius: 1
        color: root.theme.color1

        Behavior on width { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(240 / 2) : 240; easing.type: Easing.OutCubic } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: root.spacing
    }
}

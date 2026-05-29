import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

Item {
    id: root

    property var theme
    property string icon
    property string iconSource: ""
    property string label
    property string sublabel: ""
    property bool isActive: false
    property bool active: isActive
    property bool danger: false
    property int delay: 0
    property int motionToken: 0
    property bool appeared: false
    property bool hovered: area.containsMouse
    property real pressDepth: area.pressed ? 0.96 : 1
    property real contentX: appeared ? 0 : 10
    property real statusWidth: isActive ? 34 : 8
    property real sweepX: -0.3
    property real liveScale: 1

    signal clicked()

    Layout.fillWidth: true
    Layout.preferredHeight: 64
    Layout.minimumHeight: 64
    Layout.maximumHeight: 64
    implicitWidth: 120
    implicitHeight: 64

    opacity: appeared ? 1 : 0
    scale: pressDepth * liveScale

    Behavior on opacity {
        SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 260; spring: 4.8; damping: 0.86; mass: 0.9; epsilon: 0.001 }
    }

    Behavior on scale {
        SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 240; spring: 5.4; damping: 0.78; mass: 0.9; epsilon: 0.001 }
    }

    Behavior on contentX {
        SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 280; spring: 4.8; damping: 0.84; mass: 0.9; epsilon: 0.001 }
    }

    Behavior on statusWidth {
        SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 300; spring: 4.8; damping: 0.82; mass: 0.9; epsilon: 0.001 }
    }

    Timer {
        id: appearTimer
        interval: root.delay
        repeat: false
        onTriggered: root.appeared = true
    }

    Component.onCompleted: appearTimer.restart()

    onMotionTokenChanged: {
        appeared = false
        appearTimer.restart()
        statePulse.restart()
    }

    onIsActiveChanged: statePulse.restart()

    SequentialAnimation on liveScale {
        running: root.isActive && !root.hovered && !(root.theme && root.theme.reducedMotion)
        loops: Animation.Infinite
        NumberAnimation { to: 1.012; duration: 1700; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: 1700; easing.type: Easing.InOutSine }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.isActive ? -5 : 0
        radius: surface.radius + 5
        color: root.theme.withAlpha(root.isActive ? root.theme.color4 : root.theme.foreground, root.isActive && root.theme.enableGlow ? 0.10 : 0)
        opacity: root.isActive && root.theme.enableGlow ? 1 : 0

        Behavior on opacity { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 320; spring: 4.4; damping: 0.88; mass: 0.9; epsilon: 0.001 } }
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: root.theme.itemRadius
        color: root.isActive
            ? root.theme.withAlpha(root.theme.color4, root.hovered ? 0.16 : 0.10)
            : root.theme.withAlpha(root.theme.foreground, root.hovered ? 0.065 : 0.038)
        border.width: root.theme.outerBorder ? root.theme.borderWidth : 0
        border.color: root.isActive
            ? root.theme.withAlpha(root.theme.gradientBorder ? root.theme.color6 : root.theme.color4, root.hovered ? 0.36 : 0.24)
            : root.theme.withAlpha(root.theme.gradientBorder ? root.theme.color4 : root.theme.color1, root.hovered ? 0.26 : 0.15)
        antialiasing: true
        clip: true

        Behavior on color { ColorAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic } }

        Rectangle {
            width: 34
            height: parent.height * 1.7
            x: parent.width * root.sweepX
            y: -parent.height * 0.32
            rotation: 18
            color: root.theme.withAlpha(root.theme.foreground, 0.040)
            opacity: root.hovered || root.isActive ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }
        }
    }

    NumberAnimation on sweepX {
        running: root.hovered || root.isActive
        loops: Animation.Infinite
        from: -0.35
        to: 1.08
        duration: root.theme && root.theme.reducedMotion ? 0 : 1800
        easing.type: Easing.InOutSine
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: 12 + root.contentX
        anchors.rightMargin: 12

        Rectangle {
            id: iconPlate
            width: 34
            height: 34
            radius: root.theme.controlRadius
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: root.theme.withAlpha(root.isActive ? root.theme.color4 : root.theme.color1, root.isActive ? 0.20 : 0.10)
            scale: root.hovered ? 1.04 : 1
            rotation: root.hovered ? -2 : 0

            Behavior on scale { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 260; spring: 5.2; damping: 0.80; mass: 0.9; epsilon: 0.001 } }
            Behavior on rotation { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 260; spring: 5.0; damping: 0.76; mass: 0.9; epsilon: 0.001 } }
            Behavior on color { ColorAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic } }

            Text {
                id: iconText
                visible: root.iconSource.length === 0
                anchors.centerIn: parent
                text: root.icon
                color: root.isActive ? root.theme.color4 : root.theme.withAlpha(root.theme.foreground, 0.74)
                font.family: root.theme.fontFamily
                font.pixelSize: 17 * root.theme.fontScale
                scale: root.hovered ? 1.08 : 1

                Behavior on scale { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 260; spring: 5.6; damping: 0.76; mass: 0.9; epsilon: 0.001 } }
                Behavior on color { ColorAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic } }
            }

            Image {
                id: tileIconSource
                visible: false
                anchors.centerIn: parent
                width: 20
                height: 20
                source: root.iconSource
                sourceSize.width: width
                sourceSize.height: height
                smooth: true
                mipmap: true
                scale: root.hovered ? 1.08 : 1

                Behavior on scale { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 260; spring: 5.6; damping: 0.76; mass: 0.9; epsilon: 0.001 } }
            }

            MultiEffect {
                visible: root.iconSource.length > 0
                anchors.fill: tileIconSource
                source: tileIconSource
                colorization: 1
                colorizationColor: root.isActive ? root.theme.color4 : root.theme.withAlpha(root.theme.foreground, 0.74)

                Behavior on colorizationColor { ColorAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic } }
            }
        }

        Column {
            anchors.left: iconPlate.right
            anchors.leftMargin: 10
            anchors.right: stateBadge.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: root.label
                color: root.theme.foreground
                font.family: root.theme.fontFamily
                font.pixelSize: 12 * root.theme.fontScale
                font.bold: root.isActive
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.sublabel.length > 0 ? root.sublabel : (root.isActive ? "On" : "Ready")
                color: root.theme.withAlpha(root.theme.foreground, 0.48)
                font.family: root.theme.fontFamily
                font.pixelSize: 9 * root.theme.fontScale
                elide: Text.ElideRight
            }
        }

        Rectangle {
            id: stateBadge
            width: root.statusWidth
            height: 20
            radius: root.theme.microRadius
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: root.isActive ? root.theme.withAlpha(root.theme.color4, 0.18) : root.theme.withAlpha(root.theme.foreground, 0.10)
            clip: true

            Behavior on color { ColorAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic } }

            Text {
                anchors.centerIn: parent
                text: root.isActive ? "ON" : ""
                color: root.theme.color4
                font.family: root.theme.fontFamily
                font.pixelSize: 8 * root.theme.fontScale
                font.bold: true
                opacity: root.isActive ? 1 : 0
            }
        }
    }

    SequentialAnimation {
        id: statePulse
        SpringAnimation { target: iconPlate; property: "scale"; to: 1.10; duration: root.theme && root.theme.reducedMotion ? 0 : 180; spring: 5.6; damping: 0.68; mass: 0.9; epsilon: 0.001 }
        SpringAnimation { target: iconPlate; property: "scale"; to: 1.0; duration: root.theme && root.theme.reducedMotion ? 0 : 240; spring: 5.2; damping: 0.82; mass: 0.9; epsilon: 0.001 }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

import QtQuick

Item {
    id: root

    property var theme
    property string text
    property bool outlined: false
    property bool danger: false
    property bool hovered: area.containsMouse
    property bool pressed: area.pressed
    property real sweepX: -0.25

    signal clicked()

    width: 112
    height: 40
    scale: pressed ? 0.965 : (hovered ? 1.025 : 1)
    opacity: hovered ? 1 : 0.96

    Behavior on scale { SpringAnimation { duration: theme ? theme.motionDuration(260) : 260; spring: theme ? theme.springStrength : 5.0; damping: theme ? theme.springDamping : 0.82; mass: 0.85; epsilon: 0.001 } }
    Behavior on opacity { SpringAnimation { duration: theme ? theme.motionDuration(220) : 220; spring: theme ? theme.springStrength : 5.0; damping: theme ? theme.springDamping : 0.88; mass: 0.8; epsilon: 0.001 } }

    Rectangle {
        anchors.fill: body
        anchors.margins: hovered ? -6 : 0
        radius: body.radius + 5
        color: theme.withAlpha(danger ? theme.color1 : theme.color4, hovered ? 0.13 : 0)
    }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: theme.controlRadius
        color: danger
            ? theme.withAlpha(theme.color1, hovered ? 0.22 : 0.12)
            : (outlined ? theme.withAlpha(theme.foreground, hovered ? 0.075 : 0.035) : theme.withAlpha(theme.color4, hovered ? 0.18 : 0.115))
        clip: true

        Rectangle {
            width: 3
            height: parent.height - 16
            radius: 2
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            color: root.danger ? root.theme.color1 : root.theme.color4
            opacity: root.outlined ? (root.hovered ? 0.9 : 0.45) : 0.9
        }

        Rectangle {
            width: parent.width * (root.hovered ? 1 : 0)
            height: parent.height
            color: root.theme.withAlpha(root.danger ? root.theme.color1 : root.theme.color4, 0.08)
            Behavior on width { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 260; spring: 4.7; damping: 0.84; mass: 0.85; epsilon: 0.001 } }
        }
        Rectangle {
            width: 26
            height: parent.height * 1.7
            x: parent.width * root.sweepX
            y: -parent.height * 0.35
            rotation: 18
            color: root.theme.withAlpha(root.theme.foreground, 0.045)
            opacity: root.hovered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.theme.reducedMotion ? 0 : 140; easing.type: Easing.OutCubic } }
        }
        Behavior on color { ColorAnimation { duration: root.theme.reducedMotion ? 0 : 150; easing.type: Easing.OutCubic } }
    }

    NumberAnimation on sweepX {
        running: root.hovered
        loops: Animation.Infinite
        from: -0.25
        to: 1.12
        duration: root.theme && root.theme.reducedMotion ? 0 : 1400
        easing.type: Easing.InOutSine
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 20
        width: parent.width - 28
        text: root.text
        color: root.theme.foreground
        font.family: root.theme.fontFamily
        font.pixelSize: 12 * root.theme.fontScale
        font.bold: root.theme.fontBold || true
        elide: Text.ElideRight
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

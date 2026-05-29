import QtQuick

Item {
    id: root

    property var theme
    property string text
    property bool hovered: area.containsMouse

    signal clicked()

    width: 92
    height: 38
    scale: area.pressed ? 0.96 : (hovered ? 1.018 : 1)
    opacity: hovered ? 1 : 0.94

    Behavior on scale { SpringAnimation { duration: theme ? theme.motionDuration(260) : 260; spring: theme ? theme.springStrength : 5.0; damping: theme ? theme.springDamping : 0.82; mass: 0.85; epsilon: 0.001 } }
    Behavior on opacity { SpringAnimation { duration: theme ? theme.motionDuration(220) : 220; spring: theme ? theme.springStrength : 5.0; damping: theme ? theme.springDamping : 0.88; mass: 0.8; epsilon: 0.001 } }

    Rectangle {
        anchors.fill: plate
        anchors.margins: root.hovered ? -4 : 0
        radius: plate.radius + 4
        color: root.theme ? root.theme.withAlpha(root.theme.color4, root.hovered ? 0.10 : 0) : "transparent"
    }

    Rectangle {
        id: plate
        anchors.fill: parent
        radius: root.theme ? root.theme.controlRadius : 10
        color: root.theme ? root.theme.withAlpha(root.hovered ? root.theme.color4 : root.theme.foreground, root.hovered ? 0.14 : 0.055) : "transparent"

        Behavior on color { ColorAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }
    }

    Row {
        anchors.centerIn: parent
        spacing: 8

        Rectangle {
            width: 5
            height: 5
            radius: 3
            anchors.verticalCenter: parent.verticalCenter
            color: root.theme ? root.theme.color4 : "white"
            opacity: root.hovered ? 1 : 0.55
        }

        Text {
            text: root.text
            color: root.theme ? root.theme.foreground : "white"
            font.family: root.theme ? root.theme.fontFamily : "Adwaita Sans"
            font.pixelSize: 12 * (root.theme ? root.theme.fontScale : 1)
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

import QtQuick

Item {
    id: root

    property bool checked: false
    property var theme
    property color primary: theme ? theme.color4 : "white"
    property bool hovered: area.containsMouse

    signal toggled()

    width: 50
    height: 28
    scale: area.pressed ? 0.96 : 1

    Behavior on scale { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 240; spring: 5.2; damping: 0.82; mass: 0.85; epsilon: 0.001 } }

    Rectangle {
        anchors.fill: rail
        anchors.margins: root.checked ? -5 : 0
        radius: rail.radius + 5
        color: root.theme ? root.theme.withAlpha(root.primary, root.checked ? 0.13 : 0) : "transparent"

        Behavior on color { ColorAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 220; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        id: rail
        anchors.fill: parent
        radius: root.theme ? root.theme.controlRadius : 10
        color: root.theme ? (root.checked ? root.theme.withAlpha(root.primary, 0.18) : root.theme.withAlpha(root.theme.foreground, root.hovered ? 0.075 : 0.050)) : "transparent"
        clip: true

        Behavior on color { ColorAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic } }

        Rectangle {
            width: root.checked ? 18 : 7
            height: 18
            radius: root.theme ? root.theme.microRadius : 5
            x: root.checked ? parent.width - width - 5 : 6
            anchors.verticalCenter: parent.verticalCenter
            color: root.checked ? root.primary : root.theme.withAlpha(root.theme.foreground, 0.55)

            Behavior on x { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 260; spring: 4.8; damping: 0.80; mass: 0.85; epsilon: 0.001 } }
            Behavior on width { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 260; spring: 4.8; damping: 0.80; mass: 0.85; epsilon: 0.001 } }
            Behavior on color { ColorAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.checked ? "1" : "0"
        color: root.theme ? root.theme.withAlpha(root.theme.foreground, root.checked ? 0.55 : 0.28) : "white"
        font.family: root.theme ? root.theme.fontFamily : "Adwaita Sans"
        font.pixelSize: 8 * (root.theme ? root.theme.fontScale : 1)
        font.bold: true
        opacity: root.hovered ? 1 : 0

        Behavior on opacity { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 220; spring: 5.0; damping: 0.88; mass: 0.85; epsilon: 0.001 } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.checked = !root.checked
            root.toggled()
        }
    }
}

import QtQuick

Rectangle {
    id: root

    property var theme
    property string text
    signal clicked()

    height: 30
    width: label.implicitWidth + 24
    radius: theme.controlRadius
    color: area.containsMouse ? theme.withAlpha(theme.color4, 0.08) : "transparent"
    border.width: theme.outerBorder ? theme.borderWidth : 0
    border.color: area.containsMouse ? theme.withAlpha(theme.color4, 0.26) : theme.withAlpha(theme.color1, 0.18)
    scale: area.pressed ? 0.96 : (area.containsMouse ? 1.015 : 1)
    opacity: area.containsMouse ? 1 : 0.90

    Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.6; damping: 0.72; mass: 0.9; epsilon: 0.001 } }
    Behavior on opacity { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 220; spring: 5.2; damping: 0.86; mass: 0.8; epsilon: 0.001 } }
    Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(110 / 2) : 110; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(130 / 2) : 130; easing.type: Easing.OutCubic } }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.theme.foreground
        font.family: root.theme.fontFamily
        font.pixelSize: 12 * root.theme.fontScale
        font.bold: true
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

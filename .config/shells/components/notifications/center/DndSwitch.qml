import QtQuick

Rectangle {
    id: root

    property var theme
    property bool checked: false
    property bool isDND: checked
    signal toggled(bool checked)

    onCheckedChanged: isDND = checked

    width: 50
    height: 28
    radius: theme.controlRadius
    color: isDND ? theme.withAlpha(theme.color4, 0.22) : theme.withAlpha(theme.foreground, 0.055)
    border.width: theme.outerBorder ? theme.borderWidth : 0
    border.color: isDND ? theme.withAlpha(theme.color4, 0.42) : theme.withAlpha(theme.color1, 0.28)
    scale: area.pressed ? 0.97 : 1

    Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(150 / 2) : 150; easing.type: Easing.OutCubic } }
    Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.7; damping: 0.72; mass: 0.9; epsilon: 0.001 } }

    Rectangle {
        width: area.pressed ? 22 : 18
        height: 18
        radius: root.theme.microRadius
        readonly property real offPosition: 5
        readonly property real onPosition: parent.width - width - 5
        x: root.isDND ? onPosition : offPosition
        anchors.verticalCenter: parent.verticalCenter
        color: root.isDND ? theme.color4 : theme.withAlpha(theme.foreground, 0.74)

        Behavior on x { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.5; damping: 0.72; mass: 0.9; epsilon: 0.001 } }
        Behavior on width { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.5; damping: 0.72; mass: 0.9; epsilon: 0.001 } }
    }

    MouseArea {
        id: area
        z: 10
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        propagateComposedEvents: false
        onClicked: {
            root.isDND = !root.isDND
            root.toggled(root.isDND)
        }
    }
}

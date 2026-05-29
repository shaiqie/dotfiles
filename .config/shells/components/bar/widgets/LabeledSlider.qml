import QtQuick

Item {
    id: root

    property var theme
    property string label
    property real value: 0
    property real minValue: 0
    property real maxValue: 150
    property bool dragging: area.pressed
    readonly property real progress: Math.max(0, Math.min(1, (value - minValue) / Math.max(0.001, maxValue - minValue)))

    signal moved()

    width: parent ? parent.width : 340
    height: 58
    opacity: enabled ? 1 : 0.42

    Behavior on opacity { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 240; spring: 5.0; damping: 0.88; mass: 0.9; epsilon: 0.001 } }

    Text {
        id: valueText
        anchors.right: parent.right
        anchors.top: parent.top
        text: Math.round(root.value) + "%"
        color: root.theme.foreground
        font.family: root.theme.fontFamily
        font.pixelSize: 22 * root.theme.fontScale
        font.bold: true
    }

    Text {
        anchors.left: parent.left
        anchors.right: valueText.left
        anchors.rightMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 7
        text: root.label.toUpperCase()
        color: root.theme.withAlpha(root.theme.foreground, 0.48)
        font.family: root.theme.fontFamily
        font.pixelSize: 9 * root.theme.fontScale
        font.bold: true
        elide: Text.ElideRight
    }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.dragging ? 12 : 8
        radius: 4
        color: root.theme.withAlpha(root.theme.foreground, 0.075)
        clip: true

        Behavior on height { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 240; spring: 5.2; damping: 0.84; mass: 0.85; epsilon: 0.001 } }

        Rectangle {
            width: Math.max(parent.height, parent.width * root.progress)
            height: parent.height
            radius: parent.radius
            color: root.theme.withAlpha(root.theme.color4, root.dragging ? 0.95 : 0.76)
            Behavior on width { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 240; spring: 4.8; damping: 0.86; mass: 0.8; epsilon: 0.001 } }
            Behavior on color { ColorAnimation { duration: root.theme.reducedMotion ? 0 : 150; easing.type: Easing.OutCubic } }
        }

        Rectangle {
            width: 2
            height: parent.height
            x: Math.max(0, Math.min(parent.width - width, parent.width * root.progress))
            color: root.theme.foreground
            opacity: root.dragging ? 1 : 0
            Behavior on x { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 240; spring: 5.0; damping: 0.86; mass: 0.8; epsilon: 0.001 } }
            Behavior on opacity { NumberAnimation { duration: root.theme.reducedMotion ? 0 : 120; easing.type: Easing.OutCubic } }
        }
    }

    MouseArea {
        id: area
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 32
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function update(mouseX) {
            const pct = Math.max(0, Math.min(1, mouseX / track.width))
            root.value = root.minValue + pct * (root.maxValue - root.minValue)
            root.moved()
        }

        onPressed: function(mouse) { update(mouse.x) }
        onPositionChanged: function(mouse) { if (pressed) update(mouse.x) }
    }
}

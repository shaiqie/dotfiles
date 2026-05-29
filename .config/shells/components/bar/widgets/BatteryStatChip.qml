import QtQuick

Item {
    id: root

    property var theme
    property string icon
    property string value
    property string label
    property int motionToken: 0
    property int stagger: 0
    property bool active: true
    property bool hovered: area.containsMouse
    property real contentOffset: 8
    property real sweepX: -0.28

    height: 58
    opacity: active ? 1 : 0
    scale: area.pressed ? 0.965 : (hovered ? 1.025 : 1)

    onMotionTokenChanged: startEntry()
    onActiveChanged: if (active) startEntry()

    Behavior on scale { SpringAnimation { duration: theme ? theme.motionDuration(260) : 260; spring: theme ? theme.springStrength : 5.0; damping: theme ? theme.springDamping : 0.84; mass: 0.85; epsilon: 0.001 } }
    Behavior on opacity { SpringAnimation { duration: theme ? theme.motionDuration(240) : 240; spring: theme ? theme.springStrength : 5.0; damping: theme ? theme.springDamping : 0.88; mass: 0.9; epsilon: 0.001 } }
    Behavior on contentOffset { SpringAnimation { duration: theme ? theme.motionDuration(260) : 260; spring: theme ? theme.springStrength : 4.8; damping: theme ? theme.springDamping : 0.84; mass: 0.9; epsilon: 0.001 } }

    Timer {
        id: entryDelay
        interval: root.stagger
        repeat: false
        onTriggered: {
            root.opacity = 1
            root.contentOffset = 0
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.theme.itemRadius
        color: root.theme.withAlpha(root.hovered ? root.theme.color4 : root.theme.foreground, root.hovered ? 0.105 : 0.045)
        clip: true

        Rectangle {
            width: 3
            height: parent.height - 18
            radius: 2
            x: 9
            anchors.verticalCenter: parent.verticalCenter
            color: root.theme.color4
            opacity: root.hovered ? 1 : 0.55
        }

        Rectangle {
            width: parent.width * (root.hovered ? 1 : 0)
            height: parent.height
            color: root.theme.withAlpha(root.theme.color4, 0.055)
            Behavior on width { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 260; spring: 4.8; damping: 0.84; mass: 0.85; epsilon: 0.001 } }
        }

        Rectangle {
            width: 30
            height: parent.height * 1.6
            x: parent.width * root.sweepX
            y: -parent.height * 0.3
            rotation: 18
            color: root.theme.withAlpha(root.theme.foreground, 0.040)
            opacity: root.hovered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.theme.reducedMotion ? 0 : 150; easing.type: Easing.OutCubic } }
        }
    }

    NumberAnimation on sweepX {
        running: root.hovered
        loops: Animation.Infinite
        from: -0.28
        to: 1.10
        duration: root.theme && root.theme.reducedMotion ? 0 : 1500
        easing.type: Easing.InOutSine
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 10
        spacing: root.theme.itemSpacing - 2
        y: root.contentOffset

        Text {
            width: 16
            text: root.icon
            color: root.theme.color4
            font.family: root.theme.fontFamily
            font.pixelSize: 14 * root.theme.fontScale
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
        }

        Column {
            width: parent.width - 24
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.max(1, root.theme.itemSpacing - 8)

            Text {
                width: parent.width
                text: root.label.toUpperCase()
                color: root.theme.withAlpha(root.theme.foreground, 0.44)
                font.family: root.theme.fontFamily
                font.pixelSize: 8 * root.theme.fontScale
                font.bold: true
                font.letterSpacing: 0
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.value
                color: root.theme.foreground
                font.family: root.theme.fontFamily
                font.pixelSize: 14 * root.theme.fontScale
                font.bold: root.theme.fontBold || true
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
    }

    function startEntry() {
        opacity = 0
        contentOffset = 8
        entryDelay.restart()
    }
}

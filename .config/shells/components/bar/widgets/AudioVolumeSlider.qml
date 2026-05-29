import QtQuick
import QtQuick.Effects

Column {
    id: root

    property var theme
    property string label
    property string icon
    property string mutedIcon
    property string iconSource: ""
    property string mutedIconSource: ""
    property real value: 0
    property bool muted: false
    property bool hovered: dragArea.containsMouse || muteArea.containsMouse
    property bool dragging: dragArea.pressed
    property bool flash: false
    property bool showHeader: true
    property bool percentInTrack: false
    property int trackBaseHeight: 34
    property int trackHoverHeight: 38
    property int trackDragHeight: 42
    property int lastBucket: Math.floor(normalizedValue / 10)
    readonly property real normalizedValue: Math.max(0, Math.min(100, value))
    readonly property bool isOff: muted || normalizedValue <= 0
    readonly property string currentIconSource: root.isOff ? root.mutedIconSource : root.iconSource

    signal volumeMoved(real value)
    signal muteClicked()

    width: parent ? parent.width : 360
    spacing: Math.max(4, theme ? theme.itemSpacing - 3 : 7)

    onNormalizedValueChanged: {
        const bucket = Math.floor(normalizedValue / 10)
        if (bucket !== lastBucket) {
            lastBucket = bucket
            flashAnim.restart()
        }
    }

    SequentialAnimation {
        id: flashAnim
        PropertyAction { target: root; property: "flash"; value: true }
        PauseAnimation { duration: theme && theme.reducedMotion ? Math.round(75 / 2) : 75 }
        PropertyAction { target: root; property: "flash"; value: false }
    }

    Row {
        width: parent.width
        height: root.showHeader ? 24 : 0
        visible: root.showHeader

        Text {
            width: parent.width - 72
            text: root.label
            color: root.theme.foreground
            font.family: root.theme.fontFamily
            font.pixelSize: 14 * root.theme.fontScale
            font.bold: root.theme.fontBold || true
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            width: 60
            text: Math.round(root.normalizedValue) + "%"
            color: root.isOff ? root.theme.withAlpha(root.theme.color1, 0.70) : root.theme.color4
            font.family: root.theme.fontFamily
            font.pixelSize: 15 * root.theme.fontScale
            font.bold: root.theme.fontBold || true
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Rectangle {
        id: track

        width: parent.width
        height: root.dragging ? root.trackDragHeight : (root.hovered ? root.trackHoverHeight : root.trackBaseHeight)
        radius: root.theme ? root.theme.controlRadius : 10
        clip: true
        color: root.isOff ? root.theme.withAlpha(root.theme.color1, 0.20) : root.theme.withAlpha(root.theme.color1, root.flash ? 0.24 : 0.12)
        property real stretch: dragArea.pressed ? 1.08 : 1

        Behavior on height { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.75; mass: 0.9; epsilon: 0.001 } }
        Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(150 / 2) : 150; easing.type: Easing.OutCubic } }

        Rectangle {
            width: Math.max(track.height, track.width * (root.normalizedValue / 100))
            height: parent.height
            radius: root.theme ? root.theme.controlRadius : 10
            color: root.isOff ? root.theme.withAlpha(root.theme.foreground, 0.0) : root.theme.withAlpha(root.theme.color4, root.normalizedValue >= 100 ? 0.88 : 0.76)

            Behavior on width { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(80 / 2) : 80; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(150 / 2) : 150; easing.type: Easing.OutCubic } }
        }

        Rectangle {
            id: iconBubble

            z: 2
            width: 26
            height: 26
            radius: root.theme ? root.theme.microRadius : 6
            x: 4
            anchors.verticalCenter: parent.verticalCenter
            color: root.isOff ? root.theme.withAlpha(root.theme.color1, 0.18) : root.theme.withAlpha(root.theme.background, 0.22)
            scale: muteArea.pressed ? 0.94 : (root.normalizedValue >= 100 ? 1.04 : (root.hovered ? 1.08 : 1))
            opacity: muteArea.containsMouse ? 0.88 : 1

            Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.6; damping: 0.72; mass: 0.9; epsilon: 0.001 } }
            Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(110 / 2) : 110; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(150 / 2) : 150; easing.type: Easing.OutCubic } }

            Image {
                id: bubbleIconSource
                anchors.centerIn: parent
                width: 15
                height: 15
                source: root.currentIconSource
                sourceSize.width: width
                sourceSize.height: height
                smooth: true
                mipmap: true
                visible: root.currentIconSource.length > 0 ? false : true
                opacity: root.currentIconSource.length > 0 ? 0 : 1
                rotation: root.dragging && root.label.indexOf("Media") >= 0 ? spin : 0
                scale: root.dragging && root.label.indexOf("Micro") >= 0 ? micPulse : 1
                NumberAnimation on spin { running: root.dragging && root.label.indexOf("Media") >= 0; loops: Animation.Infinite; from: 0; to: 360; duration: theme && theme.reducedMotion ? Math.round(1200 / 2) : 1200 }
                property real spin: 0
                SequentialAnimation on micPulse { running: root.dragging && root.label.indexOf("Micro") >= 0; loops: Animation.Infinite; NumberAnimation { to: 1.15; duration: theme && theme.reducedMotion ? Math.round(260 / 2) : 260; easing.type: Easing.InOutSine } NumberAnimation { to: 1; duration: theme && theme.reducedMotion ? Math.round(260 / 2) : 260; easing.type: Easing.InOutSine } }
                property real micPulse: 1
            }

            MultiEffect {
                anchors.fill: bubbleIconSource
                source: bubbleIconSource
                visible: root.currentIconSource.length > 0
                colorization: 1
                colorizationColor: root.isOff ? root.theme.color1 : root.theme.foreground
            }

            Text {
                anchors.centerIn: parent
                visible: root.currentIconSource.length === 0
                text: root.isOff ? root.mutedIcon : root.icon
                color: root.isOff ? root.theme.color1 : root.theme.foreground
                font.pixelSize: 13
                font.bold: true
            }

            MouseArea {
                id: muteArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.muteClicked()
            }
        }

        Text {
            z: 2
            visible: root.percentInTrack
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.normalizedValue) + "%"
            color: root.isOff ? root.theme.withAlpha(root.theme.color1, 0.70) : root.theme.foreground
            font.pixelSize: 15
            font.bold: true
        }

        MouseArea {
            id: dragArea
            z: 1
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            function updateValue(mouseX) {
                const x = Math.max(0, Math.min(track.width, mouseX))
                root.volumeMoved(Math.round((x / track.width) * 100))
            }

            onPressed: updateValue(mouse.x)
            onPositionChanged: if (pressed) updateValue(mouse.x)
        }

        Rectangle {
            visible: root.hovered
            width: tooltipText.implicitWidth + 16
            height: 24
            radius: 12
            anchors.horizontalCenter: parent.horizontalCenter
            y: -30
            color: root.theme.withAlpha(root.theme.background, 0.92)
            border.width: root.theme.outerBorder ? root.theme.borderWidth : 0
            border.color: root.theme.withAlpha(root.theme.color4, root.theme.borderOpacity)
            opacity: root.hovered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(120 / 2) : 120; easing.type: Easing.OutCubic } }
            Text { id: tooltipText; anchors.centerIn: parent; text: Math.round(root.normalizedValue) + "%"; color: root.theme.foreground; font.family: root.theme.fontFamily; font.pixelSize: 11 * root.theme.fontScale; font.bold: root.theme.fontBold || true }
        }
    }
}

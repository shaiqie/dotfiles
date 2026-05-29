import QtQuick
import QtQuick.Effects
import Quickshell

Item {
    id: root

    property var theme
    property string text: ""
    property string iconSource: ""
    property color baseColor: theme.foreground
    property string command: ""
    property int fontSize: 15
    property int iconSize: fontSize + 2
    property int horizontalPadding: 5
    property bool bold: false
    property string tooltipText: ""
    property bool hovered: area.containsMouse
    property int islandIndex: -1
    property real nudge: 0
    property real rippleX: width / 2
    property real rippleY: height / 2
    property bool flash: false
    property real bobOffset: 0
    readonly property bool hasIconSource: iconSource.length > 0

    signal clicked()
    signal wheelUp()
    signal wheelDown()

    implicitWidth: (hasIconSource ? iconSize + (text.length > 0 ? label.implicitWidth + 6 : 0) : label.implicitWidth) + horizontalPadding * 2
    implicitHeight: 26
    width: implicitWidth
    height: implicitHeight
    y: hovered && theme && theme.islandHoverLift ? -1 : 0

    Behavior on y { SpringAnimation { duration: theme ? theme.motionDuration(260) : 260; spring: theme ? theme.springStrength : 4.8; damping: theme ? theme.springDamping : 0.84; mass: 0.9; epsilon: 0.001 } }
    Behavior on width { SpringAnimation { duration: theme ? theme.motionDuration(260) : 260; spring: theme ? theme.springStrength : 4.8; damping: theme ? theme.springDamping : 0.84; mass: 0.9; epsilon: 0.001 } }

    onHoveredChanged: {
        if (hovered) {
            tooltipDelay.restart()
            if (text === "󰂚" || text === "󰂛")
                bellRing.restart()
        } else {
            tooltipDelay.stop()
            tooltipVisible = false
            tooltip.closeAnimated()
        }
    }

    property bool tooltipVisible: false

    onTooltipTextChanged: {
        if (root.tooltipVisible && root.hovered)
            tooltip.showFor(root, root.tooltipText, QsWindow.window)
    }

    Timer {
        id: tooltipDelay
        interval: 500
        repeat: false
        onTriggered: {
            root.tooltipVisible = root.tooltipText.length > 0 && root.hovered
            if (root.tooltipVisible)
                tooltip.showFor(root, root.tooltipText, QsWindow.window)
        }
    }

    Rectangle {
        id: hoverPill
        anchors.centerIn: parent
        width: parent.width + 4
        height: parent.height
        radius: root.theme ? root.theme.controlRadius : 10
        color: root.theme.withAlpha(root.theme.color4, root.hovered ? (root.flash ? 0.20 : 0.08) : 0)
        border.width: root.hovered && root.theme.outerBorder ? root.theme.borderWidth : 0
        border.color: root.theme.withAlpha(root.theme.color4, 0.28)
        scale: root.hovered ? 1 : 0.92
        opacity: root.hovered ? 1 : 0

        Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic } }
        Behavior on border.width { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(120 / 2) : 120; easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 7.0; damping: 0.6; mass: 0.9; epsilon: 0.001 } }
        Behavior on opacity { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 220; spring: 5.2; damping: 0.86; mass: 0.8; epsilon: 0.001 } }
    }

    Rectangle {
        id: ripple
        x: root.rippleX - width / 2
        y: root.rippleY - height / 2
        width: 20
        height: 20
        radius: 10
        color: root.theme.withAlpha(root.theme.color4, 0.18)
        opacity: 0
        scale: 1
    }

    Text {
        id: label
        visible: !root.hasIconSource || root.text.length > 0
        anchors.centerIn: root.hasIconSource ? undefined : parent
        anchors.verticalCenter: root.hasIconSource ? parent.verticalCenter : undefined
        anchors.left: root.hasIconSource ? svgLabel.right : undefined
        anchors.leftMargin: root.hasIconSource ? 6 : 0
        text: root.text
        color: root.hovered ? root.theme.color4 : root.baseColor
        font.family: root.theme ? root.theme.fontFamily : "Adwaita Sans"
        font.pixelSize: root.fontSize * (root.theme ? root.theme.fontScale : 1)
        font.bold: root.bold || (root.theme && root.theme.fontBold)
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        renderType: Text.NativeRendering
        scale: area.pressed ? 0.9 : (root.hovered ? 1.08 : 1)
        rotation: 0

        Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 7.0; damping: area.pressed ? 0.45 : 0.6; mass: 0.9; epsilon: 0.001 } }
        Behavior on rotation { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.65; mass: 0.9; epsilon: 0.001 } }
    }

    Item {
        id: svgLabel
        visible: root.hasIconSource
        anchors.centerIn: root.text.length > 0 ? undefined : parent
        anchors.verticalCenter: root.text.length > 0 ? parent.verticalCenter : undefined
        anchors.left: root.text.length > 0 ? parent.left : undefined
        anchors.leftMargin: root.text.length > 0 ? root.horizontalPadding : 0
        width: root.iconSize
        height: root.iconSize
        scale: area.pressed ? 0.9 : (root.hovered ? 1.08 : 1)
        rotation: 0

        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 7.0; damping: area.pressed ? 0.45 : 0.6; mass: 0.9; epsilon: 0.001 } }
        Behavior on rotation { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.65; mass: 0.9; epsilon: 0.001 } }

        Image {
            id: svgSource
            anchors.fill: parent
            source: root.iconSource
            sourceSize.width: width
            sourceSize.height: height
            smooth: true
            mipmap: true
            visible: false
        }

        MultiEffect {
            anchors.fill: svgSource
            source: svgSource
            colorization: 1
            colorizationColor: root.hovered ? root.theme.color4 : root.baseColor

            Behavior on colorizationColor { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic } }
        }
    }

    SequentialAnimation {
        id: bellRing
        NumberAnimation { target: label; property: "rotation"; to: -8; duration: theme && theme.reducedMotion ? Math.round(90 / 2) : 90; easing.type: Easing.OutCubic }
        NumberAnimation { target: label; property: "rotation"; to: 8; duration: theme && theme.reducedMotion ? Math.round(120 / 2) : 120; easing.type: Easing.OutCubic }
        SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  target: label; property: "rotation"; to: 0; spring: 5.0; damping: 0.6; mass: 0.9; epsilon: 0.001 }
    }

    SequentialAnimation {
        id: flashAnim
        PropertyAction { target: root; property: "flash"; value: true }
        PauseAnimation { duration: theme && theme.reducedMotion ? Math.round(70 / 2) : 70 }
        PropertyAction { target: root; property: "flash"; value: false }
    }

    ParallelAnimation {
        id: rippleAnim
        NumberAnimation { target: ripple; property: "scale"; from: 1; to: 3; duration: theme && theme.reducedMotion ? Math.round(350 / 2) : 350; easing.type: Easing.OutCubic }
        NumberAnimation { target: ripple; property: "opacity"; from: 0.30; to: 0; duration: theme && theme.reducedMotion ? Math.round(350 / 2) : 350; easing.type: Easing.OutCubic }
    }

    TooltipPopup {
        id: tooltip
        theme: root.theme
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            root.clicked()
            if (root.command.length > 0)
                Quickshell.execDetached(["sh", "-c", root.command])
        }

        onPressed: function(mouse) {
            root.rippleX = mouse.x
            root.rippleY = mouse.y
            flashAnim.restart()
            rippleAnim.restart()
        }

        onWheel: function(wheel) {
            if (wheel.angleDelta.y > 0)
                root.wheelUp()
            else if (wheel.angleDelta.y < 0)
                root.wheelDown()
        }
    }
}

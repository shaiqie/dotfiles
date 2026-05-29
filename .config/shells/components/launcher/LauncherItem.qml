import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    property var theme
    property var app
    property int itemIndex: 0
    property int staggerDelay: 0
    property bool selected: false
    property bool menuVisible: false
    property bool itemReady: false
    readonly property bool isAction: app && app.action
    readonly property bool isMath: isAction && app.action === "math"
    readonly property color actionColorA: isMath ? theme.color5 : theme.color6
    readonly property color actionColorB: isMath ? actionColorA : theme.color14
    readonly property bool actionHot: isAction && (area.containsMouse || selected)
    readonly property string descriptionText: buildDescription()
    property real actionPulse: 0

    signal clicked()
    width: parent ? parent.width : 350
    height: 56
    opacity: menuVisible && itemReady ? 1 : 0
    scale: 1

    Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? 0 : 220; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(160 / 2) : 160; easing.type: Easing.OutCubic } }

    onMenuVisibleChanged: restartAppear()
    onAppChanged: restartAppear()

    Component.onCompleted: restartAppear()

    Timer {
        id: appearTimer
        interval: root.staggerDelay
        repeat: false
        onTriggered: root.itemReady = root.menuVisible
    }

    SequentialAnimation on actionPulse {
        running: root.isAction && root.menuVisible
        loops: Animation.Infinite
        NumberAnimation { from: 0; to: 1; duration: root.theme.reducedMotion ? 0 : 850; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1; to: 0; duration: root.theme.reducedMotion ? 0 : 850; easing.type: Easing.InOutSine }
    }

    function restartAppear() {
        appearTimer.stop()
        itemReady = false
        if (menuVisible)
            appearTimer.restart()
    }

    Item {
        id: contentLayer
        width: parent.width
        height: parent.height
        y: root.menuVisible && root.itemReady ? 0 : 3
        clip: true

        Behavior on y { NumberAnimation { duration: theme && theme.reducedMotion ? 0 : 280; easing.type: Easing.OutExpo } }

        Rectangle {
            id: rowBg
            anchors.fill: parent
            anchors.margins: 2
            radius: root.isAction ? Math.min(18, root.theme.itemRadius + 6) : root.theme.itemRadius
            color: root.isAction
                ? root.theme.withAlpha(root.actionColorA, (area.containsMouse || root.selected ? 0.2 : 0.12) + root.actionPulse * 0.04)
                : (area.containsMouse ? root.theme.withAlpha(root.theme.color4, 0.09) : "transparent")
            border.width: 0
            border.color: root.theme.withAlpha(root.theme.color2, 0.34)
            scale: root.actionHot ? 1.012 : 1

            Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? 0 : 130; easing.type: Easing.OutCubic } }
            Behavior on border.width { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(120 / 2) : 120; easing.type: Easing.OutCubic } }
            Behavior on scale { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 260; spring: 5.2; damping: 0.76; mass: 0.8; epsilon: 0.001 } }
        }

        Rectangle {
            visible: root.isAction
            anchors.fill: rowBg
            radius: rowBg.radius
            opacity: root.actionHot ? 0.46 + root.actionPulse * 0.16 : 0.3 + root.actionPulse * 0.08
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.theme.withAlpha(root.actionColorA, 0.36) }
                GradientStop { position: 0.46; color: root.theme.withAlpha(root.actionColorB, root.actionHot ? 0.24 : 0.14) }
                GradientStop { position: 1.0; color: "transparent" }
            }

            Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic } }
        }

        Rectangle {
            visible: root.isAction
            width: root.actionHot ? 7 : 5
            height: width
            radius: width / 2
            anchors.right: rowBg.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            color: root.actionColorA
            opacity: root.actionHot ? 0.7 + root.actionPulse * 0.25 : 0.45
            scale: root.actionHot ? 1 + root.actionPulse * 0.24 : 1

            Behavior on width { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 260; spring: 5.6; damping: 0.7; mass: 0.8; epsilon: 0.001 } }
            Behavior on opacity { NumberAnimation { duration: root.theme.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic } }
            Behavior on scale { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 320; spring: 4.8; damping: 0.78; mass: 0.9; epsilon: 0.001 } }
        }

        Rectangle {
            visible: root.isAction
            anchors.centerIn: icon
            width: root.actionHot ? 36 + root.actionPulse * 5 : 32
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: root.theme.withAlpha(root.actionColorA, root.actionHot ? 0.64 - root.actionPulse * 0.32 : 0.24 + root.actionPulse * 0.16)
            scale: root.actionHot ? 1 + root.actionPulse * 0.1 : 1

            Behavior on width { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 380; spring: 4.6; damping: 0.82; mass: 0.9; epsilon: 0.001 } }
            Behavior on border.color { ColorAnimation { duration: root.theme.reducedMotion ? 0 : 220; easing.type: Easing.OutCubic } }
            Behavior on scale { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 380; spring: 4.6; damping: 0.82; mass: 0.9; epsilon: 0.001 } }
        }

        Rectangle {
            visible: root.isAction
            anchors.centerIn: icon
            width: root.actionHot ? 28 : 24
            height: width
            radius: 9
            color: root.theme.withAlpha(root.actionColorA, (root.actionHot ? 0.2 : 0.12) + root.actionPulse * 0.05)
            rotation: root.isAction ? (root.isMath ? -8 : 8) + (root.actionPulse - 0.5) * (root.isMath ? -7 : 7) : 0

            Behavior on width { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 320; spring: 5.4; damping: 0.72; mass: 0.8; epsilon: 0.001 } }
            Behavior on rotation { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 360; spring: 5.0; damping: 0.72; mass: 0.9; epsilon: 0.001 } }
            Behavior on color { ColorAnimation { duration: root.theme.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic } }
        }

        Rectangle {
            width: root.selected && !root.isAction ? 3 : 0
            height: 22
            radius: 2
            anchors.left: parent.left
            anchors.leftMargin: 5
            anchors.verticalCenter: parent.verticalCenter
            color: root.isAction ? root.actionColorB : root.theme.color4
            opacity: root.selected && !root.isAction ? 1 : 0

            Behavior on width { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 220; spring: 5.0; damping: 0.82; mass: 0.9; epsilon: 0.001 } }
            Behavior on opacity { NumberAnimation { duration: root.theme.reducedMotion ? 0 : 120; easing.type: Easing.OutCubic } }
        }

        IconImage {
            id: icon
            anchors.left: parent.left
            anchors.leftMargin: root.selected && !root.isAction ? 15 : 12
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 26
            implicitSize: 26
            mipmap: true
            asynchronous: true
            visible: !root.isAction
            source: root.app ? (root.isAction ? root.app.icon : Quickshell.iconPath(root.app.icon, true)) : ""
            scale: area.containsMouse ? 1.12 : 1.0

            Behavior on scale { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 260; spring: 6.0; damping: 0.65; mass: 0.9; epsilon: 0.001 } }
            Behavior on anchors.leftMargin { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 220; spring: 5.0; damping: 0.82; mass: 0.9; epsilon: 0.001 } }
        }

        Image {
            id: actionIcon
            anchors.fill: icon
            source: root.isAction && root.app ? "file://" + root.app.icon : ""
            sourceSize.width: width
            sourceSize.height: height
            smooth: true
            mipmap: true
            visible: false
        }

        MultiEffect {
            visible: root.isAction
            anchors.fill: actionIcon
            source: actionIcon
            colorization: 1
            colorizationColor: root.actionColorA
            scale: root.isAction ? 1.06 + root.actionPulse * 0.12 : 1
            rotation: root.isAction ? (root.isMath ? -4 : 4) + (root.actionPulse - 0.5) * (root.isMath ? -8 : 8) : 0

            Behavior on scale { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 320; spring: 6.0; damping: 0.62; mass: 0.8; epsilon: 0.001 } }
            Behavior on rotation { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 360; spring: 5.0; damping: 0.72; mass: 0.9; epsilon: 0.001 } }
        }

        Rectangle {
            visible: root.isAction
            anchors.right: rowBg.right
            anchors.rightMargin: 28
            anchors.verticalCenter: parent.verticalCenter
            width: root.isMath ? 22 : 30
            height: 16
            radius: 8
            color: root.theme.withAlpha(root.actionColorA, root.actionHot ? 0.18 : 0.1)
            border.width: 1
            border.color: root.theme.withAlpha(root.actionColorA, root.actionHot ? 0.34 : 0.18)
            scale: root.actionHot ? 1.04 : 1

            Text {
                anchors.centerIn: parent
                text: root.isMath ? "=" : "go"
                color: root.actionColorA
                font.family: root.theme.fontFamily
                font.pixelSize: 9 * root.theme.fontScale
                font.bold: true
                renderType: Text.NativeRendering
            }

            Behavior on scale { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 260; spring: 5.2; damping: 0.72; mass: 0.8; epsilon: 0.001 } }
            Behavior on color { ColorAnimation { duration: root.theme.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }
            Behavior on border.color { ColorAnimation { duration: root.theme.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }
        }

        Column {
            anchors.left: icon.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: root.isAction ? 34 : 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            x: root.actionHot ? 2 : 0

            Behavior on x { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 280; spring: 5.2; damping: 0.76; mass: 0.85; epsilon: 0.001 } }

            Text {
                width: parent.width
                text: root.app ? root.app.name : ""
                color: root.isAction ? root.actionColorA : (root.selected ? root.theme.foreground : root.theme.color7)
                font.family: root.theme.fontFamily
                font.pixelSize: (root.isAction && root.isMath ? 16 : root.isAction ? 13.5 : 13) * root.theme.fontScale
                font.bold: true
                elide: Text.ElideRight
                renderType: Text.NativeRendering

                Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(130 / 2) : 130; easing.type: Easing.OutCubic } }
            }

            Text {
                visible: root.descriptionText.length > 0
                width: parent.width
                text: root.descriptionText
                color: root.theme.withAlpha(root.theme.foreground, 0.5)
                font.family: root.theme.fontFamily
                font.pixelSize: 10.5 * root.theme.fontScale
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    function buildDescription() {
        if (!root.app)
            return ""
        if (root.isAction)
            return String(root.app.comment || "")

        const generic = String(root.app.genericName || "").trim()
        const comment = String(root.app.comment || "").trim()
        if (generic.length > 0)
            return generic
        if (comment.length > 0)
            return comment
        return "Application"
    }
}

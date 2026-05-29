import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property var theme
    property var store
    property var notification
    property int delay: 0
    property bool appeared: false
    property bool dismissing: false
    property real dragX: 0
    property int ageTick: 0
    property bool hovered: area.containsMouse
    property real contentShift: appeared ? 0 : 10
    property real glowMargin: hovered ? -5 : -2
    property real sweepX: -0.25
    property real hoverScale: hovered ? 1.006 : 1

    signal expandedChanged()

    readonly property bool hasNotification: notification !== undefined && notification !== null
    readonly property bool hasActions: hasNotification && notification.actions && notification.actions.length > 0
    readonly property bool hasBody: hasNotification && notification.body.length > 0
    readonly property int moreCount: hasNotification ? (notification.moreCount || 0) : 0
    readonly property int cardHeight: 76 + (hasBody ? 34 : 0) + (hasActions ? 42 : 0)
    readonly property color accent: hasNotification && notification.critical ? theme.color1 : theme.color4

    width: parent ? parent.width : 360
    height: dismissing ? 0 : cardHeight
    radius: theme ? theme.panelRadius : 18
    color: "transparent"
    clip: false
    opacity: dismissing ? 0 : 1

    Behavior on height {
        SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 270; spring: 4.8; damping: 0.84; mass: 0.9; epsilon: 0.001 }
    }

    Behavior on opacity {
        SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 220; spring: 5.0; damping: 0.88; mass: 0.9; epsilon: 0.001 }
    }

    Behavior on contentShift {
        SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 280; spring: 4.8; damping: 0.84; mass: 0.9; epsilon: 0.001 }
    }

    Behavior on glowMargin {
        SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 260; spring: 4.8; damping: 0.84; mass: 0.9; epsilon: 0.001 }
    }

    Timer {
        interval: root.delay
        running: true
        repeat: false
        onTriggered: root.appeared = true
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.ageTick++
    }

    Rectangle {
        anchors.fill: card
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        radius: root.theme.panelRadius
        color: root.theme.withAlpha(root.theme.color1, Math.min(0.22, Math.max(0, root.dragX) / 720))

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            text: "󰩹"
            color: root.theme.color1
            font.pixelSize: 18
            opacity: Math.min(1, Math.max(0, root.dragX) / 110)
        }
    }

    Rectangle {
        anchors.fill: card
        anchors.margins: root.glowMargin
        radius: root.theme.itemRadius + 5
        color: root.theme.withAlpha(root.accent, root.theme.enableGlow ? (root.hovered ? 0.10 : 0.045) : 0)
        opacity: card.opacity
        Behavior on color { ColorAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        id: card
        x: dismissing ? root.width + 40 : dragX
        y: appeared ? 0 : -14
        width: parent.width
        height: root.cardHeight
        radius: root.theme.itemRadius
        color: root.theme.withAlpha(root.theme.foreground, root.hovered ? 0.066 : 0.050)
        border.width: root.theme.outerBorder ? root.theme.borderWidth : 0
        border.color: root.theme.withAlpha(root.hovered ? root.accent : (root.theme.gradientBorder ? root.theme.color4 : root.theme.color1), root.hovered ? 0.30 : 0.16)
        scale: appeared && !dismissing ? root.hoverScale : 0.96
        opacity: appeared && !dismissing ? Math.max(0.25, 1 - Math.max(0, dragX) / 230) : 0
        antialiasing: true
        clip: true

        Behavior on x { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 260; spring: 4.8; damping: 0.84; mass: 0.9; epsilon: 0.001 } }
        Behavior on y { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 260; spring: 4.6; damping: 0.84; mass: 0.9; epsilon: 0.001 } }
        Behavior on scale { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 260; spring: 4.8; damping: 0.84; mass: 0.9; epsilon: 0.001 } }
        Behavior on opacity { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 230; spring: 5.0; damping: 0.88; mass: 0.9; epsilon: 0.001 } }
        Behavior on color { ColorAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 170; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 170; easing.type: Easing.OutCubic } }

        Rectangle {
            width: 46
            height: parent.height * 1.4
            x: parent.width * root.sweepX
            y: -parent.height * 0.20
            rotation: 18
            color: root.theme.withAlpha(root.accent, 0.045)
            opacity: root.hovered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }
        }

        NumberAnimation {
            target: root
            property: "sweepX"
            running: root.hovered
            loops: Animation.Infinite
            from: -0.25
            to: 1.10
            duration: root.theme && root.theme.reducedMotion ? 0 : 1600
            easing.type: Easing.InOutSine
        }

        Item {
            anchors.fill: parent
            anchors.margins: 12
            x: root.contentShift

            Rectangle {
                id: appMark
                width: 34
                height: 34
                radius: root.theme.controlRadius
                color: root.theme.withAlpha(root.accent, 0.12)
                border.width: root.theme.outerBorder ? 1 : 0
                border.color: root.theme.withAlpha(root.accent, 0.18)
                anchors.left: parent.left
                anchors.top: parent.top
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 4
                    source: root.hasNotification ? root.notification.appIcon : ""
                    fillMode: Image.PreserveAspectFit
                    visible: root.hasNotification && root.notification.appIcon.length > 0
                    asynchronous: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: !root.hasNotification || root.notification.appIcon.length === 0
                    text: root.hasNotification && root.notification.appName.length > 0 ? root.notification.appName[0].toUpperCase() : "•"
                    color: root.accent
                    font.family: root.theme.fontFamily
                    font.pixelSize: 14 * root.theme.fontScale
                    font.bold: true
                }
            }

            Column {
                id: copy
                anchors.left: appMark.right
                anchors.leftMargin: 12
                anchors.right: meta.right
                anchors.top: parent.top
                spacing: 4

                RowLayout {
                    width: parent.width
                    height: 18
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: root.hasNotification ? root.notification.appName.toUpperCase() : ""
                        color: root.theme.withAlpha(root.theme.foreground, 0.46)
                        font.family: root.theme.fontFamily
                        font.pixelSize: 8 * root.theme.fontScale
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        text: root.hasNotification ? root.timeAgo(root.notification.timestamp) : ""
                        color: root.theme.withAlpha(root.theme.foreground, 0.40)
                        font.family: root.theme.fontFamily
                        font.pixelSize: 9 * root.theme.fontScale
                    }
                }

                Text {
                    width: parent.width
                    text: root.hasNotification ? root.notification.summary : ""
                    color: root.theme.foreground
                    font.family: root.theme.fontFamily
                    font.pixelSize: 14 * root.theme.fontScale
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: root.hasBody
                    text: root.hasNotification ? root.notification.body : ""
                    color: root.theme.withAlpha(root.theme.foreground, 0.66)
                    font.family: root.theme.fontFamily
                    font.pixelSize: 12 * root.theme.fontScale
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                }
            }

            Item {
                id: meta
                anchors.right: parent.right
                anchors.top: parent.top
                width: root.moreCount > 0 ? 56 : 22
                height: 22

                Rectangle {
                    visible: root.moreCount > 0
                    anchors.fill: parent
                    radius: root.theme.microRadius
                    color: root.theme.withAlpha(root.accent, 0.10)

                    Text {
                        anchors.centerIn: parent
                        text: "+" + root.moreCount
                        color: root.accent
                        font.family: root.theme.fontFamily
                        font.pixelSize: 10 * root.theme.fontScale
                        font.bold: true
                    }
                }
            }

            Row {
                visible: root.hasActions
                anchors.left: copy.left
                anchors.right: parent.right
                anchors.top: copy.bottom
                anchors.topMargin: 12
                spacing: 8

                Repeater {
                    model: root.hasNotification && root.notification.actions ? root.notification.actions.length : 0
                    NotifyActionButton {
                        theme: root.theme
                        text: root.notification.actions[index].text
                        onClicked: root.store.invoke(root.notification.id, index)
                    }
                }
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            drag.target: card
            drag.axis: Drag.XAxis
            drag.minimumX: 0
            drag.maximumX: root.width + 80
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            onPositionChanged: root.dragX = Math.max(0, card.x)
            onReleased: {
                if (card.x > 120) {
                    root.dismissing = true
                    dismissDelay.restart()
                } else {
                    root.dragX = 0
                    card.x = 0
                    if (root.moreCount > 0)
                        root.store.toggleGroup(root.notification.groupKey)
                }
            }
        }
    }

    Timer {
        id: dismissDelay
        interval: 180
        repeat: false
        onTriggered: root.store.dismiss(root.notification.id)
    }

    function timeAgo(ts) {
        ageTick
        const sec = Math.max(1, Math.floor((Date.now() - ts) / 1000))
        if (sec < 60)
            return "now"
        const min = Math.floor(sec / 60)
        if (min < 60)
            return min + "m ago"
        const hr = Math.floor(min / 60)
        return hr + "h ago"
    }
}

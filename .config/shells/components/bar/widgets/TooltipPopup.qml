import QtQuick
import Quickshell

PopupWindow {
    id: root

    property var theme
    property string label: ""
    property bool closing: false

    color: "transparent"
    grabFocus: false
    implicitWidth: bubble.implicitWidth
    implicitHeight: bubble.implicitHeight
    visible: false

    Rectangle {
        id: bubble

        implicitWidth: tipText.implicitWidth + 18
        implicitHeight: 26
        radius: root.theme ? root.theme.controlRadius : 10
        color: root.theme ? root.theme.withAlpha(root.theme.background, 0.96) : "#111111"
        border.width: root.theme && root.theme.outerBorder ? root.theme.borderWidth : 0
        border.color: root.theme ? root.theme.withAlpha(root.theme.color4, root.theme.borderOpacity) : "transparent"
        opacity: root.visible && !root.closing ? 1 : 0
        y: root.visible && !root.closing ? 0 : -4
        scale: root.visible && !root.closing ? 1 : 0.96
        antialiasing: true

        Behavior on opacity { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 130; easing.type: Easing.OutCubic } }
        Behavior on y { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 220; spring: 5.0; damping: 0.78; mass: 0.9; epsilon: 0.001 } }
        Behavior on scale { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 220; spring: 5.0; damping: 0.78; mass: 0.9; epsilon: 0.001 } }

        Text {
            id: tipText
            anchors.centerIn: parent
            text: root.label
            color: root.theme ? root.theme.foreground : "white"
            font.family: root.theme ? root.theme.fontFamily : "Adwaita Sans"
            font.pixelSize: 11 * (root.theme ? root.theme.fontScale : 1)
            font.bold: root.theme && root.theme.fontBold
            renderType: Text.NativeRendering
        }
    }

    Timer {
        id: hideTimer
        interval: 120
        repeat: false
        onTriggered: root.visible = false
    }

    function showFor(item, text, parentWindow) {
        const value = String(text || "")
        if (value.length === 0 || !item)
            return

        hideTimer.stop()
        root.closing = false
        root.label = value

        const win = parentWindow
        if (!win)
            return

        const pos = win.mapFromItem(item, item.width / 2, item.height)
        root.anchor.window = win
        root.anchor.rect = Qt.rect(Math.round(pos.x - root.implicitWidth / 2), Math.round(pos.y + 8), 1, 1)
        root.visible = true
    }

    function closeAnimated() {
        if (!root.visible)
            return
        root.closing = true
        hideTimer.restart()
    }
}

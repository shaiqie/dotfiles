import QtQuick
import Quickshell
import Quickshell.Widgets
import "../widgets"

Item {
    id: root

    property var theme
    property var trayItem
    property var menuAnchorItem
    readonly property string iconSource: resolveIcon()
    readonly property string appText: {
        if (!trayItem)
            return ""
        return (trayItem.title + " " + trayItem.tooltipTitle + " " + trayItem.tooltipDescription + " " + trayItem.id).toLowerCase()
    }

    width: 20
    height: 26
    scale: area.containsMouse ? 1.12 : 1

    Behavior on scale { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(150 / 2) : 150; easing.type: Easing.OutCubic } }

    Timer {
        id: tipDelay
        interval: 420
        repeat: false
        onTriggered: if (area.containsMouse) tooltip.showFor(root, tooltipLabel(), QsWindow.window)
    }

    Rectangle {
        anchors.centerIn: parent
        width: 24
        height: 24
        radius: 12
        color: root.theme.withAlpha(root.theme.color4, area.containsMouse ? 0.18 : 0)

        Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(150 / 2) : 150; easing.type: Easing.OutCubic } }
    }

    IconImage {
        anchors.centerIn: parent
        implicitSize: 16
        width: 16
        height: 16
        asynchronous: true
        mipmap: true
        source: root.iconSource
        visible: root.iconSource.length > 0
    }

    Text {
        anchors.centerIn: parent
        visible: root.iconSource.length === 0
        text: fallbackLetter()
        color: root.theme.color4
        font.family: root.theme.fontFamily
        font.pixelSize: 12 * root.theme.fontScale
        font.bold: root.theme.fontBold
        renderType: Text.NativeRendering
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: tipDelay.restart()
        onExited: {
            tipDelay.stop()
            tooltip.closeAnimated()
        }

        onClicked: function(mouse) {
            if (!root.trayItem)
                return

            if (mouse.button === Qt.RightButton || root.trayItem.onlyMenu) {
                const anchorItem = root.menuAnchorItem || root
                const pos = QsWindow.window.mapFromItem(anchorItem, 0, anchorItem.height)
                if (root.trayItem.hasMenu)
                    trayMenu.openAt(QsWindow.window, pos.x, pos.y + 6, root.trayItem.menu)
                else
                    root.trayItem.display(QsWindow.window, pos.x, pos.y + 6)
            } else {
                root.trayItem.activate()
            }
        }
    }

    TrayMenu {
        id: trayMenu
        theme: root.theme
    }

    TooltipPopup {
        id: tooltip
        theme: root.theme
    }

    function resolveIcon() {
        if (!trayItem)
            return ""

        const icon = trayItem.icon || ""
        if (icon.length > 0) {
            if (icon[0] === "/" || icon.startsWith("file:") || icon.startsWith("image:"))
                return icon

            const resolved = Quickshell.iconPath(icon, true)
            if (resolved.length > 0)
                return resolved
        }

        if (appText.indexOf("vesktop") >= 0) {
            const vesktop = Quickshell.iconPath("vesktop", true)
            if (vesktop.length > 0)
                return vesktop
            return "/usr/share/icons/hicolor/scalable/apps/vesktop.svg"
        }

        if (appText.indexOf("discord") >= 0) {
            const discord = Quickshell.iconPath("discord", true)
            if (discord.length > 0)
                return discord
            const connected = Quickshell.iconPath("discord-tray-connected", true)
            if (connected.length > 0)
                return connected
        }

        return ""
    }

    function fallbackLetter() {
        if (!trayItem)
            return "•"

        const label = trayItem.title || trayItem.tooltipTitle || trayItem.tooltipDescription || trayItem.id || ""
        return label.length > 0 ? label[0].toUpperCase() : "•"
    }

    function tooltipLabel() {
        if (!trayItem)
            return "Tray item"

        const title = trayItem.tooltipTitle || trayItem.title || trayItem.id || "Tray item"
        const body = trayItem.tooltipDescription || ""
        return body.length > 0 ? (title + " • " + body) : title
    }
}

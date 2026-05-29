import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../widgets"

Row {
    id: root

    property var theme
    property var menuAnchorItem
    property bool open: false

    spacing: 2

    IconButton {
        theme: root.theme
        iconSource: Quickshell.env("HOME") + "/.config/shells/assets/icons/panel/tray/" + (root.open ? "tray_folder_opened.svg" : "tray_folder.svg")
        baseColor: root.theme.color4
        iconSize: 18
        tooltipText: "Tray"
        onClicked: root.open = !root.open
    }

    Item {
        id: trayClip
        width: root.open ? trayRow.implicitWidth : 0
        height: 26
        clip: true
        opacity: root.open ? 1 : 0

        Behavior on width { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(500 / 2) : 500; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(220 / 2) : 220; easing.type: Easing.OutCubic } }

        Row {
            id: trayRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Repeater {
                model: SystemTray.items

                TrayItem {
                    trayItem: modelData
                    theme: root.theme
                    menuAnchorItem: root.menuAnchorItem
                }
            }
        }
    }
}

import QtQuick
import Quickshell
import "../widgets"

IconButton {
    id: root

    property var panelController

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    iconSource: Quickshell.env("HOME") + "/.config/shells/assets/icons/panel/clock/clock.svg"
    text: Qt.formatDateTime(clock.date, "hh:mm")
    baseColor: root.theme.color5
    fontSize: 13
    iconSize: 16
    bold: true
    tooltipText: Qt.formatDateTime(clock.date, "HH:mm • dddd, MMMM d yyyy")
    onClicked: if (panelController) panelController.toggleFromItem("clock", root)
}

import QtQuick
import Quickshell
import "../widgets"

IconButton {
    id: root

    property var memoryStats
    property var panelController

    iconSource: Quickshell.env("HOME") + "/.config/shells/assets/icons/panel/ram/ram.svg"
    baseColor: root.theme.color4
    iconSize: 18
    tooltipText: memoryStats && memoryStats.totalGiB > 0
        ? ("RAM " + memoryStats.usedGiB.toFixed(1) + "G / " + memoryStats.totalGiB.toFixed(1) + "G • " + Math.round(memoryStats.usedGiB / memoryStats.totalGiB * 100) + "%")
        : "RAM"
    onClicked: if (panelController) panelController.toggleFromItem("memory", root)
}

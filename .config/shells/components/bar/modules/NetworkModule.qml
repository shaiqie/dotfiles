import QtQuick
import Quickshell
import "../widgets"

IconButton {
    id: root

    property var networkState
    property var networkSpeed
    property var panelController

    iconSource: Quickshell.env("HOME") + "/.config/shells/assets/icons/panel/wifi/wifi.svg"
    baseColor: root.theme.color6
    iconSize: 17
    tooltipText: networkTooltip()
    onClicked: if (panelController) panelController.toggleFromItem("network", root)

    function networkTooltip() {
        if (!networkState || !networkState.connected)
            return "Network disconnected"

        let label = networkState.wifiConnected
            ? (networkState.name + " • " + networkState.signalStrength + "% signal")
            : (networkState.name.length > 0 ? networkState.name : "Ethernet")

        if (networkSpeed)
            label += " • ↓ " + networkSpeed.downText + "/s ↑ " + networkSpeed.upText + "/s"

        return label
    }
}

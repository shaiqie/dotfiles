import QtQuick
import Quickshell
import "../widgets"
import "../../services" as Services

IconButton {
    id: root

    property var panelController

    readonly property string iconDir: Quickshell.env("HOME") + "/.config/shells/assets/icons/panel/bluetooth/"
    readonly property string stateText: Services.BluetoothState.powered ? "On" : "Off"
    readonly property string adapterText: Services.BluetoothState.adapterName !== "Bluetooth" ? (" • " + Services.BluetoothState.adapterName) : ""

    Component.onCompleted: Services.BluetoothState.refresh()

    iconSource: iconDir + (Services.BluetoothState.powered ? "bluetooth.svg" : "bluetooth_disconnected.svg")
    baseColor: root.theme.color4
    iconSize: 17
    tooltipText: "Bluetooth radio • " + stateText + adapterText + " • Click to manage"
    onClicked: if (panelController) panelController.toggleFromItem("bluetooth", root)
}

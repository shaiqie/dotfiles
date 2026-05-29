import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../widgets"

IconButton {
    id: root

    readonly property var battery: UPower.displayDevice
    readonly property int percentage: battery && battery.isPresent ? percent(battery.percentage) : 0
    readonly property bool charging: battery && battery.state === UPowerDeviceState.Charging
    readonly property bool critical: percentage > 0 && percentage <= 15 && !charging
    property var panelController
    readonly property string iconPath: {
        if (!battery || !battery.isPresent)
            return Quickshell.env("HOME") + "/.config/shells/assets/icons/panel/battery/battery_state_alert.svg"
        if (critical)
            return Quickshell.env("HOME") + "/.config/shells/assets/icons/panel/battery/battery_state_alert.svg"
        if (percentage >= 100 || battery.state === UPowerDeviceState.FullyCharged)
            return Quickshell.env("HOME") + "/.config/shells/assets/icons/panel/battery/battery_full.svg"
        return Quickshell.env("HOME") + "/.config/shells/assets/icons/panel/battery/battery_state_" + batteryState(percentage) + ".svg"
    }

    iconSource: iconPath
    baseColor: critical ? root.theme.color1 : root.theme.color2
    iconSize: 18
    tooltipText: battery && battery.isPresent ? ("Battery " + percentage + "% • " + stateText()) : "Battery unavailable"
    onClicked: if (panelController) panelController.toggleFromItem("battery", root)

    function percent(value) {
        const raw = Number(value)
        if (!isFinite(raw))
            return 0
        return Math.max(0, Math.min(100, Math.round(raw <= 1 ? raw * 100 : raw)))
    }

    function batteryState(value) {
        if (value >= 90)
            return 6
        if (value >= 75)
            return 5
        if (value >= 60)
            return 4
        if (value >= 45)
            return 3
        if (value >= 30)
            return 2
        return 1
    }

    function stateText() {
        if (!battery)
            return "Unknown"
        if (battery.state === UPowerDeviceState.Charging)
            return "Charging"
        if (battery.state === UPowerDeviceState.FullyCharged)
            return "Full"
        if (battery.state === UPowerDeviceState.PendingCharge)
            return "Waiting"
        if (battery.state === UPowerDeviceState.PendingDischarge)
            return "Pending"
        return "Discharging"
    }
}

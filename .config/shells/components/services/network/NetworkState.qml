import QtQuick
import Quickshell.Networking
import Quickshell.Io
import ".." as Services

QtObject {
    id: root

    property bool ethernetConnected: false
    property string ethernetName: ""
    property string errorMessage: ""

    readonly property var wifiDevice: findWifiDevice()
    readonly property var wifiNetwork: findWifiNetwork()
    readonly property bool wifiConnected: wifiNetwork !== null
    readonly property bool connected: wifiConnected || ethernetConnected
    readonly property string name: wifiConnected ? wifiNetwork.name : ethernetName
    readonly property int signalStrength: wifiConnected ? percent(wifiNetwork.signalStrength) : 0
    readonly property string icon: wifiConnected ? "" : (ethernetConnected ? "󰈀" : "󰤮")

    property var _probe: Process {
        command: [Services.Config.nmcliBin, "-t", "-f", "TYPE,STATE,CONNECTION", "device", "status"]
        stdout: StdioCollector { id: nmcliOut; waitForEnd: true }
        stderr: StdioCollector { id: nmcliErr; waitForEnd: true }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.ethernetConnected = false
                root.ethernetName = ""
                root.errorMessage = root.processError(nmcliErr.text, "Network status unavailable")
                return
            }
            root.errorMessage = ""
            root.parseNmcli(nmcliOut.text)
        }
    }

    property var _timer: Timer {
        interval: 30000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refreshEthernet()
    }

    function findWifiDevice() {
        const devices = Networking.devices.values
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].type === DeviceType.Wifi)
                return devices[i]
        }
        return null
    }

    function findWifiNetwork() {
        const dev = wifiDevice
        if (dev === null)
            return null

        const networks = dev.networks.values
        for (let i = 0; i < networks.length; i++) {
            if (networks[i].connected)
                return networks[i]
        }
        return null
    }

    function percent(value) {
        const raw = Number(value)
        if (!isFinite(raw))
            return 0
        return Math.max(0, Math.min(100, Math.round(raw <= 1 ? raw * 100 : raw)))
    }

    function refreshEthernet() {
        _probe.exec(_probe.command)
    }

    function parseNmcli(text) {
        ethernetConnected = false
        ethernetName = ""

        const lines = text.trim().split("\n")
        for (let i = 0; i < lines.length; i++) {
            const parts = lines[i].split(":")
            if (parts.length >= 3 && parts[0] === "ethernet" && parts[1] === "connected") {
                ethernetConnected = true
                ethernetName = parts.slice(2).join(":")
                return
            }
        }
    }

    function processError(text, fallback) {
        const msg = String(text || "").trim()
        return msg.length > 0 ? msg : fallback
    }
}

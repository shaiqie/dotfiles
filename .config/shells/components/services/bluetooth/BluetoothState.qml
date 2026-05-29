pragma Singleton

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property bool powered: false
    property bool powerTransitioning: false
    property bool desiredPowered: false
    property bool discovering: false
    property string adapterName: "Bluetooth"
    property string errorMessage: ""
    readonly property string bluetoothctlBin: "bluetoothctl"

    property var _timer: Timer {
        interval: 3000
        running: !root.powerTransitioning
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    property var _adapterProbe: Process {
        id: adapterProbe
        command: [root.bluetoothctlBin, "show"]
        stdout: StdioCollector { id: adapterOut; waitForEnd: true }
        stderr: StdioCollector { id: adapterErr; waitForEnd: true }
        onExited: function(code) {
            if (code !== 0) {
                root.errorMessage = root.processError(adapterErr.text, "Bluetooth adapter unavailable")
                root.powered = false
                return
            }
            root.parseAdapterInfo(adapterOut.text)
        }
    }

    property var _powerProcess: Process {
        id: powerProcess
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { id: powerErr; waitForEnd: true }
        onExited: function(code) {
            root.powerTransitioning = false
            if (code !== 0) {
                root.errorMessage = root.processError(powerErr.text, "Failed to toggle Bluetooth")
                root.refresh()
                return
            }
            root.errorMessage = ""
            root.refresh()
        }
    }

    function refresh() {
        if (powerTransitioning)
            return
        adapterProbe.exec(adapterProbe.command)
    }

    function setPower(enabled) {
        desiredPowered = enabled
        powerTransitioning = true
        powered = enabled
        errorMessage = ""
        powerProcess.exec([root.bluetoothctlBin, "power", enabled ? "on" : "off"])
        if (!enabled) {
            discovering = false
            powerTransitioning = false
        }
    }

    function setDiscovering(enabled) {
        discovering = enabled
    }

    function parseAdapterInfo(text) {
        const actualPowered = /Powered:\s*yes/i.test(text)
        if (powerTransitioning && actualPowered !== desiredPowered)
            powered = desiredPowered
        else {
            powered = actualPowered
            if (powerTransitioning && actualPowered === desiredPowered)
                powerTransitioning = false
        }
        discovering = /Discovering:\s*yes/i.test(text)
        const nameMatch = /Name:\s*(.+)/i.exec(text)
        adapterName = nameMatch ? nameMatch[1].trim() : "Bluetooth"
        errorMessage = ""
    }

    function processError(text, fallback) {
        const msg = String(text || "").trim()
        return msg.length > 0 ? msg : fallback
    }
}

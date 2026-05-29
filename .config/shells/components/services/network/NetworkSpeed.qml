import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property string iface: ""
    property real upMBps: 0
    property real downMBps: 0
    property string upText: "0.0M"
    property string downText: "0.0M"

    property var _prevByIface: ({})
    property string _routeIface: ""

    property var _netFile: FileView {
        id: netFile
        path: "/proc/net/dev"
        blockLoading: true
        printErrors: false
    }

    property var _routeFile: FileView {
        id: routeFile
        path: "/proc/net/route"
        blockLoading: true
        printErrors: false
    }

    property var _timer: Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.sample()
    }

    function sample() {
        const text = netFile.text()
        if (text.length === 0)
            return

        _routeIface = readDefaultIface(routeFile.text())

        const now = Date.now()
        const nextPrev = ({})
        let pickedIface = ""
        let pickedUp = 0
        let pickedDown = 0

        const lines = text.trim().split("\n")
        for (let i = 2; i < lines.length; i++) {
            const p = lines[i].trim().split(":")
            if (p.length < 2)
                continue
            const ifaceName = p[0].trim()
            if (ifaceName === "lo")
                continue
            const cols = p[1].trim().split(/\s+/)
            if (cols.length < 9)
                continue

            const rx = Number(cols[0]) || 0
            const tx = Number(cols[8]) || 0
            nextPrev[ifaceName] = { rx: rx, tx: tx, ts: now }

            const prev = _prevByIface[ifaceName]
            if (!prev)
                continue

            const dt = Math.max(0.001, (now - Number(prev.ts || 0)) / 1000)
            const down = Math.max(0, (rx - Number(prev.rx || 0)) / dt / 1024 / 1024)
            const up = Math.max(0, (tx - Number(prev.tx || 0)) / dt / 1024 / 1024)
            if (_routeIface.length > 0) {
                if (ifaceName === _routeIface) {
                    pickedIface = ifaceName
                    pickedDown = down
                    pickedUp = up
                }
            } else if (pickedIface.length === 0 || (down + up) > (pickedDown + pickedUp)) {
                pickedIface = ifaceName
                pickedDown = down
                pickedUp = up
            }
        }

        _prevByIface = nextPrev
        iface = pickedIface
        downMBps = pickedDown
        upMBps = pickedUp
        downText = fmt(pickedDown)
        upText = fmt(pickedUp)
    }

    function readDefaultIface(routeText) {
        const lines = String(routeText || "").trim().split("\n")
        for (let i = 1; i < lines.length; i++) {
            const cols = lines[i].trim().split(/\s+/)
            if (cols.length < 2)
                continue
            if (cols[1] === "00000000")
                return cols[0]
        }
        return ""
    }

    function fmt(value) {
        if (!isFinite(value) || value <= 0)
            return "0.0M"
        if (value < 0.1)
            return value.toFixed(2) + "M"
        if (value >= 100)
            return Math.round(value) + "M"
        if (value >= 10)
            return value.toFixed(1) + "M"
        return value.toFixed(1) + "M"
    }
}

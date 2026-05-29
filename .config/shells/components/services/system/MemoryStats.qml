import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property real usedGiB: 0
    property real totalGiB: 0
    property int percentage: 0

    property var _memFile: FileView {
        path: "/proc/meminfo"
        blockLoading: true
        printErrors: false
    }

    property var _timer: Timer {
        interval: 10000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    function readKb(text, key) {
        const match = new RegExp("^" + key + ":\\s+(\\d+)", "m").exec(text)
        return match ? parseInt(match[1], 10) : 0
    }

    function refresh() {
        const text = _memFile.text()
        const total = readKb(text, "MemTotal")
        const available = readKb(text, "MemAvailable")
        if (total <= 0)
            return

        const used = total - available
        usedGiB = used / 1048576
        totalGiB = total / 1048576
        percentage = Math.round((used / total) * 100)
    }
}

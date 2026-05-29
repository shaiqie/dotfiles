import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property string title: ""
    property string appClass: ""

    property var _timer: Timer {
        interval: 500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!probe.running)
                probe.exec(probe.command)
        }
    }

    property var _probe: Process {
        id: probe
        command: ["hyprctl", "-j", "activewindow"]
        stdout: StdioCollector { id: out; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            if (code !== 0) {
                root.title = ""
                root.appClass = ""
                return
            }

            try {
                const data = JSON.parse(out.text)
                root.title = data && data.title ? String(data.title) : ""
                root.appClass = data && data.class ? String(data.class) : ""
            } catch (e) {
                root.title = ""
                root.appClass = ""
            }
        }
    }
}

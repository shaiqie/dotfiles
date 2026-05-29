import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../services" as Services

QtObject {
    id: root

    property var theme
    property var networkState

    property var ipc: IpcHandler {
        target: "lockScreen"

        function lock() { root.lock() }
        function unlock() { root.unlock() }
    }

    property var dependencyProbe: Process {
        command: [Services.Config.checkPasswordScript, "--probe"]
        stdout: StdioCollector { id: dependencyOut; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            if (dependencyOut.text.trim() === "0")
                sessionLock.locked = true
            else
                Quickshell.execDetached([Services.Config.notifySendBin, "Shells lockscreen", "Install pamtester to enable secure password unlock"])
        }
    }

    property var sessionLock: WlSessionLock {
        id: sessionLock

        WlSessionLockSurface {
            color: "black"

            LockScreen {
                anchors.fill: parent
                theme: root.theme
                networkState: root.networkState
                lockSession: root
            }
        }
    }

    function lock() {
        if (!dependencyProbe.running)
            dependencyProbe.exec(dependencyProbe.command)
    }

    function unlock() {
        sessionLock.locked = false
    }
}

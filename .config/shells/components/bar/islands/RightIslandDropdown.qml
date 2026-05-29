import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Wayland
import "../panels"

PanelWindow {
    id: root

    property var theme
    property var networkState
    property var memoryStats
    property bool followItemY: false
    property var resolvePanelYAction: null
    property real barBottomEdge: 0
    property int rightIslandWidth: 0
    property real anchorX: 0
    property real anchorY: 0
    property real anchorWidth: rightIslandWidth
    property real anchorHeight: 36
    property string openPanel: ""
    property string shownPanel: ""
    property string pendingPanel: ""
    property bool expanded: false
    property bool contentReady: false
    property int motionToken: 0
    property int panelTargetY: 0
    readonly property int panelWidth: Math.max(384, Math.round(anchorWidth + 120))
    readonly property int panelY: Math.round(panelTargetY > 0 ? Math.max(panelTargetY, barBottomEdge) : (barBottomEdge > 0 ? barBottomEdge : (anchorY + anchorHeight + 10)))
    readonly property int panelExtraGap: theme ? theme.islandGap : 0
    readonly property real anchorMidX: anchorX + anchorWidth * 0.5
    readonly property real desiredPanelX: Math.round(anchorMidX - panelWidth * 0.5)
    readonly property real panelX: Math.max(8, Math.min(width - panelWidth - 8, desiredPanelX))
    readonly property real panelScaleOriginX: Math.max(0, Math.min(panelWidth, anchorMidX - panelX))
    readonly property real panelScaleOriginY: 0
    readonly property color m3Background: theme.background
    readonly property color m3Primary: theme.color6
    readonly property color m3Surface: theme.color0
    readonly property color m3OnSurface: theme.foreground
    readonly property color m3Secondary: theme.withAlpha(theme.foreground, 0.66)

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    visible: shownPanel.length > 0 || closeTimer.running || switchTimer.running
    aboveWindows: true
    focusable: true
    exclusiveZone: -1
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "shells-right-island-dropdown"

    Item {
        id: focusCatcher
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.close()
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        onActivated: root.close()
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: root.close()
    }

    Timer {
        id: openDelay
        interval: 18
        repeat: false
        onTriggered: {
            root.expanded = true
            contentDelay.restart()
        }
    }

    Timer {
        id: contentDelay
        interval: 45
        repeat: false
        onTriggered: root.contentReady = true
    }

    Timer {
        id: switchTimer
        interval: 165
        repeat: false
        onTriggered: root.openNow(root.pendingPanel)
    }

    Timer {
        id: closeTimer
        interval: 210
        repeat: false
        onTriggered: {
            root.shownPanel = ""
            root.contentReady = false
        }
    }

    PanelBase {
        id: panel
        theme: root.theme
        expanded: root.expanded
        contentReady: root.contentReady
        scaleOriginX: root.panelScaleOriginX
        scaleOriginY: root.panelScaleOriginY
        panelY: root.panelY + root.panelExtraGap
        x: root.panelX
        width: root.panelWidth
        height: content.implicitHeight + 28
        Behavior on height { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.2; damping: 0.76; mass: 0.9; epsilon: 0.001 } }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: mouse.accepted = true
        }

        Column {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.theme.panelPadding
            spacing: root.theme.itemSpacing

            Loader {
                width: parent.width
                sourceComponent: root.shownPanel === "network" ? wifiPanel
                    : root.shownPanel === "bluetooth" ? bluetoothPanel
                    : root.shownPanel === "audio" ? audioPanel
                    : root.shownPanel === "memory" ? memoryPanel
                    : root.shownPanel === "battery" ? batteryPanel
                    : root.shownPanel === "clock" ? clockPanel
                    : null
            }
        }
    }

    Component {
        id: wifiPanel
        WifiPanel {
            width: parent.width
            theme: root.theme
            motionToken: root.motionToken
        }
    }

    Component {
        id: bluetoothPanel
        BluetoothPanel {
            width: parent.width
            theme: root.theme
            motionToken: root.motionToken
        }
    }

    Component {
        id: audioPanel
        AudioPanel {
            width: parent.width
            theme: root.theme
            motionToken: root.motionToken
        }
    }

    Component {
        id: memoryPanel
        MemoryPanel {
            width: parent.width
            theme: root.theme
            motionToken: root.motionToken
        }
    }

    Component {
        id: batteryPanel
        BatteryPanel {
            width: parent.width
            theme: root.theme
            motionToken: root.motionToken
        }
    }

    Component {
        id: clockPanel
        ClockPanel {
            width: parent.width
            theme: root.theme
            motionToken: root.motionToken
        }
    }

    function toggle(panelName) {
        if (openPanel === panelName && expanded)
            close()
        else if (shownPanel.length > 0 && shownPanel !== panelName)
            switchTo(panelName)
        else
            openNow(panelName)
    }

    function toggleFromItem(panelName, item) {
        setAnchorFromItem(item)
        toggle(panelName)
    }

    function setAnchorFromItem(item) {
        if (!item)
            return
        const g = item.mapToGlobal(0, 0)
        const local = focusCatcher.mapFromGlobal(g.x, g.y)
        anchorX = Math.round(local.x)
        anchorY = Math.round(local.y)
        anchorWidth = item.width
        anchorHeight = item.height
        if (followItemY) {
            if (typeof resolvePanelYAction === "function")
                panelTargetY = Math.round(resolvePanelYAction(item))
            else {
                const p = item.mapToGlobal(0, item.height)
                panelTargetY = Math.round(p.y + 8)
            }
        }
    }

    function openNow(panelName) {
        if (panelName.length === 0)
            return
        closeTimer.stop()
        switchTimer.stop()
        pendingPanel = ""
        openPanel = panelName
        shownPanel = panelName
        panel.resetEntrance()
        expanded = false
        contentReady = false
        motionToken++
        focusCatcher.forceActiveFocus()
        openDelay.restart()
    }

    function switchTo(panelName) {
        pendingPanel = panelName
        openPanel = ""
        contentReady = false
        expanded = false
        closeTimer.stop()
        switchTimer.restart()
    }

    function close() {
        if (shownPanel.length === 0)
            return
        pendingPanel = ""
        switchTimer.stop()
        contentReady = false
        expanded = false
        openPanel = ""
        closeTimer.restart()
    }

    function signalIcon(value) {
        const pct = Math.round(Number(value) <= 1 ? Number(value) * 100 : Number(value))
        return pct > 75 ? "󰤨" : pct > 50 ? "󰤥" : pct > 25 ? "󰤢" : "󰤟"
    }

    function secondsToHours(seconds) {
        const h = Math.floor(seconds / 3600)
        const m = Math.round((seconds % 3600) / 60)
        return h + "h " + m + "m"
    }

}

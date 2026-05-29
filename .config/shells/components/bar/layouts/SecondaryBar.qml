import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import "../islands"
import "../tray"
import "../widgets"
import "../../services" as Services
import "../../notifications/center"

PanelWindow {
    id: root

    property var theme
    property var networkState
    property var networkSpeed
    property var memoryStats
    property var activeWindow
    property var notificationStore
    property var stateService
    property real barBottomEdge: 0
    property var reportBottomEdgeAction: null
    property var reportToastAnchorAction: null
    property string phase: "hidden"
    property var toggleLayoutAction: null

    signal toggleLayoutRequested()

    readonly property var visibleWorkspaces: buildVisibleWorkspaces()
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null
    readonly property bool muted: audio ? audio.muted : true
    readonly property int volume: audio ? Math.max(0, Math.round(audio.volume * 100)) : 0
    readonly property var battery: UPower.displayDevice
    readonly property int batteryPct: battery && battery.isPresent ? percent(battery.percentage) : 0
    readonly property bool batteryCharging: battery && battery.state === UPowerDeviceState.Charging
    readonly property string batteryIcon: {
        if (!battery || !battery.isPresent)
            return "󰂑"
        if (batteryCharging)
            return "󰂄"
        if (batteryPct <= 10)
            return ""
        if (batteryPct <= 35)
            return ""
        if (batteryPct <= 60)
            return ""
        if (batteryPct <= 85)
            return ""
        return ""
    }

    property string centerTitle: ""
    property string previousTitle: ""
    property real prevX: 0
    property real prevOpacity: 0
    property real nextX: 0
    property real nextOpacity: 1
    property bool showingPrevious: false
    property bool leftReady: false
    property bool centerReady: false
    property bool rightReady: false
    property int barHeight: 36
    property real ramUsedGiB: 0
    property real ramTotalGiB: 0

    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        top: 0
        left: 0
        right: 0
    }

    implicitHeight: barHeight
    exclusiveZone: phase === "hidden" ? 0 : barHeight
    aboveWindows: true
    color: "transparent"
    surfaceFormat.opaque: false
    visible: phase !== "hidden" || hideAnim.running || showAnim.running

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        blockLoading: true
        printErrors: false
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refreshMem()
    }

    Timer {
        interval: 100
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            root.reportBottomEdgeNow()
            root.reportToastAnchorNow()
        }
    }

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    onPhaseChanged: {
        if (phase === "enter" || phase === "shown")
            startShow()
        else if (phase === "exit")
            startHide()
        else {
            shell.y = -root.barHeight
            shell.opacity = 0
            leftReady = false
            centerReady = false
            rightReady = false
        }
    }

    onVisibleChanged: {
        if (visible)
            updateCenterTitle(activeWindow ? activeWindow.title : "")
    }

    Connections {
        target: activeWindow
        function onTitleChanged() {
            root.updateCenterTitle(activeWindow ? activeWindow.title : "")
        }
    }

    Timer { id: leftDelay; interval: 0; repeat: false; onTriggered: root.leftReady = true }
    Timer { id: centerDelay; interval: 80; repeat: false; onTriggered: root.centerReady = true }
    Timer { id: rightDelay; interval: 140; repeat: false; onTriggered: root.rightReady = true }
    Timer { id: clearPrev; interval: 180; repeat: false; onTriggered: root.showingPrevious = false }

    ParallelAnimation {
        id: showAnim
        NumberAnimation { target: shell; property: "y"; from: -root.barHeight; to: 0; duration: theme && theme.reducedMotion ? Math.round(280 / 2) : 280; easing.type: Easing.OutCubic }
        NumberAnimation { target: shell; property: "opacity"; from: 0; to: 1; duration: theme && theme.reducedMotion ? Math.round(280 / 2) : 280; easing.type: Easing.OutCubic }
    }

    ParallelAnimation {
        id: hideAnim
        NumberAnimation { target: shell; property: "y"; from: shell.y; to: -root.barHeight; duration: theme && theme.reducedMotion ? Math.round(200 / 2) : 200; easing.type: Easing.OutCubic }
        NumberAnimation { target: shell; property: "opacity"; from: shell.opacity; to: 0; duration: theme && theme.reducedMotion ? Math.round(200 / 2) : 200; easing.type: Easing.OutCubic }
    }

    ParallelAnimation {
        id: titleSwap
        NumberAnimation { target: root; property: "prevX"; from: 0; to: -14; duration: theme && theme.reducedMotion ? Math.round(100 / 2) : 100; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "prevOpacity"; from: 1; to: 0; duration: theme && theme.reducedMotion ? Math.round(100 / 2) : 100; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "nextX"; from: 14; to: 0; duration: theme && theme.reducedMotion ? Math.round(150 / 2) : 150; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "nextOpacity"; from: 0; to: 1; duration: theme && theme.reducedMotion ? Math.round(150 / 2) : 150; easing.type: Easing.OutCubic }
        onFinished: clearPrev.restart()
    }

    Item {
        id: shell
        anchors.fill: parent
        y: phase === "hidden" ? -root.barHeight : 0
        opacity: phase === "hidden" ? 0 : 1

        Rectangle {
            id: mainBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: root.barHeight
            color: root.theme.background
        }

        Rectangle {
            anchors.left: mainBar.left
            anchors.right: mainBar.right
            anchors.bottom: mainBar.bottom
            height: 1
            color: root.theme.withAlpha(root.theme.color1, 0.30)
        }

        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: root.barHeight
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            Item {
                Layout.preferredWidth: leftRow.implicitWidth
                Layout.fillHeight: true
                opacity: root.leftReady ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(140 / 2) : 140; easing.type: Easing.OutCubic } }

                Row {
                    id: leftRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        id: activeIconHolder
                        width: 20
                        height: 20
                        radius: 5
                        color: root.theme.withAlpha(root.theme.color1, 0.20)
                        clip: true
                        scale: iconPulse.running ? 1 : 1

                        SequentialAnimation {
                            id: iconPulse
                            running: true
                            loops: 1
                            NumberAnimation { target: activeIconHolder; property: "scale"; from: 0.8; to: 1.0; duration: theme && theme.reducedMotion ? Math.round(220 / 2) : 220; easing.type: Easing.OutCubic }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            color: root.theme.color6
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            font.bold: true
                        }

                        Timer {
                            id: archTipDelay
                            interval: 420
                            repeat: false
                            onTriggered: if (archArea.containsMouse) archTooltip.showFor(activeIconHolder, "Arch Linux", QsWindow.window)
                        }

                        MouseArea {
                            id: archArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                            onEntered: archTipDelay.restart()
                            onExited: {
                                archTipDelay.stop()
                                archTooltip.closeAnimated()
                            }
                        }

                        TooltipPopup {
                            id: archTooltip
                            theme: root.theme
                        }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Repeater {
                            model: root.visibleWorkspaces

                            Item {
                                id: wsDot
                                property var workspace: modelData
                                property int workspaceId: workspace ? workspace.id : 0
                                property bool active: workspace ? workspace.focused : false
                                property bool occupied: workspace && workspace.toplevels ? workspace.toplevels.values.length > 0 : false
                                property bool unclaimed: active && !occupied
                                property real popScale: 1

                                width: active ? 24 : 8
                                height: 8
                                scale: popScale

                                onUnclaimedChanged: {
                                    if (unclaimed)
                                        popAnim.restart()
                                    else
                                        popScale = 1
                                }

                                SequentialAnimation {
                                    id: popAnim
                                    NumberAnimation { target: wsDot; property: "popScale"; to: 1.15; duration: theme && theme.reducedMotion ? Math.round(110 / 2) : 110; easing.type: Easing.OutCubic }
                                    SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  target: wsDot; property: "popScale"; to: 1.0; spring: 6; damping: 0.5; mass: 0.9; epsilon: 0.001 }
                                }

                                Behavior on width { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.75; mass: 0.9; epsilon: 0.001 } }

                                Timer {
                                    id: workspaceTipDelay
                                    interval: 420
                                    repeat: false
                                    onTriggered: if (workspaceArea.containsMouse) workspaceTooltip.showFor(wsDot, wsDot.tooltipText(), QsWindow.window)
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 4
                                    color: active
                                        ? (unclaimed
                                            ? root.theme.withAlpha(root.theme.color4, 0.92)
                                            : root.theme.color4)
                                        : root.theme.withAlpha(root.theme.color6, 0.60)
                                }

                                MouseArea {
                                    id: workspaceArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: workspaceTipDelay.restart()
                                    onExited: {
                                        workspaceTipDelay.stop()
                                        workspaceTooltip.closeAnimated()
                                    }
                                    onClicked: Hyprland.dispatch("workspace " + parent.workspaceId)
                                }

                                TooltipPopup {
                                    id: workspaceTooltip
                                    theme: root.theme
                                }

                                function tooltipText() {
                                    const count = workspace && workspace.toplevels ? workspace.toplevels.values.length : 0
                                    let label = "Workspace " + workspaceId
                                    if (active)
                                        label += " • Active"
                                    label += " • " + count + (count === 1 ? " app" : " apps")
                                    return label
                                }
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                opacity: root.centerReady ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(140 / 2) : 140; easing.type: Easing.OutCubic } }

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: root.centerTitle.length > 0 || root.showingPrevious

                    Item {
                        id: titleHoverItem
                        width: Math.min(520, root.width * 0.42)
                        height: 20
                        clip: true

                        Text {
                            visible: root.showingPrevious && root.previousTitle.length > 0
                            width: parent.width
                            text: root.previousTitle
                            x: root.prevX
                            opacity: root.prevOpacity
                            color: root.theme.withAlpha(root.theme.foreground, 0.72)
                            font.family: root.theme.fontFamily
                            font.pixelSize: 13 * root.theme.fontScale
                            font.bold: root.theme.fontBold
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering
                        }

                        Text {
                            width: parent.width
                            text: root.centerTitle
                            x: root.nextX
                            opacity: root.nextOpacity
                            color: root.theme.foreground
                            font.family: root.theme.fontFamily
                            font.pixelSize: 13 * root.theme.fontScale
                            font.bold: root.theme.fontBold
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering
                        }

                        Timer {
                            id: titleTipDelay
                            interval: 420
                            repeat: false
                            onTriggered: if (titleArea.containsMouse && root.centerTitle.length > 0) titleTooltip.showFor(titleHoverItem, root.centerTitle, QsWindow.window)
                        }

                        MouseArea {
                            id: titleArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                            onEntered: titleTipDelay.restart()
                            onExited: {
                                titleTipDelay.stop()
                                titleTooltip.closeAnimated()
                            }
                        }

                        TooltipPopup {
                            id: titleTooltip
                            theme: root.theme
                        }
                    }
                }
            }

            Row {
                Layout.preferredWidth: implicitWidth
                Layout.fillHeight: true
                spacing: 0
                opacity: root.rightReady ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(140 / 2) : 140; easing.type: Easing.OutCubic } }

                Rectangle { width: 1; height: 18; anchors.verticalCenter: parent.verticalCenter; color: root.theme.withAlpha(root.theme.color1, 0.30) }

                Item {
                    id: trayItem
                    width: trayRow.implicitWidth + 16
                    height: parent.height

                    Row {
                        id: trayRow
                        anchors.centerIn: parent
                        spacing: 4
                        Repeater {
                            model: SystemTray.items
                            TrayItem {
                                trayItem: modelData
                                theme: root.theme
                            }
                        }
                    }
                }

                Rectangle { width: 1; height: 18; anchors.verticalCenter: parent.verticalCenter; color: root.theme.withAlpha(root.theme.color1, 0.30) }

                BarItem {
                    id: networkItem
                    theme: root.theme
                    iconColor: root.theme.color6
                    tooltipText: root.networkTooltip()
                    iconText: root.networkState ? root.networkState.icon : "󰤮"
                    valueText: root.networkState && root.networkState.connected ? root.networkState.name : "Disconnected"
                    onClicked: root.openPanel("network", networkItem)
                }

                Rectangle { width: 1; height: 18; anchors.verticalCenter: parent.verticalCenter; color: root.theme.withAlpha(root.theme.color1, 0.30) }

                BarItem {
                    id: bluetoothItem
                    theme: root.theme
                    iconColor: root.theme.color4
                    tooltipText: "Bluetooth radio • " + (Services.BluetoothState.powered ? "On" : "Off") + (Services.BluetoothState.adapterName !== "Bluetooth" ? (" • " + Services.BluetoothState.adapterName) : "") + " • Click to manage"
                    iconSource: Quickshell.env("HOME") + "/.config/shells/assets/icons/panel/bluetooth/" + (Services.BluetoothState.powered ? "bluetooth.svg" : "bluetooth_disconnected.svg")
                    valueText: Services.BluetoothState.powered ? "Bluetooth" : "Off"
                    onClicked: root.openPanel("bluetooth", bluetoothItem)
                }

                Rectangle { width: 1; height: 18; anchors.verticalCenter: parent.verticalCenter; color: root.theme.withAlpha(root.theme.color1, 0.30) }

                BarItem {
                    id: volumeItem
                    theme: root.theme
                    iconColor: root.theme.color3
                    tooltipText: root.muted ? ("Volume muted • " + root.volume + "%") : ("Volume " + root.volume + "%")
                    iconText: root.muted ? "󰝟" : (root.volume < 35 ? "" : (root.volume < 70 ? "" : ""))
                    valueText: root.volume + "%"
                    onClicked: root.openPanel("audio", volumeItem)
                    onWheelUp: {
                        if (root.audio)
                            root.audio.volume = Math.min(1.5, root.audio.volume + 0.03)
                    }
                    onWheelDown: {
                        if (root.audio)
                            root.audio.volume = Math.max(0, root.audio.volume - 0.03)
                    }
                }

                Rectangle { width: 1; height: 18; anchors.verticalCenter: parent.verticalCenter; color: root.theme.withAlpha(root.theme.color1, 0.30) }

                BarItem {
                    id: ramItem
                    theme: root.theme
                    iconColor: root.theme.color4
                    tooltipText: root.ramTotalGiB > 0 ? ("RAM " + root.ramUsedGiB.toFixed(1) + "G / " + root.ramTotalGiB.toFixed(1) + "G • " + Math.round(root.ramUsedGiB / root.ramTotalGiB * 100) + "%") : "RAM"
                    iconText: "󰍛"
                    valueText: root.ramTotalGiB > 0 ? (root.ramUsedGiB.toFixed(1) + "G") : "--"
                    onClicked: root.openPanel("memory", ramItem)
                }

                Rectangle { width: 1; height: 18; anchors.verticalCenter: parent.verticalCenter; color: root.theme.withAlpha(root.theme.color1, 0.30) }

                BarItem {
                    id: batteryItem
                    theme: root.theme
                    iconColor: root.battery && root.battery.isPresent && root.batteryPct <= 15 && !root.batteryCharging ? root.theme.color1 : root.theme.color2
                    tooltipText: root.battery && root.battery.isPresent ? ("Battery " + root.batteryPct + "% • " + root.batteryStateText()) : "Battery unavailable"
                    iconText: root.batteryIcon
                    valueText: root.battery && root.battery.isPresent ? (root.batteryPct + "%") : "--"
                    onClicked: root.openPanel("battery", batteryItem)
                }

                Rectangle { width: 1; height: 18; anchors.verticalCenter: parent.verticalCenter; color: root.theme.withAlpha(root.theme.color1, 0.30) }

                BarItem {
                    id: refreshItem
                    theme: root.theme
                    iconColor: root.theme.color4
                    tooltipText: "Switch Layout"
                    iconSource: Quickshell.env("HOME") + "/.config/shells/assets/icons/components/bar_layout.svg"
                    valueText: ""
                    onClicked: {
                        root.toggleLayoutRequested()
                        if (typeof root.toggleLayoutAction === "function")
                            root.toggleLayoutAction()
                    }
                }

                Rectangle { width: 1; height: 18; anchors.verticalCenter: parent.verticalCenter; color: root.theme.withAlpha(root.theme.color1, 0.30) }

                BarItem {
                    id: notificationItem
                    theme: root.theme
                    iconColor: root.theme.color1
                    tooltipText: root.notificationStore ? (root.notificationStore.count + " notifications") : "Notifications"
                    iconSource: Quickshell.env("HOME") + "/.config/shells/assets/icons/panel/control_center/control_center.svg"
                    valueText: ""
                    onClicked: notificationCenter.toggleFromItem(notificationItem)
                }

                Rectangle { width: 1; height: 18; anchors.verticalCenter: parent.verticalCenter; color: root.theme.withAlpha(root.theme.color1, 0.30) }

                BarItem {
                    id: clockItem
                    theme: root.theme
                    iconColor: root.theme.color5
                    tooltipText: Qt.formatDateTime(clock.date, "HH:mm • dddd, MMMM d yyyy")
                    iconSource: Quickshell.env("HOME") + "/.config/shells/assets/icons/panel/clock/clock.svg"
                    valueText: Qt.formatDateTime(clock.date, "HH:mm")
                    boldValue: true
                    onClicked: root.openPanel("clock", clockItem)
                }

                Rectangle { width: 1; height: 18; anchors.verticalCenter: parent.verticalCenter; color: root.theme.withAlpha(root.theme.color1, 0.30) }

                BarItem {
                    id: powerItem
                    theme: root.theme
                    iconColor: root.theme.color6
                    tooltipText: "Power"
                    iconSource: Quickshell.env("HOME") + "/.config/shells/assets/icons/panel/power_menu/power_menu.svg"
                    valueText: ""
                    onClicked: Quickshell.execDetached(Services.Config.powerMenuCommand)
                }
            }
        }
    }

    RightIslandDropdown {
        id: rightDropdown
        screen: root.screen
        theme: root.theme
        networkState: root.networkState
        memoryStats: null
        barBottomEdge: root.barBottomEdge
        rightIslandWidth: 200
    }

    NotificationCenter {
        id: notificationCenter
        screen: root.screen
        theme: root.theme
        store: root.notificationStore
        networkState: root.networkState
        stateService: root.stateService
        rightPanelController: rightDropdown
        barBottomEdge: root.barBottomEdge
    }

    function openPanel(name, item) {
        rightDropdown.toggleFromItem(name, item)
    }

    function reportBottomEdgeNow() {
        if (typeof root.reportBottomEdgeAction !== "function")
            return
        const g = mainBar.mapToGlobal(0, 0)
        root.reportBottomEdgeAction(Math.round(g.y + mainBar.height + 8))
    }

    function reportToastAnchorNow() {
        if (typeof root.reportToastAnchorAction !== "function" || !notificationItem)
            return
        if (root.phase !== "shown" && root.phase !== "enter")
            return
        const width = 260
        const g = notificationItem.mapToGlobal(0, 0)
        const rightAlignedX = g.x + notificationItem.width - width
        const clampedX = Math.max(8, Math.min(root.width - width - 16, rightAlignedX))
        root.reportToastAnchorAction(Math.round(clampedX), Math.round(g.y + notificationItem.height + 8), width)
    }

    function startShow() {
        leftReady = false
        centerReady = false
        rightReady = false
        leftDelay.restart()
        centerDelay.restart()
        rightDelay.restart()
        showAnim.restart()
    }

    function startHide() {
        hideAnim.restart()
    }

    function updateCenterTitle(next) {
        const value = String(next || "")
        if (value === centerTitle)
            return
        previousTitle = centerTitle
        centerTitle = value
        showingPrevious = previousTitle.length > 0
        prevX = 0
        prevOpacity = showingPrevious ? 1 : 0
        nextX = 14
        nextOpacity = 0
        titleSwap.restart()
    }

    function buildVisibleWorkspaces() {
        const focused = Hyprland.focusedWorkspace
        const spaces = Hyprland.workspaces.values
        const visible = []
        let hasFocused = false

        for (let i = 0; i < spaces.length; i++) {
            const ws = spaces[i]
            const occupied = ws.toplevels && ws.toplevels.values.length > 0
            if (ws.focused || occupied) {
                visible.push(ws)
                if (focused && ws.id === focused.id)
                    hasFocused = true
            }
        }

        if (focused && !hasFocused)
            visible.push(focused)

        visible.sort(function(a, b) { return a.id - b.id })
        return visible
    }

    function resolveAppIcon(appClass) {
        const raw = String(appClass || "")
        if (raw.length === 0)
            return ""

        const direct = Quickshell.iconPath(raw, true)
        if (direct.length > 0)
            return direct

        const lower = raw.toLowerCase()
        const lowerIcon = Quickshell.iconPath(lower, true)
        if (lowerIcon.length > 0)
            return lowerIcon

        const parts = lower.split(".")
        const tail = parts[parts.length - 1]
        const tailIcon = Quickshell.iconPath(tail, true)
        if (tailIcon.length > 0)
            return tailIcon

        return ""
    }

    function fallbackAppGlyph(appClass) {
        const raw = String(appClass || "")
        return raw.length > 0 ? raw[0].toUpperCase() : "•"
    }

    function percent(value) {
        const raw = Number(value)
        if (!isFinite(raw))
            return 0
        return Math.max(0, Math.min(100, Math.round(raw <= 1 ? raw * 100 : raw)))
    }

    function refreshMem() {
        const text = memFile.text()
        const total = readKb(text, "MemTotal")
        const available = readKb(text, "MemAvailable")
        if (total <= 0)
            return
        ramTotalGiB = total / 1048576
        ramUsedGiB = (total - available) / 1048576
    }

    function readKb(text, key) {
        const match = new RegExp("^" + key + ":\\s+(\\d+)", "m").exec(text)
        return match ? Number(match[1]) : 0
    }

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

    function batteryStateText() {
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

    component BarItem: Item {
        id: itemRoot

        property var theme
        property string iconText: ""
        property string iconSource: ""
        property string valueText: ""
        property color iconColor: itemRoot.theme ? itemRoot.theme.color6 : "white"
        property string tooltipText: ""
        property bool boldValue: false
        signal clicked()
        signal wheelUp()
        signal wheelDown()

        onTooltipTextChanged: {
            if (area.containsMouse)
                tip.showFor(itemRoot, itemRoot.tooltipText, QsWindow.window)
        }

        width: row.implicitWidth + 18
        height: parent.height
        scale: area.pressed ? 0.92 : (area.containsMouse ? 1.08 : 1.0)

        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: area.pressed ? 0.45 : 0.70; mass: 0.9; epsilon: 0.001 } }

        Timer {
            id: tipDelay
            interval: 400
            repeat: false
            onTriggered: if (itemRoot.tooltipText.length > 0 && area.containsMouse) tip.showFor(itemRoot, itemRoot.tooltipText, QsWindow.window)
        }

        Rectangle {
            anchors.centerIn: parent
            width: itemRoot.width - 4
            height: 26
            radius: 13
            color: itemRoot.theme.withAlpha(itemRoot.theme.color1, area.containsMouse ? 0.20 : 0)
            Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(140 / 2) : 140; easing.type: Easing.OutCubic } }
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6

            Image {
                id: svgIcon
                visible: false
                width: 15
                height: 15
                source: itemRoot.iconSource
                sourceSize.width: width
                sourceSize.height: height
                smooth: true
                mipmap: true
            }

            MultiEffect {
                visible: itemRoot.iconSource.length > 0
                width: 15
                height: 15
                source: svgIcon
                colorization: 1
                colorizationColor: itemRoot.iconColor
            }

            Text {
                visible: itemRoot.iconSource.length === 0
                text: itemRoot.iconText
                color: itemRoot.iconColor
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
            }

            Text {
                text: itemRoot.valueText
                color: itemRoot.theme.foreground
                font.family: itemRoot.theme.fontFamily
                font.pixelSize: 12 * itemRoot.theme.fontScale
                font.bold: itemRoot.boldValue || itemRoot.theme.fontBold
            }
        }

        TooltipPopup {
            id: tip
            theme: itemRoot.theme
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: tipDelay.restart()
            onExited: {
                tipDelay.stop()
                tip.closeAnimated()
            }
            onClicked: itemRoot.clicked()
            onWheel: function(wheel) {
                if (wheel.angleDelta.y > 0)
                    itemRoot.wheelUp()
                else if (wheel.angleDelta.y < 0)
                    itemRoot.wheelDown()
            }
        }
    }
}

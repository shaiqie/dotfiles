import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import "../../services" as Services
import "../../bar/panels" as PanelComponents

PanelWindow {
    id: root

    property var theme
    property var store
    property var networkState
    property var stateService
    property var rightPanelController
    property bool followItemY: false
    property var resolvePanelYAction: null
    property real barBottomEdge: 0
    property real anchorX: 0
    property real anchorY: 0
    property real anchorWidth: 220
    property real anchorHeight: 36
    property bool expanded: false
    property bool contentReady: false
    property int stage: -1
    property int motionToken: 0
    property int panelTargetY: 0
    property real headerOffset: 6
    property real togglesOffset: 6
    property string mediaTitle: ""
    property string mediaArtist: ""
    property string mediaArt: ""
    property string mediaStatus: ""
    property string commandError: ""
    property string mediaError: ""
    property string audioError: ""
    property string currentWallpaper: ""
    property bool micMuted: false
    property bool sinkMuted: false
    property bool nightMode: false
    property bool bluetoothPowered: Services.BluetoothState.powered
    property string bluetoothAdapterName: Services.BluetoothState.adapterName

    property int storeCount: 0

    readonly property bool panelVisible: expanded || closeTimer.running
    readonly property int panelWidth: 390
    readonly property int panelExtraGap: theme ? theme.islandGap : 0
    readonly property int panelActualY: panelY + panelExtraGap
    readonly property int panelHeight: Math.min(740, Math.max(580, root.height - panelActualY - 22))
    readonly property real anchorMidX: anchorX + anchorWidth * 0.5
    readonly property int desiredPanelX: Math.round(anchorMidX - panelWidth * 0.5)
    readonly property int panelX: Math.max(8, Math.min(width - panelWidth - 8, desiredPanelX))
    readonly property int panelY: Math.round(panelTargetY > 0 ? panelTargetY : (barBottomEdge > 0 ? barBottomEdge : (anchorY + anchorHeight)))
    readonly property real panelScaleOriginX: Math.max(0, Math.min(panelWidth, anchorMidX - panelX))
    readonly property real panelScaleOriginY: 0
    readonly property string ccIconDir: Quickshell.env("HOME") + "/.config/shells/assets/icons/panel/control_center/"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    visible: expanded || closeTimer.running
    aboveWindows: true
    focusable: true
    exclusiveZone: -1
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "shells-notification-center"

    Component.onCompleted: loadState()
    onStateServiceChanged: loadState()
    onStoreChanged: refreshCenterCount()

    onNightModeChanged: {
        if (stateService && stateService.ready)
            stateService.setValue("nightMode", nightMode)
    }

    Connections {
        target: Services.BluetoothState
        function onPoweredChanged() {
            root.bluetoothPowered = Services.BluetoothState.powered
        }
        function onAdapterNameChanged() {
            root.bluetoothAdapterName = Services.BluetoothState.adapterName
        }
    }

    Item {
        id: focusCatcher
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.close()
    }

    Behavior on headerOffset { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.4; damping: 0.78; mass: 0.9; epsilon: 0.001 } }
    Behavior on togglesOffset { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.4; damping: 0.78; mass: 0.9; epsilon: 0.001 } }

    Connections {
        target: root.store ? root.store : null
        ignoreUnknownSignals: true

        function onCenterChanged() {
            root.refreshCenterCount()
        }
    }

    Timer {
        id: openDelay
        interval: 18
        repeat: false
        onTriggered: {
            root.expanded = true
            staggerStart.restart()
        }
    }

    Timer {
        id: staggerStart
        interval: 45
        repeat: false
        onTriggered: staggerTimer.restart()
    }

    Timer {
        id: closeTimer
        interval: 210
        repeat: false
        onTriggered: root.visible = false
    }

    Timer {
        id: staggerTimer
        interval: 30
        repeat: true
        onTriggered: {
            root.stage++
            if (root.stage === 0)
                root.headerOffset = 0
            else if (root.stage === 1)
                root.togglesOffset = 0
            if (root.stage >= 9)
                stop()
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.panelVisible
        triggeredOnStart: true
        onTriggered: mediaProbe.exec(mediaProbe.command)
    }

    Timer {
        interval: 2500
        repeat: true
        running: root.panelVisible
        triggeredOnStart: true
        onTriggered: {
            micProbe.exec(micProbe.command)
            sinkProbe.exec(sinkProbe.command)
        }
    }

    FileView {
        id: walImageFile
        path: Quickshell.env("HOME") + "/.cache/wal/wal"
        preload: true
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.currentWallpaper = walImageFile.text().trim()
        onFileChanged: {
            reload()
            root.currentWallpaper = walImageFile.text().trim()
        }
    }

    PanelComponents.PanelBase {
        id: panel
        theme: root.theme
        expanded: root.expanded
        contentReady: root.expanded && root.stage >= 0
        scaleOriginX: root.panelScaleOriginX
        scaleOriginY: root.panelScaleOriginY
        panelY: root.panelActualY
        x: root.panelX
        width: root.panelWidth
        height: root.panelHeight

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton; onClicked: mouse.accepted = true }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.theme.panelPadding
            spacing: root.theme.itemSpacing + 4

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 118
                radius: root.theme.panelRadius
                color: root.theme.withAlpha(root.theme.foreground, 0.045)
                opacity: root.stage >= 0 ? 1 : 0
                transform: Translate { y: root.headerOffset }

                Behavior on opacity { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 260; spring: 4.8; damping: 0.88; mass: 0.9; epsilon: 0.001 } }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: parent.radius - 1
                    color: "transparent"
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: root.theme.withAlpha(root.theme.color4, 0.14) }
                        GradientStop { position: 0.46; color: root.theme.withAlpha(root.theme.color2, 0.045) }
                        GradientStop { position: 1.0; color: root.theme.withAlpha(root.theme.background, 0) }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 14

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            Layout.fillWidth: true
                            text: "CONTROL"
                            color: root.theme.withAlpha(root.theme.foreground, 0.48)
                            font.pixelSize: 9
                            font.bold: true
                            font.capitalization: Font.AllUppercase
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.greeting()
                            color: root.theme.foreground
                            font.pixelSize: 26
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.currentDate()
                            color: root.theme.withAlpha(root.theme.foreground, 0.58)
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }

                    ColumnLayout {
                        Layout.preferredWidth: 86
                        Layout.fillHeight: true
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: root.storeCount
                            color: root.storeCount > 0 ? root.theme.color4 : root.theme.withAlpha(root.theme.foreground, 0.50)
                            font.pixelSize: 38
                            font.bold: true
                            horizontalAlignment: Text.AlignRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "NOTICES"
                            color: root.theme.withAlpha(root.theme.foreground, 0.48)
                            font.pixelSize: 9
                            font.bold: true
                            horizontalAlignment: Text.AlignRight
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            radius: root.theme.controlRadius
                            color: clearArea.containsMouse ? root.theme.withAlpha(root.theme.color4, 0.12) : root.theme.withAlpha(root.theme.foreground, 0.055)
                            opacity: root.storeCount > 0 ? 1 : 0
                            scale: clearArea.pressed ? 0.96 : (clearArea.containsMouse ? 1.012 : 1)

                            Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250; spring: 4.6; damping: 0.78; mass: 0.9; epsilon: 0.001 } }
                            Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? 0 : 140; easing.type: Easing.OutCubic } }

                            Text {
                                anchors.centerIn: parent
                                text: "Clear"
                                color: root.theme.foreground
                                font.pixelSize: 11
                                font.bold: true
                            }

                            MouseArea {
                                id: clearArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: root.storeCount > 0
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (root.store) root.store.clearAll()
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 214
                spacing: root.theme.itemSpacing
                opacity: root.stage >= 2 ? 1 : 0
                transform: Translate { y: root.togglesOffset }
                Behavior on opacity { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 260; spring: 4.8; damping: 0.88; mass: 0.9; epsilon: 0.001 } }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.theme.itemSpacing
                    QuickToggleTile { theme: root.theme; iconSource: root.ccIconDir + (root.networkState.wifiConnected ? "wifi_tile.svg" : "wifi_tile_off.svg"); label: "WiFi"; sublabel: root.networkState.connected ? root.networkState.name : "Radio"; isActive: root.networkState.wifiConnected === true; delay: 80; motionToken: root.motionToken; onClicked: root.run([Services.Config.nmcliBin, "radio", "wifi", isActive ? "off" : "on"]) }
                    QuickToggleTile { theme: root.theme; iconSource: root.ccIconDir + (root.bluetoothPowered ? "bluetooth_tile.svg" : "bluetooth_tile_off.svg"); label: "Bluetooth"; sublabel: root.bluetoothPowered ? root.bluetoothAdapterName : "Offline"; isActive: root.bluetoothPowered === true; delay: 110; motionToken: root.motionToken; onClicked: root.toggleBluetooth() }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.theme.itemSpacing
                    QuickToggleTile { theme: root.theme; iconSource: root.ccIconDir + (root.sinkMuted ? "output_tile_off.svg" : "output_tile.svg"); label: "Output"; sublabel: root.sinkMuted ? "Muted" : "Mixer"; isActive: !root.sinkMuted; delay: 140; motionToken: root.motionToken; onClicked: { root.close(); if (root.rightPanelController) root.rightPanelController.toggle("audio") } }
                    QuickToggleTile { theme: root.theme; iconSource: root.ccIconDir + (root.micMuted ? "input_tile_off.svg" : "input_tile.svg"); label: "Input"; sublabel: root.micMuted ? "Muted" : "Open"; isActive: !root.micMuted; delay: 170; motionToken: root.motionToken; onClicked: micToggle.exec(micToggle.command) }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.theme.itemSpacing
                    QuickToggleTile { theme: root.theme; iconSource: root.ccIconDir + "wallpaper_tile.svg"; label: "Wallpaper"; sublabel: "Scene"; isActive: false; delay: 200; motionToken: root.motionToken; onClicked: root.run(["quickshell", "ipc", "call", "wallpaper", "toggle"]) }
                    QuickToggleTile { theme: root.theme; iconSource: root.ccIconDir + "power_tile.svg"; label: "Power"; sublabel: "Session"; isActive: false; danger: true; delay: 230; motionToken: root.motionToken; onClicked: root.run(Services.Config.powerMenuCommand) }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                spacing: 10
                opacity: root.stage >= 5 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(170 / 2) : 170; easing.type: Easing.OutCubic } }

                QuickAction { theme: root.theme; iconSource: root.ccIconDir + "screenshot_button.svg"; delay: 0; onActivated: root.run(["grimblast", "copy", "area"]) }
                QuickAction { theme: root.theme; iconSource: root.ccIconDir + "color_picker_button.svg"; tooltip: "Color picker"; delay: 20; onActivated: root.run(["hyprpicker"]) }
                QuickAction { theme: root.theme; iconSource: root.ccIconDir + "shortcuts_button.svg"; tooltip: "Shortcuts"; delay: 40; onActivated: root.run(["sh", "-c", "notify-send Shortcuts 'Overlay not wired yet'"]) }
                QuickAction { theme: root.theme; iconSource: root.ccIconDir + "night_mode_button.svg"; tooltip: "Night mode"; delay: 60; onActivated: { root.nightMode = !root.nightMode; root.run(["sh", "-c", "pkill -USR1 \"$1\" || \"$1\" &", "sh", Services.Config.gammastepBin]) } }
                Item { Layout.fillWidth: true }
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: root.commandError.length > 0 ? implicitHeight : 0
                visible: root.commandError.length > 0
                text: root.commandError
                color: root.theme.color1
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            MediaMiniCard {
                Layout.fillWidth: true
                theme: root.theme
                title: root.mediaTitle
                artist: root.mediaArtist
                art: root.mediaArt
                status: root.mediaStatus
                visible: root.mediaTitle.length > 0
                Layout.preferredHeight: visible ? 96 : 0
                opacity: root.stage >= 6 && visible ? 1 : 0
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: root.mediaError.length > 0 ? implicitHeight : 0
                visible: root.mediaError.length > 0
                text: root.mediaError
                color: root.theme.color1
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: root.audioError.length > 0 ? implicitHeight : 0
                visible: root.audioError.length > 0
                text: root.audioError
                color: root.theme.color1
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: notifColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                opacity: root.stage >= 7 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(170 / 2) : 170; easing.type: Easing.OutCubic } }

                Column {
                    id: notifColumn
                    width: parent.width
                    spacing: 10

                    Item {
                        width: parent.width
                        height: root.storeCount === 0 ? 170 : 0
                        opacity: root.storeCount === 0 ? 1 : 0
                        scale: root.storeCount === 0 ? 1 : 0.90
                        clip: true

                        Behavior on height { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.4; damping: 0.78; mass: 0.9; epsilon: 0.001 } }
                        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.4; damping: 0.76; mass: 0.9; epsilon: 0.001 } }
                        Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            Rectangle {
                                width: 64
                                height: 64
                                radius: 32
                                color: root.theme.withAlpha(root.theme.color4, 0.16)
                                anchors.horizontalCenter: parent.horizontalCenter
                                rotation: bellSway
                                Text { anchors.centerIn: parent; text: "󰂜"; color: root.theme.color4; font.pixelSize: 30 }
                                SequentialAnimation on bellSway {
                                    running: true
                                    loops: Animation.Infinite
                                    NumberAnimation { to: -3; duration: theme && theme.reducedMotion ? Math.round(1000 / 2) : 1000; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 3; duration: theme && theme.reducedMotion ? Math.round(1000 / 2) : 1000; easing.type: Easing.InOutSine }
                                }
                                property real bellSway: 0
                            }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "No notifications"; color: root.theme.foreground; font.pixelSize: 17; font.bold: true }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "You're all caught up"; color: root.theme.withAlpha(root.theme.foreground, 0.62); font.pixelSize: 13 }
                        }
                    }

                    Repeater {
                        model: root.storeCount
                        NotificationCard {
                            width: notifColumn.width
                            theme: root.theme
                            store: root.store
                            notification: root.notificationAt(index)
                            delay: 210 + index * 35
                        }
                    }
                }
            }
        }
    }

    Process {
        id: commandProcess
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { id: commandErr; waitForEnd: true }
        onExited: function(code) {
            if (code !== 0) {
                root.commandError = root.processError(commandErr.text, "Command failed")
                return
            }
            root.commandError = ""
        }
    }

    Process {
        id: mediaProbe
        command: [Services.Config.playerctlBin, "metadata", "--format", "{{title}}|{{artist}}|{{mpris:artUrl}}|{{status}}"]
        stdout: StdioCollector { id: mediaOut; waitForEnd: true }
        stderr: StdioCollector { id: mediaErr; waitForEnd: true }
        onExited: function(code) {
            if (code !== 0) {
                root.mediaTitle = ""
                root.mediaError = root.processError(mediaErr.text, "No active media player")
                return
            }
            root.mediaError = ""
            const parts = mediaOut.text.trim().split("|")
            root.mediaTitle = parts[0] || ""
            root.mediaArtist = parts[1] || ""
            root.mediaArt = parts[2] || ""
            root.mediaStatus = parts[3] || ""
        }
    }

    Process {
        id: bluetoothProbe
        command: [Services.Config.bluetoothctlBin, "show"]
        stdout: StdioCollector { id: bluetoothOut; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            if (code !== 0) {
                root.bluetoothPowered = false
                return
            }
            const text = bluetoothOut.text
            root.bluetoothPowered = /Powered:\s*yes/i.test(text)
            const nameMatch = /Name:\s*(.+)/i.exec(text)
            root.bluetoothAdapterName = nameMatch ? nameMatch[1].trim() : "Bluetooth"
        }
    }

    Process {
        id: micProbe
        command: [Services.Config.pactlBin, "get-source-mute", "@DEFAULT_SOURCE@"]
        stdout: StdioCollector { id: micOut; waitForEnd: true }
        stderr: StdioCollector { id: micErr; waitForEnd: true }
        onExited: function(code) {
            if (code === 0) {
                root.micMuted = micOut.text.toLowerCase().indexOf("yes") >= 0
                root.audioError = ""
            } else {
                root.audioError = root.processError(micErr.text, "Failed to read microphone state")
            }
        }
    }

    Process {
        id: micToggle
        command: [Services.Config.pactlBin, "set-source-mute", "@DEFAULT_SOURCE@", "toggle"]
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { id: micToggleErr; waitForEnd: true }
        onExited: function(code) {
            if (code !== 0)
                root.audioError = root.processError(micToggleErr.text, "Failed to toggle microphone")
            micProbe.exec(micProbe.command)
        }
    }

    Process {
        id: sinkProbe
        command: [Services.Config.pactlBin, "get-sink-mute", "@DEFAULT_SINK@"]
        stdout: StdioCollector { id: sinkOut; waitForEnd: true }
        stderr: StdioCollector { id: sinkErr; waitForEnd: true }
        onExited: function(code) {
            if (code === 0) {
                root.sinkMuted = sinkOut.text.toLowerCase().indexOf("yes") >= 0
                root.audioError = ""
            } else {
                root.audioError = root.processError(sinkErr.text, "Failed to read speaker state")
            }
        }
    }

    function toggle() {
        if (expanded)
            close()
        else
            open()
    }

    function toggleFromItem(item) {
        setAnchorFromItem(item)
        toggle()
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

    function open() {
        visible = true
        if (store) {
            if (typeof store.syncTrackedNotifications === "function")
                store.syncTrackedNotifications()
            refreshCenterCount()
            store.centerOpen = true
        }
        panel.resetEntrance()
        expanded = false
        motionToken++
        stage = -1
        headerOffset = 6
        togglesOffset = 6
        Services.BluetoothState.refresh()
        bluetoothProbe.exec(bluetoothProbe.command)
        closeTimer.stop()
        focusCatcher.forceActiveFocus()
        openDelay.restart()
    }

    function close() {
        expanded = false
        stage = -1
        if (store)
            store.centerOpen = false
        closeTimer.restart()
    }

    function run(command) {
        commandProcess.exec(command)
    }

    function toggleBluetooth() {
        const nextPowered = !bluetoothPowered
        bluetoothPowered = nextPowered
        Services.BluetoothState.setPower(nextPowered)
    }

    function processError(text, fallback) {
        const msg = String(text || "").trim()
        return msg.length > 0 ? msg : fallback
    }

    function loadState() {
        if (!stateService || !stateService.ready)
            return
        nightMode = stateService.value("nightMode", false) === true
    }

    function notificationAt(index) {
        if (!store || index < 0 || index >= storeCount)
            return null
        if (typeof store.centerItem === "function")
            return store.centerItem(index)
        return null
    }

    function refreshCenterCount() {
        storeCount = store ? store.historyCount : 0
    }

    function greeting() {
        const h = new Date().getHours()
        if (h < 12)
            return "Good morning"
        if (h < 18)
            return "Good afternoon"
        return "Good evening"
    }

    function currentDate() {
        return Qt.formatDateTime(new Date(), "ddd, MMM d")
    }

    component QuickAction: Item {
        id: action
        signal activated()
        property var theme
        property string icon: ""
        property string iconSource: ""
        property string tooltip: "Screenshot"
        property int delay: 0
        property bool appeared: false
        property bool hovered: area.containsMouse
        property bool checked: false

        Layout.preferredWidth: 52
        Layout.preferredHeight: 44
        scale: area.pressed ? 0.94 : (hovered ? 1.035 : (appeared ? 1 : 0.92))
        opacity: appeared ? 1 : 0

        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 260; spring: 5.2; damping: 0.82; mass: 0.85; epsilon: 0.001 } }
        Behavior on opacity { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 240; spring: 5.0; damping: 0.88; mass: 0.9; epsilon: 0.001 } }

        Timer { id: delayTimer; interval: action.delay + 220; repeat: false; onTriggered: action.appeared = true }
        Component.onCompleted: delayTimer.restart()

        Timer { id: tooltipDelay; interval: 400; repeat: false }
        Timer { id: checkTimer; interval: 600; repeat: false; onTriggered: action.checked = false }

        Rectangle {
            anchors.fill: actionPlate
            anchors.margins: action.hovered ? -4 : 0
            radius: actionPlate.radius + 4
            color: action.theme.withAlpha(action.theme.color4, action.hovered ? 0.10 : 0)
        }

        Rectangle {
            id: actionPlate
            anchors.fill: parent
            radius: action.theme.controlRadius
            color: action.hovered ? action.theme.withAlpha(action.theme.color4, 0.12) : action.theme.withAlpha(action.theme.foreground, 0.045)
            Behavior on color { ColorAnimation { duration: action.theme.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }
        }

        Image {
            id: quickActionIconSource
            visible: false
            anchors.centerIn: parent
            width: 19
            height: 19
            source: action.iconSource
            sourceSize.width: width
            sourceSize.height: height
            smooth: true
            mipmap: true
        }

        MultiEffect {
            visible: action.iconSource.length > 0 && !action.checked
            anchors.fill: quickActionIconSource
            source: quickActionIconSource
            colorization: 1
            colorizationColor: action.hovered ? action.theme.color4 : action.theme.foreground

            Behavior on colorizationColor { ColorAnimation { duration: theme && theme.reducedMotion ? 0 : 150; easing.type: Easing.OutCubic } }
        }

        Text {
            anchors.centerIn: parent
            visible: action.checked || action.iconSource.length === 0
            text: action.checked ? "✓" : action.icon
            color: action.checked || action.hovered ? action.theme.color4 : action.theme.foreground
            font.pixelSize: 17
            Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? 0 : 150; easing.type: Easing.OutCubic } }
        }

        Rectangle {
            width: tip.implicitWidth + 16
            height: 24
            radius: action.theme.controlRadius
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height + 6
            color: action.theme.withAlpha(action.theme.background, 0.94)
        border.width: action.theme.outerBorder ? action.theme.borderWidth : 0
        border.color: action.theme.withAlpha(action.theme.color4, action.theme.borderOpacity)
            opacity: tooltipDelay.running || !action.hovered ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(140 / 2) : 140; easing.type: Easing.OutCubic } }
            Text { id: tip; anchors.centerIn: parent; text: action.tooltip; color: action.theme.foreground; font.pixelSize: 11 }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: tooltipDelay.restart()
            onExited: tooltipDelay.stop()
            onClicked: {
                action.checked = true
                checkTimer.restart()
                action.activated()
            }
        }
    }

    component MediaMiniCard: Rectangle {
        id: media
        property var theme
        property string title: ""
        property string artist: ""
        property string art: ""
        property string status: ""
        property real progress: 0
        property real parallaxX: 0
        property real infoOffset: 0

        radius: theme.itemRadius
        color: theme.withAlpha(theme.color1, 0.18)
        clip: true
        Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(170 / 2) : 170; easing.type: Easing.OutCubic } }
        Behavior on height { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.4; damping: 0.76; mass: 0.9; epsilon: 0.001 } }

        Image { anchors.fill: parent; source: media.art; fillMode: Image.PreserveAspectCrop; opacity: 0.26; asynchronous: true; Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(260 / 2) : 260; easing.type: Easing.OutCubic } } }
        Rectangle { anchors.fill: parent; color: media.theme.withAlpha(media.theme.background, 0.58) }
        Rectangle { x: 12 + media.parallaxX; y: 12; width: 54; height: 54; radius: 27; color: media.theme.withAlpha(media.theme.color4, 0.18); clip: true; Image { anchors.fill: parent; source: media.art; fillMode: Image.PreserveAspectCrop; asynchronous: true; RotationAnimation on rotation { running: media.status === "Playing"; loops: Animation.Infinite; from: 0; to: 360; duration: theme && theme.reducedMotion ? Math.round(12000 / 2) : 12000 } } Behavior on x { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(120 / 2) : 120; easing.type: Easing.OutCubic } } }
        Text { x: 78 + media.infoOffset; y: 14; width: parent.width - 94; text: media.title; color: media.theme.foreground; font.family: media.theme.fontFamily; font.pixelSize: 14 * media.theme.fontScale; font.bold: media.theme.fontBold || true; elide: Text.ElideRight }
        Text { x: 78 + media.infoOffset; y: 34; width: parent.width - 94; text: media.artist; color: media.theme.withAlpha(media.theme.foreground, 0.62); font.family: media.theme.fontFamily; font.pixelSize: 12 * media.theme.fontScale; elide: Text.ElideRight }
        Rectangle { x: 78; y: 60; width: parent.width - 100; height: 4; radius: 2; color: media.theme.withAlpha(media.theme.foreground, 0.14); Rectangle { width: parent.width * media.progress; height: parent.height; radius: 2; color: media.theme.color4; Behavior on width { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(1000 / 2) : 1000; easing.type: Easing.Linear } } } }
        Row { x: 78; y: 70; spacing: 20; Text { text: "󰒮"; color: media.theme.foreground; font.pixelSize: 15 } Text { text: media.status === "Playing" ? "󰏤" : "󰐊"; color: media.theme.foreground; font.pixelSize: 17 } Text { text: "󰒭"; color: media.theme.foreground; font.pixelSize: 15 } }
        Timer { interval: 1000; repeat: true; running: media.status === "Playing"; onTriggered: media.progress = (media.progress + 0.015) % 1 }
        MouseArea { anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton; onPositionChanged: function(mouse) { media.parallaxX = (mouse.x / width - 0.5) * 6 }; onExited: media.parallaxX = 0 }
    }
}

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../widgets"
import "../../services" as Services

Item {
    id: root

    property var theme
    property int motionToken: 0
    property bool busy: false
    property string errorMessage: ""
    property string expandedAddress: ""
    property string connectingAddress: ""
    property int connectDots: 1
    property int stage: -1
    property var devices: []
    readonly property string iconDir: Quickshell.env("HOME") + "/.config/shells/assets/icons/panel/bluetooth/"
    readonly property int emptyStateHeight: 196
    readonly property bool powered: Services.BluetoothState.powered
    readonly property bool powerTransitioning: Services.BluetoothState.powerTransitioning
    readonly property bool discovering: Services.BluetoothState.discovering
    readonly property string adapterName: Services.BluetoothState.adapterName
    readonly property bool hasConnected: connectedName.length > 0
    readonly property string connectedName: connectedDeviceName()
    readonly property int nearbyCount: countNearby()
    readonly property int pairedCount: countPaired()
    readonly property bool scanning: discovering
    readonly property int contentHeight: contentColumn.implicitHeight

    implicitWidth: parent ? parent.width : 360
    implicitHeight: contentHeight
    height: implicitHeight

    onMotionTokenChanged: {
        stage = -1
        stageTimer.restart()
        Services.BluetoothState.refresh()
        refreshAll()
    }

    Component.onCompleted: {
        stageTimer.restart()
        Services.BluetoothState.refresh()
        refreshAll()
    }

    Connections {
        target: Services.BluetoothState
        function onPoweredChanged() {
            if (!Services.BluetoothState.powered)
                root.devices = []
            root.refreshAll()
        }
    }

    Timer {
        id: stageTimer
        interval: 35
        repeat: true
        onTriggered: {
            root.stage++
            if (root.stage >= 4)
                stop()
        }
    }

    Timer {
        id: pollTimer
        interval: 3000
        running: !root.powerTransitioning
        repeat: true
        triggeredOnStart: false
        onTriggered: root.refreshAll()
    }

    Timer {
        id: connectingTextTimer
        interval: 400
        running: root.connectingAddress.length > 0
        repeat: true
        onTriggered: root.connectDots = root.connectDots >= 3 ? 1 : root.connectDots + 1
    }

    Column {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 12

        Rectangle {
            id: headerCard
            width: parent.width
            height: 100
            radius: root.theme.panelRadius
            opacity: root.stage >= 0 ? 1 : 0
            clip: true
            color: root.theme.withAlpha(root.theme.foreground, 0.045)

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.theme.withAlpha(root.theme.color4, 0.14) }
                GradientStop { position: 0.58; color: root.theme.withAlpha(root.theme.foreground, 0.045) }
                GradientStop { position: 1.0; color: root.theme.withAlpha(root.theme.color0, 0.18) }
            }

            Behavior on opacity { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 170; easing.type: Easing.OutCubic } }

            Row {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 14

                SvgIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    theme: root.theme
                    sourcePath: root.powered ? (root.hasConnected ? root.iconDir + "bluetooth_connected.svg" : root.iconDir + "bluetooth.svg") : root.iconDir + "bluetooth_disconnected.svg"
                    iconColor: root.powered ? root.theme.color4 : root.theme.color6
                    iconSize: 42
                    tonal: true
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 122
                    spacing: 5

                    Text {
                        text: "BLUETOOTH"
                        color: root.theme.color6
                        font.family: root.theme.fontFamily
                        font.pixelSize: 9 * root.theme.fontScale
                        font.bold: true
                        opacity: 0.82
                    }

                    Text {
                        text: root.powered ? (root.hasConnected ? "Connected" : "On") : "Off"
                        color: root.theme.foreground
                        font.family: root.theme.fontFamily
                        font.pixelSize: 22 * root.theme.fontScale
                        font.bold: true
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    Text {
                        text: root.hasConnected ? root.connectedName : (root.powered ? root.adapterName : "Turn on to see devices")
                        color: root.theme.color6
                        font.family: root.theme.fontFamily
                        font.pixelSize: 12 * root.theme.fontScale
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }

                M3Switch {
                    anchors.verticalCenter: parent.verticalCenter
                    theme: root.theme
                    primary: root.theme.color4
                    checked: root.powered
                    onToggled: root.setPower(!root.powered)
                }
            }
        }

        Rectangle {
            id: scanCard
            width: parent.width
            height: 44
            radius: root.theme.itemRadius
            opacity: root.powered ? (root.stage >= 1 ? 1 : 0) : 0.38
            color: root.theme.withAlpha(root.theme.foreground, 0.035)

            Behavior on opacity { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 170; easing.type: Easing.OutCubic } }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                spacing: 10

                Row {
                    id: scanDots
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Repeater {
                        model: 3
                        Rectangle {
                            width: 5
                            height: 5
                            radius: 3
                            color: root.theme.color4
                            opacity: root.scanning ? 0.3 : 0.45

                            SequentialAnimation on opacity {
                                running: root.scanning && !(root.theme && root.theme.reducedMotion)
                                loops: Animation.Infinite
                                PauseAnimation { duration: index * 100 }
                                NumberAnimation { to: 1; duration: 260; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0.3; duration: 260; easing.type: Easing.InOutSine }
                                PauseAnimation { duration: 300 }
                            }
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(118, parent.width - scanDots.width - nearbyChip.width - scanButton.width - 30)
                    text: root.scanning ? "Scanning..." : "Scan for devices"
                    color: root.powered ? root.theme.foreground : root.theme.color6
                    font.family: root.theme.fontFamily
                    font.pixelSize: 13 * root.theme.fontScale
                    elide: Text.ElideRight
                }

                Rectangle {
                    id: nearbyChip
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.nearbyCount > 0 ? nearbyText.implicitWidth + 16 : 0
                    height: 24
                    radius: 12
                    visible: opacity > 0
                    opacity: root.nearbyCount > 0 ? 1 : 0
                    color: root.theme.withAlpha(root.theme.color4, 0.12)

                    Behavior on opacity { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }

                    Text {
                        id: nearbyText
                        anchors.centerIn: parent
                        text: "+" + root.nearbyCount + " nearby"
                        color: root.theme.color4
                        font.family: root.theme.fontFamily
                        font.pixelSize: 10 * root.theme.fontScale
                        font.bold: true
                    }
                }

                Rectangle {
                    id: scanButton
                    anchors.verticalCenter: parent.verticalCenter
                    width: 58
                    height: 28
                    radius: 14
                    color: root.theme.withAlpha(root.theme.color4, root.powered ? 0.15 : 0.05)
                    scale: scanArea.pressed ? 0.96 : (scanArea.containsMouse ? 1.04 : 1)

                    Behavior on scale { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 220; spring: 5.4; damping: 0.72; mass: 0.9; epsilon: 0.001 } }

                    Text {
                        anchors.centerIn: parent
                        text: root.scanning ? "Stop" : "Scan"
                        color: root.powered ? root.theme.color4 : root.theme.color6
                        font.family: root.theme.fontFamily
                        font.pixelSize: 11 * root.theme.fontScale
                        font.bold: true
                    }

                    MouseArea {
                        id: scanArea
                        anchors.fill: parent
                        enabled: root.powered
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setScan(!root.scanning)
                    }
                }
            }
        }

        Item {
            id: listWrap
            width: parent.width
            height: root.devices.length === 0 ? root.emptyStateHeight : Math.min(320, Math.max(root.emptyStateHeight, deviceColumn.implicitHeight))
            opacity: root.stage >= 2 ? (root.powered ? 1 : 0.95) : 0
            clip: true

            Behavior on height { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 320; spring: 4.4; damping: 0.78; mass: 0.9; epsilon: 0.001 } }
            Behavior on opacity { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 170; easing.type: Easing.OutCubic } }

            Flickable {
                id: deviceViewport
                anchors.fill: parent
                clip: true
                contentHeight: deviceColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: deviceColumn
                    width: deviceViewport.width
                    spacing: 8

                    Repeater {
                        model: root.powered ? root.displayRows() : []

                        delegate: Loader {
                            width: deviceColumn.width
                            height: rowData.section ? 28 : (root.expandedAddress === rowData.address ? 104 : 56)
                            sourceComponent: modelData.section ? sectionDelegate : deviceDelegate
                            property var rowData: modelData

                            Behavior on height {
                                SpringAnimation {
                                    duration: root.theme && root.theme.reducedMotion ? 0 : 340
                                    spring: 4.4
                                    damping: 0.76
                                    mass: 0.9
                                    epsilon: 0.001
                                }
                            }
                        }
                    }
                }
            }

            Loader {
                anchors.fill: parent
                active: !root.powered || (root.powered && root.devices.length === 0)
                sourceComponent: !root.powered ? offEmptyState : (root.scanning ? scanningEmptyState : noDevicesEmptyState)
            }
        }
    }

    Component {
        id: sectionDelegate
        Item {
            width: deviceViewport.width
            height: 28
            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Text {
                    text: rowData.label
                    color: root.theme.color6
                    font.family: root.theme.fontFamily
                    font.pixelSize: 9 * root.theme.fontScale
                    font.bold: true
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 1
                    width: parent.width - 74
                    color: root.theme.withAlpha(root.theme.color6, 0.18)
                }
            }
        }
    }

    Component {
        id: deviceDelegate
        Item {
            id: row
            width: deviceViewport.width
            height: root.expandedAddress === rowData.address ? 104 : 56
            opacity: root.powered ? 1 : 0.4
            property bool hovered: rowArea.containsMouse
            property bool connecting: root.connectingAddress === rowData.address
            property string statusText: connecting ? ("Connecting" + ".".repeat(root.connectDots)) : (rowData.connected ? "Connected" : (rowData.paired ? "Paired" : "Available"))
            property real shakeOffset: 0

            Behavior on height { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 340; spring: 4.4; damping: 0.76; mass: 0.9; epsilon: 0.001 } }
            Behavior on opacity { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                radius: root.theme.itemRadius
                color: row.hovered || root.expandedAddress === rowData.address ? root.theme.withAlpha(root.theme.color4, 0.08) : "transparent"
                scale: rowArea.pressed ? 0.985 : 1
                x: row.shakeOffset

                Behavior on color { ColorAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 150; easing.type: Easing.OutCubic } }
                Behavior on scale { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 220; spring: 5.4; damping: 0.72; mass: 0.9; epsilon: 0.001 } }

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.expandedAddress = root.expandedAddress === rowData.address ? "" : rowData.address
                }

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    anchors.leftMargin: 10
                    anchors.rightMargin: 12
                    spacing: 10

                    SvgIcon {
                        theme: root.theme
                        sourcePath: rowData.connected ? root.iconDir + "bluetooth_connected.svg" : (rowData.paired ? root.iconDir + "bluetooth.svg" : root.iconDir + "bluetooth_searching.svg")
                        iconColor: rowData.connected ? root.theme.color4 : root.theme.color6
                        iconSize: 32
                        tonal: true
                    }

                    Column {
                        width: parent.width - 92
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: rowData.name
                            color: root.theme.foreground
                            font.family: root.theme.fontFamily
                            font.pixelSize: 13 * root.theme.fontScale
                            font.bold: true
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        Text {
                            text: rowData.battery >= 0 ? (row.statusText + " • " + rowData.battery + "% battery") : row.statusText
                            color: root.theme.color6
                            font.family: root.theme.fontFamily
                            font.pixelSize: 11 * root.theme.fontScale
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20

                        BusyIndicator {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            running: row.connecting
                            visible: row.connecting
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 8
                            height: 8
                            radius: 4
                            visible: !row.connecting && (rowData.connected || rowData.paired)
                            color: rowData.connected ? root.theme.color4 : root.theme.withAlpha(root.theme.color6, 0.4)
                            scale: rowData.connected ? 1 : 0.8
                            Behavior on scale { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 260; spring: 6.0; damping: 0.58; mass: 0.85; epsilon: 0.001 } }
                        }
                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 52
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 10
                    spacing: 8
                    opacity: root.expandedAddress === rowData.address ? 1 : 0
                    y: root.expandedAddress === rowData.address ? 0 : 4

                    Behavior on opacity { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }
                    Behavior on y { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : 220; spring: 4.8; damping: 0.78; mass: 0.9; epsilon: 0.001 } }

                    ActionPill {
                        theme: root.theme
                        label: rowData.connected ? "Disconnect" : (rowData.paired ? "Connect" : "Pair & Connect")
                        filled: true
                        accent: root.theme.color4
                        enabled: !row.connecting
                        onClicked: rowData.connected ? root.disconnectDevice(rowData.address) : root.connectDevice(rowData.address)
                    }

                    ActionPill {
                        theme: root.theme
                        label: "Forget"
                        filled: false
                        accent: root.theme.color1
                        visible: rowData.paired
                        onClicked: root.removeDevice(rowData.address)
                    }
                }
            }

            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: row; property: "shakeOffset"; to: -8; duration: 45; easing.type: Easing.OutCubic }
                NumberAnimation { target: row; property: "shakeOffset"; to: 7; duration: 55; easing.type: Easing.OutCubic }
                NumberAnimation { target: row; property: "shakeOffset"; to: -4; duration: 55; easing.type: Easing.OutCubic }
                NumberAnimation { target: row; property: "shakeOffset"; to: 0; duration: 70; easing.type: Easing.OutCubic }
            }

            Connections {
                target: root
                function onConnectingAddressChanged() {
                    if (root.connectingAddress === "" && rowData.address === root.expandedAddress && root.errorMessage.length > 0)
                        shakeAnim.restart()
                }
            }
        }
    }

    Component {
        id: offEmptyState
        EmptyState {
            theme: root.theme
            iconPath: root.iconDir + "bluetooth_disconnected.svg"
            title: "Bluetooth is off"
            subtitle: "Turn on to see devices"
            buttonLabel: "Turn On"
            onAction: root.setPower(true)
        }
    }

    Component {
        id: noDevicesEmptyState
        EmptyState {
            theme: root.theme
            iconPath: root.iconDir + "bluetooth.svg"
            title: "No paired devices"
            subtitle: "Scan to find nearby devices"
            buttonLabel: "Scan"
            onAction: root.setScan(true)
        }
    }

    Component {
        id: scanningEmptyState
        Item {
            anchors.fill: parent

            Item {
                id: radar
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 18
                width: 126
                height: 96

                Repeater {
                    model: 3
                    Rectangle {
                        anchors.centerIn: parent
                        width: 44 + index * 22
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: root.theme.withAlpha(root.theme.color4, 0.28)
                        opacity: 0
                        scale: 0.72

                        SequentialAnimation {
                            running: root.scanning && !(root.theme && root.theme.reducedMotion)
                            loops: Animation.Infinite
                            PauseAnimation { duration: index * 420 }
                            ParallelAnimation {
                                NumberAnimation { target: parent; property: "scale"; from: 0.72; to: 1.18; duration: 1500; easing.type: Easing.OutCubic }
                                NumberAnimation { target: parent; property: "opacity"; from: 0.34; to: 0; duration: 1500; easing.type: Easing.OutCubic }
                            }
                            PauseAnimation { duration: 260 }
                        }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 76
                    height: 76
                    radius: 38
                    color: root.theme.withAlpha(root.theme.color4, 0.045)
                }

                Rectangle {
                    id: sweep
                    anchors.centerIn: parent
                    width: 88
                    height: 88
                    radius: 44
                    color: "transparent"
                    border.width: 1
                    border.color: root.theme.withAlpha(root.theme.color4, 0.16)

                    Rectangle {
                        width: 42
                        height: 2
                        radius: 1
                        anchors.left: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.theme.withAlpha(root.theme.color4, 0.55)
                    }

                    RotationAnimation on rotation {
                        running: root.scanning && !(root.theme && root.theme.reducedMotion)
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 2200
                        easing.type: Easing.InOutSine
                    }
                }

                SvgIcon {
                    anchors.centerIn: parent
                    theme: root.theme
                    sourcePath: root.iconDir + "bluetooth_searching.svg"
                    iconColor: root.theme.color4
                    iconSize: 34
                    tonal: true
                    scale: root.scanning ? 1.04 : 1

                    SequentialAnimation on scale {
                        running: root.scanning && !(root.theme && root.theme.reducedMotion)
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.08; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                    }
                }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: radar.bottom
                anchors.topMargin: 4
                spacing: 7

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Looking for devices..."
                    color: root.theme.foreground
                    font.family: root.theme.fontFamily
                    font.pixelSize: 15 * root.theme.fontScale
                    font.bold: true
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Nearby devices will appear here"
                    color: root.theme.color6
                    font.family: root.theme.fontFamily
                    font.pixelSize: 12 * root.theme.fontScale
                }
            }
        }
    }

    Process {
        id: devicesProbe
        command: ["sh", "-c", Services.Config.bluetoothctlBin + " devices | while read -r kind mac name; do [ -n \"$mac\" ] || continue; echo \"DEVICE $mac $name\"; " + Services.Config.bluetoothctlBin + " info \"$mac\"; echo END_DEVICE; done"]
        stdout: StdioCollector { id: devicesOut; waitForEnd: true }
        stderr: StdioCollector { id: devicesErr; waitForEnd: true }
        onExited: function(code) {
            if (code !== 0) {
                root.errorMessage = root.processError(devicesErr.text, "Failed to list Bluetooth devices")
                return
            }
            root.devices = root.parseDevices(devicesOut.text)
        }
    }

    Process {
        id: operationProcess
        stdout: StdioCollector { id: operationOut; waitForEnd: true }
        stderr: StdioCollector { id: operationErr; waitForEnd: true }
        onExited: function(code) {
            root.busy = false
            if (root.connectingAddress.length > 0)
                root.connectingAddress = ""
            if (code !== 0)
                root.errorMessage = root.processError(operationErr.text, "Bluetooth command failed")
            refreshDelay.restart()
        }
    }

    Timer {
        id: refreshDelay
        interval: 450
        repeat: false
        onTriggered: root.refreshAll()
    }

    function refreshAll() {
        if (root.powerTransitioning || !root.powered)
            return
        devicesProbe.exec(devicesProbe.command)
    }

    function setPower(enabled) {
        root.errorMessage = ""
        Services.BluetoothState.setPower(enabled)
        if (!enabled) {
            root.devices = []
        }
    }

    function setScan(enabled) {
        if (!root.powered && enabled)
            return
        operationProcess.exec([Services.Config.bluetoothctlBin, "scan", enabled ? "on" : "off"])
        Services.BluetoothState.setDiscovering(enabled)
    }

    function connectDevice(address) {
        root.connectingAddress = address
        root.connectDots = 1
        operationProcess.exec([Services.Config.bluetoothctlBin, "connect", address])
    }

    function disconnectDevice(address) {
        operationProcess.exec([Services.Config.bluetoothctlBin, "disconnect", address])
    }

    function removeDevice(address) {
        operationProcess.exec([Services.Config.bluetoothctlBin, "remove", address])
        if (expandedAddress === address)
            expandedAddress = ""
    }

    function parseDevices(text) {
        const parsed = []
        const blocks = String(text || "").split("END_DEVICE")
        for (let i = 0; i < blocks.length; i++) {
            const block = blocks[i].trim()
            if (block.length === 0)
                continue
            const header = /^DEVICE\s+([0-9A-F:]+)\s+(.+)$/im.exec(block)
            if (!header)
                continue
            const battery = /Battery (?:Percentage|Level):.*\((\d+)\)/i.exec(block) || /Battery:\s*(\d+)%/i.exec(block)
            parsed.push({
                address: header[1],
                name: header[2].trim(),
                connected: /Connected:\s*yes/i.test(block),
                paired: /Paired:\s*yes/i.test(block),
                trusted: /Trusted:\s*yes/i.test(block),
                battery: battery ? Number(battery[1]) : -1
            })
        }
        return parsed
    }

    function displayRows() {
        const paired = []
        const nearby = []
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].paired || devices[i].connected)
                paired.push(devices[i])
            else
                nearby.push(devices[i])
        }

        const rows = []
        if (paired.length > 0) {
            rows.push({ section: true, label: "PAIRED" })
            for (let p = 0; p < paired.length; p++)
                rows.push(paired[p])
        }
        if (nearby.length > 0) {
            rows.push({ section: true, label: "NEARBY" })
            for (let n = 0; n < nearby.length; n++)
                rows.push(nearby[n])
        }
        return rows
    }

    function connectedDeviceName() {
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].connected)
                return devices[i].name
        }
        return ""
    }

    function countNearby() {
        let count = 0
        for (let i = 0; i < devices.length; i++) {
            if (!devices[i].paired && !devices[i].connected)
                count++
        }
        return count
    }

    function countPaired() {
        let count = 0
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].paired || devices[i].connected)
                count++
        }
        return count
    }

    function processError(text, fallback) {
        const msg = String(text || "").trim()
        return msg.length > 0 ? msg : fallback
    }

    component SvgIcon: Item {
        id: icon
        property var theme
        property string sourcePath: ""
        property color iconColor: "white"
        property int iconSize: 24
        property bool tonal: false

        width: tonal ? iconSize + 12 : iconSize
        height: width

        Rectangle {
            anchors.fill: parent
            radius: 10
            visible: icon.tonal
            color: icon.theme.withAlpha(icon.iconColor, 0.13)
        }

        Image {
            id: svgSource
            anchors.centerIn: parent
            width: icon.iconSize
            height: icon.iconSize
            source: icon.sourcePath
            sourceSize.width: width
            sourceSize.height: height
            smooth: true
            mipmap: true
            visible: false
        }

        MultiEffect {
            anchors.fill: svgSource
            source: svgSource
            colorization: 1
            colorizationColor: icon.iconColor
            Behavior on colorizationColor { ColorAnimation { duration: icon.theme && icon.theme.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }
        }
    }

    component ActionPill: Rectangle {
        id: pill
        property var theme
        property string label: ""
        property bool filled: false
        property color accent: theme.color4
        signal clicked()

        width: labelText.implicitWidth + 26
        height: 30
        radius: 15
        color: filled ? theme.withAlpha(accent, 0.18) : "transparent"
        border.width: filled ? 0 : (theme.outerBorder ? theme.borderWidth : 1)
        border.color: theme.withAlpha(accent, 0.35)
        scale: area.pressed ? 0.96 : (area.containsMouse ? 1.04 : 1)
        opacity: enabled ? 1 : 0.45

        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 220; spring: 5.2; damping: 0.72; mass: 0.9; epsilon: 0.001 } }
        Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? 0 : 140; easing.type: Easing.OutCubic } }

        Text {
            id: labelText
            anchors.centerIn: parent
            text: pill.label
            color: pill.accent
            font.family: pill.theme.fontFamily
            font.pixelSize: 11 * pill.theme.fontScale
            font.bold: true
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: pill.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    component EmptyState: Item {
        id: empty
        property var theme
        property string iconPath: ""
        property string title: ""
        property string subtitle: ""
        property string buttonLabel: ""
        signal action()

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: empty.buttonLabel.length > 0 ? -2 : 0
            spacing: 8

            SvgIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                theme: empty.theme
                sourcePath: empty.iconPath
                iconColor: empty.theme.color4
                iconSize: 38
                tonal: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: empty.title
                color: empty.theme.foreground
                font.family: empty.theme.fontFamily
                font.pixelSize: 15 * empty.theme.fontScale
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: empty.subtitle
                color: empty.theme.color6
                font.family: empty.theme.fontFamily
                font.pixelSize: 12 * empty.theme.fontScale
            }

            Item {
                width: 1
                height: empty.buttonLabel.length > 0 ? 6 : 0
            }

            ActionPill {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: empty.buttonLabel.length > 0
                theme: empty.theme
                label: empty.buttonLabel
                filled: true
                accent: empty.theme.color4
                onClicked: empty.action()
            }
        }
    }
}

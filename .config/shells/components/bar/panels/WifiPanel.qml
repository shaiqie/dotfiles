import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../widgets"
import "../../services" as Services

Column {
    id: root

    property var theme
    property color m3Primary: theme.color4
    property color m3Surface: theme.withAlpha(theme.foreground, 0.052)
    property color m3OnSurface: theme.foreground
    property color m3Secondary: theme.withAlpha(theme.foreground, 0.62)
    property color m3Error: theme.color1
    property bool nmcliAvailable: true
    property bool wifiEnabled: true
    property bool loading: false
    property string wifiDeviceName: "wlan0"
    property string expandedSsid: ""
    property string connectingSsid: ""
    property string errorSsid: ""
    property string errorMessage: ""
    property int selectedIndex: 0
    property string action: ""
    property string actionSsid: ""
    property bool actionAutoconnect: false
    property bool actionUsesSavedConnection: false
    property var savedConnectionNames: ({})
    property int motionToken: 0
    property int stage: -1
    property real headerOffset: 6
    property real bodyOffset: 6
    readonly property string wifiIconDir: Quickshell.env("HOME") + "/.config/shells/assets/icons/panel/wifi/"

    spacing: theme ? theme.itemSpacing + 2 : 12
    width: parent ? parent.width : 360
    focus: true

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Down) {
            selectedIndex = Math.min(networkModel.count - 1, selectedIndex + 1)
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            selectedIndex = Math.max(0, selectedIndex - 1)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            activateSelectedNetwork()
            event.accepted = true
        } else if (event.key === Qt.Key_Tab) {
            selectedIndex = networkModel.count > 0 ? (selectedIndex + 1) % networkModel.count : 0
            event.accepted = true
        }
    }

    Behavior on headerOffset { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.4; damping: 0.78; mass: 0.9; epsilon: 0.001 } }
    Behavior on bodyOffset { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.4; damping: 0.78; mass: 0.9; epsilon: 0.001 } }

    Component.onCompleted: {
        refresh()
        restartStagger()
    }

    onMotionTokenChanged: restartStagger()

    Timer {
        id: staggerTimer
        interval: 35
        repeat: true
        onTriggered: {
            root.stage++
            if (root.stage === 0)
                root.headerOffset = 0
            else if (root.stage === 1)
                root.bodyOffset = 0
            if (root.stage >= 1)
                stop()
        }
    }

    Timer {
        interval: 20000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Row {
        width: parent.width
        height: 58
        opacity: root.stage >= 0 ? 1 : 0
        transform: Translate { y: root.headerOffset }
        spacing: 12

        Behavior on opacity { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 230; spring: 4.8; damping: 0.88; mass: 0.9; epsilon: 0.001 } }

        Rectangle {
            width: 44
            height: 44
            radius: root.theme.controlRadius
            anchors.verticalCenter: parent.verticalCenter
            color: root.theme.withAlpha(root.m3Primary, root.wifiEnabled ? 0.14 : 0.06)

            WifiSvgIcon {
                anchors.centerIn: parent
                theme: root.theme
                sourcePath: root.wifiIconDir + "wifi.svg"
                iconColor: root.wifiEnabled ? root.m3Primary : root.m3Secondary
                iconSize: 24
            }
        }

        Column {
            width: parent.width - 44 - 12 - 92
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                text: "Network"
                color: root.m3OnSurface
                font.pixelSize: 22
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.loading ? "Scanning nearby signals" : (root.wifiEnabled ? networkModel.count + " networks visible" : "Radio disabled")
                color: root.m3Secondary
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        M3Switch {
            theme: root.theme
            checked: root.wifiEnabled
            anchors.verticalCenter: parent.verticalCenter
            onToggled: root.setWifi(checked)
        }

        WifiSvgIcon {
            visible: root.loading
            anchors.verticalCenter: parent.verticalCenter
            theme: root.theme
            sourcePath: root.wifiIconDir + "wifi_refresh.svg"
            iconColor: root.m3Primary
            iconSize: 18
            spinning: root.loading
        }
    }

    Item {
        width: parent.width
        height: !root.nmcliAvailable || !root.wifiEnabled || (!root.loading && networkModel.count === 0) ? 148 : 0
        visible: height > 0
        clip: true
        opacity: root.stage >= 1 ? 1 : 0
        transform: Translate { y: root.bodyOffset }

        Behavior on height { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.4; damping: 0.76; mass: 0.9; epsilon: 0.001 } }
        Behavior on opacity { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 230; spring: 4.8; damping: 0.88; mass: 0.9; epsilon: 0.001 } }

        Column {
            anchors.centerIn: parent
            width: parent.width
            spacing: 12

            WifiSvgIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                theme: root.theme
                sourcePath: root.wifiIconDir + "wifi.svg"
                iconColor: root.m3Primary
                iconSize: 34
            }

            Text {
                width: parent.width
                text: root.errorMessage.length > 0 ? root.errorMessage : (!root.nmcliAvailable ? "NetworkManager not available" : (!root.wifiEnabled ? "WiFi is disabled" : "No networks in range"))
                color: root.m3OnSurface
                font.pixelSize: 16
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                PillButton {
                    theme: root.theme
                    text: !root.nmcliAvailable ? "Refresh" : (!root.wifiEnabled ? "Enable WiFi" : "Refresh")
                    width: 128
                    onClicked: root.wifiEnabled ? root.refresh() : root.setWifi(true)
                }
            }
        }
    }

    Flickable {
        width: parent.width
        height: root.nmcliAvailable && root.wifiEnabled ? Math.min(listColumn.implicitHeight, 366) : 0
        contentHeight: listColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        opacity: root.stage >= 1 ? 1 : 0
        transform: Translate { y: root.bodyOffset }

        Behavior on height { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.4; damping: 0.76; mass: 0.9; epsilon: 0.001 } }
        Behavior on opacity { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 230; spring: 4.8; damping: 0.88; mass: 0.9; epsilon: 0.001 } }

        Column {
            id: listColumn
            width: parent.width
            spacing: 4

            Repeater {
                model: networkModel

                Rectangle {
                    id: rowRoot

                    property string rowSsid: ssid
                    property int rowIndex: index
                    property int rowSignal: strength
                    property string rowSecurity: security
                    property bool rowConnected: inUse
                    property bool rowKnown: known
                    property bool rowExpanded: root.expandedSsid === rowSsid
                    property bool rowSelected: root.selectedIndex === rowIndex
                    property bool rowConnecting: root.connectingSsid === rowSsid
                    property bool rowSecure: rowSecurity.length > 0 && rowSecurity !== "--"
                    property bool rowNeverConnected: !rowConnected && !rowKnown
                    property bool showPassword: false
                    property bool autoconnect: true
                    property string confirmAction: ""
                    property bool rowContentReady: false
                    property real rowOffset: 6

                    width: listColumn.width
                    height: 54 + (rowExpanded ? expandedBox.implicitHeight + 12 : 0)
                    radius: root.theme.controlRadius
                    clip: true
                    color: headerArea.pressed ? root.theme.withAlpha(root.m3Primary, 0.10)
                        : (headerArea.containsMouse || rowExpanded || rowSelected ? root.theme.withAlpha(root.m3Primary, 0.055) : "transparent")
                    border.width: root.theme.outerBorder ? root.theme.borderWidth : 0
                    border.color: root.theme.withAlpha(rowConnected || rowSelected ? root.m3Primary : root.theme.color1, rowSelected ? 0.36 : 0.18)

                    Behavior on height { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.8; damping: 0.72; mass: 0.9; epsilon: 0.001 } }
                    Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(130 / 2) : 130; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: rowConnected ? root.theme.withAlpha(root.m3Primary, 0.08) : "transparent"
                        opacity: rowConnected || rowSelected ? 1 : 0

                        Behavior on opacity { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 260; spring: 4.8; damping: 0.86; mass: 0.9; epsilon: 0.001 } }
                    }

                    onRowExpandedChanged: {
                        if (!rowExpanded) {
                            confirmAction = ""
                            showPassword = false
                            rowContentReady = false
                            rowOffset = 6
                            rowDelay.stop()
                        } else {
                            rowContentReady = false
                            rowOffset = 6
                            rowDelay.restart()
                        }
                    }

                    Behavior on rowOffset { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.2; damping: 0.78; mass: 0.9; epsilon: 0.001 } }

                    Timer {
                        id: rowDelay
                        interval: 75
                        repeat: false
                        onTriggered: {
                            rowRoot.rowContentReady = true
                            rowRoot.rowOffset = 0
                        }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.margins: 7
                        spacing: 8

                        Row {
                            width: parent.width
                            height: 40
                            spacing: 12

                            Item {
                                width: 38
                                height: 38
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: root.theme.controlRadius
                                    color: root.theme.withAlpha(rowConnected ? root.m3Primary : root.theme.color1, rowConnected ? 0.13 : 0.08)
                                }

                                WifiSvgIcon {
                                    anchors.centerIn: parent
                                    theme: root.theme
                                    sourcePath: root.signalIconSource(rowSignal)
                                    iconColor: root.m3Primary
                                    iconSize: 24
                                }

                                Rectangle {
                                    visible: rowSecure
                                    width: 15
                                    height: 15
                                    radius: 8
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    color: root.theme.background
                                    border.width: root.theme.outerBorder ? root.theme.borderWidth : 0
                                    border.color: root.theme.withAlpha(root.m3Primary, root.theme.borderOpacity)

                                    WifiSvgIcon {
                                        anchors.centerIn: parent
                                        theme: root.theme
                                        sourcePath: root.wifiIconDir + "wifi_item_locked.svg"
                                        iconColor: root.m3Primary
                                        iconSize: 11
                                    }
                                }
                            }

                            Column {
                                width: parent.width - 150
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: rowSsid
                                    color: root.m3OnSurface
                                    font.pixelSize: 14
                                    font.bold: rowConnected
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: rowConnected ? "Connected" : (rowKnown ? "Saved network" : (rowSecure ? rowSecurity : "Open network"))
                                    color: rowConnected ? root.m3Primary : root.m3Secondary
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 4
                                    radius: 2
                                    color: root.theme.withAlpha(root.theme.foreground, 0.06)
                                    clip: true

                                    Rectangle {
                                        width: parent.width * Math.max(0.04, Math.min(1, rowSignal / 100))
                                        height: parent.height
                                        radius: 2
                                        color: root.theme.withAlpha(rowConnected ? root.m3Primary : root.theme.color4, rowConnected ? 0.90 : 0.54)

                                        Behavior on width {
                                            SpringAnimation { duration: root.theme.reducedMotion ? 0 : 280; spring: 4.8; damping: 0.84; mass: 0.9; epsilon: 0.001 }
                                        }
                                    }
                                }
                            }

                            Text {
                                width: 50
                                text: rowSignal + "%"
                                color: root.m3Secondary
                                font.pixelSize: 11
                                horizontalAlignment: Text.AlignRight
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                width: 22
                                text: rowExpanded ? "⌃" : "⌄"
                                color: root.m3Secondary
                                font.pixelSize: 16
                                horizontalAlignment: Text.AlignHCenter
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Column {
                            id: expandedBox
                            width: parent.width
                            spacing: 10
                            opacity: rowContentReady ? 1 : 0
                            transform: Translate { y: rowRoot.rowOffset }

                            Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(160 / 2) : 160; easing.type: Easing.OutCubic } }

                            Item {
                                width: parent.width
                                height: rowNeverConnected ? 48 : 0
                                visible: rowNeverConnected

                                TextField {
                                    id: passwordField
                                    anchors.fill: parent
                                    anchors.rightMargin: 46
                                    placeholderText: "Password"
                                    color: root.m3OnSurface
                                    placeholderTextColor: root.m3Secondary
                                    echoMode: rowRoot.showPassword ? TextInput.Normal : TextInput.Password
                                    enabled: !rowRoot.rowConnecting
                                    font.pixelSize: 15
                                    leftPadding: 42
                                    rightPadding: 12
                                    background: Rectangle {
                                        radius: 15
                                        color: passwordField.activeFocus ? root.theme.withAlpha(root.m3Primary, 0.095) : root.theme.withAlpha(root.m3OnSurface, 0.045)
                                        border.width: 0
                                        clip: true

                                        Rectangle {
                                            width: 3
                                            height: parent.height - 16
                                            radius: 2
                                            x: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: root.m3Primary
                                            opacity: passwordField.activeFocus ? 1 : 0.42
                                            Behavior on opacity { NumberAnimation { duration: root.theme.reducedMotion ? 0 : 150; easing.type: Easing.OutCubic } }
                                        }

                                        Text {
                                            x: 22
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "󰌾"
                                            color: root.m3Secondary
                                            font.pixelSize: 13
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 40
                                    height: 40
                                    radius: 14
                                    color: showArea.pressed ? root.theme.withAlpha(root.m3Primary, 0.14) : (showArea.containsMouse ? root.theme.withAlpha(root.m3Primary, 0.08) : root.theme.withAlpha(root.m3OnSurface, 0.035))
                                    scale: showArea.pressed ? 0.94 : (showArea.containsMouse ? 1.04 : 1)

                                    Behavior on color { ColorAnimation { duration: root.theme.reducedMotion ? 0 : 140; easing.type: Easing.OutCubic } }
                                    Behavior on scale { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 240; spring: 5.0; damping: 0.8; mass: 0.85; epsilon: 0.001 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: rowRoot.showPassword ? "" : ""
                                        color: root.m3Secondary
                                        font.pixelSize: 14
                                    }

                                    MouseArea {
                                        id: showArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: rowRoot.showPassword = !rowRoot.showPassword
                                    }
                                }
                            }

                            Rectangle {
                                id: autoBox
                                visible: rowNeverConnected
                                enabled: !rowRoot.rowConnecting
                                width: 174
                                height: 38
                                radius: 14
                                color: rowRoot.autoconnect ? root.theme.withAlpha(root.m3Primary, 0.18)
                                    : root.theme.withAlpha(root.m3OnSurface, 0.055)
                                border.width: 0
                                opacity: rowRoot.rowConnecting ? 0.55 : (autoArea.containsMouse ? 0.86 : 1)
                                scale: autoArea.pressed ? 0.94 : 1

                                Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(150 / 2) : 150; easing.type: Easing.OutCubic } }
                                Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(110 / 2) : 110; easing.type: Easing.OutCubic } }
                                Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.6; damping: 0.72; mass: 0.9; epsilon: 0.001 } }

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    Rectangle {
                                        width: 34
                                        height: 20
                                        radius: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: rowRoot.autoconnect ? root.theme.withAlpha(root.m3Primary, 0.45) : root.theme.withAlpha(root.m3OnSurface, 0.12)

                                        Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(150 / 2) : 150; easing.type: Easing.OutCubic } }

                                        Rectangle {
                                            width: 14
                                            height: 14
                                            radius: 7
                                            x: rowRoot.autoconnect ? 17 : 3
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: rowRoot.autoconnect ? root.m3Primary : root.theme.withAlpha(root.m3OnSurface, 0.45)
                                            Behavior on x { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 260; spring: 5.2; damping: 0.78; mass: 0.8; epsilon: 0.001 } }
                                            Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(150 / 2) : 150; easing.type: Easing.OutCubic } }
                                        }
                                    }

                                    Text {
                                        width: parent.width - 44
                                        text: "Autoconnect"
                                        color: rowRoot.autoconnect ? root.m3OnSurface : root.m3Secondary
                                        font.pixelSize: 14
                                        font.bold: rowRoot.autoconnect
                                        elide: Text.ElideRight
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: autoArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !rowRoot.rowConnecting
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: rowRoot.autoconnect = !rowRoot.autoconnect
                                }
                            }

                            Row {
                                width: parent.width
                                height: rowNeverConnected ? 42 : 0
                                visible: rowNeverConnected
                                spacing: 10

                                Rectangle {
                                    width: 136
                                    height: 40
                                    radius: root.theme.controlRadius
                                    opacity: rowRoot.rowConnecting ? 0.62 : 1
                                    scale: connectArea.pressed ? 0.96 : (connectArea.containsMouse ? 1.018 : 1)
                                    color: connectArea.containsMouse ? root.theme.withAlpha(root.m3Primary, 0.20) : root.theme.withAlpha(root.m3Primary, 0.13)

                                    Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(110 / 2) : 110 } }
                                    Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.6; damping: 0.72; mass: 0.9; epsilon: 0.001 } }
                                    Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(110 / 2) : 110; easing.type: Easing.OutCubic } }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 8

                                        BusyIndicator {
                                            width: 18
                                            height: 18
                                            visible: rowRoot.rowConnecting
                                            running: rowRoot.rowConnecting
                                        }

                                        Text {
                                            text: rowRoot.rowConnecting ? "Connecting..." : "Connect"
                                            color: root.theme.foreground
                                            font.pixelSize: 14
                                            font.bold: true
                                        }
                                    }

                                    MouseArea {
                                        id: connectArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: !rowRoot.rowConnecting
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.connectNetwork(rowRoot.rowSsid, false, passwordField.text, rowRoot.autoconnect)
                                    }
                                }
                            }

                            Row {
                                width: parent.width
                                height: (!rowConnected && rowKnown && confirmAction.length === 0) ? 42 : 0
                                visible: !rowConnected && rowKnown && confirmAction.length === 0
                                spacing: 10

                                Rectangle {
                                    width: 136
                                    height: 40
                                    radius: root.theme.controlRadius
                                    opacity: rowRoot.rowConnecting ? 0.62 : 1
                                    scale: savedConnectArea.pressed ? 0.96 : (savedConnectArea.containsMouse ? 1.018 : 1)
                                    color: savedConnectArea.containsMouse ? root.theme.withAlpha(root.m3Primary, 0.20) : root.theme.withAlpha(root.m3Primary, 0.13)

                                    Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(110 / 2) : 110 } }
                                    Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.6; damping: 0.72; mass: 0.9; epsilon: 0.001 } }
                                    Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(110 / 2) : 110; easing.type: Easing.OutCubic } }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 8

                                        BusyIndicator {
                                            width: 18
                                            height: 18
                                            visible: rowRoot.rowConnecting
                                            running: rowRoot.rowConnecting
                                        }

                                        Text {
                                            text: rowRoot.rowConnecting ? "Connecting..." : "Connect"
                                            color: root.theme.foreground
                                            font.pixelSize: 14
                                            font.bold: true
                                        }
                                    }

                                    MouseArea {
                                        id: savedConnectArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: !rowRoot.rowConnecting
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.connectNetwork(rowRoot.rowSsid, true, "", false)
                                    }
                                }

                                WifiActionButton {
                                    theme: root.theme
                                    text: "Forget"
                                    danger: true
                                    width: 104
                                    onClicked: rowRoot.confirmAction = "forget"
                                }
                            }

                            Text {
                                visible: root.errorSsid === rowSsid
                                width: parent.width
                                text: root.errorMessage.length > 0 ? root.errorMessage : "Wrong password or connection failed"
                                color: root.m3Error
                                font.pixelSize: 13
                                wrapMode: Text.WordWrap
                            }

                            Row {
                                width: parent.width
                                height: rowConnected && confirmAction.length === 0 ? 42 : 0
                                visible: rowConnected && confirmAction.length === 0
                                spacing: 10

                                WifiActionButton {
                                    theme: root.theme
                                    text: "Disconnect"
                                    outlined: true
                                    width: 138
                                    onClicked: rowRoot.confirmAction = "disconnect"
                                }

                                WifiActionButton {
                                    theme: root.theme
                                    text: "Forget"
                                    danger: true
                                    width: 104
                                    onClicked: rowRoot.confirmAction = "forget"
                                }
                            }

                            Row {
                                width: parent.width
                                height: rowKnown && confirmAction.length > 0 ? 42 : 0
                                visible: rowKnown && confirmAction.length > 0
                                spacing: 10

                                Text {
                                    width: parent.width - 154
                                    text: "Are you sure?"
                                    color: root.m3OnSurface
                                    font.pixelSize: 15
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                WifiActionButton {
                                    theme: root.theme
                                    text: "Yes"
                                    danger: confirmAction === "forget"
                                    width: 70
                                    onClicked: {
                                        if (rowRoot.confirmAction === "disconnect")
                                            root.disconnectNetwork(rowRoot.rowSsid)
                                        else
                                            root.forgetNetwork(rowRoot.rowSsid)
                                    }
                                }

                                WifiActionButton {
                                    theme: root.theme
                                    text: "No"
                                    outlined: true
                                    width: 64
                                    onClicked: rowRoot.confirmAction = ""
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: headerArea
                        x: 0
                        y: 0
                        width: parent.width
                        height: 58
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleExpanded(rowRoot.rowSsid)
                    }
                }
            }
        }
    }

    ListModel { id: networkModel }

    Process {
        id: nmcliCheck
        command: ["sh", "-c", "command -v \"$1\"", "sh", Services.Config.nmcliBin]
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { id: nmcliCheckErr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            root.nmcliAvailable = exitCode === 0
            if (!root.nmcliAvailable) {
                root.loading = false
                root.errorMessage = root.processError(nmcliCheckErr.text, "NetworkManager not available")
                networkModel.clear()
                return
            }
            root.errorMessage = ""
            deviceProbe.exec(deviceProbe.command)
        }
    }

    Process {
        id: deviceProbe
        command: [Services.Config.nmcliBin, "-t", "-f", "DEVICE,TYPE,STATE", "device", "status"]
        stdout: StdioCollector {
            id: deviceOut
            waitForEnd: true
        }
        stderr: StdioCollector { id: deviceErr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.nmcliAvailable = false
                root.loading = false
                root.errorMessage = root.processError(deviceErr.text, "Failed to read network devices")
                networkModel.clear()
                return
            }
            root.parseDevices(deviceOut.text)
            radioProbe.exec(radioProbe.command)
        }
    }

    Process {
        id: radioProbe
        command: [Services.Config.nmcliBin, "-t", "-f", "WIFI", "radio"]
        stdout: StdioCollector {
            id: radioOut
            waitForEnd: true
        }
        stderr: StdioCollector { id: radioErr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.loading = false
                root.wifiEnabled = false
                root.errorMessage = root.processError(radioErr.text, "Failed to read WiFi radio state")
                networkModel.clear()
                return
            }
            root.errorMessage = ""
            root.wifiEnabled = radioOut.text.trim() === "enabled"
            if (!root.wifiEnabled) {
                root.loading = false
                networkModel.clear()
                return
            }
            savedProbe.exec(savedProbe.command)
        }
    }

    Process {
        id: savedProbe
        command: [Services.Config.nmcliBin, "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            id: savedOut
            waitForEnd: true
        }
        stderr: StdioCollector { id: savedErr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.savedConnectionNames = ({})
                root.errorMessage = root.processError(savedErr.text, "Saved WiFi profiles unavailable")
            } else {
                root.errorMessage = ""
                root.parseSavedConnections(savedOut.text)
            }
            listProbe.exec(listProbe.command)
        }
    }

    Process {
        id: listProbe
        command: [Services.Config.nmcliBin, "-t", "-f", "ACTIVE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "yes"]
        stdout: StdioCollector {
            id: listOut
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: listErr
            waitForEnd: true
        }
        onExited: function(exitCode, exitStatus) {
            root.loading = false
            if (exitCode !== 0) {
                root.errorSsid = ""
                root.errorMessage = root.processError(listErr.text, "WiFi scan failed")
                networkModel.clear()
                return
            }
            root.errorMessage = ""
            root.parseNetworks(listOut.text)
        }
    }

    Process {
        id: wifiPowerProcess
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { id: wifiPowerErr; waitForEnd: true }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0)
                root.refresh()
            else {
                root.loading = false
                root.errorMessage = root.processError(wifiPowerErr.text, "Failed to toggle WiFi")
            }
        }
    }

    Process {
        id: actionProcess
        stdout: StdioCollector {
            id: actionOut
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: actionErr
            waitForEnd: true
        }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.connectingSsid = ""
                root.errorSsid = root.actionSsid
                root.errorMessage = root.action === "connect" ? "Wrong password or connection failed" : root.processError(actionErr.text, "WiFi action failed")
                return
            }

            if (root.action === "connect" && root.actionAutoconnect && !root.actionUsesSavedConnection) {
                autoconnectProcess.exec([Services.Config.nmcliBin, "connection", "modify", root.actionSsid, "connection.autoconnect", "yes"])
                return
            }

            root.finishActionSuccess()
        }
    }

    Process {
        id: autoconnectProcess
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector {
            id: autoconnectErr
            waitForEnd: true
        }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.connectingSsid = ""
                root.errorSsid = root.actionSsid
                root.errorMessage = root.processError(autoconnectErr.text, "Autoconnect failed")
                return
            }
            root.finishActionSuccess()
        }
    }

    function refresh() {
        if (nmcliCheck.running || deviceProbe.running || radioProbe.running || savedProbe.running || listProbe.running)
            return
        loading = true
        errorSsid = ""
        errorMessage = ""
        nmcliCheck.exec(nmcliCheck.command)
    }

    function restartStagger() {
        stage = -1
        headerOffset = 6
        bodyOffset = 6
        staggerTimer.restart()
    }

    function setWifi(enabled) {
        loading = true
        wifiPowerProcess.exec([Services.Config.nmcliBin, "radio", "wifi", enabled ? "on" : "off"])
    }

    function toggleExpanded(ssid) {
        expandedSsid = expandedSsid === ssid ? "" : ssid
        errorSsid = ""
        errorMessage = ""
    }

    function connectNetwork(ssid, useSavedConnection, password, autoconnect) {
        if (actionProcess.running || autoconnectProcess.running)
            return

        let cmd
        if (useSavedConnection) {
            cmd = [Services.Config.nmcliBin, "connection", "up", ssid]
        } else {
            cmd = [Services.Config.nmcliBin, "device", "wifi", "connect", ssid]
            if (password.length > 0)
                cmd.push("password", password)
        }

        action = "connect"
        actionSsid = ssid
        actionAutoconnect = autoconnect
        actionUsesSavedConnection = useSavedConnection
        connectingSsid = ssid
        errorSsid = ""
        errorMessage = ""
        actionProcess.exec(cmd)
    }

    function disconnectNetwork(ssid) {
        action = "disconnect"
        actionSsid = ssid
        actionAutoconnect = false
        actionUsesSavedConnection = false
        errorSsid = ""
        errorMessage = ""
        actionProcess.exec([Services.Config.nmcliBin, "device", "disconnect", wifiDeviceName.length > 0 ? wifiDeviceName : "wlan0"])
    }

    function forgetNetwork(ssid) {
        action = "forget"
        actionSsid = ssid
        actionAutoconnect = false
        actionUsesSavedConnection = false
        errorSsid = ""
        errorMessage = ""
        actionProcess.exec([Services.Config.nmcliBin, "connection", "delete", ssid])
    }

    function finishActionSuccess() {
        connectingSsid = ""
        expandedSsid = ""
        errorSsid = ""
        errorMessage = ""
        actionUsesSavedConnection = false
        refresh()
    }

    function parseDevices(text) {
        const lines = text.trim().split("\n")
        for (let i = 0; i < lines.length; i++) {
            const parts = splitNmcliLine(lines[i])
            if (parts.length >= 2 && parts[1] === "wifi") {
                wifiDeviceName = parts[0]
                return
            }
        }
    }

    function parseSavedConnections(text) {
        const known = ({})
        const lines = text.trim().split("\n")

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i]
            if (line.length === 0)
                continue

            const parts = splitNmcliLine(line)
            if (parts.length < 2)
                continue

            const name = parts[0].trim()
            const type = parts[1].trim()
            if (name.length === 0)
                continue

            if (type === "wifi" || type === "802-11-wireless")
                known[name] = true
        }

        savedConnectionNames = known
    }

    function parseNetworks(text) {
        const bySsid = ({})
        const lines = text.trim().split("\n")

        for (let i = 0; i < lines.length; i++) {
            const parts = splitNmcliLine(lines[i])
            if (parts.length < 4)
                continue

            const active = parts[0] === "yes" || parts[0] === "*"
            const ssid = parts[1].trim()
            const signal = Math.max(0, Math.min(100, parseInt(parts[2], 10) || 0))
            const security = parts.slice(3).join(":").trim()
            const known = !!savedConnectionNames[ssid]

            if (ssid.length === 0)
                continue

            if (!bySsid[ssid] || active || signal > bySsid[ssid].strength)
                bySsid[ssid] = { ssid: ssid, strength: signal, security: security, inUse: active, known: known }
        }

        const parsed = []
        for (const key in bySsid)
            parsed.push(bySsid[key])

        parsed.sort(function(a, b) {
            if (a.inUse !== b.inUse)
                return a.inUse ? -1 : 1
            return b.strength - a.strength
        })

        networkModel.clear()
        for (let j = 0; j < parsed.length; j++)
            networkModel.append(parsed[j])
        selectedIndex = Math.max(0, Math.min(selectedIndex, networkModel.count - 1))
    }

    function activateSelectedNetwork() {
        if (selectedIndex < 0 || selectedIndex >= networkModel.count)
            return
        const item = networkModel.get(selectedIndex)
        if (!item)
            return
        if (item.inUse)
            disconnectNetwork(item.ssid)
        else if (item.known)
            connectNetwork(item.ssid, true, "", true)
        else
            toggleExpanded(item.ssid)
    }

    function splitNmcliLine(line) {
        const out = []
        let cur = ""
        let escaped = false
        for (let i = 0; i < line.length; i++) {
            const ch = line[i]
            if (escaped) {
                cur += ch
                escaped = false
            } else if (ch === "\\") {
                escaped = true
            } else if (ch === ":") {
                out.push(cur)
                cur = ""
            } else {
                cur += ch
            }
        }
        out.push(cur)
        return out
    }

    function signalIconSource(value) {
        const pct = Math.max(0, Math.min(100, Math.round(Number(value))))
        if (pct <= 25)
            return wifiIconDir + "wifi_item_1_bar.svg"
        if (pct <= 50)
            return wifiIconDir + "wifi_item_2_bar.svg"
        if (pct <= 75)
            return wifiIconDir + "wifi_item_3_bar.svg"
        return wifiIconDir + "wifi_item.svg"
    }

    function processError(text, fallback) {
        const msg = String(text || "").trim()
        return msg.length > 0 ? msg : fallback
    }

    component WifiSvgIcon: Item {
        id: wifiIcon

        property var theme
        property string sourcePath: ""
        property color iconColor: "white"
        property int iconSize: 24
        property bool spinning: false

        width: iconSize
        height: iconSize

        Image {
            id: svgSource
            anchors.fill: parent
            source: wifiIcon.sourcePath
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
            colorizationColor: wifiIcon.iconColor

            Behavior on colorizationColor { ColorAnimation { duration: wifiIcon.theme && wifiIcon.theme.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic } }
        }

        RotationAnimation on rotation {
            running: wifiIcon.spinning && !(wifiIcon.theme && wifiIcon.theme.reducedMotion)
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: wifiIcon.theme && wifiIcon.theme.reducedMotion ? Math.round(900 / 2) : 900
        }
    }
}

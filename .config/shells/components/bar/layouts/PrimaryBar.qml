import QtQuick
import QtQuick.Layouts
import Quickshell
import "../islands"
import "../modules"
import "../tray"
import "../widgets"
import "../../services" as Services
import "../../launcher"
import "../../notifications/center"

PanelWindow {
    id: root

    property var theme
    property var memoryStats
    property var networkState
    property var networkSpeed
    property var notificationStore
    property var stateService
    property real barBottomEdge: 0
    property var reportBottomEdgeAction: null
    property var reportToastAnchorAction: null
    property var resolvePanelYAction: null
    property string phase: "shown"
    property var toggleLayoutAction: null

    property real shellTargetOpacity: 1
    property real shellTargetScale: 1
    property bool leftEnterReady: true
    property bool rightEnterReady: true
    property real launcherTopOffset: 40

    signal toggleLayoutRequested()

    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        top: 14
        left: 20
        right: 20
    }

    implicitHeight: 48
    exclusiveZone: phase === "hidden" ? 0 : 62
    aboveWindows: true
    color: "transparent"
    surfaceFormat.opaque: false
    visible: phase !== "hidden" || shell.opacity > 0.01

    onPhaseChanged: {
        if (phase === "exit") {
            leftEnterReady = true
            rightEnterReady = true
            shellTargetScale = 0.8
            shellTargetOpacity = 0
        } else if (phase === "enter") {
            shellTargetScale = 1
            shellTargetOpacity = 1
            leftEnterReady = false
            rightEnterReady = false
            leftEnterTimer.restart()
            rightEnterTimer.restart()
        } else if (phase === "shown") {
            leftEnterReady = true
            rightEnterReady = true
            shellTargetScale = 1
            shellTargetOpacity = 1
        } else {
            leftEnterReady = false
            rightEnterReady = false
            shellTargetScale = 0.8
            shellTargetOpacity = 0
        }
    }

    Timer { id: leftEnterTimer; interval: 0; repeat: false; onTriggered: root.leftEnterReady = true }
    Timer { id: rightEnterTimer; interval: 60; repeat: false; onTriggered: root.rightEnterReady = true }

        Item {
            id: shell
            anchors.fill: parent
            clip: false
            enabled: root.phase !== "hidden"
            opacity: root.shellTargetOpacity
            scale: root.shellTargetScale

        Behavior on opacity {
            NumberAnimation {
                duration: root.phase === "exit" ? 200 : 180
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.phase === "exit" ? 200 : 180
                easing.type: Easing.OutCubic
            }
        }

        Island {
            id: leftLogoIsland
            theme: root.theme
            anchors.left: parent.left
            anchors.leftMargin: root.theme.islandGap
            anchors.verticalCenter: parent.verticalCenter
            paddingX: Math.max(4, root.theme.islandPadding - 2)
            spacing: 0
            opacity: root.leftEnterReady ? 1 : 0
            scale: root.leftEnterReady ? 1 : 0.8

            Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(160 / 2) : 160; easing.type: Easing.OutCubic } }
            Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.75; mass: 0.9; epsilon: 0.001 } }

            IconButton {
                theme: root.theme
                text: "   "
                baseColor: root.theme.color4
                tooltipText: "Arch Linux"
                horizontalPadding: 0
            }
        }

        Island {
            id: leftIsland
            theme: root.theme
            anchors.left: leftLogoIsland.right
            anchors.leftMargin: root.theme.islandGap
            anchors.verticalCenter: parent.verticalCenter
            paddingX: root.theme.islandPadding + 2
            spacing: 0
            pulseToken: root.notificationStore ? root.notificationStore.toastPulseToken : 0
            pulseCritical: root.notificationStore ? root.notificationStore.toastPulseCritical : false
            opacity: root.leftEnterReady ? 1 : 0
            scale: root.leftEnterReady ? 1 : 0.8

            Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(160 / 2) : 160; easing.type: Easing.OutCubic } }
            Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.75; mass: 0.9; epsilon: 0.001 } }
            onWidthChanged: shell.updateNotificationAnchor()
            onXChanged: shell.updateNotificationAnchor()
            onYChanged: shell.updateNotificationAnchor()

            Item {
                visible: Services.RecorderState.isRecording
                width: 10
                height: 28

                Rectangle {
                    anchors.centerIn: parent
                    width: 6
                    height: 6
                    radius: 3
                    color: "#ff3b30"

                    SequentialAnimation on scale {
                        running: Services.RecorderState.isRecording && !Services.RecorderState.isPaused
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.4; duration: theme && theme.reducedMotion ? 0 : 600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: theme && theme.reducedMotion ? 0 : 600; easing.type: Easing.InOutSine }
                    }
                }
            }

            IconButton {
                theme: root.theme
                iconSource: Quickshell.env("HOME") + "/.config/shells/assets/icons/panel/power_menu/power_menu.svg"
                baseColor: root.theme.color6
                iconSize: 18
                tooltipText: "Power menu"
                onClicked: Quickshell.execDetached(Services.Config.powerMenuCommand)
            }

            IconButton {
                id: notificationButton
                theme: root.theme
                iconSource: Quickshell.env("HOME") + "/.config/shells/assets/icons/panel/control_center/control_center.svg"
                baseColor: root.theme.color1
                iconSize: 18
                tooltipText: root.notificationStore ? ("Control center • " + root.notificationStore.count + " notifications") : "Control center"
                onClicked: notificationCenter.toggleFromItem(notificationButton)
            }

            TrayDrawer {
                theme: root.theme
                menuAnchorItem: leftIsland
            }
        }

        Island {
            id: centerIsland
            theme: root.theme
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            paddingX: root.theme.islandPadding + 3
            opacity: root.leftEnterReady ? 1 : 0
            scale: root.leftEnterReady ? 1 : 0.8

            Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(160 / 2) : 160; easing.type: Easing.OutCubic } }
            Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.75; mass: 0.9; epsilon: 0.001 } }

            Workspaces {
                theme: root.theme
            }
        }

        Island {
            id: centerClockIsland
            theme: root.theme
            anchors.right: centerIsland.left
            anchors.rightMargin: root.theme.islandGap
            anchors.verticalCenter: parent.verticalCenter
            paddingX: root.theme.islandPadding + 2
            spacing: 0
            opacity: root.leftEnterReady ? 1 : 0
            scale: root.leftEnterReady ? 1 : 0.8

            Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(160 / 2) : 160; easing.type: Easing.OutCubic } }
            Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.75; mass: 0.9; epsilon: 0.001 } }

            ClockModule {
                theme: root.theme
                panelController: rightDropdown
            }
        }

        MouseArea {
            anchors.fill: centerIsland
            acceptedButtons: Qt.RightButton | Qt.MiddleButton
            hoverEnabled: false
            cursorShape: Qt.PointingHandCursor
            onClicked: launcher.toggle()
        }

        Launcher {
            id: launcher
            screen: root.screen
            theme: root.theme
            topOffset: root.launcherTopOffset
        }

        Island {
            id: rightRefreshIsland
            theme: root.theme
            anchors.right: parent.right
            anchors.rightMargin: root.theme.islandGap
            anchors.verticalCenter: parent.verticalCenter
            paddingX: root.theme.islandPadding + 2
            spacing: 0
            opacity: root.rightEnterReady ? 1 : 0
            scale: root.rightEnterReady ? 1 : 0.8

            Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(160 / 2) : 160; easing.type: Easing.OutCubic } }
            Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.75; mass: 0.9; epsilon: 0.001 } }

            IconButton {
                theme: root.theme
                iconSource: Quickshell.env("HOME") + "/.config/shells/assets/icons/components/bar_layout.svg"
                baseColor: root.theme.color4
                iconSize: 18
                tooltipText: "Switch bar layout"
                onClicked: {
                    root.toggleLayoutRequested()
                    if (typeof root.toggleLayoutAction === "function")
                        root.toggleLayoutAction()
                }
            }
        }

        Island {
            id: rightIsland
            theme: root.theme
            anchors.right: rightRefreshIsland.left
            anchors.rightMargin: root.theme.islandGap
            anchors.verticalCenter: parent.verticalCenter
            paddingX: root.theme.islandPadding + 2
            spacing: 0
            opacity: root.rightEnterReady ? 1 : 0
            scale: root.rightEnterReady ? 1 : 0.8

            Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(160 / 2) : 160; easing.type: Easing.OutCubic } }
            Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.75; mass: 0.9; epsilon: 0.001 } }
            onWidthChanged: shell.updateRightDropdownAnchor()
            onXChanged: shell.updateRightDropdownAnchor()
            onYChanged: shell.updateRightDropdownAnchor()

            NetworkModule {
                theme: root.theme
                networkState: root.networkState
                networkSpeed: root.networkSpeed
                panelController: rightDropdown
            }

            BluetoothModule {
                theme: root.theme
                panelController: rightDropdown
            }

            AudioModule {
                theme: root.theme
                panelController: rightDropdown
            }

            MemoryModule {
                theme: root.theme
                memoryStats: root.memoryStats
                panelController: rightDropdown
            }

            BatteryModule {
                theme: root.theme
                panelController: rightDropdown
            }
        }

        RightIslandDropdown {
            id: rightDropdown
            screen: root.screen
            theme: root.theme
            networkState: root.networkState
            memoryStats: root.memoryStats
            barBottomEdge: root.barBottomEdge
            followItemY: true
            resolvePanelYAction: root.resolvePanelYAction
            rightIslandWidth: rightIsland.width
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
            followItemY: true
            resolvePanelYAction: root.resolvePanelYAction
        }

        Timer {
            interval: 80
            repeat: true
            running: true
            triggeredOnStart: true
            onTriggered: {
                shell.updateNotificationAnchor()
                shell.reportBottomEdgeNow()
                shell.reportToastAnchorNow()
                shell.updateLauncherTopOffset()
            }
        }

        function updateRightDropdownAnchor() {
            rightDropdown.setAnchorFromItem(rightIsland)
        }

        function updateNotificationAnchor() {
            notificationCenter.setAnchorFromItem(leftIsland)
        }

        function reportBottomEdgeNow() {
            if (typeof root.reportBottomEdgeAction !== "function")
                return
            const g = leftIsland.mapToGlobal(0, 0)
            root.reportBottomEdgeAction(Math.round(g.y + leftIsland.height + 8))
        }

        function reportToastAnchorNow() {
            if (typeof root.reportToastAnchorAction !== "function")
                return
            if (root.phase !== "shown" && root.phase !== "enter")
                return
            const g = rightIsland.mapToGlobal(0, 0)
            const bottom = typeof root.resolvePanelYAction === "function"
                ? root.resolvePanelYAction(rightIsland)
                : Math.round(g.y + rightIsland.height + 8)
            root.reportToastAnchorAction(Math.round(g.x), Math.round(bottom), Math.round(rightIsland.width))
        }

        function updateLauncherTopOffset() {
            root.launcherTopOffset = (root.phase === "shown" || root.phase === "enter") ? -10 : 4
        }
    }

    onVisibleChanged: if (visible) {
        shell.reportBottomEdgeNow()
        shell.reportToastAnchorNow()
        shell.updateLauncherTopOffset()
    }
}

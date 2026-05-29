import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../widgets"

Row {
    id: root

    property var theme
    readonly property var visibleWorkspaces: buildVisibleWorkspaces()

    spacing: theme ? Math.max(3, theme.itemSpacing - 2) : 8

    Repeater {
        model: root.visibleWorkspaces

        Item {
            id: dot

            property var workspace: modelData
            property int workspaceId: workspace ? workspace.id : 0
            property bool active: workspace ? workspace.focused : false
            property bool urgent: workspace ? workspace.urgent : false
            property bool occupied: workspace && workspace.toplevels ? workspace.toplevels.values.length > 0 : false
            property bool unclaimed: active && !occupied
            property real popScale: 1

            width: active ? 22 : 17
            height: 26
            scale: (active ? 1.12 : (area.containsMouse ? 1.09 : 1)) * popScale

            onUnclaimedChanged: {
                if (unclaimed)
                    popAnim.restart()
                else
                    popScale = 1
            }

            SequentialAnimation {
                id: popAnim
                NumberAnimation { target: dot; property: "popScale"; to: 1.15; duration: theme && theme.reducedMotion ? Math.round(110 / 2) : 110; easing.type: Easing.OutCubic }
                SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  target: dot; property: "popScale"; to: 1.0; spring: 6; damping: 0.5; mass: 0.9; epsilon: 0.001 }
            }

            Behavior on width { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(260 / 2) : 260; easing.type: Easing.OutCubic } }

            Timer {
                id: tipDelay
                interval: 420
                repeat: false
                onTriggered: if (area.containsMouse) tooltip.showFor(dot, dot.tooltipText(), QsWindow.window)
            }

            Rectangle {
                anchors.centerIn: parent
                width: dot.active ? 21 : (area.containsMouse ? 15 : 0)
                height: width
                radius: width / 2
                color: root.theme.withAlpha(dot.urgent ? root.theme.color1 : root.theme.color2, dot.active ? (dot.unclaimed ? 0.30 : 0.20) : 0.10)
                antialiasing: true
                scale: dot.active ? (dot.unclaimed ? 1.06 : 1) : 0.86

                Behavior on width { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(280 / 2) : 280; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(360 / 2) : 360; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(220 / 2) : 220; easing.type: Easing.OutCubic } }
            }

            Rectangle {
                anchors.centerIn: parent
                width: dot.unclaimed ? 15 : 14
                height: width
                radius: width / 2
                color: dot.active || dot.urgent
                    ? (dot.urgent
                        ? root.theme.color1
                        : (dot.unclaimed
                            ? root.theme.withAlpha(root.theme.color2, 0.90)
                            : root.theme.color2))
                    : "transparent"
                border.width: dot.active || dot.urgent ? 0 : 2
                border.color: root.theme.withAlpha(root.theme.color2, area.containsMouse ? 0.58 : 0.30)
                antialiasing: true

                Behavior on width { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(280 / 2) : 280; easing.type: Easing.OutCubic } }
                Behavior on border.width { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic } }
                Behavior on border.color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(220 / 2) : 220; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(220 / 2) : 220; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: tipDelay.restart()
                onExited: {
                    tipDelay.stop()
                    tooltip.closeAnimated()
                }
                onClicked: Hyprland.dispatch("workspace " + dot.workspaceId)
            }

            TooltipPopup {
                id: tooltip
                theme: root.theme
            }

            function tooltipText() {
                const count = workspace && workspace.toplevels ? workspace.toplevels.values.length : 0
                let label = "Workspace " + workspaceId
                if (active)
                    label += " • Active"
                if (urgent)
                    label += " • Urgent"
                label += " • " + count + (count === 1 ? " app" : " apps")
                return label
            }
        }
    }

    function buildVisibleWorkspaces() {
        const focused = Hyprland.focusedWorkspace
        const spaces = Hyprland.workspaces.values
        const visible = []
        let hasFocused = false

        for (let i = 0; i < spaces.length; i++) {
            const ws = spaces[i]
            const occupied = ws.toplevels && ws.toplevels.values.length > 0
            if (ws.focused || ws.urgent || occupied) {
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
}

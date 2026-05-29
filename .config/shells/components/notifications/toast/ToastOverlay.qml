import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property var theme
    property var store
    property real barBottomEdge: 0
    property real anchorX: 0
    property real anchorY: 0
    property real anchorWidth: 220
    property real anchorHeight: 36
    property real stableTop: 54
    property int positionToken: 0
    property int previousToastCount: 0
    readonly property var toastList: store ? store.toasts : []
    readonly property int toastWidth: 320
    readonly property int maxToastHeight: 84
    readonly property string toastPosition: theme ? theme.toastPosition : "top-right"
    readonly property bool leftSide: toastPosition === "top-left" || toastPosition === "bottom-left"
    readonly property bool bottomSide: toastPosition === "bottom-left" || toastPosition === "bottom-right"
    property bool expanded: false
    readonly property int collapsedCount: Math.min(toastModel.count, theme && theme.stackToasts ? 3 : toastModel.count)
    readonly property int expandedHeight: toastModel.count * (maxToastHeight + 8)
    readonly property int collapsedHeight: maxToastHeight + Math.max(0, collapsedCount - 1) * 6 + 12
    readonly property int hoverHeight: Math.max(expandedHeight, collapsedHeight)

    anchors {
        top: !root.bottomSide
        bottom: root.bottomSide
        left: root.leftSide
        right: !root.leftSide
    }

    margins {
        top: root.bottomSide ? 0 : Math.max(0, stableTop - 8)
        bottom: root.bottomSide ? 18 : 0
        left: root.leftSide ? 16 : 0
        right: root.leftSide ? 0 : 16
    }

    visible: toastList.length > 0
    implicitWidth: toastWidth
    implicitHeight: Math.max(1, 8 + hoverHeight)
    aboveWindows: true
    focusable: false
    exclusiveZone: -1
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "shells-notification-toasts"

    Component.onCompleted: stableTop = targetTop()

    onPositionTokenChanged: {
        const next = targetTop()
        if (toastList.length === 0)
            stableTop = next
    }

    onToastListChanged: {
        syncToasts()
        const count = toastList.length
        if (count > 0 && previousToastCount === 0)
            stableTop = targetTop()
        else if (count === 0)
            stableTop = targetTop()
        previousToastCount = count
    }

    ListModel {
        id: toastModel
        dynamicRoles: true
    }

    Item {
        id: stack
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 8
        width: root.toastWidth
        height: root.implicitHeight

        MouseArea {
            id: stackHover
            anchors.left: parent.left
            anchors.top: parent.top
            width: root.toastWidth
            height: root.hoverHeight
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onEntered: {
                closeHoverDelay.stop()
                root.expanded = true
            }
            onExited: closeHoverDelay.restart()
        }

        Repeater {
            model: toastModel

            Item {
                id: deckSlot

                property int depth: index
                property bool stacked: root.theme ? root.theme.stackToasts : true
                property bool inDeck: root.expanded || !stacked || index < 3
                property real targetX: root.expanded || !stacked ? 0 : depth * 8
                property real targetY: root.expanded || !stacked ? depth * (root.maxToastHeight + 8) : depth * 6
                property real targetWidth: root.expanded || !stacked ? root.toastWidth : root.toastWidth - depth * 16
                property real targetScale: root.expanded || !stacked ? 1.0 : 1.0 - depth * 0.04

                visible: inDeck
                x: targetX
                y: targetY
                width: targetWidth
                height: root.maxToastHeight
                scale: targetScale
                transformOrigin: Item.Top
                z: root.expanded ? (toastModel.count - index) : (3 - index)

                Behavior on x { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.5; damping: 0.72; mass: 0.9; epsilon: 0.001 } }
                Behavior on y { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.5; damping: 0.72; mass: 0.9; epsilon: 0.001 } }
                Behavior on width { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.5; damping: 0.72; mass: 0.9; epsilon: 0.001 } }
                Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.5; damping: 0.72; mass: 0.9; epsilon: 0.001 } }

                ToastCard {
                    width: parent.width
                    theme: root.theme
                    store: root.store
                    toast: model.toast
                    deckIndex: index
                    deckExpanded: root.expanded
                    stackCount: toastModel.count
                }
            }
        }
    }

    Timer {
        id: closeHoverDelay
        interval: 160
        repeat: false
        onTriggered: root.expanded = false
    }

    function targetTop() {
        return Math.max(8, Math.round(anchorY > 0 ? anchorY : (barBottomEdge > 0 ? barBottomEdge : 54)) + 8)
    }

    function syncToasts() {
        const items = toastList || []

        for (let i = toastModel.count - 1; i >= 0; i--) {
            const row = toastModel.get(i)
            if (indexOfToast(items, row.toastId) < 0)
                toastModel.remove(i)
        }

        for (let target = 0; target < items.length; target++) {
            const item = items[target]
            const id = String(item.id)
            let existing = indexOfModel(id)
            if (existing < 0) {
                toastModel.insert(target, { toastId: id, toast: item })
            } else {
                if (existing !== target)
                    toastModel.move(existing, target, 1)
                toastModel.setProperty(target, "toast", item)
            }
        }
    }

    function indexOfToast(items, id) {
        const needle = String(id)
        for (let i = 0; i < items.length; i++) {
            if (String(items[i].id) === needle)
                return i
        }
        return -1
    }

    function indexOfModel(id) {
        const needle = String(id)
        for (let i = 0; i < toastModel.count; i++) {
            if (String(toastModel.get(i).toastId) === needle)
                return i
        }
        return -1
    }
}

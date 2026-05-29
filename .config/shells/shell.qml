//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import "components/services"
import "components/bar/layouts"
import "components/wallpaper"
import "components/powermenu"
import "components/lockscreen"
import "components/settings"
import "components/recorder"
import "components/osd"
import "components/notifications/toast"

ShellRoot {
    id: root

    property string barLayout: "islands"
    property string pendingLayout: ""
    property bool switchingLayout: false
    property string islandsPhase: "shown"
    property string fixedPhase: "hidden"
    property real islandsBarBottomEdge: 70
    property real fixedBarBottomEdge: 44
    property real toastAnchorX: 1600
    property real toastAnchorY: 70
    property real toastAnchorWidth: 260
    property int toastPositionToken: 0
    readonly property real barBottomEdge: (barLayout === "fixed" || fixedPhase === "enter" || fixedPhase === "shown")
        ? fixedBarBottomEdge
        : islandsBarBottomEdge

    readonly property string layoutStatePath: Quickshell.env("HOME") + "/.cache/quickshell/bar-layout.json"

    StateService {
        id: stateService
        onReadyChanged: if (ready) root.applyStateLayout()
    }

    Component.onCompleted: {
        Qt.application.font.family = "JetBrainsMono Nerd Font"
        ensureCache.exec(ensureCache.command)
    }

    FileView {
        id: barLayoutState
        path: root.layoutStatePath
        preload: true
        blockLoading: true
        printErrors: false
        onLoaded: {
            if (!stateService.ready || stateService.value("barLayout", "") === "")
                root.loadBarLayout(text())
        }
    }

    Process {
        id: ensureCache
        command: ["mkdir", "-p", Quickshell.env("HOME") + "/.cache/quickshell"]
    }

    Timer {
        id: layoutExitTimer
        interval: 200
        repeat: false
        onTriggered: {
            if (root.pendingLayout === "fixed") {
                root.islandsPhase = "hidden"
                root.fixedPhase = "enter"
                layoutEnterTimer.interval = 280
                layoutEnterTimer.restart()
            } else {
                root.fixedPhase = "hidden"
                root.islandsPhase = "enter"
                layoutEnterTimer.interval = 320
                layoutEnterTimer.restart()
            }
        }
    }

    Timer {
        id: layoutEnterTimer
        interval: 280
        repeat: false
        onTriggered: {
            root.barLayout = root.pendingLayout
            root.islandsPhase = root.barLayout === "islands" ? "shown" : "hidden"
            root.fixedPhase = root.barLayout === "fixed" ? "shown" : "hidden"
            root.switchingLayout = false
            root.pendingLayout = ""
            root.toastPositionToken++
            barLayoutState.setText(JSON.stringify({ layout: root.barLayout }))
            stateService.setValue("barLayout", root.barLayout)
        }
    }

    Theme { id: themeService }
    MemoryStats { id: memoryService }
    NetworkState { id: networkService }
    NetworkSpeed { id: networkSpeedService }
    ActiveWindow { id: activeWindowService }
    NotificationService {
        id: notificationStore
        theme: themeService
        stateService: stateService
    }

    LockSession {
        id: lockSession
        theme: themeService
        networkState: networkService
    }

    SettingsPanel {
        id: settingsPanel
        theme: themeService
        stateService: stateService
    }

    RecorderIsland {
        id: recorderIsland
        theme: themeService
        notificationStore: notificationStore
        stateService: stateService
        barBottomEdge: root.barBottomEdge
    }

    Osd {
        id: osd
        theme: themeService
    }

    Variants {
        model: Quickshell.screens

        PrimaryBar {
            required property var modelData

            screen: modelData
            theme: themeService
            memoryStats: memoryService
            networkState: networkService
            networkSpeed: networkSpeedService
            notificationStore: notificationStore
            stateService: stateService
            barBottomEdge: root.barBottomEdge
            reportBottomEdgeAction: function(edge) { root.updateIslandsBarBottomEdge(edge) }
            reportToastAnchorAction: function(x, y, width) { root.updateToastAnchor(x, y, width) }
            resolvePanelYAction: function(item) { return root.getIslandBottom(1, item) }
            phase: root.islandsPhase
            toggleLayoutAction: function() { root.toggleBarLayout() }
        }
    }

    Variants {
        model: Quickshell.screens

        SecondaryBar {
            required property var modelData

            screen: modelData
            theme: themeService
            networkState: networkService
            networkSpeed: networkSpeedService
            memoryStats: memoryService
            activeWindow: activeWindowService
            notificationStore: notificationStore
            stateService: stateService
            barBottomEdge: root.barBottomEdge
            reportBottomEdgeAction: function(edge) { root.updateFixedBarBottomEdge(edge) }
            reportToastAnchorAction: function(x, y, width) { root.updateToastAnchor(x, y, width) }
            phase: root.fixedPhase
            toggleLayoutAction: function() { root.toggleBarLayout() }
        }
    }

    Variants {
        model: Quickshell.screens

        ToastOverlay {
            required property var modelData

            screen: modelData
            theme: themeService
            store: notificationStore
            barBottomEdge: root.barBottomEdge
            anchorX: root.toastAnchorX
            anchorY: root.toastAnchorY
            anchorWidth: root.toastAnchorWidth
            positionToken: root.toastPositionToken
        }
    }

    Variants {
        model: Quickshell.screens

        WallpaperSelector {
            required property var modelData

            screen: modelData
            theme: themeService
            stateService: stateService
        }
    }

    Variants {
        model: Quickshell.screens

        PowerMenu {
            required property var modelData

            screen: modelData
            theme: themeService
        }
    }

    Variants {
        model: Quickshell.screens

        Item {
            required property var modelData

            Loader {
                asynchronous: true
                active: true
                source: "components/clipboard/ClipboardManager.qml"
                onLoaded: {
                    item.screen = modelData
                    item.theme = themeService
                    item.stateService = stateService
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        Item {
            required property var modelData

            Loader {
                asynchronous: true
                active: true
                source: "components/emoji/EmojiPicker.qml"
                onLoaded: {
                    item.screen = modelData
                    item.theme = themeService
                    item.stateService = stateService
                }
            }
        }
    }

    function toggleBarLayout() {
        if (switchingLayout)
            return
        switchBarLayout(barLayout === "islands" ? "fixed" : "islands")
    }

    function switchBarLayout(layout) {
        const mode = layout === "fixed" ? "fixed" : "islands"
        if (barLayout === mode || switchingLayout)
            return

        switchingLayout = true
        pendingLayout = mode
        if (barLayout === "islands")
            islandsPhase = "exit"
        else
            fixedPhase = "exit"
        layoutExitTimer.restart()
    }

    function applyLayoutImmediate(layout) {
        barLayout = layout === "fixed" ? "fixed" : "islands"
        islandsPhase = barLayout === "islands" ? "shown" : "hidden"
        fixedPhase = barLayout === "fixed" ? "shown" : "hidden"
        pendingLayout = ""
        switchingLayout = false
        toastPositionToken++
    }

    function loadBarLayout(text) {
        try {
            const data = JSON.parse(text)
            applyLayoutImmediate(data && data.layout === "fixed" ? "fixed" : "islands")
        } catch (e) {
            applyLayoutImmediate("islands")
        }
    }

    function applyStateLayout() {
        const layout = stateService.value("barLayout", "")
        if (layout === "fixed" || layout === "islands")
            applyLayoutImmediate(layout)
    }

    function getIslandBottom(layoutId, islandPill) {
        const gap = 16
        if (layoutId === 1 && islandPill) {
            const p = islandPill.mapToGlobal(0, islandPill.height)
            return Math.round(p.y + gap)
        }
        if (layoutId === 2)
            return Math.round(fixedBarBottomEdge)
        return Math.round(barBottomEdge)
    }

    function updateIslandsBarBottomEdge(edge) {
        const value = Number(edge)
        if (!isFinite(value) || value <= 0)
            return
        islandsBarBottomEdge = value
    }

    function updateFixedBarBottomEdge(edge) {
        const value = Number(edge)
        if (!isFinite(value) || value <= 0)
            return
        fixedBarBottomEdge = value
    }

    function updateToastAnchor(x, y, width) {
        const ax = Number(x)
        const ay = Number(y)
        const aw = Number(width)
        if (!isFinite(ax) || !isFinite(ay) || !isFinite(aw) || aw <= 0)
            return
        const nextX = Math.max(8, Math.round(ax))
        const nextY = Math.max(8, Math.round(ay))
        const nextWidth = Math.max(180, Math.round(aw))
        if (toastAnchorX === nextX && toastAnchorY === nextY && toastAnchorWidth === nextWidth)
            return
        toastAnchorX = nextX
        toastAnchorY = nextY
        toastAnchorWidth = nextWidth
        toastPositionToken++
    }
}

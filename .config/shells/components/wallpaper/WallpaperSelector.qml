import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../services" as Services

PanelWindow {
    id: root

    property var theme
    property var stateService
    property int selectedIndex: 0
    property int visualIndex: 0
    property int savedIndex: -1
    property bool restoredFromDisk: false
    property bool initialPositionDone: false
    property bool animateStrip: true
    property bool closing: false
    property int lastActiveSoundIndex: -1
    property int repeatCount: 200
    readonly property int repeatMiddle: Math.floor(repeatCount / 2)
    property string currentWallpaperName: ""
    property string wallDir: Services.Config.wallpaperDir
    property string statePath: Quickshell.env("HOME") + "/.cache/shells-wallpaper-index"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    margins {
        top: 0
        left: 0
        right: 0
        bottom: 0
    }

    visible: false
    aboveWindows: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "shells-wallpaper-selector"
    WlrLayershell.anchors.top: true
    WlrLayershell.anchors.left: true
    WlrLayershell.anchors.right: true
    WlrLayershell.anchors.bottom: true
    WlrLayershell.margins.top: 0
    WlrLayershell.margins.left: 0
    WlrLayershell.margins.right: 0
    WlrLayershell.margins.bottom: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.exclusiveZone: -1
    focusable: true
    exclusiveZone: -1
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    surfaceFormat.opaque: false

    IpcHandler {
        target: "wallpaper"

        function toggle() { root.toggle() }
        function open() { root.open() }
        function close() { root.closeAnimated() }
    }

    FileView {
        id: stateFile
        path: root.statePath
        preload: true
        blockLoading: true
        printErrors: false

        onLoaded: root.readSavedIndex()
        onLoadFailed: {
            root.readSavedIndex()
            root.restoredFromDisk = true
            root.applyInitialIndex()
        }
    }

    onStateServiceChanged: {
        root.restoredFromDisk = false
        root.readSavedIndex()
    }

    FileView {
        id: walFile
        path: Quickshell.env("HOME") + "/.cache/wal/wal"
        preload: true
        watchChanges: true
        blockLoading: true
        printErrors: false

        onLoaded: root.updateCurrentWallpaper(walFile.text())
        onFileChanged: {
            reload()
            root.updateCurrentWallpaper(walFile.text())
        }
    }

    FolderListModel {
        id: wallpapers
        folder: "file://" + root.wallDir
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif"]
        showDirs: false
        showFiles: true
        sortField: FolderListModel.Name
        onCountChanged: {
            if (!root.initialPositionDone) {
                root.applyInitialIndex()
            } else {
                root.selectedIndex = Math.min(root.selectedIndex, Math.max(0, count - 1))
                root.visualIndex = count + root.selectedIndex
                delayedPosition.restart()
            }
        }
    }

    onSelectedIndexChanged: {
        if (wallpapers.count > 0 && visualIndex % wallpapers.count !== selectedIndex)
            visualIndex = wallpapers.count + selectedIndex
        if (initialPositionDone) {
            persistSelectedIndex()
            playActiveSound()
        }
    }

    onVisualIndexChanged: {
        if (strip.currentIndex !== visualIndex)
            strip.currentIndex = visualIndex
    }

    onVisibleChanged: {
        if (visible) {
            closing = false
            openAnim.restart()
            forceRootFocus.restart()
            openPosition.restart()
        }
    }

    Timer {
        id: forceRootFocus
        interval: 25
        repeat: false
        onTriggered: focusCatcher.forceActiveFocus()
    }

    Timer {
        id: openPosition
        interval: 50
        repeat: false
        onTriggered: root.positionStripNow()
    }

    Timer {
        id: applyClose
        interval: 100
        repeat: false
        onTriggered: root.closeAnimated()
    }

    Timer {
        id: restoreStripAnimation
        interval: 16
        repeat: false
        onTriggered: root.animateStrip = true
    }

    Timer {
        id: delayedPosition
        interval: 70
        repeat: false
        onTriggered: root.positionStripNow()
    }

    Timer {
        id: activeSoundThrottle
        interval: 85
        repeat: false
        onTriggered: root.lastActiveSoundIndex = -1
    }

    Item {
        id: focusCatcher
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.closeAnimated()
                event.accepted = true
            } else if (event.key === Qt.Key_Right) {
                root.next()
                event.accepted = true
            } else if (event.key === Qt.Key_Left) {
                root.previous()
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.applySelected()
                event.accepted = true
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: root.closeAnimated()
            onWheel: function(wheel) {
                if (wheel.angleDelta.y < 0 || wheel.angleDelta.x > 0)
                    root.next()
                else if (wheel.angleDelta.y > 0 || wheel.angleDelta.x < 0)
                    root.previous()
            }
        }
    }

    Item {
        id: shell

        anchors.centerIn: parent
        width: Math.min(root.width + 220, 1420)
        height: 360
        clip: false
        opacity: 0
        scale: 0.92
        y: 18
        transformOrigin: Item.Center

        onWidthChanged: {
            if (root.visible && !strip.moving && !strip.flicking)
                root.positionStripNow()
        }

        SequentialAnimation {
            id: openAnim
            ParallelAnimation {
                NumberAnimation { target: shell; property: "opacity"; from: 0; to: 1; duration: theme && theme.reducedMotion ? Math.round(240 / 2) : 240; easing.type: Easing.OutCubic }
                NumberAnimation { target: shell; property: "scale"; from: 0.92; to: 1; duration: theme && theme.reducedMotion ? Math.round(320 / 2) : 320; easing.type: Easing.OutCubic }
                NumberAnimation { target: shell; property: "y"; from: 18; to: 0; duration: theme && theme.reducedMotion ? Math.round(320 / 2) : 320; easing.type: Easing.OutCubic }
            }
        }

        SequentialAnimation {
            id: closeAnim
            ParallelAnimation {
                NumberAnimation { target: shell; property: "opacity"; from: shell.opacity; to: 0; duration: theme && theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.InCubic }
                NumberAnimation { target: shell; property: "scale"; from: shell.scale; to: 0.94; duration: theme && theme.reducedMotion ? Math.round(190 / 2) : 190; easing.type: Easing.InCubic }
                NumberAnimation { target: shell; property: "y"; from: shell.y; to: 14; duration: theme && theme.reducedMotion ? Math.round(190 / 2) : 190; easing.type: Easing.InCubic }
            }
            ScriptAction {
                script: {
                    root.visible = false
                    root.closing = false
                }
            }
        }

        ListView {
            id: strip
            property int slotWidth: 110
            property int slotStride: slotWidth + spacing

            anchors.fill: parent
            anchors.leftMargin: 0
            anchors.rightMargin: 0
            clip: false
            model: wallpapers.count > 0 ? wallpapers.count * repeatCount : 0
            orientation: ListView.Horizontal
            boundsBehavior: Flickable.StopAtBounds
            highlightRangeMode: ListView.NoHighlightRange
            snapMode: ListView.SnapToItem
            spacing: 0
            currentIndex: root.visualIndex
            cacheBuffer: 650
            maximumFlickVelocity: 1300
            flickDeceleration: 1800

            Behavior on contentX {
                enabled: root.animateStrip
                NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(380 / 2) : 380; easing.type: Easing.OutCubic }
            }

            Component.onCompleted: delayedPosition.restart()
            onCurrentIndexChanged: {
                if (wallpapers.count > 0 && currentIndex >= 0) {
                    root.visualIndex = currentIndex
                    root.selectedIndex = currentIndex % wallpapers.count
                }
            }

            delegate:
                WallpaperCard {
                    property int actualIndex: wallpapers.count > 0 ? index % wallpapers.count : 0

                    theme: root.theme
                    slotWidth: strip.slotWidth
                    fileName: wallpapers.get(actualIndex, "fileName")
                    fileUrl: wallpapers.get(actualIndex, "fileUrl")
                    active: index === root.visualIndex
                    distance: index - root.visualIndex
                    open: root.visible && !root.closing
                    onClicked: {
                        root.selectAndApply(actualIndex, index)
                    }
                }
        }
    }

    function open() {
        if (wallpapers.count <= 0)
            return
        closeAnim.stop()
        closing = false
        syncToCurrentWallpaper()
        visible = true
    }

    function toggle() {
        if (visible)
            closeAnimated()
        else
            open()
    }

    function closeAnimated() {
        if (!visible || closing)
            return
        closing = true
        openAnim.stop()
        closeAnim.restart()
    }

    function next() {
        if (wallpapers.count > 0) {
            visualIndex += 1
            selectedIndex = normalizeIndex(visualIndex)
            syncStrip()
        }
    }

    function previous() {
        if (wallpapers.count > 0) {
            visualIndex -= 1
            selectedIndex = normalizeIndex(visualIndex)
            syncStrip()
        }
    }

    function wrapDelta(index) {
        const count = wallpapers.count
        if (count <= 0)
            return 0
        let d = index - selectedIndex
        if (d > count / 2)
            d -= count
        if (d < -count / 2)
            d += count
        return d
    }

    function applySelected() {
        if (wallpapers.count <= 0)
            return
        const name = wallpapers.get(selectedIndex, "fileName")
        currentWallpaperName = name
        persistSelectedIndex()
        Quickshell.execDetached([Services.Config.wallpaperScript, "wallpaper", "apply", name])
        playAppliedSound()
        applyClose.restart()
    }

    function selectAndApply(index, preferredVisualIndex) {
        if (index < 0 || index >= wallpapers.count)
            return
        selectedIndex = index
        visualIndex = preferredVisualIndex === undefined ? wallpapers.count + selectedIndex : preferredVisualIndex
        syncStrip()
        persistSelectedIndex()
        const name = wallpapers.get(selectedIndex, "fileName")
        currentWallpaperName = name
        Quickshell.execDetached([Services.Config.wallpaperScript, "wallpaper", "apply", name])
        playAppliedSound()
        applyClose.restart()
    }

    function playAppliedSound() {
        Quickshell.execDetached([
            "sh",
            "-c",
            "if command -v pw-play >/dev/null 2>&1; then pw-play \"$1\"; elif command -v paplay >/dev/null 2>&1; then paplay \"$1\"; elif command -v mpv >/dev/null 2>&1; then mpv --no-terminal --really-quiet \"$1\"; fi",
            "wallpaper-applied-sound",
            Services.Config.wallpaperAppliedSoundPath
        ])
    }

    function playActiveSound() {
        if (!visible || closing || wallpapers.count <= 0)
            return
        if (selectedIndex === lastActiveSoundIndex && activeSoundThrottle.running)
            return

        lastActiveSoundIndex = selectedIndex
        activeSoundThrottle.restart()
        Quickshell.execDetached([
            "sh",
            "-c",
            "if command -v pw-play >/dev/null 2>&1; then pw-play \"$1\"; elif command -v paplay >/dev/null 2>&1; then paplay \"$1\"; elif command -v mpv >/dev/null 2>&1; then mpv --no-terminal --really-quiet \"$1\"; fi",
            "wallpaper-active-sound",
            Services.Config.wallpaperActiveSoundPath
        ])
    }

    function syncStrip() {
        if (wallpapers.count <= 0)
            return
        strip.currentIndex = visualIndex
        strip.contentX = targetContentX()
    }

    function positionStripNow() {
        if (wallpapers.count <= 0)
            return

        animateStrip = false
        const base = repeatMiddle * wallpapers.count
        visualIndex = base + selectedIndex
        strip.currentIndex = visualIndex
        strip.positionViewAtIndex(visualIndex, ListView.Center)
        strip.contentX = targetContentX()
        initialPositionDone = true
        restoreStripAnimation.restart()
    }

    function targetContentX() {
        return Math.max(0, visualIndex * strip.slotStride + strip.slotWidth / 2 - strip.width / 2)
    }

    function normalizeIndex(index) {
        if (wallpapers.count <= 0)
            return 0
        return ((index % wallpapers.count) + wallpapers.count) % wallpapers.count
    }

    function recenterVisualIndex() {
        if (wallpapers.count <= 0)
            return
        const base = repeatMiddle * wallpapers.count
        visualIndex = base + selectedIndex
        strip.currentIndex = visualIndex
        strip.contentX = targetContentX()
    }

    function readSavedIndex() {
        if (restoredFromDisk)
            return

        const stored = stateService && stateService.ready ? Number(stateService.value("wallpaperIndex", -1)) : -1
        if (!isNaN(stored) && stored >= 0)
            savedIndex = stored

        const raw = stateFile.text().trim()
        const parsed = parseInt(raw, 10)
        if (savedIndex < 0 && !isNaN(parsed) && parsed >= 0)
            savedIndex = parsed
        restoredFromDisk = true
        applyInitialIndex()
    }

    function applyInitialIndex() {
        if (!restoredFromDisk || wallpapers.count <= 0)
            return

        const currentIndex = indexForWallpaperName(currentWallpaperName)
        const baseIndex = currentIndex >= 0 ? currentIndex : (savedIndex >= 0 ? savedIndex : selectedIndex)
        selectedIndex = Math.min(Math.max(0, baseIndex), wallpapers.count - 1)
        visualIndex = repeatMiddle * wallpapers.count + selectedIndex
        delayedPosition.restart()
    }

    function persistSelectedIndex() {
        if (wallpapers.count <= 0)
            return
        savedIndex = selectedIndex
        stateFile.setText(selectedIndex + "\n")
        if (stateService && stateService.ready)
            stateService.setValue("wallpaperIndex", selectedIndex)
    }

    function updateCurrentWallpaper(text) {
        const path = String(text || "").trim()
        if (path.length === 0)
            return
        const parts = path.split("/")
        currentWallpaperName = parts[parts.length - 1]
    }

    function indexForWallpaperName(name) {
        if (!name || wallpapers.count <= 0)
            return -1
        for (let i = 0; i < wallpapers.count; i++) {
            if (wallpapers.get(i, "fileName") === name)
                return i
        }
        return -1
    }

    function syncToCurrentWallpaper() {
        const idx = indexForWallpaperName(currentWallpaperName)
        if (idx < 0)
            return
        selectedIndex = idx
        visualIndex = repeatMiddle * wallpapers.count + selectedIndex
    }
}

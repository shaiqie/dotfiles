import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../services" as Services
import "components/clipboard"

PanelWindow {
    id: root

    property var theme
    property string query: ""
    property string filter: "All"
    property int selectedIndex: 0
    property bool opening: false
    property bool closing: false
    property bool panelShown: false
    property var stateService
    property bool entranceOpen: false
    property string toastText: ""
    property var entries: []
    property var pins: []
    property var freshIds: []
    property var animatedIds: []
    property var pendingPaste: null
    property string activePasteId: ""
    property string errorText: ""
    property real searchShake: 0
    property real panelOpacity: 0
    property real panelScale: 0.95
    property real panelOffsetY: 20
    readonly property var filtered: filterEntries()
    readonly property int panelWidth: 520
    readonly property int maxListHeight: 380

    anchors {
        left: true
        right: true
        bottom: true
    }

    margins {
        bottom: 34
    }

    visible: opening || panelShown || closing
    aboveWindows: true
    focusable: true
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: panel.width
    implicitHeight: panel.height + 24
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "shells-clipboard"

    IpcHandler {
        target: "clipboard"
        function toggle() { root.toggle() }
        function open() { root.open() }
        function close() { root.closeAnimated() }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: root.closeAnimated()
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.visible
        acceptedButtons: Qt.LeftButton
        onClicked: root.closeAnimated()
    }

    FileView {
        id: pinsFile
        path: Quickshell.env("HOME") + "/.cache/quickshell/clipboard-pins.json"
        preload: true
        blockLoading: true
        printErrors: false
        onLoaded: root.loadPins(text())
    }

    onStateServiceChanged: loadState()

    Process {
        id: ensureCache
        command: ["mkdir", "-p", Quickshell.env("HOME") + "/.cache/quickshell"]
    }

    Process {
        id: listProc
        command: [Services.Config.cliphistBin, "list"]
        stdout: StdioCollector {
            id: listOut
            waitForEnd: true
        }
        stderr: StdioCollector { id: listErr; waitForEnd: true }
        onExited: function(code) {
            if (code === 0) {
                root.errorText = ""
                root.parseList(listOut.text)
            } else {
                root.errorText = root.processError(listErr.text, "Clipboard history unavailable")
                root.entries = []
            }
        }
    }

    Process {
        id: pasteProc
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { id: pasteErr; waitForEnd: true }
        onExited: function(code) {
            if (code !== 0) {
                root.errorText = root.processError(pasteErr.text, "Clipboard paste failed")
                root.showToast("Paste failed")
                root.activePasteId = ""
                return
            }
            root.errorText = ""
            root.closeAnimated()
        }
    }

    Process {
        id: deleteProc
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { id: deleteErr; waitForEnd: true }
        onExited: function(code) {
            if (code !== 0) {
                root.errorText = root.processError(deleteErr.text, "Delete failed")
                root.showToast("Delete failed")
                return
            }
            root.errorText = ""
            root.showToast("Deleted")
            root.refresh()
        }
    }

    Timer { id: focusTimer; interval: 35; repeat: false; onTriggered: searchInput.forceActiveFocus() }
    Timer { id: toastTimer; interval: 1200; repeat: false; onTriggered: root.toastText = "" }
    Timer {
        id: openRefreshTimer
        interval: 260
        repeat: false
        onTriggered: root.refresh()
    }
    Timer {
        id: entranceTimer
        interval: 700
        repeat: false
        onTriggered: root.entranceOpen = false
    }
    Timer {
        id: pasteDelay
        interval: 420
        repeat: false
        onTriggered: {
            if (root.pendingPaste)
                root.paste(root.pendingPaste)
        }
    }
    Timer {
        id: freshTimer
        interval: 3000
        repeat: false
        onTriggered: root.freshIds = []
    }
    SequentialAnimation {
        id: queryShake
        NumberAnimation { target: root; property: "searchShake"; to: -6; duration: theme && theme.reducedMotion ? Math.round(45 / 2) : 45; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "searchShake"; to: 6; duration: theme && theme.reducedMotion ? Math.round(70 / 2) : 70; easing.type: Easing.InOutCubic }
        NumberAnimation { target: root; property: "searchShake"; to: -3; duration: theme && theme.reducedMotion ? Math.round(55 / 2) : 55; easing.type: Easing.InOutCubic }
        NumberAnimation { target: root; property: "searchShake"; to: 0; duration: theme && theme.reducedMotion ? Math.round(60 / 2) : 60; easing.type: Easing.OutCubic }
    }

    ParallelAnimation {
        id: enterAnim
        NumberAnimation { target: root; property: "panelOpacity"; from: 0; to: 1; duration: theme && theme.reducedMotion ? Math.round(200 / 2) : 200; easing.type: Easing.OutCubic }
        SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  target: root; property: "panelScale"; from: 0.95; to: 1; spring: 5.0; damping: 0.75; mass: 0.9; epsilon: 0.001 }
        SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  target: root; property: "panelOffsetY"; from: 20; to: 0; spring: 5.0; damping: 0.75; mass: 0.9; epsilon: 0.001 }
        onStarted: root.panelShown = true
        onStopped: root.opening = false
    }

    ParallelAnimation {
        id: exitAnim
        NumberAnimation { target: root; property: "panelOpacity"; to: 0; duration: theme && theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "panelScale"; to: 0.95; duration: theme && theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "panelOffsetY"; to: 14; duration: theme && theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic }
        onStarted: {
            root.panelShown = false
            root.closing = true
        }
        onStopped: root.finishClose()
    }

    Component.onCompleted: {
        ensureCache.exec(ensureCache.command)
        pinsFile.reload()
        loadState()
        refresh()
    }

    Rectangle {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: root.panelWidth
        height: Math.min(480, content.implicitHeight + 28)
        radius: 22
        color: root.theme.withAlpha(root.theme.background, root.theme.panelOpacity)
        border.width: 0
        clip: true
        opacity: root.panelOpacity
        scale: root.panelScale
        y: root.panelOffsetY
        transformOrigin: Item.Bottom

        Behavior on height { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.8; damping: 0.78; mass: 0.9; epsilon: 0.001 } }

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: function(mouse) { mouse.accepted = true } }

        Column {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.theme.panelPadding
            spacing: root.theme.itemSpacing + 2

            Rectangle {
                width: parent.width
                height: 52
                radius: 16
                color: root.theme.withAlpha(root.theme.foreground, 0.045)
                clip: true
                transform: Translate { x: root.searchShake }

                Rectangle {
                    width: 3
                    height: parent.height - 18
                    radius: 2
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.theme.color4
                    opacity: searchInput.activeFocus ? 1 : 0.55
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 28
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    color: root.theme.color6
                    font.family: root.theme.fontFamily
                    font.pixelSize: 15 * root.theme.fontScale
                }

                TextInput {
                    id: searchInput
                    anchors.left: parent.left
                    anchors.leftMargin: 54
                    anchors.right: clearButton.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.query
                    color: root.theme.foreground
                    selectionColor: root.theme.withAlpha(root.theme.color4, 0.35)
                    selectedTextColor: root.theme.foreground
                    cursorVisible: activeFocus
                    font.family: root.theme.fontFamily
                    font.pixelSize: 14 * root.theme.fontScale
                    clip: true
                    onTextChanged: {
                        root.query = text
                        root.selectedIndex = 0
                    }
                    Keys.onPressed: function(event) { root.handleKey(event) }
                }

                Text {
                    visible: searchInput.text.length === 0
                    anchors.left: searchInput.left
                    anchors.verticalCenter: searchInput.verticalCenter
                    text: "Search clipboard..."
                    color: root.theme.color6
                    font.family: root.theme.fontFamily
                    font.pixelSize: 14 * root.theme.fontScale
                }

                Text {
                    id: clearButton
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: "×"
                    color: root.theme.color6
                    font.family: root.theme.fontFamily
                    font.pixelSize: 18 * root.theme.fontScale
                    opacity: root.query.length > 0 ? 1 : 0
                    scale: root.query.length > 0 ? 1 : 0.5
                    Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(120 / 2) : 120; easing.type: Easing.OutCubic } }
                    Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.7; mass: 0.9; epsilon: 0.001 } }
                    MouseArea { anchors.fill: parent; onClicked: searchInput.text = "" }
                }
            }

            Item {
                width: parent.width
                height: 34
                clip: true

                Row {
                    id: chipRow
                    spacing: 6
                    Repeater {
                        model: ["All", "Text", "Images", "Code"]
                        Rectangle {
                            property bool active: root.filter === modelData
                            width: chipText.implicitWidth + 28
                            height: 30
                            radius: 12
                            color: active ? root.theme.withAlpha(root.theme.color4, 0.16) : root.theme.withAlpha(root.theme.foreground, 0.040)
                            scale: chipArea.pressed ? 0.94 : (chipArea.containsMouse ? 1.035 : 1)
                            Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(160 / 2) : 160; easing.type: Easing.OutCubic } }
                            Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5; damping: 0.8; mass: 0.9; epsilon: 0.001 } }
                            Rectangle {
                                width: 3
                                height: parent.height - 12
                                radius: 2
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                color: root.theme.color4
                                opacity: parent.active ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: root.theme.reducedMotion ? 0 : 140; easing.type: Easing.OutCubic } }
                            }
                            Text {
                                id: chipText
                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: parent.active ? 3 : 0
                                text: modelData
                                color: parent.active ? root.theme.color4 : root.theme.color6
                                font.family: root.theme.fontFamily
                                font.pixelSize: 11 * root.theme.fontScale
                                font.bold: parent.active || root.theme.fontBold
                            }
                            MouseArea {
                                id: chipArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    root.filter = modelData
                                    root.selectedIndex = 0
                                }
                            }
                        }
                    }
                }
            }

            Text {
                width: parent.width
                visible: root.errorText.length > 0
                text: root.errorText
                color: root.theme.color1
                font.family: root.theme.fontFamily
                font.pixelSize: 12 * root.theme.fontScale
                elide: Text.ElideRight
            }

            Item {
                width: parent.width
                height: Math.min(root.maxListHeight, Math.max(120, entryList.contentHeight))
                clip: true

                ListView {
                    id: entryList
                    anchors.fill: parent
                    clip: true
                    model: root.filtered
                    spacing: 4
                    reuseItems: true
                    currentIndex: -1
                    boundsBehavior: Flickable.StopAtBounds
                    highlightFollowsCurrentItem: false
                    highlightMoveDuration: 180
                    highlightRangeMode: ListView.NoHighlightRange
                    preferredHighlightBegin: 0
                    preferredHighlightEnd: height - 76

                    delegate: ClipboardEntry {
                        width: entryList.width
                        theme: root.theme
                        entry: modelData
                        selected: index === root.selectedIndex
                        pinned: root.isPinned(modelData.id)
                        entryIndex: index
                        appearDelay: index * 35
                        hasAnimatedIn: !root.entranceOpen || root.hasAnimated(modelData.id)
                        dimmed: root.activePasteId.length > 0
                        pasting: root.activePasteId === modelData.id
                        fresh: root.freshIds.indexOf(modelData.id) >= 0
                        onClicked: root.beginPaste(modelData)
                        onDeleteRequested: root.deleteEntry(modelData)
                        onPinRequested: root.togglePin(modelData)
                        onAppearedOnce: root.markAnimated(modelData.id)
                    }

                    Keys.onPressed: function(event) { root.handleKey(event) }
                }

                Item {
                    anchors.fill: parent
                    visible: root.filtered.length === 0
                    opacity: visible ? 1 : 0
                    scale: visible ? 1 : 0.9
                    Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(160 / 2) : 160; easing.type: Easing.OutCubic } }
                    Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.8; damping: 0.76; mass: 0.9; epsilon: 0.001 } }
                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        Rectangle {
                            width: 64
                            height: 64
                            radius: 32
                            color: root.theme.withAlpha(root.theme.color4, 0.16)
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: bob
                            SequentialAnimation on bob {
                                loops: Animation.Infinite
                                NumberAnimation { to: -4; duration: theme && theme.reducedMotion ? Math.round(1000 / 2) : 1000; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0; duration: theme && theme.reducedMotion ? Math.round(1000 / 2) : 1000; easing.type: Easing.InOutSine }
                            }
                            property real bob: 0
                            Text { anchors.centerIn: parent; text: "󰅇"; color: root.theme.color4; font.family: root.theme.fontFamily; font.pixelSize: 28 * root.theme.fontScale }
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.query.length > 0 ? ("No results for " + root.query) : "No clipboard history"; color: root.theme.foreground; font.family: root.theme.fontFamily; font.pixelSize: 15 * root.theme.fontScale; font.bold: root.theme.fontBold }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "cliphist list returned nothing"; color: root.theme.color6; font.family: root.theme.fontFamily; font.pixelSize: 12 * root.theme.fontScale }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 28
                    z: 8
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: root.theme.withAlpha(root.theme.color0, 0.94) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 28
                    z: 8
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: root.theme.withAlpha(root.theme.color0, 0.94) }
                    }
                }
            }
        }

        Rectangle {
            width: toastLabel.implicitWidth + 28
            height: 32
            radius: root.theme.pillRadius
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.toastText.length > 0 ? 12 : 2
            color: root.theme.withAlpha(root.theme.color4, 0.22)
            border.width: 0
            opacity: root.toastText.length > 0 ? 1 : 0
            scale: root.toastText.length > 0 ? 1 : 0.85
            Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(150 / 2) : 150; easing.type: Easing.OutCubic } }
            Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.7; mass: 0.9; epsilon: 0.001 } }
            Behavior on anchors.bottomMargin { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.75; mass: 0.9; epsilon: 0.001 } }
            Text { id: toastLabel; anchors.centerIn: parent; text: root.toastText; color: root.theme.color4; font.family: root.theme.fontFamily; font.pixelSize: 12 * root.theme.fontScale; font.bold: root.theme.fontBold }
        }
    }

    function toggle() {
        panelShown ? closeAnimated() : open()
    }

    function open() {
        if (root.panelShown || root.opening)
            return
        exitAnim.stop()
        openRefreshTimer.stop()
        focusTimer.stop()
        entranceTimer.stop()
        opening = true
        closing = false
        panelShown = false
        panelOpacity = 0
        panelScale = 0.95
        panelOffsetY = 20
        entranceOpen = true
        animatedIds = []
        query = ""
        filter = "All"
        selectedIndex = 0
        activePasteId = ""
        pendingPaste = null
        Qt.callLater(function() {
            enterAnim.restart()
            focusTimer.restart()
            entranceTimer.restart()
            openRefreshTimer.restart()
        })
    }

    function closeAnimated() {
        if (!visible || closing)
            return
        enterAnim.stop()
        openRefreshTimer.stop()
        focusTimer.stop()
        entranceTimer.stop()
        exitAnim.restart()
    }

    function refresh() {
        listProc.exec(listProc.command)
        if (root.stateService && root.stateService.ready)
            pins = root.stateService.value("clipboardPins", pins)
        else
            pinsFile.reload()
    }

    function finishClose() {
        opening = false
        closing = false
        panelShown = false
        activePasteId = ""
        pendingPaste = null
        animatedIds = []
        entranceOpen = false
        panelOpacity = 0
        panelScale = 0.95
        panelOffsetY = 20
        searchShake = 0
    }

    function parseList(text) {
        const oldFirst = entries.length > 0 ? entries[0].id : ""
        const rows = []
        const lines = text.trim().length > 0 ? text.trim().split("\n") : []
        for (let i = 0; i < lines.length; i++) {
            const tab = lines[i].indexOf("\t")
            if (tab <= 0)
                continue
            const id = lines[i].slice(0, tab)
            const content = lines[i].slice(tab + 1)
            rows.push({
                id: id,
                order: i,
                content: content,
                preview: content.replace(/\s+/g, " ").trim(),
                type: detectType(content),
                timestamp: Date.now() - i * 60000
            })
        }
        rows.sort(function(a, b) {
            const ap = isPinned(a.id) ? 1 : 0
            const bp = isPinned(b.id) ? 1 : 0
            if (ap !== bp)
                return bp - ap
            return a.order - b.order
        })
        if (panelShown && rows.length > 0 && oldFirst.length > 0 && rows[0].id !== oldFirst) {
            freshIds = [rows[0].id]
            freshTimer.restart()
            if (query.length > 0 && filterEntriesForRows(rows).indexOf(rows[0]) < 0)
                queryShake.restart()
        }
        entries = rows
    }

    function detectType(text) {
        const lower = text.toLowerCase()
        if (lower.indexOf("[[ binary data") >= 0 || lower.indexOf("image") >= 0)
            return "Images"
        if (/[{}();=<>]/.test(text))
            return "Code"
        return "Text"
    }

    function filterEntries() {
        return filterEntriesForRows(entries)
    }

    function filterEntriesForRows(rows) {
        const q = query.toLowerCase()
        return rows.filter(function(item) {
            const passFilter = filter === "All" || item.type === filter
            const passQuery = q.length === 0 || item.content.toLowerCase().indexOf(q) >= 0
            return passFilter && passQuery
        })
    }

    function beginPaste(item) {
        if (!item)
            return
        pendingPaste = item
        activePasteId = item.id
        showToast("Copied!")
        pasteDelay.restart()
    }

    function paste(item) {
        if (!item)
            return
        pasteProc.exec(["sh", "-c", "\"$2\" decode \"$1\" | \"$3\" && { if command -v \"$4\" >/dev/null 2>&1; then \"$4\" key ctrl+v; else \"$5\" dispatch sendshortcut CTRL,V,activewindow; fi; }", "sh", item.id, Services.Config.cliphistBin, Services.Config.wlCopyBin, Services.Config.ydotoolBin, Services.Config.hyprctlBin])
    }

    function deleteEntry(item) {
        if (!item)
            return
        deleteProc.exec([Services.Config.cliphistBin, "delete-query", item.content])
    }

    function processError(text, fallback) {
        const msg = String(text || "").trim()
        return msg.length > 0 ? msg : fallback
    }

    function loadState() {
        if (stateService && stateService.ready)
            pins = stateService.value("clipboardPins", pins)
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            closeAnimated()
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            selectedIndex = Math.min(filtered.length - 1, selectedIndex + 1)
            entryList.positionViewAtIndex(selectedIndex, ListView.Contain)
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            selectedIndex = Math.max(0, selectedIndex - 1)
            entryList.positionViewAtIndex(selectedIndex, ListView.Contain)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            paste(filtered[selectedIndex])
            event.accepted = true
        } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            deleteEntry(filtered[selectedIndex])
            event.accepted = true
        } else if (event.key === Qt.Key_Tab) {
            const filters = ["All", "Text", "Images", "Code"]
            filter = filters[(filters.indexOf(filter) + 1) % filters.length]
            event.accepted = true
        }
    }

    function showToast(text) {
        toastText = text
        toastTimer.restart()
    }

    function loadPins(text) {
        try {
            pins = JSON.parse(text)
        } catch (e) {
            pins = []
        }
    }

    function persistPins() {
        pinsFile.setText(JSON.stringify(pins))
        if (stateService && stateService.ready)
            stateService.setValue("clipboardPins", pins)
    }

    function isPinned(id) {
        return pins.indexOf(id) >= 0
    }

    function hasAnimated(id) {
        return animatedIds.indexOf(id) >= 0
    }

    function markAnimated(id) {
        if (animatedIds.indexOf(id) >= 0)
            return
        animatedIds = animatedIds.concat([id])
    }

    function togglePin(item) {
        const idx = pins.indexOf(item.id)
        if (idx >= 0)
            pins.splice(idx, 1)
        else
            pins.push(item.id)
        pins = pins.slice()
        persistPins()
        parseList(entries.map(function(e) { return e.id + "\t" + e.content }).join("\n"))
    }
}

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../services" as Services
import "components/emoji"

PanelWindow {
    id: root

    property var theme
    property string query: ""
    property string category: "All"
    property int selectedIndex: -1
    property bool closing: false
    property bool panelShown: false
    property var stateService
    property bool entranceOpen: false
    property string toastText: ""
    property var emojis: []
    property var recent: []
    property var animatedIds: []
    property string activeEmoji: ""
    property string errorText: ""
    property real confirmScale: 1
    property real confirmOpacity: 0
    readonly property int panelWidth: 520
    readonly property int gridHeight: 320
    readonly property var categories: [
        { key: "All", label: "󰞅 All" },
        { key: "Smileys & Emotion", label: "😀 Smileys" },
        { key: "People & Body", label: "🧑 People" },
        { key: "Animals & Nature", label: "🐱 Animals" },
        { key: "Food & Drink", label: "🍔 Food" },
        { key: "Travel & Places", label: "✈️ Travel" },
        { key: "Activities", label: "⚽ Activities" },
        { key: "Objects", label: "💡 Objects" },
        { key: "Symbols", label: "🔣 Symbols" },
        { key: "Flags", label: "🏁 Flags" }
    ]
    readonly property var filtered: filterEmojis()

    anchors {
        left: true
        right: true
        bottom: true
    }

    margins.bottom: 16
    visible: panelShown || closing
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
    WlrLayershell.namespace: "shells-emoji-picker"

    IpcHandler {
        target: "emojiPicker"
        function toggle() { root.toggle() }
        function open() { root.open() }
        function close() { root.closeAnimated() }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.visible
        acceptedButtons: Qt.LeftButton
        onClicked: root.closeAnimated()
    }

    FileView {
        id: emojiFile
        path: "/usr/share/rofi-emoji/all_emojis.txt"
        preload: true
        blockLoading: true
        printErrors: false
        onLoaded: root.parseEmojiData(text())
    }

    FileView {
        id: recentFile
        path: Quickshell.env("HOME") + "/.cache/quickshell/recent-emojis.json"
        preload: true
        blockLoading: true
        printErrors: false
        onLoaded: root.loadRecent(text())
    }

    onStateServiceChanged: loadState()

    Process {
        id: ensureCache
        command: ["mkdir", "-p", Quickshell.env("HOME") + "/.cache/quickshell"]
    }

    Process {
        id: pasteProc
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { id: pasteErr; waitForEnd: true }
        onExited: function(code) {
            if (code !== 0) {
                root.errorText = root.processError(pasteErr.text, "Emoji paste failed")
                root.showToast("Paste failed")
                return
            }
            root.errorText = ""
        }
    }

    Component.onCompleted: {
        ensureCache.exec(ensureCache.command)
        emojiFile.reload()
        loadState()
        if (!stateService || !stateService.ready)
            recentFile.reload()
    }

    Timer { id: focusTimer; interval: 35; repeat: false; onTriggered: searchInput.forceActiveFocus() }
    Timer { id: toastTimer; interval: 1200; repeat: false; onTriggered: root.toastText = "" }
    Timer { id: entranceTimer; interval: 820; repeat: false; onTriggered: root.entranceOpen = false }
    Timer {
        id: pasteDelay
        interval: 360
        repeat: false
        onTriggered: if (root.activeEmoji.length > 0) root.copyAndPaste(root.activeEmoji)
    }

    Rectangle {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: root.panelWidth
        height: Math.min(520, content.implicitHeight + 28)
        radius: 22
        color: root.theme.withAlpha(root.theme.background, root.theme.panelOpacity)
        border.width: 0
        clip: true
        opacity: root.panelShown ? 1 : 0
        scale: root.panelShown ? 1 : 0.95
        y: root.panelShown ? 0 : 20
        transformOrigin: Item.Bottom

        Behavior on height { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.8; damping: 0.78; mass: 0.9; epsilon: 0.001 } }
        Behavior on y { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.75; mass: 0.9; epsilon: 0.001 } }
        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.75; mass: 0.9; epsilon: 0.001 } }
        Behavior on opacity { NumberAnimation { duration: root.panelShown ? 200 : 180; easing.type: Easing.OutCubic } }

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
                        root.selectedIndex = root.filtered.length > 0 ? 0 : -1
                        root.resetGridAnimation()
                    }
                    Keys.onPressed: function(event) { root.handleKey(event) }
                }

                Text {
                    visible: searchInput.text.length === 0
                    anchors.left: searchInput.left
                    anchors.verticalCenter: searchInput.verticalCenter
                    text: "Search emoji..."
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

                Flickable {
                    id: categoryFlick
                    anchors.fill: parent
                    contentWidth: categoryRow.implicitWidth
                    contentHeight: height
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: true
                    flickableDirection: Flickable.HorizontalFlick
                    Behavior on contentX { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic } }

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: function(event) {
                            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : -event.angleDelta.x
                            const maxX = Math.max(0, categoryFlick.contentWidth - categoryFlick.width)
                            categoryFlick.contentX = Math.max(0, Math.min(maxX, categoryFlick.contentX - delta * 0.45))
                            event.accepted = true
                        }
                    }

                    Row {
                        id: categoryRow
                        spacing: 6
                        Repeater {
                            model: root.categories
                            Rectangle {
                                property bool active: root.category === modelData.key
                                width: tabText.implicitWidth + 28
                                height: 30
                                radius: 12
                                color: active ? root.theme.withAlpha(root.theme.color4, 0.16) : root.theme.withAlpha(root.theme.foreground, 0.040)
                                scale: tabArea.pressed ? 0.94 : (tabArea.containsMouse ? 1.035 : 1)
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
                                    id: tabText
                                    anchors.centerIn: parent
                                    anchors.horizontalCenterOffset: parent.active ? 3 : 0
                                    text: modelData.label
                                    color: parent.active ? root.theme.color4 : root.theme.color6
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: 11 * root.theme.fontScale
                                    font.bold: parent.active || root.theme.fontBold
                                }
                                MouseArea {
                                    id: tabArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: root.setCategory(modelData.key)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 28
                    visible: categoryFlick.contentX > 1
                    opacity: visible ? 1 : 0
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: root.theme.withAlpha(root.theme.color0, 0.94) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                    Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(140 / 2) : 140; easing.type: Easing.OutCubic } }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 28
                    visible: categoryFlick.contentX < Math.max(0, categoryFlick.contentWidth - categoryFlick.width) - 1
                    opacity: visible ? 1 : 0
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: root.theme.withAlpha(root.theme.color0, 0.94) }
                    }
                    Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(140 / 2) : 140; easing.type: Easing.OutCubic } }
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

            Column {
                width: parent.width
                spacing: 4
                height: root.recent.length > 0 ? 58 : 0
                opacity: root.recent.length > 0 ? 1 : 0
                clip: true
                Behavior on height { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.78; mass: 0.9; epsilon: 0.001 } }
                Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(160 / 2) : 160; easing.type: Easing.OutCubic } }

                Text {
                    text: "Recent"
                    color: root.theme.color6
                    font.family: root.theme.fontFamily
                    font.pixelSize: 10 * root.theme.fontScale
                    font.capitalization: Font.AllUppercase
                }

                Row {
                    spacing: 4
                    Repeater {
                        model: root.recent
                        EmojiCell {
                            theme: root.theme
                            itemData: root.findEmoji(modelData)
                            compact: true
                            cellIndex: index
                            hasAnimatedIn: true
                            idlePaused: root.query.length > 0
                            onChosen: root.chooseEmoji(modelData)
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: root.gridHeight
                clip: true

                GridView {
                    id: emojiGrid
                    anchors.fill: parent
                    clip: true
                    model: root.filtered
                    cellWidth: 48
                    cellHeight: 48
                    currentIndex: -1
                    boundsBehavior: Flickable.StopAtBounds
                    highlightFollowsCurrentItem: false
                    highlightRangeMode: GridView.NoHighlightRange
                    opacity: root.filtered.length > 0 ? 1 : 0
                    scale: root.filtered.length > 0 ? 1 : 0.97
                    Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(150 / 2) : 150; easing.type: Easing.OutCubic } }
                    Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5; damping: 0.75; mass: 0.9; epsilon: 0.001 } }

                    delegate: EmojiCell {
                        theme: root.theme
                        itemData: modelData
                        cellIndex: index
                        appearDelay: (Math.floor(index / 10) * 30) + ((index % 10) * 20)
                        selected: index === root.selectedIndex
                        hasAnimatedIn: !root.entranceOpen || root.hasAnimated(modelData.emoji)
                        idlePaused: root.query.length > 0
                        onChosen: root.chooseEmoji(modelData.emoji)
                        onHasAnimatedInChanged: if (hasAnimatedIn) root.markAnimated(modelData.emoji)
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
                            Text { anchors.centerIn: parent; text: "🔍"; font.family: root.theme.fontFamily; font.pixelSize: 28 * root.theme.fontScale }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.query.length > 0 ? ("No emoji found for " + root.query) : "No emoji found"
                            color: root.theme.foreground
                            font.family: root.theme.fontFamily
                            font.pixelSize: 15 * root.theme.fontScale
                            font.bold: root.theme.fontBold
                        }
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: root.activeEmoji
            font.family: root.theme.fontFamily
            font.pixelSize: 34 * root.theme.fontScale
            opacity: root.confirmOpacity
            scale: root.confirmScale
            z: 30
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

    SequentialAnimation {
        id: confirmAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "confirmOpacity"; from: 1; to: 0; duration: theme && theme.reducedMotion ? Math.round(420 / 2) : 420; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "confirmScale"; from: 1; to: 2.5; duration: theme && theme.reducedMotion ? Math.round(420 / 2) : 420; easing.type: Easing.OutCubic }
        }
    }

    function toggle() {
        panelShown ? closeAnimated() : open()
    }

    function open() {
        ensureCache.exec(ensureCache.command)
        loadState()
        if (!stateService || !stateService.ready)
            recentFile.reload()
        visible = true
        closing = false
        panelShown = true
        entranceOpen = true
        animatedIds = []
        query = ""
        category = "All"
        selectedIndex = filtered.length > 0 ? 0 : -1
        focusTimer.restart()
        entranceTimer.restart()
    }

    function closeAnimated() {
        if (!visible)
            return
        panelShown = false
        closing = true
        closeTimer.restart()
    }

    Timer {
        id: closeTimer
        interval: 190
        repeat: false
        onTriggered: {
            root.visible = false
            root.closing = false
            root.animatedIds = []
            root.entranceOpen = false
            root.activeEmoji = ""
            root.query = ""
        }
    }

    function parseEmojiData(text) {
        const rows = []
        const lines = text.trim().split("\n")
        for (let i = 0; i < lines.length; i++) {
            const parts = lines[i].split("\t")
            if (parts.length < 4)
                continue
            const emoji = parts[0]
            const cat = parts[1]
            const name = parts[3]
            const keywords = parts.length > 4 ? parts[4].split("|").map(function(k) { return k.trim() }).filter(function(k) { return k.length > 0 }) : []
            rows.push({ emoji: emoji, name: name, category: cat, keywords: keywords, haystack: (name + " " + keywords.join(" ")).toLowerCase() })
        }
        emojis = rows
    }

    function filterEmojis() {
        const q = query.toLowerCase()
        return emojis.filter(function(item) {
            const passCat = category === "All" || item.category === category
            const passQuery = q.length === 0 || item.haystack.indexOf(q) >= 0 || item.emoji === query
            return passCat && passQuery
        })
    }

    function setCategory(cat) {
        if (category === cat)
            return
        category = cat
        selectedIndex = filtered.length > 0 ? 0 : -1
        resetGridAnimation()
    }

    function resetGridAnimation() {
        entranceOpen = true
        animatedIds = []
        entranceTimer.restart()
    }

    function chooseEmoji(emoji) {
        if (!emoji)
            return
        activeEmoji = emoji
        confirmScale = 1
        confirmOpacity = 1
        confirmAnim.restart()
        showToast("Copied!")
        addRecent(emoji)
        pasteDelay.restart()
    }

    function copyAndPaste(emoji) {
        root.closeAnimated()
        pasteProc.exec(["sh", "-c", "printf '%s' \"$1\" | \"$2\" && sleep 0.22 && { if command -v \"$3\" >/dev/null 2>&1; then \"$3\" key ctrl+v; elif command -v \"$4\" >/dev/null 2>&1; then \"$4\" -M ctrl v -m ctrl; else \"$5\" dispatch sendshortcut CTRL,V,activewindow; fi; }", "sh", emoji, Services.Config.wlCopyBin, Services.Config.ydotoolBin, Services.Config.wtypeBin, Services.Config.hyprctlBin])
    }

    function processError(text, fallback) {
        const msg = String(text || "").trim()
        return msg.length > 0 ? msg : fallback
    }

    function loadState() {
        if (stateService && stateService.ready)
            recent = stateService.value("recentEmojis", recent)
    }

    function handleKey(event) {
        const cols = Math.max(1, Math.floor(root.panelWidth / 48))
        if (event.key === Qt.Key_Escape) {
            closeAnimated()
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            selectedIndex = filtered.length > 0 ? (selectedIndex + 1 + filtered.length) % filtered.length : -1
            emojiGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            selectedIndex = filtered.length > 0 ? (selectedIndex - 1 + filtered.length) % filtered.length : -1
            emojiGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            selectedIndex = Math.min(filtered.length - 1, selectedIndex + cols)
            emojiGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
            event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            selectedIndex = Math.max(0, selectedIndex - cols)
            emojiGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (selectedIndex >= 0 && selectedIndex < filtered.length)
                chooseEmoji(filtered[selectedIndex].emoji)
            event.accepted = true
        } else if (event.key === Qt.Key_Tab) {
            const idx = categories.findIndex(function(c) { return c.key === category })
            setCategory(categories[(idx + 1) % categories.length].key)
            event.accepted = true
        }
    }

    function showToast(text) {
        toastText = text
        toastTimer.restart()
    }

    function loadRecent(text) {
        try {
            recent = JSON.parse(text)
        } catch (e) {
            recent = []
        }
    }

    function addRecent(emoji) {
        const next = [emoji].concat(recent.filter(function(e) { return e !== emoji })).slice(0, 8)
        recent = next
        recentFile.setText(JSON.stringify(next))
        if (stateService && stateService.ready)
            stateService.setValue("recentEmojis", next)
    }

    function findEmoji(emoji) {
        for (let i = 0; i < emojis.length; i++) {
            if (emojis[i].emoji === emoji)
                return emojis[i]
        }
        return { emoji: emoji, name: emoji, category: "Recent", keywords: [] }
    }

    function hasAnimated(id) {
        return animatedIds.indexOf(id) >= 0
    }

    function markAnimated(id) {
        if (animatedIds.indexOf(id) >= 0)
            return
        animatedIds = animatedIds.concat([id])
    }
}

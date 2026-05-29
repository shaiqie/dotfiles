import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

PanelWindow {
    id: root

    property var theme
    property string query: ""
    property int selectedIndex: 0
    property bool closing: false
    property bool launching: false
    property int launchPhase: 0
    property real topOffset: 0
    readonly property var results: search(query)
    readonly property int visibleCount: Math.min(results.length, 3)
    readonly property bool hasQuery: query.trim().length > 0
    readonly property int rowHeight: 56
    readonly property int rowSpacing: 2
    readonly property int resultHeight: hasQuery && visibleCount > 0 ? visibleCount * rowHeight + Math.max(0, visibleCount - 1) * rowSpacing : 0

    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        top: Math.round(root.topOffset)
    }

    visible: false
    aboveWindows: true
    focusable: true
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: panel.width
    implicitHeight: 360
    color: "transparent"
    surfaceFormat.opaque: false

    IpcHandler {
        target: "launcher"

        function toggle() {
            root.toggle()
        }

        function open() {
            root.open()
        }

        function close() {
            root.closeAnimated()
        }
    }

    onVisibleChanged: {
        if (visible) {
            closing = false
            launching = false
            launchPhase = 0
            selectedIndex = 0
            openAnim.restart()
            promptPulse.restart()
            focusTimer.restart()
        }
    }

    Timer {
        id: focusTimer
        interval: 30
        repeat: false
        onTriggered: searchInput.forceActiveFocus()
    }

    Timer {
        id: launchDropTimer
        interval: root.theme.reducedMotion ? 30 : 260
        repeat: false
        onTriggered: root.launchPhase = 2
    }

    Timer {
        id: launchCircleTimer
        interval: root.theme.reducedMotion ? 60 : 560
        repeat: false
        onTriggered: {
            root.launchPhase = 3
            panel.scale = 0.82
        }
    }

    Timer {
        id: launchFadeTimer
        interval: root.theme.reducedMotion ? 90 : 760
        repeat: false
        onTriggered: {
            root.launchPhase = 4
            panel.opacity = 0
            panel.scale = 0.18
            panel.y = -4
        }
    }

    Timer {
        id: launchDoneTimer
        interval: root.theme.reducedMotion ? 120 : 980
        repeat: false
        onTriggered: root.finishLaunchClose()
    }

    Rectangle {
        id: panel

        anchors.horizontalCenter: parent.horizontalCenter
        width: root.launching ? (root.launchPhase >= 3 ? 48 : 210) : 370
        height: root.launching ? (root.launchPhase >= 3 ? 48 : inputBar.height) : inputBar.height + (root.resultHeight > 0 ? root.resultHeight + 13 : 0)
        radius: root.launching && root.launchPhase >= 3 ? height / 2 : root.theme.panelRadius
        color: root.theme.withAlpha(root.theme.background, root.theme.panelOpacity)
        border.width: root.theme.outerBorder ? root.theme.borderWidth : 0
        border.color: root.theme.withAlpha(root.theme.color1, root.theme.borderOpacity)
        opacity: 0
        y: -4
        scale: 0.96
        transformOrigin: Item.Top
        clip: true

        Behavior on width { NumberAnimation { duration: root.theme.reducedMotion ? 0 : 300; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: root.theme.reducedMotion ? 0 : 280; easing.type: Easing.OutCubic } }
        Behavior on radius { NumberAnimation { duration: root.theme.reducedMotion ? 0 : 260; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: root.theme.reducedMotion ? 0 : 280; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: root.theme.reducedMotion ? 0 : 140; easing.type: Easing.OutCubic } }

        SequentialAnimation {
            id: openAnim
            ParallelAnimation {
                NumberAnimation { target: panel; property: "opacity"; from: 0; to: 1; duration: theme && theme.reducedMotion ? 0 : 220; easing.type: Easing.OutCubic }
                NumberAnimation { target: panel; property: "y"; from: -12; to: 0; duration: theme && theme.reducedMotion ? 0 : 320; easing.type: Easing.OutBack; easing.overshoot: 0.6 }
                NumberAnimation { target: panel; property: "scale"; from: 0.96; to: 1.0; duration: theme && theme.reducedMotion ? 0 : 300; easing.type: Easing.OutCubic }
            }
        }

        SequentialAnimation {
            id: closeAnim
            ParallelAnimation {
                NumberAnimation { target: panel; property: "opacity"; from: panel.opacity; to: 0; duration: theme && theme.reducedMotion ? 0 : 180; easing.type: Easing.InCubic }
                NumberAnimation { target: panel; property: "y"; from: panel.y; to: -10; duration: theme && theme.reducedMotion ? 0 : 200; easing.type: Easing.InCubic }
                NumberAnimation { target: panel; property: "scale"; from: 1.0; to: 0.97; duration: theme && theme.reducedMotion ? 0 : 180; easing.type: Easing.InCubic }
            }
            ScriptAction {
                script: {
                    root.visible = false
                    root.closing = false
                    root.launching = false
                    root.launchPhase = 0
                    root.query = ""
                    panel.y = -12
                    panel.scale = 0.96
                    panel.opacity = 0
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, root.theme.panelRadius - 1)
            color: root.theme.withAlpha(root.theme.color0, root.theme.panelOpacity)
        }

        Item {
            id: inputBar

            width: parent.width
            height: 54
            opacity: root.launching ? 0 : 1
            enabled: !root.launching

            Behavior on opacity { NumberAnimation { duration: root.theme.reducedMotion ? 0 : 150; easing.type: Easing.InCubic } }

            Item {
                id: prompt
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                width: 17
                height: 17

                Image {
                    id: searchIcon
                    anchors.fill: parent
                    source: Quickshell.env("HOME") + "/.config/shells/assets/icons/launcher/search.svg"
                    sourceSize.width: width
                    sourceSize.height: height
                    smooth: true
                    mipmap: true
                    visible: false
                }

                MultiEffect {
                    anchors.fill: searchIcon
                    source: searchIcon
                    colorization: 1
                    colorizationColor: root.theme.foreground
                }
            }

            SequentialAnimation {
                id: promptPulse
                NumberAnimation { target: prompt; property: "scale"; to: 1.15; duration: root.theme.reducedMotion ? 0 : 150; easing.type: Easing.OutCubic }
                SpringAnimation { target: prompt; property: "scale"; to: 1.0; duration: root.theme.reducedMotion ? 0 : 300; spring: 6.0; damping: 0.55; mass: 0.9; epsilon: 0.001 }
            }

            TextInput {
                id: searchInput

                anchors.left: prompt.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                text: root.query
                color: root.theme.foreground
                selectionColor: root.theme.withAlpha(root.theme.color2, 0.38)
                selectedTextColor: root.theme.foreground
                font.family: root.theme.fontFamily
                font.pixelSize: 14 * root.theme.fontScale
                clip: true

                onTextChanged: {
                    root.query = text
                    root.selectedIndex = 0
                    appList.positionViewAtBeginning()
                }

                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) {
                        root.closeAnimated()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Down) {
                        root.selectedIndex = Math.min(root.results.length - 1, root.selectedIndex + 1)
                        appList.currentIndex = root.selectedIndex
                        root.smoothScrollToIndex(root.selectedIndex)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                        root.selectedIndex = Math.max(0, root.selectedIndex - 1)
                        appList.currentIndex = root.selectedIndex
                        root.smoothScrollToIndex(root.selectedIndex)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.activateSelection()
                        event.accepted = true
                    }
                }
            }

            Text {
                visible: searchInput.text.length === 0
                anchors.left: searchInput.left
                anchors.verticalCenter: searchInput.verticalCenter
                text: "Search"
                color: root.theme.withAlpha(root.theme.foreground, 0.54)
                font.family: root.theme.fontFamily
                font.pixelSize: 14 * root.theme.fontScale
                renderType: Text.NativeRendering
            }
        }

        Item {
            id: launchStatus

            anchors.fill: parent
            opacity: root.launching && root.launchPhase < 3 ? 1 : 0
            y: root.launching && root.launchPhase >= 2 ? 18 : 0
            scale: root.launching ? 1 : 0.96

            Behavior on opacity { NumberAnimation { duration: root.theme.reducedMotion ? 0 : 150; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: root.theme.reducedMotion ? 0 : 300; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: root.theme.reducedMotion ? 0 : 200; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.centerIn: parent
                width: 154
                height: 6
                radius: 3
                color: root.theme.withAlpha(root.theme.color1, 0.38)
                clip: true

                Rectangle {
                    id: launchProgressFill
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.launching ? parent.width : 0
                    height: parent.height
                    radius: parent.radius
                    color: root.theme.color4

                    Behavior on width {
                        NumberAnimation {
                            duration: root.theme.reducedMotion ? 0 : 760
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Rectangle {
                    width: 54
                    height: parent.height
                    radius: parent.radius
                    x: root.launching ? parent.width + 10 : -width - 10
                    color: root.theme.withAlpha(root.theme.foreground, 0.32)
                    opacity: root.launching && root.launchPhase < 3 ? 1 : 0

                    Behavior on x {
                        NumberAnimation {
                            duration: root.theme.reducedMotion ? 0 : 620
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: root.theme.reducedMotion ? 0 : 120
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }

        Item {
            id: listViewport

            anchors.top: inputBar.bottom
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 10
            height: Math.max(0, panel.height - inputBar.height - 13)
            opacity: root.hasQuery && !root.launching ? 1 : 0
            clip: true

            Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(220 / 2) : 220; easing.type: Easing.OutCubic } }

            ListView {
                id: appList

                anchors.fill: parent
                clip: true
                model: root.results
                spacing: root.rowSpacing
                currentIndex: root.selectedIndex
                interactive: false
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: root.rowHeight * 8
                preferredHighlightBegin: 0
                preferredHighlightEnd: height - root.rowHeight
                highlightRangeMode: ListView.NoHighlightRange
                highlightMoveDuration: root.theme.reducedMotion ? 0 : 220
                highlightMoveVelocity: -1
                highlightFollowsCurrentItem: true

                highlight: Rectangle {
                    width: appList.width - 4
                    x: 2
                    height: root.rowHeight - 4
                    radius: root.theme.itemRadius
                    visible: !(root.results[root.selectedIndex] && root.results[root.selectedIndex].action)
                    color: root.theme.withAlpha(root.theme.color2, 0.22)
                    border.width: 0
                    border.color: "transparent"
                    z: 0

                    Behavior on y {
                        NumberAnimation {
                            duration: root.theme.reducedMotion ? 0 : 220
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                NumberAnimation {
                    id: scrollAnim
                    target: appList
                    property: "contentY"
                    duration: root.theme.reducedMotion ? 0 : 220
                    easing.type: Easing.OutCubic
                }

                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && root.selectedIndex !== currentIndex)
                        root.selectedIndex = currentIndex
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: function(event) {
                        appList.contentY = Math.max(0, Math.min(appList.contentHeight - appList.height, appList.contentY - event.angleDelta.y / 2))
                        event.accepted = true
                    }
                }

                add: Transition {
                    NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: theme && theme.reducedMotion ? Math.round(260 / 2) : 260; easing.type: Easing.OutCubic }
                }

                addDisplaced: Transition {
                    NumberAnimation { properties: "y"; duration: theme && theme.reducedMotion ? Math.round(320 / 2) : 320; easing.type: Easing.OutCubic }
                }

                remove: Transition {
                    NumberAnimation { properties: "opacity"; to: 0; duration: theme && theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic }
                }

                removeDisplaced: Transition {
                    NumberAnimation { properties: "y"; duration: theme && theme.reducedMotion ? Math.round(320 / 2) : 320; easing.type: Easing.OutCubic }
                }

                delegate: LauncherItem {
                    theme: root.theme
                    app: modelData
                    itemIndex: index
                    staggerDelay: Math.min(index, 8) * 32
                    selected: index === root.selectedIndex
                    menuVisible: root.hasQuery && root.visible && !root.closing && !root.launching
                    onClicked: root.launchApp(app)
                }
            }
        }
    }

    function open() {
        closeAnim.stop()
        root.closing = false
        root.visible = true
    }

    function toggle() {
        if (visible)
            closeAnimated()
        else
            open()
    }

    function closeAnimated() {
        if (!visible || closing || launching)
            return
        closing = true
        openAnim.stop()
        closeAnim.restart()
    }

    function activateSelection() {
        if (visibleCount > 0) {
            launchApp(results[selectedIndex])
            return
        }

        const command = query.trim()
        if (command.length > 0) {
            Quickshell.execDetached(["sh", "-lc", command])
            beginLaunchClose()
        }
    }

    function launchApp(app) {
        if (!app)
            return
        if (app.action === "url") {
            Quickshell.execDetached(["xdg-open", app.url])
        } else if (app.action === "math") {
            Quickshell.execDetached(["sh", "-lc", "printf '%s' " + shellQuote(app.result) + " | wl-copy"])
        } else {
            app.execute()
        }
        beginLaunchClose()
    }

    function shellQuote(text) {
        return "'" + String(text).replace(/'/g, "'\"'\"'") + "'"
    }

    function websiteAction(text) {
        const value = String(text || "").trim()
        if (value.indexOf(" ") >= 0 || value.length < 3)
            return null
        const hasScheme = /^https?:\/\//i.test(value)
        const host = hasScheme ? value.replace(/^https?:\/\//i, "").split("/")[0] : value.split("/")[0]
        if (!/^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+(:[0-9]+)?$/.test(host))
            return null
        const url = hasScheme ? value : "https://" + value
        return {
            action: "url",
            name: "Open " + value,
            genericName: "Website",
            comment: url,
            keywords: [],
            icon: Quickshell.env("HOME") + "/.config/shells/assets/icons/launcher/browser.svg",
            noDisplay: false,
            url: url
        }
    }

    function mathAction(text) {
        const expr = String(text || "").trim()
        if (!/[0-9]/.test(expr) || !/[+\-*/%]/.test(expr))
            return null
        if (!/^[0-9+\-*/%().\s]+$/.test(expr))
            return null
        try {
            const value = Function("'use strict'; return (" + expr + ")")()
            if (typeof value !== "number" || !isFinite(value))
                return null
            const result = Math.abs(value - Math.round(value)) < 0.000000001 ? String(Math.round(value)) : String(Number(value.toFixed(8)))
            return {
            action: "math",
                name: result,
            genericName: "Calculator",
                comment: expr,
            keywords: [],
                icon: Quickshell.env("HOME") + "/.config/shells/assets/icons/launcher/calculator.svg",
                noDisplay: false,
                result: result
            }
        } catch (e) {
            return null
        }
    }

    function beginLaunchClose() {
        if (!visible || launching)
            return

        openAnim.stop()
        closeAnim.stop()
        appList.currentIndex = -1
        launching = true
        closing = true
        launchPhase = 1
        panel.opacity = 1
        panel.scale = 1
        panel.y = 0
        launchDropTimer.restart()
        launchCircleTimer.restart()
        launchFadeTimer.restart()
        launchDoneTimer.restart()
    }

    function finishLaunchClose() {
        root.visible = false
        root.closing = false
        root.launching = false
        root.launchPhase = 0
        root.query = ""
        root.selectedIndex = 0
        panel.y = -12
        panel.scale = 0.96
        panel.opacity = 0
    }

    function smoothScrollToIndex(index) {
        const itemY = index * (root.rowHeight + root.rowSpacing)
        const itemBottom = itemY + root.rowHeight
        const maxY = Math.max(0, appList.contentHeight - appList.height)

        if (itemBottom > appList.contentY + appList.height) {
            scrollAnim.to = Math.min(maxY, itemBottom - appList.height)
            scrollAnim.restart()
        } else if (itemY < appList.contentY) {
            scrollAnim.to = Math.max(0, itemY)
            scrollAnim.restart()
        }
    }

    function search(text) {
        const needle = text.trim().toLowerCase()
        if (needle.length === 0)
            return []

        const actions = []
        const math = mathAction(text)
        const website = websiteAction(text)
        if (math)
            actions.push(math)
        if (website)
            actions.push(website)

        const apps = DesktopEntries.applications.values
        const scored = []

        for (let i = 0; i < apps.length; i++) {
            const app = apps[i]
            if (app.noDisplay)
                continue

            const haystack = (app.name + " " + app.genericName + " " + app.comment + " " + app.keywords.join(" ")).toLowerCase()
            const score = matchScore(needle, app.name.toLowerCase(), haystack)
            if (score > 0)
                scored.push({ app: app, score: score })
        }

        scored.sort(function(a, b) {
            if (b.score !== a.score)
                return b.score - a.score
            return a.app.name.localeCompare(b.app.name)
        })

        return actions.concat(scored.map(function(item) { return item.app }))
    }

    function matchScore(needle, name, haystack) {
        if (needle.length === 0)
            return 1
        if (name === needle)
            return 1000
        if (name.indexOf(needle) === 0)
            return 850 - name.length
        if (name.indexOf(needle) >= 0)
            return 650 - name.indexOf(needle)
        if (haystack.indexOf(needle) >= 0)
            return 420

        let score = 0
        let pos = 0
        for (let i = 0; i < needle.length; i++) {
            const found = haystack.indexOf(needle[i], pos)
            if (found < 0)
                return 0
            score += Math.max(2, 60 - (found - pos))
            pos = found + 1
        }
        return score
    }
}

import QtQuick

Item {
    id: root

    property var theme
    property var store
    property var toast
    property int deckIndex: 0
    property int stackCount: 1
    property bool deckExpanded: false
    readonly property bool frontCard: deckIndex === 0
    readonly property bool showContent: deckExpanded || frontCard
    readonly property bool interactive: deckExpanded || frontCard
    property bool hovered: interactive && (deckExpanded || hitArea.containsMouse)
    property bool exiting: false
    property bool behaviorsReady: false
    property bool pulsesReady: false
    property real dragOffset: 0
    readonly property bool leftSide: theme && (theme.toastPosition === "top-left" || theme.toastPosition === "bottom-left")
    readonly property real hiddenX: (leftSide ? -1 : 1) * (root.width + 48)
    property real cardX: hiddenX
    property real targetY: 0
    property real cardY: 0
    property real cardScale: 1
    property real remaining: toast ? toast.timeout : 5000
    property int pulseToken: toast ? toast.pulse : 0
    readonly property bool hasBody: toast && String(toast.body || "").length > 0
    readonly property int baseHeight: hasBody ? 88 : 66
    readonly property color warning: theme.color1
    readonly property color accent: toast && toast.critical ? warning : theme.color4
    readonly property color cardColor: Qt.darker(theme.color0, 1 + Math.min(deckIndex, 2) * 0.15)

    width: parent ? parent.width : 260
    height: hasBody ? 84 : 64
    clip: false

    Behavior on dragOffset { enabled: root.behaviorsReady && !root.exiting; SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.0; damping: 0.75; mass: 0.9; epsilon: 0.001 } }

    Component.onCompleted: {
        remaining = toast.timeout
        Qt.callLater(function() {
            root.behaviorsReady = true
            enterAnim.restart()
            lifeStartDelay.restart()
        })
    }

    onPulseTokenChanged: {
        remaining = toast.timeout
        ring.requestPaint()
        if (pulsesReady)
            pulseAnim.restart()
        lifeStartDelay.restart()
    }

    onDeckIndexChanged: {
        if (frontCard && !exiting && !life.running)
            lifeStartDelay.restart()
    }

    Timer {
        id: lifeStartDelay
        interval: 300
        repeat: false
        onTriggered: {
            root.pulsesReady = true
            life.restart()
        }
    }

    Timer {
        id: life
        interval: 50
        repeat: true
        onTriggered: {
            if (!root.frontCard && !root.deckExpanded)
                return
            if (!root.hovered)
                root.remaining = Math.max(0, root.remaining - interval)
            ring.requestPaint()
            if (root.remaining <= 0)
                root.dismiss("auto")
        }
    }

    ParallelAnimation {
        id: enterAnim
        SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 340;  target: root; property: "cardX"; to: 0; spring: 3.8; damping: 0.88; mass: 0.96; epsilon: 0.001 }
    }

    SequentialAnimation {
        id: pulseAnim
        SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  target: root; property: "cardScale"; to: 1.035; spring: 5.5; damping: 0.72; mass: 0.9; epsilon: 0.001 }
        SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  target: root; property: "cardScale"; to: 1.0; spring: 5.5; damping: 0.72; mass: 0.9; epsilon: 0.001 }
    }

    SequentialAnimation {
        id: autoExit
        ParallelAnimation {
            SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 340; target: root; property: "cardX"; to: root.hiddenX; spring: 3.8; damping: 0.88; mass: 0.96; epsilon: 0.001 }
        }
        ScriptAction { script: root.collapseAndRemove() }
    }

    SequentialAnimation {
        id: swipeExit
        ParallelAnimation {
            SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 340; target: root; property: "cardX"; to: root.hiddenX; spring: 3.8; damping: 0.88; mass: 0.96; epsilon: 0.001 }
        }
        ScriptAction { script: root.collapseAndRemove() }
    }

    SequentialAnimation {
        id: clickExit
        ParallelAnimation {
            SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 340; target: root; property: "cardX"; to: root.hiddenX; spring: 3.8; damping: 0.88; mass: 0.96; epsilon: 0.001 }
        }
        ScriptAction { script: root.collapseAndRemove() }
    }

    Rectangle {
        id: card
        x: root.cardX + root.dragOffset
        y: root.cardY
        width: root.width
        height: root.hasBody ? 84 : 64
        radius: root.theme.itemRadius
        color: root.theme.withAlpha(root.cardColor, Math.min(0.98, root.theme.panelOpacity + 0.02))
        scale: root.cardScale
        transformOrigin: Item.Top
        clip: true
        border.width: root.theme.outerBorder ? root.theme.borderWidth : 0
        border.color: root.toast && root.toast.critical ? root.warning : root.theme.withAlpha(root.theme.gradientBorder ? root.theme.color4 : root.theme.color1, root.theme.borderOpacity)

        Rectangle {
            id: accentBar
            visible: root.showContent
            x: 14
            width: 2
            height: 34
            radius: 1
            anchors.verticalCenter: parent.verticalCenter
            color: root.accent
        }

        Rectangle {
            id: iconBox
            visible: root.showContent
            property real bellSwing: 0
            x: accentBar.x + accentBar.width + 14
            width: 34
            height: 34
            radius: root.theme.controlRadius
            anchors.verticalCenter: parent.verticalCenter
            color: root.theme.mix(root.theme.color0, root.accent, 0.18)
            clip: true

            Text {
                anchors.centerIn: parent
                text: "󰂚"
                color: root.accent
                font.pixelSize: 16 * root.theme.fontScale
                font.bold: root.theme.fontBold || true
                rotation: iconBox.bellSwing
                transformOrigin: Item.Top
            }

            SequentialAnimation on bellSwing {
                running: root.showContent && !root.exiting && !(root.theme && root.theme.reducedMotion)
                loops: Animation.Infinite
                NumberAnimation { to: -13; duration: 120; easing.type: Easing.OutCubic }
                NumberAnimation { to: 11; duration: 180; easing.type: Easing.InOutCubic }
                NumberAnimation { to: -7; duration: 160; easing.type: Easing.InOutCubic }
                NumberAnimation { to: 4; duration: 140; easing.type: Easing.InOutCubic }
                NumberAnimation { to: 0; duration: 180; easing.type: Easing.OutCubic }
                PauseAnimation { duration: 850 }
            }
        }

        Column {
            id: textColumn
            visible: root.showContent
            x: iconBox.x + iconBox.width + 10
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(1, ringBox.x - x - 8)
            spacing: 2

            Text {
                width: parent.width
                text: root.toast ? root.toast.appName.toUpperCase() : ""
                color: root.theme.color6
                font.family: root.theme.fontFamily
                font.pixelSize: 8 * root.theme.fontScale
                font.bold: true
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            Text {
                width: parent.width
                text: root.toast ? root.toast.summary : ""
                color: root.theme.foreground
                font.family: root.theme.fontFamily
                font.pixelSize: 13 * root.theme.fontScale
                font.bold: root.theme.fontBold || true
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            Text {
                width: parent.width
                visible: root.hasBody
                text: root.toast ? root.toast.body : ""
                color: root.theme.color6
                font.family: root.theme.fontFamily
                font.pixelSize: 11 * root.theme.fontScale
                maximumLineCount: 1
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }
        }

        Item {
            id: ringBox
            visible: root.showContent
            width: 20
            height: 20
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter

            Canvas {
                id: ring
                anchors.fill: parent
                visible: !root.hovered
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.lineWidth = 2
                    ctx.lineCap = "round"
                    ctx.strokeStyle = root.theme.color1
                    ctx.beginPath()
                    ctx.arc(10, 10, 7, -Math.PI / 2, Math.PI * 1.5)
                    ctx.stroke()
                    ctx.strokeStyle = root.toast && root.toast.critical ? root.warning : root.theme.color4
                    ctx.beginPath()
                    ctx.arc(10, 10, 7, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * (root.remaining / Math.max(1, root.toast ? root.toast.timeout : 1)))
                    ctx.stroke()
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.hovered
                text: "×"
                color: root.theme.color6
                font.pixelSize: 16
                font.bold: true
        }
        }

        Row {
            id: actionRow
            z: 4
            visible: root.showContent && root.toast && root.toast.actions && root.toast.actions.length > 0
            spacing: 6
            x: textColumn.x
            y: parent.height - height - 8
            height: 22

            Repeater {
                model: root.toast && root.toast.actions ? root.toast.actions.length : 0

                Rectangle {
                    width: actionText.implicitWidth + 18
                    height: 22
                    radius: 11
                    color: root.theme.color1

                    Text {
                        id: actionText
                        anchors.centerIn: parent
                        text: root.toast.actions[index].text
                        color: root.theme.color0
                        font.pixelSize: 10
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.store.invoke(root.toast.id, index)
                            root.dismiss("click")
                        }
                    }
                }
            }
        }

        MouseArea {
            id: hitArea
            z: 1
            anchors.fill: parent
            enabled: root.interactive
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            property real pressX: 0

            onPressed: function(mouse) {
                pressX = mouse.x
            }

            onPositionChanged: function(mouse) {
                if (pressed)
                    root.dragOffset = root.leftSide ? Math.min(0, mouse.x - pressX) : Math.max(0, mouse.x - pressX)
            }

            onReleased: {
                if (Math.abs(root.dragOffset) > root.width * 0.28)
                    root.dismiss("swipe")
                else
                    root.dragOffset = 0
            }

            onClicked: root.dismiss("click")
        }

        Rectangle {
            id: countBadge
            visible: root.frontCard && !root.deckExpanded && root.stackCount > 1
            width: badgeText.implicitWidth + 12
            height: 20
            radius: 10
            color: root.theme.color4
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: -6
            anchors.rightMargin: -4
            z: 10
            scale: visible ? 1 : 0

            Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 6.0; damping: 0.6; mass: 0.9; epsilon: 0.001 } }

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: "+" + (root.stackCount - 1)
                color: root.theme.color0
                font.pixelSize: 10
                font.bold: true
            }
        }
    }

    Timer {
        id: removeDelay
        interval: 180
        repeat: false
        onTriggered: root.store.removeToast(root.toast.id)
    }

    function dismiss(kind) {
        if (exiting)
            return
        exiting = true
        lifeStartDelay.stop()
        life.stop()
        if (kind === "swipe")
            swipeExit.restart()
        else if (kind === "click")
            clickExit.restart()
        else
            autoExit.restart()
    }

    function collapseAndRemove() {
        removeDelay.restart()
    }

}

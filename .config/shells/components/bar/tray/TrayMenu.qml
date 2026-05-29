import QtQuick
import Quickshell
import Quickshell.DBusMenu

PopupWindow {
    id: root

    property var theme
    property var menuHandle
    property var menuRoot: null
    property var currentMenu: null
    property bool closing: false

    color: "transparent"
    grabFocus: true
    implicitWidth: menuBox.implicitWidth
    implicitHeight: menuBox.implicitHeight

    onVisibleChanged: {
        if (visible) {
            closing = false
            openAnim.restart()
        }
        if (!visible && menuRoot && typeof menuRoot.sendClosed === "function")
            menuRoot.sendClosed()
    }

    QsMenuOpener {
        id: opener
        menu: root.currentMenu
    }

    Timer {
        id: showTimer
        interval: 60
        repeat: false
        onTriggered: {
            root.currentMenu = root.menuRoot
            root.visible = true
        }
    }

    Timer {
        id: closeAfterTrigger
        interval: 120
        repeat: false
        onTriggered: root.closeAnimated()
    }

    Rectangle {
        id: menuBox

        implicitWidth: Math.max(180, column.implicitWidth + 14)
        implicitHeight: column.implicitHeight + 10
        radius: root.theme.itemRadius
        color: root.theme.withAlpha(root.theme.background, 0.96)
        border.width: root.theme.outerBorder ? root.theme.borderWidth : 0
        border.color: root.theme.withAlpha(root.theme.color1, root.theme.borderOpacity)
        opacity: 0
        scale: 0.94
        y: -8
        transformOrigin: Item.TopLeft

        SequentialAnimation {
            id: openAnim
            ParallelAnimation {
                NumberAnimation { target: menuBox; property: "opacity"; from: 0; to: 1; duration: theme && theme.reducedMotion ? Math.round(150 / 2) : 150; easing.type: Easing.OutCubic }
                SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  target: menuBox; property: "scale"; from: 0.92; to: 1; spring: 4.4; damping: 0.72; mass: 0.9; epsilon: 0.001 }
                SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  target: menuBox; property: "y"; from: -8; to: 0; spring: 4.4; damping: 0.76; mass: 0.9; epsilon: 0.001 }
            }
        }

        SequentialAnimation {
            id: closeAnim
            ParallelAnimation {
                NumberAnimation { target: menuBox; property: "opacity"; from: menuBox.opacity; to: 0; duration: theme && theme.reducedMotion ? Math.round(130 / 2) : 130; easing.type: Easing.InCubic }
                SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  target: menuBox; property: "scale"; from: menuBox.scale; to: 0.96; spring: 4.8; damping: 0.8; mass: 0.9; epsilon: 0.001 }
                SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  target: menuBox; property: "y"; from: menuBox.y; to: -6; spring: 4.8; damping: 0.8; mass: 0.9; epsilon: 0.001 }
            }
            ScriptAction {
                script: {
                    root.closing = false
                    root.visible = false
                }
            }
        }

        Column {
            id: column
            anchors.fill: parent
            anchors.margins: 5
            spacing: 2

            Repeater {
                model: opener.children.values

                Item {
                    id: entryRoot

                    property var entry: modelData
                    property bool appeared: root.visible && !root.closing

                    width: Math.max(170, itemRow.implicitWidth + 18)
                    height: entry.isSeparator ? 8 : 28
                    opacity: appeared ? (entry.enabled ? 1 : 0.45) : 0
                    y: appeared ? 0 : -4

                    Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic } }
                    Behavior on y { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.2; damping: 0.78; mass: 0.9; epsilon: 0.001 } }

                    Rectangle {
                        visible: entry.isSeparator
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        height: 1
                        color: root.theme.withAlpha(root.theme.foreground, 0.13)
                    }

                    Rectangle {
                        visible: !entry.isSeparator
                        anchors.fill: parent
                        radius: 10
                        color: itemArea.containsMouse && entry.enabled ? root.theme.withAlpha(root.theme.color1, 0.18) : "transparent"

                        Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(120 / 2) : 120; easing.type: Easing.OutCubic } }
                    }

                    Row {
                        id: itemRow
                        visible: !entry.isSeparator
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            width: 14
                            text: checkGlyph(entry)
                            color: root.theme.color2
                            font.family: root.theme.fontFamily
                            font.pixelSize: 12 * root.theme.fontScale
                            horizontalAlignment: Text.AlignHCenter
                            renderType: Text.NativeRendering
                        }

                        Text {
                            text: cleanText(entry.text)
                            color: itemArea.containsMouse ? root.theme.foreground : root.theme.color7
                            font.family: root.theme.fontFamily
                            font.pixelSize: 13 * root.theme.fontScale
                            elide: Text.ElideRight
                            width: Math.min(240, implicitWidth)
                            renderType: Text.NativeRendering

                            Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(120 / 2) : 120; easing.type: Easing.OutCubic } }
                        }

                        Text {
                            visible: entry.hasChildren
                            text: "›"
                            color: root.theme.withAlpha(root.theme.foreground, 0.75)
                            font.family: root.theme.fontFamily
                            font.pixelSize: 14 * root.theme.fontScale
                            renderType: Text.NativeRendering
                        }
                    }

                    MouseArea {
                        id: itemArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !entry.isSeparator && entry.enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                        onClicked: {
                            try {
                                entry.sendTriggered()
                            } catch (e) {
                                if (typeof entry.triggered === "function")
                                    entry.triggered()
                            }
                            closeAfterTrigger.restart()
                        }
                    }
                }
            }
        }
    }

    function cleanText(text) {
        return String(text || "").replace(/_/g, "")
    }

    function checkGlyph(entry) {
        if (!entry || entry.buttonType === QsMenuButtonType.None)
            return ""
        return entry.checkState === Qt.Checked ? "●" : "○"
    }

    function openAt(parentWindow, x, y, handle) {
        closeAnim.stop()
        closeAfterTrigger.stop()
        root.closing = false
        root.menuHandle = handle || null
        root.menuRoot = root.menuHandle ? (root.menuHandle.menu || root.menuHandle) : null
        root.currentMenu = null
        root.visible = false

        if (!root.menuRoot)
            return

        if (typeof root.menuRoot.updateLayout === "function")
            root.menuRoot.updateLayout()
        if (typeof root.menuRoot.sendOpened === "function")
            root.menuRoot.sendOpened()

        root.anchor.window = parentWindow
        root.anchor.rect = Qt.rect(x, y, 1, 1)
        showTimer.restart()
    }

    function closeAnimated() {
        if (!visible || closing)
            return

        closing = true
        openAnim.stop()
        closeAnim.restart()
    }
}

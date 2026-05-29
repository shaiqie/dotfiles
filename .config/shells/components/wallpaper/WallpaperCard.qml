import QtQuick

Item {
    id: root

    property var theme
    property string fileName: ""
    property string fileUrl: ""
    property int slotWidth: 320
    property bool active: false
    property int distance: 0
    property bool open: false
    readonly property int absDistance: Math.abs(distance)
    readonly property int fadeDistance: Math.min(absDistance, 6)
    readonly property real shear: -0.3249 // tan(18deg), X-axis parallelogram skew.
    readonly property int activePanelWidth: 350
    readonly property int inactivePanelWidth: 104
    readonly property real panelScale: 1
    readonly property real panelOpacity: open ? Math.max(0, 1 - fadeDistance * 0.18) : 0

    signal clicked()

    width: slotWidth
    height: 300
    z: active ? 20 : 10 - absDistance
    scale: panelScale
    opacity: panelOpacity

    Behavior on scale { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(340 / 2) : 340; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(220 / 2) : 220; easing.type: Easing.OutCubic } }

    Item {
        id: skewed
        anchors.centerIn: parent
        width: root.active ? root.activePanelWidth : root.inactivePanelWidth
        height: root.active ? 286 : 250
        transformOrigin: Item.Center
        transform: Matrix4x4 {
            matrix: Qt.matrix4x4(
                1, root.shear, 0, 0,
                0, 1,          0, 0,
                0, 0,          1, 0,
                0, 0,          0, 1
            )
        }

        Behavior on width { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(340 / 2) : 340; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(340 / 2) : 340; easing.type: Easing.OutCubic } }

        Rectangle {
            id: activeBorderPlate
            anchors.fill: panel
            anchors.margins: root.active ? -5 : 0
            radius: root.active ? 0 : panel.radius + 7
            color: root.active ? "transparent" : root.theme.withAlpha(root.theme.color2, 0.11)
            opacity: root.open && root.active ? 1 : 0
            clip: true

            Rectangle {
                visible: root.active
                anchors.centerIn: parent
                width: Math.max(parent.width, parent.height) * 1.6
                height: Math.max(parent.width, parent.height) * 1.6
                rotation: 45
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: root.theme.color2 }
                    GradientStop { position: 1.0; color: root.theme.color4 }
                }
            }
        }

        Rectangle {
            id: panel
            anchors.fill: parent
            radius: root.active ? 0 : root.theme.itemRadius
            color: root.theme.withAlpha(root.theme.background, root.active ? 0.88 : 0.74)
            border.width: root.active ? 0 : (root.theme.outerBorder ? root.theme.borderWidth : 0)
            border.color: root.active ? root.theme.color2 : root.theme.withAlpha(root.theme.foreground, root.theme.borderOpacity)
            clip: true

            Behavior on radius { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(340 / 2) : 340; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(240 / 2) : 240; easing.type: Easing.OutCubic } }
            Behavior on border.color { ColorAnimation { duration: theme && theme.reducedMotion ? Math.round(240 / 2) : 240; easing.type: Easing.OutCubic } }

            Image {
                anchors.fill: parent
                source: root.open ? root.fileUrl : ""
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: false
            }

            Rectangle {
                anchors.fill: parent
                color: root.theme.withAlpha(root.theme.background, root.active ? 0.03 : 0.16)
            }

        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

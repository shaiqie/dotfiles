import QtQuick
import QtQuick.Effects
import "../../services" as Services

Rectangle {
    id: root

    property var theme
    property bool hasPlayer: false
    property string title: ""
    property string artist: ""
    property string artUrl: ""
    property string status: "Stopped"
    property bool loading: false
    property real positionSeconds: 0
    property real durationSeconds: 0
    property real progress: durationSeconds > 0 ? Math.max(0, Math.min(1, positionSeconds / durationSeconds)) : 0
    property int motionToken: 0
    property bool hovered: hoverArea.containsMouse
    property bool dragging: progressDrag.pressed
    property real reveal: 0
    property int waveTick: 0

    signal seek(real fraction)
    signal control(var command)

    width: parent ? parent.width : 360
    height: hasPlayer ? 232 : 146
    radius: 20
    clip: true
    color: theme.withAlpha(theme.foreground, hovered ? 0.060 : 0.044)

    Behavior on height { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 360; spring: 4.4; damping: 0.82; mass: 0.9; epsilon: 0.001 } }
    Behavior on color { ColorAnimation { duration: root.theme.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic } }

    onMotionTokenChanged: restartReveal()
    onTitleChanged: titleSwap.restart()
    Component.onCompleted: restartReveal()

    function restartReveal() {
        reveal = 0
        revealIn.restart()
    }

    function formatSeconds(value) {
        const sec = Math.max(0, Math.floor(value || 0))
        const m = Math.floor(sec / 60)
        const s = sec % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    NumberAnimation on reveal {
        id: revealIn
        from: 0
        to: 1
        duration: root.theme.reducedMotion ? 0 : 420
        easing.type: Easing.OutCubic
    }

    Timer {
        interval: 160
        repeat: true
        running: root.hasPlayer && root.status === "Playing"
        onTriggered: root.waveTick++
    }

    Image {
        id: bgArt
        anchors.fill: parent
        anchors.margins: -80
        source: root.hasPlayer ? root.artUrl : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: bgArt
        visible: root.hasPlayer && root.artUrl.length > 0 && root.theme.enableBlur
        blurEnabled: root.theme.enableBlur
        blur: root.theme.enableBlur ? root.theme.blurStrength : 0
        blurMax: 64
        blurMultiplier: root.theme.blurStrength * 1.8
        saturation: 1.18
    }

    Rectangle {
        anchors.fill: parent
        color: root.theme.withAlpha(root.theme.background, root.hasPlayer ? 0.62 : 0.78)
    }

    Rectangle {
        width: parent.width * 0.64
        height: parent.height
        x: -parent.width * 0.18
        color: root.theme.withAlpha(root.theme.color4, root.hasPlayer ? 0.075 : 0.035)
        rotation: -8
        transformOrigin: Item.Center
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    Item {
        visible: !root.hasPlayer && !root.loading
        anchors.fill: parent

        Text {
            x: 18
            y: 18
            text: "MEDIA"
            color: root.theme.withAlpha(root.theme.foreground, 0.48)
            font.pixelSize: 9
            font.bold: true
        }

        Text {
            x: 18
            y: 42
            width: parent.width - 36
            text: "Nothing playing"
            color: root.theme.foreground
            font.pixelSize: 23
            font.bold: true
            elide: Text.ElideRight
        }

        Text {
            x: 18
            y: 74
            width: parent.width - 36
            text: "Player controls will appear here"
            color: root.theme.withAlpha(root.theme.foreground, 0.58)
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Rectangle {
            x: parent.width - 70
            y: 28
            width: 46
            height: 46
            radius: 16
            color: root.theme.withAlpha(root.theme.color4, 0.12)
            Text { anchors.centerIn: parent; text: "󰝚"; color: root.theme.color4; font.pixelSize: 23 }
        }
    }

    Item {
        visible: root.loading && !root.hasPlayer
        anchors.fill: parent

        Rectangle {
            x: 18
            y: 22
            width: parent.width - 36
            height: 16
            radius: 8
            color: root.theme.withAlpha(root.theme.foreground, 0.08)
            opacity: pulseOpacity
        }

        Rectangle {
            x: 18
            y: 50
            width: parent.width * 0.52
            height: 34
            radius: 14
            color: root.theme.withAlpha(root.theme.color4, 0.11)
            opacity: pulseOpacity
        }

        Rectangle {
            x: 18
            y: 104
            width: parent.width - 36
            height: 7
            radius: 4
            color: root.theme.withAlpha(root.theme.foreground, 0.10)
            opacity: pulseOpacity
        }

        property real pulseOpacity: 1
        SequentialAnimation on pulseOpacity {
            running: root.loading && !root.theme.reducedMotion
            loops: Animation.Infinite
            NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
        }
    }

    Item {
        id: player
        visible: root.hasPlayer
        anchors.fill: parent
        anchors.margins: 14
        opacity: root.reveal
        y: (1 - root.reveal) * 8

        Behavior on y { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 360; spring: 4.5; damping: 0.82; mass: 0.9; epsilon: 0.001 } }

        Rectangle {
            id: artFrame
            x: 0
            y: 0
            width: 112
            height: 132
            radius: 18
            color: root.theme.withAlpha(root.theme.foreground, 0.065)
            clip: true
            scale: root.hovered ? 1.025 : 1

            Behavior on scale { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 320; spring: 4.8; damping: 0.80; mass: 0.9; epsilon: 0.001 } }

            Image {
                anchors.fill: parent
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 38
                color: root.theme.withAlpha(root.theme.background, 0.44)
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 11
                spacing: 3
                Repeater {
                    model: 12
                    Rectangle {
                        width: 3
                        height: root.status === "Playing" ? (5 + ((index * 5 + root.waveTick * 3) % 15)) : 4
                        radius: 2
                        color: root.theme.color4
                        opacity: 0.85
                        anchors.bottom: parent.bottom
                        Behavior on height { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 260; spring: 5.0; damping: 0.76; mass: 0.8; epsilon: 0.001 } }
                    }
                }
            }
        }

        Item {
            x: 128
            y: 2
            width: parent.width - 128
            height: 86

            Text {
                text: "NOW PLAYING"
                color: root.theme.withAlpha(root.theme.foreground, 0.48)
                font.pixelSize: 9
                font.bold: true
            }

            Text {
                id: titleText
                y: 24
                width: parent.width
                text: root.title.length > 0 ? root.title : "Unknown title"
                color: root.theme.foreground
                font.pixelSize: 21
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                y: 54
                width: parent.width
                text: root.artist.length > 0 ? root.artist : "Unknown artist"
                color: root.theme.withAlpha(root.theme.foreground, 0.60)
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        SequentialAnimation {
            id: titleSwap
            NumberAnimation { target: titleText; property: "y"; to: 16; duration: root.theme.reducedMotion ? 0 : 90; easing.type: Easing.OutCubic }
            NumberAnimation { target: titleText; property: "opacity"; to: 0.25; duration: root.theme.reducedMotion ? 0 : 60 }
            PropertyAction { target: titleText; property: "y"; value: 32 }
            NumberAnimation { target: titleText; property: "opacity"; to: 1; duration: root.theme.reducedMotion ? 0 : 80 }
            SpringAnimation { target: titleText; property: "y"; to: 24; duration: root.theme.reducedMotion ? 0 : 220; spring: 5.0; damping: 0.75; mass: 0.9; epsilon: 0.001 }
        }

        Rectangle {
            id: progressTrack
            x: 0
            y: 150
            width: parent.width
            height: root.dragging ? 10 : 6
            radius: height / 2
            color: root.theme.withAlpha(root.theme.foreground, 0.10)
            clip: true

            Behavior on height { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 280; spring: 5.0; damping: 0.78; mass: 0.85; epsilon: 0.001 } }

            Rectangle {
                width: parent.width * root.progress
                height: parent.height
                radius: parent.radius
                color: root.theme.color4
                Behavior on width { SpringAnimation { duration: root.theme.reducedMotion ? 0 : 260; spring: 4.4; damping: 0.86; mass: 0.85; epsilon: 0.001 } }
            }

            MouseArea {
                id: progressDrag
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: function(mouse) { root.seek(Math.max(0, Math.min(1, mouse.x / progressTrack.width))) }
                onPositionChanged: function(mouse) { if (pressed) root.seek(Math.max(0, Math.min(1, mouse.x / progressTrack.width))) }
            }
        }

        Text {
            x: 0
            y: 164
            text: root.formatSeconds(root.positionSeconds)
            color: root.theme.withAlpha(root.theme.foreground, 0.52)
            font.pixelSize: 10
            font.bold: true
        }

        Text {
            anchors.right: parent.right
            y: 164
            text: root.formatSeconds(root.durationSeconds)
            color: root.theme.withAlpha(root.theme.foreground, 0.52)
            font.pixelSize: 10
            font.bold: true
        }

        Row {
            x: 0
            y: 184
            width: parent.width
            height: 36
            spacing: 10

            TransportButton { theme: root.theme; icon: ""; onActivated: root.control([Services.Config.playerctlBin, "previous"]) }
            PlayButton { theme: root.theme; playing: root.status === "Playing"; onActivated: root.control([Services.Config.playerctlBin, "play-pause"]) }
            TransportButton { theme: root.theme; icon: ""; onActivated: root.control([Services.Config.playerctlBin, "next"]) }
            Item { width: parent.width - 174; height: 1 }
            Rectangle {
                width: 62
                height: 28
                radius: 12
                anchors.verticalCenter: parent.verticalCenter
                color: root.theme.withAlpha(root.status === "Playing" ? root.theme.color4 : root.theme.foreground, root.status === "Playing" ? 0.13 : 0.055)
                Text {
                    anchors.centerIn: parent
                    text: root.status === "Playing" ? "LIVE" : "PAUSED"
                    color: root.status === "Playing" ? root.theme.color4 : root.theme.withAlpha(root.theme.foreground, 0.62)
                    font.pixelSize: 9
                    font.bold: true
                }
            }
        }
    }

    component TransportButton: Item {
        id: button
        signal activated()
        property var theme
        property string icon: ""
        property bool hovered: area.containsMouse
        width: 42
        height: 34
        scale: area.pressed ? 0.94 : (hovered ? 1.06 : 1)
        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 260; spring: 5.2; damping: 0.76; mass: 0.85; epsilon: 0.001 } }

        Rectangle {
            anchors.fill: parent
            radius: 13
            color: button.theme.withAlpha(button.theme.foreground, button.hovered ? 0.08 : 0.035)
            Behavior on color { ColorAnimation { duration: button.theme.reducedMotion ? 0 : 150; easing.type: Easing.OutCubic } }
        }

        Text {
            anchors.centerIn: parent
            text: button.icon
            color: button.hovered ? button.theme.color4 : button.theme.foreground
            font.pixelSize: 17
            Behavior on color { ColorAnimation { duration: button.theme.reducedMotion ? 0 : 140; easing.type: Easing.OutCubic } }
        }

        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: button.activated() }
    }

    component PlayButton: Item {
        id: button
        signal activated()
        property var theme
        property bool playing: false
        property bool hovered: area.containsMouse
        width: 52
        height: 34
        scale: area.pressed ? 0.93 : (hovered ? 1.055 : 1)

        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 270; spring: 5.4; damping: 0.68; mass: 0.85; epsilon: 0.001 } }

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: button.theme.withAlpha(button.theme.color4, button.hovered ? 0.26 : 0.18)
            Behavior on color { ColorAnimation { duration: button.theme.reducedMotion ? 0 : 150; easing.type: Easing.OutCubic } }
        }

        Text {
            anchors.centerIn: parent
            text: button.playing ? "" : ""
            color: button.theme.foreground
            font.pixelSize: 18
            x: button.playing ? 0 : 1
        }

        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: button.activated() }
    }
}

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../widgets"

IconButton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null
    readonly property bool muted: audio ? audio.muted : true
    readonly property int volume: audio ? Math.max(0, Math.round(audio.volume * 100)) : 0
    property var panelController

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    iconSource: Quickshell.env("HOME") + "/.config/shells/assets/icons/panel/audio/" + (muted ? "audio_muted.svg" : "audio.svg")
    baseColor: root.theme.color3
    iconSize: 18
    tooltipText: muted ? ("Volume muted • " + volume + "%") : ("Volume " + volume + "%")
    onClicked: if (panelController) panelController.toggleFromItem("audio", root)

    onWheelUp: {
        if (audio)
            audio.volume = Math.min(1.5, audio.volume + 0.03)
    }

    onWheelDown: {
        if (audio)
            audio.volume = Math.max(0, audio.volume - 0.03)
    }
}

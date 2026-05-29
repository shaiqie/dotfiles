pragma Singleton

import QtQuick
import Quickshell

QtObject {
    readonly property string wallpaperDir: Quickshell.env("HOME") + "/.config/hypr/wallpapers"
    readonly property string shellCliBin: Quickshell.env("HOME") + "/.local/bin/shell"
    readonly property string wallpaperScript: shellCliBin
    readonly property string cliphistBin: "cliphist"
    readonly property string wlCopyBin: "wl-copy"
    readonly property string ydotoolBin: "ydotool"
    readonly property string wtypeBin: "wtype"
    readonly property string hyprctlBin: "hyprctl"
    readonly property string nmcliBin: "nmcli"
    readonly property string bluetoothctlBin: "bluetoothctl"
    readonly property string pactlBin: "pactl"
    readonly property string playerctlBin: "playerctl"
    readonly property string brightnessctlBin: "brightnessctl"
    readonly property string walBin: "wal"
    readonly property string powerProfilesCtlBin: "powerprofilesctl"
    readonly property string gammastepBin: "gammastep"
    readonly property string curlBin: "curl"
    readonly property string notifySendBin: "notify-send"
    readonly property string gpuScreenRecorderBin: "gpu-screen-recorder"
    readonly property string xdgOpenBin: "xdg-open"
    readonly property string notificationSoundPath: Quickshell.env("HOME") + "/.config/shells/assets/sounds/notification_sound.mp3"
    readonly property string wallpaperActiveSoundPath: Quickshell.env("HOME") + "/.config/shells/assets/sounds/active.mp3"
    readonly property string wallpaperAppliedSoundPath: Quickshell.env("HOME") + "/.config/shells/assets/sounds/applied.mp3"
    readonly property string clickedSoundPath: Quickshell.env("HOME") + "/.config/shells/assets/sounds/clicked.mp3"
    readonly property string osdAppearSoundPath: Quickshell.env("HOME") + "/.config/shells/assets/sounds/appear.mp3"
    readonly property string checkPasswordScript: Quickshell.env("HOME") + "/.config/shells/scripts/checkpass.sh"
    readonly property var powerMenuCommand: ["quickshell", "ipc", "--path", Quickshell.env("HOME") + "/.config/shells", "call", "powerMenu", "toggle"]
    readonly property var lockScreenCommand: ["quickshell", "ipc", "--path", Quickshell.env("HOME") + "/.config/shells", "call", "lockScreen", "lock"]
    readonly property var recorderCommand: ["quickshell", "ipc", "--path", Quickshell.env("HOME") + "/.config/shells", "call", "recorder", "toggle"]
}

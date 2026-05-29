import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string foreground: ""
    property string background: ""
    property string color0: ""
    property string color1: ""
    property string color2: ""
    property string color3: ""
    property string color4: ""
    property string color5: ""
    property string color6: ""
    property string color7: ""
    property string color8: ""
    property string color9: ""
    property string color10: ""
    property string color11: ""
    property string color12: ""
    property string color13: ""
    property string color14: ""
    property string color15: ""
    property bool reducedMotion: false
    property bool outerBorder: false
    property real borderWidth: 1.0
    property real borderOpacity: 0.18
    property bool gradientBorder: false
    property real panelRadius: 18
    property real itemRadius: 9
    property real pillRadius: 50
    property real microRadius: 6
    property real controlRadius: 10
    property string fontFamily: "Adwaita Sans"
    property bool fontBold: false
    property real fontScale: 1.0
    property bool enableBlur: true
    property real blurStrength: 0.8
    property bool enableShadows: true
    property real shadowOpacity: 0.22
    property bool enableGlow: true
    property bool frostedGlass: false
    property real panelOpacity: 1.0
    property real panelPadding: 18
    property real itemSpacing: 10
    property real islandGap: 10
    property real islandPadding: 10
    property bool islandHoverLift: true
    property bool islandHoverGlow: true
    property real islandHoverScale: 1.025
    property string toastPosition: "top-right"
    property real toastDuration: 5000
    property int maxToasts: 3
    property bool stackToasts: true
    property bool groupSameApp: true
    property bool showInDnd: false
    property real animationSpeed: 1.0
    property real springStrength: 4.8
    property real springDamping: 0.82

    property var _walFile: FileView {
        path: Quickshell.env("HOME") + "/.cache/wal/colors.css"
        preload: true
        watchChanges: true
        blockLoading: true
        printErrors: false

        onLoaded: root.reloadColors()
        onFileChanged: {
            reload()
            root._reloadTimer.restart()
        }
    }

    property var _reloadTimer: Timer {
        interval: 40
        repeat: false
        onTriggered: root.reloadColors()
    }

    property var _configFile: FileView {
        path: Quickshell.env("HOME") + "/.config/shells/config.json"
        preload: true
        watchChanges: true
        blockLoading: true
        printErrors: false

        onLoaded: root.reloadConfig()
        onFileChanged: {
            reload()
            root.reloadConfig()
        }
    }

    Component.onCompleted: {
        reloadColors()
        reloadConfig()
    }

    function reloadConfig() {
        try {
            const config = JSON.parse(_configFile.text())
            loadConfig(config)
        } catch (e) {
            loadConfig({})
        }
    }

    function pick(value, fallback) {
        return value === undefined || value === null ? fallback : value
    }

    function loadConfig(config) {
        reducedMotion = config && config.reducedMotion === true

        const s = config && config.shell ? config.shell : ({})
        const b = s.borders || ({})
        outerBorder = pick(b.enabled, false)
        borderWidth = pick(b.width, 1.0)
        borderOpacity = pick(b.opacity, 0.18)
        gradientBorder = pick(b.gradient, false)

        const c = s.corners || ({})
        panelRadius = pick(c.panelRadius, 18)
        itemRadius = pick(c.itemRadius, 9)
        pillRadius = pick(c.pillRadius, 50)

        const t = s.typography || ({})
        fontFamily = pick(t.fontFamily, "Adwaita Sans")
        fontBold = pick(t.fontBold, false)
        fontScale = pick(t.fontScale, 1.0)

        const e = s.effects || ({})
        enableBlur = pick(e.blur, true)
        blurStrength = pick(e.blurStrength, 0.8)
        enableShadows = pick(e.shadows, true)
        shadowOpacity = pick(e.shadowOpacity, 0.22)
        enableGlow = pick(e.glow, true)
        frostedGlass = pick(e.frostedGlass, false)

        const p = s.panels || ({})
        panelOpacity = pick(p.opacity, 1.0)
        panelPadding = pick(p.padding, 18)
        itemSpacing = pick(p.itemSpacing, 10)
        islandGap = pick(p.islandGap, 10)

        const i = s.islands || ({})
        islandPadding = pick(i.padding, 10)
        islandHoverLift = pick(i.hoverLift, true)
        islandHoverGlow = pick(i.hoverGlow, false)
        islandHoverScale = pick(i.hoverScale, 1.025)

        const n = s.notifications || ({})
        toastPosition = pick(n.toastPosition, "top-right")
        toastDuration = pick(n.toastDuration, 5000)
        maxToasts = pick(n.maxToasts, 3)
        stackToasts = pick(n.stackToasts, true)
        groupSameApp = pick(n.groupSameApp, true)
        showInDnd = pick(n.showInDnd, false)

        const a = s.animations || ({})
        animationSpeed = pick(a.speed, 1.0)
        springStrength = pick(a.springStrength, 4.8)
        springDamping = pick(a.springDamping, 0.82)
    }

    function motionDuration(duration) {
        const scaled = duration / Math.max(0.1, animationSpeed)
        return reducedMotion ? Math.round(scaled / 2) : Math.round(scaled)
    }

    function springDuration() {
        return reducedMotion ? 0 : 250
    }

    function surface(level) {
        const alpha = Math.max(0, Math.min(1, panelOpacity - level * 0.08))
        return withAlpha(level > 0 ? mix(color0, color1, 0.08 * level) : color0, alpha)
    }

    function veil(alpha) {
        return withAlpha(background, alpha)
    }

    function accent(alpha) {
        return withAlpha(color4, alpha)
    }

    function reloadColors() {
        foreground = readColor("foreground", foreground)
        background = readColor("background", background)
        color0 = readColor("color0", color0)
        color1 = readColor("color1", color1)
        color2 = readColor("color2", color2)
        color3 = readColor("color3", color3)
        color4 = readColor("color4", color4)
        color5 = readColor("color5", color5)
        color6 = readColor("color6", color6)
        color7 = readColor("color7", color7)
        color8 = readColor("color8", color8)
        color9 = readColor("color9", color9)
        color10 = readColor("color10", color10)
        color11 = readColor("color11", color11)
        color12 = readColor("color12", color12)
        color13 = readColor("color13", color13)
        color14 = readColor("color14", color14)
        color15 = readColor("color15", color15)
    }

    function readColor(name, fallback) {
        const text = _walFile.text()
        const re = new RegExp("--" + name + "\\s*:\\s*([^;]+);")
        const match = re.exec(text)
        return match ? match[1].trim() : fallback
    }

    function withAlpha(hex, alpha) {
        const raw = String(hex).trim()
        if (!raw.startsWith("#") || raw.length < 7)
            return Qt.rgba(0, 0, 0, 0)

        const r = parseInt(raw.slice(1, 3), 16) / 255
        const g = parseInt(raw.slice(3, 5), 16) / 255
        const b = parseInt(raw.slice(5, 7), 16) / 255
        return Qt.rgba(r, g, b, alpha)
    }

    function mix(a, b, amount) {
        function c(hex, from, to) {
            return parseInt(String(hex).slice(from, to), 16)
        }

        const aa = String(a).trim()
        const bb = String(b).trim()
        if (!aa.startsWith("#") || !bb.startsWith("#"))
            return withAlpha(a, 1)

        const r = Math.round(c(aa, 1, 3) * (1 - amount) + c(bb, 1, 3) * amount)
        const g = Math.round(c(aa, 3, 5) * (1 - amount) + c(bb, 3, 5) * amount)
        const bl = Math.round(c(aa, 5, 7) * (1 - amount) + c(bb, 5, 7) * amount)
        return Qt.rgba(r / 255, g / 255, bl / 255, 1)
    }
}

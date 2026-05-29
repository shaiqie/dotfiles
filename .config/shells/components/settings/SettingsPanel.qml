import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../bar/widgets"
import "../services" as Services

QtObject {
    id: root

    property var theme
    property var stateService
    property bool panelOpen: false
    property bool panelShown: false
    property int panelWidth: 680
    property int panelHeight: 560
    property int panelAnimDuration: 520
    property real panelOpacity: 0
    property real panelScale: 1
    property int activeIndex: 0
    property string searchText: ""
    property var pendingSections: ({})
    property var pendingDecorationOps: []
    property var pendingAnimationOps: []
    property var pendingRuleOps: []
    property string decorationsPath: Quickshell.env("HOME") + "/.config/hypr/configs/modules/visuals/decorations.lua"
    property string rulesPath: Quickshell.env("HOME") + "/.config/hypr/configs/modules/compositor/window_rules.lua"
    property string bindsPath: Quickshell.env("HOME") + "/.config/hypr/configs/modules/core/binds.lua"
    property string walColorsPath: Quickshell.env("HOME") + "/.cache/wal/colors.css"
    property string walWallpaperPath: Quickshell.env("HOME") + "/.cache/wal/wal"
    property string themePresetDir: Quickshell.env("HOME") + "/.config/shells/themes"
    property string variablesPath: Quickshell.env("HOME") + "/.config/hypr/configs/settings/variables.lua"
    property string envPath: Quickshell.env("HOME") + "/.config/hypr/configs/settings/environment.lua"
    property int decoRounding: 10
    property int decoBorderSize: 0
    property string decoActiveBorderA: "$color1"
    property string decoActiveBorderB: "$color2"
    property int decoBorderAngle: 45
    property int decoGapsIn: 10
    property int decoGapsOut: 20
    property real decoActiveOpacity: 1.0
    property real decoInactiveOpacity: 0.92
    property bool decoGlobalTransparency: false
    property bool decoDimInactive: false
    property bool decoShadowEnabled: false
    property int decoShadowRange: 10
    property int decoShadowRenderPower: 4
    property string decoShadowColor: "$background"
    property bool decoBlurEnabled: false
    property int decoBlurSize: 15
    property int decoBlurPasses: 2
    property real decoBlurContrast: 1.5
    property real decoBlurNoise: 0.08
    property bool decoBlurXray: false
    property bool decoBlurIgnoreOpacity: true
    property string animationsPath: Quickshell.env("HOME") + "/.config/hypr/configs/modules/visuals/animations.lua"
    property bool animEnabled: true
    property real animGlobalSpeed: 1.0
    property string animPreset: "Smooth"
    property bool animWindowsEnabled: true
    property real animWindowsSpeed: 3
    property string animWindowsStyle: "popin 60%"
    property bool animWorkspacesEnabled: true
    property real animWorkspacesSpeed: 7
    property string animWorkspacesStyle: "slide"
    property bool animLayersEnabled: true
    property real animLayersSpeed: 3
    property string animLayersStyle: "slide"
    property bool animBorderEnabled: true
    property real animBorderSpeed: 10
    property string animBorderStyle: "default"
    property bool animFadeEnabled: true
    property real animFadeSpeed: 3
    property string animFadeStyle: "md3_decel"
    property var keybinds: []
    property var keybindGroups: []
    property var keybindCategoryInfos: []
    property int keybindEditLine: -1
    property string keybindEditType: "bind"
    property string keybindEditMods: ""
    property string keybindEditKey: ""
    property string keybindEditDispatcher: ""
    property string keybindEditCommand: ""
    property bool keybindEditCommandIsExpression: false
    property string keybindEditFlags: ""
    property string keybindEditRaw: ""
    property bool keybindEditHadTrailingComma: false
    property string keybindError: ""
    property bool keybindRecording: false
    property bool keybindAdding: false
    property string keybindAddMods: "$mainMod"
    property string keybindAddKey: ""
    property string keybindAddDispatcher: "exec"
    property string keybindAddCommand: ""
    property string keybindAddCategory: "Shells"
    property var themeWallpapers: []
    property var themePresets: []
    property string activeWallpaperPath: ""
    property string themePresetName: ""
    property string themeStatus: ""
    property bool themeBusy: false
    property var variableItems: []
    property var pendingVariableOps: []
    property string variableAddName: ""
    property string variableAddValue: ""
    property string variableStatus: ""
    property var envItems: []
    property var pendingEnvOps: []
    property string envAddKey: ""
    property string envAddValue: ""
    property string envStatus: ""
    property var sidebarItems: [
        { icon: "󰔎", label: "Decorations", id: "decorations", subtitle: "Hyprland visual surface" },
        { icon: "󰐴", label: "Animations", id: "animations", subtitle: "Motion curves and timing" },
        { icon: "󰌌", label: "Keybinds", id: "keybinds", subtitle: "Keyboard shortcuts" },
        { icon: "󰏘", label: "Themes", id: "themes", subtitle: "Pywal and wallpapers" },
        { icon: "󰮊", label: "Shell", id: "shell", subtitle: "Global Shells UI settings" },
        { icon: "󰏚", label: "Variables", id: "variables", subtitle: "Hyprland variables" },
        { icon: "󰙪", label: "Environments", id: "environments", subtitle: "Session env vars" }
    ]

    property var ipc: IpcHandler {
        target: "settings"
        function toggle() { root.toggle() }
        function open() { root.open() }
        function close() { root.close() }
    }

    property var saveDebounce: Timer {
        interval: 500
        repeat: false
        onTriggered: root.applyAll()
    }

    property var decorationsDebounce: Timer {
        interval: 500
        repeat: false
        onTriggered: root.writeDecorations()
    }

    property var decorationsFile: FileView {
        path: root.decorationsPath
        preload: true
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.loadDecorations(text())
        onFileChanged: {
            reload()
            root.loadDecorations(text())
        }
    }

    property var rulesFile: FileView {
        path: root.rulesPath
        preload: true
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.loadRules(text())
        onFileChanged: {
            reload()
            root.loadRules(text())
        }
    }

    property var animationsDebounce: Timer {
        interval: 500
        repeat: false
        onTriggered: root.writeAnimations()
    }

    property var variablesDebounce: Timer {
        interval: 800
        repeat: false
        onTriggered: root.writeVariables()
    }

    property var envDebounce: Timer {
        interval: 800
        repeat: false
        onTriggered: root.writeEnvironments()
    }

    property var animationsFile: FileView {
        path: root.animationsPath
        preload: true
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.loadAnimations(text())
        onFileChanged: {
            reload()
            root.loadAnimations(text())
        }
    }

    property var keybindsFile: FileView {
        path: root.bindsPath
        preload: true
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.loadKeybinds(text())
        onFileChanged: {
            reload()
            root.loadKeybinds(text())
        }
    }

    property var variablesFile: FileView {
        path: root.variablesPath
        preload: true
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.loadVariables(text())
        onFileChanged: {
            reload()
            root.loadVariables(text())
        }
    }

    property var envFile: FileView {
        path: root.envPath
        preload: true
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.loadEnvironments(text())
        onLoadFailed: root.loadEnvironments("")
        onFileChanged: {
            reload()
            root.loadEnvironments(text())
        }
    }

    property var activeWallpaperFile: FileView {
        path: root.walWallpaperPath
        preload: true
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.activeWallpaperPath = text().trim()
        onFileChanged: {
            reload()
            root.activeWallpaperPath = text().trim()
        }
    }

    property var decorationsWriter: Process {
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { id: decorationsWriteErr; waitForEnd: true }
    }

    property var rulesWriter: Process {
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
    }

    property var animationsWriter: Process {
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
    }

    property var keybindWriter: Process {
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { id: keybindWriteErr; waitForEnd: true }
        onExited: function(code) {
            if (code === 0) {
                root.keybindEditLine = -1
                root.keybindAdding = false
                root.keybindRecording = false
                root.keybindError = ""
                root.keybindsFile.reload()
            } else {
                root.keybindError = "Save failed. File changed, sed target missed, or hyprctl reload failed."
            }
        }
    }

    property var wallpaperProbe: Process {
        stdout: StdioCollector { id: wallpaperProbeOut; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            if (code === 0)
                root.themeWallpapers = root.parsePathList(wallpaperProbeOut.text)
        }
    }

    property var presetProbe: Process {
        stdout: StdioCollector { id: presetProbeOut; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            if (code === 0)
                root.themePresets = root.parsePresetList(presetProbeOut.text)
        }
    }

    property var themeRunner: Process {
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { id: themeRunnerErr; waitForEnd: true }
        onExited: function(code) {
            root.themeBusy = false
            root.themeStatus = code === 0 ? "Done" : "Theme command failed"
            root.refreshThemeAssets()
        }
    }

    property var variablesWriter: Process {
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            root.variableStatus = code === 0 ? "Variables saved" : "Variable save failed"
            if (code === 0)
                root.variablesFile.reload()
        }
    }

    property var envWriter: Process {
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            root.envStatus = code === 0 ? "Environment saved" : "Environment save failed"
            if (code === 0)
                root.envFile.reload()
        }
    }

    property var envEnsure: Process {
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            if (code === 0)
                root.envFile.reload()
        }
    }

    property var logoutRunner: Process {
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
    }

    property var panelHideTimer: Timer {
        interval: root.panelAnimDuration + 80
        repeat: false
        onTriggered: {
            if (!root.panelOpen) {
                root.panelOpacity = 0
                root.panelShown = false
                root.panelScale = 1
            }
        }
    }

    property var panelWindow: PanelWindow {
        id: panelWindow

        anchors {
            left: true
            top: true
            right: true
            bottom: true
        }
        visible: root.panelShown
        aboveWindows: true
        focusable: true
        exclusiveZone: -1
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        surfaceFormat.opaque: false
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.namespace: "shells-settings-panel"

        Shortcut {
            sequence: "Escape"
            enabled: panelWindow.visible
            onActivated: root.close()
        }

        Shortcut {
            sequence: "Ctrl+S"
            enabled: panelWindow.visible
            onActivated: root.applyAll()
        }

        Item {
            id: focusCatcher
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.close()
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onPressed: root.close()
        }

        Item {
            id: panelShell
            readonly property real targetHeight: Math.min(root.panelHeight, parent.height - 96)
            width: root.panelWidth
            height: targetHeight
            x: Math.round((parent.width - root.panelWidth) / 2)
            y: Math.round((parent.height - targetHeight) / 2)
            opacity: root.panelOpacity
            scale: root.panelScale
            transformOrigin: Item.Center
            Behavior on opacity { NumberAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : root.panelAnimDuration; easing.type: Easing.OutCubic } }
            Behavior on scale { SpringAnimation { duration: root.theme && root.theme.reducedMotion ? 0 : root.panelAnimDuration; spring: 4.4; damping: 0.78; mass: 1.0; epsilon: 0.001 } }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            }

            Rectangle {
                anchors.fill: parent
                radius: root.theme.panelRadius
                color: root.theme.withAlpha(root.theme.color0, root.theme.panelOpacity)
                border.width: root.theme.outerBorder ? root.theme.borderWidth : 0
                border.color: root.theme.withAlpha(root.theme.color1, root.theme.outerBorder ? root.theme.borderOpacity : 0.4)
                clip: true
                Row {
                    anchors.fill: parent

                    Sidebar {
                        id: sidebar
                        width: 200
                        height: parent.height
                        theme: root.theme
                        items: root.sidebarItems
                        activeIndex: root.activeIndex
                        pendingSections: root.pendingSections
                        onSelected: function(index) { root.setActive(index) }
                    }

                    Rectangle {
                        width: 1
                        height: parent.height
                        color: root.theme.withAlpha(root.theme.color1, 0.2)
                    }

                    ContentPane {
                        width: Math.max(0, parent.width - 201)
                        height: parent.height
                        theme: root.theme
                        stateService: root.stateService
                        activeItem: root.sidebarItems[root.activeIndex]
                        searchText: root.searchText
                        onDirty: function(sectionId) { root.markDirty(sectionId) }

                    }
                }
            }
        }
    }

    Component.onCompleted: {
        refreshThemeAssets()
        envEnsure.exec(["bash", "-c", "mkdir -p " + shellQuote(Quickshell.env("HOME") + "/.config/hypr") + " && touch " + shellQuote(envPath)])
        if (stateService) {
            const last = stateService.value("settingsActiveSection", "shell")
            for (let i = 0; i < sidebarItems.length; i++) {
                if (sidebarItems[i].id === last) {
                    activeIndex = i
                    return
                }
            }
        }
        activeIndex = 4
    }

    function toggle() {
        if (panelOpen)
            close()
        else
            open()
    }

    function open() {
        panelHideTimer.stop()
        panelOpen = true
        if (!panelShown) {
            panelOpacity = 0
            panelScale = 0.88
            panelShown = true
        }
        Qt.callLater(function() {
            panelOpacity = 1
            panelScale = 1
            focusCatcher.forceActiveFocus()
        })
    }

    function close() {
        panelHideTimer.stop()
        panelOpen = false
        panelOpacity = 0
        panelScale = 0.88
        panelHideTimer.restart()
    }

    function setActive(index) {
        activeIndex = Math.max(0, Math.min(sidebarItems.length - 1, index))
        if (stateService)
            stateService.setValue("settingsActiveSection", sidebarItems[activeIndex].id)
    }

    function markDirty(sectionId) {
        const next = ({})
        for (const key in pendingSections)
            next[key] = pendingSections[key]
        next[sectionId] = true
        pendingSections = next
        if (sectionId === "decorations")
            decorationsDebounce.restart()
        else if (sectionId === "animations")
            animationsDebounce.restart()
        else if (sectionId === "variables")
            variablesDebounce.restart()
        else if (sectionId === "environments")
            envDebounce.restart()
        else
            saveDebounce.restart()
    }

    function queueDecoration(scope, key, value) {
        const id = scope + ":" + key
        const next = []
        for (let i = 0; i < pendingDecorationOps.length; i++) {
            if (pendingDecorationOps[i].id !== id)
                next.push(pendingDecorationOps[i])
        }
        next.push({ id: id, scope: scope, key: key, value: String(value) })
        pendingDecorationOps = next
        markDirty("decorations")
    }

    function queueAnimation(kind, name, value) {
        const id = kind + ":" + name
        const next = []
        for (let i = 0; i < pendingAnimationOps.length; i++) {
            if (pendingAnimationOps[i].id !== id)
                next.push(pendingAnimationOps[i])
        }
        next.push({ id: id, kind: kind, name: name, value: String(value) })
        pendingAnimationOps = next
        markDirty("animations")
    }

    function queueRuleTransparency(enabled) {
        pendingRuleOps = [{ id: "rules:globalTransparency", enabled: enabled }]
        markDirty("decorations")
    }

    function applyAll() {
        if (stateService)
            stateService.saveShellConfig(theme)
        if (pendingSections.decorations)
            writeDecorations()
        if (pendingSections.animations)
            writeAnimations()
        if (pendingSections.variables)
            writeVariables()
        if (pendingSections.environments)
            writeEnvironments()
        pendingSections = ({})
    }

    function numberMatch(text, key, fallback) {
        const re = new RegExp(key + "\\s*=\\s*([-0-9.]+)")
        const match = re.exec(text)
        return match ? Number(match[1]) : fallback
    }

    function boolMatch(text, key, fallback) {
        const re = new RegExp("#?\\s*" + key + "\\s*=\\s*(true|false)")
        const match = re.exec(text)
        return match ? match[1] === "true" : fallback
    }

    function luaBlock(text, scope) {
        const startRe = new RegExp(scope + "\\s*=\\s*\\{")
        const start = String(text || "").search(startRe)
        if (start < 0)
            return ""
        const end = String(text || "").indexOf("\n    },", start)
        return end >= 0 ? String(text || "").slice(start, end) : String(text || "").slice(start)
    }

    function loadDecorations(text) {
        decoGapsIn = numberMatch(text, "gaps_in", decoGapsIn)
        decoGapsOut = numberMatch(text, "gaps_out", decoGapsOut)
        decoBorderSize = numberMatch(text, "border_size", decoBorderSize)
        decoRounding = numberMatch(text, "rounding", decoRounding)
        decoDimInactive = boolMatch(text, "dim_inactive", decoDimInactive)
        decoActiveOpacity = numberMatch(text, "active_opacity", decoActiveOpacity)
        decoInactiveOpacity = numberMatch(text, "inactive_opacity", decoInactiveOpacity)
        const shadowBlock = luaBlock(text, "shadow")
        const blurBlock = luaBlock(text, "blur")
        decoShadowEnabled = boolMatch(shadowBlock, "enabled", decoShadowEnabled)
        decoShadowRange = numberMatch(shadowBlock, "range", decoShadowRange)
        decoShadowRenderPower = numberMatch(shadowBlock, "render_power", decoShadowRenderPower)
        decoBlurEnabled = boolMatch(blurBlock, "enabled", decoBlurEnabled)
        decoBlurSize = numberMatch(blurBlock, "size", decoBlurSize)
        decoBlurPasses = numberMatch(blurBlock, "passes", decoBlurPasses)
        decoBlurContrast = numberMatch(blurBlock, "contrast", decoBlurContrast)
        decoBlurNoise = numberMatch(blurBlock, "noise", decoBlurNoise)
        decoBlurXray = boolMatch(blurBlock, "xray", decoBlurXray)
        decoBlurIgnoreOpacity = boolMatch(blurBlock, "ignore_opacity", decoBlurIgnoreOpacity)

        const active = /active_border\s*=\s*\{\s*colors\s*=\s*\{\s*([^,\s]+)\s*,\s*([^}\s]+)\s*\}\s*,\s*angle\s*=\s*([0-9]+)/.exec(text)
        if (active) {
            decoActiveBorderA = active[1]
            decoActiveBorderB = active[2]
            decoBorderAngle = Number(active[3])
        }
        const shadow = /color\s*=\s*([^,\s]+)/.exec(shadowBlock)
        if (shadow)
            decoShadowColor = shadow[1]
    }

    function loadRules(text) {
        const start = text.indexOf("name = \"global-blur-transparency\"")
        if (start < 0) {
            decoGlobalTransparency = false
            return
        }
        const end = text.indexOf("})", start)
        const block = end >= 0 ? text.slice(start, end) : text.slice(start)
        decoGlobalTransparency = /^[ \t]*opacity[ \t]*=[ \t]*"0\.85[ \t]+0\.75",?[ \t]*$/m.test(block)
    }

    function shellQuote(text) {
        return "'" + String(text).replace(/'/g, "'\"'\"'") + "'"
    }

    function shellDouble(text) {
        return "\"" + String(text).replace(/\\/g, "\\\\").replace(/"/g, "\\\"").replace(/\$/g, "\\$").replace(/`/g, "\\`") + "\""
    }

    function parsePathList(text) {
        const result = []
        const lines = String(text || "").split("\n")
        for (let i = 0; i < lines.length; i++) {
            const path = lines[i].trim()
            if (path.length > 0)
                result.push({ path: path, name: path.split("/").pop() })
        }
        return result
    }

    function parsePresetList(text) {
        const paths = parsePathList(text)
        const result = []
        for (let i = 0; i < paths.length; i++) {
            const name = paths[i].name.replace(/\.css$/, "")
            result.push({ path: paths[i].path, name: name })
        }
        return result
    }

    function themeColorItems() {
        return [
            { name: "foreground", value: theme.foreground },
            { name: "background", value: theme.background },
            { name: "color0", value: theme.color0 },
            { name: "color1", value: theme.color1 },
            { name: "color2", value: theme.color2 },
            { name: "color3", value: theme.color3 },
            { name: "color4", value: theme.color4 },
            { name: "color5", value: theme.color5 },
            { name: "color6", value: theme.color6 },
            { name: "color7", value: theme.color7 },
            { name: "color8", value: theme.color8 },
            { name: "color9", value: theme.color9 },
            { name: "color10", value: theme.color10 },
            { name: "color11", value: theme.color11 },
            { name: "color12", value: theme.color12 },
            { name: "color13", value: theme.color13 },
            { name: "color14", value: theme.color14 },
            { name: "color15", value: theme.color15 }
        ]
    }

    function refreshThemeAssets() {
        wallpaperProbe.exec(["bash", "-c", "find " + shellQuote(Services.Config.wallpaperDir) + " -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \\) | sort"])
        presetProbe.exec(["bash", "-c", "mkdir -p " + shellQuote(themePresetDir) + " && find " + shellQuote(themePresetDir) + " -maxdepth 1 -type f -name '*.css' | sort"])
    }

    function applyWallpaper(path) {
        const fileName = String(path || "").split("/").pop()
        if (fileName.length === 0)
            return
        themeBusy = true
        themeStatus = "Applying wallpaper..."
        themeRunner.exec([Services.Config.wallpaperScript, "wallpaper", "apply", fileName])
    }

    function saveThemePreset() {
        const cleaned = themePresetName.trim().replace(/[^A-Za-z0-9_.-]/g, "-")
        if (cleaned.length === 0) {
            themeStatus = "Name required"
            return
        }
        themeBusy = true
        themeStatus = "Saving preset..."
        themeRunner.exec(["bash", "-c", "mkdir -p " + shellQuote(themePresetDir) + " && cp " + shellQuote(walColorsPath) + " " + shellQuote(themePresetDir + "/" + cleaned + ".css")])
    }

    function loadThemePreset(path) {
        if (String(path || "").length === 0)
            return
        themeBusy = true
        themeStatus = "Loading preset..."
        themeRunner.exec(["bash", "-c", "cp " + shellQuote(path) + " " + shellQuote(walColorsPath)])
    }

    function deleteThemePreset(path) {
        if (String(path || "").indexOf(themePresetDir) !== 0)
            return
        themeBusy = true
        themeStatus = "Deleting preset..."
        themeRunner.exec(["bash", "-c", "rm -f " + shellQuote(path)])
    }

    function sedReplacement(text) {
        return String(text).replace(/\\/g, "\\\\").replace(/&/g, "\\&").replace(/\|/g, "\\|")
    }

    function luaString(text) {
        return "\"" + String(text).replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\""
    }

    function unquoteLua(text) {
        const trimmed = String(text || "").trim()
        const match = /^["'](.*)["']$/.exec(trimmed)
        return match ? match[1] : trimmed
    }

    function hyprLuaColor(text) {
        const value = String(text || "").trim()
        if (value === "$background")
            return "wal.background"
        const match = /^\$color([0-9]+)$/.exec(value)
        return match ? "wal.color" + match[1] : value
    }

    function simpleMatchExpr(key) {
        return "/^[[:space:]]*" + key + "[[:space:]]*=/p"
    }

    function simpleSetExpr(key, value) {
        return "/^[[:space:]]*" + key + "[[:space:]]*=/s|=.*$|= " + sedReplacement(value) + "|"
    }

    function scopedMatchExpr(scope, key) {
        return "/^[[:space:]]*" + scope + "[[:space:]]*=[[:space:]]*\\{/,/^[[:space:]]*\\},?/ { /^[[:space:]]*" + key + "[[:space:]]*=/p }"
    }

    function scopedSetExpr(scope, key, value) {
        return "/^[[:space:]]*" + scope + "[[:space:]]*=[[:space:]]*\\{/,/^[[:space:]]*\\},?/ { /^[[:space:]]*" + key + "[[:space:]]*=/s|=.*$|= " + sedReplacement(value) + ",| }"
    }

    function decorationSed(op) {
        if (op.key === "active_border") {
            const parts = String(op.value).trim().split(/\s+/)
            const first = parts.length > 0 ? parts[0] : decoActiveBorderA
            const second = parts.length > 1 ? parts[1] : decoActiveBorderB
            const angle = parts.length > 2 ? String(parts[2]).replace(/deg$/, "") : decoBorderAngle
            const line = "      active_border = { colors = { " + hyprLuaColor(first) + ", " + hyprLuaColor(second) + " }, angle = " + angle + " },"
            return {
                match: "/^[[:space:]]*active_border[[:space:]]*=/p",
                set: "/^[[:space:]]*active_border[[:space:]]*=/s|^.*$|" + sedReplacement(line) + "|"
            }
        }
        if (op.scope === "shadow" || op.scope === "blur")
            return { match: scopedMatchExpr(op.scope, op.key), set: scopedSetExpr(op.scope, op.key, op.key === "color" ? hyprLuaColor(op.value) : op.value) }
        return { match: simpleMatchExpr(op.key), set: "/^[[:space:]]*" + op.key + "[[:space:]]*=/s|=.*$|= " + sedReplacement(op.value) + ",|" }
    }

    function animationSed(op) {
        if (op.kind === "enabled")
            return {
                match: "/^[[:space:]]*enabled[[:space:]]*=[[:space:]]*(true|false),?/p",
                set: "/^[[:space:]]*enabled[[:space:]]*=/s|=.*$|= " + sedReplacement(op.value) + ",|"
            }
        return {
            match: "/hl\\.animation\\(\\{[[:space:]]*leaf[[:space:]]*=[[:space:]]*\"" + op.name + "\"/p",
            set: "/hl\\.animation\\(\\{[[:space:]]*leaf[[:space:]]*=[[:space:]]*\"" + op.name + "\"/s|speed[[:space:]]*=[[:space:]]*[0-9.]+|speed = " + sedReplacement(op.value) + "|"
        }
    }

    function ruleTransparencySed(op) {
        const line = op.enabled ? "  opacity = \"0.85 0.75\"," : "  -- opacity = \"0.85 0.75\","
        const range = "/^[[:space:]]*name[[:space:]]*=[[:space:]]*\"global-blur-transparency\"/,/^[[:space:]]*\\}\\)/"
        const opacityLine = "/^[[:space:]]*(--[[:space:]]*)?opacity[[:space:]]*=[[:space:]]*\"0\\.85[[:space:]]+0\\.75\",?[[:space:]]*$/"
        return {
            match: range + " { " + opacityLine + "p }",
            set: range + " { " + opacityLine + "s|^.*$|" + sedReplacement(line) + "| }"
        }
    }

    function sedOpForMode(op, mode) {
        if (mode === "animations")
            return animationSed(op)
        if (mode === "rules")
            return ruleTransparencySed(op)
        return decorationSed(op)
    }

    function writeSedOps(process, filePath, ops, mode) {
        if (ops.length === 0)
            return
        let script = "set -e\n"
            + "target=" + shellQuote(filePath) + "\n"
            + "hyprctl_bin=" + shellQuote(Services.Config.hyprctlBin) + "\n"
            + "backup=\"$target.bak\"\n"
            + "cp \"$target\" \"$backup\"\n"
            + "one() {\n"
            + "    count=$(sed -n -E \"$1\" \"$target\" | wc -l)\n"
            + "    test \"$count\" -eq 1\n"
            + "}\n"
        for (let i = 0; i < ops.length; i++) {
            const item = sedOpForMode(ops[i], mode)
            script += "one " + shellQuote(item.match) + "\n"
                + "sed -i -E " + shellQuote(item.set) + " \"$target\"\n"
        }
        script += "if ! \"$hyprctl_bin\" reload; then\n"
            + "    cp \"$backup\" \"$target\"\n"
            + "    \"$hyprctl_bin\" reload 2>/dev/null || true\n"
            + "    exit 1\n"
            + "fi\n"
        process.exec(["bash", "-c", script])
    }

    function writeDecorations() {
        const ops = pendingDecorationOps
        const ruleOps = pendingRuleOps
        pendingDecorationOps = []
        pendingRuleOps = []
        writeSedOps(decorationsWriter, decorationsPath, ops, "decorations")
        writeSedOps(rulesWriter, rulesPath, ruleOps, "rules")
    }

    function animationMatch(text, name, fallback) {
        const re = new RegExp("hl\\.animation\\(\\{[^\\n]*leaf\\s*=\\s*\"" + name + "\"[^\\n]*enabled\\s*=\\s*(true|false)[^\\n]*speed\\s*=\\s*([0-9.]+)(?:[^\\n]*style\\s*=\\s*\"([^\"]+)\")?")
        const match = re.exec(text)
        if (!match)
            return fallback
        return {
            enabled: match[1] === "true",
            speed: Number(match[2]),
            style: match[3] ? String(match[3]).trim() : fallback.style
        }
    }

    function loadAnimations(text) {
        animEnabled = boolMatch(text, "enabled", animEnabled)
        const windows = animationMatch(text, "windows", { enabled: animWindowsEnabled, speed: animWindowsSpeed, style: animWindowsStyle })
        animWindowsEnabled = windows.enabled
        animWindowsSpeed = windows.speed
        animWindowsStyle = windows.style
        const workspaces = animationMatch(text, "workspaces", { enabled: animWorkspacesEnabled, speed: animWorkspacesSpeed, style: animWorkspacesStyle })
        animWorkspacesEnabled = workspaces.enabled
        animWorkspacesSpeed = workspaces.speed
        animWorkspacesStyle = workspaces.style
        const layers = animationMatch(text, "layersIn", { enabled: animLayersEnabled, speed: animLayersSpeed, style: animLayersStyle })
        animLayersEnabled = layers.enabled
        animLayersSpeed = layers.speed
        animLayersStyle = layers.style
        const border = animationMatch(text, "border", { enabled: animBorderEnabled, speed: animBorderSpeed, style: animBorderStyle })
        animBorderEnabled = border.enabled
        animBorderSpeed = border.speed
        animBorderStyle = border.style
        const fade = animationMatch(text, "fade", { enabled: animFadeEnabled, speed: animFadeSpeed, style: animFadeStyle })
        animFadeEnabled = fade.enabled
        animFadeSpeed = fade.speed
        animFadeStyle = fade.style
    }

    function normalizedCategory(raw) {
        if (raw === "Apps")
            return "Applications"
        if (raw === "Quickshell")
            return "Shells"
        if (raw.indexOf("System") >= 0 || raw.indexOf("Session") >= 0 || raw.indexOf("Hardware") >= 0 || raw.indexOf("Media") >= 0 || raw.indexOf("Screenshot") >= 0)
            return "System"
        if (raw.indexOf("Workspace") >= 0)
            return "Workspaces"
        if (raw.indexOf("Window") >= 0 || raw.indexOf("Mouse") >= 0)
            return "Windows"
        return raw.length > 0 ? raw : "Other"
    }

    function splitLuaArgs(text) {
        const args = []
        let current = ""
        let depth = 0
        let quote = ""
        for (let i = 0; i < text.length; i++) {
            const ch = text[i]
            const prev = i > 0 ? text[i - 1] : ""
            if (quote.length > 0) {
                current += ch
                if (ch === quote && prev !== "\\")
                    quote = ""
                continue
            }
            if (ch === "\"" || ch === "'") {
                quote = ch
                current += ch
                continue
            }
            if (ch === "(" || ch === "{")
                depth++
            else if (ch === ")" || ch === "}")
                depth--
            if (ch === "," && depth === 0) {
                args.push(current.trim())
                current = ""
            } else {
                current += ch
            }
        }
        if (current.trim().length > 0)
            args.push(current.trim())
        return args
    }

    function parseLuaKeyExpr(expr) {
        let combo = ""
        const main = /^mainMod\s*\.\.\s*" \+ ([^"]+)"$/.exec(String(expr || "").trim())
        if (main)
            combo = "$mainMod + " + main[1]
        else
            combo = unquoteLua(expr)
        if (combo.indexOf("..") >= 0)
            return null
        const parts = combo.split(/\s*\+\s*/).filter(function(part) { return part.length > 0 })
        if (parts.length === 0)
            return null
        const key = parts[parts.length - 1]
        const mods = parts.slice(0, parts.length - 1).map(function(part) { return part === "SUPER" ? "$mainMod" : part }).join(" ")
        return { mods: mods, key: key }
    }

    function luaKeyExpr(mods, key) {
        const parts = String(mods || "").replace(/,/g, " ").split(/\s+/).filter(function(part) { return part.length > 0 })
        const normalized = []
        let hasMain = false
        for (let i = 0; i < parts.length; i++) {
            if (parts[i] === "$mainMod" || parts[i] === "mainMod" || parts[i] === "SUPER") {
                hasMain = true
            } else {
                normalized.push(parts[i])
            }
        }
        normalized.push(String(key || "").trim())
        if (hasMain)
            return "mainMod .. " + luaString(" + " + normalized.join(" + "))
        return luaString(normalized.join(" + "))
    }

    function parseLuaDispatcher(expr) {
        const exec = /^hl\.dsp\.exec_cmd\((.*)\)$/.exec(String(expr || "").trim())
        if (exec) {
            const arg = exec[1].trim()
            const quoted = /^["']/.test(arg)
            return {
                dispatcher: "exec",
                command: quoted ? unquoteLua(arg) : arg,
                commandIsExpression: !quoted
            }
        }
        return { dispatcher: String(expr || "").trim(), command: "", commandIsExpression: true }
    }

    function luaDispatcherExpr(dispatcher, command, commandIsExpression) {
        if (String(dispatcher || "").trim() !== "exec")
            return String(dispatcher || "").trim()
        const cmd = String(command || "").trim()
        return "hl.dsp.exec_cmd(" + (commandIsExpression ? cmd : luaString(cmd)) + ")"
    }

    function loadKeybinds(text) {
        const lines = text.split("\n")
        const items = []
        const grouped = ({})
        const infos = ({})
        let category = "Other"
        for (let i = 0; i < lines.length; i++) {
            const raw = lines[i]
            let cat = /^#\s*---\s*(.+?)\s*---/.exec(raw)
            if (!cat)
                cat = /^--\s*(.+?)\s*$/.exec(raw)
            if (cat) {
                category = normalizedCategory(cat[1].trim())
                if (!infos[category])
                    infos[category] = { category: category, headerLine: i + 1, insertAfterLine: i + 1, exists: true }
                continue
            }
            const luaBind = /^\s*hl\.bind\((.*)\)\s*$/.exec(raw)
            let item = null
            if (luaBind) {
                const args = splitLuaArgs(luaBind[1])
                if (args.length < 2)
                    continue
                const keyInfo = parseLuaKeyExpr(args[0])
                if (!keyInfo)
                    continue
                const action = parseLuaDispatcher(args[1])
                item = {
                    lineNo: i + 1,
                    raw: raw,
                    type: "hl.bind",
                    mods: keyInfo.mods,
                    key: keyInfo.key,
                    dispatcher: action.dispatcher,
                    command: action.command,
                    commandIsExpression: action.commandIsExpression,
                    flags: args.length > 2 ? args.slice(2).join(", ") : "",
                    hadTrailingComma: false,
                    category: category
                }
            } else {
                const match = /^\s*(bind\w*)\s*=\s*([^,]*),\s*([^,]*),\s*([^,]*),?\s*(.*)$/.exec(raw)
                if (!match)
                    continue
                item = {
                    lineNo: i + 1,
                    raw: raw,
                    type: match[1].trim(),
                    mods: match[2].trim(),
                    key: match[3].trim(),
                    dispatcher: match[4].trim(),
                    command: match[5].trim(),
                    commandIsExpression: false,
                    flags: "",
                    hadTrailingComma: raw.trim().endsWith(","),
                    category: category
                }
            }
            if (!infos[category])
                infos[category] = { category: category, headerLine: 0, insertAfterLine: i + 1, exists: category !== "Other" }
            items.push(item)
            if (!grouped[category])
                grouped[category] = []
            grouped[category].push(item)
            infos[category].insertAfterLine = i + 1
        }
        const order = ["Applications", "Shells", "System", "Windows", "Workspaces", "Other"]
        const groups = []
        const infoList = []
        for (let j = 0; j < order.length; j++) {
            const name = order[j]
            if (grouped[name] && grouped[name].length > 0) {
                groups.push({ category: name, items: grouped[name] })
                infoList.push(infos[name])
            }
        }
        for (const name in grouped) {
            if (order.indexOf(name) < 0 && grouped[name].length > 0) {
                groups.push({ category: name, items: grouped[name] })
                infoList.push(infos[name])
            }
        }
        keybinds = items
        keybindGroups = groups
        keybindCategoryInfos = infoList
    }

    function variableCategory(name) {
        if (name === "terminal" || name === "file" || name === "launcher" || name === "browser")
            return "Applications"
        if (name.indexOf("cursor") >= 0)
            return "Cursor"
        if (name.indexOf("monitor") >= 0 || name.indexOf("scale") >= 0 || name.indexOf("resolution") >= 0)
            return "Monitor"
        if (name.indexOf("input") >= 0 || name.indexOf("kb") >= 0 || name.indexOf("layout") >= 0 || name.indexOf("sensitivity") >= 0)
            return "Input"
        return "Misc"
    }

    function loadVariables(text) {
        const lines = String(text || "").split("\n")
        const items = []
        for (let i = 0; i < lines.length; i++) {
            const raw = lines[i]
            let match = /^\s*M\.([A-Za-z0-9_]+)\s*=\s*(.*)$/.exec(raw)
            if (!match)
                match = /^\s*\$([A-Za-z0-9_]+)\s*=\s*(.*)$/.exec(raw)
            if (!match)
                continue
            const name = match[1].trim()
            const rawValue = match[2].replace(/,$/, "").trim()
            if (raw.indexOf("M.") >= 0 && !/^["'].*["']$/.test(rawValue) && !/^-?[0-9.]+$/.test(rawValue) && !/^(true|false)$/.test(rawValue))
                continue
            items.push({
                lineNo: i + 1,
                raw: raw,
                name: name,
                value: unquoteLua(rawValue),
                category: variableCategory(name)
            })
        }
        variableItems = items
    }

    function filteredVariables(needle) {
        const query = String(needle || "").toLowerCase().trim()
        if (query.length === 0)
            return variableItems
        const result = []
        for (let i = 0; i < variableItems.length; i++) {
            const item = variableItems[i]
            const hay = (item.name + " " + item.value + " " + item.category).toLowerCase()
            if (hay.indexOf(query) >= 0)
                result.push(item)
        }
        return result
    }

    function queueVariableEdit(item, value) {
        const oldValue = String(item.raw || "").replace(/^\s*M\.[A-Za-z0-9_]+\s*=\s*/, "").replace(/,$/, "").trim()
        const numeric = /^-?[0-9.]+$/.test(oldValue)
        const bool = /^(true|false)$/.test(oldValue)
        const line = item.raw.indexOf("M.") >= 0 ? "M." + item.name + " = " + (numeric || bool ? String(value).trim() : luaString(value)) : "$" + item.name + " = " + String(value).trim()
        const next = []
        for (let i = 0; i < pendingVariableOps.length; i++) {
            if (pendingVariableOps[i].lineNo !== item.lineNo)
                next.push(pendingVariableOps[i])
        }
        next.push({ lineNo: item.lineNo, oldRaw: item.raw, newRaw: line })
        pendingVariableOps = next
        variableStatus = "Saving..."
        markDirty("variables")
    }

    function addVariable() {
        const name = variableAddName.trim().replace(/^\$/, "")
        const value = variableAddValue.trim()
        if (name.length === 0 || value.length === 0) {
            variableStatus = "Name and value required"
            return
        }
        pendingVariableOps = pendingVariableOps.concat([{ insertBefore: "return M", newRaw: "M." + name + " = " + luaString(value) }])
        variableAddName = ""
        variableAddValue = ""
        variableStatus = "Saving..."
        markDirty("variables")
    }

    function loadEnvironments(text) {
        const lines = String(text || "").split("\n")
        const items = []
        for (let i = 0; i < lines.length; i++) {
            const raw = lines[i]
            let match = /^\s*hl\.env\(\s*["']([^"']+)["']\s*,\s*(.*?)\s*\)\s*$/.exec(raw)
            if (match) {
                items.push({ lineNo: i + 1, raw: raw, key: match[1].trim(), value: unquoteLua(match[2].trim()), kind: "lua" })
                continue
            }
            match = /^\s*env\s*=\s*([^,=]+)\s*,\s*(.*)$/.exec(raw)
            if (match) {
                items.push({ lineNo: i + 1, raw: raw, key: match[1].trim(), value: match[2].trim(), kind: "hypr" })
                continue
            }
            match = /^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$/.exec(raw)
            if (match)
                items.push({ lineNo: i + 1, raw: raw, key: match[1].trim(), value: match[2].trim(), kind: "plain" })
        }
        envItems = items
    }

    function filteredEnvironments(needle) {
        const query = String(needle || "").toLowerCase().trim()
        if (query.length === 0)
            return envItems
        const result = []
        for (let i = 0; i < envItems.length; i++) {
            const item = envItems[i]
            if ((item.key + " " + item.value).toLowerCase().indexOf(query) >= 0)
                result.push(item)
        }
        return result
    }

    function envLineFor(item, value) {
        if (item.kind === "lua")
            return "hl.env(" + luaString(item.key) + ", " + luaString(value) + ")"
        return item.kind === "plain" ? item.key + "=" + String(value).trim() : "env = " + item.key + "," + String(value).trim()
    }

    function queueEnvEdit(item, value) {
        const next = []
        for (let i = 0; i < pendingEnvOps.length; i++) {
            if (pendingEnvOps[i].lineNo !== item.lineNo)
                next.push(pendingEnvOps[i])
        }
        next.push({ lineNo: item.lineNo, oldRaw: item.raw, newRaw: envLineFor(item, value) })
        pendingEnvOps = next
        envStatus = "Saving..."
        markDirty("environments")
    }

    function deleteEnvironment(item) {
        pendingEnvOps = pendingEnvOps.concat([{ lineNo: item.lineNo, oldRaw: item.raw, deleteLine: true }])
        envStatus = "Deleting..."
        markDirty("environments")
    }

    function addEnvironment() {
        const key = envAddKey.trim()
        const value = envAddValue.trim()
        if (key.length === 0 || value.length === 0) {
            envStatus = "Key and value required"
            return
        }
        pendingEnvOps = pendingEnvOps.concat([{ append: true, newRaw: "hl.env(" + luaString(key) + ", " + luaString(value) + ")" }])
        envAddKey = ""
        envAddValue = ""
        envStatus = "Saving..."
        markDirty("environments")
    }

    function applyLogout() {
        applyAll()
        logoutRunner.exec([Services.Config.hyprctlBin, "dispatch", "exit"])
    }

    function keybindCategoryNames() {
        const names = []
        for (let i = 0; i < keybindCategoryInfos.length; i++)
            names.push(keybindCategoryInfos[i].category)
        return names
    }

    function keybindCategoryInfo(name) {
        const normalized = normalizedCategory(String(name || "").trim())
        for (let i = 0; i < keybindCategoryInfos.length; i++) {
            if (keybindCategoryInfos[i].category.toLowerCase() === normalized.toLowerCase())
                return keybindCategoryInfos[i]
        }
        return null
    }

    function keybindText(item) {
        return (item.mods + " " + item.key + " " + item.dispatcher + " " + item.command + " " + item.category).toLowerCase()
    }

    function filteredKeybindGroups(needle) {
        const query = String(needle || "").toLowerCase().trim()
        if (query.length === 0)
            return keybindGroups
        const groups = []
        for (let i = 0; i < keybindGroups.length; i++) {
            const group = keybindGroups[i]
            const items = []
            for (let j = 0; j < group.items.length; j++) {
                const item = group.items[j]
                if (keybindText(item).indexOf(query) >= 0)
                    items.push(item)
            }
            if (items.length > 0)
                groups.push({ category: group.category, items: items })
        }
        return groups
    }

    function keybindModChips(mods) {
        const cleaned = String(mods || "").replace(/\$mainMod/g, "SUPER").replace(/,/g, " ").trim()
        return cleaned.length > 0 ? cleaned.split(/\s+/) : ["None"]
    }

    function qtModsToHypr(mods) {
        const parts = []
        if (mods & Qt.MetaModifier)
            parts.push("$mainMod")
        if (mods & Qt.ControlModifier)
            parts.push("CTRL")
        if (mods & Qt.AltModifier)
            parts.push("ALT")
        if (mods & Qt.ShiftModifier)
            parts.push("SHIFT")
        return parts.join(" ")
    }

    function qtKeyToHypr(key, text) {
        if (key >= Qt.Key_A && key <= Qt.Key_Z)
            return String.fromCharCode(65 + key - Qt.Key_A)
        if (key >= Qt.Key_0 && key <= Qt.Key_9)
            return String.fromCharCode(48 + key - Qt.Key_0)
        if (key === Qt.Key_Return || key === Qt.Key_Enter)
            return "Return"
        if (key === Qt.Key_Escape)
            return "Escape"
        if (key === Qt.Key_Tab)
            return "Tab"
        if (key === Qt.Key_Backspace)
            return "Backspace"
        if (key === Qt.Key_Space)
            return "Space"
        if (key === Qt.Key_Left)
            return "left"
        if (key === Qt.Key_Right)
            return "right"
        if (key === Qt.Key_Up)
            return "up"
        if (key === Qt.Key_Down)
            return "down"
        if (key === Qt.Key_Period)
            return "period"
        if (key === Qt.Key_Comma)
            return "comma"
        if (key === Qt.Key_Minus)
            return "minus"
        if (key === Qt.Key_Equal)
            return "equal"
        if (String(text || "").length === 1)
            return String(text).toUpperCase()
        return ""
    }

    function startKeybindEdit(item) {
        keybindEditLine = item.lineNo
        keybindEditType = item.type
        keybindEditMods = item.mods
        keybindEditKey = item.key
        keybindEditDispatcher = item.dispatcher
        keybindEditCommand = item.command
        keybindEditCommandIsExpression = item.commandIsExpression || false
        keybindEditFlags = item.flags || ""
        keybindEditRaw = item.raw
        keybindEditHadTrailingComma = item.hadTrailingComma
        keybindError = ""
        keybindRecording = false
    }

    function cancelKeybindEdit() {
        keybindEditLine = -1
        keybindError = ""
        keybindRecording = false
    }

    function keybindConflict(lineNo, mods, key) {
        const left = String(mods || "").replace(/\s+/g, " ").trim().toLowerCase()
        const right = String(key || "").trim().toLowerCase()
        for (let i = 0; i < keybinds.length; i++) {
            const item = keybinds[i]
            if (item.lineNo !== lineNo && item.mods.replace(/\s+/g, " ").trim().toLowerCase() === left && item.key.toLowerCase() === right)
                return item.category + ": " + item.dispatcher + (item.command.length > 0 ? " " + item.command : "")
        }
        return ""
    }

    function buildKeybindLine() {
        if (keybindEditType === "hl.bind") {
            const flags = keybindEditFlags.length > 0 ? ", " + keybindEditFlags : ""
            return "hl.bind(" + luaKeyExpr(keybindEditMods.trim(), keybindEditKey.trim()) + ", " + luaDispatcherExpr(keybindEditDispatcher, keybindEditCommand, keybindEditCommandIsExpression) + flags + ")"
        }
        const command = keybindEditCommand.trim()
        const tail = command.length > 0 ? ", " + command : (keybindEditHadTrailingComma ? "," : "")
        return keybindEditType.trim() + " = " + keybindEditMods.trim() + ", " + keybindEditKey.trim() + ", " + keybindEditDispatcher.trim() + tail
    }

    function saveKeybindEdit() {
        if (keybindEditLine < 1)
            return
        if (keybindEditMods.trim().length === 0 || keybindEditKey.trim().length === 0 || keybindEditDispatcher.trim().length === 0) {
            keybindError = "Modifier, key, and action cannot be empty."
            return
        }
        const conflict = keybindConflict(keybindEditLine, keybindEditMods, keybindEditKey)
        if (conflict.length > 0) {
            keybindError = "Conflict: " + conflict
            return
        }
        const newLine = buildKeybindLine()
        let script = "set -e\n"
            + "target=" + shellQuote(bindsPath) + "\n"
            + "hyprctl_bin=" + shellQuote(Services.Config.hyprctlBin) + "\n"
            + "line_no=" + keybindEditLine + "\n"
            + "old_line=" + shellQuote(keybindEditRaw) + "\n"
            + "backup=\"$target.bak\"\n"
            + "cp \"$target\" \"$backup\"\n"
            + "current=$(sed -n \"${line_no}p\" \"$target\")\n"
            + "test \"$current\" = \"$old_line\"\n"
            + "sed -i " + shellQuote(keybindEditLine + "s|^.*$|" + sedReplacement(newLine) + "|") + " \"$target\"\n"
            + "if ! \"$hyprctl_bin\" reload; then\n"
            + "    cp \"$backup\" \"$target\"\n"
            + "    \"$hyprctl_bin\" reload 2>/dev/null || true\n"
            + "    exit 1\n"
            + "fi\n"
        keybindWriter.exec(["bash", "-c", script])
    }

    function startAddKeybind() {
        keybindAdding = true
        keybindEditLine = -1
        keybindRecording = false
        keybindAddMods = "$mainMod"
        keybindAddKey = ""
        keybindAddDispatcher = "exec"
        keybindAddCommand = ""
        keybindAddCategory = keybindCategoryInfos.length > 0 ? keybindCategoryInfos[0].category : "Shells"
        keybindError = ""
    }

    function cancelAddKeybind() {
        keybindAdding = false
        keybindError = ""
    }

    function buildNewKeybindLine() {
        return "hl.bind(" + luaKeyExpr(keybindAddMods.trim(), keybindAddKey.trim()) + ", " + luaDispatcherExpr(keybindAddDispatcher.trim(), keybindAddCommand.trim(), false) + ")"
    }

    function saveNewKeybind() {
        if (keybindAddMods.trim().length === 0 || keybindAddKey.trim().length === 0 || keybindAddDispatcher.trim().length === 0) {
            keybindError = "Modifier, key, and action cannot be empty."
            return
        }
        const conflict = keybindConflict(-1, keybindAddMods, keybindAddKey)
        if (conflict.length > 0) {
            keybindError = "Conflict: " + conflict
            return
        }
        if (keybindAddCategory.trim().length === 0) {
            keybindError = "Category cannot be empty."
            return
        }
        const newLine = buildNewKeybindLine()
        const category = normalizedCategory(keybindAddCategory.trim())
        const info = keybindCategoryInfo(category)
        const sedExpr = info ? info.insertAfterLine + "a\\" + newLine.replace(/\\/g, "\\\\")
            : "$a\\\n-- " + category.replace(/\\/g, "\\\\") + "\\\n" + newLine.replace(/\\/g, "\\\\")
        let script = "set -e\n"
            + "target=" + shellQuote(bindsPath) + "\n"
            + "hyprctl_bin=" + shellQuote(Services.Config.hyprctlBin) + "\n"
            + "backup=\"$target.bak\"\n"
            + "cp \"$target\" \"$backup\"\n"
            + "sed -i " + shellQuote(sedExpr) + " \"$target\"\n"
            + "if ! \"$hyprctl_bin\" reload; then\n"
            + "    cp \"$backup\" \"$target\"\n"
            + "    \"$hyprctl_bin\" reload 2>/dev/null || true\n"
            + "    exit 1\n"
            + "fi\n"
        keybindWriter.exec(["bash", "-c", script])
    }

    function writeExactLineOps(process, filePath, ops) {
        if (ops.length === 0)
            return
        let script = "set -e\n"
            + "target=" + shellQuote(filePath) + "\n"
            + "hyprctl_bin=" + shellQuote(Services.Config.hyprctlBin) + "\n"
            + "backup=\"$target.bak\"\n"
            + "cp \"$target\" \"$backup\"\n"
        for (let i = 0; i < ops.length; i++) {
            const op = ops[i]
            if (op.append) {
                script += "sed -i " + shellQuote("$a\\" + String(op.newRaw).replace(/\\/g, "\\\\")) + " \"$target\"\n"
            } else if (op.insertBefore) {
                script += "one_line=$(sed -n " + shellQuote("/^[[:space:]]*" + op.insertBefore + "[[:space:]]*$/=") + " \"$target\" | head -n 1)\n"
                    + "test -n \"$one_line\"\n"
                    + "sed -i \"${one_line}i\\" + shellDouble(String(op.newRaw)).slice(1, -1) + "\" \"$target\"\n"
            } else if (op.deleteLine) {
                script += "current=$(sed -n " + shellQuote(op.lineNo + "p") + " \"$target\")\n"
                    + "test \"$current\" = " + shellQuote(op.oldRaw) + "\n"
                    + "sed -i " + shellQuote(op.lineNo + "d") + " \"$target\"\n"
            } else {
                script += "current=$(sed -n " + shellQuote(op.lineNo + "p") + " \"$target\")\n"
                    + "test \"$current\" = " + shellQuote(op.oldRaw) + "\n"
                    + "sed -i " + shellQuote(op.lineNo + "s|^.*$|" + sedReplacement(op.newRaw) + "|") + " \"$target\"\n"
            }
        }
        script += "if ! \"$hyprctl_bin\" reload; then\n"
            + "    cp \"$backup\" \"$target\"\n"
            + "    \"$hyprctl_bin\" reload 2>/dev/null || true\n"
            + "    exit 1\n"
            + "fi\n"
        process.exec(["bash", "-c", script])
    }

    function writeVariables() {
        const ops = pendingVariableOps
        pendingVariableOps = []
        writeExactLineOps(variablesWriter, variablesPath, ops)
    }

    function writeEnvironments() {
        const ops = pendingEnvOps
        pendingEnvOps = []
        writeExactLineOps(envWriter, envPath, ops)
    }

    function writeAnimations() {
        const ops = pendingAnimationOps
        pendingAnimationOps = []
        writeSedOps(animationsWriter, animationsPath, ops, "animations")
    }

    component Sidebar: Rectangle {
        id: side
        property var theme
        property var items: []
        property int activeIndex: 0
        property var pendingSections: ({})
        signal selected(int index)

        color: "transparent"

        Column {
            anchors.fill: parent
            anchors.margins: side.theme.panelPadding
            spacing: side.theme.itemSpacing + 4

            Row {
                width: parent.width
                height: 28
                spacing: 10

                Text { text: "󰒓"; color: side.theme.color4; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Settings"; color: side.theme.foreground; font.family: side.theme.fontFamily; font.pixelSize: 18 * side.theme.fontScale; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
            }

            Item {
                width: parent.width
                height: 7 * 56

                Rectangle {
                    id: activeIndicator
                    width: parent.width
                    height: 48
                    x: 0
                    y: side.activeIndex * 56
                    radius: side.theme.itemRadius
                    color: side.theme.withAlpha(side.theme.color4, 0.15)
                    Behavior on y { SpringAnimation { duration: side.theme && side.theme.reducedMotion ? 0 : 250; spring: side.theme.springStrength; damping: 0.78; mass: 0.9; epsilon: 0.001 } }
                }

                Repeater {
                    model: side.items

                    Rectangle {
                        id: navItem
                        width: parent.width
                        height: 48
                        y: index * 56
                        radius: side.theme.itemRadius
                        color: navArea.containsMouse ? side.theme.withAlpha(side.theme.color4, 0.08) : "transparent"
                        scale: navArea.pressed ? 0.97 : 1
                        Behavior on color { ColorAnimation { duration: side.theme.motionDuration(150); easing.type: Easing.OutCubic } }
                        Behavior on scale { SpringAnimation { duration: side.theme && side.theme.reducedMotion ? 0 : 250; spring: side.theme.springStrength; damping: side.theme.springDamping; mass: 0.9; epsilon: 0.001 } }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            spacing: 10

                            Rectangle {
                                width: 28
                                height: 28
                                radius: 14
                                anchors.verticalCenter: parent.verticalCenter
                                color: side.theme.withAlpha(side.theme.color4, 0.15)
                                scale: navArea.containsMouse ? 1.1 : 1
                                Behavior on scale { SpringAnimation { duration: side.theme && side.theme.reducedMotion ? 0 : 250; spring: side.theme.springStrength; damping: side.theme.springDamping; mass: 0.9; epsilon: 0.001 } }
                                Text { anchors.centerIn: parent; text: modelData.icon; color: side.theme.color4; font.pixelSize: 14 }
                            }

                            Text {
                                width: parent.width - 72
                                text: modelData.label
                                color: side.theme.foreground
                                font.family: side.theme.fontFamily
                                font.pixelSize: 13 * side.theme.fontScale
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                anchors.verticalCenter: parent.verticalCenter
                                opacity: side.pendingSections[modelData.id] ? pulseOpacity : 0
                                color: side.theme.color4
                                property real pulseOpacity: 1
                                SequentialAnimation on pulseOpacity {
                                    loops: Animation.Infinite
                                    running: side.pendingSections[modelData.id] === true
                                    NumberAnimation { to: 0.35; duration: side.theme.motionDuration(650); easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1; duration: side.theme.motionDuration(650); easing.type: Easing.InOutSine }
                                }
                            }
                        }

                        MouseArea {
                            id: navArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: side.selected(index)
                        }
                    }
                }
            }
        }
    }

    component ContentPane: Item {
        id: pane
        property var theme
        property var stateService
        property var activeItem
        property string searchText: ""
        property var shownItem: activeItem
        property var nextItem: null
        property bool ready: false
        signal dirty(string sectionId)

        onActiveItemChanged: {
            if (!ready || !shownItem) {
                shownItem = activeItem
                ready = true
                return
            }
            if (shownItem && activeItem && shownItem.id === activeItem.id)
                return
            nextItem = activeItem
            sectionSwitch.restart()
        }

        SequentialAnimation {
            id: sectionSwitch
            NumberAnimation { target: content; property: "opacity"; to: 0; duration: pane.theme.motionDuration(110); easing.type: Easing.OutCubic }
            NumberAnimation { target: content; property: "x"; to: -22; duration: pane.theme.motionDuration(110); easing.type: Easing.OutCubic }
            ScriptAction {
                script: {
                    pane.shownItem = pane.nextItem
                    flick.contentY = 0
                    content.x = 22
                }
            }
            ParallelAnimation {
                NumberAnimation { target: content; property: "opacity"; to: 1; duration: pane.theme.motionDuration(180); easing.type: Easing.OutCubic }
                NumberAnimation { target: content; property: "x"; to: 0; duration: pane.theme.motionDuration(180); easing.type: Easing.OutCubic }
            }
        }

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: pane.theme.panelPadding
            contentWidth: width
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: content
                width: flick.width
                spacing: pane.theme.itemSpacing + 8
                opacity: 1
                x: 0

                Text {
                    text: pane.shownItem ? pane.shownItem.label : ""
                    color: pane.theme.foreground
                    font.family: pane.theme.fontFamily
                    font.pixelSize: 22 * pane.theme.fontScale
                    font.bold: true
                }

                Text {
                    width: parent.width
                    text: pane.shownItem ? pane.shownItem.subtitle : ""
                    color: pane.theme.color6
                    font.family: pane.theme.fontFamily
                    font.pixelSize: 12 * pane.theme.fontScale
                    wrapMode: Text.WordWrap
                }

                Loader {
                    width: parent.width
                    sourceComponent: pane.shownItem && pane.shownItem.id === "shell" ? shellSection
                        : pane.shownItem && pane.shownItem.id === "decorations" ? decorationsSection
                        : pane.shownItem && pane.shownItem.id === "animations" ? animationsSection
                        : pane.shownItem && pane.shownItem.id === "keybinds" ? keybindsSection
                        : pane.shownItem && pane.shownItem.id === "themes" ? themesSection
                        : pane.shownItem && pane.shownItem.id === "variables" ? variablesSection
                        : pane.shownItem && pane.shownItem.id === "environments" ? environmentsSection
                        : placeholderSection
                }
            }
        }

        Component {
            id: placeholderSection
            Column {
                width: parent.width
                spacing: 14
                PlaceholderCard { theme: pane.theme; title: pane.shownItem ? pane.shownItem.label + " controls" : ""; text: "Section scaffold ready. Controls will write with debounce and use Android 16 surfaces." }
                LivePreview { theme: pane.theme }
            }
        }

        Component {
            id: keybindsSection
            Column {
                width: parent.width
                spacing: 14

                Rectangle {
                    width: parent.width
                    height: keybindErrorText.visible ? 44 : 0
                    radius: pane.theme.itemRadius
                    color: pane.theme.withAlpha(pane.theme.color3, 0.16)
                    border.width: keybindErrorText.visible && pane.theme.outerBorder ? pane.theme.borderWidth : 0
                    border.color: pane.theme.withAlpha(pane.theme.color3, 0.55)
                    visible: height > 0
                    clip: true
                    Behavior on height { NumberAnimation { duration: pane.theme.motionDuration(160); easing.type: Easing.OutCubic } }
                    Text {
                        id: keybindErrorText
                        anchors.fill: parent
                        anchors.margins: 12
                        text: root.keybindError
                        visible: root.keybindError.length > 0
                        color: pane.theme.foreground
                        font.pixelSize: 12 * pane.theme.fontScale
                        font.bold: true
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Rectangle {
                    id: addKeybindButton
                    width: parent.width
                    height: 42
                    radius: pane.theme.pillRadius
                    color: addKeybindArea.containsMouse ? pane.theme.withAlpha(pane.theme.color4, 0.26) : pane.theme.withAlpha(pane.theme.color4, 0.16)
                    border.width: pane.theme.outerBorder ? pane.theme.borderWidth : 0
                    border.color: pane.theme.withAlpha(pane.theme.color4, addKeybindArea.containsMouse ? 0.72 : 0.42)
                    scale: addKeybindArea.pressed ? 0.98 : (addKeybindArea.containsMouse ? 1.015 : 1)
                    Behavior on color { ColorAnimation { duration: pane.theme.motionDuration(160); easing.type: Easing.OutCubic } }
                    Behavior on border.color { ColorAnimation { duration: pane.theme.motionDuration(160); easing.type: Easing.OutCubic } }
                    Behavior on scale { SpringAnimation { duration: pane.theme && pane.theme.reducedMotion ? 0 : 260; spring: pane.theme.springStrength + 1; damping: pane.theme.springDamping; mass: 0.8; epsilon: 0.001 } }
                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            text: "󰐕"
                            color: pane.theme.color4
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                            rotation: addKeybindArea.containsMouse ? 90 : 0
                            Behavior on rotation { SpringAnimation { duration: pane.theme && pane.theme.reducedMotion ? 0 : 300; spring: pane.theme.springStrength + 1; damping: pane.theme.springDamping; mass: 0.8; epsilon: 0.001 } }
                        }
                        Text { text: "Add New Keybind"; color: pane.theme.foreground; font.pixelSize: 12 * pane.theme.fontScale; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        id: addKeybindArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.startAddKeybind()
                    }
                }

                Item {
                    width: parent.width
                    height: root.keybindAdding ? addKeybindCard.height : 0
                    clip: true
                    Behavior on height { NumberAnimation { duration: pane.theme.motionDuration(220); easing.type: Easing.OutCubic } }

                    ShellCard {
                        id: addKeybindCard
                        theme: pane.theme
                        title: "New Keybind"
                        animateEntrance: false
                        opacity: root.keybindAdding ? 1 : 0
                        y: root.keybindAdding ? 0 : -16
                        scale: root.keybindAdding ? 1 : 0.96
                        Behavior on opacity { NumberAnimation { duration: pane.theme.motionDuration(180); easing.type: Easing.OutCubic } }
                        Behavior on y { SpringAnimation { duration: pane.theme && pane.theme.reducedMotion ? 0 : 280; spring: pane.theme.springStrength; damping: pane.theme.springDamping; mass: 0.85; epsilon: 0.001 } }
                        Behavior on scale { SpringAnimation { duration: pane.theme && pane.theme.reducedMotion ? 0 : 280; spring: pane.theme.springStrength; damping: pane.theme.springDamping; mass: 0.85; epsilon: 0.001 } }
                        CategoryPicker { theme: pane.theme }
                        ShellTextInput { theme: pane.theme; label: "Category"; textValue: root.keybindAddCategory; onChanged: function(v) { root.keybindAddCategory = v } }
                        ShellTextInput { theme: pane.theme; label: "Modifiers"; textValue: root.keybindAddMods; onChanged: function(v) { root.keybindAddMods = v } }
                        ShellTextInput { theme: pane.theme; label: "Key"; textValue: root.keybindAddKey; onChanged: function(v) { root.keybindAddKey = v } }
                        KeyRecorder { theme: pane.theme; addMode: true }
                        ShellTextInput { theme: pane.theme; label: "Action"; textValue: root.keybindAddDispatcher; onChanged: function(v) { root.keybindAddDispatcher = v } }
                        ShellTextInput { theme: pane.theme; label: "Command"; textValue: root.keybindAddCommand; onChanged: function(v) { root.keybindAddCommand = v } }
                        Row {
                            width: parent.width
                            height: 36
                            spacing: 8
                            layoutDirection: Qt.RightToLeft
                            KeybindActionButton { theme: pane.theme; label: "Add"; accent: true; onClicked: root.saveNewKeybind() }
                            KeybindActionButton { theme: pane.theme; label: "Cancel"; onClicked: root.cancelAddKeybind() }
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: root.filteredKeybindGroups(pane.searchText).length === 0
                    text: "No keybinds match search."
                    color: pane.theme.color6
                    font.pixelSize: 12 * pane.theme.fontScale
                    font.bold: true
                }

                Repeater {
                    model: root.filteredKeybindGroups(pane.searchText)
                    ShellCard {
                        id: keybindGroupCard
                        property real cardScale: 0.98
                        theme: pane.theme
                        title: modelData.category
                        animateEntrance: false
                        opacity: 0
                        scale: cardScale
                        Component.onCompleted: groupEnter.restart()
                        SequentialAnimation {
                            id: groupEnter
                            PauseAnimation { duration: pane.theme.motionDuration(Math.min(180, index * 35)) }
                            ParallelAnimation {
                                NumberAnimation { target: keybindGroupCard; property: "opacity"; to: 1; duration: pane.theme.motionDuration(220); easing.type: Easing.OutCubic }
                                NumberAnimation { target: keybindGroupCard; property: "cardScale"; to: 1; duration: pane.theme.motionDuration(220); easing.type: Easing.OutCubic }
                            }
                        }
                        Repeater {
                            model: modelData.items
                            KeybindRow {
                                theme: pane.theme
                                item: modelData
                            }
                        }
                    }
                }
            }
        }

        Component {
            id: themesSection
            Column {
                width: parent.width
                spacing: 14

                ShellCard { theme: pane.theme; title: "Current Colors"
                    Flow {
                        width: parent.width
                        spacing: 8
                        Repeater {
                            model: root.themeColorItems()
                            ThemeSwatch {
                                theme: pane.theme
                                colorName: modelData.name
                                colorValue: modelData.value
                            }
                        }
                    }
                }

                ShellCard { theme: pane.theme; title: "Wallpaper Picker"
                    Text {
                        width: parent.width
                        text: root.themeWallpapers.length === 0 ? "No wallpapers found in " + Services.Config.wallpaperDir : "Active: " + (root.activeWallpaperPath.length > 0 ? root.activeWallpaperPath.split("/").pop() : "unknown")
                        color: pane.theme.color6
                        font.pixelSize: 11 * pane.theme.fontScale
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Grid {
                        width: parent.width
                        columns: 3
                        spacing: 10
                        Repeater {
                            model: root.themeWallpapers
                            WallpaperTile {
                                theme: pane.theme
                                item: modelData
                            }
                        }
                    }
                }

                ShellCard { theme: pane.theme; title: "Theme Presets"
                    ShellTextInput { theme: pane.theme; label: "Preset Name"; textValue: root.themePresetName; onChanged: function(v) { root.themePresetName = v } }
                    Row {
                        width: parent.width
                        height: 36
                        spacing: 8
                        layoutDirection: Qt.RightToLeft
                        KeybindActionButton { theme: pane.theme; label: "Save"; accent: true; onClicked: root.saveThemePreset() }
                        KeybindActionButton { theme: pane.theme; label: "Refresh"; onClicked: root.refreshThemeAssets() }
                    }
                    Text {
                        width: parent.width
                        visible: root.themeStatus.length > 0
                        text: root.themeStatus
                        color: root.themeBusy ? pane.theme.color4 : pane.theme.color6
                        font.pixelSize: 11 * pane.theme.fontScale
                        font.bold: true
                    }
                    Column {
                        width: parent.width
                        spacing: 8
                        Repeater {
                            model: root.themePresets
                            ThemePresetRow {
                                theme: pane.theme
                                item: modelData
                            }
                        }
                    }
                }
            }
        }

        Component {
            id: variablesSection
            Column {
                width: parent.width
                spacing: 14

                ShellCard { theme: pane.theme; title: "Add Variable"
                    Column {
                        width: parent.width
                        spacing: 8
                        ShellTextInput { width: parent.width; theme: pane.theme; label: "Name"; textValue: root.variableAddName; onChanged: function(v) { root.variableAddName = v } }
                        ShellTextInput { width: parent.width; theme: pane.theme; label: "Value"; textValue: root.variableAddValue; onChanged: function(v) { root.variableAddValue = v } }
                        Row {
                            width: parent.width
                            height: 36
                            layoutDirection: Qt.RightToLeft
                            KeybindActionButton { theme: pane.theme; label: "Add"; accent: true; onClicked: root.addVariable() }
                        }
                    }
                    Text {
                        width: parent.width
                        visible: root.variableStatus.length > 0
                        text: root.variableStatus
                        color: pane.theme.color6
                        font.pixelSize: 11 * pane.theme.fontScale
                        font.bold: true
                    }
                }

                ShellCard { theme: pane.theme; title: "Hyprland Variables"
                    Column {
                        width: parent.width
                        spacing: 8
                        Repeater {
                            model: root.filteredVariables(pane.searchText)
                            VariableRow {
                                theme: pane.theme
                                item: modelData
                            }
                        }
                    }
                }
            }
        }

        Component {
            id: environmentsSection
            Column {
                width: parent.width
                spacing: 14

                ShellCard { theme: pane.theme; title: "Session Warning"
                    Rectangle {
                        width: parent.width
                        height: 54
                        radius: pane.theme.itemRadius
                        color: pane.theme.withAlpha(pane.theme.color3, 0.14)
                        border.width: pane.theme.outerBorder ? pane.theme.borderWidth : 0
                        border.color: pane.theme.withAlpha(pane.theme.color3, 0.42)
                        Text {
                            anchors.fill: parent
                            anchors.margins: 12
                            text: "Environment changes usually require re-login."
                            color: pane.theme.foreground
                            font.pixelSize: 12 * pane.theme.fontScale
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    Row {
                        width: parent.width
                        height: 36
                        spacing: 8
                        layoutDirection: Qt.RightToLeft
                        KeybindActionButton { theme: pane.theme; label: "Logout"; accent: true; onClicked: root.applyLogout() }
                    }
                }

                ShellCard { theme: pane.theme; title: "Add Environment"
                    Column {
                        width: parent.width
                        spacing: 8
                        ShellTextInput { width: parent.width; theme: pane.theme; label: "Key"; textValue: root.envAddKey; onChanged: function(v) { root.envAddKey = v } }
                        ShellTextInput { width: parent.width; theme: pane.theme; label: "Value"; textValue: root.envAddValue; onChanged: function(v) { root.envAddValue = v } }
                        Row {
                            width: parent.width
                            height: 36
                            layoutDirection: Qt.RightToLeft
                            KeybindActionButton { theme: pane.theme; label: "Add"; accent: true; onClicked: root.addEnvironment() }
                        }
                    }
                    Text {
                        width: parent.width
                        visible: root.envStatus.length > 0
                        text: root.envStatus
                        color: pane.theme.color6
                        font.pixelSize: 11 * pane.theme.fontScale
                        font.bold: true
                    }
                }

                ShellCard { theme: pane.theme; title: "Common Variables"
                    EnvQuickRow { theme: pane.theme; keyName: "XCURSOR_SIZE"; fallbackValue: "24" }
                    EnvQuickRow { theme: pane.theme; keyName: "QT_QPA_PLATFORM"; fallbackValue: "wayland" }
                    EnvQuickRow { theme: pane.theme; keyName: "GDK_BACKEND"; fallbackValue: "wayland" }
                    EnvQuickRow { theme: pane.theme; keyName: "WLR_NO_HARDWARE_CURSORS"; fallbackValue: "0" }
                    EnvQuickRow { theme: pane.theme; keyName: "ELECTRON_OZONE_PLATFORM_HINT"; fallbackValue: "auto" }
                }

                ShellCard { theme: pane.theme; title: "Environment Entries"
                    Column {
                        width: parent.width
                        spacing: 8
                        Repeater {
                            model: root.filteredEnvironments(pane.searchText)
                            EnvRow {
                                theme: pane.theme
                                item: modelData
                            }
                        }
                    }
                }
            }
        }

        Component {
            id: animationsSection
            Column {
                width: parent.width
                spacing: 14
                ShellCard { theme: pane.theme; title: "Global"
                    ShellSwitch { theme: pane.theme; label: "Enable Animations"; checked: root.animEnabled; onChanged: function(v) { root.animEnabled = v; root.queueAnimation("enabled", "enabled", v ? "true" : "false") } }
                    ShellSlider { theme: pane.theme; label: "Global Speed"; value: root.animGlobalSpeed; minValue: 0.1; maxValue: 10; step: 0.1; enabled: root.animEnabled; onChanged: function(v) { root.animGlobalSpeed = v } }
                    SegmentedControl { theme: pane.theme; label: "Bezier Preset"; value: root.animPreset; options: ["Smooth", "Bouncy", "Snappy", "Linear", "Spring"]; onChanged: function(v) { root.animPreset = v } }
                    BezierPreview { theme: pane.theme; preset: root.animPreset }
                }
                ShellCard { theme: pane.theme; title: "Windows"
                    ShellSwitch { theme: pane.theme; label: "Windows"; checked: root.animWindowsEnabled; onChanged: function(v) { root.animWindowsEnabled = v } }
                    ShellSlider { theme: pane.theme; label: "Speed"; value: root.animWindowsSpeed; minValue: 0.1; maxValue: 10; step: 0.1; enabled: root.animWindowsEnabled && root.animEnabled; onChanged: function(v) { root.animWindowsSpeed = v; root.queueAnimation("speed", "windows", Number(v).toFixed(1).replace(/\\.0$/, "")) } }
                    ShellTextInput { theme: pane.theme; label: "Style"; textValue: root.animWindowsStyle; onChanged: function(v) { root.animWindowsStyle = v } }
                }
                ShellCard { theme: pane.theme; title: "Workspaces"
                    ShellSwitch { theme: pane.theme; label: "Workspaces"; checked: root.animWorkspacesEnabled; onChanged: function(v) { root.animWorkspacesEnabled = v } }
                    ShellSlider { theme: pane.theme; label: "Speed"; value: root.animWorkspacesSpeed; minValue: 0.1; maxValue: 10; step: 0.1; enabled: root.animWorkspacesEnabled && root.animEnabled; onChanged: function(v) { root.animWorkspacesSpeed = v; root.queueAnimation("speed", "workspaces", Number(v).toFixed(1).replace(/\\.0$/, "")) } }
                    SegmentedControl { theme: pane.theme; label: "Style"; value: root.animWorkspacesStyle; options: ["slide", "fade", "zoom"]; onChanged: function(v) { root.animWorkspacesStyle = v } }
                }
                ShellCard { theme: pane.theme; title: "Layers"
                    ShellSwitch { theme: pane.theme; label: "Layers"; checked: root.animLayersEnabled; onChanged: function(v) { root.animLayersEnabled = v } }
                    ShellSlider { theme: pane.theme; label: "Speed"; value: root.animLayersSpeed; minValue: 0.1; maxValue: 10; step: 0.1; enabled: root.animLayersEnabled && root.animEnabled; onChanged: function(v) { root.animLayersSpeed = v; root.queueAnimation("speed", "layersIn", Number(v).toFixed(1).replace(/\\.0$/, "")) } }
                    SegmentedControl { theme: pane.theme; label: "Style"; value: root.animLayersStyle; options: ["slide", "fade", "popin"]; onChanged: function(v) { root.animLayersStyle = v } }
                }
                ShellCard { theme: pane.theme; title: "Border + Fade"
                    ShellSwitch { theme: pane.theme; label: "Border Animation"; checked: root.animBorderEnabled; onChanged: function(v) { root.animBorderEnabled = v } }
                    ShellSlider { theme: pane.theme; label: "Border Speed"; value: root.animBorderSpeed; minValue: 0.1; maxValue: 12; step: 0.1; enabled: root.animBorderEnabled && root.animEnabled; onChanged: function(v) { root.animBorderSpeed = v; root.queueAnimation("speed", "border", Number(v).toFixed(1).replace(/\\.0$/, "")) } }
                    ShellSwitch { theme: pane.theme; label: "Fade Animation"; checked: root.animFadeEnabled; onChanged: function(v) { root.animFadeEnabled = v } }
                    ShellSlider { theme: pane.theme; label: "Fade Speed"; value: root.animFadeSpeed; minValue: 0.1; maxValue: 10; step: 0.1; enabled: root.animFadeEnabled && root.animEnabled; onChanged: function(v) { root.animFadeSpeed = v; root.queueAnimation("speed", "fade", Number(v).toFixed(1).replace(/\\.0$/, "")) } }
                    BezierPreview { theme: pane.theme; preset: root.animPreset }
                }
            }
        }

        Component {
            id: decorationsSection
            Column {
                width: parent.width
                spacing: 14
                ShellCard { theme: pane.theme; title: "Window"
                    ShellSlider { theme: pane.theme; label: "Rounding"; value: root.decoRounding; minValue: 0; maxValue: 30; step: 1; onChanged: function(v) { root.decoRounding = Math.round(v); root.queueDecoration("global", "rounding", root.decoRounding) } }
                    ShellSlider { theme: pane.theme; label: "Border Size"; value: root.decoBorderSize; minValue: 0; maxValue: 5; step: 1; onChanged: function(v) { root.decoBorderSize = Math.round(v); root.queueDecoration("global", "border_size", root.decoBorderSize) } }
                    ShellTextInput { theme: pane.theme; label: "Active Border A"; textValue: root.decoActiveBorderA; onChanged: function(v) { root.decoActiveBorderA = v; root.queueDecoration("global", "active_border", root.decoActiveBorderA + " " + root.decoActiveBorderB + " " + Math.round(root.decoBorderAngle) + "deg") } }
                    ShellTextInput { theme: pane.theme; label: "Active Border B"; textValue: root.decoActiveBorderB; onChanged: function(v) { root.decoActiveBorderB = v; root.queueDecoration("global", "active_border", root.decoActiveBorderA + " " + root.decoActiveBorderB + " " + Math.round(root.decoBorderAngle) + "deg") } }
                    ShellSlider { theme: pane.theme; label: "Border Angle"; value: root.decoBorderAngle; minValue: 0; maxValue: 360; step: 5; onChanged: function(v) { root.decoBorderAngle = Math.round(v); root.queueDecoration("global", "active_border", root.decoActiveBorderA + " " + root.decoActiveBorderB + " " + root.decoBorderAngle + "deg") } }
                    ShellSlider { theme: pane.theme; label: "Gaps In"; value: root.decoGapsIn; minValue: 0; maxValue: 50; step: 1; onChanged: function(v) { root.decoGapsIn = Math.round(v); root.queueDecoration("global", "gaps_in", root.decoGapsIn) } }
                    ShellSlider { theme: pane.theme; label: "Gaps Out"; value: root.decoGapsOut; minValue: 0; maxValue: 50; step: 1; onChanged: function(v) { root.decoGapsOut = Math.round(v); root.queueDecoration("global", "gaps_out", root.decoGapsOut) } }
                    DecorationPreview { theme: pane.theme }
                }
                ShellCard { theme: pane.theme; title: "Opacity"
                    ShellSlider { theme: pane.theme; label: "Active Opacity"; value: root.decoActiveOpacity; minValue: 0.5; maxValue: 1; step: 0.01; onChanged: function(v) { root.decoActiveOpacity = v; root.queueDecoration("global", "active_opacity", Number(v).toFixed(2)) } }
                    ShellSlider { theme: pane.theme; label: "Inactive Opacity"; value: root.decoInactiveOpacity; minValue: 0.5; maxValue: 1; step: 0.01; onChanged: function(v) { root.decoInactiveOpacity = v; root.queueDecoration("global", "inactive_opacity", Number(v).toFixed(2)) } }
                    ShellSwitch { theme: pane.theme; label: "Global Transparency"; checked: root.decoGlobalTransparency; onChanged: function(v) { root.decoGlobalTransparency = v; root.queueRuleTransparency(v) } }
                    ShellSwitch { theme: pane.theme; label: "Dim Inactive"; checked: root.decoDimInactive; onChanged: function(v) { root.decoDimInactive = v; root.queueDecoration("global", "dim_inactive", v ? "true" : "false") } }
                }
                ShellCard { theme: pane.theme; title: "Shadow"
                    ShellSwitch { theme: pane.theme; label: "Enable Shadow"; checked: root.decoShadowEnabled; onChanged: function(v) { root.decoShadowEnabled = v; root.queueDecoration("shadow", "enabled", v ? "true" : "false") } }
                    ShellSlider { theme: pane.theme; label: "Shadow Range"; value: root.decoShadowRange; minValue: 0; maxValue: 50; step: 1; enabled: root.decoShadowEnabled; onChanged: function(v) { root.decoShadowRange = Math.round(v); root.queueDecoration("shadow", "range", root.decoShadowRange) } }
                    ShellSlider { theme: pane.theme; label: "Render Power"; value: root.decoShadowRenderPower; minValue: 1; maxValue: 4; step: 1; enabled: root.decoShadowEnabled; onChanged: function(v) { root.decoShadowRenderPower = Math.round(v); root.queueDecoration("shadow", "render_power", root.decoShadowRenderPower) } }
                    ShellTextInput { theme: pane.theme; label: "Shadow Color"; textValue: root.decoShadowColor; onChanged: function(v) { root.decoShadowColor = v; root.queueDecoration("shadow", "color", root.decoShadowColor) } }
                }
                ShellCard { theme: pane.theme; title: "Blur"
                    ShellSwitch { theme: pane.theme; label: "Enable Blur"; checked: root.decoBlurEnabled; onChanged: function(v) { root.decoBlurEnabled = v; root.queueDecoration("blur", "enabled", v ? "true" : "false") } }
                    ShellSlider { theme: pane.theme; label: "Blur Size"; value: root.decoBlurSize; minValue: 1; maxValue: 30; step: 1; enabled: root.decoBlurEnabled; onChanged: function(v) { root.decoBlurSize = Math.round(v); root.queueDecoration("blur", "size", root.decoBlurSize) } }
                    ShellSlider { theme: pane.theme; label: "Passes"; value: root.decoBlurPasses; minValue: 1; maxValue: 5; step: 1; enabled: root.decoBlurEnabled; onChanged: function(v) { root.decoBlurPasses = Math.round(v); root.queueDecoration("blur", "passes", root.decoBlurPasses) } }
                    ShellSlider { theme: pane.theme; label: "Contrast"; value: root.decoBlurContrast; minValue: 0.5; maxValue: 2; step: 0.05; enabled: root.decoBlurEnabled; onChanged: function(v) { root.decoBlurContrast = v; root.queueDecoration("blur", "contrast", Number(v).toFixed(2)) } }
                    ShellSlider { theme: pane.theme; label: "Noise"; value: root.decoBlurNoise; minValue: 0; maxValue: 1; step: 0.01; enabled: root.decoBlurEnabled; onChanged: function(v) { root.decoBlurNoise = v; root.queueDecoration("blur", "noise", Number(v).toFixed(2)) } }
                    ShellSwitch { theme: pane.theme; label: "XRay"; checked: root.decoBlurXray; onChanged: function(v) { root.decoBlurXray = v; root.queueDecoration("blur", "xray", v ? "true" : "false") } }
                    ShellSwitch { theme: pane.theme; label: "Ignore Opacity"; checked: root.decoBlurIgnoreOpacity; onChanged: function(v) { root.decoBlurIgnoreOpacity = v; root.queueDecoration("blur", "ignore_opacity", v ? "true" : "false") } }
                }
            }
        }

        Component {
            id: shellSection
            Column {
                width: parent.width
                spacing: 14
                ShellCard { theme: pane.theme; title: "Borders"; onDirty: pane.dirty("shell")
                    ShellSwitch { theme: pane.theme; label: "Outer Border"; checked: pane.theme.outerBorder; onChanged: function(v) { pane.theme.outerBorder = v; pane.dirty("shell") } }
                    ShellSlider { theme: pane.theme; label: "Border Width"; value: pane.theme.borderWidth; minValue: 0.5; maxValue: 4; step: 0.5; enabled: pane.theme.outerBorder; onChanged: function(v) { pane.theme.borderWidth = v; pane.dirty("shell") } }
                    ShellSlider { theme: pane.theme; label: "Border Opacity"; value: pane.theme.borderOpacity; minValue: 0; maxValue: 1; step: 0.05; enabled: pane.theme.outerBorder; onChanged: function(v) { pane.theme.borderOpacity = v; pane.dirty("shell") } }
                    ShellSwitch { theme: pane.theme; label: "Gradient Border"; checked: pane.theme.gradientBorder; onChanged: function(v) { pane.theme.gradientBorder = v; pane.dirty("shell") } }
                    LivePreview { theme: pane.theme }
                }
                ShellCard { theme: pane.theme; title: "Corners"; onDirty: pane.dirty("shell")
                    ShellSlider { theme: pane.theme; label: "Panel Radius"; value: pane.theme.panelRadius; minValue: 0; maxValue: 32; step: 1; onChanged: function(v) { pane.theme.panelRadius = v; pane.dirty("shell") } }
                    ShellSlider { theme: pane.theme; label: "Item Radius"; value: pane.theme.itemRadius; minValue: 0; maxValue: 20; step: 1; onChanged: function(v) { pane.theme.itemRadius = v; pane.dirty("shell") } }
                    ShellSlider { theme: pane.theme; label: "Pill Radius"; value: pane.theme.pillRadius; minValue: 0; maxValue: 50; step: 1; onChanged: function(v) { pane.theme.pillRadius = v; pane.dirty("shell") } }
                    CornerPreview { theme: pane.theme }
                }
                ShellCard { theme: pane.theme; title: "Typography"; onDirty: pane.dirty("shell")
                    ShellTextInput { theme: pane.theme; label: "Font Family"; textValue: pane.theme.fontFamily; onChanged: function(v) { pane.theme.fontFamily = v; pane.dirty("shell") } }
                    ShellSwitch { theme: pane.theme; label: "Bold by Default"; checked: pane.theme.fontBold; onChanged: function(v) { pane.theme.fontBold = v; pane.dirty("shell") } }
                    ShellSlider { theme: pane.theme; label: "Font Scale"; value: pane.theme.fontScale; minValue: 0.8; maxValue: 1.4; step: 0.05; onChanged: function(v) { pane.theme.fontScale = v; pane.dirty("shell") } }
                    Text { text: "The quick brown fox"; color: pane.theme.foreground; font.family: pane.theme.fontFamily; font.pixelSize: 18 * pane.theme.fontScale; font.bold: pane.theme.fontBold }
                }
                ShellCard { theme: pane.theme; title: "Effects"; onDirty: pane.dirty("shell")
                    ShellSwitch { theme: pane.theme; label: "Enable Blur"; checked: pane.theme.enableBlur; onChanged: function(v) { pane.theme.enableBlur = v; pane.dirty("shell") } }
                    ShellSlider { theme: pane.theme; label: "Blur Strength"; value: pane.theme.blurStrength; minValue: 0; maxValue: 1; step: 0.05; enabled: pane.theme.enableBlur; onChanged: function(v) { pane.theme.blurStrength = v; pane.dirty("shell") } }
                    ShellSwitch { theme: pane.theme; label: "Enable Shadows"; checked: pane.theme.enableShadows; onChanged: function(v) { pane.theme.enableShadows = v; pane.dirty("shell") } }
                    ShellSlider { theme: pane.theme; label: "Shadow Opacity"; value: pane.theme.shadowOpacity; minValue: 0; maxValue: 0.6; step: 0.05; enabled: pane.theme.enableShadows; onChanged: function(v) { pane.theme.shadowOpacity = v; pane.dirty("shell") } }
                    ShellSwitch { theme: pane.theme; label: "Enable Glow"; checked: pane.theme.enableGlow; onChanged: function(v) { pane.theme.enableGlow = v; pane.dirty("shell") } }
                    ShellSwitch { theme: pane.theme; label: "Frosted Glass"; checked: pane.theme.frostedGlass; onChanged: function(v) { pane.theme.frostedGlass = v; pane.dirty("shell") } }
                    PerformanceChip { theme: pane.theme }
                }
                ShellCard { theme: pane.theme; title: "Panels"; onDirty: pane.dirty("shell")
                    ShellSlider { theme: pane.theme; label: "Panel Opacity"; value: pane.theme.panelOpacity; minValue: 0.7; maxValue: 1; step: 0.05; onChanged: function(v) { pane.theme.panelOpacity = v; pane.dirty("shell") } }
                    ShellSlider { theme: pane.theme; label: "Panel Padding"; value: pane.theme.panelPadding; minValue: 8; maxValue: 24; step: 1; onChanged: function(v) { pane.theme.panelPadding = v; pane.dirty("shell") } }
                    ShellSlider { theme: pane.theme; label: "Item Spacing"; value: pane.theme.itemSpacing; minValue: 4; maxValue: 16; step: 1; onChanged: function(v) { pane.theme.itemSpacing = v; pane.dirty("shell") } }
                    ShellSlider { theme: pane.theme; label: "Island Gap"; value: pane.theme.islandGap; minValue: 4; maxValue: 16; step: 1; onChanged: function(v) { pane.theme.islandGap = v; pane.dirty("shell") } }
                    LivePreview { theme: pane.theme }
                }
                ShellCard { theme: pane.theme; title: "Islands"; onDirty: pane.dirty("shell")
                    ShellSlider { theme: pane.theme; label: "Island Padding"; value: pane.theme.islandPadding; minValue: 8; maxValue: 20; step: 1; onChanged: function(v) { pane.theme.islandPadding = v; pane.dirty("shell") } }
                    ShellSwitch { theme: pane.theme; label: "Hover Lift"; checked: pane.theme.islandHoverLift; onChanged: function(v) { pane.theme.islandHoverLift = v; pane.dirty("shell") } }
                    ShellSwitch { theme: pane.theme; label: "Hover Glow"; checked: pane.theme.islandHoverGlow; onChanged: function(v) { pane.theme.islandHoverGlow = v; pane.dirty("shell") } }
                    ShellSlider { theme: pane.theme; label: "Hover Scale"; value: pane.theme.islandHoverScale; minValue: 1; maxValue: 1.15; step: 0.01; onChanged: function(v) { pane.theme.islandHoverScale = v; pane.dirty("shell") } }
                }
                ShellCard { theme: pane.theme; title: "Notifications"; onDirty: pane.dirty("shell")
                    SegmentedControl { theme: pane.theme; label: "Toast Position"; value: pane.theme.toastPosition; options: ["top-left", "top-right", "bottom-left", "bottom-right"]; onChanged: function(v) { pane.theme.toastPosition = v; pane.dirty("shell") } }
                    ShellSlider { theme: pane.theme; label: "Toast Duration"; value: pane.theme.toastDuration; minValue: 2000; maxValue: 10000; step: 500; onChanged: function(v) { pane.theme.toastDuration = v; pane.dirty("shell") } }
                    ShellSlider { theme: pane.theme; label: "Max Visible Toasts"; value: pane.theme.maxToasts; minValue: 1; maxValue: 5; step: 1; onChanged: function(v) { pane.theme.maxToasts = Math.round(v); pane.dirty("shell") } }
                    ShellSwitch { theme: pane.theme; label: "Stack Toasts"; checked: pane.theme.stackToasts; onChanged: function(v) { pane.theme.stackToasts = v; pane.dirty("shell") } }
                    ShellSwitch { theme: pane.theme; label: "Group Same App"; checked: pane.theme.groupSameApp; onChanged: function(v) { pane.theme.groupSameApp = v; pane.dirty("shell") } }
                    ShellSwitch { theme: pane.theme; label: "Show Critical in DND"; checked: pane.theme.showInDnd; onChanged: function(v) { pane.theme.showInDnd = v; pane.dirty("shell") } }
                }
                ShellCard { theme: pane.theme; title: "Animations"; onDirty: pane.dirty("shell")
                    ShellSwitch { theme: pane.theme; label: "Reduced Motion"; checked: pane.theme.reducedMotion; onChanged: function(v) { pane.theme.reducedMotion = v; pane.dirty("shell") } }
                    ShellSlider { theme: pane.theme; label: "Animation Speed"; value: pane.theme.animationSpeed; minValue: 0.5; maxValue: 2; step: 0.05; onChanged: function(v) { pane.theme.animationSpeed = v; pane.dirty("shell") } }
                    ShellSlider { theme: pane.theme; label: "Spring Strength"; value: pane.theme.springStrength; minValue: 2; maxValue: 8; step: 0.1; onChanged: function(v) { pane.theme.springStrength = v; pane.dirty("shell") } }
                    ShellSlider { theme: pane.theme; label: "Spring Damping"; value: pane.theme.springDamping; minValue: 0.5; maxValue: 0.9; step: 0.01; onChanged: function(v) { pane.theme.springDamping = v; pane.dirty("shell") } }
                    SpringPreview { theme: pane.theme }
                }
            }
        }
    }

    component KeyChip: Rectangle {
        id: chip
        property var theme
        property string textValue: ""
        property bool accent: false
        property bool lifted: false
        width: chipText.implicitWidth + 16
        height: 26
        radius: theme.pillRadius
        color: accent ? theme.color4 : theme.withAlpha(theme.color4, 0.14)
        border.width: theme.outerBorder ? theme.borderWidth : 0
        border.color: theme.withAlpha(theme.color4, accent ? 0.75 : 0.28)
        scale: lifted ? 1.05 : 1
        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 240; spring: theme.springStrength + 1; damping: theme.springDamping; mass: 0.8; epsilon: 0.001 } }
        Behavior on color { ColorAnimation { duration: theme.motionDuration(140); easing.type: Easing.OutCubic } }
        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.textValue
            color: chip.accent ? chip.theme.color0 : chip.theme.foreground
            font.family: chip.theme.fontFamily
            font.pixelSize: 10 * chip.theme.fontScale
            font.bold: true
        }
    }

    component KeybindActionButton: Rectangle {
        id: actionButton
        property var theme
        property string label: ""
        property bool accent: false
        signal clicked()
        width: 86
        height: 34
        radius: theme.pillRadius
        color: accent ? (actionArea.containsMouse ? theme.withAlpha(theme.color4, 0.86) : theme.color4)
            : (actionArea.containsMouse ? theme.withAlpha(theme.color1, 0.44) : theme.withAlpha(theme.color1, 0.32))
        border.width: theme.outerBorder ? theme.borderWidth : 0
        border.color: accent ? theme.withAlpha(theme.color4, actionArea.containsMouse ? 0.85 : 0.55) : theme.withAlpha(theme.color1, actionArea.containsMouse ? 0.65 : 0.42)
        scale: actionArea.pressed ? 0.94 : (actionArea.containsMouse ? 1.05 : 1)
        Behavior on color { ColorAnimation { duration: theme.motionDuration(150); easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: theme.motionDuration(150); easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 260; spring: theme.springStrength + 1.5; damping: theme.springDamping; mass: 0.75; epsilon: 0.001 } }
        Text {
            anchors.centerIn: parent
            text: actionButton.label
            color: actionButton.accent ? actionButton.theme.color0 : actionButton.theme.foreground
            font.pixelSize: 12 * actionButton.theme.fontScale
            font.bold: true
        }
        MouseArea {
            id: actionArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: actionButton.clicked()
        }
    }

    component CategoryPicker: Column {
        id: picker
        property var theme
        width: parent ? parent.width : 440
        spacing: 8
        Text {
            text: "Existing Categories"
            color: picker.theme.color6
            font.pixelSize: 11 * picker.theme.fontScale
            font.bold: true
        }
        Flow {
            width: parent.width
            spacing: 8
            Repeater {
                model: root.keybindCategoryNames()
                Rectangle {
                    id: categoryChip
                    property bool selected: root.normalizedCategory(root.keybindAddCategory) === modelData
                    width: categoryText.implicitWidth + 20
                    height: 30
                    radius: picker.theme.pillRadius
                    color: selected ? picker.theme.color4 : (categoryArea.containsMouse ? picker.theme.withAlpha(picker.theme.color4, 0.22) : picker.theme.withAlpha(picker.theme.color1, 0.20))
                    border.width: picker.theme.outerBorder ? picker.theme.borderWidth : 0
                    border.color: picker.theme.withAlpha(picker.theme.color4, selected ? 0.85 : (categoryArea.containsMouse ? 0.55 : 0.24))
                    scale: categoryArea.pressed ? 0.94 : (categoryArea.containsMouse ? 1.06 : 1)
                    Behavior on color { ColorAnimation { duration: picker.theme.motionDuration(150); easing.type: Easing.OutCubic } }
                    Behavior on border.color { ColorAnimation { duration: picker.theme.motionDuration(150); easing.type: Easing.OutCubic } }
                    Behavior on scale { SpringAnimation { duration: picker.theme && picker.theme.reducedMotion ? 0 : 260; spring: picker.theme.springStrength + 1; damping: picker.theme.springDamping; mass: 0.75; epsilon: 0.001 } }
                    Text {
                        id: categoryText
                        anchors.centerIn: parent
                        text: modelData
                        color: categoryChip.selected ? picker.theme.color0 : picker.theme.foreground
                        font.pixelSize: 11 * picker.theme.fontScale
                        font.bold: true
                    }
                    MouseArea {
                        id: categoryArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.keybindAddCategory = modelData
                    }
                }
            }
        }
    }

    component ThemeSwatch: Rectangle {
        id: swatch
        property var theme
        property string colorName: ""
        property string colorValue: ""
        width: 68
        height: 64
        radius: theme.itemRadius
        color: theme.withAlpha(theme.color1, swatchArea.containsMouse ? 0.24 : 0.14)
        border.width: theme.outerBorder ? theme.borderWidth : 0
        border.color: theme.withAlpha(theme.color4, swatchArea.containsMouse ? 0.52 : 0.18)
        scale: swatchArea.containsMouse ? 1.05 : 1

        Behavior on color { ColorAnimation { duration: theme.motionDuration(140); easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: theme.motionDuration(140); easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 260; spring: theme.springStrength + 1; damping: theme.springDamping; mass: 0.8; epsilon: 0.001 } }

        Rectangle {
            width: 38
            height: 38
            radius: 12
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 8
            color: swatch.colorValue
            border.width: swatch.theme.outerBorder ? swatch.theme.borderWidth : 0
            border.color: swatch.theme.withAlpha(swatch.theme.foreground, 0.18)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 7
            text: swatchArea.containsMouse ? swatch.colorValue : swatch.colorName
            color: swatch.theme.foreground
            font.pixelSize: 9 * swatch.theme.fontScale
            font.bold: true
            elide: Text.ElideRight
            width: parent.width - 8
            horizontalAlignment: Text.AlignHCenter
        }

        MouseArea {
            id: swatchArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
    }

    component WallpaperTile: Rectangle {
        id: tile
        property var theme
        property var item
        property bool active: root.activeWallpaperPath === item.path
        width: Math.floor((parent ? parent.width : 430) / 3) - 8
        height: 88
        radius: theme.itemRadius
        color: theme.withAlpha(theme.color1, 0.14)
        border.width: active ? 2 : (theme.outerBorder ? theme.borderWidth : 0)
        border.color: active ? theme.color4 : theme.withAlpha(theme.color1, theme.borderOpacity)
        scale: tileArea.pressed ? 0.97 : (tileArea.containsMouse ? 1.035 : 1)
        clip: true

        Behavior on border.color { ColorAnimation { duration: theme.motionDuration(150); easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 260; spring: theme.springStrength + 1; damping: theme.springDamping; mass: 0.8; epsilon: 0.001 } }

        Image {
            anchors.fill: parent
            source: "file://" + tile.item.path
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: tileArea.containsMouse ? 0.92 : 0.78
            Behavior on opacity { NumberAnimation { duration: tile.theme.motionDuration(140); easing.type: Easing.OutCubic } }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 30
            color: tile.theme.withAlpha(tile.theme.color0, 0.70)
            Text {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                text: tile.item.name
                color: tile.theme.foreground
                font.pixelSize: 10 * tile.theme.fontScale
                font.bold: true
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }

        MouseArea {
            id: tileArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.applyWallpaper(tile.item.path)
        }
    }

    component ThemePresetRow: Rectangle {
        id: presetRow
        property var theme
        property var item
        width: parent ? parent.width : 440
        height: 44
        radius: theme.itemRadius
        color: presetArea.containsMouse ? theme.withAlpha(theme.color4, 0.08) : theme.withAlpha(theme.color0, 0.42)
        border.width: theme.outerBorder ? theme.borderWidth : 0
        border.color: theme.withAlpha(theme.color4, presetArea.containsMouse ? 0.34 : 0.14)
        scale: presetArea.pressed ? 0.99 : (presetArea.containsMouse ? 1.008 : 1)

        Behavior on color { ColorAnimation { duration: theme.motionDuration(150); easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: theme.motionDuration(150); easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 260; spring: theme.springStrength + 1; damping: theme.springDamping; mass: 0.85; epsilon: 0.001 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: presetRow.item.name
                color: presetRow.theme.foreground
                font.pixelSize: 12 * presetRow.theme.fontScale
                font.bold: presetRow.theme.fontBold
                elide: Text.ElideRight
                Layout.alignment: Qt.AlignVCenter
            }

            KeybindActionButton { theme: presetRow.theme; label: "Load"; accent: true; onClicked: root.loadThemePreset(presetRow.item.path) }
            KeybindActionButton { theme: presetRow.theme; label: "Delete"; onClicked: root.deleteThemePreset(presetRow.item.path) }
        }

        MouseArea {
            id: presetArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
    }

    component VariableRow: Rectangle {
        id: variableRow
        property var theme
        property var item
        property string editValue: item.value
        width: parent ? parent.width : 440
        height: 54
        radius: theme.itemRadius
        color: variableArea.containsMouse ? theme.withAlpha(theme.color4, 0.08) : theme.withAlpha(theme.color0, 0.42)
        border.width: theme.outerBorder ? theme.borderWidth : 0
        border.color: theme.withAlpha(theme.color4, variableArea.containsMouse ? 0.34 : 0.14)
        scale: variableArea.pressed ? 0.99 : (variableArea.containsMouse ? 1.006 : 1)

        Behavior on color { ColorAnimation { duration: theme.motionDuration(150); easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: theme.motionDuration(150); easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 260; spring: theme.springStrength + 1; damping: theme.springDamping; mass: 0.85; epsilon: 0.001 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 10
            spacing: 10

            Column {
                Layout.preferredWidth: 128
                Layout.alignment: Qt.AlignVCenter
                spacing: 2
                Text {
                    text: "$" + variableRow.item.name
                    color: variableRow.theme.color4
                    font.family: "monospace"
                    font.pixelSize: 12 * variableRow.theme.fontScale
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width
                }
                Text {
                    text: variableRow.item.category
                    color: variableRow.theme.color6
                    font.pixelSize: 9 * variableRow.theme.fontScale
                    font.bold: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: variableRow.theme.pillRadius
                color: valueField.activeFocus ? variableRow.theme.withAlpha(variableRow.theme.color4, 0.14) : variableRow.theme.withAlpha(variableRow.theme.color1, 0.16)
                border.width: variableRow.theme.outerBorder ? variableRow.theme.borderWidth : 0
                border.color: variableRow.theme.withAlpha(variableRow.theme.color4, valueField.activeFocus ? 0.58 : 0.18)
                TextInput {
                    id: valueField
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    text: variableRow.editValue
                    color: variableRow.theme.foreground
                    verticalAlignment: TextInput.AlignVCenter
                    onTextChanged: {
                        variableRow.editValue = text
                        root.queueVariableEdit(variableRow.item, text)
                    }
                }
            }
        }

        MouseArea {
            id: variableArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
    }

    component EnvRow: Rectangle {
        id: envRow
        property var theme
        property var item
        property string editValue: item.value
        width: parent ? parent.width : 440
        height: 54
        radius: theme.itemRadius
        color: envArea.containsMouse ? theme.withAlpha(theme.color4, 0.08) : theme.withAlpha(theme.color0, 0.42)
        border.width: theme.outerBorder ? theme.borderWidth : 0
        border.color: theme.withAlpha(theme.color4, envArea.containsMouse ? 0.34 : 0.14)
        scale: envArea.pressed ? 0.99 : (envArea.containsMouse ? 1.006 : 1)

        Behavior on color { ColorAnimation { duration: theme.motionDuration(150); easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: theme.motionDuration(150); easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 260; spring: theme.springStrength + 1; damping: theme.springDamping; mass: 0.85; epsilon: 0.001 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            spacing: 10

            Text {
                Layout.preferredWidth: 156
                text: envRow.item.key
                color: envRow.theme.color4
                font.family: "monospace"
                font.pixelSize: 12 * envRow.theme.fontScale
                font.bold: true
                elide: Text.ElideRight
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: envRow.theme.pillRadius
                color: envValueField.activeFocus ? envRow.theme.withAlpha(envRow.theme.color4, 0.14) : envRow.theme.withAlpha(envRow.theme.color1, 0.16)
                border.width: envRow.theme.outerBorder ? envRow.theme.borderWidth : 0
                border.color: envRow.theme.withAlpha(envRow.theme.color4, envValueField.activeFocus ? 0.58 : 0.18)
                TextInput {
                    id: envValueField
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    text: envRow.editValue
                    color: envRow.theme.foreground
                    verticalAlignment: TextInput.AlignVCenter
                    onTextChanged: {
                        envRow.editValue = text
                        root.queueEnvEdit(envRow.item, text)
                    }
                }
            }

            KeybindActionButton { theme: envRow.theme; label: "Delete"; onClicked: root.deleteEnvironment(envRow.item) }
        }

        MouseArea {
            id: envArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
    }

    component EnvQuickRow: Row {
        id: quickEnv
        property var theme
        property string keyName: ""
        property string fallbackValue: ""
        width: parent ? parent.width : 440
        height: 38
        spacing: 8

        function findItem() {
            for (let i = 0; i < root.envItems.length; i++) {
                if (root.envItems[i].key === quickEnv.keyName)
                    return root.envItems[i]
            }
            return null
        }

        Text {
            width: 190
            text: quickEnv.keyName
            color: quickEnv.theme.color4
            font.family: "monospace"
            font.pixelSize: 12 * quickEnv.theme.fontScale
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
        }

        KeybindActionButton {
            theme: quickEnv.theme
            label: "Set"
            accent: true
            onClicked: {
                const item = quickEnv.findItem()
                if (item)
                    root.queueEnvEdit(item, quickEnv.fallbackValue)
                else {
                    root.envAddKey = quickEnv.keyName
                    root.envAddValue = quickEnv.fallbackValue
                    root.addEnvironment()
                }
            }
        }

        Text {
            width: parent.width - 284
            text: quickEnv.fallbackValue
            color: quickEnv.theme.color6
            font.pixelSize: 11 * quickEnv.theme.fontScale
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
        }
    }

    component KeyRecorder: Rectangle {
        id: recorder
        property var theme
        property bool addMode: false
        width: parent ? parent.width : 440
        height: 38
        radius: theme.pillRadius
        color: root.keybindRecording ? theme.withAlpha(theme.color4, 0.24)
            : (recorderArea.containsMouse ? theme.withAlpha(theme.color4, 0.14) : theme.withAlpha(theme.color1, 0.18))
        border.width: theme.outerBorder ? theme.borderWidth : 0
        border.color: theme.withAlpha(theme.color4, root.keybindRecording ? 0.75 : (recorderArea.containsMouse ? 0.46 : 0.22))
        scale: recorderArea.pressed ? 0.98 : (recorderArea.containsMouse ? 1.01 : 1)
        focus: root.keybindRecording

        Behavior on color { ColorAnimation { duration: theme.motionDuration(140) } }
        Behavior on border.color { ColorAnimation { duration: theme.motionDuration(140); easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 260; spring: theme.springStrength + 1; damping: theme.springDamping; mass: 0.8; epsilon: 0.001 } }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10

            Text {
                text: "󰌌"
                color: recorder.theme.color4
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                width: parent.width - 94
                text: root.keybindRecording ? "Press new keybind" : "Record keybind"
                color: recorder.theme.foreground
                font.family: recorder.theme.fontFamily
                font.pixelSize: 12 * recorder.theme.fontScale
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
            }

            Text {
                text: root.keybindRecording ? "Listening" : "Start"
                color: recorder.theme.color6
                font.family: recorder.theme.fontFamily
                font.pixelSize: 11 * recorder.theme.fontScale
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: recorderArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.keybindRecording = true
                recorder.forceActiveFocus()
            }
        }

        Keys.onPressed: function(event) {
            if (!root.keybindRecording)
                return
            if (event.key === Qt.Key_Escape) {
                root.keybindRecording = false
                event.accepted = true
                return
            }
            const keyName = root.qtKeyToHypr(event.key, event.text)
            if (keyName.length === 0)
                return
            if (recorder.addMode) {
                root.keybindAddMods = root.qtModsToHypr(event.modifiers)
                root.keybindAddKey = keyName
            } else {
                root.keybindEditMods = root.qtModsToHypr(event.modifiers)
                root.keybindEditKey = keyName
            }
            root.keybindRecording = false
            event.accepted = true
        }
    }

    component KeybindRow: Rectangle {
        id: keyRow
        property var theme
        property var item
        property bool editing: root.keybindEditLine === item.lineNo
        property real baseScale: 0.98
        width: parent ? parent.width : 440
        height: editing ? rowColumn.implicitHeight + 20 : 58
        radius: theme.itemRadius
        color: editing ? theme.withAlpha(theme.color4, 0.12)
            : (summaryArea.containsMouse ? theme.withAlpha(theme.color4, 0.08) : theme.withAlpha(theme.color0, 0.42))
        border.width: theme.outerBorder ? theme.borderWidth : 0
        border.color: theme.withAlpha(theme.color4, editing ? 0.58 : (summaryArea.containsMouse ? 0.36 : 0.16))
        opacity: 0
        scale: baseScale * (summaryArea.pressed ? 0.985 : (summaryArea.containsMouse ? 1.01 : 1))
        clip: true

        Behavior on height { NumberAnimation { duration: theme.motionDuration(180); easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: theme.motionDuration(140) } }
        Behavior on border.color { ColorAnimation { duration: theme.motionDuration(140); easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 260; spring: theme.springStrength + 1; damping: theme.springDamping; mass: 0.8; epsilon: 0.001 } }

        Component.onCompleted: rowEnter.restart()

        ParallelAnimation {
            id: rowEnter
            NumberAnimation { target: keyRow; property: "opacity"; to: 1; duration: keyRow.theme.motionDuration(220); easing.type: Easing.OutCubic }
            NumberAnimation { target: keyRow; property: "baseScale"; to: 1; duration: keyRow.theme.motionDuration(220); easing.type: Easing.OutCubic }
        }

        Column {
            id: rowColumn
            width: parent.width - 20
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 10
            spacing: 10

            RowLayout {
                id: summaryRow
                width: parent.width
                height: 38
                spacing: 10

                Row {
                    Layout.preferredWidth: 170
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 5
                    Repeater {
                        model: root.keybindModChips(keyRow.item.mods)
                        KeyChip { theme: keyRow.theme; textValue: modelData; lifted: summaryArea.containsMouse }
                    }
                    KeyChip { theme: keyRow.theme; textValue: keyRow.item.key; accent: true; lifted: summaryArea.containsMouse }
                }

                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2
                    Text {
                        width: parent.width
                        text: keyRow.item.dispatcher + (keyRow.item.command.length > 0 ? "  " + keyRow.item.command : "")
                        color: keyRow.theme.foreground
                        font.family: keyRow.theme.fontFamily
                        font.pixelSize: 12 * keyRow.theme.fontScale
                        font.bold: keyRow.theme.fontBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: keyRow.item.type + "  line " + keyRow.item.lineNo
                        color: keyRow.theme.color6
                        font.family: keyRow.theme.fontFamily
                        font.pixelSize: 10 * keyRow.theme.fontScale
                        elide: Text.ElideRight
                    }
                }

                Text {
                    text: keyRow.editing ? "󰏫" : "󰏌"
                    color: keyRow.theme.color4
                    font.pixelSize: 16
                    rotation: keyRow.editing ? 90 : (summaryArea.containsMouse ? 8 : 0)
                    Layout.alignment: Qt.AlignVCenter
                    Behavior on rotation { SpringAnimation { duration: keyRow.theme && keyRow.theme.reducedMotion ? 0 : 280; spring: keyRow.theme.springStrength + 1; damping: keyRow.theme.springDamping; mass: 0.8; epsilon: 0.001 } }
                }

                MouseArea {
                    id: summaryArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.startKeybindEdit(keyRow.item)
                }
            }

            Column {
                width: parent.width
                height: keyRow.editing ? implicitHeight : 0
                opacity: keyRow.editing ? 1 : 0
                y: keyRow.editing ? 0 : -8
                clip: true
                spacing: 8
                Behavior on opacity { NumberAnimation { duration: keyRow.theme.motionDuration(140); easing.type: Easing.OutCubic } }
                Behavior on y { SpringAnimation { duration: keyRow.theme && keyRow.theme.reducedMotion ? 0 : 260; spring: keyRow.theme.springStrength; damping: keyRow.theme.springDamping; mass: 0.9; epsilon: 0.001 } }

                ShellTextInput { theme: keyRow.theme; label: "Modifiers"; textValue: root.keybindEditMods; onChanged: function(v) { root.keybindEditMods = v } }
                ShellTextInput { theme: keyRow.theme; label: "Key"; textValue: root.keybindEditKey; onChanged: function(v) { root.keybindEditKey = v } }
                KeyRecorder { theme: keyRow.theme }
                ShellTextInput { theme: keyRow.theme; label: "Action"; textValue: root.keybindEditDispatcher; onChanged: function(v) { root.keybindEditDispatcher = v } }
                ShellTextInput { theme: keyRow.theme; label: "Command"; textValue: root.keybindEditCommand; onChanged: function(v) { root.keybindEditCommand = v } }

                Row {
                    width: parent.width
                    height: 36
                    spacing: 8
                    layoutDirection: Qt.RightToLeft

                    KeybindActionButton { theme: keyRow.theme; label: "Save"; accent: true; onClicked: root.saveKeybindEdit() }
                    KeybindActionButton { theme: keyRow.theme; label: "Cancel"; onClicked: root.cancelKeybindEdit() }
                }
            }
        }
    }

    component ShellCard: Rectangle {
        id: card
        property var theme
        property string title: ""
        property bool animateEntrance: true
        property real enterScale: 0.985
        default property alias body: bodyColumn.data
        signal dirty()
        width: parent ? parent.width : 440
        height: bodyColumn.implicitHeight + 36
        radius: theme.panelRadius
        color: cardHover.containsMouse ? theme.withAlpha(theme.color4, 0.075) : theme.withAlpha(theme.color1, 0.16)
        border.width: theme.outerBorder ? theme.borderWidth : 0
        border.color: cardHover.containsMouse ? theme.withAlpha(theme.color4, 0.28) : theme.withAlpha(theme.color1, theme.outerBorder ? theme.borderOpacity : 0.20)
        opacity: animateEntrance ? 0 : 1
        scale: (animateEntrance ? enterScale : 1) * (cardHover.containsMouse ? 1.006 : 1)

        Behavior on height { NumberAnimation { duration: theme.motionDuration(180); easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: theme.motionDuration(180); easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: theme.motionDuration(180); easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 320; spring: theme.springStrength; damping: theme.springDamping; mass: 0.9; epsilon: 0.001 } }

        Component.onCompleted: {
            if (animateEntrance)
                cardEnter.restart()
        }

        ParallelAnimation {
            id: cardEnter
            NumberAnimation { target: card; property: "opacity"; to: 1; duration: card.theme.motionDuration(240); easing.type: Easing.OutCubic }
            NumberAnimation { target: card; property: "enterScale"; to: 1; duration: card.theme.motionDuration(260); easing.type: Easing.OutCubic }
        }

        MouseArea {
            id: cardHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        Column {
            id: bodyColumn
            anchors.fill: parent
            anchors.margins: 14
            spacing: theme.itemSpacing
            Text { text: card.title; color: card.theme.foreground; font.family: card.theme.fontFamily; font.pixelSize: 15 * card.theme.fontScale; font.bold: true }
        }
    }

    component PlaceholderCard: Rectangle {
        property var theme
        property string title: ""
        property string text: ""
        width: parent ? parent.width : 440
        height: 120
        radius: theme.panelRadius
        color: theme.withAlpha(theme.color1, 0.14)
        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8
            Text { text: title; color: theme.foreground; font.pixelSize: 15; font.bold: true }
            Text { width: parent.width; text: parent.parent.text; color: theme.color6; font.pixelSize: 12; wrapMode: Text.WordWrap }
        }
    }

    component ShellSwitch: Item {
        id: switchRow
        property var theme
        property string label: ""
        property bool checked: false
        signal changed(bool value)
        width: parent.width
        height: 46
        scale: switchArea.pressed ? 0.985 : (switchArea.containsMouse ? 1.006 : 1)

        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 260; spring: theme.springStrength + 1; damping: theme.springDamping; mass: 0.85; epsilon: 0.001 } }

        Rectangle {
            anchors.fill: parent
            radius: theme.controlRadius
            color: switchArea.containsMouse ? theme.withAlpha(theme.color4, 0.065) : theme.withAlpha(theme.foreground, 0.028)
            Behavior on color { ColorAnimation { duration: theme.motionDuration(150); easing.type: Easing.OutCubic } }
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 10
            spacing: 12
            Rectangle {
                width: switchRow.checked ? 7 : 3
                height: 24
                radius: 2
                color: switchRow.checked ? switchRow.theme.color4 : switchRow.theme.withAlpha(switchRow.theme.foreground, 0.24)
                anchors.verticalCenter: parent.verticalCenter
                Behavior on width { SpringAnimation { duration: switchRow.theme.reducedMotion ? 0 : 240; spring: 5.0; damping: 0.84; mass: 0.8; epsilon: 0.001 } }
                Behavior on color { ColorAnimation { duration: switchRow.theme.motionDuration(150); easing.type: Easing.OutCubic } }
            }
            Text {
                width: parent.width - 92
                text: switchRow.label
                color: switchRow.theme.foreground
                font.pixelSize: 13 * switchRow.theme.fontScale
                font.bold: switchRow.checked
                anchors.verticalCenter: parent.verticalCenter
                x: switchArea.containsMouse ? 3 : 0
                Behavior on x { SpringAnimation { duration: switchRow.theme && switchRow.theme.reducedMotion ? 0 : 240; spring: switchRow.theme.springStrength + 1; damping: switchRow.theme.springDamping; mass: 0.8; epsilon: 0.001 } }
            }
            M3Switch {
                theme: switchRow.theme
                checked: switchRow.checked
                anchors.verticalCenter: parent.verticalCenter
                onToggled: switchRow.changed(checked)
            }
        }

        MouseArea {
            id: switchArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: switchRow.changed(!switchRow.checked)
        }
    }

    component ShellTextInput: Item {
        id: shellInput
        property var theme
        property string label: ""
        property string textValue: ""
        property real labelWidth: 130
        signal changed(string value)
        width: parent.width
        height: 54
        Text {
            id: inputLabel
            anchors.left: parent.left
            anchors.top: parent.top
            width: shellInput.width
            text: label
            color: theme.withAlpha(theme.foreground, 0.48)
            font.pixelSize: 9 * theme.fontScale
            font.bold: true
            font.capitalization: Font.AllUppercase
        }
        Rectangle {
            id: inputFrame
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 34
            radius: theme.controlRadius
            color: field.activeFocus ? theme.withAlpha(theme.color4, 0.12) : (inputHover.hovered ? theme.withAlpha(theme.color4, 0.065) : theme.withAlpha(theme.foreground, 0.035))
            border.width: theme.outerBorder ? theme.borderWidth : 0
            border.color: theme.withAlpha(theme.color4, field.activeFocus ? 0.65 : (inputHover.hovered ? 0.38 : 0.16))
            scale: field.activeFocus ? 1.01 : 1
            Behavior on color { ColorAnimation { duration: theme.motionDuration(150); easing.type: Easing.OutCubic } }
            Behavior on border.color { ColorAnimation { duration: theme.motionDuration(150); easing.type: Easing.OutCubic } }
            Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 260; spring: theme.springStrength + 1; damping: theme.springDamping; mass: 0.85; epsilon: 0.001 } }
            TextInput {
                id: field
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                text: shellInput.textValue
                color: shellInput.theme.foreground
                verticalAlignment: TextInput.AlignVCenter
                onTextChanged: shellInput.changed(text)
            }
            HoverHandler { id: inputHover }
        }
    }

    component ShellSlider: Item {
        id: slider
        property var theme
        property string label: ""
        property real value: 0
        property real minValue: 0
        property real maxValue: 100
        property real step: 1
        property real progress: Math.max(0, Math.min(1, (value - minValue) / Math.max(0.001, maxValue - minValue)))
        signal changed(real value)
        width: parent.width
        height: 62
        opacity: enabled ? 1 : 0.38
        scale: sliderArea.pressed ? 0.995 : (sliderArea.containsMouse ? 1.006 : 1)

        Behavior on opacity { NumberAnimation { duration: theme.motionDuration(180); easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 260; spring: theme.springStrength + 1; damping: theme.springDamping; mass: 0.85; epsilon: 0.001 } }

        Text {
            text: slider.label.toUpperCase()
            color: slider.theme.withAlpha(slider.theme.foreground, 0.48)
            font.pixelSize: 9 * slider.theme.fontScale
            font.bold: true
            font.capitalization: Font.AllUppercase
        }
        Text {
            anchors.right: parent.right
            y: -2
            text: slider.value.toFixed(slider.step < 1 ? 2 : 0)
            color: slider.theme.foreground
            font.pixelSize: 20 * slider.theme.fontScale
            font.bold: true
        }
        Rectangle {
            id: track
            width: parent.width
            height: sliderArea.pressed ? 11 : 7
            y: 42
            radius: 4
            color: slider.theme.withAlpha(slider.theme.foreground, 0.070)
            Behavior on color { ColorAnimation { duration: slider.theme.motionDuration(150); easing.type: Easing.OutCubic } }
            Behavior on height { SpringAnimation { duration: slider.theme.reducedMotion ? 0 : 240; spring: slider.theme.springStrength + 1; damping: slider.theme.springDamping; mass: 0.8; epsilon: 0.001 } }
            Rectangle {
                width: Math.max(parent.height, parent.width * slider.progress)
                height: parent.height
                radius: parent.radius
                color: slider.theme.withAlpha(slider.theme.color4, sliderArea.pressed ? 0.96 : 0.76)
                Behavior on width { SpringAnimation { duration: slider.theme && slider.theme.reducedMotion ? 0 : 260; spring: slider.theme.springStrength + 1; damping: slider.theme.springDamping; mass: 0.75; epsilon: 0.001 } }
                Behavior on color { ColorAnimation { duration: slider.theme.motionDuration(140); easing.type: Easing.OutCubic } }
            }
            Rectangle {
                width: 3
                height: sliderArea.pressed ? 22 : 14
                radius: 2
                x: Math.max(0, Math.min(parent.width - width, parent.width * slider.progress))
                anchors.verticalCenter: parent.verticalCenter
                color: slider.theme.foreground
                opacity: sliderArea.containsMouse || sliderArea.pressed ? 0.92 : 0
                Behavior on x { SpringAnimation { duration: slider.theme && slider.theme.reducedMotion ? 0 : 260; spring: slider.theme.springStrength + 1; damping: slider.theme.springDamping; mass: 0.75; epsilon: 0.001 } }
                Behavior on height { SpringAnimation { duration: slider.theme && slider.theme.reducedMotion ? 0 : 220; spring: slider.theme.springStrength + 2; damping: slider.theme.springDamping; mass: 0.65; epsilon: 0.001 } }
                Behavior on opacity { NumberAnimation { duration: slider.theme.motionDuration(120); easing.type: Easing.OutCubic } }
            }
            MouseArea {
                id: sliderArea
                anchors.fill: parent
                enabled: slider.enabled
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                function update(mouseX) {
                    const pct = Math.max(0, Math.min(1, mouseX / track.width))
                    const raw = slider.minValue + pct * (slider.maxValue - slider.minValue)
                    const snapped = Math.round(raw / slider.step) * slider.step
                    slider.value = Math.max(slider.minValue, Math.min(slider.maxValue, snapped))
                    slider.changed(slider.value)
                }
                onPressed: function(mouse) { update(mouse.x) }
                onPositionChanged: function(mouse) { if (pressed) update(mouse.x) }
            }
        }
    }

    component SegmentedControl: Column {
        id: segment
        property var theme
        property string label: ""
        property string value: ""
        property var options: []
        signal changed(string value)
        width: parent.width
        spacing: 8
        Text { text: label.toUpperCase(); color: theme.withAlpha(theme.foreground, 0.48); font.pixelSize: 9 * theme.fontScale; font.bold: true; font.capitalization: Font.AllUppercase }
        Row {
            spacing: 7
            Repeater {
                model: segment.options
                Rectangle {
                    id: segmentButton
                    property bool selected: modelData === segment.value
                    width: 102
                    height: 32
                    radius: segment.theme.controlRadius
                    color: selected ? segment.theme.withAlpha(segment.theme.color4, 0.18) : (segmentArea.containsMouse ? segment.theme.withAlpha(segment.theme.color4, 0.09) : segment.theme.withAlpha(segment.theme.foreground, 0.045))
                    border.width: segment.theme.outerBorder ? segment.theme.borderWidth : 0
                    border.color: segment.theme.withAlpha(segment.theme.color4, selected ? 0.75 : (segmentArea.containsMouse ? 0.42 : 0.16))
                    scale: segmentArea.pressed ? 0.96 : (segmentArea.containsMouse ? 1.018 : 1)
                    Behavior on color { ColorAnimation { duration: segment.theme.motionDuration(150); easing.type: Easing.OutCubic } }
                    Behavior on border.color { ColorAnimation { duration: segment.theme.motionDuration(150); easing.type: Easing.OutCubic } }
                    Behavior on scale { SpringAnimation { duration: segment.theme && segment.theme.reducedMotion ? 0 : 260; spring: segment.theme.springStrength + 1; damping: segment.theme.springDamping; mass: 0.8; epsilon: 0.001 } }
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: segmentButton.selected ? segment.theme.color4 : segment.theme.foreground
                        font.pixelSize: 10 * segment.theme.fontScale
                        font.bold: true
                    }
                    MouseArea {
                        id: segmentArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: segment.changed(modelData)
                    }
                }
            }
        }
    }

    component LivePreview: Rectangle {
        property var theme
        width: 130
        height: 84
        radius: theme.panelRadius
        color: theme.withAlpha(theme.color0, theme.panelOpacity)
        border.width: theme.outerBorder ? theme.borderWidth : 0
        border.color: theme.withAlpha(theme.color1, theme.outerBorder ? theme.borderOpacity : 0.35)
        Behavior on radius { NumberAnimation { duration: theme.motionDuration(160); easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: theme.motionDuration(160); easing.type: Easing.OutCubic } }
        Behavior on border.width { NumberAnimation { duration: theme.motionDuration(120); easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: theme.motionDuration(160); easing.type: Easing.OutCubic } }
        Row {
            anchors.centerIn: parent
            spacing: theme.itemSpacing
            Behavior on spacing { NumberAnimation { duration: theme.motionDuration(160); easing.type: Easing.OutCubic } }
            Rectangle {
                width: 28
                height: 28
                radius: theme.itemRadius
                color: theme.withAlpha(theme.color4, 0.25)
                Behavior on radius { NumberAnimation { duration: theme.motionDuration(160); easing.type: Easing.OutCubic } }
            }
            Rectangle {
                width: 58
                height: 28
                radius: theme.pillRadius
                color: theme.color4
                Behavior on radius { NumberAnimation { duration: theme.motionDuration(160); easing.type: Easing.OutCubic } }
            }
        }
    }

    component CornerPreview: Row {
        property var theme
        spacing: 12
        Rectangle {
            width: 78; height: 58; radius: theme.panelRadius; color: theme.withAlpha(theme.color4, 0.18); border.width: theme.outerBorder ? theme.borderWidth : 0; border.color: theme.color4
            Behavior on radius { NumberAnimation { duration: theme.motionDuration(170); easing.type: Easing.OutCubic } }
        }
        Rectangle {
            width: 58; height: 58; radius: theme.itemRadius; color: theme.withAlpha(theme.color4, 0.18); border.width: theme.outerBorder ? theme.borderWidth : 0; border.color: theme.color4
            Behavior on radius { NumberAnimation { duration: theme.motionDuration(170); easing.type: Easing.OutCubic } }
        }
        Rectangle {
            width: 88; height: 34; radius: theme.pillRadius; color: theme.color4; anchors.verticalCenter: parent.verticalCenter
            Behavior on radius { NumberAnimation { duration: theme.motionDuration(170); easing.type: Easing.OutCubic } }
        }
    }

    component DecorationPreview: Rectangle {
        property var theme
        width: 160
        height: 88
        radius: root.decoRounding
        color: theme.withAlpha(theme.color0, root.decoActiveOpacity)
        border.width: Math.max(1, root.decoBorderSize)
        border.color: theme.color4
        Behavior on radius { NumberAnimation { duration: theme.motionDuration(170); easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: theme.motionDuration(170); easing.type: Easing.OutCubic } }
        Behavior on border.width { NumberAnimation { duration: theme.motionDuration(140); easing.type: Easing.OutCubic } }
        Rectangle {
            width: 80
            height: 42
            radius: Math.max(0, root.decoRounding - 4)
            anchors.centerIn: parent
            color: theme.withAlpha(theme.color1, root.decoInactiveOpacity * 0.35)
            Behavior on radius { NumberAnimation { duration: theme.motionDuration(170); easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: theme.motionDuration(170); easing.type: Easing.OutCubic } }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            text: "gaps " + root.decoGapsIn + " / " + root.decoGapsOut
            color: theme.color6
            font.pixelSize: 10
            font.bold: true
        }
    }

    component BezierPreview: Rectangle {
        id: bezier
        property var theme
        property string preset: "Smooth"
        width: 240
        height: 120
        radius: theme.itemRadius
        color: theme.withAlpha(theme.color1, 0.12)
        scale: bezierHover.containsMouse ? 1.015 : 1
        Behavior on radius { NumberAnimation { duration: theme.motionDuration(160); easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: theme.motionDuration(160); easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 300; spring: theme.springStrength; damping: theme.springDamping; mass: 0.9; epsilon: 0.001 } }
        onPresetChanged: curve.requestPaint()

        MouseArea {
            id: bezierHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        Canvas {
            id: curve
            anchors.fill: parent
            anchors.margins: 14
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = bezier.theme.withAlpha(bezier.theme.foreground, 0.18)
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.moveTo(0, height)
                ctx.lineTo(width, height)
                ctx.lineTo(width, 0)
                ctx.stroke()
                ctx.strokeStyle = bezier.theme.color4
                ctx.lineWidth = 3
                ctx.beginPath()
                ctx.moveTo(0, height)
                const amp = bezier.preset === "Bouncy" ? 0.18 : (bezier.preset === "Snappy" ? -0.08 : 0)
                for (let i = 0; i <= 60; i++) {
                    const t = i / 60
                    let y = 1 - (bezier.preset === "Linear" ? t : (1 - Math.pow(1 - t, 3)))
                    if (bezier.preset === "Bouncy")
                        y -= Math.sin(t * Math.PI) * amp
                    if (bezier.preset === "Spring")
                        y += Math.sin(t * Math.PI * 5) * (1 - t) * 0.08
                    ctx.lineTo(t * width, Math.max(0, Math.min(1, y)) * height)
                }
                ctx.stroke()
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
        }

        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 10
            text: bezier.preset
            color: bezier.theme.color6
            font.pixelSize: 11
            font.bold: true
        }
    }

    component PerformanceChip: Rectangle {
        id: perfChip
        property var theme
        readonly property int cost: (theme.enableBlur ? 1 : 0) + (theme.enableShadows ? 1 : 0) + (theme.enableGlow ? 1 : 0)
        width: perfText.implicitWidth + 24
        height: 30
        radius: 15
        color: theme.withAlpha(cost >= 3 ? theme.color1 : theme.color4, 0.18)
        scale: perfHover.containsMouse ? 1.04 : 1
        Behavior on width { NumberAnimation { duration: theme.motionDuration(160); easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: theme.motionDuration(160); easing.type: Easing.OutCubic } }
        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 260; spring: theme.springStrength + 1; damping: theme.springDamping; mass: 0.8; epsilon: 0.001 } }
        Text { id: perfText; anchors.centerIn: parent; text: "GPU Load: " + (perfChip.cost >= 3 ? "High" : (perfChip.cost >= 1 ? "Medium" : "Low")); color: theme.foreground; font.pixelSize: 12; font.bold: true }
        MouseArea {
            id: perfHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
    }

    component SpringPreview: Rectangle {
        id: springBox
        property var theme
        width: 240
        height: 58
        radius: theme.itemRadius
        color: theme.withAlpha(theme.color1, 0.14)
        Behavior on radius { NumberAnimation { duration: theme.motionDuration(160); easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: theme.motionDuration(160); easing.type: Easing.OutCubic } }
        Rectangle {
            id: ball
            width: 20
            height: 20
            radius: 10
            y: 19
            x: targetX
            color: springBox.theme.color4
            property real targetX: 0
            Behavior on x { SpringAnimation { duration: springBox.theme && springBox.theme.reducedMotion ? 0 : 250; spring: springBox.theme.springStrength; damping: springBox.theme.springDamping; mass: 0.9; epsilon: 0.001 } }
        }
        Timer { interval: 1200; repeat: true; running: true; onTriggered: ball.targetX = ball.targetX === 0 ? 200 : 0 }
    }
}

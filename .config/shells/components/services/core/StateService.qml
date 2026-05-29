import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string path: Quickshell.env("HOME") + "/.cache/quickshell/state.json"
    property string configPath: Quickshell.env("HOME") + "/.config/shells/config.json"
    property var data: ({})
    property bool ready: false

    signal stateLoaded()

    property var _file: FileView {
        path: root.path
        preload: true
        blockLoading: true
        printErrors: false
        onLoaded: root.load(text())
        onLoadFailed: {
            root.data = ({})
            root.ready = true
            root.stateLoaded()
        }
    }

    property var _configFile: FileView {
        path: root.configPath
        preload: true
        blockLoading: true
        printErrors: false
    }

    function load(text) {
        try {
            const parsed = JSON.parse(text)
            data = parsed && typeof parsed === "object" ? parsed : ({})
        } catch (e) {
            data = ({})
        }
        ready = true
        stateLoaded()
    }

    function value(key, fallback) {
        if (data && data[key] !== undefined)
            return data[key]
        return fallback
    }

    function setValue(key, value) {
        const next = ({})
        for (const name in data)
            next[name] = data[name]
        next[key] = value
        data = next
        _file.setText(JSON.stringify(next, null, 2))
    }

    function loadFullConfig() {
        try {
            const parsed = JSON.parse(_configFile.text())
            return parsed && typeof parsed === "object" ? parsed : ({})
        } catch (e) {
            return ({})
        }
    }

    function writeConfig(config) {
        _configFile.setText(JSON.stringify(config, null, 2))
    }

    function saveShellConfig(theme) {
        const config = loadFullConfig()
        config.reducedMotion = theme.reducedMotion
        config.shell = {
            borders: {
                enabled: theme.outerBorder,
                width: theme.borderWidth,
                opacity: theme.borderOpacity,
                gradient: theme.gradientBorder
            },
            corners: {
                panelRadius: theme.panelRadius,
                itemRadius: theme.itemRadius,
                pillRadius: theme.pillRadius
            },
            typography: {
                fontFamily: theme.fontFamily,
                fontBold: theme.fontBold,
                fontScale: theme.fontScale
            },
            effects: {
                blur: theme.enableBlur,
                blurStrength: theme.blurStrength,
                shadows: theme.enableShadows,
                shadowOpacity: theme.shadowOpacity,
                glow: theme.enableGlow,
                frostedGlass: theme.frostedGlass
            },
            panels: {
                opacity: theme.panelOpacity,
                padding: theme.panelPadding,
                itemSpacing: theme.itemSpacing,
                islandGap: theme.islandGap
            },
            islands: {
                padding: theme.islandPadding,
                hoverLift: theme.islandHoverLift,
                hoverGlow: theme.islandHoverGlow,
                hoverScale: theme.islandHoverScale
            },
            notifications: {
                toastPosition: theme.toastPosition,
                toastDuration: theme.toastDuration,
                maxToasts: theme.maxToasts,
                stackToasts: theme.stackToasts,
                groupSameApp: theme.groupSameApp,
                showInDnd: theme.showInDnd
            },
            animations: {
                speed: theme.animationSpeed,
                springStrength: theme.springStrength,
                springDamping: theme.springDamping
            }
        }
        writeConfig(config)
    }
}

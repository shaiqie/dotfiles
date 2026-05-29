import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import ".." as Services

Item {
    id: root

    property var notifications: []
    property var historyNotifications: []
    property int historyCount: historyNotifications.length
    property var visibleNotifications: []
    property var toasts: []
    property var expandedApps: ({})
    property int count: notifications.length
    property bool dnd: false
    property bool centerOpen: false
    property var theme
    property var stateService
    property int toastPulseToken: 0
    property bool toastPulseCritical: false
    property bool autoClaimOwnership: true
    property bool serverOwnedByQuickshell: false
    property string notificationOwnerComm: ""
    property int ownershipClaimAttempts: 0
    property int localNotificationSeed: -1
    property var connectedNotificationIds: ({})
    property bool logNextSync: false

    signal centerChanged()

    onStateServiceChanged: loadState()
    Component.onCompleted: trackedSyncTimer.restart()

    onDndChanged: {
        if (stateService && stateService.ready)
            stateService.setValue("dnd", dnd)
    }

    NotificationServer {
        id: server

        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: true
        actionsSupported: true
        actionIconsSupported: true
        imageSupported: true

        onTrackedNotificationsChanged: trackedSyncTimer.restart()
    }

    Timer {
        id: trackedSyncTimer
        interval: 50
        repeat: false
        onTriggered: root.syncTrackedNotifications()
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.syncTrackedNotifications()
    }

    IpcHandler {
        id: notificationIpc
        target: "notifications"
        property string state: "{}"

        function sync() {
            root.syncTrackedNotifications()
            refresh()
        }

        function debug() {
            root.syncTrackedNotifications()
            refresh()
        }

        function refresh() {
            state = JSON.stringify({
                count: root.count,
                raw: root.notifications.length,
                history: root.historyNotifications.length,
                historyCount: root.historyCount,
                visible: root.visibleNotifications.length,
                toasts: root.toasts.length,
                tracked: server.trackedNotifications && server.trackedNotifications.values ? server.trackedNotifications.values.length : -1,
                latest: root.notifications.length > 0 ? root.notifications[0].summary : "",
                owner: root.notificationOwnerComm,
                ownedByQuickshell: root.serverOwnedByQuickshell
            })
        }
    }

    Process {
        id: ownerStatus
        command: ["busctl", "--user", "--no-pager", "status", "org.freedesktop.Notifications"]
        stdout: StdioCollector { id: ownerStatusOut; waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            if (code !== 0) {
                root.serverOwnedByQuickshell = false
                root.notificationOwnerComm = ""
                return
            }

            const text = String(ownerStatusOut.text || "")
            const match = /\nComm=([^\n]+)/.exec("\n" + text)
            const comm = match ? String(match[1]).trim() : ""
            root.notificationOwnerComm = comm
            root.serverOwnedByQuickshell = comm === "quickshell"
            if (!root.serverOwnedByQuickshell && root.autoClaimOwnership && root.ownershipClaimAttempts < 3) {
                root.ownershipClaimAttempts++
                claimOwner.exec(claimOwner.command)
            }
        }
    }

    Process {
        id: claimOwner
        command: ["sh", "-c", "pkill -x dunst; pkill -x mako; pkill -x swaync; pkill -x fnott; pkill -x xfce4-notifyd; pkill -x notification-daemon; pkill -x mate-notification-daemon"]
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: ownerStatus.exec(ownerStatus.command)
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!ownerStatus.running)
                ownerStatus.exec(ownerStatus.command)
        }
    }

    Connections {
        target: server

        function onNotification(notification) {
            notification.tracked = true
            root.importNotification(notification, true)
        }
    }

    Connections {
        target: server.trackedNotifications

        function onValuesChanged() {
            trackedSyncTimer.restart()
        }
    }

    function addNotification(appName, summary, body, actions) {
        const item = {
            id: localNotificationSeed--,
            ref: null,
            appName: appName || "App",
            appIcon: "",
            summary: summary || "",
            body: stripMarkup(body || ""),
            actions: actions || [],
            timestamp: Date.now(),
            dismissed: false,
            expanded: false,
            urgency: NotificationUrgency.Normal,
            critical: false,
            accent: accentFor(appName || "App")
        }

        const next = notifications.slice()
        next.unshift(item)
        notifications = next
        publishCenterItem(item)
        count = next.length
        visibleNotifications = next.filter(function(n) { return !n.dismissed })
        rebuildVisible()

        if (shouldShowToast(item))
            pushToast(item)
    }

    function importNotification(notification, allowToast) {
        const item = {
            id: notification.id,
            ref: notification,
            appName: notification.appName || "App",
            appIcon: notification.image || notification.appIcon || "",
            summary: notification.summary || "",
            body: stripMarkup(notification.body || ""),
            actions: notification.actions || [],
            timestamp: Date.now(),
            dismissed: false,
            expanded: false,
            urgency: notification.urgency,
            critical: notification.urgency === NotificationUrgency.Critical,
            accent: accentFor(notification.appName || "App")
        }

        const next = notifications.slice()
        const old = next.findIndex(function(n) { return n.id === item.id })
        if (old >= 0)
            next.splice(old, 1)
        next.unshift(item)
        notifications = next
        publishCenterItem(item)
        count = next.length
        visibleNotifications = next.filter(function(n) { return !n.dismissed })
        rebuildVisible()

        if (allowToast && shouldShowToast(item))
            pushToast(item)
    }

    function add(notification) {
        importNotification(notification, true)
    }

    function remove(id) {
        const next = notifications.filter(function(n) { return n.id !== id })
        notifications = next
        count = next.length
        rebuildVisible()
    }

    function dismiss(id) {
        const item = find(id)
        if (item && item.ref)
            item.ref.dismiss()
        historyNotifications = historyNotifications.filter(function(n) { return n.id !== id })
        historyCount = historyNotifications.length
        centerChanged()
        remove(id)
    }

    function clearAll() {
        const copy = notifications.slice()
        for (let i = 0; i < copy.length; i++) {
            if (copy[i].ref)
                copy[i].ref.dismiss()
        }
        notifications = []
        historyNotifications = []
        historyCount = 0
        centerChanged()
        toasts = []
        count = 0
        rebuildVisible()
    }

    function invoke(id, actionIndex) {
        const item = find(id)
        if (!item || !item.actions || !item.actions[actionIndex])
            return
        item.actions[actionIndex].invoke()
        removeToast(id)
    }

    function find(id) {
        for (let i = 0; i < notifications.length; i++) {
            if (notifications[i].id === id)
                return notifications[i]
        }
        return null
    }

    function pushToast(item) {
        const now = Date.now()
        const next = toasts.slice()
        const groupSame = theme ? theme.groupSameApp : true
        const maxVisible = Math.max(1, Math.round(theme ? theme.maxToasts : 3))
        const same = groupSame ? next.findIndex(function(t) { return t.appName === item.appName && now - t.updatedAt < 10000 }) : -1
        const replace = next.findIndex(function(t) { return t.id === item.id })

        const toast = {
            id: item.id,
            appName: item.appName,
            appIcon: item.appIcon,
            summary: item.summary,
            body: item.body,
            actions: item.actions,
            timestamp: item.timestamp,
            updatedAt: now,
            groupCount: 1,
            timeout: item.critical ? Math.max(10000, theme ? theme.toastDuration : 5000) : (theme ? theme.toastDuration : 5000),
            critical: item.critical,
            accent: item.critical ? "#ff5f57" : item.accent,
            pulse: toastPulseToken + 1
        }

        if (replace >= 0) {
            toast.groupCount = next[replace].groupCount
            next.splice(replace, 1)
            next.unshift(toast)
        } else if (same >= 0) {
            toast.groupCount = next[same].groupCount + 1
            next.splice(same, 1)
            next.unshift(toast)
        } else {
            if (next.length >= maxVisible)
                next.pop()
            next.unshift(toast)
        }

        toastPulseCritical = item.critical
        toasts = next
        toastPulseToken++
        playNotificationSound()
    }

    function shouldShowToast(item) {
        if (centerOpen)
            return false
        if (!dnd)
            return true
        return item && item.critical && theme && theme.showInDnd
    }

    function removeToast(id) {
        toasts = toasts.filter(function(t) { return t.id !== id })
    }

    function playNotificationSound() {
        const path = Services.Config.notificationSoundPath
        Quickshell.execDetached([
            "sh",
            "-c",
            "if command -v pw-play >/dev/null 2>&1; then pw-play \"$1\"; elif command -v paplay >/dev/null 2>&1; then paplay \"$1\"; elif command -v mpv >/dev/null 2>&1; then mpv --no-terminal --really-quiet \"$1\"; fi",
            "notification-sound",
            path
        ])
    }

    function toggleGroup(appName) {
        const next = ({})
        for (const key in expandedApps)
            next[key] = expandedApps[key]
        next[appName] = !next[appName]
        expandedApps = next
        rebuildVisible()
    }

    function rebuildVisible() {
        const groups = ({})
        const order = []
        for (let i = 0; i < notifications.length; i++) {
            const key = notifications[i].appName
            if (!groups[key]) {
                groups[key] = []
                order.push(key)
            }
            groups[key].push(notifications[i])
        }

        const out = []
        for (let j = 0; j < order.length; j++) {
            const app = order[j]
            const group = groups[app]
            const expanded = expandedApps[app] === true
            if (group.length > 1 && !expanded) {
                const top = cloneNotification(group[0])
                top.moreCount = group.length - 1
                top.groupKey = app
                out.push(top)
            } else {
                for (let k = 0; k < group.length; k++) {
                    const item = cloneNotification(group[k])
                    item.moreCount = 0
                    item.groupKey = app
                    item.groupIndex = k
                    out.push(item)
                }
            }
        }
        visibleNotifications = out
    }

    function mergeHistory(item) {
        const next = historyNotifications.filter(function(n) { return n.id !== item.id })
        next.unshift(item)
        return next.slice(0, 80)
    }

    function publishCenterItem(item) {
        historyNotifications = mergeHistory(item)
        historyCount = historyNotifications.length
        centerChanged()
    }

    function centerItem(index) {
        if (index < 0 || index >= historyNotifications.length)
            return null
        return historyNotifications[index]
    }

    function syncTrackedNotifications() {
        if (logNextSync)
            console.log("syncTrackedNotifications called, count:", notifications.length)

        if (!server.trackedNotifications || !server.trackedNotifications.values) {
            rebuildVisible()
            if (logNextSync) {
                console.log("visibleNotifications after sync:", visibleNotifications.length)
                logNextSync = false
            }
            return
        }

        const tracked = server.trackedNotifications.values
        for (let i = 0; i < tracked.length; i++) {
            const notification = tracked[i]
            if (!notification)
                continue
            notification.tracked = true
            importNotification(notification, false)
        }

        rebuildVisible()

        if (logNextSync) {
            console.log("visibleNotifications after sync:", visibleNotifications.length)
            logNextSync = false
        }
    }

    function cloneNotification(item) {
        return {
            id: item.id,
            ref: item.ref,
            appName: item.appName,
            appIcon: item.appIcon,
            summary: item.summary,
            body: item.body,
            actions: item.actions,
            timestamp: item.timestamp,
            dismissed: item.dismissed,
            expanded: item.expanded,
            urgency: item.urgency,
            critical: item.critical,
            accent: item.accent
        }
    }

    function accentFor(appName) {
        const name = appName.toLowerCase()
        if (name.indexOf("firefox") >= 0 || name.indexOf("browser") >= 0 || name.indexOf("chrome") >= 0)
            return "#7ab7ff"
        if (name.indexOf("kitty") >= 0 || name.indexOf("terminal") >= 0 || name.indexOf("code") >= 0)
            return "#70d67b"
        if (name.indexOf("spotify") >= 0 || name.indexOf("music") >= 0 || name.indexOf("player") >= 0)
            return "#c09cff"
        if (name.indexOf("vesktop") >= 0 || name.indexOf("discord") >= 0)
            return "#9aa7ff"
        return "#a8c7fa"
    }

    function stripMarkup(text) {
        return text.replace(/<[^>]*>/g, "")
    }

    function loadState() {
        if (stateService && stateService.ready)
            dnd = stateService.value("dnd", false) === true
    }
}

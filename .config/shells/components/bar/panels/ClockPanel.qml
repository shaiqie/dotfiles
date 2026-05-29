import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: root

    property var theme
    property int motionToken: 0
    property date now: new Date()
    property int displayMonth: now.getMonth()
    property int displayYear: now.getFullYear()
    property int selectedDay: now.getDate()
    property int transitionDirection: 1
    property real gridOffset: 0
    property real gridOpacity: 1
    property bool clockReady: false
    property bool calendarReady: false
    property bool extrasReady: false
    readonly property int cellSize: 40
    readonly property int cellGap: 6
    readonly property string clockIconDir: Quickshell.env("HOME") + "/.config/shells/assets/icons/panel/clock/"
    readonly property var weekdays: ["S", "M", "T", "W", "T", "F", "S"]
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

    width: parent ? parent.width : 360
    spacing: 14

    Component.onCompleted: {
        rebuildCalendar()
        startCascade()
    }

    onMotionTokenChanged: startCascade()
    onNowChanged: {
        if (displayMonth === now.getMonth() && displayYear === now.getFullYear())
            rebuildCalendar()
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Timer { id: calendarDelay; interval: 80; repeat: false; onTriggered: root.calendarReady = true }
    Timer { id: extrasDelay; interval: 200; repeat: false; onTriggered: root.extrasReady = true }

    ListModel { id: dayModel }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 104
        radius: root.theme.panelRadius
        color: root.theme.withAlpha(root.theme.foreground, 0.045)
        border.width: root.theme.outerBorder ? root.theme.borderWidth : 0
        border.color: root.theme.withAlpha(root.theme.color1, 0.16)
        opacity: root.clockReady ? 1 : 0

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: "transparent"
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.theme.withAlpha(root.theme.color4, 0.11) }
                GradientStop { position: 0.48; color: root.theme.withAlpha(root.theme.color2, 0.045) }
                GradientStop { position: 1.0; color: root.theme.withAlpha(root.theme.background, 0) }
            }
        }

        Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic } }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Row {
                    Layout.preferredHeight: 54
                    height: 54
                    spacing: 1

                    FlipDigit { theme: root.theme; value: Qt.formatDateTime(root.now, "hh").slice(0, 1); visible: Qt.formatDateTime(root.now, "hh").length > 1 }
                    FlipDigit { theme: root.theme; value: Qt.formatDateTime(root.now, "hh").slice(1, 2) }
                    Text {
                        text: ":"
                        color: root.theme.color4
                        font.family: root.theme.fontFamily
                        font.pixelSize: 46 * root.theme.fontScale
                        font.bold: root.theme.fontBold
                        opacity: colonPulse.running ? 1 : 1

                        SequentialAnimation on opacity {
                            id: colonPulse
                            running: true
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: theme && theme.reducedMotion ? Math.round(500 / 2) : 500; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: theme && theme.reducedMotion ? Math.round(500 / 2) : 500; easing.type: Easing.InOutSine }
                        }
                    }
                    FlipDigit { theme: root.theme; value: Qt.formatDateTime(root.now, "mm").slice(0, 1) }
                    FlipDigit { theme: root.theme; value: Qt.formatDateTime(root.now, "mm").slice(1, 2) }
                }

                Text {
                    Layout.fillWidth: true
                    text: Qt.formatDateTime(root.now, "dddd, MMMM d yyyy")
                    color: root.theme.withAlpha(root.theme.foreground, 0.58)
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                Layout.preferredWidth: 74
                Layout.fillHeight: true
                radius: root.theme.controlRadius
                color: root.theme.withAlpha(root.theme.color4, 0.10)
                clip: true

                ClockSvgIcon {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    theme: root.theme
                    sourcePath: root.clockIconDir + "time_item.svg"
                    iconColor: root.theme.withAlpha(root.theme.color4, 0.38)
                    iconSize: 22
                    opacity: 0.9
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(root.now, "dd")
                        color: root.theme.foreground
                        font.pixelSize: 24
                        font.bold: true
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(root.now, "MMM").toUpperCase()
                        color: root.theme.color4
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 42
        opacity: root.calendarReady ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic } }

        NavButton {
            theme: root.theme
            icon: "‹"
            onActivated: root.previousMonth()
        }

        Text {
            Layout.fillWidth: true
            text: root.monthNames[root.displayMonth] + " " + root.displayYear
            color: root.theme.foreground
            font.pixelSize: 18
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            opacity: root.gridOpacity
            Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(250 / 2) : 250; easing.type: Easing.OutCubic } }
        }

        NavButton {
            theme: root.theme
            icon: "›"
            onActivated: root.nextMonth()
        }
    }

    Row {
        Layout.preferredWidth: calendarWidth()
        Layout.preferredHeight: 16
        Layout.alignment: Qt.AlignHCenter
        width: calendarWidth()
        spacing: root.cellGap
        opacity: root.calendarReady ? 1 : 0

        Repeater {
            model: root.weekdays
            Text {
                width: root.cellSize
                text: modelData
                color: root.theme.color6
                font.pixelSize: 12
                font.capitalization: Font.AllUppercase
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    Item {
        Layout.preferredWidth: root.calendarWidth()
        Layout.preferredHeight: root.cellSize * 6 + root.cellGap * 5
        Layout.alignment: Qt.AlignHCenter
        width: root.calendarWidth()
        height: root.cellSize * 6 + root.cellGap * 5
        clip: true
        opacity: root.calendarReady ? root.gridOpacity : 0

        Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(250 / 2) : 250; easing.type: Easing.OutCubic } }

        Grid {
            id: calendarGrid
            width: root.calendarWidth()
            columns: 7
            spacing: root.cellGap
            x: root.gridOffset

            Behavior on x { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(250 / 2) : 250; easing.type: Easing.OutCubic } }

            Repeater {
                model: dayModel
                DayCell {
                    theme: root.theme
                    width: root.cellSize
                    height: root.cellSize
                    dayNumber: model.day
                    currentMonth: model.currentMonth
                    today: model.today
                    selected: model.selected
                    weekend: model.weekend
                    onPicked: root.selectedDay = model.day
                }
            }
        }
    }

    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: 66
        width: parent.width
        height: 66
        contentWidth: worldRow.implicitWidth
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        opacity: root.extrasReady ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic } }

        Row {
            id: worldRow
            spacing: 8

            WorldClockCard {
                theme: root.theme
                city: "Jakarta"
                offset: "UTC+7"
                timeText: Qt.formatDateTime(root.now, "hh:mm:ss")
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 74
        width: parent.width
        height: 74
        radius: theme.panelRadius
        color: theme.withAlpha(theme.foreground, 0.045)
        border.width: theme.outerBorder ? theme.borderWidth : 0
        border.color: theme.withAlpha(theme.color1, 0.16)
        opacity: root.extrasReady ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: theme && theme.reducedMotion ? Math.round(180 / 2) : 180; easing.type: Easing.OutCubic } }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                width: 32
                height: 32
                radius: 16
                color: root.theme.withAlpha(root.theme.color4, 0.16)
                ClockSvgIcon {
                    anchors.centerIn: parent
                    theme: root.theme
                    sourcePath: root.clockIconDir + "event_item.svg"
                    iconColor: root.theme.color4
                    iconSize: 18
                }
            }

            Text {
                Layout.fillWidth: true
                text: "No upcoming events"
                color: root.theme.color6
                font.pixelSize: 14
                font.bold: true
                elide: Text.ElideRight
            }
        }
    }

    NumberAnimation {
        id: monthOut
        target: root
        property: "gridOffset"
        duration: theme && theme.reducedMotion ? Math.round(125 / 2) : 125
        easing.type: Easing.OutCubic
        onStarted: fadeOut.restart()
        onStopped: {
            root.applyPendingMonth()
            root.gridOffset = -root.transitionDirection * root.calendarWidth()
            root.gridOpacity = 0
            monthIn.restart()
        }
    }

    NumberAnimation {
        id: monthIn
        target: root
        property: "gridOffset"
        to: 0
        duration: theme && theme.reducedMotion ? Math.round(250 / 2) : 250
        easing.type: Easing.OutCubic
        onStarted: fadeIn.restart()
    }

    NumberAnimation { id: fadeOut; target: root; property: "gridOpacity"; to: 0; duration: theme && theme.reducedMotion ? Math.round(125 / 2) : 125; easing.type: Easing.OutCubic }
    NumberAnimation { id: fadeIn; target: root; property: "gridOpacity"; to: 1; duration: theme && theme.reducedMotion ? Math.round(250 / 2) : 250; easing.type: Easing.OutCubic }

    property int pendingMonth: displayMonth
    property int pendingYear: displayYear

    function startCascade() {
        clockReady = false
        calendarReady = false
        extrasReady = false
        clockReady = true
        calendarDelay.restart()
        extrasDelay.restart()
    }

    function calendarWidth() {
        return cellSize * 7 + cellGap * 6
    }

    function nextMonth() {
        pendingMonth = displayMonth + 1
        pendingYear = displayYear
        if (pendingMonth > 11) {
            pendingMonth = 0
            pendingYear += 1
        }
        transitionDirection = 1
        runMonthTransition()
    }

    function previousMonth() {
        pendingMonth = displayMonth - 1
        pendingYear = displayYear
        if (pendingMonth < 0) {
            pendingMonth = 11
            pendingYear -= 1
        }
        transitionDirection = -1
        runMonthTransition()
    }

    function runMonthTransition() {
        monthOut.stop()
        monthIn.stop()
        fadeOut.stop()
        fadeIn.stop()
        monthOut.to = -transitionDirection * calendarWidth()
        monthOut.restart()
    }

    function applyPendingMonth() {
        displayMonth = pendingMonth
        displayYear = pendingYear
        selectedDay = Math.min(selectedDay, new Date(displayYear, displayMonth + 1, 0).getDate())
        rebuildCalendar()
    }

    function rebuildCalendar() {
        dayModel.clear()
        const first = new Date(displayYear, displayMonth, 1)
        const start = new Date(displayYear, displayMonth, 1 - first.getDay())
        const today = new Date()
        for (let i = 0; i < 42; i++) {
            const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i)
            dayModel.append({
                day: d.getDate(),
                currentMonth: d.getMonth() === displayMonth,
                today: d.getFullYear() === today.getFullYear() && d.getMonth() === today.getMonth() && d.getDate() === today.getDate(),
                selected: d.getMonth() === displayMonth && d.getDate() === selectedDay,
                weekend: d.getDay() === 0 || d.getDay() === 6
            })
        }
    }

    component FlipDigit: Item {
        id: digit
        property var theme
        property string value: "0"
        width: 29
        height: 54

        onValueChanged: flip.restart()

        Text {
            id: digitText
            anchors.centerIn: parent
            text: digit.value
            color: digit.theme.foreground
            font.family: digit.theme.fontFamily
            font.pixelSize: 46 * digit.theme.fontScale
            font.bold: digit.theme.fontBold
        }

        SequentialAnimation {
            id: flip
            NumberAnimation { target: digitText; property: "y"; to: -8; duration: theme && theme.reducedMotion ? Math.round(80 / 2) : 80; easing.type: Easing.OutCubic }
            NumberAnimation { target: digitText; property: "opacity"; to: 0.35; duration: theme && theme.reducedMotion ? Math.round(40 / 2) : 40 }
            PropertyAction { target: digitText; property: "y"; value: 8 }
            NumberAnimation { target: digitText; property: "opacity"; to: 1; duration: theme && theme.reducedMotion ? Math.round(60 / 2) : 60 }
            NumberAnimation { target: digitText; property: "y"; to: 0; duration: theme && theme.reducedMotion ? Math.round(120 / 2) : 120; easing.type: Easing.OutCubic }
        }
    }

    component NavButton: Item {
        id: nav
        signal activated()
        property var theme
        property string icon: ""
        property bool hovered: area.containsMouse
        property bool down: area.pressed

        Layout.preferredWidth: 36
        Layout.preferredHeight: 36
        scale: down ? 0.94 : (hovered ? 1.035 : 1.0)

        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.2; damping: 0.82; mass: 0.85; epsilon: 0.001 } }

        Rectangle {
            anchors.fill: parent
            radius: nav.theme.controlRadius
            color: nav.hovered ? nav.theme.withAlpha(nav.theme.color4, 0.10) : nav.theme.withAlpha(nav.theme.foreground, 0.045)
            Behavior on color { ColorAnimation { duration: nav.theme.reducedMotion ? 0 : 150; easing.type: Easing.OutCubic } }
        }

        Text {
            anchors.centerIn: parent
            text: nav.icon
            color: nav.theme.foreground
            font.pixelSize: 22
            font.bold: true
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            onClicked: nav.activated()
        }
    }

    component DayCell: Item {
        id: cell
        signal picked()
        property var theme
        property int dayNumber: 1
        property bool currentMonth: true
        property bool today: false
        property bool selected: false
        property bool weekend: false
        property bool hovered: area.containsMouse

        opacity: currentMonth ? 1 : 0.3
        scale: area.pressed ? 0.92 : (hovered ? 1.04 : 1.0)

        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 5.2; damping: 0.80; mass: 0.85; epsilon: 0.001 } }

        Rectangle {
            anchors.centerIn: parent
            width: cell.today || cell.selected || cell.hovered ? parent.width : 26
            height: cell.today || cell.selected || cell.hovered ? parent.height : 26
            radius: cell.theme.controlRadius
            color: cell.today ? cell.theme.withAlpha(cell.theme.color4, 0.22)
                : (cell.selected ? cell.theme.withAlpha(cell.theme.color4, 0.13)
                : (cell.hovered ? cell.theme.withAlpha(cell.theme.color4, 0.08) : "transparent"))

            Behavior on width { SpringAnimation { duration: cell.theme.reducedMotion ? 0 : 220; spring: 5.0; damping: 0.84; mass: 0.8; epsilon: 0.001 } }
            Behavior on height { SpringAnimation { duration: cell.theme.reducedMotion ? 0 : 220; spring: 5.0; damping: 0.84; mass: 0.8; epsilon: 0.001 } }
            Behavior on color { ColorAnimation { duration: cell.theme.reducedMotion ? 0 : 150; easing.type: Easing.OutCubic } }
        }

        Text {
            anchors.centerIn: parent
            text: cell.dayNumber
            color: cell.today || cell.selected ? cell.theme.color4 : (cell.weekend ? cell.theme.color2 : cell.theme.foreground)
            font.pixelSize: 14
            font.bold: cell.today || cell.selected
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            onClicked: cell.picked()
        }
    }

    component WorldClockCard: Item {
        id: card
        property var theme
        property string city: ""
        property string offset: ""
        property string timeText: ""
        property bool hovered: area.containsMouse

        width: 184
        height: 62
        scale: hovered ? 1.02 : 1.0

        Behavior on scale { SpringAnimation { duration: theme && theme.reducedMotion ? 0 : 250;  spring: 4.2; damping: 0.76; mass: 0.9; epsilon: 0.001 } }

        Rectangle {
            anchors.fill: parent
            radius: card.theme.controlRadius
            color: card.theme.withAlpha(card.hovered ? card.theme.color4 : card.theme.foreground, card.hovered ? 0.10 : 0.045)
            Behavior on color { ColorAnimation { duration: card.theme.reducedMotion ? 0 : 150; easing.type: Easing.OutCubic } }
        }

        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            ClockSvgIcon {
                theme: card.theme
                sourcePath: root.clockIconDir + "clock.svg"
                iconColor: card.theme.color4
                iconSize: 20
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: card.city; color: card.theme.foreground; font.pixelSize: 14; font.bold: true }
                Text { text: card.offset; color: card.theme.withAlpha(card.theme.foreground, 0.60); font.pixelSize: 11 }
            }

            Text {
                text: card.timeText
                color: card.theme.foreground
                font.pixelSize: 16
                font.bold: true
            }
        }
    }

    component ClockSvgIcon: Item {
        id: clockIcon

        property var theme
        property string sourcePath: ""
        property color iconColor: "white"
        property int iconSize: 24

        width: iconSize
        height: iconSize

        Image {
            id: svgSource
            anchors.fill: parent
            source: clockIcon.sourcePath
            sourceSize.width: width
            sourceSize.height: height
            smooth: true
            mipmap: true
            visible: false
        }

        MultiEffect {
            anchors.fill: svgSource
            source: svgSource
            colorization: 1
            colorizationColor: clockIcon.iconColor

            Behavior on colorizationColor { ColorAnimation { duration: clockIcon.theme && clockIcon.theme.reducedMotion ? 0 : 170; easing.type: Easing.OutCubic } }
        }
    }
}

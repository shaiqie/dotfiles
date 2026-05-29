import QtQuick

Column {
    property var theme
    property string icon
    property string title
    property string subtitle

    spacing: 2

    Text {
        text: icon + "  " + title
        color: theme.foreground
        font.family: theme.fontFamily
        font.pixelSize: 32 * theme.fontScale
        font.bold: theme.fontBold
        elide: Text.ElideRight
        width: parent.width
    }

    Text {
        text: subtitle
        color: theme.withAlpha(theme.foreground, 0.68)
        font.family: theme.fontFamily
        font.pixelSize: 14 * theme.fontScale
        elide: Text.ElideRight
        width: parent.width
    }
}

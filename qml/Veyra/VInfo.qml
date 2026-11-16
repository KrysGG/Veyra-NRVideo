// Fork: the round "i" beside a setting. A click opens a short explanation under
// the row it belongs to: what the feature does, what it costs and what to try
// when it misbehaves. It keeps the panels tidy without losing the help text.
import QtQuick
import QtQuick.Controls

Item {
    id: info
    // What the card says. `title` is optional; the row's label is used by VRow.
    property string title: ""
    property string text: ""
    // The item the card is laid out under: it takes that item's width and opens
    // just below it, so it never leaves the panel the row sits in.
    property Item host: parent
    property real offsetY: host ? host.height : 0
    readonly property bool shown: pop.opened
    implicitWidth: 16
    implicitHeight: 16
    visible: text.length > 0

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: pop.opened ? Theme.accent : hover.hovered ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
        border.width: pop.opened ? 0 : 1
        border.color: hover.hovered ? Theme.t2 : Theme.t3
        Behavior on color { ColorAnimation { duration: Theme.d(150) } }
        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 0.5
            text: "i"
            color: pop.opened ? Theme.accentInk : hover.hovered ? Theme.t1 : Theme.t2
            font.family: Theme.fontUi
            font.pixelSize: 10
            font.weight: Font.Bold
        }
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { gesturePolicy: TapHandler.WithinBounds; onTapped: pop.opened ? pop.close() : pop.open() }
    ToolTip.visible: hover.hovered && !pop.opened
    ToolTip.delay: 500
    ToolTip.text: qsTr("What is this?")

    Popup {
        id: pop
        parent: info.host
        x: 0
        y: info.offsetY + 2
        width: info.host ? info.host.width : 280
        padding: 12
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.d(140) }
            NumberAnimation { property: "scale"; from: 0.97; to: 1; duration: Theme.d(180); easing.type: Easing.OutCubic }
        }
        exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Theme.d(100) } }
        background: Rectangle {
            // Over the picture (fullscreen quick panel) the card is cut out of
            // the native video window like any other popover.
            readonly property bool videoCover: pop.opened
            readonly property real coverRadius: 10
            radius: 10
            color: Theme.popover
            border.width: 1
            border.color: Theme.stroke2
        }
        contentItem: Column {
            spacing: 6
            Text {
                width: parent.width
                visible: info.title.length > 0
                text: info.title
                color: Theme.t1
                font.family: Theme.fontUi
                font.pixelSize: 12
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
            }
            Text {
                width: parent.width
                text: info.text
                textFormat: Text.StyledText
                color: Theme.t2
                font.family: Theme.fontUi
                font.pixelSize: 12
                lineHeight: 1.15
                wrapMode: Text.Wrap
                onLinkActivated: link => Qt.openUrlExternally(link)
                HoverHandler { cursorShape: parent.hoveredLink.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor }
            }
        }
    }
}

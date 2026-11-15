import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Item {
    id: row
    property string label: ""
    property string hint: ""
    property color hintColor: Theme.t3
    property string value: ""
    // Narrow panels with a wide control (导出 输出设置): the hint runs under the
    // whole row instead of being squeezed beside the control.
    property bool hintBelow: false
    // Fork: extra help shown by the round "i" beside the label (what the feature
    // does, its cost, what to try when it misbehaves).
    property string info: ""
    // Fork: compact rows keep their description behind the "i" until asked for.
    // Warnings (any hint not in the quiet colour) and rows that opt out stay visible.
    property bool hintAlways: false
    readonly property bool hintsCompact: typeof veyra !== "undefined" && veyra.preferences
        && veyra.preferences.showHints !== true
    readonly property bool hintFolded: hintsCompact && !hintAlways && Qt.colorEqual(hintColor, Theme.t3)
    readonly property bool hintShown: hint.length > 0 && !hintFolded
    readonly property string infoText: {
        const parts = []
        if (hint.length > 0 && (hintFolded || info.length === 0)) parts.push(hint)
        if (info.length > 0) parts.push(info)
        return parts.join("<br><br>")
    }
    readonly property bool stacked: width > 0 && width - slot.childrenRect.width - (value.length ? 52 : 0) - 12
        < Math.min(170, labelMetrics.advanceWidth(label))
    FontMetrics { id: labelMetrics; font.family: Theme.fontUi; font.pixelSize: Theme.fsBody }
    default property alias control: slot.data
    // The row's slider, when its control is one (typed values beside the number).
    readonly property Item valueSlider: {
        for (let i = 0; i < slot.children.length; ++i) {
            const c = slot.children[i]
            if (c && c.commitValue !== undefined && c.inputDecimals !== undefined) return c
        }
        return null
    }

    // The layout reads Layout.preferredHeight. `height` is deliberately NOT set: a
    // layout-managed item that sets its own height is undefined behaviour, and this
    // row is only ever placed inside a layout.
    // A hint that wraps (narrow panels) grows the row instead of running into
    // the next one.
    implicitHeight: Math.max(Theme.rowMinHeight, mainRow.implicitHeight + 8)
        + (hintBelow && hintShown ? belowHint.implicitHeight + 6 : 0)
    Layout.preferredHeight: implicitHeight
    Layout.fillWidth: true
    GridLayout {
        id: mainRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        columns: row.stacked ? 2 : 3
        columnSpacing: 12
        rowSpacing: 6
        ColumnLayout {
            id: textColumn
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.columnSpan: row.stacked ? 2 : 1
            spacing: 2
            // fillWidth here too: without a hint the label is the column's only child,
            // and a layout with no filling child cannot grow, which left the control
            // beside the label instead of at the row's right edge.
            // Grow the row for long labels instead of hiding translated text.
            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 6
                Text { Layout.fillWidth: true; Layout.maximumWidth: labelInfo.visible ? Math.ceil(implicitWidth) + 1 : Number.POSITIVE_INFINITY; Layout.minimumWidth: 0; text: row.label; color: Theme.t2; font.family: Theme.fontUi; font.pixelSize: Theme.fsBody; wrapMode: Text.Wrap }
                VInfo {
                    id: labelInfo
                    objectName: "row-info"
                    Layout.alignment: Qt.AlignVCenter
                    host: row
                    offsetY: mainRow.height + 2
                    title: row.label
                    text: row.infoText
                    visible: row.label.length > 0 && (row.info.length > 0 || (row.hint.length > 0 && row.hintFolded))
                }
                Item { Layout.fillWidth: true; visible: labelInfo.visible }
            }
            Text {
                visible: row.hintShown && !row.hintBelow
                text: row.hint
                color: row.hintColor
                font.family: Theme.fontUi
                font.pixelSize: 11
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
        }
        Item {
            id: slot
            implicitHeight: childrenRect.height
            Layout.preferredWidth: childrenRect.width
            Layout.preferredHeight: childrenRect.height
        }
        // A row whose control is a slider: its number can be clicked and typed.
        VSliderValue {
            visible: row.value.length > 0
            text: row.value
            slider: row.valueSlider
            Layout.minimumWidth: 40
        }
    }
    Text {
        id: belowHint
        visible: row.hintBelow && row.hintShown
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: mainRow.bottom
        anchors.topMargin: 6
        text: row.hint
        color: row.hintColor
        font.family: Theme.fontUi
        font.pixelSize: 11
        wrapMode: Text.WordWrap
    }
}

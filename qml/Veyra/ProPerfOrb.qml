// Professional-view reusable presentation component.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects

Item {
    id: orb
    property real fraction: 0
    property bool known: false
    property string value: "—"
    property string label: ""
    property string tip: ""
    property int size: 56
    // Compact (the node page's 40px bar): no label under the ring; the
    // tooltip names the orb instead.
    property bool showLabel: true
    readonly property color tone: !known ? Qt.rgba(1, 1, 1, 0.25)
                                : fraction < 0.7 ? Theme.ok : fraction < 1.0 ? "#F2B941" : Theme.err
    // Rings line up even when one label runs to two lines (GPU name orbs).
    Layout.alignment: Qt.AlignTop
    implicitWidth: Math.max(size, labelText.implicitWidth)
    implicitHeight: showLabel ? size + 4 + labelText.implicitHeight : size
    // The ring is only a few dozen pixels across. Sub-percent changes do
    // not add visible information; the numeric label retains full precision.
    readonly property real shown: Math.round(telemetry.value * 100) / 100
    VTelemetryValue {
        id: telemetry
        targetValue: orb.known ? Math.min(1, Math.max(0, orb.fraction)) : 0
        animate: orb.visible && !Theme.reduced && (!veyra.paused || (typeof vyTest !== "undefined" && vyTest.disablePausedUiIdle === true))
        duration: 600
    }
    onShownChanged: ring.requestPaint()
    onToneChanged: ring.requestPaint()
    // The ring's footprint: the label and value are laid out against it.
    Item {
        id: ringBox
        width: orb.size; height: orb.size
        anchors.horizontalCenter: parent.horizontalCenter
    }
    // Fork: the canvas reaches past the ring by the glow's size, so the glow
    // fades out instead of being cut off square at the ring's box.
    Canvas {
        id: ring
        readonly property int glow: 12
        x: ringBox.x - glow; y: ringBox.y - glow
        width: orb.size + glow * 2; height: orb.size + glow * 2
        onPaint: {
            const c = getContext("2d"); c.reset()
            const r = orb.size / 2 - 4, cx = width / 2, cy = height / 2
            c.lineWidth = 5; c.lineCap = "round"
            c.strokeStyle = Qt.rgba(1, 1, 1, 0.08)
            c.beginPath(); c.arc(cx, cy, r, 0, Math.PI * 2); c.stroke()
            if (orb.shown > 0.001) {
                c.strokeStyle = orb.tone
                c.shadowColor = orb.tone; c.shadowBlur = 8
                c.beginPath(); c.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * orb.shown); c.stroke()
            }
        }
    }
    Text {
        anchors.centerIn: ringBox
        width: orb.size - 12
        horizontalAlignment: Text.AlignHCenter
        text: orb.value
        color: orb.known ? Theme.t1 : Theme.t3
        font.family: Theme.fontMono
        font.pixelSize: orb.size >= 50 ? 11 : 9
        font.weight: Font.DemiBold; font.variableAxes: Theme.axesDemiBold
        fontSizeMode: Text.HorizontalFit; minimumPixelSize: 8
    }
    Text {
        id: labelText
        visible: orb.showLabel
        anchors.top: ringBox.bottom; anchors.topMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        text: orb.label
        horizontalAlignment: Text.AlignHCenter
        lineHeight: 0.95
        color: Theme.t3
        font.family: Theme.fontUi
        font.pixelSize: 10
    }
    HoverHandler { id: orbHover }
    ToolTip.visible: orbHover.hovered && (orb.tip.length > 0 || !orb.showLabel)
    ToolTip.text: (orb.showLabel ? "" : orb.label.replace("\n", " ") + "：") + orb.tip
}

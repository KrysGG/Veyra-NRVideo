// Start-up notice: a DLSS file this card could use is missing (Settings → NVIDIA 组件).
//
// Shown once per launch, a few seconds after start, and only while the scan still
// reports the file missing. 不再提示 stores dependencyNoticeHidden; the Settings
// nav entry stays yellow either way, so the guide remains easy to find.
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: banner
    // The native video host subtracts visible videoCover items from its region.
    objectName: "videoCover"
    property real coverRadius: 10
    property bool shown: false
    signal openRequested()
    signal hideForever()
    width: 560
    height: Math.max(54, bannerRow.implicitHeight + 20)
    radius: 10
    color: "#2A2414"
    border.color: "#7A6630"
    visible: shown
    function show() { shown = true }
    function dismiss() { shown = false }
    RowLayout {
        id: bannerRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 14
        anchors.rightMargin: 8
        spacing: 8
        VIcon { name: "info"; size: 16; color: Theme.warn; Layout.alignment: Qt.AlignVCenter }
        Text {
            Layout.fillWidth: true
            text: qsTr("缺少 DLSS / NVIDIA 帧生成所需的运行组件。前往 设置 › NVIDIA 组件 查看安装指南。")
            color: "#F6E7BE"
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsBody
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
        }
        VButton {
            objectName: "deps-banner-open"
            primary: true
            text: qsTr("查看指南")
            onClicked: { banner.openRequested(); banner.dismiss() }
        }
        VButton {
            objectName: "deps-banner-hide"
            ghost: true
            text: qsTr("不再提示")
            onClicked: { banner.hideForever(); banner.dismiss() }
        }
        VButton {
            objectName: "deps-banner-dismiss"
            icon: true
            iconName: "x"
            ghost: true
            tip: qsTr("关闭")
            onClicked: banner.dismiss()
        }
    }
}

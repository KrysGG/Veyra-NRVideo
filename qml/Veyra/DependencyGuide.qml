// 设置 → NVIDIA 组件: where the user-downloaded DLSS / ANR files go, and how to put them there.
//
// The files come from their publishers (NVIDIA's DLSS SDK release; the ANR project's
// own releases). Veyra links to those pages and opens the target folder; it does not
// download or redistribute the files. Status, folders and links all come from the
// bridge (QmlPlayerBridge::nvidiaDependencies, src/ui/bridge/Dependencies.cpp), so the
// paths shown are the ones the backends load from.
//
// The step pictures are drawn here rather than shipped as screenshots: they show this
// machine's real target folder, follow the theme and the UI language, and mark a
// file as in place once the scan sees it.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: guide
    spacing: 12

    readonly property var deps: veyra.nvidiaDependencies || []
    function dep(id) {
        for (let i = 0; i < deps.length; ++i) if (deps[i].id === id) return deps[i]
        return ({ present: false, relevant: false, files: [], folder: "" })
    }
    readonly property var dlssSr: dep("dlss-sr")
    readonly property var dlssFg: dep("dlss-fg")
    readonly property var anr: dep("anr")
    readonly property bool dlssReady: dlssSr.present === true && dlssFg.present === true
    // The ANR steps are an opt-in experiment; open them when ANR is the only thing missing.
    property bool anrOpen: false
    function folderName(path) {
        const parts = String(path || "").split(/[\\/]/).filter(p => p.length > 0)
        return parts.length ? parts[parts.length - 1] : ""
    }

    // --- drawing pieces ------------------------------------------------------
    // A file row in a mock Explorer window: { text, kind: dll|zip|dir|file, hl, ok, dim }.
    component FileRow: Rectangle {
        id: fileRow
        property var item: ({})
        Layout.fillWidth: true
        implicitHeight: 22
        radius: 5
        color: item.hl ? Theme.accentSoft : "transparent"
        border.width: item.hl ? 1 : 0
        border.color: Theme.accent
        opacity: item.dim ? 0.45 : 1
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 6
            VIcon {
                name: fileRow.item.kind === "dir" ? "folder" : fileRow.item.kind === "zip" ? "box" : fileRow.item.kind === "dll" ? "layers" : "film"
                size: 12
                color: fileRow.item.kind === "dir" ? Theme.warn : fileRow.item.hl ? Theme.accent : Theme.t2
            }
            Text {
                Layout.fillWidth: true
                text: fileRow.item.text || ""
                color: fileRow.item.hl ? Theme.t1 : Theme.t2
                font.family: Theme.fontMono
                font.pixelSize: 11
                elide: Text.ElideMiddle
            }
            VIcon { visible: fileRow.item.ok === true; name: "check"; size: 12; color: Theme.ok }
        }
    }
    // A small window: title bar, a path/address line, then rows or a drop zone.
    component MockWindow: Rectangle {
        id: win
        property string title: ""
        property string address: ""
        property bool browser: false
        property var rows: []
        property string dropText: ""
        property bool target: false
        Layout.fillWidth: true
        Layout.preferredWidth: 10
        implicitHeight: winCol.implicitHeight + 10
        radius: 8
        color: Theme.card
        border.width: 1
        border.color: target ? Theme.accent : Theme.stroke2
        ColumnLayout {
            id: winCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 5
            spacing: 4
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                Repeater { model: 3; Rectangle { width: 6; height: 6; radius: 3; color: Theme.stroke2 } }
                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    text: win.title
                    color: Theme.t2
                    font.family: Theme.fontUi
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 18
                radius: win.browser ? 9 : 4
                color: Theme.bgMid
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 7
                    anchors.right: parent.right
                    anchors.rightMargin: 7
                    spacing: 5
                    VIcon { anchors.verticalCenter: parent.verticalCenter; name: win.browser ? "globe" : "folder"; size: 10; color: Theme.t3 }
                    Text {
                        width: parent.width - 15
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.address
                        color: Theme.t2
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        elide: Text.ElideLeft
                    }
                }
            }
            Repeater { model: win.rows; FileRow { required property var modelData; item: modelData } }
            Rectangle {
                visible: win.dropText.length > 0
                Layout.fillWidth: true
                implicitHeight: 30
                radius: 6
                color: Qt.rgba(1, 0.541, 0.239, 0.06)
                border.width: 1
                border.color: Theme.accent
                Text {
                    anchors.centerIn: parent
                    text: win.dropText
                    color: Theme.accent
                    font.family: Theme.fontUi
                    font.pixelSize: 11
                }
            }
        }
    }
    // The drag between two windows.
    component DragArrow: ColumnLayout {
        spacing: 2
        Layout.alignment: Qt.AlignVCenter
        VIcon { Layout.alignment: Qt.AlignHCenter; name: "right"; size: 22; color: Theme.accent }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("拖放")
            color: Theme.accent
            font.family: Theme.fontUi
            font.pixelSize: 11
            font.weight: Font.DemiBold; font.variableAxes: Theme.axesDemiBold
        }
    }
    component Picture: Rectangle {
        default property alias content: picRow.data
        Layout.fillWidth: true
        implicitHeight: picRow.implicitHeight + 24
        radius: 10
        color: Theme.bgMid
        border.width: 1
        border.color: Theme.stroke
        RowLayout {
            id: picRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 12
            spacing: 10
        }
    }
    // A numbered step: title, text, an optional picture and buttons.
    component Step: Rectangle {
        id: step
        property int number: 1
        property string title: ""
        property string text: ""
        property bool done: false
        // Buttons and pictures under the text: `extra: [ ... ]` at the use site.
        property alias extra: stepExtra.data
        Layout.fillWidth: true
        implicitHeight: stepCol.implicitHeight + 24
        radius: 12
        color: Theme.card2
        border.width: 1
        border.color: Theme.stroke
        ColumnLayout {
            id: stepCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: 24; implicitHeight: 24; radius: 12
                    color: step.done ? Qt.rgba(0.239, 0.863, 0.518, 0.16) : Theme.accentSoft
                    Text {
                        anchors.centerIn: parent
                        visible: !step.done
                        text: step.number
                        color: Theme.accent
                        font.family: Theme.fontUi
                        font.pixelSize: 12
                        font.weight: Font.DemiBold; font.variableAxes: Theme.axesDemiBold
                    }
                    VIcon { anchors.centerIn: parent; visible: step.done; name: "check"; size: 13; color: Theme.ok }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    VH3 { text: step.title }
                    Text {
                        Layout.fillWidth: true
                        text: step.text
                        color: Theme.t2
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsBody
                        wrapMode: Text.WordWrap
                        textFormat: Text.StyledText
                    }
                }
            }
            ColumnLayout {
                id: stepExtra
                visible: children.length > 0
                Layout.fillWidth: true
                Layout.leftMargin: 34
                spacing: 10
            }
        }
    }

    // --- page ----------------------------------------------------------------
    VH1 { text: qsTr("NVIDIA 组件") }
    Text {
        Layout.fillWidth: true
        text: qsTr("DLSS 超分辨率和 DLSS 帧生成需要 NVIDIA 的运行文件。Veyra 不附带也不代为下载它们：请从 NVIDIA 官方发布页下载，再按下面的步骤放进 Veyra 的组件文件夹。放好后几秒内自动识别，不用重启。")
        color: Theme.t2
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsBody
        wrapMode: Text.WordWrap
    }

    VGroup {
        objectName: "deps-status"
        Repeater {
            model: guide.deps
            delegate: VRow {
                required property var modelData
                label: modelData.name
                hint: modelData.summary + " · " + modelData.files.join(", ")
                VTag {
                    objectName: "deps-tag-" + modelData.id
                    text: modelData.present ? qsTr("已就绪") : !modelData.relevant ? qsTr("此显卡不可用") : qsTr("缺少")
                    kind: modelData.present ? "ok" : !modelData.relevant ? "" : modelData.optional ? "exp" : "warn"
                }
            }
        }
        VRow {
            label: qsTr("重新检查")
            hint: qsTr("文件放好后会自动识别；也可以手动立即检查")
            VButton { objectName: "deps-refresh"; text: qsTr("检查"); iconName: "refresh"; onClicked: veyra.refreshNvidiaDependencies() }
        }
    }

    VH2 { Layout.topMargin: 6; text: qsTr("安装 DLSS（超分辨率 + 帧生成）") }

    Step {
        number: 1
        done: guide.dlssReady
        title: qsTr("下载 NVIDIA DLSS SDK")
        text: qsTr("打开 NVIDIA 在 GitHub 上的官方发布页（DLSS SDK v310.9.1，本版本按它验证），在 Assets 里下载 <b>Source code (zip)</b>。")
        extra: [
            VButton { objectName: "deps-download-dlss"; primary: true; iconName: "external"; text: qsTr("打开 NVIDIA 下载页"); onClicked: veyra.openDependencyDownload("dlss-fg") },
            Picture {
                MockWindow {
                    browser: true
                    title: "DLSS 310.9.1 SDK · NVIDIA/DLSS"
                    address: "github.com/NVIDIA/DLSS/releases/tag/v310.9.1"
                    rows: [
                        { text: "Source code (zip)", kind: "zip", hl: true },
                        { text: "Source code (tar.gz)", kind: "zip", dim: true }
                    ]
                }
            }
        ]
    }

    Step {
        number: 2
        done: guide.dlssReady
        title: qsTr("解压，找到两个 DLL")
        text: qsTr("解压下载的 zip，依次打开 <b>lib → Windows_x86_64 → rel</b>，找到 <b>nvngx_dlss.dll</b> 和 <b>nvngx_dlssg.dll</b>。同目录的其他文件不需要。")
        extra: [
            Picture {
                MockWindow {
                    title: "rel"
                    address: "DLSS-310.9.1\\lib\\Windows_x86_64\\rel"
                    rows: [
                        { text: "nvngx_dlss.dll", kind: "dll", hl: true },
                        { text: "nvngx_dlssd.dll", kind: "dll", dim: true },
                        { text: "nvngx_dlssg.dll", kind: "dll", hl: true }
                    ]
                }
            }
        ]
    }

    Step {
        number: 3
        done: guide.dlssReady
        title: qsTr("拖进 Veyra 的组件文件夹")
        text: qsTr("点击“打开目标文件夹”，把这两个 DLL 从 rel 拖进打开的窗口。目标文件夹：<br><font face=\"Consolas\">%1</font>").arg(guide.dlssFg.folder || "")
        extra: [
            VButton { objectName: "deps-open-dlss"; iconName: "folder"; text: qsTr("打开目标文件夹"); onClicked: veyra.openDependencyFolder("dlss-fg") },
            Picture {
                MockWindow {
                    title: "rel"
                    address: "DLSS-310.9.1\\lib\\Windows_x86_64\\rel"
                    rows: [
                        { text: "nvngx_dlss.dll", kind: "dll", hl: true },
                        { text: "nvngx_dlssg.dll", kind: "dll", hl: true }
                    ]
                }
                DragArrow { }
                MockWindow {
                    target: true
                    title: guide.folderName(guide.dlssFg.folder)
                    address: guide.dlssFg.folder || ""
                    rows: [
                        { text: "nvngx_dlss.dll", kind: "dll", ok: guide.dlssSr.present === true, dim: guide.dlssSr.present !== true },
                        { text: "nvngx_dlssg.dll", kind: "dll", ok: guide.dlssFg.present === true, dim: guide.dlssFg.present !== true }
                    ]
                    dropText: guide.dlssReady ? "" : qsTr("放到这里")
                }
            }
        ]
    }

    Step {
        number: 4
        done: guide.dlssReady
        title: guide.dlssReady ? qsTr("DLSS 已就绪") : qsTr("确认")
        text: guide.dlssReady
              ? qsTr("两个文件都已找到。超分和补帧里的 DLSS 选项现在可以使用。")
              : qsTr("上方状态变成“已就绪”即完成。如果文件已放好仍显示缺少，确认文件名没有被改成“nvngx_dlss (1).dll”之类，且没有放进子文件夹。")
    }

    // --- ANR (experimental, not NVIDIA) ------------------------------------------
    VGroup {
        Layout.topMargin: 6
        VRow {
            label: qsTr("ANR 帧生成（实验）")
            hint: qsTr("第三方 apex-compute/ANR 项目的补帧组件，不是 NVIDIA 官方组件；其作者目前禁止第三方再分发，只能自行下载")
            Row {
                spacing: 8
                VTag { anchors.verticalCenter: parent.verticalCenter; text: guide.anr.present ? qsTr("已就绪") : qsTr("可选"); kind: guide.anr.present ? "ok" : "exp" }
                VButton {
                    objectName: "deps-anr-toggle"
                    ghost: true
                    text: guide.anrOpen ? qsTr("收起") : qsTr("查看步骤")
                    trailingIcon: "down"
                    onClicked: guide.anrOpen = !guide.anrOpen
                }
            }
        }
    }
    Step {
        visible: guide.anrOpen
        number: 1
        done: guide.anr.present === true
        title: qsTr("下载 ANR 帧生成组件")
        text: qsTr("打开 ANR 项目的 GitHub 发布页，下载最新 FG 版本里的 <b>anr-fg-…-addon.zip</b>（不需要 full 或 kit 包）。")
        extra: [
            VButton { objectName: "deps-download-anr"; iconName: "external"; text: qsTr("打开 ANR 发布页"); onClicked: veyra.openDependencyDownload("anr") },
            Picture {
                MockWindow {
                    browser: true
                    title: "Releases · apex-compute/ANR"
                    address: "github.com/apex-compute/ANR/releases"
                    rows: [
                        { text: "anr-fg-…-addon.zip", kind: "zip", hl: true },
                        { text: "anr-fg-…-full.zip", kind: "zip", dim: true },
                        { text: "anr-fg-…-kit-windows.zip", kind: "zip", dim: true }
                    ]
                }
            }
        ]
    }
    Step {
        visible: guide.anrOpen
        number: 2
        done: guide.anr.present === true
        title: qsTr("把 zip 里的全部文件拖进 anr 文件夹")
        text: qsTr("解压 addon.zip，把里面<b>所有文件</b>（包括 nvngx_dlssg.dll 和模型文件）拖进 anr 文件夹。按钮会在需要时自动建好这个文件夹：<br><font face=\"Consolas\">%1</font>").arg(guide.anr.folder || "")
        extra: [
            VButton { objectName: "deps-open-anr"; iconName: "folder"; text: qsTr("打开 anr 文件夹"); onClicked: veyra.openDependencyFolder("anr") },
            Picture {
                MockWindow {
                    title: "anr-fg-addon"
                    address: "Downloads\\anr-fg-addon"
                    rows: [
                        { text: "nvngx_dlssg.dll", kind: "dll", hl: true },
                        { text: qsTr("模型和其余文件…"), kind: "file", hl: true }
                    ]
                }
                DragArrow { }
                MockWindow {
                    target: true
                    title: "anr"
                    address: guide.anr.folder || ""
                    rows: guide.anr.present ? [{ text: "nvngx_dlssg.dll", kind: "dll", ok: true }] : []
                    dropText: guide.anr.present ? "" : qsTr("放到这里")
                }
            }
        ]
    }
}

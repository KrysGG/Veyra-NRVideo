import QtQuick
import QtTest
import Veyra

// 设置 → NVIDIA 组件 and the start-up notice (DependencyGuide / DependencyBanner).
Rectangle {
    id: fixture
    width: 760; height: 3200
    color: Theme.card
    QtObject {
        id: backend
        property var calls: []
        property var preferences: ({})
        property int uiDeviceGeneration: 0
        property var nvidiaDependencies: [
            { id: "dlss-sr", name: "DLSS SR", summary: "sr", files: ["nvngx_dlss.dll"], folder: "C:\\Veyra\\runtime\\experimental", present: true, relevant: true, optional: false },
            { id: "dlss-fg", name: "DLSS FG", summary: "fg", files: ["nvngx_dlssg.dll"], folder: "C:\\Veyra\\runtime\\experimental", present: false, relevant: true, optional: false },
            { id: "anr", name: "ANR", summary: "anr", files: ["nvngx_dlssg.dll"], folder: "C:\\Veyra\\runtime\\experimental\\anr", present: false, relevant: false, optional: true }
        ]
        function openDependencyDownload(id) { calls = calls.concat(["download:" + id]) }
        function openDependencyFolder(id) { calls = calls.concat(["folder:" + id]) }
        function openDownloadsFolder() { calls = calls.concat(["downloads"]) }
        function refreshNvidiaDependencies() { calls = calls.concat(["refresh"]) }
    }
    DependencyGuide { id: guide; property var veyra: backend; x: 20; y: 20; width: 700 }
    DependencyBanner { id: banner; y: 20; x: 20; width: 560 }
    SignalSpy { id: opened; target: banner; signalName: "openRequested" }
    SignalSpy { id: hidden; target: banner; signalName: "hideForever" }

    TestCase {
        name: "DependencyGuide"
        when: windowShown
        function init() { backend.calls = []; guide.anrOpen = false; banner.dismiss(); opened.clear(); hidden.clear() }
        function click(name) { const item = findChild(guide, name); verify(item, name); verify(item.visible, name + " visible"); mouseClick(item, item.width / 2, item.height / 2) }
        function test_status() {
            compare(guide.dlssReady, false)
            compare(findChild(guide, "deps-tag-dlss-sr").kind, "ok")
            compare(findChild(guide, "deps-tag-dlss-fg").kind, "warn")
            // ANR on a card that cannot run it: neutral, not a warning.
            compare(findChild(guide, "deps-tag-anr").kind, "")
        }
        function test_buttons() {
            click("deps-download-dlss")
            click("deps-open-downloads")
            click("deps-open-dlss")
            click("deps-refresh")
            compare(backend.calls, ["download:dlss-fg", "downloads", "folder:dlss-fg", "refresh"])
        }
        function test_anrSteps() {
            verify(!findChild(guide, "deps-download-anr").visible)
            click("deps-anr-toggle")
            compare(guide.anrOpen, true)
            waitForRendering(guide)
            click("deps-download-anr")
            click("deps-open-downloads-anr")
            click("deps-open-anr")
            compare(backend.calls, ["download:anr", "downloads", "folder:anr"])
        }
        function test_linuxSteps() {
            compare(guide.linuxOpen, false)
            click("deps-linux-toggle")
            compare(guide.linuxOpen, true)
            // The Linux note names the folder under Veyra's own, not the full Windows path.
            compare(guide.relativeFolder("C:\\Users\\You\\Downloads\\Veyra\\runtime\\experimental"), "runtime/experimental")
        }
        function test_ready() {
            const saved = backend.nvidiaDependencies
            backend.nvidiaDependencies = saved.map(d => Object.assign({}, d, { present: true }))
            compare(guide.dlssReady, true)
            compare(findChild(guide, "deps-tag-dlss-fg").kind, "ok")
            backend.nvidiaDependencies = saved
        }
        function test_banner() {
            compare(banner.visible, false)
            banner.show()
            const open = findChild(banner, "deps-banner-open")
            mouseClick(open, open.width / 2, open.height / 2)
            compare(opened.count, 1)
            compare(banner.visible, false)
            banner.show()
            const hide = findChild(banner, "deps-banner-hide")
            mouseClick(hide, hide.width / 2, hide.height / 2)
            compare(hidden.count, 1)
            compare(banner.visible, false)
            banner.show()
            const close = findChild(banner, "deps-banner-dismiss")
            mouseClick(close, close.width / 2, close.height / 2)
            compare(opened.count, 1); compare(hidden.count, 1)
            compare(banner.visible, false)
        }
    }
}

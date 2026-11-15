// QML bridge: user-supplied runtime files (Settings → NVIDIA 组件).
//
// DLSS Super Resolution, DLSS Frame Generation and ANR frame generation each need a
// DLL the user downloads from its publisher; source builds and some packages do not
// carry them. This lists what is missing, where each file goes, and where to get it.
// Presence is read from the same paths the backends load (Hardware.cpp
// scanEffectCapabilities, AnrProvider), so the guide cannot point at a folder the
// engine does not look in.
#include "../QmlPlayerBridge_p.h"
#include "veyra/ngx/AnrProvider.h"

namespace veyra::ui {
namespace {
// Publisher pages only: Veyra never downloads or redistributes these files.
// v310.9.1 is the DLSS SDK build the RTX 30/40 frame generation patches are audited
// against (DlssgTransfusion); the release's lib/Windows_x86_64/rel holds both DLLs.
const QString kDlssRelease = QStringLiteral("https://github.com/NVIDIA/DLSS/releases/tag/v310.9.1");
const QString kAnrReleases = QStringLiteral("https://github.com/apex-compute/ANR/releases");

struct Dependency {
    const char* id;
    QString name, summary, url, publisher, archivePath;
    QStringList files;
    std::filesystem::path folder;
    HardwareEffect hardware;
    bool optional;
};

std::vector<Dependency> dependencies() {
    const auto nr = runtime::localRuntimeDirectory();
    return {
        {"dlss-sr", QObject::tr("DLSS 超分辨率"), QObject::tr("RTX 超分里的 DLSS 选项需要它"), kDlssRelease, QStringLiteral("NVIDIA"),
         QStringLiteral("lib\\Windows_x86_64\\rel"), {QStringLiteral("nvngx_dlss.dll")}, nr, HardwareEffect::Nvidia, false},
        {"dlss-fg", QObject::tr("DLSS 帧生成"), QObject::tr("补帧里的 DLSS 选项需要它"), kDlssRelease, QStringLiteral("NVIDIA"),
         QStringLiteral("lib\\Windows_x86_64\\rel"), {QStringLiteral("nvngx_dlssg.dll")}, nr, HardwareEffect::Nvidia, false},
        {"anr", QObject::tr("ANR 帧生成（实验）"), QObject::tr("补帧里的 ANR 选项需要它；不是 NVIDIA 官方组件"), kAnrReleases, QStringLiteral("apex-compute/ANR"),
         QStringLiteral("anr-fg-…-addon.zip"), {QStringLiteral("nvngx_dlssg.dll")},
         std::filesystem::path(ngx::AnrProvider::directory(nr.wstring())), HardwareEffect::CrossVendor, true},
    };
}
const Dependency* findDependency(const std::vector<Dependency>& list, const QString& id) {
    for (const auto& d : list) if (id == QLatin1String(d.id)) return &d;
    return nullptr;
}
QString nativePath(const std::filesystem::path& path) {
    return QDir::toNativeSeparators(QString::fromStdWString(path.lexically_normal().wstring()));
}
}

QVariantList QmlPlayerBridge::nvidiaDependencies() const {
    // Read on effectCapabilitiesChanged only (the 2 s capability scan), never per frame.
    const auto gpu = effectGpu();
    QVariantList out;
    for (const auto& d : dependencies()) {
        bool present = true;
        QStringList missing;
        for (const auto& file : d.files) {
            std::error_code ec;
            if (!std::filesystem::is_regular_file(d.folder / file.toStdWString(), ec)) { present = false; missing << file; }
        }
        out << QVariantMap{{"id", QString::fromLatin1(d.id)}, {"name", d.name}, {"summary", d.summary},
                           {"files", d.files}, {"missingFiles", missing}, {"folder", nativePath(d.folder)},
                           {"publisher", d.publisher}, {"archivePath", d.archivePath}, {"url", d.url},
                           {"present", present}, {"relevant", hardwareSupports(d.hardware, gpu)}, {"optional", d.optional}};
    }
    return out;
}
bool QmlPlayerBridge::nvidiaDependenciesMissing() const {
    // The start-up notice: a required NVIDIA file is missing on a card that can run it.
    // ANR is an opt-in experiment and only shows on the guide page.
    for (const auto& value : nvidiaDependencies()) {
        const auto d = value.toMap();
        if (d.value("relevant").toBool() && !d.value("optional").toBool() && !d.value("present").toBool()) return true;
    }
    return false;
}
void QmlPlayerBridge::refreshNvidiaDependencies() {
    // 重新检查: rescan now instead of waiting for the next capability tick, so menus
    // that were greyed out for a missing file come back as soon as it is in place.
    (void)currentEffectCapabilities(true);
    emit effectCapabilitiesChanged();
    emit fgChoicesChanged();
}
void QmlPlayerBridge::openDependencyDownload(const QString& id) {
    const auto list = dependencies();
    const auto* d = findDependency(list, id);
    if (!d || !QDesktopServices::openUrl(QUrl(d->url))) emit notice(tr("无法打开浏览器"), true);
}
void QmlPlayerBridge::openDownloadsFolder() {
    // Step 2 starts where the browser saved the zip.
    QString dir = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    if (dir.isEmpty()) dir = QDir::homePath();
    if (!QDesktopServices::openUrl(QUrl::fromLocalFile(dir))) emit notice(tr("无法打开目录：%1").arg(dir), true);
}
void QmlPlayerBridge::openDependencyFolder(const QString& id) {
    const auto list = dependencies();
    const auto* d = findDependency(list, id);
    if (!d) return;
    // The ANR folder does not exist until someone creates it; make it so there is
    // somewhere to drop the files.
    const QString dir = nativePath(d->folder);
    QDir().mkpath(dir);
    if (!QDesktopServices::openUrl(QUrl::fromLocalFile(dir))) emit notice(tr("无法打开目录：%1").arg(dir), true);
}
}

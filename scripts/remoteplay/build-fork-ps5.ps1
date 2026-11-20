[CmdletBinding()]
param(
    [string]$Root = "",
    [string]$SdkRoot = "",
    [string]$DepsRoot = "",
    [string]$BuildDirectory = "",
    [string]$QtRoot = "C:/Qt/6.8.3/msvc2022_64",
    [string]$FfmpegRoot = "C:/veyra-deps/ffmpeg-prefix",
    [string]$DisplayVersion = "",
    [switch]$SkipDependencies,
    [switch]$ConfigureOnly
)
# Fork build with PS5 Remote Play compiled in.
#
# Upstream ships Remote Play only in its own release builds; the fork's local
# builds left VEYRA_ENABLE_REMOTEPLAY off, so the PS5 Streaming card only said
# that this build has no Remote Play. This script prepares the same inputs the
# upstream release used and configures the fork with Remote Play switched on:
#
#   1. vcpkg static dependencies (x64-windows-static, /MT like the app):
#      Opus, OpenSSL, curl, json-c, libevent, miniupnpc, protobuf (protoc),
#      SDL3 3.4.14 (controller only) and pkgconf.
#   2. A Python venv with the protobuf module for nanopb code generation.
#   3. The pinned chiaki-ng checkout (scripts/remoteplay/dependency-lock.json).
#   4. scripts/remoteplay/build-native.ps1: patched stage, provenance check and
#      the native initialization gate.
#   5. The fork's usual Release configuration plus Remote Play, then the
#      veyra_qml_ui target.
#
# Steps 1-3 are skipped when their outputs already exist, so a rerun only
# rebuilds the app. Everything is written under DepsRoot and BuildDirectory;
# nothing is installed system wide.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $Root) { $Root = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path }
$Root = (Resolve-Path $Root).Path
if (-not $SdkRoot) { $SdkRoot = Join-Path $Root "third_party_local" }
$SdkRoot = (Resolve-Path $SdkRoot).Path
if (-not $DepsRoot) { $DepsRoot = Join-Path $SdkRoot "remoteplay" }
if (-not $BuildDirectory) { $BuildDirectory = Join-Path $Root "out/build/fork-ps5" }
New-Item -ItemType Directory -Force -Path $DepsRoot | Out-Null
$DepsRoot = (Resolve-Path $DepsRoot).Path

$lock = Get-Content -Raw -LiteralPath (Join-Path $Root "scripts/remoteplay/dependency-lock.json") | ConvertFrom-Json
$ChiakiCommit = $lock.chiaki_commit
$SdlVersion = $lock.sdl3.version
$Triplet = "x64-windows-static"

function Step([string]$Text) { Write-Host ""; Write-Host "=== $Text" -ForegroundColor Cyan }
function Invoke-Checked([string]$Command, [string[]]$Arguments) {
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Command failed with exit code $LASTEXITCODE" }
}
function Fwd([string]$Path) { return $Path.Replace('\', '/') }

# --- MSVC environment (vswhere first, BuildTools fallback) --------------------
Step "MSVC environment"
$vsRoot = ""
$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path -LiteralPath $vswhere) {
    $vsRoot = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath) -join ""
}
if (-not $vsRoot) { $vsRoot = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools" }
$vcvars = Join-Path $vsRoot "VC\Auxiliary\Build\vcvars64.bat"
if (-not (Test-Path -LiteralPath $vcvars)) { throw "vcvars64.bat not found under $vsRoot" }
foreach ($line in (& cmd.exe /d /c "`"$vcvars`" >nul 2>&1 && set")) {
    $i = $line.IndexOf('=')
    if ($i -gt 0) { [Environment]::SetEnvironmentVariable($line.Substring(0, $i), $line.Substring($i + 1), "Process") }
}
$env:VSLANG = "1033"
if (-not (Get-Command ninja -ErrorAction SilentlyContinue)) {
    $wingetNinja = Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages") -Filter ninja.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $wingetNinja) { throw "ninja.exe not found on PATH or in WinGet packages" }
    $env:PATH = $wingetNinja.DirectoryName + ";" + $env:PATH
}
$ninja = (Get-Command ninja).Source
Write-Host "Visual Studio: $vsRoot"
Write-Host "Ninja: $ninja"

# --- 1. vcpkg static dependencies ---------------------------------------------
$vcpkgRoot = Join-Path $DepsRoot "vcpkg"
$manifestDir = Join-Path $DepsRoot "manifest"
$installRoot = Join-Path $DepsRoot "installed"
$prefix = Join-Path $installRoot $Triplet
if (-not $SkipDependencies) {
    Step "vcpkg static dependencies ($Triplet)"
    if (-not (Test-Path -LiteralPath (Join-Path $vcpkgRoot ".git"))) {
        Invoke-Checked "git" @("clone", "https://github.com/microsoft/vcpkg.git", $vcpkgRoot)
    }
    if (-not (Test-Path -LiteralPath (Join-Path $vcpkgRoot "vcpkg.exe"))) {
        Invoke-Checked (Join-Path $vcpkgRoot "bootstrap-vcpkg.bat") @("-disableMetrics")
    }
    $baseline = (& git -C $vcpkgRoot rev-parse HEAD).Trim()
    $manifest = [ordered]@{
        name = "veyra-fork-remoteplay"
        "version-string" = "1"
        "builtin-baseline" = $baseline
        dependencies = @("opus", "openssl", "curl", "json-c", "libevent", "miniupnpc", "protobuf", "sdl3", "pkgconf")
    }
    # The app asks for SDL3 $SdlVersion exactly. Pin it when this vcpkg knows
    # that version; otherwise stop with a clear message instead of a CMake error.
    $sdlVersions = Join-Path $vcpkgRoot "versions/s-/sdl3.json"
    if (-not (Select-String -LiteralPath $sdlVersions -SimpleMatch "`"$SdlVersion`"" -Quiet)) {
        throw "This vcpkg checkout has no SDL3 $SdlVersion port version; update vcpkg (git -C `"$vcpkgRoot`" pull) and rerun."
    }
    $manifest.overrides = @(@{ name = "sdl3"; version = $SdlVersion })
    New-Item -ItemType Directory -Force -Path $manifestDir | Out-Null
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $manifestDir "vcpkg.json") -Encoding UTF8
    Invoke-Checked (Join-Path $vcpkgRoot "vcpkg.exe") @("install",
        "--x-manifest-root=$manifestDir", "--x-install-root=$installRoot",
        "--triplet=$Triplet", "--host-triplet=$Triplet", "--clean-after-build")
}
$protoc = Join-Path $prefix "tools/protobuf/protoc.exe"
$pkgConfig = Join-Path $prefix "tools/pkgconf/pkgconf.exe"
foreach ($p in @($protoc, $pkgConfig, (Join-Path $prefix "share/sdl3"))) {
    if (-not (Test-Path -LiteralPath $p)) { throw "Missing dependency output: $p" }
}

# --- 2. Python venv for nanopb ------------------------------------------------
$venv = Join-Path $DepsRoot "venv"
$python = Join-Path $venv "Scripts/python.exe"
if (-not (Test-Path -LiteralPath $python)) {
    Step "Python venv for nanopb"
    $sysPython = (Get-Command python -ErrorAction SilentlyContinue)
    if (-not $sysPython) { $sysPython = (Get-Command py -ErrorAction SilentlyContinue) }
    if (-not $sysPython) { throw "Python 3 is required (python or py on PATH)" }
    Invoke-Checked $sysPython.Source @("-m", "venv", $venv)
}
# nanopb runs protoc --python_out and imports the result, so the Python
# protobuf runtime must not be older than vcpkg's protoc (libprotoc 36.2 ->
# Python protobuf 7.36.2).
# ponytail: assumes the 7.x Python line for protoc 34+; adjust when protobuf bumps majors again.
$protocVersion = ((& $protoc --version) -replace '^libprotoc\s+', '').Trim()
$wantProtobuf = "7.$protocVersion"
# Windows PowerShell 5.1 turns redirected native stderr into a terminating
# error under "Stop", so probe with "Continue".
$ErrorActionPreference = "Continue"
$haveProtobuf = (& $python -c "import google.protobuf as g; print(g.__version__)" 2>$null)
$ErrorActionPreference = "Stop"
if ("$haveProtobuf".Trim() -ne $wantProtobuf) {
    Invoke-Checked $python @("-m", "pip", "install", "--disable-pip-version-check", "protobuf==$wantProtobuf")
}
# build-native.ps1 and Chiaki's nanopb step call plain "python" and "protoc".
$env:PATH = (Join-Path $venv "Scripts") + ";" + (Split-Path -Parent $protoc) + ";" + $env:PATH

# --- 3. Pinned chiaki-ng checkout ---------------------------------------------
$chiaki = Join-Path $DepsRoot "chiaki-source"
if (-not (Test-Path -LiteralPath (Join-Path $chiaki ".git"))) {
    Step "chiaki-ng $ChiakiCommit"
    Invoke-Checked "git" @("clone", "--no-checkout", $lock.chiaki_repository, $chiaki)
    Invoke-Checked "git" @("-C", $chiaki, "checkout", "--detach", $ChiakiCommit)
    Invoke-Checked "git" @("-C", $chiaki, "submodule", "update", "--init", "--recursive")
}

# --- 4. Patched stage + native gate -------------------------------------------
Step "Chiaki stage and native gate"
$stage = Join-Path $DepsRoot "chiaki-stage"
Invoke-Checked "powershell.exe" @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
    (Join-Path $Root "scripts/remoteplay/build-native.ps1"),
    "-Root", $Root, "-ChiakiCheckout", $chiaki, "-StageDirectory", $stage,
    "-BuildDirectory", (Join-Path $DepsRoot "native-gate"),
    "-PrefixPath", $prefix, "-ProtocPath", $protoc, "-PkgConfigPath", $pkgConfig)

# --- 5. Fork app with Remote Play ---------------------------------------------
Step "Configure fork build with Remote Play"
$sdk = Fwd $SdkRoot
$cmakeArgs = @("-S", $Root, "-B", $BuildDirectory, "-G", "Ninja",
    "-DCMAKE_BUILD_TYPE=Release", "-DCMAKE_MAKE_PROGRAM=$(Fwd $ninja)",
    "-DCMAKE_PREFIX_PATH=$(Fwd $QtRoot);$(Fwd $prefix)",
    "-DVEYRA_BUILD_QML_UI=ON", "-DVEYRA_ENABLE_EXPERIMENTAL_DLSSNR=ON",
    "-DVEYRA_FFMPEG_ROOT=$(Fwd $FfmpegRoot)",
    "-DVEYRA_DLSS_SDK_ROOT=$sdk/nvidia/DLSS_SDK_310.7.0",
    "-DVEYRA_CUDA_DRIVER_INCLUDE_DIR=$sdk/nvidia/cuda-12.9-headers/include",
    "-DVEYRA_NVENC_HEADERS_ROOT=$sdk/nvidia/nv-codec-headers-13.0",
    "-DVEYRA_NVOF_SDK_ROOT=$sdk/nvidia/Optical_Flow_SDK_5.0.7",
    "-DVEYRA_XESS_ROOT=$sdk/intel/xess-3.0.2",
    "-DVEYRA_FIDELITYFX_ROOT=$sdk/amd/FidelityFX-SDK/sdk",
    "-DVEYRA_FIDELITYFX2_ROOT=$sdk/amd/FidelityFX-SDK-2.3.0/Kits/FidelityFX",
    # Chiaki and the update verifier share one static OpenSSL (/MT).
    "-DOPENSSL_ROOT_DIR=$(Fwd $prefix)", "-DOPENSSL_USE_STATIC_LIBS=ON",
    "-DVEYRA_ENABLE_REMOTEPLAY=ON",
    "-DVEYRA_RP_CHIAKI_SOURCE_DIR=$(Fwd $stage)",
    "-DVEYRA_RP_CHIAKI_VERIFY_DIR=$(Fwd $chiaki)",
    "-DPROTOC=$(Fwd $protoc)", "-DPKG_CONFIG_EXECUTABLE=$(Fwd $pkgConfig)",
    "-DPython3_EXECUTABLE=$(Fwd $python)", "-DPYTHON_EXECUTABLE=$(Fwd $python)")
if (Test-Path -LiteralPath "$SdkRoot/libdovi/lib/dovi.lib") { $cmakeArgs += "-DVEYRA_LIBDOVI_ROOT=$sdk/libdovi" }
if ($DisplayVersion) { $cmakeArgs += "-DVEYRA_DISPLAY_VERSION=$DisplayVersion" }
Invoke-Checked "cmake" $cmakeArgs
if ($ConfigureOnly) { Write-Host "Configured $BuildDirectory"; exit 0 }

Step "Build veyra_qml_ui"
Invoke-Checked "cmake" @("--build", $BuildDirectory, "--target", "veyra_qml_ui")
$exe = Join-Path $BuildDirectory "veyra_qml_ui.exe"
if (-not (Test-Path -LiteralPath $exe)) { throw "Build finished without $exe" }
Write-Host ""
Write-Host "Built $exe with PS5 Remote Play." -ForegroundColor Green

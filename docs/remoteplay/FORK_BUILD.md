# Building the fork with PS5 Remote Play

The fork's local builds used to leave `VEYRA_ENABLE_REMOTEPLAY` off, so the
PS5 Streaming card, the Settings > PS5 Streaming page and the pairing dialog
were present but reported that this build has no Remote Play. Remote Play
itself (pairing, wake, discovery, HDR/HEVC, DualSense feedback, controller
forwarding) comes from upstream Veyra 2.2.0 and feeds the same NR, SR and
frame generation chain as a capture card.

`scripts/remoteplay/build-fork-ps5.ps1` compiles it in:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/remoteplay/build-fork-ps5.ps1 `
  -SdkRoot "C:/Games/Veyra GTA VI Fork/third_party_local"
```

What it does, in order:

1. Clones vcpkg into `<SdkRoot>/remoteplay/vcpkg` and installs the static
   (`x64-windows-static`, `/MT`) dependencies: Opus, OpenSSL, curl, json-c,
   libevent, miniupnpc, protobuf, SDL3 3.4.14 and pkgconf.
2. Creates a Python venv with the `protobuf` module for nanopb.
3. Clones chiaki-ng at the commit pinned in `dependency-lock.json`.
4. Runs `build-native.ps1`: patched stage, provenance check, native gate.
5. Configures the usual fork Release build plus Remote Play in
   `out/build/fork-ps5` and builds `veyra_qml_ui`.

Steps 1 to 3 are skipped when their outputs exist. `-SkipDependencies` skips
the vcpkg step entirely; `-ConfigureOnly` stops after CMake configure.

The first run takes a while (OpenSSL, protobuf and curl compile from source).
Nothing is installed system wide; everything stays under `<SdkRoot>/remoteplay`
and the build directory.

## Using it

1. Start the app, open **PS5 Streaming** on the home page (or Settings > PS5
   Streaming).
2. Get your PSN Account ID with **Get Account ID**, then on the PS5 open
   Settings > System > Remote Play > Pair Device and enter the 8-digit PIN.
3. Connect. The stream goes through the same enhancement and frame generation
   chain as a capture card, so the PS5's 60 fps output can be generated up
   to the display rate.

The combined executable contains Chiaki (AGPLv3 with the OpenSSL exception);
see `THIRD_PARTY_NOTICES.md`.

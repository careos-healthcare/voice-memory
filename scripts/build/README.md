# Genesis release pipeline

`build_genesis.sh` builds from the local Flutter/pub cache, disables tool
telemetry, invokes Flutter with `--no-pub`, and never contains an upload action.
Run the toolchain check from the repository root:

```sh
./scripts/build/build_genesis.sh --dry-run
```

Build one or more host-compatible targets with `--targets`. Cross-compilation
is intentionally rejected: Linux AppImages are built on Linux, MSIX packages
on Windows, and Apple artifacts on macOS.

Release builds require a clean tracked Git tree so the commit and
`SOURCE_DATE_EPOCH` identify the complete source input. `--allow-dirty` exists
only for diagnostic builds and is recorded in the manifest.

Local signing inputs:

- Android: create the git-ignored `apps/voicememory_mobile/android/key.properties`
  pointing to a local release keystore.
- iOS: install the distribution identity and provisioning profile in the local
  keychain/profile store, then set `GENESIS_IOS_EXPORT_OPTIONS_PLIST` to a
  manual-signing export-options plist. No `match` repository is used.
- macOS: install the identity locally and set
  `GENESIS_MACOS_SIGN_IDENTITY`.
- Windows: set `GENESIS_WINDOWS_CERT_PFX`,
  `GENESIS_WINDOWS_CERT_PASSWORD`, and a matching
  `GENESIS_WINDOWS_PUBLISHER`.

The optional `native/runners/<platform>/` directories may contain packaged
`.so`, `.dylib`, `.framework`, or `.dll` hardware runners. Only files that
exist are copied. Every desktop bundle receives
`genesis_runtime_capabilities.json`, so MLX/CoreML/Vulkan support is never
advertised when its compiled runner is absent. The repository does not
currently ship those platform binaries; release hosts must stage audited,
locally compiled runners in that directory before building.

Outputs are written to `dist/genesis/`, with SHA-256 values in
`genesis_manifest.json`. Compiler inputs and unsigned payloads are normalized
on a best-effort basis using `SOURCE_DATE_EPOCH`. Platform signing formats may
embed certificate- or platform-controlled data, so byte-identical signed
artifacts are not promised; verify the final signed artifacts by their manifest
hashes. The build invokes `verify_genesis_manifest.py` before succeeding; it
rejects missing, extra, renamed, resized, or hash-mismatched artifacts.

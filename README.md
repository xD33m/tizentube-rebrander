# TizenTube YouTube Rebrander

Automatically downloads [TizenTube Cobalt](https://github.com/reisxd/TizenTubeCobalt),
rebrands it as "YouTube" (name + official icons), signs it, and installs it on
your Android TV device via ADB.

## Prerequisites

**Bundled in `tools/`** (no install needed):

- `apktool.jar` — APK decompiling/rebuilding
- `uber-apk-signer.jar` — APK signing (v2+v3)

**Bundled in `assets/`** (no install needed):

- YouTube for Android TV icons (all densities)
- YouTube for Android TV banner

**Must be installed on your system:**

| Tool        | Install                               |
| ----------- | ------------------------------------- |
| Java 11+    | `choco install temurin`               |
| adb         | `choco install scrcpy` (includes adb) |
| ImageMagick | `choco install imagemagick`           |
| curl        | Built into Git Bash / Windows         |

## Usage

```bash
# Basic — connects to your Android TV device and does everything
./rebrand-tizentube.sh --device-ip 192.168.0.168

# Specify a different TizenTube release
./rebrand-tizentube.sh --device-ip 192.168.0.168 --release v1.0.8

# Custom app name
./rebrand-tizentube.sh --device-ip 192.168.0.168 --app-name "YouTube"
```

## What it does

1. Downloads TizenTube Cobalt APK (arm64) from GitHub
2. Decompiles it with bundled apktool
3. Replaces name, icons, and banners from bundled assets
4. Rebuilds and signs the APK (bundled uber-apk-signer)
5. Uninstalls old TizenTube and installs the rebranded version

## Notes

- Network debugging must be enabled on your Android TV device (Settings → Developer Options → Network Debugging)
- The script uses a debug signing key — this is fine for sideloaded apps
- If you update TizenTube, just re-run the script with the new `--release` version

## Acknowledgments

This project bundles the following open-source tools:

- [apktool](https://github.com/iBotPeaches/Apktool) — Apache License 2.0
- [uber-apk-signer](https://github.com/nicoulaj/uber-apk-signer/) — Apache License 2.0

## Disclaimer

This project is not affiliated with, endorsed by, or associated with Google, YouTube, or Cobalt. YouTube and the YouTube logo are trademarks of Google LLC. All product names and trademarks are the property of their respective owners. This tool is provided for personal use only.

## License

This project is licensed under the [MIT License](LICENSE).

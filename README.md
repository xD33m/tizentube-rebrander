# Android TV Rebrander

Automatically downloads an open-source Android TV client, rebrands it as the
official app it replaces (name + real icons + real banner), signs it, and
installs it on your Android TV device via ADB.

| `--app`     | Source                                                          | Rebranded as |
| ----------- | --------------------------------------------------------------- | ------------ |
| `tizentube` | [TizenTube Cobalt](https://github.com/reisxd/TizenTubeCobalt)     | YouTube      |
| `twitch`    | [SmartTwitchTV](https://github.com/fgl27/SmartTwitchTV)           | Twitch       |

`tizentube` is the default, so existing commands keep working unchanged.

## Prerequisites

**Bundled in `tools/`** (no install needed):

- `apktool.jar` — APK decompiling/rebuilding
- `uber-apk-signer.jar` — APK signing (v2+v3)

**Bundled in `assets/`** (no install needed):

- `assets/youtube/` — YouTube for Android TV icons (all densities) and banner
- `assets/twitch/` — Twitch for Android TV icon, banner, splash and adaptive icon layers

**Must be installed on your system:**

| Tool        | Install (Windows, winget)                        | Install (macOS, brew)              |
| ----------- | ------------------------------------------------ | ---------------------------------- |
| Java 11+    | `winget install EclipseAdoptium.Temurin.21.JDK`  | `brew install --cask temurin`      |
| adb         | `winget install Google.PlatformTools`            | `brew install android-platform-tools` |
| ImageMagick | `winget install ImageMagick.ImageMagick`         | `brew install imagemagick`         |
| curl        | Built into Git Bash / Windows                    | Built in                           |

The script detects missing dependencies on startup and offers to install them for
you via winget, choco, brew, apt, dnf, or pacman. On Windows, open a **new**
terminal after an install so the new tools are on your PATH.

## Usage

```bash
# Basic — connects to your Android TV device, fetches latest release, and does everything
./rebrand-tizentube.sh --device-ip 192.168.0.168

# Rebrand SmartTwitchTV as Twitch instead
./rebrand-tizentube.sh --app twitch --device-ip 192.168.0.168

# Pin a specific release (tag as it appears on GitHub)
./rebrand-tizentube.sh --device-ip 192.168.0.168 --release v1.0.8
./rebrand-tizentube.sh --app twitch --device-ip 192.168.0.168 --release 379

# Custom app name
./rebrand-tizentube.sh --device-ip 192.168.0.168 --app-name "YouTube"

# Dry run — build the APK without connecting to or installing on a device
./rebrand-tizentube.sh --dry-run
./rebrand-tizentube.sh --app twitch --dry-run
```

## What it does

1. Downloads the chosen app's APK from GitHub (ABI-matched for TizenTube, by
   filename pattern for SmartTwitchTV)
2. Decompiles it with bundled apktool
3. Replaces name, icons, and banners from that app's bundled assets
4. Rebuilds and signs the APK (bundled uber-apk-signer)
5. Uninstalls the old app and installs the rebranded version

## Notes

- Network debugging must be enabled on your Android TV device (Settings → Developer Options → Network Debugging)
- The script uses a debug signing key — this is fine for sideloaded apps
- Installing replaces the existing app, so its local settings and logins are lost
- If `--release` is omitted, the latest release is automatically fetched from GitHub
- Supports [NO_COLOR](https://no-color.org/) — set `NO_COLOR=1` to disable colored output

## Acknowledgments

This project bundles the following open-source tools:

- [apktool](https://github.com/iBotPeaches/Apktool) — Apache License 2.0
- [uber-apk-signer](https://github.com/patrickfav/uber-apk-signer) — Apache License 2.0

## Disclaimer

This project is not affiliated with, endorsed by, or associated with Google, YouTube, Cobalt, Twitch, or Amazon. YouTube and the YouTube logo are trademarks of Google LLC. Twitch and the Twitch logo are trademarks of Twitch Interactive, Inc. All product names and trademarks are the property of their respective owners. This tool is provided for personal use only.

## License

This project is licensed under the [MIT License](LICENSE).

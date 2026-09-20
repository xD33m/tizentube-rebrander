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

## Adding another app

Each app is one `case` branch in the profile block near the top of the script.
A profile sets the GitHub repo, package name, asset directory and new name, then
lists an `ASSET_MAP` of `"<file under assets/<app>/>|<path inside the APK>"`
pairs. Each source image is resized to the dimensions of the file it replaces, so
the mapping is all you need — find the paths by decompiling the APK once with
`java -jar tools/apktool.jar d <apk>` and looking at what `android:icon` and
`android:banner` point to in `AndroidManifest.xml`.

## Where the assets came from

The icons and banners in `assets/` are the real ones, extracted from the official
apps installed on an Android TV device:

- `assets/twitch/banners/app_banner.png` and `assets/twitch/icons/ic_launcher.png`
  are unmodified files from the official Twitch app (`tv.twitch.android.app`).
  Note the launcher icon and banner live in the app's density split APK
  (`split_config.xhdpi.apk`), not in `base.apk`.
- The adaptive icon layers and the splash image are composed from those same
  files: the glitch mark lifted onto transparency for the foreground, and the
  brand purple `#9146FF` sampled from the originals for the background.

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

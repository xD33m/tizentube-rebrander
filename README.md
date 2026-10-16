# Android TV Rebrander

[![CI](https://github.com/xD33m/tizentube-rebrander/actions/workflows/ci.yml/badge.svg)](https://github.com/xD33m/tizentube-rebrander/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/github/license/xD33m/tizentube-rebrander)](LICENSE)

One Bash script that turns an open-source Android TV client into a drop-in
lookalike of the official app: download, patch, sign and install over ADB in a
single command.

## What it automates

```
GitHub release ─▶ download APK ─▶ apktool decode ─▶ patch name, icons, banners
               ─▶ apktool build ─▶ sign (v2+v3) ─▶ adb install on the TV
```

By hand this is a dozen steps across four tools: look up the latest release,
pick the APK for the TV's CPU, decompile it, edit `strings.xml` and
`AndroidManifest.xml`, resize every icon and banner to the exact dimensions the
APK already uses, rebuild, sign, connect to the TV and install without losing the
app's data. `rebrand.sh` does all of it, and stops with a clear error message
when a step fails.

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

You also need an Android TV device with **network debugging** enabled
(Settings → Developer Options → Network Debugging), or one already connected to
`adb` over USB. The script runs in Bash: Git Bash on Windows, or the default
shell on macOS and Linux.

## Usage

```bash
# Basic — connects to your Android TV device, fetches latest release, and does everything
./rebrand.sh --device-ip 192.168.0.168

# Rebrand SmartTwitchTV as Twitch instead
./rebrand.sh --app twitch --device-ip 192.168.0.168

# Pin a specific release (tag as it appears on GitHub)
./rebrand.sh --device-ip 192.168.0.168 --release v1.0.8
./rebrand.sh --app twitch --device-ip 192.168.0.168 --release 379

# Custom app name
./rebrand.sh --device-ip 192.168.0.168 --app-name "YouTube"

# Dry run — build the APK without connecting to or installing on a device
./rebrand.sh --dry-run
./rebrand.sh --app twitch --dry-run

# Force a fresh download, ignoring the cached APK
./rebrand.sh --app twitch --device-ip 192.168.0.168 --no-cache

# Wipe the app's data instead of updating it in place
./rebrand.sh --app twitch --device-ip 192.168.0.168 --clean-install
```

Run `./rebrand.sh --help` for the full option list.

## How it works

1. Downloads the chosen app's APK from GitHub (ABI-matched for TizenTube, by
   filename pattern for SmartTwitchTV)
2. Decompiles it with bundled apktool
3. Replaces name, icons, and banners from that app's bundled assets
4. Rebuilds and signs the APK (bundled uber-apk-signer), copying it to `dist/`
5. Installs it, updating in place when it can and falling back to a clean install

In more detail:

- **Preflight.** Checks for `java`, `adb`, `curl` and ImageMagick (`magick`, or
  ImageMagick 6's `convert`, ignoring Windows' unrelated `convert.exe`), and for
  the bundled jars and assets. A missing tool can be installed on the spot with
  the detected package manager.
- **Release lookup.** Without `--release`, the latest tag comes from the GitHub
  releases API. TizenTube Cobalt publishes one APK per ABI, so the script reads
  `ro.product.cpu.abilist` from the device and picks `cobalt-arm64.apk` or
  `cobalt-arm.apk`. SmartTwitchTV publishes one APK whose name carries the
  version, so it is found by matching the release's asset names.
- **Device checks.** `adb connect` output and `adb devices -l` are checked
  separately for "unauthorized" and "offline", each with its own fix-it message.
- **Patching.** The app name is replaced in `res/values/strings.xml` and in every
  `label` attribute of `AndroidManifest.xml`, for both the `android:` prefix and
  the `n0:`/`n1:` prefixes apktool 3.x emits. `extractNativeLibs` is switched
  from `false` to `true` for the rebuilt APK. Each bundled image is resized to the exact
  size of the file it replaces, and file names that apktool 3.x writes without an
  extension are handled.
- **Safety nets.** `set -euo pipefail` throughout; downloads go to a `.part` file
  that is only moved into the cache once complete; the run fails if no image was
  replaced, which is the signal that the upstream APK layout changed.

## Limitations

- **Two apps.** Only the TizenTube Cobalt and SmartTwitchTV profiles exist.
- **Only the look changes.** The app name, icons and banners are replaced; the
  package name and code stay the upstream app's. It installs next to the official
  app, not in place of it.
- **ARM only for TizenTube.** Devices reporting an ABI other than `arm64-v8a`,
  `armeabi-v7a` or `armeabi` are rejected, because those are the APKs the project
  publishes. `--dry-run` builds the arm64 APK.
- **Debug signing key.** Builds are signed with uber-apk-signer's debug key. That
  is fine for sideloading onto your own TV and keeps updates in place, but it is
  not a key to publish APKs with.
- **Tied to upstream layouts.** Asset names, resource paths and release file
  names are hard-coded per profile. If an upstream release changes them, the run
  stops with an error rather than producing a half-rebranded APK.
- **Unauthenticated GitHub API.** The release lookup does not use a token, so it
  is subject to GitHub's anonymous rate limit. Pin `--release` if you hit it.
- **Interactive.** A missing dependency triggers a `[Y/n]` prompt, so the
  script is meant to be run from a terminal.
- **No device in CI.** CI runs ShellCheck, a syntax and line ending check and a
  CLI smoke test. The download, patch and install path is verified by hand on a
  real device.

## Output and caching

| Path      | Contents                                                              |
| --------- | --------------------------------------------------------------------- |
| `build/`  | Scratch space — decompiled sources and intermediates. Wiped each run.  |
| `dist/`   | Signed APKs, one per app and release tag. Survives failed runs.        |
| `.cache/` | Downloaded upstream APKs, keyed by app and release tag.                |

A release tag's APK never changes, so it is downloaded once and reused — worth
having when TizenTube Cobalt is a 160 MB download. Pass `--no-cache` to force a
fresh download. All three directories are gitignored.

## Keeping your app data

Every build is signed with uber-apk-signer's debug key, and that key is the same
every time. So once an app has been rebranded, later runs update it in place with
`adb install -r` and its settings and logins survive.

A clean install (uninstall first, data lost) only happens when the installed copy
has a different signature — the upstream release, or nothing installed yet. Pass
`--clean-install` to force one.

## Notes

- Network debugging must be enabled on your Android TV device (Settings → Developer Options → Network Debugging)
- The script uses a debug signing key — this is fine for sideloaded apps
- A clean install (first install, or `--clean-install`) wipes the app's local settings and logins; later runs update in place and keep them
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

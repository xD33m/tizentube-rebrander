#!/usr/bin/env bash
#
# rebrand-tizentube.sh
#
# Automatically downloads TizenTube Cobalt, rebrands it as "YouTube" using
# bundled icons from the official YouTube for Android TV app, then rebuilds,
# signs, and installs it on a connected Android TV device.
#
# Bundled in tools/:
#   - apktool.jar
#   - uber-apk-signer.jar
#
# Must be pre-installed on the system:
#   - java  (JDK 11+)    — choco install temurin / brew install temurin / apt install default-jdk
#   - adb               — choco install scrcpy / brew install android-platform-tools / apt install adb
#   - ImageMagick       — choco install imagemagick / brew install imagemagick / apt install imagemagick
#   - curl              — built into most systems
#
# Usage:
#   ./rebrand-tizentube.sh [--device-ip 192.168.0.168] [--release v1.0.8]
#   If --release is omitted, the latest release is fetched from GitHub.
#

set -euo pipefail

# ──────────────────────────── defaults ────────────────────────────
DEVICE_IP="${DEVICE_IP:-}"
RELEASE="${RELEASE:-}"
ADB_PORT="5555"
TIZENTUBE_REPO="reisxd/TizenTubeCobalt"
TIZENTUBE_PACKAGE="io.gh.reisxd.tizentube.cobalt"
NEW_APP_NAME="YouTube"
DRY_RUN=false

# Resolve script directory for local assets and tools
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="${SCRIPT_DIR}/assets"
TOOLS_DIR="${SCRIPT_DIR}/tools"
APKTOOL_JAR="${TOOLS_DIR}/apktool.jar"
UBER_SIGNER_JAR="${TOOLS_DIR}/uber-apk-signer.jar"
WORK_DIR="${SCRIPT_DIR}/build"

# ──────────────────────────── parse args ──────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --device-ip) [[ -n "${2:-}" ]] || fail "--device-ip requires an argument"; DEVICE_IP="$2"; shift 2 ;;
    --release)   [[ -n "${2:-}" ]] || fail "--release requires an argument"; RELEASE="$2"; shift 2 ;;
    --app-name)  [[ -n "${2:-}" ]] || fail "--app-name requires an argument"; NEW_APP_NAME="$2"; shift 2 ;;
    --dry-run)   DRY_RUN=true; shift ;;
    --help|-h)
      echo "Usage: $0 [--device-ip IP] [--release vX.Y.Z] [--app-name NAME] [--dry-run]"
      exit 0 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

# ──────────────────────────── helpers ─────────────────────────────
if [[ -z "${NO_COLOR:-}" ]] && [[ -t 1 ]]; then
  info()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
  ok()    { echo -e "\033[1;32m[OK]\033[0m    $*"; }
  warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
  fail()  { echo -e "\033[1;31m[FAIL]\033[0m  $*"; exit 1; }
else
  info()  { echo "[INFO]  $*"; }
  ok()    { echo "[OK]    $*"; }
  warn()  { echo "[WARN]  $*"; }
  fail()  { echo "[FAIL]  $*"; exit 1; }
fi

# Cross-platform sed -i (macOS requires backup suffix)
sedi() {
  if sed --version &>/dev/null; then
    sed -i "$@"       # GNU sed
  else
    sed -i '' "$@"    # BSD/macOS sed
  fi
}

# Extract image dimensions using ImageMagick identify
get_image_size() {
  if [[ "$MAGICK" == "magick" ]]; then
    MSYS_NO_PATHCONV=1 magick identify -format '%w %h' "$1" 2>/dev/null || true
  else
    identify -format '%w %h' "$1" 2>/dev/null || true
  fi
}

# Resize wrapper that suppresses MSYS path mangling on Windows
magick_resize() {
  MSYS_NO_PATHCONV=1 "$MAGICK" "$1" -resize "${2}x${3}!" "$4"
}

# ──────────────────────────── package manager detection ───────────
detect_pkg_manager() {
  if command -v choco &>/dev/null; then
    echo "choco"
  elif command -v brew &>/dev/null; then
    echo "brew"
  elif command -v apt-get &>/dev/null; then
    echo "apt"
  elif command -v dnf &>/dev/null; then
    echo "dnf"
  elif command -v pacman &>/dev/null; then
    echo "pacman"
  else
    echo ""
  fi
}

# Map a dependency name to the install command for each package manager
pkg_install_cmd() {
  local dep="$1" pm="$2"
  case "$dep" in
    java)
      case "$pm" in
        choco)  echo "choco install -y temurin" ;;
        brew)   echo "brew install --cask temurin" ;;
        apt)    echo "sudo apt-get install -y default-jdk" ;;
        dnf)    echo "sudo dnf install -y java-17-openjdk" ;;
        pacman) echo "sudo pacman -S --noconfirm jdk-openjdk" ;;
      esac ;;
    adb)
      case "$pm" in
        choco)  echo "choco install -y scrcpy" ;;
        brew)   echo "brew install android-platform-tools" ;;
        apt)    echo "sudo apt-get install -y adb" ;;
        dnf)    echo "sudo dnf install -y android-tools" ;;
        pacman) echo "sudo pacman -S --noconfirm android-tools" ;;
      esac ;;
    imagemagick)
      case "$pm" in
        choco)  echo "choco install -y imagemagick" ;;
        brew)   echo "brew install imagemagick" ;;
        apt)    echo "sudo apt-get install -y imagemagick" ;;
        dnf)    echo "sudo dnf install -y ImageMagick" ;;
        pacman) echo "sudo pacman -S --noconfirm imagemagick" ;;
      esac ;;
    curl)
      case "$pm" in
        choco)  echo "choco install -y curl" ;;
        brew)   echo "brew install curl" ;;
        apt)    echo "sudo apt-get install -y curl" ;;
        dnf)    echo "sudo dnf install -y curl" ;;
        pacman) echo "sudo pacman -S --noconfirm curl" ;;
      esac ;;
  esac
}

# Prompt user to auto-install a missing dependency, or fail
prompt_install() {
  local dep="$1" pm="$2"
  local cmd
  cmd=$(pkg_install_cmd "$dep" "$pm")
  if [[ -z "$cmd" ]]; then
    fail "'$dep' is not installed and no supported package manager was found. Install it manually and re-run."
  fi
  warn "'$dep' is not installed."
  read -rp "       Install it now with: $cmd ? [Y/n] " answer
  answer="${answer:-y}"
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    info "Running: $cmd"
    $cmd || fail "Failed to install '$dep'. Install it manually and re-run."
    ok "'$dep' installed."
  else
    fail "'$dep' is required. Install it manually and re-run."
  fi
}

# Check for a command; offer to install if missing
check_or_install() {
  local cmd_name="$1" dep_name="$2"
  if ! command -v "$cmd_name" &>/dev/null; then
    prompt_install "$dep_name" "$PKG_MANAGER"
    # Re-check after install
    command -v "$cmd_name" &>/dev/null || fail "'$cmd_name' still not found after install attempt."
  fi
}

# ──────────────────────────── preflight ───────────────────────────
info "Checking prerequisites..."

PKG_MANAGER=$(detect_pkg_manager)
if [[ -n "$PKG_MANAGER" ]]; then
  info "Detected package manager: $PKG_MANAGER"
else
  info "No supported package manager detected — missing deps must be installed manually."
fi

check_or_install java java
check_or_install adb adb
check_or_install curl curl

# Detect ImageMagick command (v7 uses magick, v6 uses convert)
if command -v magick &>/dev/null; then
  MAGICK=magick
elif command -v convert &>/dev/null; then
  MAGICK=convert
else
  prompt_install imagemagick "$PKG_MANAGER"
  # Re-detect after install
  if command -v magick &>/dev/null; then
    MAGICK=magick
  elif command -v convert &>/dev/null; then
    MAGICK=convert
  else
    fail "ImageMagick still not found after install attempt."
  fi
fi

[[ -f "$APKTOOL_JAR" ]]      || fail "apktool.jar not found at ${APKTOOL_JAR}"
[[ -f "$UBER_SIGNER_JAR" ]]  || fail "uber-apk-signer.jar not found at ${UBER_SIGNER_JAR}"
[[ -d "${ASSETS_DIR}/icons" ]] || fail "Icon assets not found at ${ASSETS_DIR}/icons"
ok "All prerequisites found (bundled tools + system commands)."

# ──────────────────────────── resolve release ─────────────────────
if [[ -z "$RELEASE" ]]; then
  info "No --release specified, fetching latest from GitHub..."
  RELEASE=$(curl -sL "https://api.github.com/repos/${TIZENTUBE_REPO}/releases/latest" \
    | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name":\s*"([^"]+)".*/\1/') \
    || true
  if [[ -z "$RELEASE" ]]; then
    fail "Could not determine latest release. Specify one with --release vX.Y.Z"
  fi
  ok "Latest release: ${RELEASE}"
fi

# ──────────────────────────── connect device ──────────────────────
if [[ "$DRY_RUN" != true ]]; then
  if [[ -n "$DEVICE_IP" ]]; then
    info "Connecting to device at ${DEVICE_IP}:${ADB_PORT}..."
    ADB_CONNECT_OUT=$(adb connect "${DEVICE_IP}:${ADB_PORT}" 2>&1) || true
    if ! echo "$ADB_CONNECT_OUT" | grep -qE "connected|already"; then
      fail "Could not connect to device: ${ADB_CONNECT_OUT}\n       Check IP and that network debugging is enabled."
    fi
    ok "Connected to device."
  else
    info "No --device-ip provided, assuming device is already connected."
  fi

  # Verify device is reachable
  ADB_DEVICES_OUT=$(adb devices -l 2>&1)
  if echo "$ADB_DEVICES_OUT" | tail -n +2 | grep -q "unauthorized"; then
    fail "Device is connected but unauthorized.\n       Check the TV screen for an ADB authorization prompt and tap 'Always allow from this computer'.\n       If no prompt appears, revoke USB debugging authorizations in Developer Options and reconnect."
  elif echo "$ADB_DEVICES_OUT" | tail -n +2 | grep -q "offline"; then
    fail "Device is connected but offline. Try: adb disconnect ${DEVICE_IP}:${ADB_PORT} && adb connect ${DEVICE_IP}:${ADB_PORT}"
  elif ! echo "$ADB_DEVICES_OUT" | tail -n +2 | grep -qE '\bdevice\b'; then
    fail "No ADB device found. 'adb devices -l' output:\n${ADB_DEVICES_OUT}"
  fi
  ok "ADB device detected."
else
  info "Dry run — skipping device connection."
fi

# ──────────────────────────── detect device ABI ──────────────────
if [[ "$DRY_RUN" != true ]]; then
  DEVICE_ABI=$(adb shell getprop ro.product.cpu.abilist 2>/dev/null | tr -d '\r' | cut -d',' -f1)
  case "$DEVICE_ABI" in
    arm64-v8a)  APK_VARIANT="cobalt-arm64.apk" ;;
    armeabi-v7a|armeabi) APK_VARIANT="cobalt-arm.apk" ;;
    *) fail "Unsupported device ABI: ${DEVICE_ABI:-unknown}. Available APKs: cobalt-arm64.apk, cobalt-arm.apk" ;;
  esac
  info "Detected device ABI: ${DEVICE_ABI} → ${APK_VARIANT}"
else
  APK_VARIANT="cobalt-arm64.apk"
  info "Dry run — defaulting to ${APK_VARIANT}"
fi
TIZENTUBE_APK_URL="https://github.com/${TIZENTUBE_REPO}/releases/download/${RELEASE}/${APK_VARIANT}"

# ──────────────────────────── work dir ────────────────────────────
if [[ -d "$WORK_DIR" ]]; then
  if [[ -d "${WORK_DIR}/signed" ]]; then
    warn "Previous build found in ${WORK_DIR}/signed — it will be overwritten."
  fi
  rm -rf "$WORK_DIR"
fi
mkdir -p "$WORK_DIR"
info "Working directory: $WORK_DIR"

# ──────────────────────────── download TizenTube ──────────────────
TIZENTUBE_APK="${WORK_DIR}/${APK_VARIANT}"
info "Downloading TizenTube Cobalt ${RELEASE}..."
curl -L --fail -o "$TIZENTUBE_APK" "$TIZENTUBE_APK_URL" \
  || fail "Failed to download TizenTube from $TIZENTUBE_APK_URL"
ok "Downloaded TizenTube Cobalt ($(du -h "$TIZENTUBE_APK" | cut -f1))."

# ──────────────────────────── decompile TizenTube ─────────────────
COBALT_DIR="${WORK_DIR}/cobalt-decompiled"
info "Decompiling TizenTube..."
java -jar "$APKTOOL_JAR" d "$TIZENTUBE_APK" -o "$COBALT_DIR" -f &>/dev/null \
  || fail "apktool decompile failed"
ok "Decompiled TizenTube."

# ──────────────────────────── change app name ─────────────────────
info "Changing app name to '${NEW_APP_NAME}'..."

# Escape special sed characters in app name
SAFE_APP_NAME=$(printf '%s' "$NEW_APP_NAME" | sed 's/[&\\|/]/\\&/g')

# strings.xml
STRINGS_FILE="${COBALT_DIR}/res/values/strings.xml"
if [[ -f "$STRINGS_FILE" ]]; then
  sedi "s|<string name=\"app_name\">.*</string>|<string name=\"app_name\">${SAFE_APP_NAME}</string>|" "$STRINGS_FILE"
fi

# AndroidManifest.xml label
MANIFEST="${COBALT_DIR}/AndroidManifest.xml"
sedi "s|android:label=\"[^\"]*\"|android:label=\"${SAFE_APP_NAME}\"|g" "$MANIFEST"

# Fix extractNativeLibs for rebuilt APK
sedi 's|android:extractNativeLibs=\"false\"|android:extractNativeLibs=\"true\"|' "$MANIFEST"

ok "App name set to '${NEW_APP_NAME}'."

# ──────────────────────────── replace icons (from local assets) ───
info "Replacing icons from bundled assets..."

if [[ ! -d "${ASSETS_DIR}/icons" ]]; then
  fail "Assets directory not found at ${ASSETS_DIR}/icons. Run from the script's directory."
fi

for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  src="${ASSETS_DIR}/icons/ic_launcher_${density}.png"
  dst="${COBALT_DIR}/res/mipmap-${density}/ic_app.png"
  if [[ -f "$src" ]] && [[ -f "$dst" ]]; then
    dims=$(get_image_size "$dst")
    if [[ -n "$dims" ]]; then
      w=$(echo "$dims" | cut -d' ' -f1)
      h=$(echo "$dims" | cut -d' ' -f2)
      magick_resize "$src" "$w" "$h" "$dst" \
        || fail "ImageMagick failed to resize icon for ${density} (${w}x${h})"
    else
      cp "$src" "$dst"
    fi
  fi
done
ok "Icons replaced."

# ──────────────────────────── replace banners (from local assets) ─
info "Replacing banners..."
YT_BANNER="${ASSETS_DIR}/banners/app_banner.png"
if [[ -f "$YT_BANNER" ]]; then
  for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
    dst="${COBALT_DIR}/res/drawable-${density}/app_banner.png"
    if [[ -f "$dst" ]]; then
      dims=$(get_image_size "$dst")
      if [[ -n "$dims" ]]; then
        w=$(echo "$dims" | cut -d' ' -f1)
        h=$(echo "$dims" | cut -d' ' -f2)
        magick_resize "$YT_BANNER" "$w" "$h" "$dst" \
          || fail "ImageMagick failed to resize banner for ${density} (${w}x${h})"
      else
        cp "$YT_BANNER" "$dst"
      fi
    fi
  done
  ok "Banners replaced."
else
  info "No banner asset found at ${YT_BANNER}, skipping."
fi

# ──────────────────────────── rebuild APK ─────────────────────────
UNSIGNED_APK="${WORK_DIR}/cobalt-unsigned.apk"
info "Rebuilding APK..."
java -jar "$APKTOOL_JAR" b "$COBALT_DIR" -o "$UNSIGNED_APK" &>/dev/null \
  || fail "apktool build failed"
ok "APK rebuilt."

# ──────────────────────────── sign APK ────────────────────────────
SIGNED_DIR="${WORK_DIR}/signed"
info "Signing APK with uber-apk-signer (v2+v3)..."
java -jar "$UBER_SIGNER_JAR" -a "$UNSIGNED_APK" -o "$SIGNED_DIR" 2>&1 | tail -5

SIGNED_APK=$(find "$SIGNED_DIR" -name "*.apk" ! -name "*.idsig" | head -1)
if [[ -z "$SIGNED_APK" ]] || [[ ! -f "$SIGNED_APK" ]]; then
  fail "Signing failed — no signed APK produced."
fi
ok "APK signed: $(basename "$SIGNED_APK")"

# ──────────────────────────── install on device ───────────────────
if [[ "$DRY_RUN" == true ]]; then
  info "Dry run — skipping uninstall/install. Signed APK at: ${SIGNED_APK}"
else
  info "Uninstalling old TizenTube (${TIZENTUBE_PACKAGE})..."
  adb uninstall "$TIZENTUBE_PACKAGE" &>/dev/null || true

  info "Installing rebranded APK..."
  adb install "$SIGNED_APK" 2>&1 | tail -3

  # Verify
  if adb shell pm list packages | grep -q "$TIZENTUBE_PACKAGE"; then
    ok "Successfully installed! '${NEW_APP_NAME}' is now on your device."
  else
    fail "Installation may have failed. Check your device."
  fi
fi

# ──────────────────────────── cleanup ─────────────────────────────
info "Keeping signed APK at: ${SIGNED_APK}"
info "Working directory: ${WORK_DIR}"
echo ""
ok "All done! TizenTube Cobalt is now disguised as '${NEW_APP_NAME}' on your device."

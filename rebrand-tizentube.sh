#!/usr/bin/env bash
#
# Renamed to rebrand.sh once this tool grew past TizenTube. Kept so existing
# commands, scripts and bookmarks keep working.
#
set -euo pipefail
echo "[WARN]  rebrand-tizentube.sh is now rebrand.sh - forwarding." >&2
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/rebrand.sh" "$@"

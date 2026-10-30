#!/usr/bin/env bash
# Run on PC (Git Bash/WSL) from repo root — pulls device dumps into backup_porsche/
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEST="${REPO_ROOT}/backup_porsche/partitions"
REMOTE="${REMOTE:-/sdcard/nethunter_backup}"

mkdir -p "$DEST"
adb devices
adb pull "$REMOTE" "$DEST"
echo "Saved under $DEST (gitignored)"

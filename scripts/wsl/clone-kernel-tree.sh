#!/usr/bin/env bash
# Interactive helper to clone sm8350 kernel + porsche device tree (Phase 5).
# Does NOT clone unless CONFIRM=1 — repos are multi-GB.
#
# Usage:
#   ROM=lineage|pixelos KERNEL_DIR=~/android/kernel ./clone-kernel-tree.sh
#   CONFIRM=1 ROM=lineage KERNEL_DIR=~/android/kernel ./clone-kernel-tree.sh
#
# Run from WSL2. Project path (Windows): nethunter-realme-gt2-porsche/scripts/wsl/

set -euo pipefail

ROM="${ROM:-}"
KERNEL_DIR="${KERNEL_DIR:-${HOME}/android/kernel}"
DEVICE_DIR="${DEVICE_DIR:-${HOME}/android/device/realme_porsche}"
CONFIRM="${CONFIRM:-0}"

# --- Documented clone URLs (verify branch/tag against your ROM before CONFIRM=1) ---
#
# LineageOS (shared OnePlus sm8350 kernel + realme porsche device tree):
#   Kernel:  https://github.com/LineageOS/android_kernel_oneplus_sm8350
#   Device:  https://github.com/LineageOS/android_device_realme_porsche
#   Branch:  match LineageOS 23 / your ROM manifest (e.g. lineage-23.0 or device default)
#
# PixelOS:
#   Kernel:  https://github.com/PixelOS-Devices/kernel_oneplus_sm8350
#   Device:  https://github.com/PixelOS-Devices/android_device_realme_porsche
#   Branch:  match PixelOS 16 for porsche (see pixelos.net download page / device repo)
#
# Unofficial device tree mirror (Lineage-based):
#   https://github.com/pjgowtham/android_device_realme_porsche

lineage_kernel_url="https://github.com/LineageOS/android_kernel_oneplus_sm8350.git"
lineage_device_url="https://github.com/LineageOS/android_device_realme_porsche.git"
pixelos_kernel_url="https://github.com/PixelOS-Devices/kernel_oneplus_sm8350.git"
pixelos_device_url="https://github.com/PixelOS-Devices/android_device_realme_porsche.git"

usage() {
  cat <<'EOF'
Clone kernel + device tree for Realme GT 2 (porsche / sm8350).

Environment:
  ROM          lineage | pixelos   (required)
  KERNEL_DIR   kernel checkout     (default: ~/android/kernel)
  DEVICE_DIR   device tree path     (default: ~/android/device/realme_porsche)
  CONFIRM      1 to run git clone   (default: 0 = dry-run only)
  KERNEL_BRANCH optional branch/tag for kernel repo
  DEVICE_BRANCH optional branch/tag for device repo

Examples:
  ROM=lineage ./clone-kernel-tree.sh
  CONFIRM=1 ROM=pixelos KERNEL_DIR=~/android/kernel ./clone-kernel-tree.sh
EOF
}

if [[ -z "${ROM}" ]]; then
  usage
  echo ""
  read -r -p "ROM (lineage|pixelos): " ROM
fi

ROM="$(echo "${ROM}" | tr '[:upper:]' '[:lower:]')"

case "${ROM}" in
  lineage)
    KERNEL_URL="${lineage_kernel_url}"
    DEVICE_URL="${lineage_device_url}"
    DEFAULT_KERNEL_BRANCH="${KERNEL_BRANCH:-lineage-23.0}"
    DEFAULT_DEVICE_BRANCH="${DEVICE_BRANCH:-lineage-23.0}"
    ;;
  pixelos)
    KERNEL_URL="${pixelos_kernel_url}"
    DEVICE_URL="${pixelos_device_url}"
    DEFAULT_KERNEL_BRANCH="${KERNEL_BRANCH:-sixteen}"
    DEFAULT_DEVICE_BRANCH="${DEVICE_BRANCH:-sixteen}"
    ;;
  *)
    echo "ERROR: ROM must be 'lineage' or 'pixelos', got: ${ROM}" >&2
    exit 1
    ;;
esac

KERNEL_BRANCH="${KERNEL_BRANCH:-${DEFAULT_KERNEL_BRANCH}}"
DEVICE_BRANCH="${DEVICE_BRANCH:-${DEFAULT_DEVICE_BRANCH}}"

echo "=== NetHunter porsche kernel clone plan (dry-run unless CONFIRM=1) ==="
echo "ROM:           ${ROM}"
echo "KERNEL_DIR:    ${KERNEL_DIR}"
echo "KERNEL_URL:    ${KERNEL_URL}"
echo "KERNEL_BRANCH: ${KERNEL_BRANCH}"
echo "DEVICE_DIR:    ${DEVICE_DIR}"
echo "DEVICE_URL:    ${DEVICE_URL}"
echo "DEVICE_BRANCH: ${DEVICE_BRANCH}"
echo "CONFIRM:       ${CONFIRM}"
echo ""
echo "Disk: ensure ~40-60 GB free before cloning."
echo "Next: clone kali-nethunter-kernel-builder inside KERNEL_DIR (see docs/phases/05-build-kernel-detailed.md)."
echo ""

if [[ "${CONFIRM}" != "1" ]]; then
  echo "Dry run only. Set CONFIRM=1 to execute git clone."
  exit 0
fi

command -v git >/dev/null 2>&1 || { echo "git not found"; exit 1; }

if [[ -d "${KERNEL_DIR}/.git" ]]; then
  echo "SKIP kernel: ${KERNEL_DIR} already a git repo"
else
  mkdir -p "$(dirname "${KERNEL_DIR}")"
  echo "Cloning kernel..."
  git clone -b "${KERNEL_BRANCH}" --depth 1 "${KERNEL_URL}" "${KERNEL_DIR}" || {
    echo "WARN: shallow clone failed; retry without --depth 1 or fix branch name (${KERNEL_BRANCH})" >&2
    exit 1
  }
fi

if [[ -d "${DEVICE_DIR}/.git" ]]; then
  echo "SKIP device: ${DEVICE_DIR} already a git repo"
else
  mkdir -p "$(dirname "${DEVICE_DIR}")"
  echo "Cloning device tree..."
  git clone -b "${DEVICE_BRANCH}" --depth 1 "${DEVICE_URL}" "${DEVICE_DIR}" || {
    echo "WARN: device clone failed; check branch (${DEVICE_BRANCH}) or URL" >&2
    exit 1
  }
fi

echo "Done. Verify porsche DTS/defconfig in ${KERNEL_DIR} before building."

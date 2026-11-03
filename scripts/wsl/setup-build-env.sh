#!/usr/bin/env bash
# Install Ubuntu packages for Kali NetHunter / Android kernel builds (SM8350, etc.).
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: setup-build-env.sh [OPTIONS]

Installs build dependencies on Ubuntu (WSL2 or native) for kernel development.

Options:
  -n, --dry-run   Print apt commands without installing (requires sudo for apt-get -s).
  -h, --help      Show this help and exit.

Optional Kali NetHunter tooling (not installed by default):
  On Kali or Debian-based hosts you may also want:
    kali-nethunter-kernel-builder dependencies from its README
    android-sdk-libsparse-utils, device-tree-compiler (dtc), lz4, zstd, cpio
    cross-compilers if not using Clang-only builds (e.g. gcc-aarch64-linux-gnu)

Suggested kernel tree location after cloning kali-nethunter-kernel-builder:
  ~/android/kernel/sm8350
EOF
}

DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -f /proc/version ]] || ! grep -qi microsoft /proc/version 2>/dev/null; then
  echo "Warning: this does not look like WSL; continuing anyway." >&2
fi

APT_PACKAGES=(
  build-essential
  bc
  bison
  flex
  libssl-dev
  clang
  lld
  python3
  python3-pip
  git
  ccache
  zip
  curl
  wget
  repo
  ca-certificates
  gnupg
  file
  rsync
  pkg-config
)

echo "Target: $(lsb_release -ds 2>/dev/null || echo 'unknown Ubuntu/Debian')"
echo "Packages: ${APT_PACKAGES[*]}"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[dry-run] sudo apt-get update"
  echo "[dry-run] sudo apt-get install -y --no-install-recommends ${APT_PACKAGES[*]}"
  if apt-cache show repo &>/dev/null; then
    echo "[dry-run] repo package is available in configured apt sources."
  else
    echo "[dry-run] note: 'repo' may be missing from default sources; install via:"
    echo "  sudo apt-get install -y repo  # or use Google's repo launcher in ~/bin/repo"
  fi
  exit 0
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "sudo is required for package installation." >&2
  exit 1
fi

if ! sudo -n true 2>/dev/null; then
  if [[ ! -t 0 ]] || [[ ! -t 1 ]]; then
    echo "ERROR: apt install needs an interactive sudo password." >&2
    echo "Open Ubuntu (WSL) from the Start menu, then run:" >&2
    echo "  bash $(cd "$(dirname "$0")" && pwd)/setup-build-env.sh" >&2
    echo "Or from PowerShell: wsl -d Ubuntu" >&2
    exit 1
  fi
  echo "You will be prompted for your Linux user password (sudo)." >&2
fi

sudo apt-get update
if ! sudo apt-get install -y --no-install-recommends "${APT_PACKAGES[@]}"; then
  echo "Some packages failed; retrying without 'repo' if that was the cause..." >&2
  local_without_repo=()
  for p in "${APT_PACKAGES[@]}"; do
    [[ "$p" == repo ]] && continue
    local_without_repo+=("$p")
  done
  sudo apt-get install -y --no-install-recommends "${local_without_repo[@]}"
  if ! command -v repo >/dev/null 2>&1; then
    echo "Install 'repo' manually: https://source.android.com/docs/setup/download#installing-repo" >&2
  fi
fi

echo "Done. Verify with: $(dirname "$0")/verify-wsl.sh"

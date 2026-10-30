#!/usr/bin/env bash
# Verify WSL2 and print toolchain versions for kernel builds.
set -euo pipefail

fail=0

is_wsl2=0
if [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
  if grep -qi "WSL2\|microsoft-standard" /proc/version 2>/dev/null; then
    is_wsl2=1
  fi
  # WSL2 also exposes WSLInterop; kernel line is the primary signal above.
  if [[ -d /run/WSL ]] || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    : # WSL environment confirmed
  fi
fi

echo "=== WSL / OS ==="
if [[ "$is_wsl2" -eq 1 ]]; then
  echo "WSL2: yes"
else
  echo "WSL2: NO (expected WSL2 for this project)" >&2
  fail=1
fi
uname -a
if command -v lsb_release >/dev/null 2>&1; then
  lsb_release -a 2>/dev/null || true
fi

echo
echo "=== Disk (need ~40–60 GB free for kernel + out-of-tree builds) ==="
df -h ~ / 2>/dev/null | sed '1!b;/Filesystem/d'

print_ver() {
  local name="$1"
  shift
  if command -v "$1" >/dev/null 2>&1; then
    echo -n "$name: "
    "$@" 2>/dev/null | head -1
  else
    echo "$name: not installed" >&2
  fi
}

echo
echo "=== Tool versions ==="
print_ver "gcc" gcc --version
print_ver "clang" clang --version
print_ver "lld" lld --version
print_ver "make" make --version
print_ver "python3" python3 --version
print_ver "git" git --version
print_ver "ccache" ccache --version
print_ver "repo" repo version
print_ver "bc" bc --version
print_ver "bison" bison --version
print_ver "flex" flex --version

exit "$fail"

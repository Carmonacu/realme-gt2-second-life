#!/bin/bash
# Ejecutado dentro de: proot-distro login ubuntu -- bash ~/media-arr/install-inside-ubuntu.sh
set -euo pipefail

MEDIA_ARR="${MEDIA_ARR:-/data/data/com.termux/files/home/media-arr}"
APPS="${MEDIA_ARR}/apps"
CFG="${MEDIA_ARR}/config"
LOG="${MEDIA_ARR}/log"

RADARR_URL="${RADARR_URL:-https://github.com/Radarr/Radarr/releases/download/v6.4.4.10685/Radarr.master.6.4.4.10685.linux-core-arm64.tar.gz}"
SONARR_URL="${SONARR_URL:-https://github.com/Sonarr/Sonarr/releases/download/v4.0.20.3014/Sonarr.main.4.0.20.3014.linux-arm64.tar.gz}"
PROWLARR_URL="${PROWLARR_URL:-https://github.com/Prowlarr/Prowlarr/releases/download/v2.7.0.5723/Prowlarr.master.2.7.0.5723.linux-core-arm64.tar.gz}"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl ca-certificates unzip libssl3 libsqlite3-0 libicu78 \
  || apt-get install -y curl ca-certificates unzip libssl3 libsqlite3-0 libicu76 libicu74 || true

find_exe() {
  local dest="$1" exe="$2"
  if [[ -x "${dest}/${exe}/${exe}" ]]; then
    echo "${dest}/${exe}/${exe}"
  elif [[ -x "${dest}/${exe}" ]]; then
    echo "${dest}/${exe}"
  else
    find "$dest" -maxdepth 3 -type f -name "$exe" -perm -111 2>/dev/null | head -1
  fi
}

install_arr() {
  local slug="$1" url="$2" exe="$3"
  local dest="${APPS}/${slug}"
  echo "==> ${slug} from ${url##*/}"
  rm -rf "$dest"
  mkdir -p "$dest"
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL --retry 3 -o "${tmp}/pkg.tar.gz" "$url"
  tar -xzf "${tmp}/pkg.tar.gz" -C "$dest"
  rm -rf "$tmp"
  local bin
  bin="$(find_exe "$dest" "$exe")"
  [[ -n "$bin" && -f "$bin" ]] || { echo "Falta binario $exe en $dest" >&2; find "$dest" -type f | head -20 >&2; exit 1; }
  chmod +x "$bin"
  echo "$bin" >"${dest}/.exe-path"
  echo "    -> $bin"
}

mkdir -p "$APPS" "$CFG"/{radarr,sonarr,prowlarr} "$LOG"

install_arr radarr "$RADARR_URL" Radarr
install_arr sonarr "$SONARR_URL" Sonarr
install_arr prowlarr "$PROWLARR_URL" Prowlarr

echo "==> *Arr* listos en ${APPS}"

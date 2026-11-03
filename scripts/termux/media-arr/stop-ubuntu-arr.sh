#!/bin/bash
MEDIA_ARR="${MEDIA_ARR:-/data/data/com.termux/files/home/media-arr}"

flare_stop="${MEDIA_ARR}/run/stop-flaresolverr.sh"
[[ -f "$flare_stop" ]] || flare_stop="${MEDIA_ARR}/stop-flaresolverr.sh"
[[ -f "$flare_stop" ]] && bash "$flare_stop" || true

pkill -f '[R]adarr' 2>/dev/null || true
pkill -f '[S]onarr' 2>/dev/null || true
pkill -f '[P]rowlarr' 2>/dev/null || true

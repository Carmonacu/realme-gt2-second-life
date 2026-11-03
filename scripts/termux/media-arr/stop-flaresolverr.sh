#!/bin/bash
MEDIA_ARR="${MEDIA_ARR:-/data/data/com.termux/files/home/media-arr}"
LOG="${MEDIA_ARR}/log"
PID_FILE="${LOG}/flaresolverr.pid"
APPS="${MEDIA_ARR}/apps/flaresolverr"

if [[ -f "$PID_FILE" ]]; then
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [[ -n "$pid" ]]; then
    kill "$pid" 2>/dev/null || true
    sleep 1
    kill -9 "$pid" 2>/dev/null || true
  fi
  rm -f "$PID_FILE"
fi

pkill -f '[s]rc/flaresolverr.py' 2>/dev/null || true
pkill -f "${APPS}/.venv" 2>/dev/null || true
pkill -f 'flaresolverr/dist' 2>/dev/null || true

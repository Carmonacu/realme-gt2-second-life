#!/usr/bin/env bash
# Phase 3 template — run ON DEVICE via adb shell su (or adb root).
# Dumps critical partitions to /sdcard/nethunter_backup/ using by-name paths.
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/sdcard/nethunter_backup}"
PARTS=(persist modemst1 modemst2 fsg fsc oplusreserve)

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root (adb shell su -c 'sh /path/to/this/script')" >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"

for part in "${PARTS[@]}"; do
  dev="/dev/block/by-name/${part}"
  out="${BACKUP_DIR}/${part}.img"
  if [[ ! -e "$dev" ]]; then
    echo "WARN: missing $dev — skip" >&2
    continue
  fi
  echo "Dumping $part ..."
  dd if="$dev" of="$out" bs=4096 conv=fsync
  sync
done

echo "Done. Pull from PC: adb pull ${BACKUP_DIR} ./backup_porsche/partitions"

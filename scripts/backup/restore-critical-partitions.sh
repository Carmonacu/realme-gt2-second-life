#!/usr/bin/env bash
# Phase 7 template — DESTRUCTIVE. Restore from images in backup_porsche/partitions/
# Push images to device first, then run on device as root. Review every line before use.
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/sdcard/nethunter_backup_restore}"
PARTS=(persist modemst1 modemst2 fsg fsc oplusreserve)

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root on device" >&2
  exit 1
fi

for part in "${PARTS[@]}"; do
  img="${BACKUP_DIR}/${part}.img"
  dev="/dev/block/by-name/${part}"
  if [[ ! -f "$img" ]]; then
    echo "WARN: no $img — skip" >&2
    continue
  fi
  echo "RESTORING $part from $img to $dev ..."
  dd if="$img" of="$dev" bs=4096 conv=fsync
  sync
done

echo "Reboot and verify IMEI/SIM. Prefer stock boot images if modem still broken."

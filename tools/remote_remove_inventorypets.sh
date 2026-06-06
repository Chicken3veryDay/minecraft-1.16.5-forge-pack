#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="${SERVER_DIR:-/opt/minecraft/server}"
SERVICE_NAME="${SERVICE_NAME:-minecraft}"
MODS_DIR="$SERVER_DIR/mods"
LOG_PATH="$SERVER_DIR/logs/latest.log"
TARGET_JAR="inventorypets-1.16.5-2.2.jar"
BACKUP_ROOT="$SERVER_DIR/mod-removal-backups"
BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)-inventorypets-internal-server-error"

echo "== stopping $SERVICE_NAME =="
systemctl stop "$SERVICE_NAME"

echo "== removing $TARGET_JAR =="
if [ -f "$MODS_DIR/$TARGET_JAR" ]; then
  mkdir -p "$BACKUP_DIR"
  mv "$MODS_DIR/$TARGET_JAR" "$BACKUP_DIR/$TARGET_JAR"
  echo "Backed up to $BACKUP_DIR/$TARGET_JAR"
else
  echo "$TARGET_JAR was already absent"
fi

echo "== starting $SERVICE_NAME =="
START_EPOCH="$(date +%s)"
systemctl start "$SERVICE_NAME"

echo "== waiting for startup =="
for _ in $(seq 1 180); do
  if ! systemctl is-active --quiet "$SERVICE_NAME"; then
    sleep 2
    continue
  fi

  log_mtime="$(stat -c %Y "$LOG_PATH" 2>/dev/null || echo 0)"
  if [ "$log_mtime" -ge "$START_EPOCH" ] && tail -240 "$LOG_PATH" | grep -Eq 'Done \(.*\)! For help'; then
    break
  fi

  sleep 2
done

systemctl is-active "$SERVICE_NAME"

echo "== remaining inventory/pet jars =="
find "$MODS_DIR" -maxdepth 1 -type f -printf '%f %s\n' | grep -Ei 'inventory|pet' | sort || true

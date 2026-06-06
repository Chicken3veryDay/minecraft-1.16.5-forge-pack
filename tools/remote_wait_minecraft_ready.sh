#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="${SERVER_DIR:-/opt/minecraft/server}"
SERVICE_NAME="${SERVICE_NAME:-minecraft}"
LOG_PATH="$SERVER_DIR/logs/latest.log"

echo "== service =="
systemctl is-active "$SERVICE_NAME"

echo "== waiting for Done line =="
for _ in $(seq 1 180); do
  if tail -240 "$LOG_PATH" 2>/dev/null | grep -Eq 'Done \(.*\)! For help'; then
    tail -60 "$LOG_PATH"
    exit 0
  fi

  sleep 2
done

echo "Minecraft did not report ready before timeout." >&2
tail -180 "$LOG_PATH" >&2 || true
exit 1

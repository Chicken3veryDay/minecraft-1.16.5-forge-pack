#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="${SERVER_DIR:-/opt/minecraft/server}"
LOG_PATH="$SERVER_DIR/logs/latest.log"

echo "== service =="
systemctl is-active minecraft || true

echo "== notable join/lag lines =="
grep -E 'Done \(|joined the game|logged in with entity id|lost connection|Disconnecting|mismatched|rejected|Server is still starting|Can.t keep up|server overloaded|timed out' "$LOG_PATH" \
  | tail -120 || true

echo "== mod count =="
find "$SERVER_DIR/mods" -maxdepth 1 -type f -name '*.jar' | wc -l

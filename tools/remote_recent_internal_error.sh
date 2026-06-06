#!/usr/bin/env bash
set -euo pipefail

LOG_PATH="${LOG_PATH:-/opt/minecraft/server/logs/latest.log}"

echo "== recent joins/disconnects/errors =="
grep -Eai 'joined the game|logged in with entity id|lost connection|Internal Server Error|Exception|ERROR|Skipping Entity|Tried to load unrecognized|FileNotFound|Disconnecting|mismatched|rejected|Can.t keep up|server overloaded' "$LOG_PATH" \
  | tail -240 || true

echo "== last 220 log lines =="
tail -220 "$LOG_PATH" || true

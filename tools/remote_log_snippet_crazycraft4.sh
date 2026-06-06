#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/opt/minecraft/server/logs/latest.log"

echo "== service state =="
systemctl is-active minecraft || true

echo
echo "== 02:08:13 context =="
if [[ -f "$LOG_FILE" ]]; then
  grep -n -B8 -A18 '02:08:13' "$LOG_FILE" | tail -n 160 || true
fi

echo
echo "== recent severe markers =="
if [[ -f "$LOG_FILE" ]]; then
  grep -nE 'FATAL|ERROR|OutOfMemoryError|Cannot allocate memory|Failed to start|Stopping server' "$LOG_FILE" | tail -n 80 || true
fi

#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="/opt/minecraft/server"
SERVICE_NAME="minecraft"

echo "== status =="
systemctl status "$SERVICE_NAME" --no-pager -l || true

echo
echo "== memory =="
free -h || true

echo
echo "== latest.log markers =="
if [[ -f "$SERVER_DIR/logs/latest.log" ]]; then
  grep -E "Done \\(|ERROR|Exception|Missing|Failed|mismatch|Duplicate|OutOfMemory|Cannot allocate" "$SERVER_DIR/logs/latest.log" | tail -n 80 || true
  echo
  echo "== latest.log tail =="
  tail -n 180 "$SERVER_DIR/logs/latest.log"
else
  echo "No latest.log found."
fi

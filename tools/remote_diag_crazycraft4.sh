#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="/opt/minecraft/server"

echo "== selected properties =="
grep -E '^(level-name|motd|server-port|online-mode)=' "${SERVER_DIR}/server.properties" || true

echo
echo "== level.dat files =="
find "$SERVER_DIR" -maxdepth 4 -name level.dat -printf '%p %s bytes\n' || true

echo
echo "== world root =="
find "${SERVER_DIR}/world" -maxdepth 1 -type f -printf '%f %s bytes\n' 2>/dev/null | sort || true

echo
echo "== top-level directories =="
find "$SERVER_DIR" -maxdepth 1 -type d -printf '%f\n' | sort | head -n 80

echo
echo "== mod file count =="
find "${SERVER_DIR}/mods" -maxdepth 2 -type f | wc -l

echo
echo "== disk =="
df -h /

echo
echo "== latest log markers =="
if [[ -f "${SERVER_DIR}/logs/latest.log" ]]; then
  grep -E 'Done \(|Preparing start region|Saving chunks|level.dat|FATAL|ERROR|Exception|Failed to start|OutOfMemoryError|Cannot allocate memory' "${SERVER_DIR}/logs/latest.log" | tail -n 120 || true
fi

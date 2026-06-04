#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="${SERVER_DIR:-/opt/minecraft/server}"
LOG_PATH="$SERVER_DIR/logs/latest.log"
PROPS_PATH="$SERVER_DIR/server.properties"

echo "== service =="
systemctl is-active minecraft || true
systemctl show minecraft \
  -p ActiveState \
  -p SubState \
  -p MainPID \
  -p MemoryCurrent \
  -p MemoryPeak \
  -p CPUUsageNSec \
  --no-pager || true

echo "== host resources =="
uptime || true
free -m || true
df -h / "$SERVER_DIR" 2>/dev/null || df -h / || true

echo "== java process =="
ps -eo pid,ppid,pcpu,pmem,rss,vsz,etime,args --sort=-pcpu \
  | grep -Ei 'java|minecraft|forge' \
  | grep -v grep \
  | head -20 || true

echo "== server properties (safe) =="
if [ -f "$PROPS_PATH" ]; then
  grep -E '^(allow-flight|difficulty|enable-rcon|entity-broadcast-range-percentage|max-players|max-tick-time|online-mode|rcon\.port|simulation-distance|spawn-protection|view-distance)=' "$PROPS_PATH" \
    | sed -E 's/^(rcon\.password=).*/\1[redacted]/' || true
fi

echo "== latest lag and disconnect lines =="
if [ -f "$LOG_PATH" ]; then
  grep -Eai 'joined the game|logged in with entity id|lost connection|disconnect|Internal Exception|timed out|mismatch|rejected|channel|VANILLA|Can.t keep up|server overloaded|tick took|Watchdog|ERROR|Exception|Crash|fatal|OutOfMemory|Killed' "$LOG_PATH" \
    | tail -300 || true
fi

echo "== latest log tail =="
if [ -f "$LOG_PATH" ]; then
  tail -160 "$LOG_PATH" || true
fi

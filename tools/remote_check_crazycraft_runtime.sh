#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="${SERVER_DIR:-/opt/minecraft/server}"
SERVICE_NAME="${SERVICE_NAME:-minecraft}"
LOG_PATH="$SERVER_DIR/logs/latest.log"

echo "== service =="
systemctl is-active "$SERVICE_NAME" || true
systemctl show "$SERVICE_NAME" -p MainPID -p MemoryCurrent -p MemoryPeak -p ActiveState -p SubState --no-pager || true

echo
echo "== host memory =="
free -m || true
swapon --show || true

echo
echo "== launch/config =="
sed -n "1,12p" "$SERVER_DIR/start-server.sh" || true
grep -E "^(auto|silent|backups_to_keep|backup_timer|compression_level|only_if_players_online|force_on_shutdown) =" "$SERVER_DIR/config/ftbbackups-common.toml" || true

echo
echo "== latest ready/lag/join lines =="
if [ -f "$LOG_PATH" ]; then
  grep -E "Done \(|joined the game|logged in with entity id|lost connection|Can't keep up|Server Backup started|FTB Utilities Backups|OutOfMemory|Killed|ERROR|Exception" "$LOG_PATH" | tail -80 || true
fi

echo
echo "== latest tail =="
tail -60 "$LOG_PATH" || true

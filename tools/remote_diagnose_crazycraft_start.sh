#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="/opt/minecraft/server"
SERVICE_NAME="minecraft"

echo "== service =="
systemctl status "$SERVICE_NAME" --no-pager -l || true

echo
echo "== unit =="
systemctl cat "$SERVICE_NAME" || true

echo
echo "== launcher =="
ls -la "$SERVER_DIR"/forge.jar "$SERVER_DIR"/minecraft_server.1.16.5.jar "$SERVER_DIR"/start-server.sh 2>&1 || true
sed -n '1,40p' "$SERVER_DIR/start-server.sh" 2>/dev/null || true

echo
echo "== java =="
/opt/java/mc-java/bin/java -version 2>&1 || true

echo
echo "== recent journal =="
journalctl -u "$SERVICE_NAME" -n 120 --no-pager -o cat || true

echo
echo "== latest.log tail =="
if [[ -f "$SERVER_DIR/logs/latest.log" ]]; then
  tail -n 160 "$SERVER_DIR/logs/latest.log"
else
  echo "No latest.log found."
fi

echo
echo "== crash reports =="
find "$SERVER_DIR/crash-reports" -maxdepth 1 -type f -printf '%TY-%Tm-%Td %TH:%TM %f\n' 2>/dev/null | sort | tail -n 10 || true

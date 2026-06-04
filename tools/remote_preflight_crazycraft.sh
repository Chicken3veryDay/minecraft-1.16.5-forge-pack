#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="/opt/minecraft/server"
SERVICE_NAME="minecraft"

echo "== systemd unit =="
systemctl cat "$SERVICE_NAME" || true

echo
echo "== service status =="
systemctl status "$SERVICE_NAME" --no-pager -l || true

echo
echo "== java =="
command -v java || true
java -version 2>&1 || true

echo
echo "== server disk =="
df -h /opt /tmp || true

echo
echo "== server root =="
if [[ -d "$SERVER_DIR" ]]; then
  find "$SERVER_DIR" -maxdepth 1 -mindepth 1 -printf '%f\n' | sort
fi

echo
echo "== server.properties keepers =="
if [[ -f "${SERVER_DIR}/server.properties" ]]; then
  grep -E '^(server-ip|server-port|online-mode|enable-rcon|white-list|enforce-whitelist|difficulty|gamemode|allow-flight|level-seed)=' "${SERVER_DIR}/server.properties" || true
fi

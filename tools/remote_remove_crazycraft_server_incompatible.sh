#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="/opt/minecraft/server"
SERVICE_NAME="minecraft"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
BACKUP_DIR="${SERVER_DIR}/mods.server-incompatible-${STAMP}"

mkdir -p "$BACKUP_DIR"

move_if_present() {
  local pattern="$1"
  shopt -s nullglob
  for path in "${SERVER_DIR}"/mods/${pattern}; do
    mv "$path" "$BACKUP_DIR/"
    echo "Moved $(basename "$path") to $BACKUP_DIR"
  done
  shopt -u nullglob
}

move_if_present 'enhanced_boss_bars*.jar'
rm -f "${SERVER_DIR}/config/enhanced_boss_bars-common.toml"

if id minecraft >/dev/null 2>&1; then
  chown -R minecraft:minecraft "$BACKUP_DIR"
fi

systemctl reset-failed "$SERVICE_NAME" || true
systemctl restart "$SERVICE_NAME"
sleep 5
systemctl status "$SERVICE_NAME" --no-pager -l || true

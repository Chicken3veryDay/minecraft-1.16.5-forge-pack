#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="${SERVER_DIR:-/opt/minecraft/server}"
MODS_DIR="$SERVER_DIR/mods"
PROPS_PATH="$SERVER_DIR/server.properties"
BACKUP_ROOT="$SERVER_DIR/perf-removal-backups"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/$STAMP"

removed_mods=(
  "Atlas-Lib-1.16.5-1.1.3c.jar"
  "Craziniess Awakened.jar"
  "GatewaysToEternity-1.16.5-1.0.2.jar"
  "Hats-1.16.5-10.3.4.jar"
  "InsaneLib-1.4.2-mc1.16.5.jar"
  "LightAura-4.4.0.jar"
  "MobsPropertiesRandomness-3.3.0-mc1.16.5.jar"
  "Morph-1.16.5-10.2.1.jar"
  "ScalingHealth-1.16.5-4.1.5+11.jar"
  "The-Hordes-1.16.5-1.1.5c.jar"
  "champions-forge-1.16.5-2.0.1.16.jar"
  "coroutil-forge-1.16.5-1.3.6.jar"
  "dragonfight-1.8.jar"
  "guardvillagers-1.16.5.1.2.4.jar"
  "iChunUtil-1.16.5-10.7.0.jar"
  "itemcollectors-1.1.12-forge-mc1.16.jar"
  "pandorasbox-2.2.6-1.16.5.jar"
  "smarterfarmers-1.16.5-1.2.1.jar"
  "supermartijn642configlib-1.1.6-forge-mc1.16.jar"
  "supermartijn642corelib-1.1.21-forge-mc1.16.jar"
  "watut-forge-1.16.5-1.0.14.jar"
)

set_property() {
  local key="$1"
  local value="$2"
  if grep -qE "^${key}=" "$PROPS_PATH"; then
    sed -i -E "s|^${key}=.*|${key}=${value}|" "$PROPS_PATH"
  else
    printf '%s=%s\n' "$key" "$value" >> "$PROPS_PATH"
  fi
}

echo "== stopping minecraft =="
systemctl stop minecraft

echo "== backing up removed mods =="
mkdir -p "$BACKUP_DIR"
for name in "${removed_mods[@]}"; do
  if [ -f "$MODS_DIR/$name" ]; then
    mv "$MODS_DIR/$name" "$BACKUP_DIR/$name"
    echo "moved $name"
  fi
done

echo "== applying server.properties performance defaults =="
cp "$PROPS_PATH" "$BACKUP_DIR/server.properties.before"
set_property "view-distance" "4"
set_property "entity-broadcast-range-percentage" "50"
set_property "sync-chunk-writes" "false"
set_property "network-compression-threshold" "512"
set_property "max-tick-time" "180000"

echo "== starting minecraft =="
systemctl start minecraft
systemctl is-active minecraft

echo "== optimized mod count =="
find "$MODS_DIR" -maxdepth 1 -type f -name '*.jar' | wc -l

echo "backup: $BACKUP_DIR"

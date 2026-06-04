#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="${SERVER_DIR:-/opt/minecraft/server}"

cd "$SERVER_DIR"

echo "== start script =="
sed -n "1,30p" start-server.sh || true

echo
echo "== server.properties =="
grep -E "^(level-name|level-seed|view-distance|simulation-distance|sync-chunk-writes|network-compression-threshold|entity-broadcast-range-percentage|max-tick-time|allow-flight|online-mode)=" server.properties || true

echo
echo "== ftb backups =="
grep -E "^(auto|silent|backups_to_keep|backup_timer|compression_level|only_if_players_online|force_on_shutdown) =" config/ftbbackups-common.toml || true

echo
echo "== world shape =="
du -sh world || true
find world -maxdepth 2 -type d | sort | head -80 || true

echo
echo "== counts =="
if [ -d world/region ]; then
  printf "world/region files: "
  find world/region -type f | wc -l
fi
if [ -d world/entities ]; then
  printf "world/entities files: "
  find world/entities -type f | wc -l
fi
if [ -d world/playerdata ]; then
  find world/playerdata -type f -printf "%TY-%Tm-%Td %TH:%TM %f %s bytes\n" | sort | tail -10 || true
fi

echo
echo "== recent backups =="
find backups -maxdepth 1 -type f -printf "%TY-%Tm-%Td %TH:%TM %f %s bytes\n" 2>/dev/null | sort | tail -10 || true

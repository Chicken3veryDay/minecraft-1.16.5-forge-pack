set -eu

SERVER_DIR=/opt/minecraft/server

echo "== service =="
systemctl status minecraft --no-pager -l || true

echo "== server.properties =="
sed -n '1,220p' "$SERVER_DIR/server.properties" || true

echo "== mods summary =="
find "$SERVER_DIR/mods" -maxdepth 1 -type f -name '*.jar' | wc -l
find "$SERVER_DIR/mods" -maxdepth 1 -type f -name '*.jar' -printf '%f\n' | sort

echo "== mod hashes =="
cd "$SERVER_DIR/mods"
sha256sum *.jar | sort -k2

echo "== latest log notable lines =="
grep -Eai 'unexpected custom data|disconnect|failed|error|exception|mismatch|handshake|reject|mod list|fml|fatally|missing|duplicate' "$SERVER_DIR/logs/latest.log" | tail -200 || true

echo "== latest log tail =="
tail -120 "$SERVER_DIR/logs/latest.log" || true


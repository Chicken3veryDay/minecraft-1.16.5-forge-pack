#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="${SERVER_DIR:-/opt/minecraft/server}"
SERVICE_NAME="${SERVICE_NAME:-minecraft}"
BACKUP_ROOT="${BACKUP_ROOT:-/opt/minecraft/server/runtime-stability-backups}"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/$STAMP"

cd "$SERVER_DIR"

echo "== backup touched files =="
mkdir -p "$BACKUP_DIR"
cp -a start-server.sh "$BACKUP_DIR/start-server.sh.before"
cp -a server.properties "$BACKUP_DIR/server.properties.before"
cp -a config/ftbbackups-common.toml "$BACKUP_DIR/ftbbackups-common.toml.before"
echo "$BACKUP_DIR"

echo
echo "== stop service =="
systemctl stop "$SERVICE_NAME"

echo
echo "== update start script =="
cat > start-server.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cd /opt/minecraft/server
exec /opt/java/mc-java/bin/java -Xms1G -Xmx2816M -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+DisableExplicitGC -jar forge.jar nogui
SH
chmod +x start-server.sh
chown minecraft:minecraft start-server.sh 2>/dev/null || true
sed -n "1,20p" start-server.sh

echo
echo "== update ftb backups config =="
python3 - <<'PY'
from pathlib import Path

path = Path("config/ftbbackups-common.toml")
text = path.read_text()
replacements = {
    "auto": "false",
    "silent": "true",
    "backups_to_keep": "4",
    "backup_timer": "1440",
}
lines = []
seen = set()
for line in text.splitlines():
    stripped = line.strip()
    replaced = False
    for key, value in replacements.items():
        if stripped.startswith(f"{key} ="):
            prefix = line[: len(line) - len(line.lstrip())]
            lines.append(f"{prefix}{key} = {value}")
            seen.add(key)
            replaced = True
            break
    if not replaced:
        lines.append(line)

for key, value in replacements.items():
    if key not in seen:
        lines.append(f"{key} = {value}")

path.write_text("\n".join(lines) + "\n")
PY
chown minecraft:minecraft config/ftbbackups-common.toml 2>/dev/null || true
grep -E "^(auto|silent|backups_to_keep|backup_timer|compression_level|only_if_players_online|force_on_shutdown) =" config/ftbbackups-common.toml || true

echo
echo "== start service =="
systemctl start "$SERVICE_NAME"
systemctl is-active "$SERVICE_NAME"

echo
echo "backup: $BACKUP_DIR"

#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="${SERVER_DIR:-/opt/minecraft/server}"
SERVICE_NAME="${SERVICE_NAME:-minecraft}"
BACKUP_ROOT="${BACKUP_ROOT:-/opt/minecraft/backups}"
WIPE_WORLD="${WIPE_WORLD:-1}"
START_SERVICE="${START_SERVICE:-1}"
JAVA_BIN="${JAVA_BIN:-java}"
JAVA_ARGS="${JAVA_ARGS:--Xms1G -Xmx2500M -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+DisableExplicitGC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_PATH="${MANIFEST_PATH:-${SCRIPT_DIR}/.pack-manifest.json}"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT}/pre-forge-projecte-chaos-${STAMP}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

read_property() {
  local file="$1"
  local key="$2"
  if [[ -f "$file" ]]; then
    awk -F= -v key="$key" '$1 == key { value=substr($0, index($0, "=") + 1) } END { print value }' "$file"
  fi
}

set_property() {
  local file="$1"
  local key="$2"
  local value="$3"
  python3 - "$file" "$key" "$value" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
key = sys.argv[2]
value = sys.argv[3]
line = f"{key}={value}"
lines = path.read_text(encoding="utf-8", errors="replace").splitlines() if path.exists() else []
for index, current in enumerate(lines):
    if current.startswith(f"{key}="):
        lines[index] = line
        break
else:
    lines.append(line)
path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
}

copy_property_if_present() {
  local source="$1"
  local target="$2"
  local key="$3"
  local value
  value="$(read_property "$source" "$key" || true)"
  if [[ -n "${value}" ]]; then
    set_property "$target" "$key" "$value"
  fi
}

need_cmd python3
need_cmd sha256sum
need_cmd tar
need_cmd "${JAVA_BIN}"

if [[ ! -f "$MANIFEST_PATH" ]]; then
  echo "Missing manifest: ${MANIFEST_PATH}" >&2
  exit 1
fi

SERVER_PAYLOAD="$(python3 - "$MANIFEST_PATH" <<'PY'
import json
import pathlib
import sys

manifest = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8-sig"))
root = pathlib.Path(sys.argv[1]).parent
server = manifest.get("server", [])
if not server:
    print("")
    sys.exit(0)
paths = []
for item in server:
    source = root / item["path"]
    if not source.exists() and str(item["path"]).startswith("pack-sources/"):
        source = root / str(item["path"])[len("pack-sources/"):]
    relative = item.get("relativePath") or pathlib.Path(item["path"]).name
    paths.append(f"{source}|{relative}")
print("\n".join(paths))
PY
)"

if [[ -z "$SERVER_PAYLOAD" ]]; then
  echo "Manifest contains no server payload. Build pack assets first." >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR" "$SERVER_DIR"

if [[ "$(id -u)" == "0" ]] && command -v systemctl >/dev/null 2>&1; then
  systemctl stop "$SERVICE_NAME" >/dev/null 2>&1 || true
fi

PROPS_BACKUP="${BACKUP_DIR}/server.properties"
if [[ -f "${SERVER_DIR}/server.properties" ]]; then
  cp -a "${SERVER_DIR}/server.properties" "$PROPS_BACKUP"
fi

if [[ -d "$SERVER_DIR" ]]; then
  tar --warning=no-file-changed --ignore-failed-read -C "$SERVER_DIR" -czf "${BACKUP_DIR}/server.tar.gz" .
fi

if [[ "$WIPE_WORLD" == "1" ]]; then
  rm -rf "${SERVER_DIR:?}/world" "${SERVER_DIR:?}/world_nether" "${SERVER_DIR:?}/world_the_end" "${SERVER_DIR:?}/DIM-1" "${SERVER_DIR:?}/DIM1"
fi

rm -rf \
  "${SERVER_DIR:?}/mods" \
  "${SERVER_DIR:?}/config" \
  "${SERVER_DIR:?}/defaultconfigs" \
  "${SERVER_DIR:?}/libraries" \
  "${SERVER_DIR:?}/versions" \
  "${SERVER_DIR:?}/run.sh" \
  "${SERVER_DIR:?}/run.bat" \
  "${SERVER_DIR:?}/user_jvm_args.txt"

while IFS='|' read -r source_path relative_path; do
  [[ -z "$source_path" ]] && continue
  target_path="${SERVER_DIR}/${relative_path}"
  mkdir -p "$(dirname "$target_path")"
  cp -f "$source_path" "$target_path"
done <<< "$SERVER_PAYLOAD"

printf 'eula=true\n' > "${SERVER_DIR}/eula.txt"
if [[ -f "$PROPS_BACKUP" ]]; then
  touch "${SERVER_DIR}/server.properties"
  for key in server-ip server-port online-mode enable-rcon rcon.port rcon.password white-list enforce-whitelist difficulty gamemode allow-flight; do
    copy_property_if_present "$PROPS_BACKUP" "${SERVER_DIR}/server.properties" "$key"
  done
fi
set_property "${SERVER_DIR}/server.properties" "level-seed" ""
set_property "${SERVER_DIR}/server.properties" "motd" "Forge 1.20.1 ProjectE Chaos Pack"
set_property "${SERVER_DIR}/server.properties" "view-distance" "8"
set_property "${SERVER_DIR}/server.properties" "simulation-distance" "6"

installer_path="$(find "${SERVER_DIR}" -maxdepth 1 -type f -name 'forge-*-installer.jar' | head -n 1)"
if [[ -n "${installer_path}" ]]; then
  (
    cd "${SERVER_DIR}"
    "${JAVA_BIN}" -jar "$(basename "${installer_path}")" --installServer
  )
fi
(
  cd "${SERVER_DIR}"
  # Forge run.sh reads this file; keep memory sizing explicit for small VPS hosts.
  printf '%s\n' ${JAVA_ARGS} > user_jvm_args.txt
)

cat > "${SERVER_DIR}/start-server.sh" <<SH
#!/usr/bin/env bash
set -euo pipefail
cd "${SERVER_DIR}"
if [[ -x ./run.sh ]]; then
  exec ./run.sh nogui
fi
if [[ -f forge-server-launch.jar ]]; then
  exec "${JAVA_BIN}" ${JAVA_ARGS} -jar forge-server-launch.jar nogui
fi
echo "Forge server launch files are missing. Run the bundled installer first." >&2
exit 1
SH
chmod +x "${SERVER_DIR}/start-server.sh"

if [[ "$(id -u)" == "0" ]] && command -v systemctl >/dev/null 2>&1; then
  cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<SERVICE
[Unit]
Description=Minecraft Forge ProjectE Chaos Server
After=network.target

[Service]
Type=simple
WorkingDirectory=${SERVER_DIR}
ExecStart=${SERVER_DIR}/start-server.sh
Restart=on-failure
RestartSec=15
SuccessExitStatus=0 143

[Install]
WantedBy=multi-user.target
SERVICE
  systemctl daemon-reload
  systemctl enable "$SERVICE_NAME" >/dev/null
  if [[ "$START_SERVICE" == "1" ]]; then
    systemctl start "$SERVICE_NAME"
  fi
elif [[ "$START_SERVICE" == "1" ]]; then
  "${SERVER_DIR}/start-server.sh"
fi

echo "Forge ProjectE chaos server staging complete."
echo "Backup: ${BACKUP_DIR}"
echo "Server: ${SERVER_DIR}"

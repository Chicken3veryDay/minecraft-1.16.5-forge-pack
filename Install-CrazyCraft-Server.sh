#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="${SERVER_DIR:-/opt/minecraft/server}"
SERVICE_NAME="${SERVICE_NAME:-minecraft}"
BACKUP_ROOT="${BACKUP_ROOT:-/opt/minecraft/server-backups}"
CACHE_DIR="${CACHE_DIR:-/opt/minecraft/pack-cache}"
WIPE_WORLD="${WIPE_WORLD:-1}"
START_SERVICE="${START_SERVICE:-1}"
JAVA_BIN="${JAVA_BIN:-/opt/java/mc-java/bin/java}"
JAVA_ARGS="${JAVA_ARGS:--Xms1G -Xmx2816M -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+DisableExplicitGC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_PATH="${MANIFEST_PATH:-${SCRIPT_DIR}/.pack-manifest.json}"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT}/pre-crazycraft-${STAMP}"
EXTRACT_DIR="${CACHE_DIR}/pack-assets-${STAMP}"

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
need_cmd curl
need_cmd unzip
need_cmd sha256sum
need_cmd tar
if [[ ! -x "$JAVA_BIN" ]]; then
  JAVA_BIN="$(command -v java || true)"
fi
if [[ -z "$JAVA_BIN" || ! -x "$JAVA_BIN" ]]; then
  echo "Missing required command: java" >&2
  exit 1
fi

SERVICE_USER="root"
SERVICE_GROUP="root"
if id minecraft >/dev/null 2>&1; then
  SERVICE_USER="minecraft"
  SERVICE_GROUP="minecraft"
fi

if [[ ! -f "$MANIFEST_PATH" ]]; then
  echo "Missing manifest: ${MANIFEST_PATH}" >&2
  exit 1
fi

manifest_info="$(python3 - "$MANIFEST_PATH" <<'PY'
import json
import pathlib
import sys

manifest = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8-sig"))
archive = manifest["assetArchive"]
print(archive["url"])
print(archive["name"])
print(archive["sha256"])
print(archive.get("layoutRoot", ""))
PY
)"
mapfile -t manifest_lines <<< "$manifest_info"
ASSET_URL="${manifest_lines[0]}"
ASSET_NAME="${manifest_lines[1]}"
ASSET_SHA256="${manifest_lines[2]}"
LAYOUT_ROOT="${manifest_lines[3]:-}"
ASSET_PATH="${CACHE_DIR}/${ASSET_NAME}"

mkdir -p "$BACKUP_DIR" "$CACHE_DIR"

if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files "${SERVICE_NAME}.service" >/dev/null 2>&1; then
  echo "Stopping ${SERVICE_NAME}..."
  systemctl stop "$SERVICE_NAME" || true
  systemctl cat "$SERVICE_NAME" > "${BACKUP_DIR}/systemd-${SERVICE_NAME}.txt" 2>&1 || true
  systemctl status "$SERVICE_NAME" --no-pager > "${BACKUP_DIR}/systemd-${SERVICE_NAME}-status.txt" 2>&1 || true
fi

if [[ -d "$SERVER_DIR" ]]; then
  echo "Backing up ${SERVER_DIR} to ${BACKUP_DIR}/server.tar.gz ..."
  tar -C "$SERVER_DIR" -czf "${BACKUP_DIR}/server.tar.gz" .
fi

PROPS_BACKUP="${BACKUP_DIR}/server.properties"
if [[ -f "${SERVER_DIR}/server.properties" ]]; then
  cp -a "${SERVER_DIR}/server.properties" "$PROPS_BACKUP"
fi

echo "Downloading release asset archive..."
if [[ ! -f "$ASSET_PATH" ]] || [[ "$(sha256sum "$ASSET_PATH" | awk '{print $1}')" != "$ASSET_SHA256" ]]; then
  rm -f "$ASSET_PATH"
  curl -fL --retry 5 --retry-delay 5 -o "$ASSET_PATH" "$ASSET_URL"
fi

actual_sha="$(sha256sum "$ASSET_PATH" | awk '{print $1}')"
if [[ "$actual_sha" != "$ASSET_SHA256" ]]; then
  echo "Asset archive SHA-256 mismatch: expected ${ASSET_SHA256}, got ${actual_sha}" >&2
  exit 1
fi

rm -rf "$EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR"
unzip -q "$ASSET_PATH" -d "$EXTRACT_DIR"

ASSET_ROOT="$EXTRACT_DIR"
if [[ -n "$LAYOUT_ROOT" ]]; then
  ASSET_ROOT="${EXTRACT_DIR}/${LAYOUT_ROOT}"
fi
SERVER_PAYLOAD="${ASSET_ROOT}/Server"
if [[ ! -d "$SERVER_PAYLOAD" ]]; then
  echo "Asset archive did not contain Server payload: ${SERVER_PAYLOAD}" >&2
  exit 1
fi

mkdir -p "$SERVER_DIR"

echo "Removing previous pack files..."
pack_paths=(mods config defaultconfigs kubejs scripts resourcepacks datapacks libraries crash-reports logs versions config-overrides resources)
if [[ "$WIPE_WORLD" == "1" ]]; then
  pack_paths+=(world world_nether world_the_end DIM-1 DIM1)
fi
for path in "${pack_paths[@]}"; do
  if [[ -e "${SERVER_DIR}/${path}" ]]; then
    rm -rf "${SERVER_DIR:?}/${path}"
  fi
done

find "$SERVER_DIR" -maxdepth 1 -type f \( \
  -name 'forge*.jar' -o \
  -name 'minecraft_server*.jar' -o \
  -name 'start*.bat' -o \
  -name 'run*.sh' -o \
  -name 'user_jvm_args.txt' -o \
  -name 'server-icon.png' \
\) -delete

echo "Installing Crazy Craft server files..."
cp -a "${SERVER_PAYLOAD}/." "$SERVER_DIR/"
rm -f "${SERVER_DIR}"/mods/enhanced_boss_bars*.jar
rm -f "${SERVER_DIR}/config/enhanced_boss_bars-common.toml"

printf 'eula=true\n' > "${SERVER_DIR}/eula.txt"
if [[ -f "$PROPS_BACKUP" ]]; then
  touch "${SERVER_DIR}/server.properties"
  for key in server-ip server-port online-mode enable-rcon rcon.port rcon.password white-list enforce-whitelist difficulty gamemode allow-flight; do
    copy_property_if_present "$PROPS_BACKUP" "${SERVER_DIR}/server.properties" "$key"
  done
fi
set_property "${SERVER_DIR}/server.properties" "level-seed" ""
set_property "${SERVER_DIR}/server.properties" "motd" "Crazy Craft Updated 0.12.9"

cat > "${SERVER_DIR}/start-server.sh" <<SH
#!/usr/bin/env bash
set -euo pipefail
cd "${SERVER_DIR}"
exec "${JAVA_BIN}" ${JAVA_ARGS} -jar forge.jar nogui
SH
chmod +x "${SERVER_DIR}/start-server.sh"
if [[ "$(id -u)" == "0" ]]; then
  chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "$SERVER_DIR"
fi

if [[ "$(id -u)" == "0" ]] && command -v systemctl >/dev/null 2>&1; then
  cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<SERVICE
[Unit]
Description=Minecraft Crazy Craft Updated Server
After=network.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_GROUP}
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

echo "Crazy Craft Updated server install complete."
echo "Backup: ${BACKUP_DIR}"
echo "Server: ${SERVER_DIR}"
echo "Asset SHA-256: ${actual_sha}"

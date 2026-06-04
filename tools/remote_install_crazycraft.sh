#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="/opt/minecraft/server"
SERVICE_NAME="minecraft"
PACK_NAME="CCU Server Pack Bat - 0.12.9.zip"
PACK_URL="https://edge.forgecdn.net/files/8070/007/CCU%20Server%20Pack%20Bat%20-%200.12.9.zip"
PACK_SHA256="0c7b14464dd659f2d11166822b146f2ab755d3992b4fb0ea029bd1a097991ad3"
BACKUP_ROOT="/opt/minecraft/server-backups"
CACHE_DIR="/opt/minecraft/pack-cache"
JAVA_BIN="/opt/java/mc-java/bin/java"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT}/pre-crazycraft-${STAMP}"
PACK_PATH="${CACHE_DIR}/${PACK_NAME}"
EXTRACT_DIR="${CACHE_DIR}/crazycraft-0.12.9-${STAMP}"

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
updated = False
for index, current in enumerate(lines):
    if current.startswith(f"{key}="):
        lines[index] = line
        updated = True
        break
if not updated:
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

need_cmd systemctl
need_cmd tar
need_cmd curl
need_cmd unzip
need_cmd sha256sum
need_cmd python3
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

mkdir -p "$BACKUP_DIR" "$CACHE_DIR"

echo "Stopping ${SERVICE_NAME}..."
systemctl stop "$SERVICE_NAME" || true

echo "Writing service snapshot..."
systemctl cat "$SERVICE_NAME" > "${BACKUP_DIR}/systemd-${SERVICE_NAME}.txt" 2>&1 || true
systemctl status "$SERVICE_NAME" --no-pager > "${BACKUP_DIR}/systemd-${SERVICE_NAME}-status.txt" 2>&1 || true

if [[ -d "$SERVER_DIR" ]]; then
  echo "Backing up ${SERVER_DIR} to ${BACKUP_DIR}/server.tar.gz ..."
  tar -C "$SERVER_DIR" -czf "${BACKUP_DIR}/server.tar.gz" .
fi

PROPS_BACKUP="${BACKUP_DIR}/server.properties"
if [[ -f "${SERVER_DIR}/server.properties" ]]; then
  cp -a "${SERVER_DIR}/server.properties" "$PROPS_BACKUP"
fi

echo "Downloading official Crazy Craft Updated server pack..."
if [[ ! -f "$PACK_PATH" ]] || [[ "$(sha256sum "$PACK_PATH" | awk '{print $1}')" != "$PACK_SHA256" ]]; then
  rm -f "$PACK_PATH"
  curl -fL --retry 5 --retry-delay 5 -o "$PACK_PATH" "$PACK_URL"
fi

actual_sha="$(sha256sum "$PACK_PATH" | awk '{print $1}')"
if [[ "$actual_sha" != "$PACK_SHA256" ]]; then
  echo "Server pack SHA-256 mismatch: expected ${PACK_SHA256}, got ${actual_sha}" >&2
  exit 1
fi

mkdir -p "$EXTRACT_DIR"
unzip -q "$PACK_PATH" -d "$EXTRACT_DIR"

mkdir -p "$SERVER_DIR"

echo "Removing old world and previous pack files..."
for path in \
  world world_nether world_the_end DIM-1 DIM1 \
  mods config defaultconfigs kubejs scripts resourcepacks datapacks libraries \
  crash-reports logs versions config-overrides resources; do
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

echo "Installing Crazy Craft Updated server pack files..."
cp -a "${EXTRACT_DIR}/." "$SERVER_DIR/"

INCOMPATIBLE_DIR="${SERVER_DIR}/mods.server-incompatible-${STAMP}"
mkdir -p "$INCOMPATIBLE_DIR"
for path in "${SERVER_DIR}"/mods/enhanced_boss_bars*.jar; do
  if [[ -e "$path" ]]; then
    mv "$path" "$INCOMPATIBLE_DIR/"
    echo "Moved server-incompatible mod $(basename "$path") to ${INCOMPATIBLE_DIR}"
  fi
done
if [[ -f "${SERVER_DIR}/config/enhanced_boss_bars-common.toml" ]]; then
  rm -f "${SERVER_DIR}/config/enhanced_boss_bars-common.toml"
  echo "Removed server-incompatible config enhanced_boss_bars-common.toml"
fi

echo "Accepting EULA and preserving server properties..."
printf 'eula=true\n' > "${SERVER_DIR}/eula.txt"

if [[ -f "$PROPS_BACKUP" ]]; then
  touch "${SERVER_DIR}/server.properties"
  for key in server-ip server-port online-mode enable-rcon rcon.port rcon.password white-list enforce-whitelist difficulty gamemode allow-flight; do
    copy_property_if_present "$PROPS_BACKUP" "${SERVER_DIR}/server.properties" "$key"
  done
fi
set_property "${SERVER_DIR}/server.properties" "level-seed" ""
set_property "${SERVER_DIR}/server.properties" "motd" "Crazy Craft Updated 0.12.9"

cat > "${SERVER_DIR}/start-server.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cd /opt/minecraft/server
exec /opt/java/mc-java/bin/java -Xms1G -Xmx2816M -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+DisableExplicitGC -jar forge.jar nogui
SH
chmod +x "${SERVER_DIR}/start-server.sh"
if [[ "$JAVA_BIN" != "/opt/java/mc-java/bin/java" ]]; then
  sed -i "s#exec /opt/java/mc-java/bin/java #exec ${JAVA_BIN} #" "${SERVER_DIR}/start-server.sh"
fi
chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "$SERVER_DIR"

echo "Updating systemd service..."
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

echo "Starting ${SERVICE_NAME}..."
systemctl start "$SERVICE_NAME"

echo "Crazy Craft install staged."
echo "Backup: ${BACKUP_DIR}"
echo "Pack SHA-256: ${actual_sha}"
echo "Java:"
"$JAVA_BIN" -version 2>&1 | sed 's/^/  /'
echo "Service:"
systemctl status "$SERVICE_NAME" --no-pager -l || true

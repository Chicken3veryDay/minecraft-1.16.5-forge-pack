#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="/opt/minecraft/server"
SERVICE_NAME="minecraft"
PACK_NAME="CrazyCraft4Server.zip"
PACK_URL="https://vl4.voidswrath.com/releases/CrazyCraft4Server.zip"
PACK_SHA256="eae8930d4a83bafcc32681b285dc0c663faa6a4a505550b5d254031a5e377c97"
BACKUP_ROOT="/opt/minecraft/server-backups"
CACHE_DIR="/opt/minecraft/pack-cache"
JAVA_ROOT="/opt/java/crazycraft4-java8"
JAVA_TARBALL="${CACHE_DIR}/temurin-jdk8-linux-x64.tar.gz"
JAVA_BIN="${JAVA_ROOT}/bin/java"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT}/pre-crazycraft4-${STAMP}"
PACK_PATH="${CACHE_DIR}/${PACK_NAME}"
EXTRACT_DIR="${CACHE_DIR}/crazycraft4-${STAMP}"

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
need_cmd tar

NEW_LEVEL_SEED="$(
  python3 - <<'PY'
import random
print(random.SystemRandom().randint(-(2**63), 2**63 - 1))
PY
)"

if [[ ! -x "$JAVA_BIN" ]] || ! "$JAVA_BIN" -version 2>&1 | grep -q 'version "1\.8\.'; then
  echo "Installing portable Java 8 for Crazy Craft 4.0..."
  rm -rf "$JAVA_ROOT"
  mkdir -p "$JAVA_ROOT" "$CACHE_DIR"
  curl -fL --retry 5 --retry-delay 5 -o "$JAVA_TARBALL" "https://api.adoptium.net/v3/binary/latest/8/ga/linux/x64/jdk/hotspot/normal/eclipse"
  tar -xzf "$JAVA_TARBALL" -C "$JAVA_ROOT" --strip-components=1
fi
if [[ ! -x "$JAVA_BIN" ]] || ! "$JAVA_BIN" -version 2>&1 | grep -q 'version "1\.8\.'; then
  echo "Java 8 install failed; ${JAVA_BIN} is not a working Java 8 runtime." >&2
  exit 1
fi

SERVICE_USER="root"
SERVICE_GROUP="root"
if id minecraft >/dev/null 2>&1; then
  SERVICE_USER="minecraft"
  SERVICE_GROUP="minecraft"
fi

mkdir -p "$BACKUP_DIR" "$CACHE_DIR"
printf '%s\n' "$NEW_LEVEL_SEED" > "${BACKUP_DIR}/new-level-seed.txt"

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

echo "Downloading official VoidLauncher-free Crazy Craft 4.0 server pack..."
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

echo "Fresh world seed for reset: ${NEW_LEVEL_SEED}"
echo "Removing old world and previous pack files..."
for path in \
  world world_nether world_the_end DIM-1 DIM1 \
  mods config defaultconfigs kubejs scripts resourcepacks datapacks libraries \
  crash-reports logs versions config-overrides resources addons asm data debug \
  modernfix patchouli_books server structures customnpcs journeymap \
  mods.client-incompatible mods.client-only mods.disabled-startup-errors \
  mods.extra-disabled-20260602-190824 mods.server-incompatible-20260604-015432 \
  mods.server-only-disabled mods.disabled-recipe-scramble _PackBackups mod-removal-backups perf-removal-backups \
  runtime-stability-backups tps-backups world-backups world-seed-backups \
  backups local shrines-saves; do
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

echo "Installing Crazy Craft 4.0 server pack files..."
cp -a "${EXTRACT_DIR}/." "$SERVER_DIR/"

echo "Disabling Recipe Scramble so crafting recipes stay normal..."
mkdir -p "${SERVER_DIR}/mods.disabled-recipe-scramble"
find "${SERVER_DIR}/mods" -maxdepth 1 -type f -name '*Recipe-Scramble*.jar' -exec mv -f {} "${SERVER_DIR}/mods.disabled-recipe-scramble/" \;

echo "Accepting EULA and preserving server properties..."
printf 'eula=true\n' > "${SERVER_DIR}/eula.txt"

if [[ -f "$PROPS_BACKUP" ]]; then
  touch "${SERVER_DIR}/server.properties"
  for key in server-ip server-port online-mode enable-rcon rcon.port rcon.password white-list enforce-whitelist difficulty gamemode allow-flight; do
    copy_property_if_present "$PROPS_BACKUP" "${SERVER_DIR}/server.properties" "$key"
  done
fi
set_property "${SERVER_DIR}/server.properties" "level-seed" "$NEW_LEVEL_SEED"
set_property "${SERVER_DIR}/server.properties" "motd" "Crazy Craft 4.0 Official"

cat > "${SERVER_DIR}/start-server.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cd /opt/minecraft/server
exec /opt/java/crazycraft4-java8/bin/java -Xms1G -Xmx2816M -XX:PermSize=256M -XX:MaxPermSize=512M -XX:+UseConcMarkSweepGC -jar forge-1.7.10-10.13.4.1558-1.7.10-universal.jar nogui
SH
chmod +x "${SERVER_DIR}/start-server.sh"
chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "$SERVER_DIR"

echo "Updating systemd service..."
cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<SERVICE
[Unit]
Description=Minecraft Crazy Craft 4.0 Server
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

echo "Crazy Craft 4.0 install staged with a fresh world target."
echo "Backup: ${BACKUP_DIR}"
echo "Pack SHA-256: ${actual_sha}"
echo "Java:"
"$JAVA_BIN" -version 2>&1 | sed 's/^/  /'
echo "Service:"
systemctl status "$SERVICE_NAME" --no-pager -l || true

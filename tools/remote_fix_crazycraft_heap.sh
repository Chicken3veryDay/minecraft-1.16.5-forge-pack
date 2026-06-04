#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="/opt/minecraft/server"
SERVICE_NAME="minecraft"

cat > "${SERVER_DIR}/start-server.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cd /opt/minecraft/server
exec /opt/java/mc-java/bin/java -Xms1G -Xmx2816M -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+DisableExplicitGC -jar forge.jar nogui
SH
chmod +x "${SERVER_DIR}/start-server.sh"
if id minecraft >/dev/null 2>&1; then
  chown minecraft:minecraft "${SERVER_DIR}/start-server.sh"
fi

systemctl reset-failed "$SERVICE_NAME" || true
systemctl restart "$SERVICE_NAME"
sleep 5
systemctl status "$SERVICE_NAME" --no-pager -l || true

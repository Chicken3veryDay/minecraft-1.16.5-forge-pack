#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="/opt/minecraft/server"
SERVICE_NAME="minecraft"
SWAPFILE="/swapfile-minecraft"
SWAP_SIZE="8G"

systemctl stop "$SERVICE_NAME" || true

if ! swapon --show=NAME --noheadings | grep -Fxq "$SWAPFILE"; then
  if [[ ! -f "$SWAPFILE" ]]; then
    echo "Creating ${SWAP_SIZE} swapfile at ${SWAPFILE}..."
    fallocate -l "$SWAP_SIZE" "$SWAPFILE" || dd if=/dev/zero of="$SWAPFILE" bs=1M count=8192 status=progress
    chmod 600 "$SWAPFILE"
    mkswap "$SWAPFILE"
  fi
  swapon "$SWAPFILE"
fi

if ! grep -Eq "^[^#[:space:]]+[[:space:]]+none[[:space:]]+swap[[:space:]]" /etc/fstab || ! grep -Fq "$SWAPFILE" /etc/fstab; then
  echo "${SWAPFILE} none swap sw 0 0" >> /etc/fstab
fi

sysctl vm.swappiness=10 >/dev/null || true
cat > /etc/sysctl.d/99-minecraft-swappiness.conf <<'EOF'
vm.swappiness=10
EOF

cat > "${SERVER_DIR}/start-server.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cd /opt/minecraft/server
exec /opt/java/mc-java/bin/java -Xms1G -Xmx4G -XX:+UseG1GC -jar forge.jar nogui
SH
chmod +x "${SERVER_DIR}/start-server.sh"
if id minecraft >/dev/null 2>&1; then
  chown minecraft:minecraft "${SERVER_DIR}/start-server.sh"
fi

systemctl reset-failed "$SERVICE_NAME" || true
systemctl start "$SERVICE_NAME"
sleep 5
free -h
systemctl status "$SERVICE_NAME" --no-pager -l || true

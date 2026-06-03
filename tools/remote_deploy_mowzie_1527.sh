set -eu

SERVER_DIR=/opt/minecraft/server
MODS_DIR="$SERVER_DIR/mods"
BACKUP_DIR="$SERVER_DIR/_PackBackups/mowzie-geckolib-$(date -u +%Y%m%d-%H%M%S)"
NEW_JAR=/tmp/mowziesmobs-1.5.27.jar

test -f "$NEW_JAR"
mkdir -p "$BACKUP_DIR"

systemctl stop minecraft

if [ -f "$MODS_DIR/mowziesmobs-1.5.25.jar" ]; then
    mv "$MODS_DIR/mowziesmobs-1.5.25.jar" "$BACKUP_DIR/"
fi

install -m 0644 "$NEW_JAR" "$MODS_DIR/mowziesmobs-1.5.27.jar"
chown --reference="$MODS_DIR" "$MODS_DIR/mowziesmobs-1.5.27.jar" || true
rm -f "$NEW_JAR"

systemctl start minecraft
systemctl status minecraft --no-pager -l || true

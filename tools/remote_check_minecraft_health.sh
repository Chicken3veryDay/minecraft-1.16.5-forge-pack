set -eu

echo "== service =="
systemctl is-active minecraft

echo "== latest notable lines =="
grep -E 'Done|ERROR|Exception|Crash|Mowzie|GeckoLib|mowziesmobs' /opt/minecraft/server/logs/latest.log | tail -120 || true

echo "== latest tail =="
tail -40 /opt/minecraft/server/logs/latest.log

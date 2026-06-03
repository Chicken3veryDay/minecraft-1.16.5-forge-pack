set -eu

echo "== host =="
hostname
id
pwd

echo "== java processes =="
ps -eo pid,ppid,user,etime,cmd | grep -Ei 'java|minecraft|forge' | grep -v grep || true

echo "== systemd candidates =="
systemctl list-units --type=service --all --no-pager | grep -Ei 'minecraft|forge|mc|server' || true

echo "== minecraft paths =="
find /root /home /opt /srv -maxdepth 4 \( -name server.properties -o -name forge-*.jar -o -name '*minecraft*' -o -name mods -o -name latest.log \) 2>/dev/null | sort | head -300

echo "== listening ports =="
ss -ltnp | grep -E ':(22|25565|25575)\b' || true


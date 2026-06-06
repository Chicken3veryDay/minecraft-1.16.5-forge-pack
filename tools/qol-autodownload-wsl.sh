#!/usr/bin/env bash
set -Eeuo pipefail

REPO="/mnt/c/Users/micha/Desktop/Mods"
CLIENT_WIN='C:\Users\micha\AppData\Roaming\.minecraft\crazy-craft-4.0-official'
SERVER='root@192.3.179.150'
REMOTE_SERVER_DIR='/opt/minecraft/server'
WIN_KEY='C:\Users\micha\.ssh\racknerd_mc_ed25519'
WSL_KEY="$HOME/.ssh/racknerd_mc_ed25519"
STAGE="$REPO/_qol-server-stage"
CACHE="$REPO/_InstallCache/crazy-craft-4.0/qol-wsl"
DROP="$REPO/pack-sources/CrazyCraft4/qol-mods"

mkdir -p "$CACHE" "$DROP/both" "$DROP/client" "$DROP/server" "$HOME/.ssh"

if [ ! -f "$WSL_KEY" ]; then
  cp /mnt/c/Users/micha/.ssh/racknerd_mc_ed25519 "$WSL_KEY"
fi
chmod 600 "$WSL_KEY" || true

cd "$REPO"

echo '== Update repo =='
git fetch origin
git reset --hard origin/main

cat > "$CACHE/download_qol.py" <<'PY'
import json, os, re, sys, time, urllib.parse, urllib.request
from pathlib import Path
from html import unescape

repo = Path('/mnt/c/Users/micha/Desktop/Mods')
drop = repo / 'pack-sources' / 'CrazyCraft4' / 'qol-mods'
cache = repo / '_InstallCache' / 'crazy-craft-4.0' / 'qol-wsl'
ua = 'Mozilla/5.0 CrazyCraft4QoLWSL/1.0'

def log(kind, msg):
    print(f'[{kind}] {msg}', flush=True)

def request(url, binary=False):
    req = urllib.request.Request(url, headers={'User-Agent': ua, 'Accept': '*/*'})
    with urllib.request.urlopen(req, timeout=35) as r:
        data = r.read()
    return data if binary else data.decode('utf-8', 'replace')

def is_jar(path: Path):
    try:
        if not path.exists() or path.stat().st_size < 4096:
            return False
        with path.open('rb') as f:
            return f.read(2) == b'PK'
    except Exception:
        return False

def safe_name(name):
    name = urllib.parse.unquote(name or '').strip()
    name = re.sub(r'[\\/<>:"|?*]+', '-', name)
    name = re.sub(r'\s+', ' ', name).strip(' .-')
    if not name.lower().endswith('.jar'):
        name += '.jar'
    return name

def save_url(url, name):
    target = cache / safe_name(name)
    try:
        log('RUN', f'download {target.name}')
        data = request(url, binary=True)
        target.write_bytes(data)
        if is_jar(target):
            return target
        target.unlink(missing_ok=True)
    except Exception as e:
        try: target.unlink(missing_ok=True)
        except Exception: pass
    return None

def copy_to_drop(mod, jar):
    dest_side = mod['side']
    dest = drop / dest_side / jar.name
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(jar.read_bytes())
    log('OK', f'{mod["name"]}: saved to {dest}')

mods = [
    dict(name='VeinMiner', side='both', modrinth=['veinminer'], curse=['veinminer'], pattern=r'vein.?miner'),
    dict(name='Mouse Tweaks', side='client', modrinth=['mouse-tweaks','mousetweaks'], curse=['mouse-tweaks'], pattern=r'mouse.?tweaks'),
    dict(name='Fast Leaf Decay', side='both', modrinth=['fast-leaf-decay','fastleafdecay'], curse=['fast-leaf-decay'], pattern=r'fast.?leaf'),
    dict(name='Morpheus', side='server', modrinth=['morpheus'], curse=['morpheus'], pattern=r'morpheus'),
    dict(name='AromaBackup', side='server', modrinth=['aromabackup','aromabackup-backup'], curse=['aromabackup'], pattern=r'aroma.?backup'),
    dict(name='Aroma1997Core', side='server', modrinth=['aroma1997core'], curse=['aroma1997core'], pattern=r'aroma1997.?core'),
    dict(name='Stackie', side='server', modrinth=['stackie'], curse=['stackie'], pattern=r'stackie'),
    dict(name='TrashSlot', side='client', modrinth=['trashslot','trash-slot'], curse=['trashslot'], pattern=r'trash.?slot'),
    dict(name='AutoTrash', side='client', modrinth=['auto-trash','autotrash'], curse=['auto-trash','autotrash','auto-trash-slot'], pattern=r'auto.?trash'),
    dict(name='BetterFps', side='client', modrinth=['betterfps','better-fps'], curse=['betterfps'], pattern=r'better.?fps'),
]

for d in ['both','client','server']:
    (drop/d).mkdir(parents=True, exist_ok=True)
cache.mkdir(parents=True, exist_ok=True)

def existing_for(mod):
    roots = [drop/'both', drop/mod['side'], cache]
    rx = re.compile(mod['pattern'], re.I)
    for root in roots:
        if not root.exists():
            continue
        hits = sorted([p for p in root.glob('*.jar') if rx.search(p.name)], key=lambda p: p.stat().st_mtime, reverse=True)
        for hit in hits:
            if is_jar(hit):
                return hit
    return None

def try_modrinth(mod):
    for slug in mod['modrinth']:
        try:
            url = 'https://api.modrinth.com/v2/project/{}/version?loaders=[%22forge%22]&game_versions=[%221.7.10%22]'.format(urllib.parse.quote(slug))
            versions = json.loads(request(url))
            for v in versions:
                files = [f for f in v.get('files', []) if str(f.get('filename','')).lower().endswith('.jar')]
                files.sort(key=lambda f: not f.get('primary', False))
                for f in files:
                    jar = save_url(f['url'], f['filename'])
                    if jar:
                        return jar
        except Exception:
            pass
    return None

def extract_downloads_from_html(html, slug):
    ids = []
    for m in re.finditer(r'/minecraft/mc-mods/' + re.escape(slug) + r'/files/(\d+)', html):
        if m.group(1) not in ids:
            ids.append(m.group(1))
    # Also catch CDN jar links that are directly embedded.
    cdn = []
    for m in re.finditer(r'https?://[^"\']+?\.jar(?:\?[^"\']*)?', html):
        cdn.append(unescape(m.group(0)))
    return ids, cdn

def try_curse(mod):
    for slug in mod['curse']:
        pages = [
            f'https://www.curseforge.com/minecraft/mc-mods/{slug}/files/all?page=1&pageSize=50&version=1.7.10',
            f'https://www.curseforge.com/minecraft/mc-mods/{slug}/files?version=1.7.10',
        ]
        for page in pages:
            try:
                html = request(page)
            except Exception:
                continue
            ids, cdn_links = extract_downloads_from_html(html, slug)
            for link in cdn_links:
                name = Path(urllib.parse.urlparse(link).path).name
                jar = save_url(link, name)
                if jar:
                    return jar
            for file_id in ids[:12]:
                urls = [
                    f'https://www.curseforge.com/minecraft/mc-mods/{slug}/download/{file_id}',
                    f'https://www.curseforge.com/minecraft/mc-mods/{slug}/files/{file_id}/download',
                ]
                for url in urls:
                    jar = save_url(url, f'{slug}-{file_id}.jar')
                    if jar:
                        return jar
    return None

missing = []
for mod in mods:
    found = existing_for(mod)
    if found:
        log('OK', f'{mod["name"]}: already have {found.name}')
        copy_to_drop(mod, found)
        continue
    jar = try_modrinth(mod)
    if not jar:
        jar = try_curse(mod)
    if jar:
        copy_to_drop(mod, jar)
    else:
        log('MISS', f'{mod["name"]}: no automatic Forge 1.7.10 jar found')
        missing.append(mod['name'])

print('\n== Missing ==')
for m in missing:
    print(' - ' + m)

if missing:
    sys.exit(2)
PY

echo '== Autodownload QoL jars =='
set +e
python3 "$CACHE/download_qol.py"
DL_STATUS=$?
set -e
if [ "$DL_STATUS" -ne 0 ]; then
  echo
  echo '[WARN] Some jars could not be auto-downloaded. The installer will still use anything it found.'
fi

REPO_WIN="$(wslpath -w "$REPO")"
STAGE_WIN="$(wslpath -w "$STAGE")"

echo '== Install client QoL =='
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$REPO_WIN\\tools\\Install-CrazyCraftQoL.ps1" -Client -ClientPath "$CLIENT_WIN" -Force

echo '== Stage server QoL =='
rm -rf "$STAGE"
mkdir -p "$STAGE/mods" "$STAGE/config"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$REPO_WIN\\tools\\Install-CrazyCraftQoL.ps1" -Server -ServerPath "$STAGE_WIN" -Force

mapfile -t SERVER_JARS < <(find "$STAGE/mods" -maxdepth 1 -type f -iname '*.jar' 2>/dev/null | sort)
if [ "${#SERVER_JARS[@]}" -eq 0 ]; then
  echo '[STOP] No server jars staged. Auto-download did not find server-side jars.'
  echo 'Put jars in pack-sources/CrazyCraft4/qol-mods/{both,server}, then rerun this script.'
  exit 1
fi

echo '== Stop VPS and backup mod list =='
ssh -i "$WSL_KEY" -o StrictHostKeyChecking=accept-new "$SERVER" 'bash -s' <<'REMOTE'
set -euo pipefail
SERVER_DIR="/opt/minecraft/server"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
systemctl stop minecraft || true
mkdir -p "$SERVER_DIR/backups/qol-$STAMP" "$SERVER_DIR/mods" "$SERVER_DIR/config"
find "$SERVER_DIR/mods" -maxdepth 1 -type f -name "*.jar" -printf "%f\n" | sort > "$SERVER_DIR/backups/qol-$STAMP/mods-before.txt" || true
REMOTE

echo '== Upload server jars =='
for jar in "${SERVER_JARS[@]}"; do
  scp -i "$WSL_KEY" -o StrictHostKeyChecking=accept-new "$jar" "$SERVER:$REMOTE_SERVER_DIR/mods/"
done

if compgen -G "$STAGE/config/*" >/dev/null; then
  echo '== Upload config =='
  for cfg in "$STAGE"/config/*; do
    [ -f "$cfg" ] && scp -i "$WSL_KEY" -o StrictHostKeyChecking=accept-new "$cfg" "$SERVER:$REMOTE_SERVER_DIR/config/"
  done
fi

echo '== Restart and verify VPS =='
ssh -i "$WSL_KEY" -o StrictHostKeyChecking=accept-new "$SERVER" 'bash -s' <<'REMOTE'
set -euo pipefail
SERVER_DIR="/opt/minecraft/server"
chown -R minecraft:minecraft "$SERVER_DIR/mods" "$SERVER_DIR/config" || true

echo '== QoL jars now on server =='
find "$SERVER_DIR/mods" -maxdepth 1 -type f \( \
  -iname "*veinminer*.jar" -o \
  -iname "*fastleaf*.jar" -o \
  -iname "*morpheus*.jar" -o \
  -iname "*aromabackup*.jar" -o \
  -iname "*aroma1997core*.jar" -o \
  -iname "*stackie*.jar" \
\) -printf "%f\n" | sort || true

echo
echo '== Start Minecraft =='
systemctl reset-failed minecraft || true
systemctl start minecraft

echo
echo '== Watch boot =='
for i in $(seq 1 240); do
  if grep -q "Done (" "$SERVER_DIR/logs/latest.log" 2>/dev/null; then
    echo 'SERVER_READY'
    break
  fi
  if ! systemctl is-active minecraft >/dev/null 2>&1; then
    echo 'SERVER_FAILED'
    systemctl status minecraft --no-pager -l || true
    tail -160 "$SERVER_DIR/logs/latest.log" 2>/dev/null || true
    tail -220 "$SERVER_DIR/logs/fml-server-latest.log" 2>/dev/null || true
    exit 1
  fi
  sleep 1
done

echo
echo '== Final =='
systemctl is-active minecraft || true
ss -lntp | grep ':25565' || echo '25565 not listening'
REMOTE

echo '== Done =='

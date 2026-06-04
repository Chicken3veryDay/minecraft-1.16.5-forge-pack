#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="/opt/minecraft/server"
SERVICE_NAME="minecraft"
LOG_FILE="${SERVER_DIR}/logs/latest.log"

echo "== service =="
systemctl status "$SERVICE_NAME" --no-pager -l || true

echo
echo "== memory =="
free -h || true
swapon --show || true

echo
echo "== server.properties =="
grep -E '^(motd|level-seed|server-port|online-mode|difficulty|gamemode|allow-flight|enable-rcon)=' "${SERVER_DIR}/server.properties" || true

echo
echo "== world seed =="
python3 - "${SERVER_DIR}/world/level.dat" <<'PY'
import gzip
import io
import struct
import sys

TAG_END = 0
TAG_BYTE = 1
TAG_SHORT = 2
TAG_INT = 3
TAG_LONG = 4
TAG_FLOAT = 5
TAG_DOUBLE = 6
TAG_BYTE_ARRAY = 7
TAG_STRING = 8
TAG_LIST = 9
TAG_COMPOUND = 10
TAG_INT_ARRAY = 11
TAG_LONG_ARRAY = 12

payload = gzip.open(sys.argv[1], "rb").read()
stream = io.BytesIO(payload)

def read(size):
    data = stream.read(size)
    if len(data) != size:
        raise EOFError("unexpected end of NBT")
    return data

def read_u8():
    return read(1)[0]

def read_i16():
    return struct.unpack(">h", read(2))[0]

def read_i32():
    return struct.unpack(">i", read(4))[0]

def read_i64():
    return struct.unpack(">q", read(8))[0]

def read_string():
    length = read_i16()
    return read(length).decode("utf-8", errors="replace")

def read_payload(tag_type):
    if tag_type == TAG_BYTE:
        return struct.unpack(">b", read(1))[0]
    if tag_type == TAG_SHORT:
        return read_i16()
    if tag_type == TAG_INT:
        return read_i32()
    if tag_type == TAG_LONG:
        return read_i64()
    if tag_type == TAG_FLOAT:
        return struct.unpack(">f", read(4))[0]
    if tag_type == TAG_DOUBLE:
        return struct.unpack(">d", read(8))[0]
    if tag_type == TAG_BYTE_ARRAY:
        return read(read_i32())
    if tag_type == TAG_STRING:
        return read_string()
    if tag_type == TAG_LIST:
        item_type = read_u8()
        length = read_i32()
        return [read_payload(item_type) for _ in range(length)]
    if tag_type == TAG_COMPOUND:
        value = {}
        while True:
            child_type = read_u8()
            if child_type == TAG_END:
                return value
            child_name = read_string()
            value[child_name] = read_payload(child_type)
    if tag_type == TAG_INT_ARRAY:
        return [read_i32() for _ in range(read_i32())]
    if tag_type == TAG_LONG_ARRAY:
        return [read_i64() for _ in range(read_i32())]
    raise ValueError(f"unsupported tag type {tag_type}")

root_type = read_u8()
if root_type != TAG_COMPOUND:
    raise ValueError("level.dat root is not a compound")
_root_name = read_string()
root = read_payload(root_type)
data = root.get("Data", {})
seed = None
if isinstance(data, dict):
    seed = data.get("RandomSeed")
    worldgen = data.get("WorldGenSettings")
    if isinstance(worldgen, dict) and "seed" in worldgen:
        seed = worldgen["seed"]
print(seed if seed is not None else "unknown")
PY

echo
echo "== latest.log health markers =="
if [[ -f "$LOG_FILE" ]]; then
  grep -E "Done \\(|FATAL|ERROR|LoadingFailedException|has failed to load correctly|Internal Server Error|Can't keep up|mismatch|Missing" "$LOG_FILE" | tail -n 120 || true
else
  echo "No latest.log found."
fi

echo
echo "== mods moved aside =="
find "$SERVER_DIR" -maxdepth 1 -type d -name 'mods.server-incompatible-*' -printf '%f\n' | sort | tail -n 5 || true

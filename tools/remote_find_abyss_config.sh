#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="${SERVER_DIR:-/opt/minecraft/server}"

echo "== abyss config entries =="
ls -la "$SERVER_DIR/config" 2>/dev/null | grep -i abyss || true

echo "== abyss paths =="
find "$SERVER_DIR" -maxdepth 4 \( -iname '*abyss*' -o -iname 'theabyss2.json' \) 2>/dev/null \
  | sort \
  | head -100 || true

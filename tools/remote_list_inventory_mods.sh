#!/usr/bin/env bash
set -euo pipefail

find /opt/minecraft/server/mods -maxdepth 1 -type f -printf '%f %s\n' \
  | grep -Ei 'inventory|pet' \
  | sort

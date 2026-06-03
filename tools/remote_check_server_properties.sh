#!/usr/bin/env bash
set -euo pipefail

grep -E '^(enable-rcon|rcon\.password|rcon\.port|level-name|online-mode)=' /opt/minecraft/server/server.properties \
  | sed -E 's/^(rcon\.password=).*/\1[redacted]/'

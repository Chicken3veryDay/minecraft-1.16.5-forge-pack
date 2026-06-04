#!/usr/bin/env bash
set -euo pipefail

LOG_PATH="${LOG_PATH:-/opt/minecraft/server/logs/latest.log}"

grep -E 'CodexVerifier|imfdumb|mismatched|rejected|lost connection|Disconnecting|joined the game|logged in with entity id' "$LOG_PATH" \
  | tail -160 || true

#!/usr/bin/env bash
set -euo pipefail

SERVER_DIR="/opt/minecraft/server"
SERVICE_NAME="minecraft"
LOG_FILE="${SERVER_DIR}/logs/latest.log"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-900}"
SLEEP_SECONDS=10
elapsed=0

echo "Waiting up to ${TIMEOUT_SECONDS}s for Crazy Craft startup..."
while (( elapsed <= TIMEOUT_SECONDS )); do
  state="$(systemctl is-active "$SERVICE_NAME" || true)"
  if [[ "$state" != "active" ]]; then
    echo "Service is not active: $state"
    systemctl status "$SERVICE_NAME" --no-pager -l || true
    [[ -f "$LOG_FILE" ]] && tail -n 160 "$LOG_FILE"
    exit 1
  fi

  if [[ -f "$LOG_FILE" ]]; then
    if grep -q "Done (.*)! For help" "$LOG_FILE"; then
      grep "Done (.*)! For help" "$LOG_FILE" | tail -n 1
      exit 0
    fi

    if grep -Eq "Failed to start the minecraft server|LoadingFailedException|OutOfMemoryError|Cannot allocate memory" "$LOG_FILE"; then
      echo "Startup failure marker found."
      grep -E "Failed to start the minecraft server|LoadingFailedException|OutOfMemoryError|Cannot allocate memory|ModID:|has failed to load correctly|Attempted to load class" "$LOG_FILE" | tail -n 80 || true
      exit 2
    fi
  fi

  if (( elapsed % 60 == 0 )); then
    mem="$(free -h | awk '/^Mem:/ {print "mem used=" $3 " free=" $4 " available=" $7} /^Swap:/ {print "swap used=" $3 " free=" $4}')"
    echo "${elapsed}s: service active; ${mem}"
  fi

  sleep "$SLEEP_SECONDS"
  elapsed=$((elapsed + SLEEP_SECONDS))
done

echo "Timed out waiting for Crazy Craft startup."
systemctl status "$SERVICE_NAME" --no-pager -l || true
[[ -f "$LOG_FILE" ]] && tail -n 180 "$LOG_FILE"
exit 124

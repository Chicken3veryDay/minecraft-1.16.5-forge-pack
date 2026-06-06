#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Install-Fabric-Server.sh is deprecated. Redirecting to Install-Forge-Server.sh." >&2
exec "${SCRIPT_DIR}/Install-Forge-Server.sh" "$@"

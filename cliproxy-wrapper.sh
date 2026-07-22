#!/bin/bash
# cliproxy-wrapper.sh — Run CLIProxyAPI through proxychains4
#
# This wrapper solves the issue where CLIProxyAPI ignores HTTP_PROXY/HTTPS_PROXY
# environment variables. It uses proxychains4 to redirect all outbound traffic
# through your local proxy.
#
# Usage:
#   ./cliproxy-wrapper.sh /path/to/CLIProxyAPI -config /path/to/config.yaml
#
# Prerequisites:
#   - proxychains-ng installed (brew install proxychains-ng)
#   - proxychains.conf in the same directory or at /opt/homebrew/etc/proxychains.conf
#
# Credits:
#   - CLIProxyAPI: https://github.com/router-for-me/CLIProxyAPI
#   - Grok Build Switch: https://github.com/1parado/grok-build-switch
#   - proxychains-ng: https://github.com/rofl0r/proxychains-ng

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Path to proxychains config (local takes priority over global)
if [[ -f "$SCRIPT_DIR/proxychains.conf" ]]; then
  export PROXYCHAINS_CONF_FILE="$SCRIPT_DIR/proxychains.conf"
elif [[ -f "$HOME/.proxychains.conf" ]]; then
  export PROXYCHAINS_CONF_FILE="$HOME/.proxychains.conf"
else
  export PROXYCHAINS_CONF_FILE="/opt/homebrew/etc/proxychains.conf"
fi

# Find proxychains4 binary
PROXYCHAINS_BIN="$(command -v proxychains4 2>/dev/null || echo "/opt/homebrew/bin/proxychains4")"

if [[ ! -x "$PROXYCHAINS_BIN" ]]; then
  echo "ERROR: proxychains4 not found. Install it with: brew install proxychains-ng" >&2
  exit 1
fi

# All arguments after the script name are passed to CLIProxyAPI
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/CLIProxyAPI [CLIProxyAPI args...]" >&2
  exit 1
fi

exec "$PROXYCHAINS_BIN" "$@"

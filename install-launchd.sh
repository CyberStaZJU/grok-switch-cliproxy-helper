#!/bin/bash
# install-launchd.sh — Install CLIProxyAPI + proxychains as a macOS LaunchAgent
#
# This script sets up CLIProxyAPI to run through proxychains4 at login.
# Run this script from the directory containing cliproxy-wrapper.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== CLIProxyAPI Proxy LaunchAgent Installer ==="
echo ""

# Check proxychains4
if ! command -v proxychains4 &>/dev/null; then
  echo "proxychains4 not found. Install it first:"
  echo "  brew install proxychains-ng"
  exit 1
fi

# Check proxychains.conf exists
if [[ ! -f "$SCRIPT_DIR/proxychains.conf" ]]; then
  echo "ERROR: proxychains.conf not found in $SCRIPT_DIR"
  echo "Copy proxychains.conf.example to proxychains.conf and edit it:"
  echo "  cp $SCRIPT_DIR/proxychains.conf.example $SCRIPT_DIR/proxychains.conf"
  exit 1
fi

# Ask for paths
read -rp "Path to CLIProxyAPI binary: " CLI_PATH
CLI_PATH="${CLI_PATH/#\~/$HOME}"
if [[ ! -x "$CLI_PATH" ]]; then
  echo "ERROR: CLIProxyAPI binary not found or not executable: $CLI_PATH"
  exit 1
fi

read -rp "Path to CLIProxyAPI config.yaml: " CONFIG_PATH
CONFIG_PATH="${CONFIG_PATH/#\~/$HOME}"
if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "ERROR: config.yaml not found: $CONFIG_PATH"
  exit 1
fi

WORK_DIR="$(dirname "$CONFIG_PATH")"
PLIST_SRC="$SCRIPT_DIR/com.grokbuildswitch.cliproxyapi.plist.template"
PLIST_DST="$HOME/Library/LaunchAgents/com.grokbuildswitch.cliproxyapi.plist"

# Generate plist with actual paths
sed -e "s|PATH_PLACEHOLDER|$SCRIPT_DIR|g" \
    -e "s|BIN_PLACEHOLDER|$(dirname "$CLI_PATH")|g" \
    -e "s|CONFIG_PLACEHOLDER|$WORK_DIR|g" \
    -e "s|WORKDIR_PLACEHOLDER|$WORK_DIR|g" \
    "$PLIST_SRC" > "$PLIST_DST"

echo "LaunchAgent plist written to: $PLIST_DST"

# Load the service
launchctl bootstrap gui/$(id -u)/ "$PLIST_DST" 2>&1 || {
  echo "Failed to bootstrap. Trying kickstart..."
  launchctl kickstart -k gui/$(id -u)/com.grokbuildswitch.cliproxyapi 2>&1
}

echo ""
echo "Installation complete!"
echo "Check status: launchctl print gui/$(id -u)/com.grokbuildswitch.cliproxyapi"
echo "Check logs:   tail -f $WORK_DIR/logs/stdout.log"

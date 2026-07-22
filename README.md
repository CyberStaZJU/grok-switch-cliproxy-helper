# Grok Build Switch + CLIProxyAPI Proxy Setup (macOS)

Complete guide to run [Grok Build Switch](https://github.com/1parado/grok-build-switch) with [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) subscription proxy through a local proxy on macOS.

This guide is designed to be **AI-agent parsable** — every step is explicit, copy-pasteable, and verifiable.

---

## Table of Contents

1. [Credits & References](#credits--references)
2. [Architecture Overview](#architecture-overview)
3. [Prerequisites](#prerequisites)
4. [Step 1: Install proxychains-ng](#step-1-install-proxychains-ng)
5. [Step 2: Install Grok Build Switch](#step-2-install-grok-build-switch)
6. [Step 3: Login to Codex](#step-3-login-to-codex)
7. [Step 4: Verify CLIProxyAPI Works](#step-4-verify-cliproxyapi-works)
8. [Step 5: Create Wrapper for Proxy](#step-5-create-wrapper-for-proxy)
9. [Step 6: Install LaunchAgent](#step-6-install-launchagent)
10. [Step 7: Test End-to-End](#step-7-test-end-to-end)
11. [Troubleshooting](#troubleshooting)
12. [Uninstall](#uninstall)

---

## Credits & References

| Project | Link | License | Role |
|---------|------|---------|------|
| **Grok Build Switch** | <https://github.com/1parado/grok-build-switch> | MIT | Main app — manages Grok CLI profiles & subscription proxy |
| **CLIProxyAPI** | <https://github.com/router-for-me/CLIProxyAPI> | MIT | Bundled binary — provides local proxy for Codex/Gemini/Grok subscriptions |
| **proxychains-ng** | <https://github.com/rofl0r/proxychains-ng> | GPL-2.0 | Forces TCP connections through a proxy (CLIProxyAPI ignores env vars) |

**This project is NOT affiliated with any of the above.** It is a community helper.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        User Browser                         │
│                   (Grok Build Switch UI)                    │
└─────────────────────┬───────────────────────────────────────┘
                      │ HTTP :17878
┌─────────────────────▼───────────────────────────────────────┐
│                     grok_switch (Go)                        │
│  • Manages profiles (Default, LongCat, Kimi, Subscription)  │
│  • Reads/writes ~/.grok/config.toml                         │
│  • Starts CLIProxyAPI as LaunchAgent                        │
└─────────────────────┬───────────────────────────────────────┘
                      │ launchctl
┌─────────────────────▼───────────────────────────────────────┐
│                    CLIProxyAPI                               │
│  • Local proxy at 127.0.0.1:8317                            │
│  • Forwards requests to Codex/Gemini/Grok using OAuth       │
│  • PROBLEM: ignores HTTP_PROXY / HTTPS_PROXY env vars       │
└─────────────────────┬───────────────────────────────────────┘
                      │ direct TCP (bypasses proxy!)
                      │
            ┌─────────▼──────────┐
            │   chatgpt.com  ✗   │  ← connection reset without proxy
            │   api.openai.com   │
            └────────────────────┘

 SOLUTION: Wrap CLIProxyAPI with proxychains4

┌─────────────────────────────────────────────────────────────┐
│  proxychains4 → socks5://127.0.0.1:7891 (your local proxy)  │
│       │                                                     │
│       └──► CLIProxyAPI ──► chatgpt.com ✓                   │
└─────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

| Requirement | Verify Command | Expected Output |
|-------------|---------------|-----------------|
| macOS (Apple Silicon or Intel) | `uname -m` | `arm64` or `x86_64` |
| Homebrew | `which brew` | `/opt/homebrew/bin/brew` |
| Local proxy running (Clash/Surge/V2Ray) | `curl -s -x socks5://127.0.0.1:7891 https://httpbin.org/ip` | JSON with origin IP |
| proxychains-ng | `brew list proxychains-ng` | (no error) |
| Grok Build Switch installed | `ls ~/Library/Application\ Support/Grok\ Build\ Switch/` | `profiles.json` etc. |

---

## Step 1: Install proxychains-ng

```bash
brew install proxychains-ng
```

Verify:
```bash
proxychains4 --version
# proxychains 4.17
```

---

## Step 2: Install Grok Build Switch

### Option A: Download pre-built (recommended)

1. Go to <https://github.com/1parado/grok-build-switch/releases>
2. Download the latest `Grok-Build-Switch-*-macOS-arm64.dmg`
3. Open DMG, drag `Grok Build Switch.app` to `/Applications`

### Option B: Build from source

```bash
git clone https://github.com/1parado/grok-build-switch.git
cd grok-build-switch
./build-macos.sh
# Output: dist/macos/Grok Build Switch.app
```

### First launch

```bash
open "/Applications/Grok Build Switch.app"
# Browser opens http://127.0.0.1:17878
```

---

## Step 3: Login to Codex

1. In the app, go to **订阅代理** (Subscription Proxy)
2. Click **启动** (Start) next to the service status
3. Click **登录 Codex**
4. A URL appears — click **打开验证页** (Open Verification Page)
5. Browser opens `https://auth.openai.com/oauth/authorize?...`
6. Login to your OpenAI account and authorize
7. **Important**: After authorization, the browser redirects to `localhost:1455` — this may show a connection error, that's OK
8. Back in the app, the account should appear under **账号** (Accounts)

> **Note**: If login times out, you may need to use device code flow. CLIProxyAPI supports `-codex-device-login` but the UI may not expose this. See [Troubleshooting](#troubleshooting).

---

## Step 4: Verify CLIProxyAPI Works

Get your inference key from the **订阅代理** page (labeled "推理 Key"):

```bash
# Replace KEY with your actual inference key
KEY="your-inference-key-here"

# Test models endpoint
curl -s -H "Authorization: Bearer $KEY" \
  http://127.0.0.1:8317/v1/models | python3 -m json.tool

# Expected: list of models (gpt-5.5, gpt-5.6-luna, etc.)

# Test chat completions
curl -s -X POST \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-5.5","messages":[{"role":"user","content":"hi"}],"max_tokens":10}' \
  http://127.0.0.1:8317/v1/chat/completions | python3 -m json.tool
```

**If you get `connection reset by peer`**: CLIProxyAPI is not using your proxy. Proceed to Step 5.

---

## Step 5: Create Wrapper for Proxy

Create a wrapper script that runs CLIProxyAPI through proxychains4:

```bash
# Navigate to CLIProxyAPI directory
AUTH_DIR="$HOME/Library/Application Support/Grok Build Switch/cliproxy"
cd "$AUTH_DIR/bin"

# Backup original binary
mv CLIProxyAPI CLIProxyAPI.bin

# Create wrapper script
cat > CLIPROXYAPI << 'WRAPPER'
#!/bin/bash
exec /opt/homebrew/bin/proxychains4 "$DIR/CLIProxyAPI.bin" "$@"
WRAPPER

# Fix the wrapper (DIR is not defined in script scope — use absolute path)
cat > CLIProxyAPI << 'WRAPPER'
#!/bin/bash
exec /opt/homebrew/bin/proxychains4 "/Users/USERNAME/Library/Application Support/Grok Build Switch/cliproxy/bin/CLIProxyAPI.bin" "$@"
WRAPPER

chmod +x CLIProxyAPI
```

> **Replace `USERNAME`** with your macOS username in the wrapper script.

### Configure proxychains

```bash
cat > /opt/homebrew/etc/proxychains.conf << 'EOF'
strict_chain
proxy_dns
tcp_read_time_out 15000
tcp_connect_time_out 8000

[ProxyList]
socks5 127.0.0.1 7891
EOF
```

> **Adjust the port** if your proxy uses a different SOCKS5 port (common: 7890, 7891, 1080).

---

## Step 6: Install LaunchAgent

Create a LaunchAgent so CLIProxyAPI + proxy wrapper starts automatically:

```bash
cat > "$HOME/Library/LaunchAgents/com.grokbuildswitch.cliproxyapi.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.grokbuildswitch.cliproxyapi</string>
<key>ProgramArguments</key><array>
  <string>/Users/USERNAME/Library/Application Support/Grok Build Switch/cliproxy/bin/CLIProxyAPI</string>
  <string>-config</string>
  <string>/Users/USERNAME/Library/Application Support/Grok Build Switch/cliproxy/config.yaml</string>
</array>
<key>WorkingDirectory</key><string>/Users/USERNAME/Library/Application Support/Grok Build Switch/cliproxy</string>
<key>StandardOutPath</key><string>/Users/USERNAME/Library/Application Support/Grok Build Switch/cliproxy/logs/stdout.log</string>
<key>StandardErrorPath</key><string>/Users/USERNAME/Library/Application Support/Grok Build Switch/cliproxy/logs/stderr.log</string>
<key>RunAtLoad</key><true/>
<key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
</dict></plist>
PLIST
```

> **Replace `USERNAME`** with your macOS username (3 occurrences).

### Load the service

```bash
launchctl bootstrap gui/$(id -u)/ "$HOME/Library/LaunchAgents/com.grokbuildswitch.cliproxyapi.plist"
```

### Verify it's running

```bash
# Check process
ps aux | grep CLIProxyAPI | grep -v grep
# Should show: .../CLIProxyAPI.bin -config .../config.yaml

# Check health
curl -s http://127.0.0.1:8317/healthz
# Should return: {"status":"ok"}
```

---

## Step 7: Test End-to-End

```bash
KEY="your-inference-key-here"

# Should now succeed through proxy
curl -s --max-time 20 -X POST \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-5.5","messages":[{"role":"user","content":"1+1="}],"max_tokens":5}' \
  http://127.0.0.1:8317/v1/chat/completions
```

**Expected response**:
```json
{
  "choices": [{
    "message": {"content": "2", "role": "assistant"},
    "finish_reason": "stop"
  }]
}
```

### Using in Grok CLI

1. In Grok Build Switch, go to **订阅代理** → **创建 Codex Provider**
2. Go to home page, find **订阅代理 · ChatGPT/Codex**, click **启用**
3. Open a new terminal:
   ```bash
   grok
   ```
4. Your requests will now go through your Codex subscription via the proxy.

---

## Troubleshooting

### `connection reset by peer`

CLIProxyAPI is not using your proxy. Ensure:
1. `proxychains4` is installed: `brew list proxychains-ng`
2. Wrapper script exists: `ls -la "$HOME/Library/Application Support/Grok Build Switch/cliproxy/bin/CLIProxyAPI"`
3. `proxychains.conf` has correct proxy: `cat /opt/homebrew/etc/proxychains.conf`

### `proxychains4: not found` in logs

The LaunchAgent doesn't have `/opt/homebrew/bin` in PATH. Edit the wrapper to use full path:
```bash
cat "$HOME/Library/Application Support/Grok Build Switch/cliproxy/bin/CLIProxyAPI"
# Should show: exec /opt/homebrew/bin/proxychains4 ...
```

### DNS resolves to `224.0.0.1` or `0.0.0.0`

Add `proxy_dns` to `/opt/homebrew/etc/proxychains.conf`:
```conf
proxy_dns
```

### OAuth callback fails (localhost:1455)

This is a CLIProxyAPI limitation. Workaround using device code flow:

```bash
# Stop the service first
launchctl bootout gui/$(id -u)/com.grokbuildswitch.cliproxyapi 2>/dev/null

# Run device login manually
cd "$HOME/Library/Application Support/Grok Build Switch/cliproxy/bin"
./CLIProxyAPI.bin -config ../config.yaml -codex-device-login
# Follow the instructions: go to URL, enter code

# Restart service
launchctl kickstart -k gui/$(id -u)/com.grokbuildswitch.cliproxyapi
```

### `dial tcp ... connect: connection refused`

Your proxy's SOCKS5 port is wrong. Common ports:
- Clash: `7890` (HTTP), `7891` (SOCKS5)
- Surge: `6152` (HTTP), `6153` (SOCKS5)
- V2Ray: `10808` (SOCKS5)

Test: `curl -s -x socks5://127.0.0.1:PORT https://httpbin.org/ip`

---

## Uninstall

```bash
# Stop service
launchctl bootout gui/$(id -u)/com.grokbuildswitch.cliproxyapi 2>/dev/null

# Remove LaunchAgent
rm "$HOME/Library/LaunchAgents/com.grokbuildswitch.cliproxyapi.plist"

# Restore original binary (if wrapper exists)
AUTH_DIR="$HOME/Library/Application Support/Grok Build Switch/cliproxy/bin"
[[ -f "$AUTH_DIR/CLIProxyAPI.bin" ]] && mv "$AUTH_DIR/CLIProxyAPI.bin" "$AUTH_DIR/CLIProxyAPI"
```

---

## File Structure Reference

```
~/Library/Application Support/Grok Build Switch/
├── profiles.json          # Provider profiles (contains API keys — keep secret)
├── settings.json          # App settings
├── config.toml            # Current Grok CLI config (active)
├── backups/               # Auto backups of config.toml
├── cliproxy/
│   ├── CLIProxyAPI        # Wrapper script (this project)
│   ├── CLIProxyAPI.bin    # Original CLIProxyAPI binary
│   ├── config.yaml        # CLIProxyAPI management config
│   ├── auth/              # OAuth credentials for Codex/Gemini/Grok
│   │   └── codex-*.json   # Your logged-in subscription
│   └── logs/
│       ├── stdout.log
│       └── stderr.log
├── grok_pool/             # Multi-account pool
└── registrar/             # Account registrar
```

---

## Security Notes

- **Never commit** `profiles.json`, `auth/*.json`, or `config.toml` — they contain API keys and OAuth tokens.
- The `cliproxy/config.yaml` contains a management API key — treat it as a secret.
- `proxychains.conf` may contain proxy credentials — keep it local.
- All subscription OAuth tokens are stored as plaintext on disk.

---

## License

MIT License — see [LICENSE](./LICENSE)

This project references:
- [Grok Build Switch](https://github.com/1parado/grok-build-switch) (MIT)
- [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) (MIT)
- [proxychains-ng](https://github.com/rofl0r/proxychains-ng) (GPL-2.0)

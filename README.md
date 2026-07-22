# Grok Switch CLIProxyAPI Proxy Helper (macOS)

A wrapper to route [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) traffic through a local HTTP/SOCKS5 proxy on macOS. Designed for [Grok Build Switch](https://github.com/1parado/grok-build-switch) users who need a proxy to reach Codex / OpenAI / Google / xAI APIs.

## Credits & References

| Project | Link | License |
|---------|------|---------|
| **Grok Build Switch** | <https://github.com/1parado/grok-build-switch> | MIT |
| **CLIProxyAPI** | <https://github.com/router-for-me/CLIProxyAPI> | MIT |
| **proxychains-ng** | <https://github.com/rofl0r/proxychains-ng> | GPL-2.0 |

This project is **not affiliated with** Grok Build Switch or CLIProxyAPI. It is a community helper tool.

## Problem

[CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) is bundled with [Grok Build Switch](https://github.com/1parado/grok-build-switch) to provide subscription proxy for Codex/Gemini/Grok. However, it ignores standard `HTTP_PROXY` / `HTTPS_PROXY` environment variables, so users in regions that need a proxy to reach `chatgpt.com` / `api.openai.com` will get `connection reset` errors.

## Solution

This toolkit uses [proxychains-ng](https://github.com/rofl0r/proxychains-ng) to transparently redirect CLIProxyAPI's outbound HTTP/HTTPS connections through your local proxy (e.g. Clash, Surge, V2Ray).

## Requirements

- macOS (Apple Silicon or Intel)
- [Homebrew](https://brew.sh/)
- A running local proxy that exposes both HTTP and SOCKS5 ports
- CLIProxyAPI binary (bundled with [Grok Build Switch](https://github.com/1parado/grok-build-switch) or standalone)

## Quick Start

```bash
# 1. Install proxychains-ng
brew install proxychains-ng

# 2. Configure proxy (edit with your proxy details)
cp proxychains.conf.example proxychains.conf
# Edit proxychains.conf: set your proxy type/ip/port

# 3. Run CLIProxyAPI through the wrapper
./cliproxy-wrapper.sh /path/to/CLIProxyAPI -config /path/to/config.yaml
```

## Files

| File | Description |
|------|-------------|
| `cliproxy-wrapper.sh` | Wrapper script: runs CLIProxyAPI through proxychains4 |
| `proxychains.conf.example` | Template proxychains configuration |
| `install-launchd.sh` | Install as a macOS LaunchAgent (auto-start on login) |
| `com.grokbuildswitch.cliproxyapi.plist.template` | LaunchAgent plist template |

## Setup as LaunchAgent (Auto-start)

```bash
# 1. Copy the plist template
cp com.grokbuildswitch.cliproxyapi.plist.template ~/Library/LaunchAgents/com.grokbuildswitch.cliproxyapi.plist

# 2. Edit the plist: replace PATH_PLACEHOLDER with your CLIProxyAPI path
# 3. Edit proxychains.conf: set your proxy

# 4. Load the service
launchctl bootstrap gui/$(id -u)/ ~/Library/LaunchAgents/com.grokbuildswitch.cliproxyapi.plist
```

## How It Works

1. `proxychains4` intercepts network syscalls from the wrapped process
2. All TCP connections are redirected to your configured proxy
3. DNS resolution can be done remotely (`proxy_dns`) to avoid DNS pollution
4. CLIProxyAPI thinks it's connecting directly, but traffic goes through your proxy

## Configuration

Edit `proxychains.conf`:

```conf
strict_chain
proxy_dns
tcp_read_time_out 15000
tcp_connect_time_out 8000

[ProxyList]
# Choose one:
socks5  127.0.0.1 7891    # SOCKS5 (recommended, handles TCP + UDP)
# http    127.0.0.1 7890    # HTTP CONNECT
```

## Notes

- **Do NOT commit your `proxychains.conf`** if it contains sensitive proxy credentials
- The wrapper does NOT modify CLIProxyAPI itself — it only redirects network traffic
- CLIProxyAPI is third-party software; see its own [license](https://github.com/router-for-me/CLIProxyAPI) for terms
- [Grok Build Switch](https://github.com/1parado/grok-build-switch) is the upstream project that bundles CLIProxyAPI
- This helper wrapper is released under the MIT License

## License

MIT License - see [LICENSE](./LICENSE)

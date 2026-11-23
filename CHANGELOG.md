# Changelog

Breaking changes are listed first in each entry.

## 1.0.0-rc.104 (2026-11-23)

- First release: XERJ 1.0.0-rc.104 (official musl release binary, SHA-256 pinned), Caddy 2.11.9 as the public front, TBXark mcp-proxy 1.6.0 for the remote MCP endpoint at `/mcp`.
- One generated `XERJ_API_KEY` protects the API and `/mcp`; the web console is blocked (404).
- Memory cap and small write buffers sized from the service's memory limit, so the template runs on 0.5 GB.

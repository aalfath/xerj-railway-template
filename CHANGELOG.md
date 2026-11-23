# Changelog

Breaking changes are listed first in each entry.

## 1.0.0-rc.104-r2 (2026-11-23)

No breaking changes. No data migration; apply the update and redeploy.

- Fix: on some Railway hosts XERJ held 270–420 MB at boot (transparent huge pages in jemalloc and async workers sized for the host's CPUs), so every write got HTTP 429 and the service could be OOM-killed at 0.5 GB. The start script now turns huge pages off for XERJ's allocator and runs 4 async workers (`_RJEM_MALLOC_CONF`, `TOKIO_WORKER_THREADS`; both can be overridden). XERJ now holds about 20 MB at boot.

## 1.0.0-rc.104 (2026-11-23)

- First release: XERJ 1.0.0-rc.104 (official musl release binary, SHA-256 pinned), Caddy 2.11.9 as the public front, TBXark mcp-proxy 1.6.0 for the remote MCP endpoint at `/mcp`.
- One generated `XERJ_API_KEY` protects the API and `/mcp`; the web console is blocked (404).
- Memory cap and small write buffers sized from the service's memory limit, so the template runs on 0.5 GB.

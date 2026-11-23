[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/xerj?utm_medium=integration&utm_source=button&utm_campaign=xerj)

# XERJ on Railway

One-click [XERJ](https://github.com/xerj-org/xerj) on [Railway](https://railway.com): the Elasticsearch-compatible search engine and agent memory, with a **remote MCP endpoint** and a generated API key. Nothing to fill in at deploy time.

| | |
|---|---|
| XERJ | 1.0.0-rc.104, official `x86_64-unknown-linux-musl` release binary, SHA-256 `1628ee40…db7b693` checked at build |
| Caddy | 2.11.9 (`caddy:2.11.9-alpine@sha256:003a9780…836f0`), the only public listener |
| mcp-proxy | [TBXark/mcp-proxy](https://github.com/TBXark/mcp-proxy) 1.6.0 (MIT), SHA-256 checked, serves `xerj mcp` over streamable HTTP |
| Base | `debian:trixie-20261104-slim@sha256:a72b4433…b6b2` |

## What the template deploys

One service, `XERJ`, built from this repo, with a volume at `/data`:

- `https://YOUR-DOMAIN/`: XERJ's Elasticsearch-compatible API (`Authorization: ApiKey <XERJ_API_KEY>`)
- `https://YOUR-DOMAIN/mcp`: remote MCP server, 24 XERJ tools (`Authorization: Bearer <XERJ_API_KEY>`)
- `https://YOUR-DOMAIN/healthz`: health check, no key
- `/_xerj-console`: answers 404 (the console signs in with passkeys bound to `localhost` and can't work on a Railway domain)

## Variables

| Variable | Default | What it is |
|---|---|---|
| `XERJ_API_KEY` | `${{secret(64,"abcdef0123456789")}}` | Admin API key and MCP bearer token, 64 hex characters. Change it and redeploy to rotate. |
| `XERJ_MCP_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}/mcp` | The MCP address to paste into your client (informational). |
| `PORT` | `8080` | Port Caddy listens on. |

Optional, read by the start script or XERJ: `XERJ_EMBED_MODE` (`lexical` default; `neural` downloads a ~90 MB model to the volume and needs 1 GB RAM), `XERJ_MAX_PROCESS_MEMORY_MB` (override the memory cap), `XERJ_MEMORY_SHARE_PERCENT` (default 45% of the service's memory limit), `XERJ_LOG`, `TOKIO_WORKER_THREADS` (default 4) and `_RJEM_MALLOC_CONF` (allocator settings; the default turns transparent huge pages off, which keeps XERJ at about 20 MB at boot).

## Connect

```sh
curl -H "Authorization: ApiKey $XERJ_API_KEY" https://YOUR-DOMAIN/_cat/indices
claude mcp add --transport http xerj https://YOUR-DOMAIN/mcp --header "Authorization: Bearer $XERJ_API_KEY"
```

## Memory

Runs on 0.5 GB (Railway Free plan). The start script reads the container's memory limit and gives XERJ an explicit cap (45%) and small write buffers, so heavy bulk loads get HTTP 429 (retry) instead of an out-of-memory kill. Keep bulk requests to about 1,000 documents / 5 MB. Tested at 0.5 GB: 80,000 documents (48 MB) and 1,600 source files (30 MB). Use 1 GB or more for big or fast imports, or for neural embeddings.

If XERJ, Caddy or mcp-proxy stops, the container exits non-zero and Railway's restart policy brings it back.

## Updates

The template builds from this repo's `main` branch. A merge to `main` (for example a new XERJ version in the `Dockerfile`) makes Railway offer an update to everyone who deployed the template; they choose when to apply it. Read [CHANGELOG.md](CHANGELOG.md) first. Data on the volume is kept.

To bump XERJ: change `XERJ_VERSION` and `XERJ_SHA256` in the `Dockerfile` (the hash is in the release's `.sha256` asset), add a `CHANGELOG.md` entry, test, merge.

## Licences

XERJ's engine is Apache-2.0. Since rc.101 the release binaries also contain the proprietary XERJ-Query model crates, which run only with `--facts-model-dir`; this template doesn't enable them. Caddy is Apache-2.0, mcp-proxy MIT. This wrapper is MIT.

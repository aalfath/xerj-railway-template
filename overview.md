# Deploy and Host XERJ on Railway

XERJ is an open-source search engine and memory store for AI agents, shipped as one Rust binary. It speaks the Elasticsearch 8.x REST API, so existing Elasticsearch clients work unchanged, and adds BM25 full-text, vector and hybrid search, code search and namespaced agent memory, plus a set of MCP tools for agents.

## About Hosting XERJ

This template runs XERJ 1.0.0-rc.104 (the official release binary, checked against a pinned SHA-256) as one Railway service with a volume at `/data` for every index, the write-ahead log and agent memory. Railway terminates HTTPS. Caddy is the only public listener: it forwards the API to XERJ on loopback and serves a remote MCP endpoint at `/mcp`, where mcp-proxy runs XERJ's MCP tools over streamable HTTP. One generated 64-character key (`XERJ_API_KEY`) protects both the API and `/mcp`, so nothing is open on the first deploy. There is nothing to fill in when you deploy, and no LLM key is needed: XERJ indexes and searches on its own.

## Common Use Cases

* Long-term memory and retrieval (RAG) for AI agents, over MCP or plain HTTP
* Code and documentation search for Claude Code, Cursor or any MCP client, without grep
* A light Elasticsearch-compatible search API for apps already written against Elasticsearch clients

## Dependencies for XERJ Hosting

* XERJ release binary from github.com/xerj-org/xerj (Apache-2.0 engine)
* Caddy (front door) and TBXark mcp-proxy (remote MCP endpoint), both pinned
* A Railway volume mounted at `/data` (included)

### Deployment Dependencies

* XERJ: https://github.com/xerj-org/xerj (release notes: https://github.com/xerj-org/xerj/releases)
* XERJ docs: https://xerj.org
* Template source: https://github.com/aalfath/xerj-railway-template

### Implementation Details

**What you get:** one service, `XERJ`, with a public HTTPS domain, a 64-hex `XERJ_API_KEY` generated for you (see the service's Variables tab), and the MCP address in `XERJ_MCP_URL`. Health check: `/healthz`. If any internal process stops, the service exits with an error and Railway restarts it.

**Use the API** (any Elasticsearch client works the same way):

```sh
curl -H "Authorization: ApiKey YOUR-XERJ-API-KEY" https://YOUR-DOMAIN/_cat/indices
curl -H "Authorization: ApiKey YOUR-XERJ-API-KEY" -H 'content-type: application/x-ndjson' \
  -XPOST "https://YOUR-DOMAIN/notes/_bulk?refresh=true" --data-binary @docs.ndjson
curl -H "Authorization: ApiKey YOUR-XERJ-API-KEY" "https://YOUR-DOMAIN/notes/_search?q=railway"
```

**Connect an MCP client** (streamable HTTP, 24 XERJ tools: search, hybrid search, memory store and recall, code search and more). For Claude Code:

```sh
claude mcp add --transport http xerj https://YOUR-DOMAIN/mcp --header "Authorization: Bearer YOUR-XERJ-API-KEY"
```

Or in an `mcpServers` config: `{"xerj": {"type": "http", "url": "https://YOUR-DOMAIN/mcp", "headers": {"Authorization": "Bearer YOUR-XERJ-API-KEY"}}}`

**Memory:** the template runs on 0.5 GB of RAM (Railway's Free plan). It sizes XERJ's write buffers from the service's memory limit, so a heavy bulk load gets HTTP 429 (back off and retry, as Elasticsearch clients do) instead of an out-of-memory crash. Send bulk requests of about 1,000 documents or 5 MB at most. In tests at 0.5 GB, 80,000 documents (48 MB) and 1,600 source files (30 MB) were indexed. Give the service 1 GB or more for large or fast imports.

**Left out on purpose:** XERJ's web console (it signs in with passkeys bound to `localhost`, so it can't work on a Railway domain, and its first-run page must not be public: the template answers 404 for it); the gRPC and native REST ports (loopback only); the optional XERJ-Query `/_facts` model (proprietary model bundle, off unless you add `--facts-model-dir`); neural embeddings (set `XERJ_EMBED_MODE=neural` to download a ~90 MB model to the volume; give the service 1 GB). Feedback reporting from the MCP tools is off (`XERJ_DISABLE_FEEDBACK=true`).

**Rotate the key:** change `XERJ_API_KEY` to another 64-character hex value and redeploy.

**Updates:** the service builds from the public GitHub repo above. When a new XERJ version is merged there, Railway shows an update notice on your project and you choose when to apply it. Read `CHANGELOG.md` in the repo first. Your data stays on the volume.

## Why Deploy XERJ on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying XERJ on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->

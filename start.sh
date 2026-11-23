#!/bin/bash
# XERJ on Railway. Runs three processes and exits non-zero as soon as one of
# them stops, so Railway's ON_FAILURE restart policy brings the service back:
#   xerj       the search engine, on loopback, data on the /data volume
#   mcp-proxy  serves `xerj mcp` (stdio) as a remote streamable-HTTP MCP server
#   caddy      the only public listener, on $PORT
#
# Variables:
#   XERJ_API_KEY   required, 64 hex characters (the template generates it).
#                  Admin key for the API and bearer token for /mcp.
#   PORT           public port (Railway sets it; default 8080)
#   XERJ_EMBED_MODE, XERJ_LOG, XERJ_MAX_PROCESS_MEMORY_MB: read by XERJ itself
#   XERJ_DISABLE_FEEDBACK  default true: the MCP field-report tools send nothing
set -euo pipefail

log() { echo "xerj-railway: $*"; }
die() { echo "xerj-railway: ERROR: $*" >&2; exit 1; }

DATA_DIR="${XERJ_DATA_DIR:-/data}"
export PORT="${PORT:-8080}"
export XERJ_ES_PORT=19200 XERJ_REST_PORT=19201 XERJ_GRPC_PORT=19202 MCP_PROXY_PORT=19300
case "$PORT" in 19200|19201|19202|19300) die "PORT $PORT is used inside the container; pick another" ;; esac

# Fixed settings, overridable from Railway variables.
export XERJ_DISABLE_FEEDBACK="${XERJ_DISABLE_FEEDBACK:-true}"
export XERJ_NO_AUTOSTART=1
export XERJ_HUB_HOME="${XERJ_HUB_HOME:-$DATA_DIR/hub}"
export XERJ_CODE_HOME="${XERJ_CODE_HOME:-$DATA_DIR/code}"
export HOME="${HOME:-/root}"
# The image must bind loopback; ignore anything that would publish XERJ itself.
unset XERJ_BIND_ADDRESS XERJ_ALLOW_INSECURE_NETWORK_BIND XERJ_AUTO_PORT || true

# Admin key: required, 64 hex characters. XERJ adopts a well-formed
# <data_dir>/admin.key, so rewriting it on every boot makes rotation a matter
# of changing the variable and redeploying.
key="$(printf '%s' "${XERJ_API_KEY:-}" | tr -d '[:space:]' | tr 'A-F' 'a-f')"
[ -n "$key" ] || die "XERJ_API_KEY is empty. Set it to 64 hex characters (the template generates one)."
[ "${#key}" -eq 64 ] || die "XERJ_API_KEY must be exactly 64 hex characters (got ${#key})."
case "$key" in *[!0-9a-f]*) die "XERJ_API_KEY may contain only 0-9 and a-f." ;; esac
export XERJ_API_KEY="$key"

mkdir -p "$DATA_DIR" "$XERJ_HUB_HOME" "$XERJ_CODE_HOME"
if ! awk -v d="$DATA_DIR" '$2 == d { f = 1 } END { exit !f }' /proc/mounts; then
  log "WARNING: $DATA_DIR is not a mounted volume: indices are lost on every redeploy."
fi
( umask 077; printf '%s\n' "$key" > "$DATA_DIR/admin.key" )

RUN_DIR=/tmp/xerj-railway
mkdir -p "$RUN_DIR"; chmod 700 "$RUN_DIR"
umask 077
cat > "$RUN_DIR/xerj.toml" <<TOML
[server]
es_compat_port = $XERJ_ES_PORT
rest_port = $XERJ_REST_PORT
grpc_port = $XERJ_GRPC_PORT
bind_address = "127.0.0.1"
data_dir = "$DATA_DIR"

[auth]
enabled = true

[embedding]
model_cache_dir = "$DATA_DIR/models"

# Small-memory profile (Railway's Free plan gives a service 0.5 GB). XERJ's
# defaults size buffers for a laptop; these keep the in-memory write buffers
# and caches small so a bulk load is answered with HTTP 429 (retry) instead
# of an out-of-memory kill. Raise them on bigger plans.
[storage]
flush_size_mb = ${XERJ_FLUSH_SIZE_MB:-16}
wal_max_size_mb = 128

[indexing]
turbo_batch_size = ${XERJ_TURBO_BATCH_SIZE:-500}
turbo_parallel = ${XERJ_TURBO_PARALLEL:-false}

[engine]
ingest_shards = ${XERJ_INGEST_SHARDS:-1}

[merge]
max_concurrent = 1

[limits]
max_total_memtable_mb = ${XERJ_MAX_TOTAL_MEMTABLE_MB:-48}
max_segment_hydration_cache_mb = ${XERJ_HYDRATION_CACHE_MB:-32}
max_concurrent_searches = ${XERJ_MAX_CONCURRENT_SEARCHES:-8}
max_query_memory_mb = ${XERJ_MAX_QUERY_MEMORY_MB:-128}
max_body_bytes = ${XERJ_MAX_BODY_BYTES:-20971520}
memory_watermark_percent = ${XERJ_MEMORY_WATERMARK_PERCENT:-70}
TOML

cat > "$RUN_DIR/mcp-proxy.json" <<JSON
{
  "mcpProxy": {
    "baseURL": "http://127.0.0.1:$MCP_PROXY_PORT",
    "addr": "127.0.0.1:$MCP_PROXY_PORT",
    "name": "XERJ",
    "version": "${XERJ_VERSION:-unknown}",
    "type": "streamable-http",
    "options": { "panicIfInvalid": true, "logEnabled": false, "authTokens": ["$key"] }
  },
  "mcpServers": {
    "xerj": {
      "command": "/usr/local/bin/xerj",
      "args": ["mcp", "--url", "http://127.0.0.1:$XERJ_ES_PORT", "--no-autostart", "--disable-feedback"],
      "env": {
        "XERJ_AUTH": "ApiKey $key",
        "XERJ_DISABLE_FEEDBACK": "true",
        "XERJ_NO_AUTOSTART": "1",
        "XERJ_HUB_HOME": "$XERJ_HUB_HOME",
        "XERJ_CODE_HOME": "$XERJ_CODE_HOME",
        "HOME": "$HOME"
      },
      "timeout": "120s",
      "options": { "autoReconnect": true }
    }
  }
}
JSON
umask 022

pids=()
stop() {
  log "stopping"
  for p in "${pids[@]}"; do kill -TERM "$p" 2>/dev/null || true; done
  for p in "${pids[@]}"; do wait "$p" 2>/dev/null || true; done
  exit 0
}
trap stop TERM INT

# The console's one-time owner link is printed on every boot until an owner
# exists. The console is blocked at Caddy, but keep the token out of the logs.
log "starting $(xerj -V 2>/dev/null | head -n1) on 127.0.0.1:$XERJ_ES_PORT, data in $DATA_DIR"
xerj --config "$RUN_DIR/xerj.toml" --data-dir "$DATA_DIR" \
  > >(sed -u -e 's|\(setup#token=\)[A-Za-z0-9_-]*|\1[hidden]|g') 2>&1 &
xerj_pid=$!; pids+=("$xerj_pid")

for i in $(seq 1 240); do
  curl -fsS -o /dev/null "http://127.0.0.1:$XERJ_ES_PORT/health/ready" && break
  kill -0 "$xerj_pid" 2>/dev/null || { wait "$xerj_pid" || rc=$?; die "xerj exited during startup (code ${rc:-0})"; }
  sleep 0.5
done
curl -fsS -o /dev/null "http://127.0.0.1:$XERJ_ES_PORT/health/ready" || die "xerj not ready after 120 s"
log "xerj ready"

mcp-proxy -config "$RUN_DIR/mcp-proxy.json" -expand-env=false -log-level warn &
pids+=("$!")
caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &
pids+=("$!")
log "listening on :$PORT (API at /, MCP at /mcp, health at /healthz)"

# Exit non-zero when any child stops (BusyBox-safe polling, no wait -n).
while :; do
  for p in "${pids[@]}"; do
    if ! kill -0 "$p" 2>/dev/null; then
      rc=0; wait "$p" || rc=$?
      log "process $p stopped (code $rc); exiting so Railway restarts the service"
      for q in "${pids[@]}"; do kill -TERM "$q" 2>/dev/null || true; done
      exit $(( rc == 0 ? 1 : rc ))
    fi
  done
  sleep 2 & wait $! || true
done

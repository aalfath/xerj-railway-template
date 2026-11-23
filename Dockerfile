# XERJ on Railway: https://github.com/aalfath/xerj-railway-template
#
# XERJ publishes no container image, only release binaries with a .sha256 file
# per asset. This image downloads the pinned musl build of XERJ and the pinned
# TBXark mcp-proxy build, checks each against a checksum pinned here, and runs
# them behind Caddy (copied from the official Caddy image, pinned by digest).
#
# To update XERJ: change XERJ_VERSION and XERJ_SHA256 together (the value is in
# xerj-<version>-x86_64-unknown-linux-musl.tar.gz.sha256 on the release page),
# add a CHANGELOG.md entry and merge to main.
ARG XERJ_VERSION=1.0.0-rc.104
ARG XERJ_SHA256=1628ee401a9a121156cc380950f9d48923e6e856458ae1e6648f0ef18db7b693
ARG MCP_PROXY_VERSION=1.6.0
ARG MCP_PROXY_SHA256=f00212ba9d1d09194f06538f09348f2fcd9458c5516fb5213b927e6183bc3e98

FROM caddy:2.11.9-alpine@sha256:003a97808e781aa9f7e75cc2f43d34d461099031faf5e20faefb9f61126836f0 AS caddy

FROM debian:trixie-20261104-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2 AS fetch
ARG XERJ_VERSION
ARG XERJ_SHA256
ARG MCP_PROXY_VERSION
ARG MCP_PROXY_SHA256
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /fetch
RUN set -eu; \
    a="xerj-${XERJ_VERSION}-x86_64-unknown-linux-musl"; \
    curl -fsSL --retry 3 -o "$a.tar.gz" "https://github.com/xerj-org/xerj/releases/download/v${XERJ_VERSION}/$a.tar.gz"; \
    echo "${XERJ_SHA256}  $a.tar.gz" | sha256sum -c -; \
    tar -xzf "$a.tar.gz"; \
    install -m 0755 "$a/xerj" /fetch/xerj; \
    cp "$a/LICENSE" /fetch/XERJ-LICENSE; \
    m="mcp-proxy_${MCP_PROXY_VERSION}_linux_amd64.tar.gz"; \
    curl -fsSL --retry 3 -o "$m" "https://github.com/TBXark/mcp-proxy/releases/download/v${MCP_PROXY_VERSION}/$m"; \
    echo "${MCP_PROXY_SHA256}  $m" | sha256sum -c -; \
    mkdir mp && tar -xzf "$m" -C mp; \
    install -m 0755 mp/mcp-proxy /fetch/mcp-proxy; \
    cp mp/LICENSE /fetch/MCP-PROXY-LICENSE

FROM debian:trixie-20261104-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2
ARG XERJ_VERSION
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /data /etc/caddy /usr/share/doc/xerj /usr/share/doc/mcp-proxy
COPY --from=fetch /fetch/xerj /usr/local/bin/xerj
COPY --from=fetch /fetch/mcp-proxy /usr/local/bin/mcp-proxy
COPY --from=fetch /fetch/XERJ-LICENSE /usr/share/doc/xerj/LICENSE
COPY --from=fetch /fetch/MCP-PROXY-LICENSE /usr/share/doc/mcp-proxy/LICENSE
COPY --from=caddy /usr/bin/caddy /usr/local/bin/caddy
COPY Caddyfile /etc/caddy/Caddyfile
COPY start.sh /usr/local/bin/start.sh
RUN chmod 0755 /usr/local/bin/start.sh

LABEL org.opencontainers.image.title="XERJ for Railway" \
      org.opencontainers.image.source="https://github.com/aalfath/xerj-railway-template" \
      org.opencontainers.image.version="${XERJ_VERSION}" \
      org.opencontainers.image.licenses="Apache-2.0"

ENV XERJ_VERSION=${XERJ_VERSION} \
    PORT=8080 \
    XERJ_DATA_DIR=/data \
    XERJ_LOG=info

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/start.sh"]

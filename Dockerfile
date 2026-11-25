# syntax=docker/dockerfile:1
# Render xray (VLESS + WS + TLS) — route B (Docker image) per DEPLOY_MEMORY.md §5.
# Multi-stage: copy the xray binary out of the official image onto a shell Alpine
# (the official xray image has no shell, so it cannot run an entrypoint script).
# Render terminates TLS at its load balancer (*.onrender.com :443) and forwards
# plain HTTP to the container's $PORT, so the xray inbound is plain WS on $PORT.
# Build context must contain entrypoint.sh. No secrets are baked into the image:
# UUID / WS_PATH are supplied as Render environment variables at runtime.
# Two ways onto Render: (a) public Git URL — Render builds this Dockerfile from a
# public repo (GitLab/Codeberg, email-only; GitHub off-limits); (b) prebuilt image
# pushed to a public registry, deployed via Dashboard > Existing Image.
# Image requirements (Render docs): linux/amd64, compressed size <= 10 GB.

FROM ghcr.io/xtls/xray-core:latest AS xray

FROM alpine:3.20

RUN apk add --no-cache ca-certificates tzdata

COPY --from=xray /usr/local/bin/xray /usr/local/bin/xray
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh /usr/local/bin/xray

ENTRYPOINT ["/entrypoint.sh"]

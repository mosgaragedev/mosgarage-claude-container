#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# readiness-probe.sh
# Drop into any mosgarage container as /usr/local/bin/readiness-probe.sh
# Called by Docker HEALTHCHECK and mosgaraged to verify service readiness.
#
# Exit 0 = ready   Exit 1 = not ready
#
# Configure via env vars:
#   PROBE_TYPE    http | tcp | exec | combined (default: http)
#   PROBE_URL     HTTP URL to check (default: http://localhost:$PORT/health)
#   PROBE_PORT    TCP port to check
#   PROBE_CMD     Shell command to run for exec probe
#   PORT          Service port (default: 8080)
# ─────────────────────────────────────────────────────────────────────────────

PROBE_TYPE="${PROBE_TYPE:-http}"
PORT="${PORT:-8080}"
PROBE_URL="${PROBE_URL:-http://localhost:${PORT}/health}"
PROBE_PORT="${PROBE_PORT:-$PORT}"

probe_http() {
    curl -sf --max-time 5 "$PROBE_URL" &>/dev/null
}

probe_tcp() {
    timeout 5 bash -c "echo > /dev/tcp/localhost/${PROBE_PORT}" &>/dev/null
}

probe_exec() {
    [ -n "$PROBE_CMD" ] && eval "$PROBE_CMD" &>/dev/null
}

probe_combined() {
    probe_tcp && probe_http
}

case "$PROBE_TYPE" in
    http)     probe_http     ;;
    tcp)      probe_tcp      ;;
    exec)     probe_exec     ;;
    combined) probe_combined ;;
    *)        probe_http     ;;
esac

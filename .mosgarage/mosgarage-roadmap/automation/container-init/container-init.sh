#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# container-init.sh
# Universal init wrapper for all mosgarage containers.
# Runs before the main service process to:
#   1. Validate required env vars
#   2. Wait for declared dependencies (HTTP/TCP)
#   3. Register with mosgaraged daemon
#   4. Run any pre-start hooks
#   5. Exec the main process
#
# Usage in Dockerfile:
#   COPY automation/container-init.sh /usr/local/bin/init.sh
#   ENTRYPOINT ["/usr/local/bin/init.sh"]
#   CMD ["node", "server.js"]        ← passed as $@
#
# Configure via env:
#   SERVICE_NAME          mosgarage service name (e.g. "community")
#   REQUIRED_VARS         comma-separated list of required env var names
#   WAIT_FOR              comma-separated "host:port" or "http://url" pairs
#   WAIT_TIMEOUT          seconds (default: 120)
#   DAEMON_URL            mosgaraged URL (default: http://mosgaraged:9090)
#   DAEMON_KEY            shared secret for daemon registration
#   PRE_START_HOOK        path to optional pre-start script
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:-unknown}"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-120}"
DAEMON_URL="${DAEMON_URL:-http://mosgaraged:9090}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; RESET='\033[0m'
log()  { echo -e "${GREEN}[init:${SERVICE_NAME}]${RESET} $*"; }
warn() { echo -e "${YELLOW}[init:${SERVICE_NAME}]${RESET} $*"; }
fail() { echo -e "${RED}[init:${SERVICE_NAME}]${RESET} $*"; exit 1; }

# ── 1. Validate required env vars ─────────────────────────────────────────────
if [ -n "${REQUIRED_VARS:-}" ]; then
    log "Validating required env vars..."
    IFS=',' read -ra VARS <<< "$REQUIRED_VARS"
    missing=()
    for var in "${VARS[@]}"; do
        var=$(echo "$var" | xargs)   # trim whitespace
        [ -z "${!var:-}" ] && missing+=("$var")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        fail "Missing required env vars: ${missing[*]}"
    fi
    log "Env vars OK (${#VARS[@]} checked)"
fi

# ── 2. Wait for dependencies ──────────────────────────────────────────────────
if [ -n "${WAIT_FOR:-}" ]; then
    IFS=',' read -ra DEPS <<< "$WAIT_FOR"
    for dep in "${DEPS[@]}"; do
        dep=$(echo "$dep" | xargs)
        elapsed=0
        log "Waiting for: $dep (max ${WAIT_TIMEOUT}s)"

        while [ $elapsed -lt $WAIT_TIMEOUT ]; do
            if [[ "$dep" == http* ]]; then
                # HTTP check
                curl -sf --max-time 3 "$dep" &>/dev/null && break
            else
                # TCP check (host:port)
                host="${dep%%:*}"
                port="${dep##*:}"
                timeout 3 bash -c "echo > /dev/tcp/$host/$port" &>/dev/null && break
            fi
            sleep 3; elapsed=$((elapsed + 3)); printf "."
        done
        echo ""
        [ $elapsed -ge $WAIT_TIMEOUT ] && fail "Dependency not ready: $dep"
        log "✓ $dep is ready"
    done
fi

# ── 3. Register with mosgaraged ───────────────────────────────────────────────
if [ -n "${DAEMON_URL:-}" ] && [ -n "${SERVICE_NAME:-}" ]; then
    reg_payload="{\"type\":\"service:ready\",\"payload\":{\"name\":\"${SERVICE_NAME}\",\"pid\":$$}}"
    curl -sf --max-time 3 \
        -X POST "${DAEMON_URL}/emit" \
        -H "Content-Type: application/json" \
        -H "X-Daemon-Key: ${DAEMON_KEY:-}" \
        -d "$reg_payload" &>/dev/null || warn "Could not register with daemon (non-fatal)"
    log "Registered with mosgaraged"
fi

# ── 4. Pre-start hook ─────────────────────────────────────────────────────────
if [ -n "${PRE_START_HOOK:-}" ] && [ -x "$PRE_START_HOOK" ]; then
    log "Running pre-start hook: $PRE_START_HOOK"
    "$PRE_START_HOOK" || fail "Pre-start hook failed"
fi

# ── 5. Exec main process ──────────────────────────────────────────────────────
log "Init complete — starting: $*"
exec "$@"

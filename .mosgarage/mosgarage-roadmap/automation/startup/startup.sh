#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# startup.sh — mosgarage Platform Container Startup Orchestrator
#
# Ensures services start in dependency order with health gates between each
# tier. Avoids race conditions (e.g. control-plane starting before postgres
# is ready, workspaces starting before mosgaraged is up).
#
# Startup tiers:
#   Tier 0 (network)   : Docker network
#   Tier 1 (data)      : postgres
#   Tier 2 (infra)     : traefik
#   Tier 3 (daemon)    : mosgaraged
#   Tier 4 (platform)  : control-plane
#   Tier 5 (services)  : studio-blog, studio-docs, flipstack, community,
#                        academy, ecampus, agent
#
# Usage:
#   ./startup.sh              # full platform start
#   ./startup.sh console      # console workstream only (Tier 0-4)
#   ./startup.sh --down       # graceful shutdown (reverse order)
#   ./startup.sh --status     # show readiness of all services
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
TIMEOUT="${STARTUP_TIMEOUT:-120}"    # seconds to wait per health gate
MODE="${1:-full}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; RESET='\033[0m'
ok()    { echo -e "${GREEN}  ✓ $1${RESET}"; }
fail()  { echo -e "${RED}  ✗ $1${RESET}"; }
step()  { echo -e "\n${YELLOW}▶ $1${RESET}"; }
info()  { echo -e "${CYAN}  → $1${RESET}"; }

# ── Wait for a container to be healthy ────────────────────────────────────────
wait_healthy() {
    local service="$1"
    local timeout="${2:-$TIMEOUT}"
    local elapsed=0

    info "Waiting for $service to be healthy (max ${timeout}s)..."
    while [ $elapsed -lt $timeout ]; do
        local state
        state=$(docker inspect --format='{{.State.Health.Status}}' \
            "$(docker compose ps -q "$service" 2>/dev/null)" 2>/dev/null || echo "none")

        case "$state" in
            healthy)  ok "$service is healthy"; return 0 ;;
            none)
                # No healthcheck — check if running
                local running
                running=$(docker inspect --format='{{.State.Running}}' \
                    "$(docker compose ps -q "$service" 2>/dev/null)" 2>/dev/null || echo "false")
                [ "$running" = "true" ] && ok "$service is running (no healthcheck)" && return 0
                ;;
            unhealthy) fail "$service is unhealthy"; return 1 ;;
        esac

        sleep 3
        elapsed=$((elapsed + 3))
        printf "."
    done

    fail "$service did not become healthy within ${timeout}s"
    return 1
}

# ── Wait for HTTP endpoint to respond ─────────────────────────────────────────
wait_http() {
    local name="$1" url="$2" timeout="${3:-$TIMEOUT}"
    local elapsed=0
    info "Waiting for $name HTTP ($url)..."
    while [ $elapsed -lt $timeout ]; do
        if curl -sf --max-time 3 "$url" &>/dev/null; then
            ok "$name HTTP ready"; return 0
        fi
        sleep 3; elapsed=$((elapsed + 3)); printf "."
    done
    fail "$name HTTP not ready after ${timeout}s"; return 1
}

# ── Graceful shutdown (reverse tier order) ─────────────────────────────────────
if [ "$MODE" = "--down" ]; then
    step "Graceful shutdown — reverse tier order"
    docker compose stop agent ecampus academy community 2>/dev/null || true
    sleep 2
    docker compose stop studio-flipstack studio-docs studio-blog 2>/dev/null || true
    sleep 2
    docker compose stop control-plane 2>/dev/null || true
    sleep 2
    docker compose stop mosgaraged 2>/dev/null || true
    sleep 2
    docker compose stop traefik 2>/dev/null || true
    sleep 2
    docker compose stop postgres 2>/dev/null || true
    ok "Platform stopped"
    exit 0
fi

# ── Status check ──────────────────────────────────────────────────────────────
if [ "$MODE" = "--status" ]; then
    step "Platform readiness status"
    DAEMON_URL="http://localhost:9090"
    if curl -sf "$DAEMON_URL/health" &>/dev/null; then
        curl -sf "$DAEMON_URL/services" | jq '
          to_entries[] | "\(.key): \(.value.status)"
        ' -r 2>/dev/null || true
    else
        docker compose ps
    fi
    exit 0
fi

# ── Determine workstream ───────────────────────────────────────────────────────
CONSOLE_ONLY=false
[ "$MODE" = "console" ] && CONSOLE_ONLY=true

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}  mosgarage Platform Startup${RESET}"
echo -e "  Mode   : ${MODE}"
echo -e "  Compose: ${COMPOSE_FILE}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

# ── Tier 0: Network ───────────────────────────────────────────────────────────
step "Tier 0 — Docker network"
docker network inspect mosgarage-net &>/dev/null || \
    docker network create mosgarage-net
ok "mosgarage-net ready"

# ── Tier 1: Data ──────────────────────────────────────────────────────────────
step "Tier 1 — Database (postgres)"
docker compose up -d postgres
wait_healthy postgres 60
ok "Tier 1 complete"

# ── Tier 2: Infrastructure ────────────────────────────────────────────────────
step "Tier 2 — Infrastructure (traefik)"
docker compose up -d traefik
wait_http "traefik" "http://localhost:80" 30 || true   # may redirect, that's fine
ok "Tier 2 complete"

# ── Tier 3: Daemon ────────────────────────────────────────────────────────────
step "Tier 3 — Orchestration daemon (mosgaraged)"
docker compose up -d mosgaraged
wait_http "mosgaraged" "http://localhost:9090/health" 60
ok "Tier 3 complete"

# ── Tier 4: Control Plane ─────────────────────────────────────────────────────
step "Tier 4 — Control plane (.NET API)"
docker compose up -d control-plane
wait_http "control-plane API" "http://localhost:8080/health" 90
ok "Tier 4 complete"

if $CONSOLE_ONLY; then
    echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${GREEN}  Console workstream ready.${RESET}"
    echo -e "  console.mosgarage.xyz — workspace provisioning active"
    echo -e "  api.mosgarage.xyz     — control plane healthy"
    echo -e "  Daemon health: curl http://localhost:9090/health"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    exit 0
fi

# ── Tier 5: Platform services (parallel) ──────────────────────────────────────
step "Tier 5 — Platform services (parallel startup)"
docker compose up -d \
    studio-blog \
    studio-docs \
    studio-flipstack \
    community \
    academy \
    ecampus \
    agent

# Wait for all in parallel
pids=()
for svc in studio-blog studio-docs studio-flipstack community academy ecampus agent; do
    wait_healthy "$svc" 120 &
    pids+=($!)
done

all_ok=true
for pid in "${pids[@]}"; do
    wait "$pid" || all_ok=false
done

$all_ok && ok "Tier 5 complete — all services healthy" || \
    fail "Some Tier 5 services failed — check: docker compose logs"

# ── Final status ──────────────────────────────────────────────────────────────
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}  Platform startup complete.${RESET}"
echo -e "  Service health : curl http://localhost:9090/services | jq ."
echo -e "  Traefik dash   : https://traefik.mosgarage.xyz"
echo -e "  API            : https://api.mosgarage.xyz/health"
echo -e "  Console        : https://console.mosgarage.xyz"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

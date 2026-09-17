#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# setup-github-project.sh
# Creates the full mosgarage GitHub Project board via gh CLI.
# Requires: gh CLI authenticated as mosgaragedev
#
# Usage:
#   ./scripts/setup-github-project.sh
#   ./scripts/setup-github-project.sh --dry-run   (print without creating)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

ORG="mosgarage"
REPO="mosgarage-platform"     # main platform repo
DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

YELLOW='\033[1;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'; RESET='\033[0m'
step()  { echo -e "\n${YELLOW}▶ $1${RESET}"; }
ok()    { echo -e "${GREEN}  ✓ $1${RESET}"; }
info()  { echo -e "${CYAN}  → $1${RESET}"; }
run()   {
    if $DRY_RUN; then
        echo -e "${CYAN}  [dry-run] $*${RESET}"
    else
        "$@"
    fi
}

# ── Pre-flight ────────────────────────────────────────────────────────────────
step "Pre-flight checks"
command -v gh   &>/dev/null || { echo "gh CLI not found. Install: https://cli.github.com"; exit 1; }
command -v jq   &>/dev/null || { echo "jq not found. Install: sudo apt install jq"; exit 1; }

if ! gh auth status &>/dev/null; then
    echo -e "${RED}Not authenticated. Run: gh auth login${RESET}"; exit 1
fi
AUTHED_USER=$(gh api user --jq '.login')
ok "Authenticated as: $AUTHED_USER"

# ── Create GitHub Project (v2) ────────────────────────────────────────────────
step "Creating GitHub Project v2"
PROJECT_ID=$(gh project create \
    --owner "$ORG" \
    --title "mosgarage Platform Roadmap" \
    --format json 2>/dev/null | jq -r '.number' || echo "")

if [ -z "$PROJECT_ID" ]; then
    # Project may already exist — find it
    PROJECT_ID=$(gh project list --owner "$ORG" --format json | \
        jq -r '.projects[] | select(.title == "mosgarage Platform Roadmap") | .number')
    ok "Project already exists: #${PROJECT_ID}"
else
    ok "Created project: #${PROJECT_ID}"
fi

# ── Create labels in repo ─────────────────────────────────────────────────────
step "Creating workstream labels in $ORG/$REPO"
declare -A LABELS=(
    ["🏗️ infrastructure"]="0075ca"
    ["⚙️ mosgaraged"]="e4e669"
    ["💻 console"]="d93f0b"
    ["🎨 studio"]="0e8a16"
    ["🤝 community"]="1d76db"
    ["🎓 academy"]="5319e7"
    ["🏫 ecampus"]="b60205"
    ["🤖 agent"]="006b75"
    ["🛠️ dev-environment"]="f9d0c4"
    ["🪟 windows-tooling"]="c5def5"
    ["🚀 ci-cd"]="bfd4f2"
    ["critical"]="ee0701"
    ["high"]="e99695"
    ["medium"]="f9d0c4"
    ["low"]="c2e0c6"
)

for label in "${!LABELS[@]}"; do
    color="${LABELS[$label]}"
    run gh label create "$label" \
        --repo "$ORG/$REPO" \
        --color "$color" \
        --force 2>/dev/null || true
    info "label: $label (#$color)"
done
ok "Labels created"

# ── Create milestones ─────────────────────────────────────────────────────────
step "Creating milestones"
declare -A MILESTONES=(
    ["v0.1 — Foundation"]="2025-08-01"
    ["v0.2 — Console GA"]="2025-09-01"
    ["v0.3 — Studio"]="2025-10-01"
    ["v0.4 — Community + Academy"]="2025-11-01"
    ["v0.5 — eCampus + Agent"]="2025-12-01"
    ["v1.0 — Platform GA"]="2026-01-01"
)

declare -A MILESTONE_IDS
for title in "${!MILESTONES[@]}"; do
    due="${MILESTONES[$title]}"
    id=$(gh api "repos/$ORG/$REPO/milestones" \
        --method POST \
        --field title="$title" \
        --field due_on="${due}T00:00:00Z" \
        --jq '.number' 2>/dev/null || \
        gh api "repos/$ORG/$REPO/milestones" --jq \
            ".[] | select(.title == \"$title\") | .number" 2>/dev/null || echo "")
    MILESTONE_IDS["$title"]="${id:-}"
    info "milestone: $title (due: $due, id: ${id:-existing})"
done
ok "Milestones created"

# ── Create issues ─────────────────────────────────────────────────────────────
step "Creating issues"

create_issue() {
    local title="$1" milestone="$2" labels="$3"
    local mid="${MILESTONE_IDS[$milestone]:-}"

    if $DRY_RUN; then
        echo -e "  [dry-run] issue: \"$title\" → milestone: $milestone labels: $labels"
        return
    fi

    local args=(
        --repo "$ORG/$REPO"
        --title "$title"
        --label "$labels"
    )
    [ -n "$mid" ] && args+=(--milestone "$mid")

    gh issue create "${args[@]}" \
        --body "Part of workstream: $labels | Milestone: $milestone" \
        2>/dev/null || info "Issue may already exist: $title"
}

# ── WS-INFRA ──
create_issue "Set up Traefik v3 with wildcard TLS and forward auth middleware" "v0.1 — Foundation" "🏗️ infrastructure,critical"
create_issue "Configure PostgreSQL 16 with health checks and named volumes" "v0.1 — Foundation" "🏗️ infrastructure,critical"
create_issue "Define mosgarage.platform.yml service registry schema" "v0.1 — Foundation" "🏗️ infrastructure,high"
create_issue "Configure DNS wildcard records (*.mosgarage.xyz)" "v0.1 — Foundation" "🏗️ infrastructure,critical"
create_issue "Entra ID OIDC app registration — covers all platform services" "v0.1 — Foundation" "🏗️ infrastructure,critical"
create_issue "Set up Docker networks and volume strategy" "v0.1 — Foundation" "🏗️ infrastructure,high"

# ── WS-DAEMON ──
create_issue "mosgaraged: service health polling loop" "v0.1 — Foundation" "⚙️ mosgaraged,high"
create_issue "mosgaraged: Unix socket IPC bus" "v0.1 — Foundation" "⚙️ mosgaraged,high"
create_issue "mosgaraged: HTTP API (health, manifest, services, emit)" "v0.1 — Foundation" "⚙️ mosgaraged,high"
create_issue "mosgaraged: systemd service + Docker image (multi-arch)" "v0.1 — Foundation" "⚙️ mosgaraged,high"
create_issue "mosgaraged: idle workspace detection + control plane signal" "v0.1 — Foundation" "⚙️ mosgaraged,medium"
create_issue "mosgaraged: platform version tracking + update notifications" "v0.2 — Console GA" "⚙️ mosgaraged,medium"

# ── WS-CONSOLE ──
create_issue "Build mosgarage/console Docker image (code-server + DevPod + DinD)" "v0.1 — Foundation" "💻 console,critical"
create_issue "Rename mosgarage/codeserver → mosgarage/console on Docker Hub" "v0.1 — Foundation" "💻 console,critical"
create_issue "Control plane: workspace provisioning API (create/stop/delete)" "v0.1 — Foundation" "💻 console,critical"
create_issue "Per-workspace Traefik dynamic routing (ws-{id}.console.mosgarage.xyz)" "v0.1 — Foundation" "💻 console,critical"
create_issue "Container startup automation — ordered init, health gates, readiness probes" "v0.1 — Foundation" "💻 console,critical"
create_issue "Console dashboard — web homepage (workspaces, stats, quick actions)" "v0.2 — Console GA" "💻 console,high"
create_issue "Console dashboard — embedded panel inside code-server" "v0.2 — Console GA" "💻 console,medium"
create_issue "Visual Studio autoload — WSL + workspace picker on launch" "v0.2 — Console GA" "💻 console,high"
create_issue "Multi-arch build for console image (amd64 + arm64)" "v0.2 — Console GA" "💻 console,high"

# ── WS-STUDIO ──
create_issue "Ghost blog setup under studio.mosgarage.xyz" "v0.3 — Studio" "🎨 studio,high"
create_issue "Docusaurus docs site (/docs path)" "v0.3 — Studio" "🎨 studio,high"
create_issue "FlipStack: 3D interactive viewer component (React)" "v0.3 — Studio" "🎨 studio,high"
create_issue "FlipStack: standalone mosgarage/flipstack Docker image" "v0.3 — Studio" "🎨 studio,high"
create_issue "FlipStack: embed script distribution" "v0.3 — Studio" "🎨 studio,medium"
create_issue "Content builder — AMP-style structured authoring" "v0.3 — Studio" "🎨 studio,medium"

# ── WS-COMMUNITY ──
create_issue "Community portal scaffold (Next.js + Discord bridge)" "v0.4 — Community + Academy" "🤝 community,high"
create_issue "Developer profiles (Entra ID + GitHub linked)" "v0.4 — Community + Academy" "🤝 community,medium"

# ── WS-ACADEMY ──
create_issue "Academy portal scaffold (Next.js)" "v0.4 — Community + Academy" "🎓 academy,high"
create_issue "Course structure — modules, lessons, progress tracking" "v0.4 — Community + Academy" "🎓 academy,high"
create_issue "Academy ↔ FlipStack integration (course content as flipbooks)" "v0.4 — Community + Academy" "🎓 academy,medium"

# ── WS-ECAMPUS ──
create_issue "eCampus scaffold (Next.js, Entra ID auth required)" "v0.5 — eCampus + Agent" "🏫 ecampus,high"
create_issue "Org/team management — enrol users, assign courses" "v0.5 — eCampus + Agent" "🏫 ecampus,high"

# ── WS-AGENT ──
create_issue "Agent service scaffold — Fastify + LLM routing" "v0.5 — eCampus + Agent" "🤖 agent,high"
create_issue "Agent: coding assistant inside console (code-server extension)" "v0.5 — eCampus + Agent" "🤖 agent,high"
create_issue "Agent: task automation via mosgaraged IPC bus" "v0.5 — eCampus + Agent" "🤖 agent,medium"

# ── WS-DEVENV ──
create_issue "WSL-first dev setup — ~/dev/localhost as source of truth" "v0.1 — Foundation" "🛠️ dev-environment,high"
create_issue "dev-watcher.sh — inotifywait auto-commit + push" "v0.1 — Foundation" "🛠️ dev-environment,high"
create_issue "Git bare hub — post-receive fan-out to Windows, GitHub, VPS" "v0.1 — Foundation" "🛠️ dev-environment,high"
create_issue "VS Code WSL auto-connect settings" "v0.1 — Foundation" "🛠️ dev-environment,medium"
create_issue "Visual Studio 2022 — WSL + VPS SSH connection config" "v0.2 — Console GA" "🛠️ dev-environment,medium"
create_issue "OneDrive smart backup — dev files + IDE settings + SSH keys" "v0.2 — Console GA" "🛠️ dev-environment,medium"

# ── WS-WINDOWS ──
create_issue "Windows context menu — send highlighted text to Planner/ADO/GitHub" "v0.2 — Console GA" "🪟 windows-tooling,medium"
create_issue "Context menu mini-popup — title, notes, due date, destination picker" "v0.2 — Console GA" "🪟 windows-tooling,medium"

# ── WS-CICD ──
create_issue "GitHub Actions: multi-arch build matrix for all platform images" "v0.1 — Foundation" "🚀 ci-cd,high"
create_issue "GitHub Actions: deploy to Oracle VPS on version tag push" "v0.1 — Foundation" "🚀 ci-cd,high"
create_issue "Semver + CalVer versioning scripts" "v0.1 — Foundation" "🚀 ci-cd,medium"
create_issue "Azure DevOps pipeline mirror" "v0.3 — Studio" "🚀 ci-cd,medium"

ok "All issues created"

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}  Project board ready.${RESET}"
echo -e "  View: https://github.com/orgs/${ORG}/projects/${PROJECT_ID}"
echo -e "  Issues: https://github.com/${ORG}/${REPO}/issues"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"

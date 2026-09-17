#!/usr/bin/env bash
# ============================================================
# mosgarage · workspace-startup.sh
# Entrypoint for dynamically provisioned workspace containers.
# ============================================================
set -euo pipefail

WORKSPACE_ID="${MOSGARAGE_WORKSPACE_ID:-}"
AGENT_TOKEN="${MOSGARAGE_AGENT_TOKEN:-}"
TUNNEL_DNA="${MOSGARAGE_TUNNEL_DNA:-}"
SERVER_URL="${MOSGARAGE_SERVER_URL:-http://mosgarage:7070}"
GIT_REPO="${MOSGARAGE_GIT_REPO:-}"
GIT_BRANCH="${GIT_BRANCH:-main}"

echo "
╔══════════════════════════════════════════════════════╗
║  mosgarage workspace agent                           ║
╠══════════════════════════════════════════════════════╣
║  Workspace : ${WORKSPACE_ID}  
║  Tunnel    : ${TUNNEL_DNA}.try.mosgarage.app
║  Server    : ${SERVER_URL}
╚══════════════════════════════════════════════════════╝
"

# ── Ensure dirs ──────────────────────────────────────────────────
mkdir -p /home/mosgarage/{workspace,.ssh,.config/code-server} /var/log/mosgarage

# ── SSH key (if provided via volume or env) ───────────────────────
if [[ -f "/home/mosgarage/.ssh/id_ed25519" ]]; then
  chmod 600 /home/mosgarage/.ssh/id_ed25519
  echo "SSH key found"
fi

# ── Clone git repo into workspace (if configured) ────────────────
if [[ -n "${GIT_REPO}" && ! -d "/home/mosgarage/workspace/.git" ]]; then
  echo "Cloning ${GIT_REPO} [${GIT_BRANCH}]..."
  git clone --branch "${GIT_BRANCH}" --single-branch \
    "${GIT_REPO}" /home/mosgarage/workspace 2>&1 || \
  git clone "${GIT_REPO}" /home/mosgarage/workspace 2>&1 || true
fi

# ── code-server config ────────────────────────────────────────────
cat > /home/mosgarage/.config/code-server/config.yaml <<EOF
bind-addr: 0.0.0.0:8080
auth: password
password: ${CODE_SERVER_PASSWORD:-${AGENT_TOKEN:0:12}}
cert: false
user-data-dir: /home/mosgarage/.code-server
extensions-dir: /home/mosgarage/.code-server/extensions
EOF

# ── Run git-setup for GitHub backup ──────────────────────────────
if command -v git-setup &>/dev/null; then
  git-setup 2>&1 || echo "git-setup warning (non-fatal)"
fi

# ── Install VS Code extensions (background) ──────────────────────
(
  sleep 15
  code-server \
    --install-extension ms-python.python \
    --install-extension dbaeumer.vscode-eslint \
    --install-extension esbenp.prettier-vscode \
    --install-extension eamodio.gitlens \
    --install-extension PKief.material-icon-theme \
    --install-extension GitHub.vscode-pull-request-github \
    2>/dev/null || true
  echo "VS Code extensions installed"
) &

# ── SSH server setup ─────────────────────────────────────────────
echo "Setting up SSH server..."
ssh-setup 2>&1 | tee -a /var/log/mosgarage/ssh-setup.log || echo "ssh-setup warning (non-fatal)"

# ── Launch supervisor (agent + code-server + git-sync + apps) ─────
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/workspace.conf

#!/usr/bin/env bash
# ============================================================
# mosgarage · startup.sh — control plane entrypoint
# ============================================================
set -euo pipefail

echo "
╔══════════════════════════════════════════════════════╗
║  mosgarage · control plane                           ║
╠══════════════════════════════════════════════════════╣
║  .NET 8 ASP.NET Core                                 ║
║  SignalR  · EF Core · PostgreSQL · Docker prov.      ║
╚══════════════════════════════════════════════════════╝
"

# ── SSH key permissions (for git sync) ───────────────────────────
SSH_DIR="/home/mosgarage/.ssh"
mkdir -p "${SSH_DIR}" && chmod 700 "${SSH_DIR}"
[[ -f "${SSH_DIR}/id_ed25519" ]] && chmod 600 "${SSH_DIR}/id_ed25519"

# ── Ensure Unix socket dir is writable ───────────────────────────
SOCK_DIR=$(dirname "${MOSGARAGE_SOCKET_PATH:-/var/run/mosgarage.sock}")
mkdir -p "${SOCK_DIR}" 2>/dev/null || true

# ── SSH setup ────────────────────────────────────────────────────
ssh-setup 2>&1 | tee -a /var/log/mosgarage/ssh-setup.log || echo "ssh-setup warning"

# ── Git setup (background, non-blocking) ─────────────────────────
if [[ -n "${GITHUB_TOKEN:-}" ]] || [[ -f "${SSH_DIR}/id_ed25519" ]]; then
  (git-setup 2>&1 | tee -a /var/log/mosgarage/git-sync.log) &
fi

# ── Launch .NET control plane ─────────────────────────────────────
exec dotnet /app/server/Mosgarage.Server.dll

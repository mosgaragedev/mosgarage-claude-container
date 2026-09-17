#!/usr/bin/env bash
# ============================================================
# mosgarage · ssh-setup.sh
# Auto-generates all SSH host keys, authorized_keys, and
# optionally a client keypair. Runs on every container start.
# Idempotent — safe to call multiple times.
# ============================================================

set -euo pipefail

HOST_KEYS_DIR="/etc/ssh/host_keys"
AUTH_KEYS_DIR="/etc/ssh/authorized_keys"
CLIENT_KEYS_DIR="/home/mosgarage/.ssh"
LOG="/var/log/mosgarage/ssh-setup.log"
BANNER="/etc/ssh/mosgarage-banner.txt"

log() { echo "[ssh-setup] $(date '+%H:%M:%S') $*" | tee -a "$LOG"; }

# ── Create dirs ───────────────────────────────────────────────────
mkdir -p "${HOST_KEYS_DIR}" "${AUTH_KEYS_DIR}" "${CLIENT_KEYS_DIR}"
chmod 700 "${HOST_KEYS_DIR}" "${CLIENT_KEYS_DIR}"
chmod 755 "${AUTH_KEYS_DIR}"

# ── Generate host keys (if missing) ──────────────────────────────
generate_host_key() {
  local type="$1"
  local file="${HOST_KEYS_DIR}/ssh_host_${type}_key"
  if [[ ! -f "${file}" ]]; then
    log "Generating ${type} host key..."
    ssh-keygen -t "${type}" -f "${file}" -N "" -q
    chmod 600 "${file}"
    chmod 644 "${file}.pub"
    log "  ✅ ${type} host key created"
  else
    log "  ✔  ${type} host key exists"
  fi
}

generate_host_key ed25519
generate_host_key rsa
generate_host_key ecdsa

# ── Authorized keys — multiple sources ───────────────────────────
AUTH_KEYS_FILE="${AUTH_KEYS_DIR}/mosgarage"
> "${AUTH_KEYS_FILE}"   # reset on each run

# Source 1: MOSGARAGE_SSH_PUBLIC_KEY env var
if [[ -n "${MOSGARAGE_SSH_PUBLIC_KEY:-}" ]]; then
  log "Adding SSH key from MOSGARAGE_SSH_PUBLIC_KEY env var"
  echo "${MOSGARAGE_SSH_PUBLIC_KEY}" >> "${AUTH_KEYS_FILE}"
fi

# Source 2: MOSGARAGE_SSH_PUBLIC_KEYS (newline-separated, base64-encoded)
if [[ -n "${MOSGARAGE_SSH_PUBLIC_KEYS_B64:-}" ]]; then
  log "Adding SSH keys from MOSGARAGE_SSH_PUBLIC_KEYS_B64"
  echo "${MOSGARAGE_SSH_PUBLIC_KEYS_B64}" | base64 -d >> "${AUTH_KEYS_FILE}"
fi

# Source 3: Mounted file at /home/mosgarage/.ssh/authorized_keys
if [[ -f "${CLIENT_KEYS_DIR}/authorized_keys" ]]; then
  log "Adding keys from mounted authorized_keys"
  cat "${CLIENT_KEYS_DIR}/authorized_keys" >> "${AUTH_KEYS_FILE}"
fi

# Source 4: GitHub public keys (fetch user's keys from GitHub API)
if [[ -n "${GITHUB_USER:-}" ]] && command -v curl &>/dev/null; then
  log "Fetching SSH keys from github.com/${GITHUB_USER}..."
  GITHUB_KEYS=$(curl -sf "https://github.com/${GITHUB_USER}.keys" 2>/dev/null || echo "")
  if [[ -n "${GITHUB_KEYS}" ]]; then
    echo "# GitHub keys for ${GITHUB_USER}" >> "${AUTH_KEYS_FILE}"
    echo "${GITHUB_KEYS}" >> "${AUTH_KEYS_FILE}"
    COUNT=$(echo "${GITHUB_KEYS}" | grep -c "ssh-" || true)
    log "  ✅ Added ${COUNT} key(s) from GitHub for ${GITHUB_USER}"
  else
    log "  ⚠️  No public keys found on github.com/${GITHUB_USER}"
  fi
fi

chmod 600 "${AUTH_KEYS_FILE}"
KEY_COUNT=$(grep -c "ssh-" "${AUTH_KEYS_FILE}" 2>/dev/null || echo "0")
log "Total authorized keys: ${KEY_COUNT}"

if [[ "${KEY_COUNT}" -eq 0 ]]; then
  log "⚠️  WARNING: No authorized keys found!"
  log "   Set MOSGARAGE_SSH_PUBLIC_KEY env var OR"
  log "   Mount your ~/.ssh/id_ed25519.pub to /home/mosgarage/.ssh/authorized_keys OR"
  log "   Add your SSH key to github.com/${GITHUB_USER:-<username>}"

  # In dev mode: enable password auth as fallback
  if [[ "${MOSGARAGE_ENV:-production}" != "production" ]]; then
    log "DEV MODE: Enabling password authentication as fallback"
    sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null || true
  fi
fi

# ── Generate client keypair (if requested) ────────────────────────
if [[ "${MOSGARAGE_SSH_GENERATE_CLIENT_KEY:-false}" == "true" ]]; then
  CLIENT_KEY="${CLIENT_KEYS_DIR}/id_ed25519"
  if [[ ! -f "${CLIENT_KEY}" ]]; then
    log "Generating client Ed25519 keypair for mosgarage user..."
    ssh-keygen -t ed25519 -f "${CLIENT_KEY}" -N "" \
      -C "mosgarage@$(hostname)-$(date +%Y%m%d)" -q
    chmod 600 "${CLIENT_KEY}"
    chmod 644 "${CLIENT_KEY}.pub"
    # Auto-authorize own key
    cat "${CLIENT_KEY}.pub" >> "${AUTH_KEYS_FILE}"
    log "  ✅ Client keypair generated: ${CLIENT_KEY}"
    log "  📋 Public key:"
    cat "${CLIENT_KEY}.pub"
  fi
fi

# ── SSH client config (for git and outbound connections) ─────────
cat > "${CLIENT_KEYS_DIR}/config" <<EOF
# mosgarage SSH client config
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  StrictHostKeyChecking no
  ServerAliveInterval 60

Host *
  ServerAliveInterval 60
  ServerAliveCountMax 5
  StrictHostKeyChecking accept-new
  AddKeysToAgent yes
  IdentityFile ~/.ssh/id_ed25519
EOF
chmod 600 "${CLIENT_KEYS_DIR}/config"

# ── Fix ownership ────────────────────────────────────────────────
chown -R mosgarage:mosgarage "${CLIENT_KEYS_DIR}" 2>/dev/null || true

# ── Enable/disable password auth from env ────────────────────────
if [[ "${MOSGARAGE_SSH_ALLOW_PASSWORD:-false}" == "true" ]]; then
  log "Password authentication ENABLED (MOSGARAGE_SSH_ALLOW_PASSWORD=true)"
  sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' \
    /etc/ssh/sshd_config 2>/dev/null || true
fi

# ── Print connection info ─────────────────────────────────────────
HOSTNAME_OUT=$(hostname 2>/dev/null || echo "localhost")
log ""
log "╔══════════════════════════════════════════════════╗"
log "║  SSH server ready                                ║"
log "╠══════════════════════════════════════════════════╣"
log "║  Port      : 2222                                ║"
log "║  User      : mosgarage                           ║"
log "║  Auth keys : ${KEY_COUNT}                                    "
log "╠══════════════════════════════════════════════════╣"
log "║  Connect:                                        ║"
log "║  ssh -p 2222 mosgarage@${HOSTNAME_OUT}           "
log "║                                                  ║"
log "║  VS Code Remote-SSH:                             ║"
log "║  Add to ~/.ssh/config:                           ║"
log "║    Host mosgarage                                ║"
log "║      HostName ${HOSTNAME_OUT}                    "
log "║      Port 2222                                   ║"
log "║      User mosgarage                              ║"
log "╚══════════════════════════════════════════════════╝"

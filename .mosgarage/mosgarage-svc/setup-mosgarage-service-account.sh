#!/usr/bin/env bash
# setup-mosgarage-service-account.sh
#
# Creates a dedicated, least-privilege system account to run the mosgarage
# control plane (Mosgarage.Server / Mosgarage.Agent / mosgaraged / Traefik)
# on a Linux host. No login shell, docker-group membership for container
# management, scoped sudoers (systemctl only — no root shell), optional
# systemd unit + CAP_NET_BIND_SERVICE if the agent ever needs to bind a
# privileged port directly on the host (not needed for a Docker-fronted
# stack, since the Docker daemon does that binding for you).
#
# This is a standalone bootstrap for boxes that don't have pwsh installed
# yet (e.g. a brand-new OCI VPS). Once pwsh + your mosgarage-dotfiles
# profile are deployed, New-MosgarageServiceAccount.ps1 covers the same
# ground and also handles Windows.

set -euo pipefail

SVC_USER="${MG_SVC_USER:-mosgarage-svc}"
SVC_HOME="${MG_SVC_HOME:-/opt/mosgarage}"
SVC_SHELL="/usr/sbin/nologin"
BIN_PATH="${MG_AGENT_BIN:-$SVC_HOME/bin/Mosgarage.Agent}"
DIRS=(bin data logs workspaces certs)
INSTALL_SERVICE=0
UNINSTALL=0

usage() {
  cat <<EOF
Usage: sudo $0 [options]

  --user NAME       service account name       (default: mosgarage-svc)
  --home PATH       home / data root            (default: /opt/mosgarage)
  --bin PATH        path to Mosgarage.Agent binary
  --install-service  also install + enable the systemd unit (skipped under WSL2)
  --uninstall        remove the account, sudoers entry, and systemd unit
  -h, --help          show this help

Env var overrides: MG_SVC_USER, MG_SVC_HOME, MG_AGENT_BIN
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user) SVC_USER="$2"; shift 2 ;;
    --home) SVC_HOME="$2"; shift 2 ;;
    --bin) BIN_PATH="$2"; shift 2 ;;
    --install-service) INSTALL_SERVICE=1; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ $EUID -ne 0 ]]; then
  echo "Run as root (sudo $0 ...)." >&2
  exit 1
fi

is_wsl() {
  grep -qi microsoft /proc/version 2>/dev/null
}

if [[ $UNINSTALL -eq 1 ]]; then
  echo "==> Removing $SVC_USER"
  systemctl disable --now mosgarage-agent.service 2>/dev/null || true
  rm -f /etc/systemd/system/mosgarage-agent.service
  rm -f "/etc/sudoers.d/${SVC_USER}"
  userdel -r "$SVC_USER" 2>/dev/null || echo "    (user already absent)"
  systemctl daemon-reload 2>/dev/null || true
  echo "Done."
  exit 0
fi

echo "==> Creating service account: $SVC_USER"
if id "$SVC_USER" &>/dev/null; then
  echo "    already exists, skipping useradd"
else
  useradd --system --create-home --home-dir "$SVC_HOME" \
    --shell "$SVC_SHELL" --comment "mosgarage platform service account" \
    "$SVC_USER"
fi

echo "==> Directory layout under $SVC_HOME"
for d in "${DIRS[@]}"; do
  install -d -m 750 -o "$SVC_USER" -g "$SVC_USER" "$SVC_HOME/$d"
done

echo "==> docker group membership"
if getent group docker >/dev/null; then
  usermod -aG docker "$SVC_USER"
  echo "    added (needed for Docker.DotNet / the workspace provisioner)"
else
  echo "    docker group not found yet — install Docker Engine first, then re-run"
fi

echo "==> CAP_NET_BIND_SERVICE on the agent binary (optional)"
echo "    only relevant if a mosgarage process binds a port <1024 directly on"
echo "    the host (e.g. Traefik run outside Docker). Your documented ports —"
echo "    8080/3000/4000/7072/2222 — don't need this; Docker itself owns 80/443"
echo "    binding for containerized Traefik. Skipping unless --bin resolves."
if [[ -f "$BIN_PATH" ]]; then
  setcap 'cap_net_bind_service=+ep' "$BIN_PATH" \
    && echo "    granted to $BIN_PATH"
else
  echo "    $BIN_PATH not present — run manually later if you ever need it:"
  echo "      sudo setcap 'cap_net_bind_service=+ep' $BIN_PATH"
fi

echo "==> Scoped sudoers (systemctl control only — never a root shell)"
SUDOERS_FILE="/etc/sudoers.d/${SVC_USER}"
cat > "$SUDOERS_FILE" <<EOF
# Managed by setup-mosgarage-service-account.sh — do not hand-edit
Cmnd_Alias MG_SERVICES = /usr/bin/systemctl restart mosgarage-agent, \\
                          /usr/bin/systemctl restart mosgarage-server, \\
                          /usr/bin/systemctl restart traefik, \\
                          /usr/bin/systemctl status mosgarage-*
${SVC_USER} ALL=(root) NOPASSWD: MG_SERVICES
EOF
chmod 440 "$SUDOERS_FILE"
if ! visudo -cf "$SUDOERS_FILE"; then
  echo "    sudoers syntax check failed — removing file" >&2
  rm -f "$SUDOERS_FILE"
fi

if is_wsl; then
  echo "==> WSL2 detected — skipping systemd unit"
  echo "    (enable systemd in /etc/wsl.conf first if you want one: [boot]\\nsystemd=true)"
elif [[ $INSTALL_SERVICE -eq 1 ]]; then
  echo "==> Installing systemd unit"
  cat > /etc/systemd/system/mosgarage-agent.service <<EOF
[Unit]
Description=Mosgarage Agent (workspace/dev-container control plane)
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=simple
User=${SVC_USER}
Group=${SVC_USER}
WorkingDirectory=${SVC_HOME}
ExecStart=${BIN_PATH}
Restart=on-failure
RestartSec=5
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${SVC_HOME}
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  echo "    unit installed (not started). Enable with:"
  echo "      systemctl enable --now mosgarage-agent"
else
  echo "==> Skipping systemd unit (pass --install-service to create it)"
fi

echo
echo "=== Summary ==="
id "$SVC_USER"
echo "Home:   $SVC_HOME"
echo "Shell:  $SVC_SHELL (service-only — no interactive/SSH login as this user)"
echo "Groups: $(id -nG "$SVC_USER")"
echo "Done."

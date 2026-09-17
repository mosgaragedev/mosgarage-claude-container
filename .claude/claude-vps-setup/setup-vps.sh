#!/bin/bash
#
# Claude Code VPS Setup Script
# ============================
# A comprehensive, idempotent setup script for running Claude Code persistently on a VPS.
#
# Author: Matt Fitzgerald / Hillway Property Consultants
# Created: December 2024
#
# Usage:
#   chmod +x setup-vps.sh
#   sudo ./setup-vps.sh
#
# Features:
#   - Updates system packages
#   - Installs Node.js 20 LTS
#   - Installs Claude Code globally
#   - Installs tmux, mosh, git, and essentials
#   - Configures tmux with mouse support and better colors
#   - Creates systemd service for persistent Claude Code sessions
#   - Sets up automatic session recovery
#   - Creates helper scripts for common operations
#

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

CLAUDE_USER="${CLAUDE_USER:-claude}"
CLAUDE_HOME="/home/${CLAUDE_USER}"
TMUX_SESSION_NAME="claude"
NODE_VERSION="20"

# =============================================================================
# COLOR OUTPUT
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}  $1${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

# =============================================================================
# PREREQUISITE CHECKS
# =============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
        print_info "Detected OS: $OS $OS_VERSION"
    else
        print_error "Cannot detect OS. This script supports Ubuntu/Debian."
        exit 1
    fi

    if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
        print_warning "This script is optimized for Ubuntu/Debian. Proceeding anyway..."
    fi
}

# =============================================================================
# SYSTEM UPDATES
# =============================================================================

update_system() {
    print_header "Updating System Packages"

    print_step "Updating package lists..."
    apt-get update -qq
    print_success "Package lists updated"

    print_step "Upgrading installed packages..."
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq
    print_success "Packages upgraded"

    print_step "Installing essential packages..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        curl \
        wget \
        git \
        tmux \
        mosh \
        htop \
        vim \
        nano \
        build-essential \
        ca-certificates \
        gnupg \
        lsb-release \
        unzip \
        jq \
        tree \
        ncdu \
        fail2ban \
        ufw
    print_success "Essential packages installed"
}

# =============================================================================
# NODE.JS INSTALLATION
# =============================================================================

install_nodejs() {
    print_header "Installing Node.js ${NODE_VERSION} LTS"

    # Check if Node.js is already installed with correct version
    if command -v node &> /dev/null; then
        CURRENT_NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ "$CURRENT_NODE_VERSION" == "$NODE_VERSION" ]]; then
            print_success "Node.js ${NODE_VERSION} is already installed ($(node -v))"
            return 0
        else
            print_warning "Node.js $CURRENT_NODE_VERSION found, upgrading to ${NODE_VERSION}..."
        fi
    fi

    print_step "Adding NodeSource repository..."
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - > /dev/null 2>&1
    print_success "NodeSource repository added"

    print_step "Installing Node.js..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nodejs
    print_success "Node.js installed: $(node -v)"
    print_success "npm installed: $(npm -v)"
}

# =============================================================================
# CLAUDE CODE INSTALLATION
# =============================================================================

install_claude_code() {
    print_header "Installing Claude Code"

    # Check if already installed
    if command -v claude &> /dev/null; then
        print_success "Claude Code is already installed"
        print_step "Checking for updates..."
        npm update -g @anthropic-ai/claude-code 2>/dev/null || true
        print_success "Claude Code is up to date"
    else
        print_step "Installing Claude Code globally..."
        npm install -g @anthropic-ai/claude-code
        print_success "Claude Code installed successfully"
    fi

    # Verify installation
    if command -v claude &> /dev/null; then
        print_info "Claude Code location: $(which claude)"
    else
        print_error "Claude Code installation failed"
        exit 1
    fi
}

# =============================================================================
# USER SETUP
# =============================================================================

setup_user() {
    print_header "Setting Up Claude User"

    # Create user if doesn't exist
    if id "$CLAUDE_USER" &>/dev/null; then
        print_success "User '$CLAUDE_USER' already exists"
    else
        print_step "Creating user '$CLAUDE_USER'..."
        useradd -m -s /bin/bash "$CLAUDE_USER"
        print_success "User '$CLAUDE_USER' created"
    fi

    # Add to sudo group (optional, comment out if not needed)
    if groups "$CLAUDE_USER" | grep -q sudo; then
        print_success "User already in sudo group"
    else
        print_step "Adding user to sudo group..."
        usermod -aG sudo "$CLAUDE_USER"
        print_success "User added to sudo group"
    fi

    # Create necessary directories
    print_step "Creating directories..."
    mkdir -p "${CLAUDE_HOME}/.claude"
    mkdir -p "${CLAUDE_HOME}/projects"
    mkdir -p "${CLAUDE_HOME}/.local/bin"
    mkdir -p "${CLAUDE_HOME}/logs"
    chown -R "${CLAUDE_USER}:${CLAUDE_USER}" "${CLAUDE_HOME}"
    print_success "Directories created"
}

# =============================================================================
# TMUX CONFIGURATION
# =============================================================================

configure_tmux() {
    print_header "Configuring tmux"

    TMUX_CONF="${CLAUDE_HOME}/.tmux.conf"

    print_step "Creating tmux configuration..."
    cat > "$TMUX_CONF" << 'TMUX_EOF'
# =============================================================================
# Claude Code tmux Configuration
# =============================================================================

# Use C-a as prefix (easier than C-b)
unbind C-b
set-option -g prefix C-a
bind-key C-a send-prefix

# Enable mouse support
set -g mouse on

# Increase scrollback buffer
set -g history-limit 50000

# Start windows and panes at 1, not 0
set -g base-index 1
setw -g pane-base-index 1

# Renumber windows when one is closed
set -g renumber-windows on

# Enable 256 colors
set -g default-terminal "screen-256color"
set -ga terminal-overrides ",*256col*:Tc"

# Faster command sequences
set -s escape-time 10

# Increase repeat timeout
set -sg repeat-time 600

# Focus events (for vim)
set -g focus-events on

# Activity monitoring
setw -g monitor-activity on
set -g visual-activity off

# -----------------------------------------------------------------------------
# Status Bar
# -----------------------------------------------------------------------------

set -g status-interval 5
set -g status-position bottom
set -g status-bg colour234
set -g status-fg colour137

set -g status-left-length 40
set -g status-left '#[fg=colour233,bg=colour245,bold] #S #[bg=colour234] '

set -g status-right-length 80
set -g status-right '#[fg=colour245] %H:%M #[fg=colour233,bg=colour245,bold] %d-%b-%Y '

setw -g window-status-current-format '#[fg=colour234,bg=colour81,bold] #I:#W#F '
setw -g window-status-format ' #I:#W#F '

# -----------------------------------------------------------------------------
# Pane Borders
# -----------------------------------------------------------------------------

set -g pane-border-style fg=colour238
set -g pane-active-border-style fg=colour81

# -----------------------------------------------------------------------------
# Key Bindings
# -----------------------------------------------------------------------------

# Split panes with | and -
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %

# Navigate panes with vim keys
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Resize panes with vim keys
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# Reload config
bind r source-file ~/.tmux.conf \; display-message "Config reloaded!"

# Quick window switching
bind -n M-1 select-window -t 1
bind -n M-2 select-window -t 2
bind -n M-3 select-window -t 3
bind -n M-4 select-window -t 4
bind -n M-5 select-window -t 5

# Create new window in current path
bind c new-window -c "#{pane_current_path}"

# Kill pane/window without confirmation
bind x kill-pane
bind X kill-window

# -----------------------------------------------------------------------------
# Copy Mode (vim-like)
# -----------------------------------------------------------------------------

setw -g mode-keys vi
bind -T copy-mode-vi v send -X begin-selection
bind -T copy-mode-vi y send -X copy-selection-and-cancel
bind -T copy-mode-vi Escape send -X cancel

# -----------------------------------------------------------------------------
# Session Management
# -----------------------------------------------------------------------------

# Save and restore sessions (requires tmux-resurrect plugin, optional)
# set -g @plugin 'tmux-plugins/tmux-resurrect'
# set -g @plugin 'tmux-plugins/tmux-continuum'
# set -g @continuum-restore 'on'

TMUX_EOF

    chown "${CLAUDE_USER}:${CLAUDE_USER}" "$TMUX_CONF"
    print_success "tmux configuration created at $TMUX_CONF"
}

# =============================================================================
# SYSTEMD SERVICE
# =============================================================================

create_systemd_service() {
    print_header "Creating Systemd Service"

    SERVICE_FILE="/etc/systemd/system/claude-tmux.service"

    print_step "Creating systemd service file..."
    cat > "$SERVICE_FILE" << SERVICE_EOF
[Unit]
Description=Claude Code tmux Session
After=network.target

[Service]
Type=forking
User=${CLAUDE_USER}
Group=${CLAUDE_USER}
WorkingDirectory=${CLAUDE_HOME}

# Start tmux session
ExecStart=/usr/bin/tmux new-session -d -s ${TMUX_SESSION_NAME} -c ${CLAUDE_HOME}/projects

# Stop tmux session
ExecStop=/usr/bin/tmux kill-session -t ${TMUX_SESSION_NAME}

# Restart configuration
Restart=on-failure
RestartSec=10

# Environment
Environment="HOME=${CLAUDE_HOME}"
Environment="PATH=/usr/local/bin:/usr/bin:/bin:${CLAUDE_HOME}/.local/bin"

[Install]
WantedBy=multi-user.target
SERVICE_EOF

    print_success "Service file created at $SERVICE_FILE"

    print_step "Reloading systemd daemon..."
    systemctl daemon-reload
    print_success "Systemd daemon reloaded"

    print_step "Enabling service..."
    systemctl enable claude-tmux.service
    print_success "Service enabled (will start on boot)"
}

# =============================================================================
# HELPER SCRIPTS
# =============================================================================

create_helper_scripts() {
    print_header "Creating Helper Scripts"

    BIN_DIR="${CLAUDE_HOME}/.local/bin"

    # -------------------------------------------------------------------------
    # claude-attach: Attach to Claude tmux session
    # -------------------------------------------------------------------------
    print_step "Creating claude-attach script..."
    cat > "${BIN_DIR}/claude-attach" << 'SCRIPT_EOF'
#!/bin/bash
# Attach to the Claude Code tmux session

SESSION_NAME="${CLAUDE_SESSION_NAME:-claude}"

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    tmux attach-session -t "$SESSION_NAME"
else
    echo "No Claude session found. Starting new session..."
    tmux new-session -s "$SESSION_NAME" -c ~/projects
fi
SCRIPT_EOF
    chmod +x "${BIN_DIR}/claude-attach"
    print_success "Created: claude-attach"

    # -------------------------------------------------------------------------
    # claude-start: Start Claude Code in tmux
    # -------------------------------------------------------------------------
    print_step "Creating claude-start script..."
    cat > "${BIN_DIR}/claude-start" << 'SCRIPT_EOF'
#!/bin/bash
# Start Claude Code in the tmux session

SESSION_NAME="${CLAUDE_SESSION_NAME:-claude}"
WINDOW_NAME="claude-code"

# Check if session exists
if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Creating new tmux session..."
    tmux new-session -d -s "$SESSION_NAME" -c ~/projects
fi

# Check if Claude window exists
if tmux list-windows -t "$SESSION_NAME" | grep -q "$WINDOW_NAME"; then
    echo "Claude Code window already exists. Selecting it..."
    tmux select-window -t "$SESSION_NAME:$WINDOW_NAME"
else
    echo "Creating Claude Code window..."
    tmux new-window -t "$SESSION_NAME" -n "$WINDOW_NAME" -c ~/projects
    tmux send-keys -t "$SESSION_NAME:$WINDOW_NAME" "claude" Enter
fi

echo "Claude Code started. Use 'claude-attach' to connect."
SCRIPT_EOF
    chmod +x "${BIN_DIR}/claude-start"
    print_success "Created: claude-start"

    # -------------------------------------------------------------------------
    # claude-stop: Stop Claude Code session
    # -------------------------------------------------------------------------
    print_step "Creating claude-stop script..."
    cat > "${BIN_DIR}/claude-stop" << 'SCRIPT_EOF'
#!/bin/bash
# Stop the Claude Code tmux session gracefully

SESSION_NAME="${CLAUDE_SESSION_NAME:-claude}"

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Stopping Claude session..."
    # Send Ctrl+C to interrupt any running process
    tmux send-keys -t "$SESSION_NAME" C-c
    sleep 1
    # Kill the session
    tmux kill-session -t "$SESSION_NAME"
    echo "Claude session stopped."
else
    echo "No Claude session running."
fi
SCRIPT_EOF
    chmod +x "${BIN_DIR}/claude-stop"
    print_success "Created: claude-stop"

    # -------------------------------------------------------------------------
    # claude-status: Check Claude session status
    # -------------------------------------------------------------------------
    print_step "Creating claude-status script..."
    cat > "${BIN_DIR}/claude-status" << 'SCRIPT_EOF'
#!/bin/bash
# Check status of Claude Code session

SESSION_NAME="${CLAUDE_SESSION_NAME:-claude}"

echo "======================================"
echo "  Claude Code Session Status"
echo "======================================"
echo

# Check tmux session
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "[ACTIVE] tmux session '$SESSION_NAME' is running"
    echo
    echo "Windows:"
    tmux list-windows -t "$SESSION_NAME"
else
    echo "[STOPPED] No tmux session found"
fi

echo
echo "--------------------------------------"
echo "  Systemd Service Status"
echo "--------------------------------------"
systemctl status claude-tmux.service --no-pager -l 2>/dev/null || echo "Service not installed"

echo
echo "--------------------------------------"
echo "  Quick Commands"
echo "--------------------------------------"
echo "  claude-attach  - Connect to session"
echo "  claude-start   - Start Claude Code"
echo "  claude-stop    - Stop session"
echo "  claude-restart - Restart session"
SCRIPT_EOF
    chmod +x "${BIN_DIR}/claude-status"
    print_success "Created: claude-status"

    # -------------------------------------------------------------------------
    # claude-restart: Restart Claude session
    # -------------------------------------------------------------------------
    print_step "Creating claude-restart script..."
    cat > "${BIN_DIR}/claude-restart" << 'SCRIPT_EOF'
#!/bin/bash
# Restart the Claude Code session

echo "Restarting Claude Code session..."
claude-stop 2>/dev/null
sleep 2
claude-start
echo "Done!"
SCRIPT_EOF
    chmod +x "${BIN_DIR}/claude-restart"
    print_success "Created: claude-restart"

    # -------------------------------------------------------------------------
    # claude-logs: View logs
    # -------------------------------------------------------------------------
    print_step "Creating claude-logs script..."
    cat > "${BIN_DIR}/claude-logs" << 'SCRIPT_EOF'
#!/bin/bash
# View Claude Code related logs

echo "======================================"
echo "  Claude Code Logs"
echo "======================================"

if [[ "$1" == "-f" || "$1" == "--follow" ]]; then
    echo "Following systemd logs (Ctrl+C to stop)..."
    journalctl -u claude-tmux.service -f
else
    echo "Last 50 log entries:"
    journalctl -u claude-tmux.service -n 50 --no-pager
    echo
    echo "Use 'claude-logs -f' to follow logs in real-time"
fi
SCRIPT_EOF
    chmod +x "${BIN_DIR}/claude-logs"
    print_success "Created: claude-logs"

    # -------------------------------------------------------------------------
    # claude-update: Update Claude Code
    # -------------------------------------------------------------------------
    print_step "Creating claude-update script..."
    cat > "${BIN_DIR}/claude-update" << 'SCRIPT_EOF'
#!/bin/bash
# Update Claude Code to the latest version

echo "Updating Claude Code..."
sudo npm update -g @anthropic-ai/claude-code

echo
echo "Current version:"
claude --version 2>/dev/null || echo "Claude Code not found"
SCRIPT_EOF
    chmod +x "${BIN_DIR}/claude-update"
    print_success "Created: claude-update"

    # Set ownership
    chown -R "${CLAUDE_USER}:${CLAUDE_USER}" "$BIN_DIR"

    # Add to PATH in .bashrc if not already there
    BASHRC="${CLAUDE_HOME}/.bashrc"
    if ! grep -q "\.local/bin" "$BASHRC" 2>/dev/null; then
        print_step "Adding helper scripts to PATH..."
        echo '' >> "$BASHRC"
        echo '# Claude Code helper scripts' >> "$BASHRC"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$BASHRC"
        echo 'export CLAUDE_SESSION_NAME="claude"' >> "$BASHRC"
        chown "${CLAUDE_USER}:${CLAUDE_USER}" "$BASHRC"
        print_success "PATH updated in .bashrc"
    fi
}

# =============================================================================
# ENVIRONMENT SETUP
# =============================================================================

setup_environment() {
    print_header "Setting Up Environment"

    ENV_FILE="${CLAUDE_HOME}/.claude/env"

    print_step "Creating environment template..."
    cat > "$ENV_FILE" << 'ENV_EOF'
# Claude Code Environment Configuration
# =====================================
# Copy this file to ~/.bashrc or source it

# Anthropic API Key (REQUIRED)
# Get your key from: https://console.anthropic.com/
# export ANTHROPIC_API_KEY="sk-ant-..."

# Optional: Extended thinking tokens
export CLAUDE_CODE_MAX_THINKING_TOKENS=10000

# Optional: Default model
# export CLAUDE_CODE_MODEL="claude-opus-4-5-20251101"

# Optional: tmux session name
export CLAUDE_SESSION_NAME="claude"
ENV_EOF

    chown "${CLAUDE_USER}:${CLAUDE_USER}" "$ENV_FILE"
    print_success "Environment template created at $ENV_FILE"
    print_warning "Remember to set ANTHROPIC_API_KEY!"
}

# =============================================================================
# FIREWALL CONFIGURATION
# =============================================================================

configure_firewall() {
    print_header "Configuring Firewall"

    print_step "Configuring UFW..."

    # Allow SSH
    ufw allow OpenSSH > /dev/null 2>&1
    print_success "SSH allowed"

    # Allow mosh (UDP 60000-61000)
    ufw allow 60000:61000/udp > /dev/null 2>&1
    print_success "Mosh ports allowed (60000-61000/udp)"

    # Enable firewall if not already enabled
    if ufw status | grep -q "Status: inactive"; then
        print_step "Enabling firewall..."
        echo "y" | ufw enable > /dev/null 2>&1
        print_success "Firewall enabled"
    else
        print_success "Firewall already active"
    fi

    print_info "Firewall status:"
    ufw status numbered
}

# =============================================================================
# FINAL SETUP
# =============================================================================

print_summary() {
    print_header "Setup Complete!"

    echo -e "${GREEN}Claude Code VPS setup completed successfully!${NC}"
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  NEXT STEPS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "  1. ${YELLOW}Set your Anthropic API key:${NC}"
    echo -e "     su - ${CLAUDE_USER}"
    echo -e "     echo 'export ANTHROPIC_API_KEY=\"sk-ant-...\"' >> ~/.bashrc"
    echo -e "     source ~/.bashrc"
    echo
    echo -e "  2. ${YELLOW}Start the Claude Code service:${NC}"
    echo -e "     sudo systemctl start claude-tmux.service"
    echo
    echo -e "  3. ${YELLOW}Attach to the session:${NC}"
    echo -e "     su - ${CLAUDE_USER}"
    echo -e "     claude-attach"
    echo
    echo -e "  4. ${YELLOW}Start Claude Code:${NC}"
    echo -e "     claude"
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  HELPER COMMANDS (as ${CLAUDE_USER} user)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "  ${GREEN}claude-attach${NC}   - Connect to the tmux session"
    echo -e "  ${GREEN}claude-start${NC}    - Start Claude Code in tmux"
    echo -e "  ${GREEN}claude-stop${NC}     - Stop the Claude session"
    echo -e "  ${GREEN}claude-restart${NC}  - Restart the session"
    echo -e "  ${GREEN}claude-status${NC}   - Check session status"
    echo -e "  ${GREEN}claude-logs${NC}     - View service logs"
    echo -e "  ${GREEN}claude-update${NC}   - Update Claude Code"
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  CONNECTION TIPS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "  ${YELLOW}SSH:${NC}  ssh ${CLAUDE_USER}@your-server-ip"
    echo -e "  ${YELLOW}Mosh:${NC} mosh ${CLAUDE_USER}@your-server-ip"
    echo
    echo -e "  ${PURPLE}Mosh is recommended for unstable connections!${NC}"
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    print_header "Claude Code VPS Setup Script"
    print_info "Starting setup at $(date)"
    print_info "User: ${CLAUDE_USER}"
    print_info "Home: ${CLAUDE_HOME}"
    echo

    # Run all setup steps
    check_root
    check_os
    update_system
    install_nodejs
    install_claude_code
    setup_user
    configure_tmux
    create_systemd_service
    create_helper_scripts
    setup_environment
    configure_firewall

    # Print summary
    print_summary

    print_info "Setup completed at $(date)"
}

# Run main function
main "$@"

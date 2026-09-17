#!/bin/bash
#
# Tailscale Setup Script for Claude VPS
# --------------------------------------
# This script installs and configures Tailscale on Ubuntu/Debian systems
# for secure, easy access from Matt's devices.
#
# Usage: sudo ./setup-tailscale.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
        CODENAME=$VERSION_CODENAME
        log_info "Detected OS: $PRETTY_NAME"
    else
        log_error "Cannot detect OS. /etc/os-release not found."
        exit 1
    fi

    # Validate supported OS
    case $OS in
        ubuntu|debian)
            log_success "OS $OS is supported"
            ;;
        *)
            log_error "Unsupported OS: $OS. This script supports Ubuntu and Debian only."
            exit 1
            ;;
    esac
}

# Check if Tailscale is already installed
check_existing_installation() {
    if command -v tailscale &> /dev/null; then
        log_warning "Tailscale is already installed"
        tailscale version
        read -p "Do you want to continue and reconfigure? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Exiting. Run 'sudo tailscale up --ssh' to reconfigure manually."
            exit 0
        fi
    fi
}

# Add Tailscale repository
add_tailscale_repo() {
    log_info "Adding Tailscale repository..."

    # Install prerequisites
    apt-get update
    apt-get install -y curl gnupg apt-transport-https

    # Add Tailscale's GPG key
    curl -fsSL https://pkgs.tailscale.com/stable/$OS/$CODENAME.noarmor.gpg | \
        tee /usr/share/keyrings/tailscale-archive-keyring.gpg > /dev/null

    # Add Tailscale repository
    curl -fsSL https://pkgs.tailscale.com/stable/$OS/$CODENAME.tailscale-keyring.list | \
        tee /etc/apt/sources.list.d/tailscale.list > /dev/null

    log_success "Tailscale repository added"
}

# Install Tailscale
install_tailscale() {
    log_info "Installing Tailscale..."

    apt-get update
    apt-get install -y tailscale

    log_success "Tailscale installed successfully"
    tailscale version
}

# Start and enable Tailscale service
start_tailscale_service() {
    log_info "Starting Tailscale service..."

    systemctl enable --now tailscaled

    # Wait for service to be ready
    sleep 2

    if systemctl is-active --quiet tailscaled; then
        log_success "Tailscale service is running"
    else
        log_error "Tailscale service failed to start"
        systemctl status tailscaled
        exit 1
    fi
}

# Configure Tailscale with SSH
configure_tailscale() {
    log_info "Configuring Tailscale with SSH access..."

    echo ""
    echo "=============================================="
    echo "  AUTHENTICATION REQUIRED"
    echo "=============================================="
    echo ""
    echo "A browser link will appear below. You need to:"
    echo "1. Copy the URL"
    echo "2. Open it in a browser on your Mac"
    echo "3. Log in with your Tailscale account"
    echo "4. Authorize this machine"
    echo ""
    echo "The --ssh flag enables Tailscale SSH, allowing"
    echo "passwordless SSH access from your other devices."
    echo ""
    echo "Press Enter to continue..."
    read

    # Run tailscale up with SSH enabled
    tailscale up --ssh

    # Wait for connection
    sleep 3

    # Get status
    STATUS=$(tailscale status --json 2>/dev/null | head -1)
    if [[ -n "$STATUS" ]]; then
        log_success "Tailscale is connected!"
    fi
}

# Display connection information
display_info() {
    echo ""
    echo "=============================================="
    echo "  TAILSCALE SETUP COMPLETE"
    echo "=============================================="
    echo ""

    # Get Tailscale IP
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "Not available")
    HOSTNAME=$(tailscale status --self --json 2>/dev/null | grep -o '"HostName":"[^"]*"' | cut -d'"' -f4 || hostname)
    MAGIC_DNS=$(tailscale status --self --json 2>/dev/null | grep -o '"DNSName":"[^"]*"' | cut -d'"' -f4 || echo "Not available")

    echo "Tailscale IPv4:     $TAILSCALE_IP"
    echo "Hostname:           $HOSTNAME"
    echo "MagicDNS Name:      $MAGIC_DNS"
    echo ""
    echo "=============================================="
    echo "  NEXT STEPS ON YOUR MAC"
    echo "=============================================="
    echo ""
    echo "1. Install Tailscale on Mac:"
    echo "   - Download from: https://tailscale.com/download/mac"
    echo "   - Or: brew install --cask tailscale"
    echo ""
    echo "2. Log in with the same Tailscale account"
    echo ""
    echo "3. Enable MagicDNS in Tailscale Admin Console:"
    echo "   https://login.tailscale.com/admin/dns"
    echo "   - Enable MagicDNS"
    echo "   - Optionally set a custom tailnet name"
    echo ""
    echo "4. Connect to this VPS using:"
    echo "   ssh $HOSTNAME                    # Using hostname"
    echo "   ssh $TAILSCALE_IP                # Using IP"
    echo "   ssh ${HOSTNAME%%.*}              # Using short name (if MagicDNS enabled)"
    echo ""
    echo "5. Tailscale SSH (no keys needed!):"
    echo "   Since --ssh is enabled, you can SSH without"
    echo "   managing SSH keys. Tailscale handles auth."
    echo ""
    echo "=============================================="
    echo "  USEFUL COMMANDS"
    echo "=============================================="
    echo ""
    echo "tailscale status          # Show connection status"
    echo "tailscale ping <device>   # Ping another device"
    echo "tailscale ssh <device>    # SSH to another device"
    echo "tailscale ip              # Show Tailscale IPs"
    echo "tailscale logout          # Disconnect from tailnet"
    echo ""
}

# Set hostname for MagicDNS
set_hostname() {
    CURRENT_HOSTNAME=$(hostname)

    echo ""
    log_info "Current hostname: $CURRENT_HOSTNAME"
    echo ""
    echo "For MagicDNS, you can access this VPS using its hostname."
    echo "Would you like to set a custom hostname? (e.g., 'claude-vps')"
    echo ""
    read -p "Enter new hostname (or press Enter to keep '$CURRENT_HOSTNAME'): " NEW_HOSTNAME

    if [[ -n "$NEW_HOSTNAME" ]]; then
        hostnamectl set-hostname "$NEW_HOSTNAME"
        log_success "Hostname changed to: $NEW_HOSTNAME"
        log_info "You may need to restart Tailscale for the change to take effect:"
        echo "  sudo systemctl restart tailscaled"
        echo "  sudo tailscale up --ssh"
    fi
}

# Main execution
main() {
    echo ""
    echo "=============================================="
    echo "  TAILSCALE SETUP FOR CLAUDE VPS"
    echo "=============================================="
    echo ""
    echo "This script will:"
    echo "  1. Detect your OS (Ubuntu/Debian)"
    echo "  2. Add the Tailscale repository"
    echo "  3. Install Tailscale"
    echo "  4. Configure Tailscale SSH"
    echo "  5. Set up MagicDNS hostname"
    echo ""

    check_root
    detect_os
    check_existing_installation
    add_tailscale_repo
    install_tailscale
    start_tailscale_service
    set_hostname
    configure_tailscale
    display_info

    log_success "Setup complete! Enjoy secure access to your VPS."
}

# Run main function
main "$@"

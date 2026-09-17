#!/bin/bash
#
# sync-credentials.sh
# One-liner sync from Mac to VPS via scp
# Combines export, transfer, and provides import command
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration - customize these
VPS_USER="${VPS_USER:-root}"
VPS_HOST="${VPS_HOST:-}"
VPS_PORT="${VPS_PORT:-22}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_usage() {
    echo "Usage: $0 [user@]hostname[:port] [options]"
    echo ""
    echo "Syncs Claude Code credentials from this Mac to a VPS."
    echo ""
    echo "Arguments:"
    echo "  hostname       VPS hostname or IP address (required)"
    echo "  user           SSH username (default: root)"
    echo "  port           SSH port (default: 22)"
    echo ""
    echo "Options:"
    echo "  --dry-run      Show what would be done without executing"
    echo "  --no-import    Only transfer, don't run import on VPS"
    echo "  --help         Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 my-vps.example.com"
    echo "  $0 matt@192.168.1.100"
    echo "  $0 matt@my-vps.example.com:2222"
    echo ""
    echo "Environment variables:"
    echo "  VPS_USER       Default SSH user"
    echo "  VPS_HOST       Default VPS hostname"
    echo "  VPS_PORT       Default SSH port"
    echo ""
}

# Parse arguments
DRY_RUN=false
NO_IMPORT=false
TARGET=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-import)
            NO_IMPORT=true
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            TARGET="$1"
            shift
            ;;
    esac
done

# Parse target
if [[ -n "$TARGET" ]]; then
    # Extract user if specified (user@host)
    if [[ "$TARGET" == *"@"* ]]; then
        VPS_USER="${TARGET%%@*}"
        TARGET="${TARGET#*@}"
    fi

    # Extract port if specified (host:port)
    if [[ "$TARGET" == *":"* ]]; then
        VPS_HOST="${TARGET%%:*}"
        VPS_PORT="${TARGET#*:}"
    else
        VPS_HOST="$TARGET"
    fi
fi

# Validate
if [[ -z "$VPS_HOST" ]]; then
    echo -e "${RED}Error: VPS hostname is required${NC}"
    echo ""
    show_usage
    exit 1
fi

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Claude Code Credentials Sync${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo "Target: ${VPS_USER}@${VPS_HOST}:${VPS_PORT}"
echo ""

if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}[DRY RUN MODE - no changes will be made]${NC}"
    echo ""
fi

# Step 1: Create export
echo -e "${YELLOW}Step 1: Creating encrypted credentials package...${NC}"
echo ""

TEMP_DIR="/tmp/claude-sync-$$"
mkdir -p "$TEMP_DIR"
trap "rm -rf $TEMP_DIR" EXIT

if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY RUN] Would run: $SCRIPT_DIR/export-credentials.sh $TEMP_DIR"
else
    # Run export script
    "$SCRIPT_DIR/export-credentials.sh" "$TEMP_DIR"
fi

# Find the created archive
ARCHIVE_FILE=$(ls -t "$TEMP_DIR"/claude-credentials-*.tar.gz.enc 2>/dev/null | head -1)

if [[ -z "$ARCHIVE_FILE" ]] && [[ "$DRY_RUN" == false ]]; then
    echo -e "${RED}Error: Export failed - no archive created${NC}"
    exit 1
fi

ARCHIVE_NAME=$(basename "$ARCHIVE_FILE" 2>/dev/null || echo "claude-credentials-TIMESTAMP.tar.gz.enc")

# Step 2: Transfer import script and archive
echo ""
echo -e "${YELLOW}Step 2: Transferring to VPS...${NC}"
echo ""

SSH_OPTS="-p $VPS_PORT"
SCP_OPTS="-P $VPS_PORT"

if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY RUN] Would run:"
    echo "  scp $SCP_OPTS $SCRIPT_DIR/import-credentials.sh ${VPS_USER}@${VPS_HOST}:/tmp/"
    echo "  scp $SCP_OPTS $ARCHIVE_FILE ${VPS_USER}@${VPS_HOST}:/tmp/"
else
    # Transfer import script
    echo "Transferring import script..."
    scp $SCP_OPTS "$SCRIPT_DIR/import-credentials.sh" "${VPS_USER}@${VPS_HOST}:/tmp/"

    # Transfer archive
    echo "Transferring credentials archive..."
    scp $SCP_OPTS "$ARCHIVE_FILE" "${VPS_USER}@${VPS_HOST}:/tmp/"

    echo -e "  ${GREEN}✓${NC} Files transferred successfully"
fi

# Step 3: Run import on VPS (optional)
if [[ "$NO_IMPORT" == true ]]; then
    echo ""
    echo -e "${YELLOW}Skipping remote import (--no-import specified)${NC}"
    echo ""
    echo "To complete setup, SSH to the VPS and run:"
    echo "  chmod +x /tmp/import-credentials.sh"
    echo "  /tmp/import-credentials.sh /tmp/$ARCHIVE_NAME"
else
    echo ""
    echo -e "${YELLOW}Step 3: Running import on VPS...${NC}"
    echo ""

    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY RUN] Would run:"
        echo "  ssh $SSH_OPTS ${VPS_USER}@${VPS_HOST} 'chmod +x /tmp/import-credentials.sh && /tmp/import-credentials.sh /tmp/$ARCHIVE_NAME'"
    else
        echo -e "${BLUE}Connecting to VPS to run import...${NC}"
        echo -e "${BLUE}You'll need to enter the encryption password you set earlier.${NC}"
        echo ""

        # Execute import remotely
        ssh -t $SSH_OPTS "${VPS_USER}@${VPS_HOST}" \
            "chmod +x /tmp/import-credentials.sh && /tmp/import-credentials.sh /tmp/$ARCHIVE_NAME && rm /tmp/import-credentials.sh /tmp/$ARCHIVE_NAME"
    fi
fi

# Step 4: Cleanup
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Sync Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY RUN] No changes were made"
else
    echo -e "${GREEN}Credentials have been synced to ${VPS_USER}@${VPS_HOST}${NC}"
    echo ""
    echo -e "${YELLOW}Don't forget to:${NC}"
    echo "1. SSH to VPS and set your API tokens in ~/.claude.json"
    echo "2. Install required npm packages for MCP servers"
    echo "3. Test with: claude --version"
fi
echo ""

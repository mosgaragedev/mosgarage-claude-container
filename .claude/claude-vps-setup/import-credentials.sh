#!/bin/bash
#
# import-credentials.sh
# Imports Claude Code credentials from encrypted tarball
# Run this on the VPS after transferring the archive
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMPORT_DIR="/tmp/claude-import-$$"
ARCHIVE_PATH="$1"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Claude Code Credentials Import Script${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Check arguments
if [[ -z "$ARCHIVE_PATH" ]]; then
    echo -e "${RED}Error: Please provide the path to the encrypted archive${NC}"
    echo ""
    echo "Usage: $0 /path/to/claude-credentials-YYYYMMDD_HHMMSS.tar.gz.enc"
    exit 1
fi

if [[ ! -f "$ARCHIVE_PATH" ]]; then
    echo -e "${RED}Error: Archive not found: $ARCHIVE_PATH${NC}"
    exit 1
fi

# Check for existing installation
echo -e "${YELLOW}Step 1: Checking existing Claude Code setup...${NC}"
echo ""

BACKUP_NEEDED=false
if [[ -f "$HOME/.claude.json" ]] || [[ -d "$HOME/.claude" ]]; then
    BACKUP_NEEDED=true
    BACKUP_DIR="$HOME/.claude-backup-$(date +%Y%m%d_%H%M%S)"
    echo -e "  ${YELLOW}⚠${NC} Existing Claude Code configuration found"
    echo -e "  ${YELLOW}⚠${NC} Will backup to: $BACKUP_DIR"
fi

# Create temporary import directory
mkdir -p "$IMPORT_DIR"
trap "rm -rf $IMPORT_DIR" EXIT

# Decrypt and extract
echo ""
echo -e "${YELLOW}Step 2: Decrypting archive...${NC}"
echo ""
echo -e "${BLUE}Enter the encryption password:${NC}"

# Decrypt
openssl enc -aes-256-cbc -d -salt -pbkdf2 -iter 100000 \
    -in "$ARCHIVE_PATH" \
    -out "$IMPORT_DIR/credentials.tar.gz"

# Extract
echo ""
echo -e "${YELLOW}Step 3: Extracting files...${NC}"
echo ""

cd "$IMPORT_DIR"
tar -xzf credentials.tar.gz

# Show manifest if exists
if [[ -f "$IMPORT_DIR/MANIFEST.txt" ]]; then
    echo -e "${BLUE}--- Manifest ---${NC}"
    cat "$IMPORT_DIR/MANIFEST.txt"
    echo -e "${BLUE}----------------${NC}"
    echo ""
fi

# Backup existing config if needed
if [[ "$BACKUP_NEEDED" == true ]]; then
    echo -e "${YELLOW}Step 4: Backing up existing configuration...${NC}"
    echo ""
    mkdir -p "$BACKUP_DIR"
    [[ -f "$HOME/.claude.json" ]] && cp "$HOME/.claude.json" "$BACKUP_DIR/"
    [[ -d "$HOME/.claude" ]] && cp -r "$HOME/.claude" "$BACKUP_DIR/"
    echo -e "  ${GREEN}✓${NC} Backup created at $BACKUP_DIR"
    echo ""
fi

# Install files
echo -e "${YELLOW}Step 5: Installing credentials...${NC}"
echo ""

# Create .claude directory if it doesn't exist
mkdir -p "$HOME/.claude"

# Copy main config
if [[ -f "$IMPORT_DIR/.claude.json" ]]; then
    cp "$IMPORT_DIR/.claude.json" "$HOME/.claude.json"
    chmod 600 "$HOME/.claude.json"
    echo -e "  ${GREEN}✓${NC} .claude.json installed"
fi

# Copy .claude directory contents
for file in settings.json CLAUDE.md statsig.json projects.json; do
    if [[ -f "$IMPORT_DIR/.claude/$file" ]]; then
        cp "$IMPORT_DIR/.claude/$file" "$HOME/.claude/$file"
        chmod 600 "$HOME/.claude/$file"
        echo -e "  ${GREEN}✓${NC} .claude/$file installed"
    fi
done

# Copy skills if present
if [[ -d "$IMPORT_DIR/.claude/skills" ]]; then
    mkdir -p "$HOME/.claude/skills"
    cp -r "$IMPORT_DIR/.claude/skills/"* "$HOME/.claude/skills/" 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} .claude/skills/ installed"
fi

# Set proper permissions
echo ""
echo -e "${YELLOW}Step 6: Setting permissions...${NC}"
echo ""

chmod 700 "$HOME/.claude"
find "$HOME/.claude" -type f -exec chmod 600 {} \;
echo -e "  ${GREEN}✓${NC} Permissions set (700 for directory, 600 for files)"

# Validate setup
echo ""
echo -e "${YELLOW}Step 7: Validating installation...${NC}"
echo ""

VALIDATION_PASSED=true

# Check main config exists and is valid JSON
if [[ -f "$HOME/.claude.json" ]]; then
    if command -v jq &> /dev/null; then
        if jq empty "$HOME/.claude.json" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} .claude.json is valid JSON"
        else
            echo -e "  ${RED}✗${NC} .claude.json is not valid JSON"
            VALIDATION_PASSED=false
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} jq not installed - skipping JSON validation"
    fi
else
    echo -e "  ${RED}✗${NC} .claude.json not found after import"
    VALIDATION_PASSED=false
fi

# Check for placeholder tokens that need to be set
if grep -q "SET_ON_VPS" "$HOME/.claude.json" 2>/dev/null; then
    echo ""
    echo -e "  ${YELLOW}⚠${NC} Tokens need to be configured!"
    echo -e "    Edit ~/.claude.json and replace 'SET_ON_VPS' with actual values:"
    grep -o '"[^"]*"[[:space:]]*:[[:space:]]*"SET_ON_VPS"' "$HOME/.claude.json" | \
        sed 's/"SET_ON_VPS"/[NEEDS_VALUE]/' | \
        while read line; do echo "      $line"; done
fi

# Check Claude Code installation
echo ""
if command -v claude &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} Claude Code CLI is installed"
    echo -e "    Version: $(claude --version 2>/dev/null || echo 'unknown')"
else
    echo -e "  ${YELLOW}⚠${NC} Claude Code CLI not found"
    echo -e "    Install with: npm install -g @anthropic-ai/claude-code"
fi

# Summary
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Import Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

if [[ "$VALIDATION_PASSED" == true ]]; then
    echo -e "${GREEN}Credentials successfully imported.${NC}"
else
    echo -e "${YELLOW}Import completed with warnings - see above.${NC}"
fi

echo ""
echo -e "${YELLOW}Required manual steps:${NC}"
echo ""
echo "1. Set your API tokens in ~/.claude.json:"
echo "   - ANTHROPIC_API_KEY"
echo "   - SLACK_MCP_XOXP_TOKEN (if using Slack)"
echo "   - GITHUB_TOKEN (if using GitHub)"
echo ""
echo "2. Install required MCP server packages:"
echo "   npm install -g @modelcontextprotocol/server-github"
echo "   npm install -g @supabase/mcp-server-supabase"
echo "   npm install -g slack-mcp-server"
echo ""
echo "3. Test the setup:"
echo "   claude --version"
echo ""
echo "4. Clean up the archive:"
echo "   rm $ARCHIVE_PATH"
echo ""

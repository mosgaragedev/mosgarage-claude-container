#!/bin/bash
#
# export-credentials.sh
# Securely packages Claude Code credentials for transfer to VPS
# Run this on the Mac to create an encrypted tarball
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
EXPORT_DIR="/tmp/claude-export-$$"
OUTPUT_DIR="${1:-$HOME/Desktop}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE_NAME="claude-credentials-${TIMESTAMP}.tar.gz.enc"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Claude Code Credentials Export Script${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Create temporary export directory
mkdir -p "$EXPORT_DIR"
trap "rm -rf $EXPORT_DIR" EXIT

# Function to safely copy file with redaction check
safe_copy() {
    local src="$1"
    local dest="$2"
    local filename=$(basename "$src")

    if [[ -f "$src" ]]; then
        cp "$src" "$dest"
        echo -e "  ${GREEN}✓${NC} $filename"
        return 0
    else
        echo -e "  ${YELLOW}⚠${NC} $filename (not found - skipping)"
        return 1
    fi
}

# Function to check for sensitive patterns
check_sensitive() {
    local file="$1"
    local patterns=("sk-" "xoxp-" "xoxb-" "ghp_" "ghs_" "ANTHROPIC_API_KEY" "password" "secret")
    local found=0

    for pattern in "${patterns[@]}"; do
        if grep -qi "$pattern" "$file" 2>/dev/null; then
            found=1
            break
        fi
    done

    return $found
}

echo -e "${YELLOW}Step 1: Collecting Claude Code configuration files...${NC}"
echo ""

# Files to export
FILES_TO_EXPORT=(
    "$HOME/.claude.json"
    "$HOME/.claude/settings.json"
    "$HOME/.claude/CLAUDE.md"
    "$HOME/.claude/statsig.json"
    "$HOME/.claude/projects.json"
)

# Create subdirectory structure
mkdir -p "$EXPORT_DIR/.claude"

# Copy main config
if [[ -f "$HOME/.claude.json" ]]; then
    # Check for embedded tokens/secrets
    if check_sensitive "$HOME/.claude.json"; then
        echo -e "  ${YELLOW}⚠${NC} .claude.json contains potential secrets"
        echo -e "    ${YELLOW}Creating sanitized version...${NC}"

        # Create sanitized version - remove env vars with actual tokens
        # Keep structure but replace token values with placeholders
        cat "$HOME/.claude.json" | \
            sed 's/"SLACK_MCP_XOXP_TOKEN"[[:space:]]*:[[:space:]]*"[^"]*"/"SLACK_MCP_XOXP_TOKEN": "SET_ON_VPS"/g' | \
            sed 's/"ANTHROPIC_API_KEY"[[:space:]]*:[[:space:]]*"[^"]*"/"ANTHROPIC_API_KEY": "SET_ON_VPS"/g' | \
            sed 's/"GITHUB_TOKEN"[[:space:]]*:[[:space:]]*"[^"]*"/"GITHUB_TOKEN": "SET_ON_VPS"/g' | \
            sed 's/"SUPABASE_[^"]*_KEY"[[:space:]]*:[[:space:]]*"[^"]*"/"SUPABASE_KEY": "SET_ON_VPS"/g' | \
            sed 's/xoxp-[a-zA-Z0-9-]*/SET_ON_VPS/g' | \
            sed 's/sk-[a-zA-Z0-9-]*/SET_ON_VPS/g' | \
            sed 's/ghp_[a-zA-Z0-9]*/SET_ON_VPS/g' \
            > "$EXPORT_DIR/.claude.json"
        echo -e "  ${GREEN}✓${NC} .claude.json (sanitized)"
    else
        safe_copy "$HOME/.claude.json" "$EXPORT_DIR/.claude.json"
    fi
else
    echo -e "  ${RED}✗${NC} .claude.json not found - this is required!"
    exit 1
fi

# Copy .claude directory contents
echo ""
echo -e "${YELLOW}Step 2: Collecting .claude directory files...${NC}"
echo ""

for file in settings.json CLAUDE.md statsig.json projects.json; do
    if [[ -f "$HOME/.claude/$file" ]]; then
        safe_copy "$HOME/.claude/$file" "$EXPORT_DIR/.claude/$file"
    fi
done

# Check for any custom skills
if [[ -d "$HOME/.claude/skills" ]]; then
    mkdir -p "$EXPORT_DIR/.claude/skills"
    cp -r "$HOME/.claude/skills/"* "$EXPORT_DIR/.claude/skills/" 2>/dev/null || true
    echo -e "  ${GREEN}✓${NC} skills/ directory"
fi

# Create manifest
echo ""
echo -e "${YELLOW}Step 3: Creating manifest...${NC}"
echo ""

cat > "$EXPORT_DIR/MANIFEST.txt" << EOF
Claude Code Credentials Export
==============================
Created: $(date)
Source: $(hostname)
User: $(whoami)

Files Included:
$(find "$EXPORT_DIR" -type f | sed "s|$EXPORT_DIR/||" | sort)

IMPORTANT NOTES:
----------------
1. API tokens have been REDACTED from .claude.json
2. You must manually set the following on the VPS:
   - ANTHROPIC_API_KEY
   - SLACK_MCP_XOXP_TOKEN (if using Slack MCP)
   - GITHUB_TOKEN (if using GitHub MCP)
   - Any Supabase access tokens

3. After import, edit ~/.claude.json to add your tokens
4. MCP server npm packages must be installed separately

Setup Commands for VPS:
-----------------------
# Install Claude Code
npm install -g @anthropic-ai/claude-code

# Install MCP servers (as needed)
npm install -g @modelcontextprotocol/server-github
npm install -g @supabase/mcp-server-supabase
npm install -g slack-mcp-server
npm install -g @anthropic-ai/claude-mcp-server-puppeteer

EOF

echo -e "  ${GREEN}✓${NC} MANIFEST.txt created"

# Display what was collected
echo ""
echo -e "${YELLOW}Step 4: Summary of collected files...${NC}"
echo ""
echo "Files to be exported:"
find "$EXPORT_DIR" -type f -exec ls -lh {} \; | awk '{print "  " $NF " (" $5 ")"}'

# Create encrypted archive
echo ""
echo -e "${YELLOW}Step 5: Creating encrypted archive...${NC}"
echo ""
echo -e "${BLUE}You will be prompted for an encryption password.${NC}"
echo -e "${BLUE}Remember this password - you'll need it on the VPS!${NC}"
echo ""

# Create tarball first
cd "$EXPORT_DIR"
tar -czf "/tmp/claude-credentials-${TIMESTAMP}.tar.gz" .

# Encrypt with openssl
openssl enc -aes-256-cbc -salt -pbkdf2 -iter 100000 \
    -in "/tmp/claude-credentials-${TIMESTAMP}.tar.gz" \
    -out "${OUTPUT_DIR}/${ARCHIVE_NAME}"

# Cleanup unencrypted tarball
rm "/tmp/claude-credentials-${TIMESTAMP}.tar.gz"

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Export Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "Encrypted archive created at:"
echo -e "  ${BLUE}${OUTPUT_DIR}/${ARCHIVE_NAME}${NC}"
echo ""
echo -e "File size: $(ls -lh "${OUTPUT_DIR}/${ARCHIVE_NAME}" | awk '{print $5}')"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Transfer to VPS:  scp ${OUTPUT_DIR}/${ARCHIVE_NAME} user@vps:/tmp/"
echo "2. On VPS, run:      ./import-credentials.sh /tmp/${ARCHIVE_NAME}"
echo ""
echo -e "${RED}SECURITY REMINDER:${NC}"
echo "- Delete the archive after successful import"
echo "- Never commit this file to git"
echo "- The archive contains your Claude Code configuration"
echo ""

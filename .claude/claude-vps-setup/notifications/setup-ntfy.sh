#!/bin/bash
#
# setup-ntfy.sh - ntfy.sh Push Notification Setup for Claude Code
#
# This script sets up push notifications so you get alerts on your phone
# when Claude needs input or completes a task.
#
# Usage: ./setup-ntfy.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration paths
CONFIG_DIR="${HOME}/.config/claude-notify"
TOPIC_FILE="${CONFIG_DIR}/topic"
HOOK_SCRIPT="${CONFIG_DIR}/notify-hook.sh"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Claude Code Push Notifications Setup  ${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Create config directory
mkdir -p "${CONFIG_DIR}"

# Generate unique topic name if not exists
if [[ -f "${TOPIC_FILE}" ]]; then
    TOPIC=$(cat "${TOPIC_FILE}")
    echo -e "${YELLOW}Existing topic found: ${TOPIC}${NC}"
    echo ""
    read -p "Use existing topic? (Y/n): " USE_EXISTING
    if [[ "${USE_EXISTING}" =~ ^[Nn] ]]; then
        TOPIC=""
    fi
fi

if [[ -z "${TOPIC}" ]]; then
    # Generate a unique, hard-to-guess topic name
    RANDOM_SUFFIX=$(openssl rand -hex 4)
    TOPIC="claude-matt-${RANDOM_SUFFIX}"
    echo "${TOPIC}" > "${TOPIC_FILE}"
    chmod 600 "${TOPIC_FILE}"
    echo -e "${GREEN}Generated new topic: ${TOPIC}${NC}"
fi

NTFY_URL="https://ntfy.sh/${TOPIC}"

echo ""
echo -e "${BLUE}Testing notification...${NC}"
echo ""

# Send test notification with all the bells and whistles
TEST_RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Title: Claude Code Ready!" \
    -H "Priority: high" \
    -H "Tags: robot,white_check_mark" \
    -H "Click: ssh://matt@your-vps-ip" \
    -d "Push notifications are configured! You'll be notified when Claude needs your input or completes tasks." \
    "${NTFY_URL}" 2>/dev/null)

if [[ "${TEST_RESULT}" == "200" ]]; then
    echo -e "${GREEN}Test notification sent successfully!${NC}"
else
    echo -e "${RED}Failed to send notification (HTTP ${TEST_RESULT})${NC}"
    echo -e "${YELLOW}Check your internet connection and try again.${NC}"
    exit 1
fi

# Copy hook script to config location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/notify-hook.sh" ]]; then
    cp "${SCRIPT_DIR}/notify-hook.sh" "${HOOK_SCRIPT}"
    chmod +x "${HOOK_SCRIPT}"
    echo -e "${GREEN}Hook script installed to: ${HOOK_SCRIPT}${NC}"
fi

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Setup Complete!                       ${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "${GREEN}Your private ntfy topic:${NC}"
echo -e "  ${YELLOW}${TOPIC}${NC}"
echo ""
echo -e "${GREEN}Subscribe URL:${NC}"
echo -e "  ${YELLOW}${NTFY_URL}${NC}"
echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo ""
echo -e "1. ${BLUE}Install ntfy app on your phone:${NC}"
echo "   iOS:     https://apps.apple.com/app/ntfy/id1625396347"
echo "   Android: https://play.google.com/store/apps/details?id=io.heckel.ntfy"
echo ""
echo -e "2. ${BLUE}Subscribe to your topic:${NC}"
echo "   Open the app → tap '+' → enter: ${YELLOW}${TOPIC}${NC}"
echo ""
echo -e "3. ${BLUE}Add to Claude Code hooks config:${NC}"
echo "   Add the following to ~/.claude/settings.json under 'hooks':"
echo ""
cat << 'EOF'
   "hooks": {
     "Notification": [
       {
         "matcher": {},
         "hooks": [
           {
             "type": "command",
             "command": "~/.config/claude-notify/notify-hook.sh notification \"$CLAUDE_NOTIFICATION_MESSAGE\""
           }
         ]
       }
     ],
     "Stop": [
       {
         "matcher": {},
         "hooks": [
           {
             "type": "command",
             "command": "~/.config/claude-notify/notify-hook.sh stop \"$CLAUDE_STOP_REASON\""
           }
         ]
       }
     ]
   }
EOF
echo ""
echo -e "${GREEN}Configuration saved to: ${CONFIG_DIR}${NC}"
echo ""

# Show QR code if qrencode is available
if command -v qrencode &> /dev/null; then
    echo -e "${BLUE}Scan this QR code to subscribe:${NC}"
    echo ""
    qrencode -t ANSIUTF8 "ntfy://${TOPIC}"
    echo ""
elif command -v brew &> /dev/null; then
    echo -e "${YELLOW}Tip: Install qrencode for QR codes: brew install qrencode${NC}"
    echo ""
fi

echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}You're all set! Test by running:${NC}"
echo -e "  ${YELLOW}~/.config/claude-notify/notify-hook.sh test 'Hello from Claude!'${NC}"
echo -e "${CYAN}========================================${NC}"

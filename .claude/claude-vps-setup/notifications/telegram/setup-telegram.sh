#!/bin/bash
#
# Telegram Bot Setup for Claude Code Notifications
# Creates and tests Telegram bot configuration
#
# Usage: ./setup-telegram.sh
#

set -e

CONFIG_FILE="$HOME/.claude-telegram"
SCRIPTS_DIR="$HOME/.claude/scripts"

echo "========================================"
echo "  Telegram Bot Setup for Claude Code"
echo "========================================"
echo ""

# Check if config already exists
if [ -f "$CONFIG_FILE" ]; then
    echo "Existing configuration found at $CONFIG_FILE"
    source "$CONFIG_FILE"
    echo "  Bot Token: ${TELEGRAM_BOT_TOKEN:0:10}...${TELEGRAM_BOT_TOKEN: -5}"
    echo "  Chat ID: $TELEGRAM_CHAT_ID"
    echo ""
    read -p "Do you want to reconfigure? (y/N): " RECONFIG
    if [[ ! "$RECONFIG" =~ ^[Yy]$ ]]; then
        echo "Keeping existing configuration."
        exit 0
    fi
    echo ""
fi

# Step 1: Get Bot Token
echo "STEP 1: Bot Token"
echo "-----------------"
echo "To get a bot token:"
echo "  1. Open Telegram and search for @BotFather"
echo "  2. Send /newbot and follow the prompts"
echo "  3. Copy the API token provided"
echo ""
read -p "Enter your Telegram Bot Token: " BOT_TOKEN

if [ -z "$BOT_TOKEN" ]; then
    echo "Error: Bot token cannot be empty"
    exit 1
fi

# Validate token format (should contain a colon)
if [[ ! "$BOT_TOKEN" == *":"* ]]; then
    echo "Warning: Token doesn't appear to be in the expected format (should contain ':')"
    read -p "Continue anyway? (y/N): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""

# Step 2: Get Chat ID
echo "STEP 2: Chat ID"
echo "---------------"
echo "To get your chat ID:"
echo "  1. Start a chat with your bot in Telegram"
echo "  2. Send any message to the bot"
echo "  3. We'll fetch the chat ID automatically"
echo ""
read -p "Have you sent a message to your bot? (Y/n): " SENT_MSG

if [[ "$SENT_MSG" =~ ^[Nn]$ ]]; then
    echo ""
    echo "Please send a message to your bot first, then run this script again."
    exit 1
fi

echo ""
echo "Fetching chat ID from Telegram API..."

# Fetch updates to get chat ID
RESPONSE=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates")

# Check if request was successful
if echo "$RESPONSE" | grep -q '"ok":false'; then
    echo "Error: Invalid bot token or API error"
    echo "Response: $RESPONSE"
    exit 1
fi

# Try to extract chat ID using different methods
if command -v jq &> /dev/null; then
    CHAT_ID=$(echo "$RESPONSE" | jq -r '.result[0].message.chat.id // empty')
else
    # Fallback: use grep/sed if jq not available
    CHAT_ID=$(echo "$RESPONSE" | grep -o '"chat":{"id":[0-9-]*' | head -1 | grep -o '[0-9-]*$')
fi

if [ -z "$CHAT_ID" ]; then
    echo "Could not automatically detect chat ID."
    echo ""
    echo "Alternative methods to get your chat ID:"
    echo "  1. Forward a message to @userinfobot"
    echo "  2. Use @RawDataBot"
    echo "  3. Check the API response manually:"
    echo "     curl 'https://api.telegram.org/bot${BOT_TOKEN}/getUpdates'"
    echo ""
    read -p "Enter your Chat ID manually: " CHAT_ID
fi

if [ -z "$CHAT_ID" ]; then
    echo "Error: Chat ID cannot be empty"
    exit 1
fi

echo "Chat ID detected: $CHAT_ID"
echo ""

# Step 3: Test the connection
echo "STEP 3: Testing Connection"
echo "--------------------------"
echo "Sending test message..."

TEST_RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}" \
    -d "text=🎉 Claude Code notifications configured successfully!" \
    -d "parse_mode=Markdown")

if echo "$TEST_RESPONSE" | grep -q '"ok":true'; then
    echo "✓ Test message sent successfully!"
else
    echo "✗ Failed to send test message"
    echo "Response: $TEST_RESPONSE"
    exit 1
fi

echo ""

# Step 4: Save configuration
echo "STEP 4: Saving Configuration"
echo "----------------------------"

cat > "$CONFIG_FILE" << EOF
# Telegram Bot Configuration for Claude Code
# Generated on $(date)

TELEGRAM_BOT_TOKEN="${BOT_TOKEN}"
TELEGRAM_CHAT_ID="${CHAT_ID}"
EOF

chmod 600 "$CONFIG_FILE"
echo "✓ Configuration saved to $CONFIG_FILE"

# Step 5: Install hook script
echo ""
echo "STEP 5: Installing Hook Script"
echo "------------------------------"

mkdir -p "$SCRIPTS_DIR"

# Copy the hook script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/telegram-hook.sh" ]; then
    cp "$SCRIPT_DIR/telegram-hook.sh" "$SCRIPTS_DIR/telegram-notify.sh"
    chmod +x "$SCRIPTS_DIR/telegram-notify.sh"
    echo "✓ Hook script installed to $SCRIPTS_DIR/telegram-notify.sh"
else
    echo "⚠ telegram-hook.sh not found in current directory"
    echo "  Please manually copy it to $SCRIPTS_DIR/telegram-notify.sh"
fi

echo ""
echo "========================================"
echo "  Setup Complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Add the following to your ~/.claude/settings.json:"
echo ""
echo '   {
     "hooks": {
       "Stop": [
         {
           "matcher": "",
           "hooks": [
             {
               "type": "command",
               "command": "bash ~/.claude/scripts/telegram-notify.sh stop"
             }
           ]
         }
       ],
       "Notification": [
         {
           "matcher": "",
           "hooks": [
             {
               "type": "command",
               "command": "bash ~/.claude/scripts/telegram-notify.sh notification"
             }
           ]
         }
       ]
     }
   }'
echo ""
echo "2. Test with: echo '{}' | bash ~/.claude/scripts/telegram-notify.sh test"
echo ""
echo "Done!"

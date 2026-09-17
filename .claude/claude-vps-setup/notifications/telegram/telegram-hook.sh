#!/bin/bash
#
# Telegram Notification Hook for Claude Code
# Sends formatted messages to Telegram when Claude Code events occur
#
# Usage:
#   echo '{"session_id":"..."}' | ./telegram-hook.sh [stop|notification|test]
#
# Configuration:
#   Reads from ~/.claude-telegram which should contain:
#   TELEGRAM_BOT_TOKEN="your-bot-token"
#   TELEGRAM_CHAT_ID="your-chat-id"
#

CONFIG_FILE="$HOME/.claude-telegram"
HOOK_TYPE="${1:-stop}"

# Load configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found at $CONFIG_FILE" >&2
    echo "Run setup-telegram.sh to configure." >&2
    exit 1
fi

source "$CONFIG_FILE"

if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "Error: TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID not set" >&2
    exit 1
fi

# Read input from stdin (Claude Code passes JSON)
INPUT=$(cat)

# Extract information from hook input
SESSION_ID=""
TRANSCRIPT_PATH=""
CWD=""
NOTIFICATION_TYPE=""
MESSAGE=""

if command -v jq &> /dev/null; then
    SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
    TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
    CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
    NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type // empty' 2>/dev/null)
    MESSAGE=$(echo "$INPUT" | jq -r '.message // empty' 2>/dev/null)
fi

# Get project name from current directory
PROJECT_NAME="${CWD##*/}"
if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME="$(basename "$(pwd)")"
fi

# Get hostname for VPS identification
HOSTNAME=$(hostname -s 2>/dev/null || echo "unknown")

# Try to extract last message from transcript for context
LAST_MESSAGE=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ] && command -v jq &> /dev/null; then
    LAST_MESSAGE=$(tail -20 "$TRANSCRIPT_PATH" 2>/dev/null | \
        jq -r 'select(.message.role == "assistant") | .message.content[0].text // empty' 2>/dev/null | \
        tail -1 | tr '\n' ' ' | cut -c1-100)
fi

# Function to send Telegram message
send_telegram() {
    local text="$1"
    local parse_mode="${2:-MarkdownV2}"
    local reply_markup="$3"

    # Build the request
    local data="chat_id=${TELEGRAM_CHAT_ID}&text=${text}&parse_mode=${parse_mode}"

    if [ -n "$reply_markup" ]; then
        data="${data}&reply_markup=${reply_markup}"
    fi

    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "$data" > /dev/null 2>&1
}

# Function to escape text for MarkdownV2
escape_markdown() {
    local text="$1"
    # Escape special characters for MarkdownV2
    echo "$text" | sed -e 's/\\/\\\\/g' \
                       -e 's/\[/\\[/g' \
                       -e 's/\]/\\]/g' \
                       -e 's/(/\\(/g' \
                       -e 's/)/\\)/g' \
                       -e 's/~/\\~/g' \
                       -e 's/>/\\>/g' \
                       -e 's/#/\\#/g' \
                       -e 's/+/\\+/g' \
                       -e 's/-/\\-/g' \
                       -e 's/=/\\=/g' \
                       -e 's/|/\\|/g' \
                       -e 's/{/\\{/g' \
                       -e 's/}/\\}/g' \
                       -e 's/\./\\./g' \
                       -e 's/!/\\!/g' \
                       -e 's/_/\\_/g' \
                       -e 's/`/\\`/g'
}

# Function to send with HTML (simpler escaping)
send_telegram_html() {
    local text="$1"
    local reply_markup="$2"

    local data="chat_id=${TELEGRAM_CHAT_ID}&parse_mode=HTML"

    # URL encode the text
    local encoded_text=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$text'''))" 2>/dev/null || echo "$text")
    data="${data}&text=${encoded_text}"

    if [ -n "$reply_markup" ]; then
        data="${data}&reply_markup=${reply_markup}"
    fi

    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "$data" > /dev/null 2>&1
}

# Build and send message based on hook type
case "$HOOK_TYPE" in
    stop)
        # Claude finished processing
        TITLE="Task Completed"
        EMOJI="✅"

        # Build HTML message
        MSG="<b>${EMOJI} Claude Code ${TITLE}</b>

<b>Host:</b> <code>${HOSTNAME}</code>
<b>Project:</b> <code>${PROJECT_NAME}</code>"

        if [ -n "$SESSION_ID" ]; then
            SHORT_SESSION="${SESSION_ID:0:8}"
            MSG="${MSG}
<b>Session:</b> <code>${SHORT_SESSION}...</code>"
        fi

        if [ -n "$LAST_MESSAGE" ]; then
            # Escape HTML entities
            ESCAPED_MSG=$(echo "$LAST_MESSAGE" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
            MSG="${MSG}

<b>Summary:</b>
<i>${ESCAPED_MSG}</i>"
        fi

        MSG="${MSG}

<i>$(date '+%Y-%m-%d %H:%M:%S')</i>"

        send_telegram_html "$MSG"
        ;;

    notification)
        # Claude needs attention (permission request or idle)
        TITLE="Needs Attention"
        EMOJI="🔔"

        if [ "$NOTIFICATION_TYPE" = "permission" ]; then
            EMOJI="🔐"
            TITLE="Permission Required"
        elif [ "$NOTIFICATION_TYPE" = "idle" ]; then
            EMOJI="⏰"
            TITLE="Input Required"
        fi

        MSG="<b>${EMOJI} Claude Code ${TITLE}</b>

<b>Host:</b> <code>${HOSTNAME}</code>
<b>Project:</b> <code>${PROJECT_NAME}</code>"

        if [ -n "$MESSAGE" ]; then
            ESCAPED_MSG=$(echo "$MESSAGE" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
            MSG="${MSG}

<b>Message:</b>
<code>${ESCAPED_MSG}</code>"
        fi

        MSG="${MSG}

<i>$(date '+%Y-%m-%d %H:%M:%S')</i>"

        send_telegram_html "$MSG"
        ;;

    test)
        # Test message
        MSG="<b>🧪 Claude Code Test Notification</b>

<b>Host:</b> <code>${HOSTNAME}</code>
<b>Status:</b> ✅ Working correctly

<b>Configuration:</b>
• Bot Token: <code>${TELEGRAM_BOT_TOKEN:0:10}...</code>
• Chat ID: <code>${TELEGRAM_CHAT_ID}</code>
• Hook Script: <code>telegram-hook.sh</code>

<i>Sent at $(date '+%Y-%m-%d %H:%M:%S')</i>"

        send_telegram_html "$MSG"
        echo "Test notification sent!"
        ;;

    error)
        # Error notification
        MSG="<b>❌ Claude Code Error</b>

<b>Host:</b> <code>${HOSTNAME}</code>
<b>Project:</b> <code>${PROJECT_NAME}</code>"

        if [ -n "$MESSAGE" ]; then
            ESCAPED_MSG=$(echo "$MESSAGE" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
            MSG="${MSG}

<b>Error:</b>
<pre>${ESCAPED_MSG}</pre>"
        fi

        MSG="${MSG}

<i>$(date '+%Y-%m-%d %H:%M:%S')</i>"

        send_telegram_html "$MSG"
        ;;

    custom)
        # Custom message (read from MESSAGE env var or second argument)
        CUSTOM_MSG="${2:-$MESSAGE}"
        if [ -z "$CUSTOM_MSG" ]; then
            echo "Error: No custom message provided" >&2
            exit 1
        fi

        MSG="<b>📬 Claude Code</b>

<b>Host:</b> <code>${HOSTNAME}</code>
<b>Project:</b> <code>${PROJECT_NAME}</code>

${CUSTOM_MSG}

<i>$(date '+%Y-%m-%d %H:%M:%S')</i>"

        send_telegram_html "$MSG"
        ;;

    *)
        echo "Unknown hook type: $HOOK_TYPE" >&2
        echo "Usage: $0 [stop|notification|test|error|custom]" >&2
        exit 1
        ;;
esac

exit 0

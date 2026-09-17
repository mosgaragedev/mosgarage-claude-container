#!/bin/bash
#
# notify-hook.sh - Push notification hook for Claude Code
#
# This script is called by Claude Code hooks to send push notifications
# via ntfy.sh when Claude needs input or completes a task.
#
# Usage:
#   notify-hook.sh notification "Permission request message"
#   notify-hook.sh stop "end_turn|user_interrupt|etc"
#   notify-hook.sh test "Test message"
#

# Configuration
CONFIG_DIR="${HOME}/.config/claude-notify"
TOPIC_FILE="${CONFIG_DIR}/topic"

# Check if topic is configured
if [[ ! -f "${TOPIC_FILE}" ]]; then
    echo "Error: ntfy topic not configured. Run setup-ntfy.sh first." >&2
    exit 1
fi

TOPIC=$(cat "${TOPIC_FILE}")
NTFY_URL="https://ntfy.sh/${TOPIC}"

# Get current working directory for context
CWD=$(pwd 2>/dev/null || echo "unknown")
PROJECT_NAME=$(basename "${CWD}" 2>/dev/null || echo "unknown")

# Hostname for identification (useful when running on VPS)
HOSTNAME_SHORT=$(hostname -s 2>/dev/null || echo "unknown")

# Event type and message
EVENT_TYPE="${1:-unknown}"
MESSAGE="${2:-No message provided}"

# Truncate message if too long (ntfy has limits)
if [[ ${#MESSAGE} -gt 500 ]]; then
    MESSAGE="${MESSAGE:0:497}..."
fi

# Function to send notification
send_notification() {
    local title="$1"
    local body="$2"
    local priority="$3"
    local tags="$4"
    local click_url="$5"
    local actions="$6"

    # Build curl command
    local curl_args=(
        -s
        -o /dev/null
        -H "Title: ${title}"
        -H "Priority: ${priority}"
        -H "Tags: ${tags}"
    )

    # Add click URL if provided
    if [[ -n "${click_url}" ]]; then
        curl_args+=(-H "Click: ${click_url}")
    fi

    # Add actions if provided
    if [[ -n "${actions}" ]]; then
        curl_args+=(-H "Actions: ${actions}")
    fi

    # Send the notification
    curl "${curl_args[@]}" -d "${body}" "${NTFY_URL}" 2>/dev/null
}

case "${EVENT_TYPE}" in
    notification)
        # Claude is waiting for user input/permission
        # This typically happens when Claude needs approval for an action

        # Try to extract what Claude is asking for
        if echo "${MESSAGE}" | grep -qi "permission\|approve\|confirm\|allow"; then
            TITLE="Claude Needs Permission"
            TAGS="robot,warning,loudspeaker"
            PRIORITY="high"
        else
            TITLE="Claude Notification"
            TAGS="robot,bell"
            PRIORITY="default"
        fi

        BODY="[${HOSTNAME_SHORT}:${PROJECT_NAME}]
${MESSAGE}

Tap to connect and respond."

        # Deep link to Termius (if configured) or generic SSH
        # Termius URL scheme: termius://host/hostname
        # Generic SSH: ssh://user@host
        CLICK_URL=""

        # Action button to mark as seen (useful for tracking)
        ACTIONS="view, Connect via SSH, ssh://matt@${HOSTNAME_SHORT}"

        send_notification "${TITLE}" "${BODY}" "${PRIORITY}" "${TAGS}" "${CLICK_URL}" "${ACTIONS}"
        ;;

    stop)
        # Claude has stopped - determine why
        STOP_REASON="${MESSAGE}"

        case "${STOP_REASON}" in
            end_turn)
                TITLE="Claude Completed"
                BODY="[${HOSTNAME_SHORT}:${PROJECT_NAME}]
Task finished - ready for next instruction."
                TAGS="robot,white_check_mark"
                PRIORITY="default"
                ;;
            user_interrupt)
                TITLE="Claude Interrupted"
                BODY="[${HOSTNAME_SHORT}:${PROJECT_NAME}]
Session was interrupted by user."
                TAGS="robot,stop_sign"
                PRIORITY="low"
                ;;
            tool_error)
                TITLE="Claude Error"
                BODY="[${HOSTNAME_SHORT}:${PROJECT_NAME}]
A tool encountered an error. Check session."
                TAGS="robot,x,warning"
                PRIORITY="high"
                ;;
            max_turns)
                TITLE="Claude Hit Turn Limit"
                BODY="[${HOSTNAME_SHORT}:${PROJECT_NAME}]
Maximum conversation turns reached."
                TAGS="robot,hourglass"
                PRIORITY="default"
                ;;
            *)
                TITLE="Claude Stopped"
                BODY="[${HOSTNAME_SHORT}:${PROJECT_NAME}]
Reason: ${STOP_REASON}"
                TAGS="robot,octagonal_sign"
                PRIORITY="default"
                ;;
        esac

        send_notification "${TITLE}" "${BODY}" "${PRIORITY}" "${TAGS}" "" ""
        ;;

    test)
        # Test notification
        TITLE="Test Notification"
        BODY="[${HOSTNAME_SHORT}:${PROJECT_NAME}]
${MESSAGE}

Push notifications are working!"
        TAGS="robot,test_tube,white_check_mark"
        PRIORITY="default"

        send_notification "${TITLE}" "${BODY}" "${PRIORITY}" "${TAGS}" "" ""
        echo "Test notification sent to ${NTFY_URL}"
        ;;

    *)
        # Unknown event type - send generic notification
        TITLE="Claude Event: ${EVENT_TYPE}"
        BODY="[${HOSTNAME_SHORT}:${PROJECT_NAME}]
${MESSAGE}"
        TAGS="robot,question"
        PRIORITY="default"

        send_notification "${TITLE}" "${BODY}" "${PRIORITY}" "${TAGS}" "" ""
        ;;
esac

exit 0

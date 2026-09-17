#!/usr/bin/env bash
# ==============================================================================
# ntfy-with-termius.sh - Send ntfy notifications with Termius deep links
# ==============================================================================
# Author: Matt Fitzgerald / Hillway Property Consultants
# Purpose: Send push notifications that open Termius directly when tapped
# ==============================================================================
#
# Usage:
#   ./ntfy-with-termius.sh "Your message"                     # Basic notification
#   ./ntfy-with-termius.sh -t "Title" "Your message"          # With title
#   ./ntfy-with-termius.sh -p high "Urgent message"           # High priority
#   ./ntfy-with-termius.sh -h                                 # Show help
#
# Environment Variables:
#   NTFY_TOPIC           - Your ntfy topic (required)
#   NTFY_SERVER          - ntfy server URL (default: https://ntfy.sh)
#   TERMIUS_HOST_LABEL   - Termius host label (default: Claude VPS)
#
# ==============================================================================

set -e

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

NTFY_SERVER="${NTFY_SERVER:-https://ntfy.sh}"
NTFY_TOPIC="${NTFY_TOPIC:-}"
TERMIUS_HOST_LABEL="${TERMIUS_HOST_LABEL:-Claude VPS}"

# URL encode the Termius host label for deep link
TERMIUS_LABEL_ENCODED=$(echo "$TERMIUS_HOST_LABEL" | sed 's/ /%20/g')
TERMIUS_DEEP_LINK="termius://host?label=${TERMIUS_LABEL_ENCODED}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------

show_help() {
    cat << EOF
ntfy Notification Sender with Termius Deep Links

Usage: $(basename "$0") [OPTIONS] "MESSAGE"

Options:
  -t, --title TITLE     Notification title (default: VPS Alert)
  -p, --priority LEVEL  Priority: min, low, default, high, urgent
  -g, --tags TAGS       Comma-separated tags/emojis (e.g., "computer,check")
  -c, --click URL       Override click URL (default: Termius deep link)
  -n, --no-termius      Disable Termius deep link
  -h, --help            Show this help message

Environment Variables:
  NTFY_TOPIC            Your ntfy topic (required)
  NTFY_SERVER           Server URL (default: https://ntfy.sh)
  TERMIUS_HOST_LABEL    Termius host label (default: Claude VPS)

Examples:
  # Basic notification
  $(basename "$0") "Task completed successfully"

  # With title and high priority
  $(basename "$0") -t "Claude Alert" -p high "Urgent: Review needed"

  # With custom tags
  $(basename "$0") -g "white_check_mark,computer" "Build finished"

  # Task completion notification
  $(basename "$0") -t "Task Done" -g "tada" "Refactoring complete in 5m 32s"

Setup:
  1. Install ntfy app on your phone (iOS/Android)
  2. Subscribe to your topic in the app
  3. Set environment variable: export NTFY_TOPIC="your-topic"
  4. Ensure Termius is configured with host label matching TERMIUS_HOST_LABEL

Termius Integration:
  When you tap the notification, it will open Termius and connect
  directly to your Claude VPS (requires Termius app installed).

EOF
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

send_notification() {
    local message="$1"
    local title="${2:-VPS Alert}"
    local priority="${3:-default}"
    local tags="${4:-computer}"
    local click_url="$5"

    if [[ -z "$NTFY_TOPIC" ]]; then
        log_error "NTFY_TOPIC environment variable not set"
        echo ""
        echo "Set it with: export NTFY_TOPIC=\"your-topic-name\""
        exit 1
    fi

    # Build curl command
    local curl_args=(
        -s
        -H "Title: $title"
        -H "Priority: $priority"
        -H "Tags: $tags"
    )

    # Add click URL if provided
    if [[ -n "$click_url" ]]; then
        curl_args+=(-H "Click: $click_url")
    fi

    # Send notification
    local response
    response=$(curl "${curl_args[@]}" -d "$message" "${NTFY_SERVER}/${NTFY_TOPIC}" 2>&1) || {
        log_error "Failed to send notification: $response"
        exit 1
    }

    log_info "Notification sent to topic: $NTFY_TOPIC"
    if [[ -n "$click_url" ]]; then
        log_info "Click action: $click_url"
    fi
}

# ------------------------------------------------------------------------------
# Parse Arguments
# ------------------------------------------------------------------------------

TITLE="VPS Alert"
PRIORITY="default"
TAGS="computer"
CLICK_URL="$TERMIUS_DEEP_LINK"
MESSAGE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--title)
            TITLE="$2"
            shift 2
            ;;
        -p|--priority)
            PRIORITY="$2"
            shift 2
            ;;
        -g|--tags)
            TAGS="$2"
            shift 2
            ;;
        -c|--click)
            CLICK_URL="$2"
            shift 2
            ;;
        -n|--no-termius)
            CLICK_URL=""
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            MESSAGE="$1"
            shift
            ;;
    esac
done

# ------------------------------------------------------------------------------
# Main Execution
# ------------------------------------------------------------------------------

if [[ -z "$MESSAGE" ]]; then
    log_error "No message provided"
    echo ""
    show_help
    exit 1
fi

send_notification "$MESSAGE" "$TITLE" "$PRIORITY" "$TAGS" "$CLICK_URL"

# ==============================================================================

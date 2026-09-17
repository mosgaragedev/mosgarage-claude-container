#!/usr/bin/env bash
# ==============================================================================
# claude-session.sh - Start or attach to a Claude Code tmux session
# ==============================================================================
# Author: Matt Fitzgerald / Hillway Property Consultants
# Purpose: Manage persistent Claude Code sessions via tmux
# ==============================================================================
#
# Usage:
#   ./claude-session.sh                    # Start/attach to default 'claude' session
#   ./claude-session.sh -s myproject       # Use custom session name
#   ./claude-session.sh -p "Fix the bug"   # Start with initial prompt
#   ./claude-session.sh -d /path/to/dir    # Start in specific directory
#   ./claude-session.sh -n                 # Always create new session
#   ./claude-session.sh -h                 # Show help
#
# Examples:
#   ./claude-session.sh -s bizgen -d ~/Projects/bizgen
#   ./claude-session.sh -s document-filer -p "Review the filer status"
#   ./claude-session.sh -n -s temp-task    # Force new session
#
# ==============================================================================

set -e

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

DEFAULT_SESSION="claude"
DEFAULT_DIR="${HOME}/Projects"
TMUX_CONF="${HOME}/.tmux.conf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------

show_help() {
    cat << EOF
Claude Code Session Manager

Usage: $(basename "$0") [OPTIONS]

Options:
  -s, --session NAME    Session name (default: ${DEFAULT_SESSION})
  -d, --directory DIR   Working directory (default: ${DEFAULT_DIR})
  -p, --prompt TEXT     Initial prompt to send to Claude Code
  -n, --new             Force create new session (kill existing if present)
  -l, --list            List existing Claude sessions
  -k, --kill NAME       Kill specified session
  -h, --help            Show this help message

Examples:
  $(basename "$0")                                    # Attach to 'claude' session
  $(basename "$0") -s bizgen -d ~/Projects/bizgen    # Custom session for project
  $(basename "$0") -s task -p "Review the code"      # Start with a prompt
  $(basename "$0") -l                                 # List all Claude sessions
  $(basename "$0") -k claude                          # Kill the claude session

Session Management:
  - Sessions persist when you detach (Ctrl+A, d)
  - Reattach anytime with the same session name
  - Multiple sessions can run in parallel
  - Use -l to see all active sessions

EOF
}

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

check_dependencies() {
    if ! command -v tmux &> /dev/null; then
        log_error "tmux is not installed. Install with: brew install tmux"
        exit 1
    fi

    if ! command -v claude &> /dev/null; then
        log_error "claude CLI is not installed or not in PATH"
        exit 1
    fi
}

list_sessions() {
    log_info "Active tmux sessions:"
    echo ""
    if tmux list-sessions 2>/dev/null; then
        echo ""
        log_info "Attach to a session with: $(basename "$0") -s <session-name>"
    else
        log_warning "No active tmux sessions found"
    fi
}

kill_session() {
    local session_name="$1"
    if tmux has-session -t "$session_name" 2>/dev/null; then
        tmux kill-session -t "$session_name"
        log_success "Killed session: $session_name"
    else
        log_warning "Session not found: $session_name"
    fi
}

session_exists() {
    tmux has-session -t "$1" 2>/dev/null
}

create_session() {
    local session_name="$1"
    local work_dir="$2"
    local initial_prompt="$3"

    log_info "Creating new session: $session_name"
    log_info "Working directory: $work_dir"

    # Ensure directory exists
    if [[ ! -d "$work_dir" ]]; then
        log_warning "Directory does not exist: $work_dir"
        log_info "Creating directory..."
        mkdir -p "$work_dir"
    fi

    # Create new detached session
    if [[ -n "$initial_prompt" ]]; then
        # Start Claude with initial prompt
        tmux new-session -d -s "$session_name" -c "$work_dir" "claude \"$initial_prompt\"; exec bash"
    else
        # Start Claude interactively
        tmux new-session -d -s "$session_name" -c "$work_dir" "claude; exec bash"
    fi

    log_success "Session '$session_name' created"
}

attach_session() {
    local session_name="$1"
    log_info "Attaching to session: $session_name"
    tmux attach-session -t "$session_name"
}

# ------------------------------------------------------------------------------
# Parse Arguments
# ------------------------------------------------------------------------------

SESSION_NAME="$DEFAULT_SESSION"
WORK_DIR="$DEFAULT_DIR"
INITIAL_PROMPT=""
FORCE_NEW=false
ACTION="start"

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--session)
            SESSION_NAME="$2"
            shift 2
            ;;
        -d|--directory)
            WORK_DIR="$2"
            shift 2
            ;;
        -p|--prompt)
            INITIAL_PROMPT="$2"
            shift 2
            ;;
        -n|--new)
            FORCE_NEW=true
            shift
            ;;
        -l|--list)
            ACTION="list"
            shift
            ;;
        -k|--kill)
            ACTION="kill"
            SESSION_NAME="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# ------------------------------------------------------------------------------
# Main Execution
# ------------------------------------------------------------------------------

check_dependencies

case $ACTION in
    list)
        list_sessions
        exit 0
        ;;
    kill)
        kill_session "$SESSION_NAME"
        exit 0
        ;;
    start)
        # If forcing new, kill existing session first
        if $FORCE_NEW && session_exists "$SESSION_NAME"; then
            log_warning "Killing existing session: $SESSION_NAME"
            kill_session "$SESSION_NAME"
        fi

        # Create or attach to session
        if session_exists "$SESSION_NAME"; then
            log_info "Session '$SESSION_NAME' already exists"
            attach_session "$SESSION_NAME"
        else
            create_session "$SESSION_NAME" "$WORK_DIR" "$INITIAL_PROMPT"
            attach_session "$SESSION_NAME"
        fi
        ;;
esac

# ==============================================================================

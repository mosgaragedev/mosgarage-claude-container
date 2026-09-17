#!/usr/bin/env bash
# ==============================================================================
# claude-task.sh - Run Claude Code tasks in the background with logging
# ==============================================================================
# Author: Matt Fitzgerald / Hillway Property Consultants
# Purpose: Execute Claude Code tasks in background with output logging and
#          optional Slack notifications on completion
# ==============================================================================
#
# Usage:
#   ./claude-task.sh "Your prompt here"                    # Basic usage
#   ./claude-task.sh -d /path/to/dir "Your prompt"        # In specific directory
#   ./claude-task.sh -o custom.log "Your prompt"          # Custom log file
#   ./claude-task.sh -n "Task name" "Your prompt"         # Named task
#   ./claude-task.sh -w "Your prompt"                     # Wait for completion
#   ./claude-task.sh -h                                    # Show help
#
# Examples:
#   ./claude-task.sh "Refactor the auth module"
#   ./claude-task.sh -d ~/Projects/bizgen -n "BizGen API" "Create new endpoint"
#   ./claude-task.sh -w -n "Quick fix" "Fix the typo in README"
#
# Environment Variables:
#   CLAUDE_TASK_SLACK_WEBHOOK    - Slack webhook URL for notifications
#   CLAUDE_TASK_LOG_DIR          - Directory for log files (default: ~/.claude-tasks)
#
# ==============================================================================

set -e

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

LOG_DIR="${CLAUDE_TASK_LOG_DIR:-${HOME}/.claude-tasks}"
SLACK_WEBHOOK="${CLAUDE_TASK_SLACK_WEBHOOK:-}"
DEFAULT_DIR="${HOME}/Projects"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------

show_help() {
    cat << EOF
Claude Code Background Task Runner

Usage: $(basename "$0") [OPTIONS] "PROMPT"

Options:
  -d, --directory DIR   Working directory (default: current directory or ~/Projects)
  -o, --output FILE     Custom log file path (default: auto-generated in ~/.claude-tasks)
  -n, --name NAME       Task name for identification (used in logs and notifications)
  -w, --wait            Wait for task to complete (foreground mode)
  -s, --silent          Suppress output (background mode only)
  -t, --tail            Start task and immediately tail the log
  -l, --list            List recent task logs
  -v, --view LOG_FILE   View a specific log file
  -h, --help            Show this help message

Environment Variables:
  CLAUDE_TASK_SLACK_WEBHOOK    Slack webhook URL for completion notifications
  CLAUDE_TASK_LOG_DIR          Log directory (default: ~/.claude-tasks)

Examples:
  $(basename "$0") "Refactor the authentication module"
  $(basename "$0") -d ~/Projects/bizgen "Create user API endpoint"
  $(basename "$0") -n "Document Filer" -d ~/Projects/document-filer "Process remaining files"
  $(basename "$0") -w "Quick syntax fix"
  $(basename "$0") -t "Long running task with live output"
  $(basename "$0") -l                    # List recent logs
  $(basename "$0") -v task_20241229.log  # View specific log

Notification Setup:
  To enable Slack notifications on task completion:
  export CLAUDE_TASK_SLACK_WEBHOOK="https://hooks.slack.com/services/XXX/YYY/ZZZ"

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

log_task() {
    echo -e "${CYAN}[TASK]${NC} $1"
}

check_dependencies() {
    if ! command -v claude &> /dev/null; then
        log_error "claude CLI is not installed or not in PATH"
        exit 1
    fi
}

ensure_log_dir() {
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR"
        log_info "Created log directory: $LOG_DIR"
    fi
}

list_logs() {
    log_info "Recent task logs in $LOG_DIR:"
    echo ""
    if [[ -d "$LOG_DIR" ]] && [[ -n "$(ls -A "$LOG_DIR" 2>/dev/null)" ]]; then
        ls -lt "$LOG_DIR"/*.log 2>/dev/null | head -20 | while read -r line; do
            echo "  $line"
        done
        echo ""
        log_info "View a log with: $(basename "$0") -v <filename>"
    else
        log_warning "No logs found"
    fi
}

view_log() {
    local log_file="$1"

    # If just filename provided, look in LOG_DIR
    if [[ ! -f "$log_file" ]]; then
        log_file="${LOG_DIR}/${log_file}"
    fi

    if [[ -f "$log_file" ]]; then
        less -R "$log_file"
    else
        log_error "Log file not found: $log_file"
        exit 1
    fi
}

send_slack_notification() {
    local task_name="$1"
    local status="$2"
    local duration="$3"
    local log_file="$4"

    if [[ -z "$SLACK_WEBHOOK" ]]; then
        return 0
    fi

    local icon="white_check_mark"
    local color="good"

    if [[ "$status" != "0" ]]; then
        icon="x"
        color="danger"
    fi

    local message
    message=$(cat << EOF
{
    "attachments": [
        {
            "color": "${color}",
            "blocks": [
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": ":${icon}: *Claude Task Completed*\n*Task:* ${task_name}\n*Duration:* ${duration}\n*Status:* $([ "$status" = "0" ] && echo "Success" || echo "Failed (exit code: ${status})")"
                    }
                },
                {
                    "type": "context",
                    "elements": [
                        {
                            "type": "mrkdwn",
                            "text": "Log: \`${log_file}\`"
                        }
                    ]
                }
            ]
        }
    ]
}
EOF
)

    curl -s -X POST -H 'Content-type: application/json' --data "$message" "$SLACK_WEBHOOK" > /dev/null 2>&1 || true
}

format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(( (seconds % 3600) / 60 ))
    local secs=$((seconds % 60))

    if [[ $hours -gt 0 ]]; then
        printf "%dh %dm %ds" $hours $minutes $secs
    elif [[ $minutes -gt 0 ]]; then
        printf "%dm %ds" $minutes $secs
    else
        printf "%ds" $secs
    fi
}

generate_log_filename() {
    local task_name="$1"
    local sanitized_name

    if [[ -n "$task_name" ]]; then
        # Sanitize task name for filename
        sanitized_name=$(echo "$task_name" | tr ' ' '_' | tr -cd '[:alnum:]_-' | head -c 30)
        echo "${LOG_DIR}/${sanitized_name}_${TIMESTAMP}.log"
    else
        echo "${LOG_DIR}/claude_task_${TIMESTAMP}.log"
    fi
}

run_task() {
    local prompt="$1"
    local work_dir="$2"
    local log_file="$3"
    local task_name="$4"
    local wait_mode="$5"
    local silent_mode="$6"
    local tail_mode="$7"

    local start_time
    start_time=$(date +%s)

    # Write task header to log
    {
        echo "=============================================================================="
        echo "Claude Code Task Log"
        echo "=============================================================================="
        echo "Task Name:  ${task_name:-unnamed}"
        echo "Started:    $(date)"
        echo "Directory:  ${work_dir}"
        echo "Log File:   ${log_file}"
        echo "=============================================================================="
        echo "Prompt:"
        echo "$prompt"
        echo "=============================================================================="
        echo ""
    } > "$log_file"

    if [[ "$wait_mode" == "true" ]]; then
        # Foreground mode - run and wait
        log_task "Running task: ${task_name:-unnamed}"
        log_info "Directory: $work_dir"
        log_info "Log file: $log_file"
        echo ""

        cd "$work_dir"

        # Run Claude and capture exit code
        set +e
        claude "$prompt" 2>&1 | tee -a "$log_file"
        local exit_code=${PIPESTATUS[0]}
        set -e

        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        local duration_str
        duration_str=$(format_duration $duration)

        # Write footer to log
        {
            echo ""
            echo "=============================================================================="
            echo "Task completed at: $(date)"
            echo "Duration: $duration_str"
            echo "Exit code: $exit_code"
            echo "=============================================================================="
        } >> "$log_file"

        echo ""
        if [[ $exit_code -eq 0 ]]; then
            log_success "Task completed in $duration_str"
        else
            log_error "Task failed with exit code $exit_code after $duration_str"
        fi

        # Send notification
        send_slack_notification "$task_name" "$exit_code" "$duration_str" "$log_file"

        return $exit_code
    else
        # Background mode
        if [[ "$silent_mode" != "true" ]]; then
            log_task "Starting background task: ${task_name:-unnamed}"
            log_info "Directory: $work_dir"
            log_info "Log file: $log_file"
            log_info "Monitor with: tail -f $log_file"
        fi

        # Run in background with nohup
        (
            cd "$work_dir"

            set +e
            claude "$prompt" >> "$log_file" 2>&1
            local exit_code=$?
            set -e

            local end_time
            end_time=$(date +%s)
            local duration=$((end_time - start_time))
            local duration_str
            duration_str=$(format_duration $duration)

            # Write footer to log
            {
                echo ""
                echo "=============================================================================="
                echo "Task completed at: $(date)"
                echo "Duration: $duration_str"
                echo "Exit code: $exit_code"
                echo "=============================================================================="
            } >> "$log_file"

            # Send notification
            send_slack_notification "${task_name:-unnamed}" "$exit_code" "$duration_str" "$log_file"
        ) &

        local pid=$!

        if [[ "$silent_mode" != "true" ]]; then
            log_info "Background PID: $pid"
            echo ""
        fi

        # If tail mode, follow the log
        if [[ "$tail_mode" == "true" ]]; then
            sleep 1  # Brief pause to let task start
            log_info "Tailing log file (Ctrl+C to stop watching, task continues)..."
            echo ""
            tail -f "$log_file"
        fi
    fi
}

# ------------------------------------------------------------------------------
# Parse Arguments
# ------------------------------------------------------------------------------

WORK_DIR=""
LOG_FILE=""
TASK_NAME=""
WAIT_MODE="false"
SILENT_MODE="false"
TAIL_MODE="false"
ACTION="run"
PROMPT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--directory)
            WORK_DIR="$2"
            shift 2
            ;;
        -o|--output)
            LOG_FILE="$2"
            shift 2
            ;;
        -n|--name)
            TASK_NAME="$2"
            shift 2
            ;;
        -w|--wait)
            WAIT_MODE="true"
            shift
            ;;
        -s|--silent)
            SILENT_MODE="true"
            shift
            ;;
        -t|--tail)
            TAIL_MODE="true"
            shift
            ;;
        -l|--list)
            ACTION="list"
            shift
            ;;
        -v|--view)
            ACTION="view"
            LOG_FILE="$2"
            shift 2
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
            PROMPT="$1"
            shift
            ;;
    esac
done

# ------------------------------------------------------------------------------
# Main Execution
# ------------------------------------------------------------------------------

check_dependencies
ensure_log_dir

case $ACTION in
    list)
        list_logs
        exit 0
        ;;
    view)
        view_log "$LOG_FILE"
        exit 0
        ;;
    run)
        if [[ -z "$PROMPT" ]]; then
            log_error "No prompt provided"
            echo ""
            show_help
            exit 1
        fi

        # Set defaults if not provided
        if [[ -z "$WORK_DIR" ]]; then
            WORK_DIR="${PWD}"
        fi

        if [[ -z "$LOG_FILE" ]]; then
            LOG_FILE=$(generate_log_filename "$TASK_NAME")
        fi

        # Validate directory
        if [[ ! -d "$WORK_DIR" ]]; then
            log_error "Directory does not exist: $WORK_DIR"
            exit 1
        fi

        run_task "$PROMPT" "$WORK_DIR" "$LOG_FILE" "$TASK_NAME" "$WAIT_MODE" "$SILENT_MODE" "$TAIL_MODE"
        ;;
esac

# ==============================================================================

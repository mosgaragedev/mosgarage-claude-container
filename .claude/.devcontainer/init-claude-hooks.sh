#!/bin/bash
set -euo pipefail

# Get workspace folder from environment or default
WORKSPACE_FOLDER="${containerWorkspaceFolder:-/workspaces/claude-devcontainer}"
WORKSPACE_HOOKS="$WORKSPACE_FOLDER/.claude/hooks"
TEMPLATE_DIR="/usr/local/share/claude-defaults/hooks"

echo "Initializing Claude Code hooks..."

# Create .claude/hooks directory in workspace if it doesn't exist
if [ ! -d "$WORKSPACE_HOOKS" ]; then
    echo "Creating $WORKSPACE_HOOKS directory..."
    mkdir -p "$WORKSPACE_HOOKS"
fi

# Copy session-start hook template if it doesn't exist
if [ ! -f "$WORKSPACE_HOOKS/session-start.sh" ]; then
    if [ -f "$TEMPLATE_DIR/session-start.sh" ]; then
        echo "Installing session-start hook..."
        cp "$TEMPLATE_DIR/session-start.sh" "$WORKSPACE_HOOKS/"
        chmod +x "$WORKSPACE_HOOKS/session-start.sh"
        echo "✓ Session-start hook installed at $WORKSPACE_HOOKS/session-start.sh"
    else
        echo "Warning: Hook template not found at $TEMPLATE_DIR/session-start.sh"
    fi
else
    echo "Session-start hook already exists, preserving user customizations"
    # Ensure it's executable even if it already exists
    chmod +x "$WORKSPACE_HOOKS/session-start.sh"
fi

# Set ownership to node user
chown -R node:node "$WORKSPACE_FOLDER/.claude" 2>/dev/null || true

echo "Claude Code hooks initialization complete"

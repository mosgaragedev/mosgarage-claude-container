#!/bin/bash
set -e

ACTION=${1:-clone}

# Environment Variables
REPO_URL=${REPO_URL:-}
VOLUME_NAME=${VOLUME_NAME:-repo_data}
MOUNT_POINT=${MOUNT_POINT:-/data}
SSH_KEY=${SSH_KEY:-}
AZURE_TENANT=${AZURE_TENANT:-}
AZURE_CLIENT_ID=${AZURE_CLIENT_ID:-}
AZURE_CLIENT_SECRET=${AZURE_CLIENT_SECRET:-}

# Automate SSH Connection
if [ -n "$SSH_KEY" ]; then
    mkdir -p ~/.ssh
    echo "$SSH_KEY" > ~/.ssh/id_rsa
    chmod 600 ~/.ssh/id_rsa
    ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
    echo "SSH key injected and GitHub known_hosts updated."
fi

# Automate Microsoft Sandbox Login (igedevteam.onmicrosoft.com)
if [ -n "$AZURE_TENANT" ] && [ -n "$AZURE_CLIENT_ID" ] && [ -n "$AZURE_CLIENT_SECRET" ]; then
    echo "Authenticating with MS Developer Sandbox..."
    az login --service-principal -u "$AZURE_CLIENT_ID" -p "$AZURE_CLIENT_SECRET" --tenant "$AZURE_TENANT" --allow-no-subscriptions > /dev/null
    echo "Azure CLI authenticated."
fi

# Execute Action
if [ "$ACTION" = "clone" ]; then
    if [ -z "$REPO_URL" ]; then echo "Error: REPO_URL is required for cloning."; exit 1; fi
    echo "Cloning $REPO_URL into volume at $MOUNT_POINT..."
    git clone "$REPO_URL" "$MOUNT_POINT/workspace"
    echo "Clone complete."
elif [ "$ACTION" = "inspect" ]; then
    echo "Inspecting volume $VOLUME_NAME..."
    ls -la "$MOUNT_POINT"
    docker volume inspect "$VOLUME_NAME" || echo "Volume not found locally."
elif [ "$ACTION" = "recover" ]; then
    BACKUP_DIR="/backup/workspace_$(date +%F_%T)"
    echo "Recovering data to $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"
    cp -r "$MOUNT_POINT/workspace" "$BACKUP_DIR/"
    echo "Recovery complete."
else
    exec "$@"
fi

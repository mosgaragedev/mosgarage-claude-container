#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to handle errors
error_exit() {
    echo "Error: $1"
    exit 1
}

# Function to change directory and run a command
run_in_dir() {
    local dir="$1"
    shift
    local cmd="$@"

    echo ">> Entering directory: ${dir}"
    pushd "${dir}" > /dev/null || error_exit "Failed to navigate to ${dir}"

    # Run the command and handle any errors
    echo ">> ${cmd}"
    eval "${cmd}" || error_exit "Failed to execute command: ${cmd} in ${dir}"

    popd > /dev/null
}

# Add the repository to the list of safe directories for Git
git config --global --add safe.directory /workspaces/spring-postgres

echo "Current directory: $(pwd)"

run_in_dir "frontend" "npm install"

echo '🚀 Setup finished successfully!'
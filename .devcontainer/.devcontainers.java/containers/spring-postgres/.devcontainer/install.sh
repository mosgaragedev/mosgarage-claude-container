#!/bin/bash

# Add the repository to the list of safe directories for Git
git config --global --add safe.directory /workspaces/spring-postgres

# Execute the Gradle build process
./gradlew build

echo '🚀 Setup finished successfully!'
# Git Commit and Push Command

Analyzes current changes, writes a descriptive commit message, and pushes to the current branch.

## Usage
```
/commit [optional custom message]
```

## What it does
1. Shows git status to see what files have changed
2. Shows git diff to analyze the actual changes
3. Gets recent commit history to understand the commit message style
4. Adds all changes to staging
5. Writes a descriptive commit message based on the changes
6. Creates the commit with Claude Code attribution
7. Pushes to the current branch

## Examples
```
/commit
/commit "fix: update QR code validation logic"
```

If no custom message is provided, Claude will analyze the changes and write an appropriate commit message automatically.

## Notes
- Follows conventional commit format when possible
- Includes Claude Code attribution
- Will not commit if there are no changes
- Automatically pushes after successful commit
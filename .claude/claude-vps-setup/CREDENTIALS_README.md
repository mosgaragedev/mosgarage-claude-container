# Claude Code Credentials Transfer Scripts

Secure scripts for transferring Claude Code configuration from your Mac to a VPS.

## Scripts Overview

### 1. `export-credentials.sh` (Run on Mac)

Creates an encrypted tarball containing your Claude Code configuration.

**What it exports:**
- `~/.claude.json` - MCP server configuration
- `~/.claude/settings.json` - Claude Code settings
- `~/.claude/CLAUDE.md` - Your global instructions
- `~/.claude/statsig.json` - Feature flags (optional)
- `~/.claude/projects.json` - Project list (optional)
- `~/.claude/skills/` - Custom skills directory

**Security features:**
- Automatically redacts sensitive tokens (API keys, OAuth tokens)
- Replaces secrets with `SET_ON_VPS` placeholder
- Uses AES-256-CBC encryption with PBKDF2
- Creates timestamped archive

**Usage:**
```bash
# Creates archive on Desktop (default)
./export-credentials.sh

# Or specify output directory
./export-credentials.sh /path/to/output
```

### 2. `import-credentials.sh` (Run on VPS)

Imports credentials from the encrypted archive.

**What it does:**
- Decrypts the archive
- Backs up any existing configuration
- Installs files to correct locations
- Sets proper permissions (700/600)
- Validates JSON syntax
- Lists tokens that need manual configuration

**Usage:**
```bash
./import-credentials.sh /tmp/claude-credentials-20241230_103800.tar.gz.enc
```

### 3. `sync-credentials.sh` (Run on Mac - All-in-One)

Combines export, transfer, and import in one command.

**Usage:**
```bash
# Basic usage
./sync-credentials.sh my-vps.example.com

# With username
./sync-credentials.sh matt@192.168.1.100

# With custom port
./sync-credentials.sh matt@my-vps.example.com:2222

# Dry run (show what would happen)
./sync-credentials.sh my-vps.example.com --dry-run

# Transfer only, don't run import
./sync-credentials.sh my-vps.example.com --no-import
```

## Quick Start

### Option A: One-liner sync

```bash
./sync-credentials.sh root@your-vps-ip
```

You'll be prompted for:
1. Encryption password (set it, remember it)
2. SSH password or key authentication
3. Decryption password (same as encryption)

### Option B: Manual transfer

```bash
# On Mac: Create encrypted archive
./export-credentials.sh

# Transfer to VPS
scp ~/Desktop/claude-credentials-*.tar.gz.enc root@your-vps:/tmp/

# Copy import script
scp import-credentials.sh root@your-vps:/tmp/

# On VPS: Import
ssh root@your-vps
chmod +x /tmp/import-credentials.sh
/tmp/import-credentials.sh /tmp/claude-credentials-*.tar.gz.enc
```

## What Gets Redacted

The export script automatically removes these sensitive patterns:

| Pattern | Description |
|---------|-------------|
| `sk-*` | Anthropic API keys |
| `xoxp-*` | Slack user tokens |
| `xoxb-*` | Slack bot tokens |
| `ghp_*` | GitHub personal access tokens |
| `ghs_*` | GitHub server tokens |
| `ANTHROPIC_API_KEY` | Environment variable values |
| `SUPABASE_*_KEY` | Supabase credentials |

These are replaced with `SET_ON_VPS` in the exported config.

## Post-Import Setup

After importing on the VPS, you must:

### 1. Set API Tokens

Edit `~/.claude.json` and replace `SET_ON_VPS` with actual values:

```bash
nano ~/.claude.json
```

Find and update:
```json
{
  "mcpServers": {
    "github": {
      "env": {
        "GITHUB_TOKEN": "ghp_your_actual_token"
      }
    },
    "slack": {
      "env": {
        "SLACK_MCP_XOXP_TOKEN": "xoxp-your_actual_token"
      }
    }
  }
}
```

### 2. Set Environment Variables

Add to your shell profile (`~/.bashrc` or `~/.zshrc`):

```bash
export ANTHROPIC_API_KEY="sk-ant-your-key"
```

### 3. Install MCP Server Packages

```bash
# GitHub MCP
npm install -g @modelcontextprotocol/server-github

# Supabase MCP
npm install -g @supabase/mcp-server-supabase

# Slack MCP (using korotovsky version)
npm install -g slack-mcp-server

# Puppeteer MCP (optional - requires Chrome)
npm install -g @anthropic-ai/claude-mcp-server-puppeteer
```

### 4. Test the Setup

```bash
claude --version
claude chat
```

## Security Best Practices

1. **Delete archives after import** - Don't leave encrypted files lying around
2. **Use strong encryption password** - Different from your other passwords
3. **Never commit credentials** - Add `*.enc` to `.gitignore`
4. **Rotate tokens periodically** - Especially after transfer
5. **Verify file permissions** - Should be 600 (owner read/write only)

## Troubleshooting

### "Permission denied" on scripts
```bash
chmod +x export-credentials.sh import-credentials.sh sync-credentials.sh
```

### "openssl: command not found"
```bash
# Mac (should be installed)
brew install openssl

# Ubuntu/Debian
apt install openssl
```

### "jq: command not found" (optional for validation)
```bash
# Mac
brew install jq

# Ubuntu/Debian
apt install jq
```

### "Claude Code not found"
```bash
npm install -g @anthropic-ai/claude-code
```

### Wrong permissions after import
```bash
chmod 700 ~/.claude
chmod 600 ~/.claude.json ~/.claude/*
```

## File Locations Reference

| File | Purpose |
|------|---------|
| `~/.claude.json` | MCP server configuration, global settings |
| `~/.claude/settings.json` | UI/behavior preferences, permissions |
| `~/.claude/CLAUDE.md` | Global instructions (your CLAUDE.md) |
| `~/.claude/skills/` | Custom skill definitions |
| `~/.claude/projects.json` | Known projects list |
| `~/.claude/statsig.json` | Feature flags |

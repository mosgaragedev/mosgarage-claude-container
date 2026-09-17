# Claude Code VPS Setup

A comprehensive, idempotent setup script for running Claude Code persistently on a VPS (Ubuntu/Debian).

## Features

- Updates system packages
- Installs Node.js 20 LTS
- Installs Claude Code globally via npm
- Installs essential tools: tmux, mosh, git, htop, fail2ban, ufw
- Configures tmux with mouse support, vim keybindings, and a nice status bar
- Creates a dedicated `claude` user
- Sets up a systemd service for persistent tmux sessions
- Provides helper scripts for common operations
- Configures firewall (UFW) with SSH and Mosh ports

## Quick Start

```bash
# Upload to your VPS
scp setup-vps.sh root@your-server-ip:/root/

# SSH into your VPS
ssh root@your-server-ip

# Run the setup
chmod +x setup-vps.sh
./setup-vps.sh

# Set your API key
su - claude
echo 'export ANTHROPIC_API_KEY="sk-ant-..."' >> ~/.bashrc
source ~/.bashrc

# Start Claude Code
sudo systemctl start claude-tmux.service
claude-attach
claude
```

## Helper Commands

Once setup is complete, these commands are available for the `claude` user:

| Command | Description |
|---------|-------------|
| `claude-attach` | Connect to the tmux session |
| `claude-start` | Start Claude Code in tmux |
| `claude-stop` | Stop the Claude session |
| `claude-restart` | Restart the session |
| `claude-status` | Check session status |
| `claude-logs` | View service logs |
| `claude-update` | Update Claude Code |

## tmux Key Bindings

The script configures tmux with these custom bindings:

| Key | Action |
|-----|--------|
| `Ctrl+a` | Prefix (instead of Ctrl+b) |
| `Prefix + \|` | Split pane horizontally |
| `Prefix + -` | Split pane vertically |
| `Prefix + h/j/k/l` | Navigate panes (vim-style) |
| `Prefix + H/J/K/L` | Resize panes |
| `Prefix + r` | Reload config |
| `Alt + 1-5` | Quick window switching |
| Mouse | Enabled for scrolling and selection |

## Connection Methods

### SSH
```bash
ssh claude@your-server-ip
claude-attach
```

### Mosh (Recommended for unstable connections)
```bash
mosh claude@your-server-ip
claude-attach
```

## Systemd Service

The service is configured to start automatically on boot:

```bash
# Start the service
sudo systemctl start claude-tmux.service

# Stop the service
sudo systemctl stop claude-tmux.service

# Check status
sudo systemctl status claude-tmux.service

# View logs
journalctl -u claude-tmux.service -f
```

## Configuration

### API Key
Set your Anthropic API key in `~/.bashrc`:
```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```

### Extended Thinking
Already configured with 10,000 tokens:
```bash
export CLAUDE_CODE_MAX_THINKING_TOKENS=10000
```

### Custom Session Name
Change the default tmux session name:
```bash
export CLAUDE_SESSION_NAME="my-session"
```

## Directory Structure

After setup:
```
/home/claude/
├── .claude/
│   └── env              # Environment template
├── .local/bin/          # Helper scripts
├── .tmux.conf           # tmux configuration
├── logs/                # Log files
└── projects/            # Working directory
```

## Requirements

- Ubuntu 20.04+ or Debian 11+
- Root access
- Internet connection

## Idempotent

The script is safe to run multiple times. It will:
- Skip already-installed packages
- Update existing configurations
- Not duplicate entries

## Security

The script configures:
- UFW firewall (SSH + Mosh ports)
- fail2ban for SSH protection
- Non-root user for Claude Code

## License

MIT

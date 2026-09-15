# Claude Code + Codex + Gemini CLI DevContainer

A production-ready VS Code devcontainer that combines Claude Code, OpenAI Codex CLI, and Google Gemini CLI in a secure, sandboxed environment as per https://claude-devcontainers.centminmod.com.

## Overview

**What is this?**

This is a pre-configured development environment that runs in an isolated container on your computer. Think of it as a "development workspace in a box" - everything you need to code with AI assistants is already set up and ready to go.

**How does it work?**

Instead of installing Claude Code, Python, Node.js, and dozens of other tools directly on your computer, this devcontainer packages everything into a Docker container. When you open your project in VS Code, it automatically:

1. Creates a secure, isolated workspace
2. Installs all the AI coding assistants (Claude Code, Codex, Gemini)
3. Sets up development tools and package managers
4. Configures network security to only allow trusted connections
5. Preserves your API keys and settings across restarts

**Why use this?**

- **Zero Setup**: No manual installation of tools - just open and start coding
- **Consistency**: Works the same on Mac, Windows, and Linux
- **Security**: Network firewall blocks unauthorized connections by default
- **Multiple AI Assistants**: Claude Code, OpenAI Codex, and Google Gemini work side-by-side
- **Clean Host System**: All tools run in the container, keeping your computer clean
- **Team-Ready**: Share the same development environment across your entire team
- **Disposable**: Delete and rebuild anytime without losing your configurations

## Features

- **Claude Code** - Anthropic's AI coding assistant with MCP servers support
- **MCP Servers** - Three pre-configured servers:
  - **Context7** - Library documentation and code examples
  - **Cloudflare Docs** - Cloudflare products documentation
  - **Chrome DevTools** - Browser automation with Chromium
- **Claude Code Skills** - AI cross-verifier skill for multi-AI code validation using Codex and Gemini CLI
- **Codex CLI** - OpenAI's coding agent for your terminal
- **Gemini CLI** - Google's AI agent with Gemini models
- **OpenCode CLI** - Open-source terminal AI coding agent with multi-model support
- **Modern Package Managers** - uv (Python) and bun (JavaScript) pre-installed
- **React/Next.js Ready** - Pre-configured for React, Next.js, shadcn/ui, and Tailwind CSS
- **OpenTelemetry Integration** - Full observability with metrics, logs, and traces
- **Security by design** - Three-layer security with network firewall, IPv6 protection, and dynamic IP whitelisting
- **Persistent configurations** - All CLI configs persist across container rebuilds
- **Developer-friendly** - ZSH with productivity enhancements, fzf, git-delta
- **VS Code integration** - Pre-configured extensions for optimal experience
- **Complete toolchain** - Build tools, compilers, and utilities for any project
- **UTF-8 locale support** - Proper encoding for international characters

## Prerequisites

- [VS Code](https://code.visualstudio.com/)
- [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

## Quick Start

### Using This Repository Directly

1. Clone this repository
2. Open in VS Code
3. When prompted, click "Reopen in Container"
4. Wait for the container to build (first time takes ~5-10 minutes)

### Adding to Your Existing Project

If your project already has a Dockerfile (for production), you can add this devcontainer without conflicts:

#### Option 1: Copy .devcontainer directory (Recommended)

```bash
# From this repository
cp -r .devcontainer /path/to/your/project/

# Your project structure will be:
# your-project/
# ├── Dockerfile              ← Your production Dockerfile (no conflict!)
# ├── .devcontainer/
# │   ├── devcontainer.json   ← Dev environment config
# │   ├── Dockerfile          ← Dev environment image
# │   └── init-firewall.sh    ← Firewall script
# └── src/
```

#### Option 2: Rename devcontainer Dockerfile

If you prefer, you can rename the devcontainer Dockerfile:

```bash
# Rename the Dockerfile
mv .devcontainer/Dockerfile .devcontainer/Dockerfile.devcontainer

# Update devcontainer.json line 4:
"dockerfile": "Dockerfile.devcontainer",
```

#### Option 3: Use as template

Copy only the configuration you need and customize for your stack.

## Configuration

### API Keys

You'll need to configure API keys for the AI assistants you want to use:

**Claude Code:**

```bash
claude config set apiKey YOUR_ANTHROPIC_API_KEY
```

**Codex CLI:**

First run will prompt for authentication:

```bash
codex
```

**Gemini CLI:**

⚠️ **Container Limitation**: Google account authentication (`/ide install`) does not work in dev containers due to dynamic port forwarding issues ([GitHub issue #6297](https://github.com/google-gemini/gemini-cli/issues/6297)). Use API key authentication instead.

**Setup Options** (choose one):

**Option 1: .env File (Recommended for devcontainers)** ⭐

```bash
# Copy the template
cp .env.example .env

# Edit .env and add your key
GEMINI_API_KEY=your_google_api_key_here
```

⚠️ **Security**: .env is git-ignored. Never commit API keys to version control.

**Option 2: Environment variable (temporary)**

```bash
export GEMINI_API_KEY=YOUR_GOOGLE_API_KEY
```

**Option 3: Settings file (persistent)**

```bash
mkdir -p ~/.gemini
echo '{"apiKey": "YOUR_GOOGLE_API_KEY"}' > ~/.gemini/settings.json
```

Get your API key: https://makersuite.google.com/app/apikey

**Note**: While the `google.gemini-cli-vscode-ide-companion` extension is pre-installed, the IDE integration features requiring Google account authentication will not function in this containerized environment. API key authentication provides full CLI functionality.

**OpenCode:**

OpenCode is provider-agnostic and supports multiple AI providers. Configure your preferred provider:

**Option 1: Anthropic (Claude)**
```bash
# Set API key via environment variable
export ANTHROPIC_API_KEY=YOUR_ANTHROPIC_API_KEY

# Or use config command
opencode config set provider anthropic
opencode config set apiKey YOUR_ANTHROPIC_API_KEY
```

**Option 2: OpenAI**
```bash
export OPENAI_API_KEY=YOUR_OPENAI_API_KEY
opencode config set provider openai
```

**Option 3: Google (Gemini)**
```bash
export GOOGLE_API_KEY=YOUR_GOOGLE_API_KEY
opencode config set provider google
```

**Option 4: .env file (persistent across sessions)**
```bash
# Add to .env file in workspace root
echo "ANTHROPIC_API_KEY=your_key_here" >> .env
```

**Verify configuration:**
```bash
opencode config list
opencode --version
```

**Note**: OpenCode's multi-model support means you can switch providers based on your needs. Configuration persists in `/home/node/.opencode` via Docker volume. See the [OpenCode documentation](https://opencode.ai/) for local model setup.

**GitHub CLI (gh):**

The GitHub CLI is pre-installed for creating pull requests and managing repositories from the terminal.

**One-time authentication required:**

```bash
gh auth login
```

**Interactive prompts:**
```
? What account do you want to log into? GitHub.com
? What is your preferred protocol for Git operations? HTTPS
? Authenticate Git with your GitHub credentials? Yes
? How would you like to authenticate GitHub CLI? Login with a web browser

! First copy your one-time code: XXXX-XXXX
Press Enter to open github.com in your browser...
✓ Authentication complete.
```

**Alternative: Personal Access Token**

If browser authentication doesn't work in your Docker environment:

```bash
# Create token at: https://github.com/settings/tokens
# Required scopes: repo, workflow

echo "your_token_here" | gh auth login --with-token
```

**Verify authentication:**
```bash
gh auth status
gh api user --jq .login  # Should show your username
```

**Persistence:**
- GitHub authentication is stored in `/home/node/.config/gh`
- Persists across container rebuilds via Docker named volume
- Re-authentication only needed if volume is deleted

**Required for:**
- Creating pull requests: `gh pr create`
- Viewing PR status: `gh pr view`
- Managing issues: `gh issue create`
- Repository operations: `gh repo clone`

### Persistent Storage

The following directories are persisted in named volumes:

- `/home/node/.claude` - Claude Code configuration
- `/home/node/.codex` - Codex CLI configuration
- `/home/node/.gemini` - Gemini CLI settings
- `/home/node/.opencode` - OpenCode configuration
- `/home/node/.config/gh` - GitHub CLI authentication tokens
- `/home/node/.npm-global` - Global npm packages
- `/home/node/.cargo` - uv (Python package manager)
- `/home/node/.bun` - Bun runtime and cache
- `/home/node/.local` - AWS CLI binary and local installations
- `/home/node/.aws` - AWS CLI credentials and configuration
- `/home/node/.wrangler` - Cloudflare Wrangler configuration
- `/home/node/.vercel` - Vercel CLI configuration
- `/commandhistory` - Shell command history

## Git Workflow and Branch Protection

This devcontainer includes a git workflow safeguard system to prevent accidental data loss and ensure code quality through automated pre-commit hooks and branch protection.

### Branch Protection System

**Pre-commit Hook Enforcement:**
- Direct commits to `main`/`master` branches are **technically blocked** by a git hook
- Hook runs automatically on every commit attempt
- Provides guidance on creating feature branches
- Can be bypassed with `--no-verify` (not recommended)
- Automatically installed via `postStartCommand` in devcontainer.json

**Workflow Requirements:**

**STEP 0: Pre-Work Sync Check (MANDATORY)**

Before creating any new branch or starting work, ALWAYS ensure master is up-to-date:

```bash
# 1. Switch to master (if not already there)
git checkout master

# 2. Fetch latest changes from remote (safe, doesn't merge)
git fetch origin

# 3. Check sync status
git status
```

**Interpret status and take action:**

- ✅ `"Your branch is up to date with 'origin/master'"` → **Proceed to step 1 below**

- ⚠️ `"Your branch is behind 'origin/master' by X commits"` → **Pull first:**
  ```bash
  git pull origin master
  # Verify: git status  # Should now show "up to date"
  ```

- ⚠️ `"Your branch and 'origin/master' have diverged"` → **Resolve divergence:**
  ```bash
  # Option 1: If you have no local commits on master, force update
  git reset --hard origin/master

  # Option 2: If you have local commits, merge or rebase
  git pull origin master  # Creates merge commit
  # OR
  git rebase origin/master  # Replays your commits on top
  ```

**Why this matters:** Ensures your feature branch is based on the latest code, preventing work on outdated master and reducing future merge conflicts.

**Only after master is up-to-date**, proceed with the workflow below:

Before ANY destructive operation (rm, major refactors, rewrites):

1. **Verify clean state:** Run `git status` - must show clean working tree or committed changes
2. **Create feature branch:** Use descriptive naming:
   - `feature/description` - for new features
   - `fix/description` - for bug fixes
   - `session/YYYYMMDD-HHMM-description` - for session-based work
   - `refactor/description` - for refactoring work
3. **Confirm branch:** Run `git branch --show-current` - must NOT be main/master
4. **Proceed with changes** - now safe to make destructive edits
5. **Commit frequently:** After each logical unit of work

**NEVER:**
- Delete files while on main/master branch
- Run `rm -rf` without verifying you're on a feature branch
- Skip commits during long refactors
- Force-push to main/master
- Bypass pre-commit hook without explicit user request

### PR and Merge Workflow

When work is complete and ready for review:

1. **Use git-pr-helper skill** - Provides comprehensive PR assistance (see [Claude Code Skills](#claude-code-skills))
2. **Generate PR description** - Skill analyzes commits and creates quality description
3. **Run safety checks** - Verify tests pass, no conflicts with base branch
4. **Create PR** - Using `gh pr create` or skill workflow
5. **Merge after review** - Skill guides merge strategy (regular, squash, rebase)
6. **Clean up branches** - Skill helps identify and remove old branches

### Safety Stack

This project uses a defense-in-depth approach:

1. **Layer 1 - Git Hook (Technical Enforcement):** Blocks commits to main/master automatically
2. **Layer 2 - CLAUDE.md Instructions (Guidance):** Protocol guides safe workflows
3. **Layer 3 - git-pr-helper Skill (Workflow Assistance):** Helps with PR/merge operations
4. **Layer 4 - Docker Volumes (Data Persistence):** Configs survive container rebuilds
5. **Layer 5 - User Review (Final Check):** Never merge without user confirmation

### Hook Installation

Git hooks are stored in `.git/hooks/` and are NOT committed to the repository. This devcontainer automatically installs hooks on container start via `postStartCommand`.

**Manual reinstallation (if needed):**
```bash
bash /workspaces/claude-devcontainer/.devcontainer/setup-git-hooks.sh
```

The setup script includes robust git repository detection that works with git worktrees, submodules, and any clone location.

## Security

### Container Security Architecture

This devcontainer follows a security-first design with defense-in-depth principles:

**Capability Model:**
- Uses `cap-drop=ALL` to remove all Linux capabilities by default
- Selectively adds only required capabilities with `cap-add`:
  - `NET_ADMIN` + `NET_RAW` - Network firewall management (iptables, ipset)
  - `SETUID` + `SETGID` - User switching for proper file permissions
  - `SYS_ADMIN` - Kernel parameter control for IPv6 disabling

**Security Benefits:**
- Minimal attack surface through capability restrictions
- Defense-in-depth with multiple security layers
- Network isolation through firewall rules
- Non-root user execution (node user)
- Persistent volumes with proper ownership

### Network Firewall

The devcontainer includes a network firewall that restricts outbound connections to:

- **npm registry** (registry.npmjs.org)
- **GitHub** (api.github.com, github.com)
- **Claude API** (api.anthropic.com)
- **OpenAI API** (api.openai.com)
- **Google AI API** (generativelanguage.googleapis.com)
- **VS Code services** (marketplace, updates, telemetry)
- **SSH connections** (port 22)
- **DNS queries** (port 53)
- **Local network** (Docker host network)

All other outbound connections are blocked by default.

**Dynamic IP Range Whitelisting:**

The firewall automatically fetches and whitelists IP ranges for:
- **Anthropic** - Claude API infrastructure
- **Google Cloud** - Gemini API and services
- **Cloudflare** - CDN and edge network

Uses `ipset` for efficient IP range matching, supporting both DNS-resolvable domains and direct IP address ranges.

**Resilient DNS Resolution:**

The firewall script handles DNS resolution failures gracefully:
- Warns on failed DNS lookups instead of failing container startup
- Tracks resolution statistics (e.g., "98/102 domains resolved successfully")
- Container starts even if some domains (like Alibaba Cloud endpoints) fail to resolve
- Firewall remains functional with the successfully resolved domains

This ensures the container starts reliably in all network environments while maintaining security through the domains that do resolve.

### Adding Domains to Firewall

To whitelist additional domains, edit [.devcontainer/init-firewall.sh](.devcontainer/init-firewall.sh) and add them to the domain list around line 47:

```bash
for domain in \
    "registry.npmjs.org" \
    "api.anthropic.com" \
    "api.openai.com" \
    "generativelanguage.googleapis.com" \
    "your-new-domain.com" \
    ...
```

Then rebuild the container.

### Three-Layer IPv6 Security

The devcontainer implements defense-in-depth IPv6 protection for maximum compatibility:

**Layer 1: Container Creation (Most Reliable)**
- IPv6 disabled at container creation via `--sysctl` flags in devcontainer.json
- Applied before container starts, works in most environments

**Layer 2: Runtime Disable with Graceful Degradation**
- Runtime IPv6 disable attempt via sysctl in init-firewall.sh
- Non-fatal if it fails (environment constraints may prevent disabling)
- Warning message displayed instead of container startup failure

**Layer 3: IPv6 Firewall Rules (Security Backup)**
- ip6tables DROP policies for INPUT/FORWARD/OUTPUT
- Only allows IPv6 localhost (::1) traffic
- Explicitly REJECTs all other IPv6 traffic
- Provides equivalent security if IPv6 cannot be disabled

This approach ensures the container starts successfully while maintaining security across all environments (Docker Desktop, Podman, cloud, various host configurations).

### Security Warning

⚠️ **IMPORTANT**: Only use this devcontainer with trusted repositories. When Claude Code is run with `--dangerously-skip-permissions`, malicious code could potentially exfiltrate data accessible in the container, including API credentials.

### Git Configuration (Anthropic Best Practice)

The container automatically configures git to ignore `.claude/settings.local.json` globally. This prevents accidentally committing:

- API keys
- Personal configuration
- Sensitive settings

This is an official Anthropic best practice that Claude Code itself implements.

## Claude Code Settings Strategy

Claude Code uses two configuration files with different purposes:

### `.claude/settings.json` (Committed to Git)

**Purpose**: Project-wide configuration shared with your team

**What goes here:**

- Environment variables affecting Claude's behavior (`MAX_MCP_OUTPUT_TOKENS`, timeout values)
- Project-wide permission policies
- Git commit settings (`includeCoAuthoredBy`)
- Tool approval policies shared across the team

**Example** (already included in this repo):

```json
{
  "env": {
    "MAX_MCP_OUTPUT_TOKENS": "60000",
    "BASH_DEFAULT_TIMEOUT_MS": "300000",
    "BASH_MAX_TIMEOUT_MS": "600000",
    "MAX_THINKING_TOKENS": "8192"
  },
  "includeCoAuthoredBy": false
}
```

### `.claude/settings.local.json` (Git-Ignored, Personal)

**Purpose**: Personal overrides and machine-specific settings

**What goes here:**

- Your Anthropic API key
- Personal workflow preferences
- Experimental settings you're testing
- Machine-specific environment variables

**Example**:

```json
{
  "apiKey": "your-api-key-here",
  "dangerouslySkipPermissions": true
}
```

### Settings Precedence

Settings merge with the following priority (highest to lowest):

1. `.claude/settings.local.json` (personal, git-ignored)
2. `.claude/settings.json` (project-wide, committed)
3. Global Claude Code settings (~/.claude/config.json)
4. Claude Code defaults

This means you can override team settings locally for testing without affecting others.

## Port Forwarding

The following ports are automatically forwarded:

- **3000** - Gemini Server
- **8080** - Development Server
- **8888** - Jupyter/Lab

## VS Code Extensions

Pre-installed extensions:

- **Claude Code** - Anthropic's AI coding assistant
- **ESLint** - JavaScript linting
- **Prettier** - Code formatting
- **GitLens** - Git visualization
- **ChatGPT** - OpenAI integration
- **OpenCode** - Open-source terminal AI coding agent
- **Gemini CLI VSCode IDE Companion** - Gemini integration
- **Gemini Code Assist** - Google's code assistance
- **GitHub Copilot** - GitHub's AI pair programmer
- **GitHub Copilot Chat** - Conversational coding
- **Kilo Code** - Additional AI coding tools
- **ShellCheck** - Shell script linting
- **Claude Dev** - Alternative Claude interface
- **Beyond Compare** - File comparison
- **Even Better TOML** - TOML language support
- **Jupyter Keymap** - Jupyter keybindings
- **Sublime Keybindings** - Sublime Text keybindings
- **GC Excel Viewer** - Excel/CSV file viewer
- **JSON Flow** - JSON visualization
- **Python** - Python language support
- **Pylance** - Python type checking and IntelliSense
- **Debugpy** - Python debugger
- **YAML** - YAML language support

## Usage Examples

### Fast Search Tools

```bash
# ripgrep - blazing fast text search
rg "TODO"                    # Find all TODOs (smart-case by default)
rg -i "error"                # Case-insensitive search
rg -t js "function"          # Search only JavaScript files
rg "api" --stats             # Show search statistics

# fd - fast file finder
fd test                      # Find files/dirs matching "test"
fd -e js                     # Find all .js files
fd -H config                 # Include hidden files
fd -t f ".*\.py$"           # Find only files (not dirs) matching pattern
```

### Claude Code

```bash
# Start an interactive session
claude

# Run a specific task
claude "refactor this function to use async/await"

# Work with specific files
claude "add error handling to api.ts"
```

### MCP Servers

Claude Code has access to **three pre-configured MCP (Model Context Protocol) servers**:

**Context7** - Library documentation and code examples
```bash
# In Claude Code, you can ask:
"Show me Next.js documentation for app router"
"How do I use MongoDB aggregation pipelines?"
"Give me examples of React hooks"
```

**Cloudflare Docs** - Cloudflare products documentation
```bash
# In Claude Code, you can ask:
"How do I deploy a Worker to Cloudflare?"
"Show me R2 storage API documentation"
"What are the limits for Durable Objects?"
```

**Chrome DevTools** - Browser automation and testing
```bash
# In Claude Code, you can ask:
"Take a screenshot of https://example.com"
"Navigate to this URL and click the login button"
"Get the console logs from the current page"
```

### How MCP Servers Are Configured

All three MCP servers are automatically installed during container initialization via `.devcontainer/mcp-install.sh`:

**Transport Types:**
- **Context7** and **cf-docs**: SSE (Server-Sent Events) transport - remote HTTP connections
- **Chrome DevTools**: stdio transport - local subprocess with container-optimized Chromium

**Configuration Storage:**
- SSE servers: `/home/node/.claude/mcp.json` (JSON format)
- stdio servers: Claude's internal configuration (managed by `claude mcp add` command)

**Verify Installation:**
```bash
# List all configured MCP servers
claude mcp list

# Expected output:
# context7: https://mcp.context7.com/sse (SSE) - ✓ Connected
# cf-docs: https://docs.mcp.cloudflare.com/sse (SSE) - ✓ Connected
# chrome-devtools: npx chrome-devtools-mcp@latest ... - ✓ Connected
```

**Container-Specific Chromium Flags:**

Chrome DevTools MCP uses special flags for containerized environments:
- `--executablePath=/usr/bin/chromium` - Use container's Chromium installation
- `--headless` - Run without GUI (server environment)
- `--no-sandbox` - Required for Docker containers (no kernel sandboxing)
- `--disable-setuid-sandbox` - Disable SUID sandbox (incompatible with containers)
- `--disable-dev-shm-usage` - Use /tmp instead of /dev/shm (avoids Docker memory limits)

These flags are necessary because Docker's security model conflicts with Chrome's native sandboxing.

### Manual MCP Server Management

**Reinstall All Servers:**
```bash
.devcontainer/mcp-install.sh
```

**Add Individual Server:**
```bash
# SSE server example
claude mcp add --transport sse context7 https://mcp.context7.com/sse

# stdio server example (with flags after --)
claude mcp add --transport stdio chrome-devtools npx chrome-devtools-mcp@latest -- \
  --executablePath=/usr/bin/chromium \
  --headless \
  --chromeArg='--no-sandbox'
```

**Remove Server:**
```bash
claude mcp remove <server-name>
```

**Template Configuration** (SSE servers only):

The template at `/usr/local/share/claude-defaults/mcp.json` contains baseline configuration for SSE servers, copied to `~/.claude/mcp.json` if not present. stdio servers like Chrome DevTools are stored separately in Claude's internal config.

```json
{
  "mcpServers": {
    "context7": {
      "transport": {
        "type": "sse",
        "url": "https://mcp.context7.com/sse"
      }
    },
    "cf-docs": {
      "transport": {
        "type": "sse",
        "url": "https://docs.mcp.cloudflare.com/sse"
      }
    }
  }
}
```

### Codex CLI

```bash
# Start interactive mode
codex

# Run with a prompt
codex "create a REST API with Express"

# Configure settings
codex --help
```

### Gemini CLI

**Note:** Requires `GEMINI_API_KEY` environment variable or `~/.gemini/settings.json` configured (see Configuration section above).

```bash
# Start interactive session
gemini

# Run a specific task
gemini "explain this code"

# Configure model
gemini --model gemini-pro
```

### OpenCode CLI

**Note:** OpenCode supports multiple AI providers. Configure your preferred provider first (see Configuration section above).

```bash
# Start interactive session
opencode

# Run with a specific task
opencode "refactor this function to use async/await"

# Check version and configuration
opencode --version
opencode config list

# Switch providers on the fly
opencode config set provider anthropic
opencode config set provider openai
opencode config set provider google
```

### uv (Python Package Manager)

```bash
# Create a new Python project
uv init my-project

# Install dependencies
uv pip install requests pandas numpy

# Run Python with uv
uv run python script.py

# Sync dependencies from pyproject.toml
uv sync
```

### bun (JavaScript Runtime)

```bash
# Initialize a new project
bun init

# Install dependencies (much faster than npm)
bun install

# Run scripts
bun run dev

# Execute a file
bun index.ts

# Add packages
bun add react next shadcn-ui
```

### Vercel CLI

```bash
# Login to Vercel
vercel login

# Deploy current directory
vercel

# Deploy to production
vercel --prod

# Link to existing project
vercel link

# Check deployment status
vercel ls

# View deployment logs
vercel logs <deployment-url>

# Pull environment variables
vercel env pull

# List projects
vercel projects ls
```

## Troubleshooting

### Container fails to build

- Check Docker is running
- Try rebuilding: `Dev Containers: Rebuild Container`
- Check Docker has enough resources (4GB+ RAM recommended)
- Use cleanup script: `./cleanup-devcontainer.sh` → option 2

### Firewall blocks needed domain

- Edit [init-firewall.sh](init-firewall.sh) to add the domain
- Rebuild container
- Check firewall logs: `sudo /usr/local/bin/init-firewall.sh`

### API authentication fails

- Verify API keys are set correctly
- Check network connectivity: `curl https://api.anthropic.com`
- Ensure firewall allows the API endpoint

### GitHub CLI authentication required

**Symptom**:
```
gh pr create
To get started with GitHub CLI, please run:  gh auth login
Alternatively, populate the GH_TOKEN environment variable with a GitHub API authentication token.
```

**Solution**:

Run the one-time authentication setup:

```bash
gh auth login
```

Follow the interactive prompts to authenticate via web browser.

**Verify authentication:**
```bash
gh auth status
# Expected: ✓ Logged in to github.com as <your-username>
```

**Alternative (if browser auth fails):**
```bash
# Create a Personal Access Token at: https://github.com/settings/tokens
# Required scopes: repo, workflow

echo "your_token_here" | gh auth login --with-token
```

**Persistence:**
- Authentication tokens are stored in `/home/node/.config/gh`
- Backed by Docker volume, persists across container rebuilds
- Only needs to be done once per devcontainer volume

### Git Hooks Issues

This devcontainer uses a pre-commit hook to prevent accidental commits directly to main/master branches. If you encounter issues with the hook system, use these troubleshooting steps:

#### Hook not blocking commits to main/master

**Symptom:** You can commit directly to main/master without any warning or block.

**Verification:**
```bash
# Check if hook is installed
ls -la .git/hooks/pre-commit

# Check if hook is executable
test -x .git/hooks/pre-commit && echo "Hook is executable" || echo "Hook is NOT executable"

# View hook content
cat .git/hooks/pre-commit
```

**Solutions:**

1. **Reinstall the hook:**
   ```bash
   bash /workspaces/claude-devcontainer/.devcontainer/setup-git-hooks.sh
   ```

2. **Check permissions:**
   ```bash
   chmod +x .git/hooks/pre-commit
   ```

3. **Verify hook is working:**
   ```bash
   # Switch to master and try a test commit (should be blocked)
   git checkout master
   touch test-file.txt
   git add test-file.txt
   git commit -m "test" # Should be blocked with error message
   ```

#### Setup script fails to install hook

**Symptom:** Running `setup-git-hooks.sh` produces errors or doesn't create the hook file.

**Check logs:**
```bash
bash -x /workspaces/claude-devcontainer/.devcontainer/setup-git-hooks.sh
```

**Common issues:**

1. **Not a git repository:** The script uses robust git detection via `git rev-parse --git-dir`, which works with standard repos, worktrees, and submodules. If it still fails:
   ```bash
   # Verify you're in a git repository
   git rev-parse --git-dir
   ```

2. **Permission denied:** Ensure `.git/hooks/` directory is writable:
   ```bash
   ls -la .git/hooks/
   chmod u+w .git/hooks/
   ```

3. **Container initialization:** The hook is automatically installed via `postStartCommand` in `devcontainer.json`. If the container started but hook wasn't installed, manually run:
   ```bash
   bash /workspaces/claude-devcontainer/.devcontainer/setup-git-hooks.sh
   ```

#### Testing hook manually

To verify the hook logic works correctly:

```bash
# Direct execution test
.git/hooks/pre-commit
echo $?  # Should output: 1 (blocked) if on main/master, 0 (allowed) otherwise
```

#### Emergency bypass (use with caution)

If you need to bypass the hook for a specific commit (not recommended):

```bash
git commit --no-verify -m "emergency commit message"
```

⚠️ **Warning:** Only use `--no-verify` in genuine emergencies. The hook exists to protect you from accidentally committing to main/master. Always prefer creating a feature branch instead.

### Global npm packages not found

- Verify PATH includes `/home/node/.npm-global/bin`
- Check npm prefix: `npm config get prefix` (should be `/home/node/.npm-global`)

### Codex CLI Landlock sandbox error

**Problem:** When running `codex` commands, you see:
```
thread 'main' panicked at linux-sandbox/src/linux_run_main.rs:30:9:
error running landlock: Sandbox(LandlockRestrict)
```

**Cause:** Docker Desktop's LinuxKit kernel doesn't include Landlock support (a Linux security module). This is a known limitation of containerized environments.

**Solution:** Disable Codex's sandboxing (safe in containers):

The configuration is already applied in `~/.codex/config.toml`:
```toml
sandbox_mode = "danger-full-access"
approval_policy = "never"
```

This is OpenAI's officially recommended approach for Docker containers. Security is provided by:
- Docker container isolation
- Network firewall restrictions ([init-firewall.sh](.devcontainer/init-firewall.sh))
- Non-root user execution

**Verify it's working:**
```bash
codex --version
codex exec "echo 'Hello from Codex'"
```

**⚠️ Known Limitation: VSCode Extension**

The above fix **only works for Codex CLI**, not the VSCode extension. This is a known OpenAI issue:

- ❌ **VSCode extension** ignores `sandbox_mode` in config.toml ([issue #5041](https://github.com/openai/codex/issues/5041))
- ✅ **Codex CLI** respects config.toml and works perfectly
- 🔧 **Workaround**: Use `codex exec "your prompt"` instead of the VSCode extension
- ⏳ **Status**: OpenAI is working on adding config.toml support to the extension

The VSCode extension tries to use Landlock sandboxing regardless of config settings, causing the same error in Docker environments. Until OpenAI fixes this, use the CLI for Codex functionality.

### OpenCode `/models` crash or TUI freeze

**Symptom**:
```
TypeError: undefined is not an object (evaluating 'flat().length')
    at <anonymous> (src/cli/cmd/tui/ui/dialog-select.tsx:49:49)
```

**Cause:** Incompatible providers in auth.json (cloudflare-workers-ai doesn't support AI SDK v5, expired OAuth tokens)

**Solution:**

1. **Backup your configuration:**
   ```bash
   cp ~/.local/share/opencode/auth.json ~/.local/share/opencode/auth.json.backup
   ```

2. **Edit auth.json to remove incompatible providers:**
   ```bash
   nano ~/.local/share/opencode/auth.json
   # Remove: cloudflare-workers-ai, expired github-copilot entries
   # Keep: anthropic, openrouter, nvidia, openai, google
   ```

3. **Clear OpenCode cache:**
   ```bash
   rm -rf ~/.cache/opencode/*
   ```

4. **Verify fix:**
   ```bash
   opencode models  # Should list models without errors
   ```

**Compatible providers:** anthropic, openai, google, openrouter, nvidia

**Known incompatible:** cloudflare-workers-ai (AI SDK v5), requesty

**Reference:** Similar issue reported in [OpenCode Issue #2468](https://github.com/sst/opencode/issues/2468)

## Architecture

```text
┌─────────────────────────────────────────────┐
│           VS Code (Host)                     │
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│         Docker Container                     │
│  ┌─────────────────────────────────────┐    │
│  │  Node.js 22 + TypeScript             │    │
│  │  - Claude Code                        │    │
│  │  - Codex CLI                          │    │
│  │  - Gemini CLI                         │    │
│  └─────────────────────────────────────┘    │
│                                              │
│  ┌─────────────────────────────────────┐    │
│  │  Network Firewall (iptables)         │    │
│  │  - Whitelist-based filtering         │    │
│  │  - Default deny policy               │    │
│  └─────────────────────────────────────┘    │
│                                              │
│  ┌─────────────────────────────────────┐    │
│  │  Persistent Volumes                  │    │
│  │  - ~/.claude                          │    │
│  │  - ~/.codex                           │    │
│  │  - ~/.gemini                          │    │
│  │  - ~/.config/gh                       │    │
│  │  - ~/.npm-global                      │    │
│  │  - ~/.cargo                           │    │
│  │  - ~/.bun                             │    │
│  │  - ~/.local                           │    │
│  │  - ~/.aws                             │    │
│  │  - ~/.wrangler                        │    │
│  └─────────────────────────────────────┘    │
└──────────────────────────────────────────────┘
```

## Included Packages & Tools

The container includes a comprehensive set of development tools:

### Core Tools

- **Shell**: ZSH with Oh My Zsh, fzf fuzzy finder
- **Version Control**: Git, Git LFS, GitHub CLI (gh)
- **Editors**: Nano, Vim
- **Build Tools**: build-essential, gcc, g++, make, cmake, pkg-config
- **Fast Search**: ripgrep (rg), fd-find (fd) - Modern grep/find replacements

### Network & System

- **Network Tools**: curl, wget, netcat, telnet, ping, net-tools
- **DNS Tools**: dig, nslookup, host
- **Process Tools**: htop, procps, tree
- **Security**: iptables, ipset, OpenSSL

### Development

- **Python**: Python 3 with pip, venv, and development headers
- **Node.js**: Node 22 with npm, yarn, pnpm support
- **Cloud Tools**: AWS CLI v2, Cloudflare Wrangler, Vercel CLI
- **Libraries**: zlib, libssl, libffi, readline, sqlite3, ncurses
- **Data Tools**: jq (JSON), yq (YAML), sed, awk

### Compression & Archives

- zip, unzip, bzip2, xz-utils

### Locale Support

- UTF-8 locale configured (en_US.UTF-8) for proper international character support

### Why These Tools Matter

- **ripgrep** (`rg`): 10-100x faster than grep, respects .gitignore by default, colored output
- **fd**: 5-10x faster than find, simpler syntax, respects .gitignore

This comprehensive toolset ensures Claude Code, Codex CLI, and Gemini CLI can:

- Build native npm modules (node-gyp)
- Compile C/C++ projects
- Process data in various formats
- Work with any repository dependencies
- Search codebases lightning-fast with ripgrep and fd

## OpenTelemetry Monitoring Integration

This devcontainer can optionally be configured to send telemetry data to an external OpenTelemetry collector for monitoring Claude Code usage, costs, and performance.

### Configuration

The devcontainer includes optional pre-configured OpenTelemetry environment variables in two locations:

**1. Container Environment** (`.devcontainer/devcontainer.json` - containerEnv section)
- Sets environment variables for the entire container
- Available to all processes, including shell sessions

**2. Claude Code Settings** (`.devcontainer/settings.json.template` - env section)
- Specific to Claude Code CLI
- Ensures telemetry works even if container env is modified

**Environment Variables:**
```json
{
  "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
  "OTEL_LOG_USER_PROMPTS": "1",
  "OTEL_METRICS_EXPORTER": "otlp",
  "OTEL_LOGS_EXPORTER": "otlp",
  "OTEL_EXPORTER_OTLP_PROTOCOL": "grpc",
  "OTEL_EXPORTER_OTLP_ENDPOINT": "http://otel-collector:4317",
  "OTEL_RESOURCE_ATTRIBUTES": "deployment.environment=devcontainer,service.name=claude-code"
}
```

**Note:** The settings are duplicated in both locations for redundancy. Claude Code reads from its own settings.json env section, so having them there ensures telemetry works regardless of container configuration changes.

The devcontainer automatically connects to the `claude-code-opentelemetry_otel` Docker network to communicate with your monitoring stack.

### Important Note: deployment.environment Label

**Claude Code currently ignores the `OTEL_RESOURCE_ATTRIBUTES` environment variable** and hardcodes `deployment.environment=local` for all telemetry data, regardless of the configured value.

This means:
- ✅ Telemetry **IS** flowing from the devcontainer to your OTel Collector
- ✅ Both environments use `service.name=claude-code` (same label)
- ❌ Both environments report `deployment.environment=local` (cannot differentiate)

### Workaround: Use os_type to Differentiate

Since Claude Code won't honor the `deployment.environment` attribute, you can differentiate devcontainer vs macOS usage using the **`os_type`** label:

| Environment | os_type | Terminal |
|------------|---------|----------|
| macOS Local | `darwin` | `iTerm.app` |
| Devcontainer | `linux` | `vscode` |

**Example Prometheus/Grafana Queries:**

```promql
# Devcontainer usage only
claude_code_cost_usage_USD_total{os_type="linux"}

# macOS local usage only
claude_code_cost_usage_USD_total{os_type="darwin"}

# All Claude Code usage (both environments)
claude_code_cost_usage_USD_total{service_name="claude-code"}
```

**Grafana Dashboard Filtering:**

If your Grafana dashboards filter by `service_name=claude-code`, they will show **combined metrics from both macOS and devcontainer**. To separate them, add an additional filter:

```promql
# Devcontainer only dashboard
claude_code_cost_usage_USD_total{service_name="claude-code",os_type="linux"}
```

### Network Requirements

The devcontainer must be connected to your OpenTelemetry network:
- Network: `claude-code-opentelemetry_otel` (auto-configured in devcontainer.json)
- Firewall allows traffic to 172.21.0.0/16 subnet (OTel Collector network)
- OTel Collector accessible at `otel-collector:4317` (gRPC)

For more details on setting up an OpenTelemetry monitoring stack for Claude Code, see the [official Claude Code monitoring documentation](https://docs.claude.com/en/docs/claude-code/monitoring-usage).

## Files

- [.devcontainer/devcontainer.json](.devcontainer/devcontainer.json) - Container configuration, mounts, extensions
- [.devcontainer/Dockerfile](.devcontainer/Dockerfile) - Container image definition, installed packages
- [.devcontainer/init-firewall.sh](.devcontainer/init-firewall.sh) - Network security setup script
- [.devcontainer/init-claude-config.sh](.devcontainer/init-claude-config.sh) - Claude Code auto-configuration script
- [.devcontainer/init-codex-config.sh](.devcontainer/init-codex-config.sh) - Codex CLI auto-configuration script (sandbox fix for containers)
- [.devcontainer/init-opencode-config.sh](.devcontainer/init-opencode-config.sh) - OpenCode auto-configuration script
- [.devcontainer/setup-git-hooks.sh](.devcontainer/setup-git-hooks.sh) - Git hook installation script with robust detection (worktrees, submodules)
- [.devcontainer/mcp-install.sh](.devcontainer/mcp-install.sh) - Manual MCP server installation script
- [.devcontainer/settings.json.template](.devcontainer/settings.json.template) - Claude Code settings template
- [.devcontainer/mcp.json.template](.devcontainer/mcp.json.template) - MCP servers configuration template
- [.devcontainer/llms.txt](.devcontainer/llms.txt) - AI discovery protocol documentation for AI assistants
- [.claude/skills/ai-cross-verifier/](.claude/skills/ai-cross-verifier/) - Multi-AI verification skill for code validation

## Resources

- [Claude Code Documentation](https://docs.claude.com/en/docs/claude-code)
- [Codex CLI Documentation](https://developers.openai.com/codex/cli/)
- [Gemini CLI Documentation](https://github.com/google-gemini/gemini-cli)
- [VS Code Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers)
- [Original Reference Implementation](https://github.com/hesreallyhim/claude-code-containers/tree/main/containers/node-python-basic/.devcontainer)

# mosgarage-claude-hq

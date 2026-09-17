# Telegram Notifications for Claude Code

Get instant Telegram notifications when Claude Code finishes tasks, needs permission, or requires your attention. Perfect for monitoring long-running tasks on VPS or remote servers.

## Overview

This setup provides:
- **Task completion alerts** - Know when Claude finishes processing
- **Permission requests** - Get notified when Claude needs tool approval
- **Idle notifications** - Alert when Claude is waiting for input
- **Project context** - See which project and host triggered the notification
- **Task summaries** - Brief summary of what was completed

## Prerequisites

- Telegram account
- `curl` installed (standard on most systems)
- `jq` installed (optional but recommended for better message extraction)

```bash
# Install jq on Ubuntu/Debian
sudo apt install jq

# Install jq on macOS
brew install jq
```

## Step 1: Create a Telegram Bot

1. **Open Telegram** and search for `@BotFather`

2. **Start a chat** with BotFather and send `/newbot`

3. **Follow the prompts:**
   - Enter a name for your bot (e.g., "Claude Code Notifications")
   - Enter a username for your bot (must end in `bot`, e.g., `my_claude_alerts_bot`)

4. **Save the API token** - BotFather will give you something like:
   ```
   123456789:ABCdefGHIjklMNOpqrSTUvwxYZ-1234567
   ```

5. **Optional: Customize your bot** with BotFather:
   - `/setdescription` - Add a description
   - `/setuserpic` - Add a profile photo
   - `/setcommands` - Not needed for notifications

## Step 2: Get Your Chat ID

### Method A: Automatic (Recommended)

1. **Start a conversation** with your new bot in Telegram
2. **Send any message** to the bot (e.g., "Hello")
3. **Run the setup script:**
   ```bash
   ./setup-telegram.sh
   ```
   The script will automatically fetch your chat ID

### Method B: Manual

1. **Start a conversation** with your bot and send a message

2. **Open this URL** in your browser (replace `YOUR_BOT_TOKEN`):
   ```
   https://api.telegram.org/botYOUR_BOT_TOKEN/getUpdates
   ```

3. **Find your chat ID** in the JSON response:
   ```json
   {
     "result": [{
       "message": {
         "chat": {
           "id": 123456789  <-- This is your chat ID
         }
       }
     }]
   }
   ```

### Method C: Use @userinfobot

1. Search for `@userinfobot` in Telegram
2. Start a chat and send any message
3. It will reply with your user ID (same as chat ID for private chats)

## Step 3: Run Setup Script

```bash
# Make executable
chmod +x setup-telegram.sh telegram-hook.sh

# Run setup
./setup-telegram.sh
```

The script will:
1. Prompt for your bot token
2. Automatically detect your chat ID
3. Send a test message
4. Save configuration to `~/.claude-telegram`
5. Install the hook script to `~/.claude/scripts/`

## Step 4: Configure Claude Code Hooks

Add the following to your `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/scripts/telegram-notify.sh stop"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/scripts/telegram-notify.sh notification"
          }
        ]
      }
    ]
  }
}
```

If you already have hooks configured, merge the new hooks into your existing configuration.

## Step 5: Test the Setup

```bash
# Send a test notification
echo '{"session_id":"test-123"}' | bash ~/.claude/scripts/telegram-notify.sh test
```

You should receive a test message in Telegram.

## Notification Types

### Task Completed (Stop Hook)
Sent when Claude finishes processing a request.

```
✅ Claude Code Task Completed

Host: my-vps
Project: my-project
Session: abc12345...

Summary:
Created the user authentication system with...

2024-12-30 14:32:15
```

### Permission Required
Sent when Claude needs approval for a tool action.

```
🔐 Claude Code Permission Required

Host: my-vps
Project: my-project

Message:
Claude needs your permission to use Bash

2024-12-30 14:32:15
```

### Input Required (Idle)
Sent when Claude has been waiting for input for 60+ seconds.

```
⏰ Claude Code Input Required

Host: my-vps
Project: my-project

2024-12-30 14:32:15
```

## Configuration File

The configuration is stored at `~/.claude-telegram`:

```bash
# Telegram Bot Configuration for Claude Code
TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN_HERE"
TELEGRAM_CHAT_ID="YOUR_CHAT_ID_HERE"
```

File permissions are set to 600 (owner read/write only) for security.

## Manual Usage

You can also send notifications manually:

```bash
# Test message
echo '{}' | bash ~/.claude/scripts/telegram-notify.sh test

# Custom message
echo '{}' | bash ~/.claude/scripts/telegram-notify.sh custom "Deployment completed!"

# Error message
echo '{"message":"Something went wrong"}' | bash ~/.claude/scripts/telegram-notify.sh error
```

## Troubleshooting

### "Configuration file not found"
Run `./setup-telegram.sh` to create the configuration.

### "Could not automatically detect chat ID"
- Make sure you've sent a message to your bot first
- Try using @userinfobot to get your chat ID manually
- Check the API response manually:
  ```bash
  curl "https://api.telegram.org/botYOUR_TOKEN/getUpdates"
  ```

### Test message not received
1. Verify your bot token is correct
2. Check you have the right chat ID
3. Make sure you've started a conversation with the bot
4. Test the API directly:
   ```bash
   curl -X POST "https://api.telegram.org/botYOUR_TOKEN/sendMessage" \
     -d "chat_id=YOUR_CHAT_ID" \
     -d "text=Test"
   ```

### Hooks not triggering
1. Verify your `~/.claude/settings.json` is valid JSON
2. Check the hook script exists at `~/.claude/scripts/telegram-notify.sh`
3. Make sure the script is executable: `chmod +x ~/.claude/scripts/telegram-notify.sh`
4. Restart Claude Code after changing settings

### Messages have formatting issues
The script uses HTML parsing mode. If you see issues, check for unescaped `<`, `>`, or `&` characters in your project paths or messages.

## Advanced Configuration

### Send to Multiple Recipients

Modify `telegram-hook.sh` to send to multiple chat IDs:

```bash
CHAT_IDS=("123456789" "987654321")

for CHAT_ID in "${CHAT_IDS[@]}"; do
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        -d "text=${MSG}" \
        -d "parse_mode=HTML"
done
```

### Send to Group Chat

1. Add your bot to a group
2. Get the group chat ID (will be negative, e.g., `-123456789`)
3. Update `~/.claude-telegram` with the group chat ID

### Project-Specific Notifications

Use the matcher in hooks to filter by project:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "/important-project/",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/scripts/telegram-notify.sh stop"
          }
        ]
      }
    ]
  }
}
```

### Disable Notifications Temporarily

Comment out or remove the hooks from `~/.claude/settings.json`, or rename the config file:

```bash
mv ~/.claude-telegram ~/.claude-telegram.disabled
```

## Security Considerations

- **Bot token**: Treat like a password. Anyone with it can send messages as your bot.
- **Chat ID**: Less sensitive but still keep private.
- **Config file**: Stored with 600 permissions (owner-only access).
- **Don't commit**: Add `.claude-telegram` to your `.gitignore`.

## Resources

- [Telegram Bot API Documentation](https://core.telegram.org/bots/api)
- [Claude Code Hooks Reference](https://docs.anthropic.com/en/docs/claude-code/hooks)
- [Creating a Telegram Bot with BotFather](https://core.telegram.org/bots#botfather)

## Credits

Based on the Claude Code hooks system and Telegram Bot API. Inspired by the community's notification solutions for long-running AI tasks.

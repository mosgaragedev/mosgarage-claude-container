# Claude Code Push Notifications with ntfy.sh

Get instant push notifications on your phone when Claude Code needs your attention - whether it's waiting for permission, completed a task, or encountered an error.

## Overview

This setup uses [ntfy.sh](https://ntfy.sh), a free, open-source push notification service. Your notifications go through a private topic that only you know, so no account or sign-up is required.

**How it works:**
1. Claude Code hooks trigger when events occur (notifications, stop events)
2. The hook script sends a message to your private ntfy topic
3. Your phone receives the push notification instantly
4. Tap the notification to connect via SSH/Termius

---

## Quick Setup

### 1. Run the Setup Script

```bash
cd /path/to/notifications
./setup-ntfy.sh
```

This will:
- Generate a unique private topic name (e.g., `claude-matt-a1b2c3d4`)
- Send a test notification to verify it works
- Install the hook script to `~/.config/claude-notify/`
- Display your topic URL for phone setup

### 2. Install ntfy App on Your Phone

**iOS:**
- [Download from App Store](https://apps.apple.com/app/ntfy/id1625396347)

**Android:**
- [Download from Google Play](https://play.google.com/store/apps/details?id=io.heckel.ntfy)
- Or [F-Droid](https://f-droid.org/en/packages/io.heckel.ntfy/) if you prefer

### 3. Subscribe to Your Topic

1. Open the ntfy app
2. Tap the **+** button (or "Add subscription")
3. Enter your topic name (shown by setup script, e.g., `claude-matt-a1b2c3d4`)
4. Leave server as `ntfy.sh` (default)
5. Tap **Subscribe**

You should see the test notification that was sent during setup!

### 4. Configure Claude Code Hooks

Add the hooks configuration to your Claude Code settings:

**Edit `~/.claude/settings.json`:**

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": {},
        "hooks": [
          {
            "type": "command",
            "command": "~/.config/claude-notify/notify-hook.sh notification \"$CLAUDE_NOTIFICATION_MESSAGE\""
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": {},
        "hooks": [
          {
            "type": "command",
            "command": "~/.config/claude-notify/notify-hook.sh stop \"$CLAUDE_STOP_REASON\""
          }
        ]
      }
    ]
  }
}
```

If you already have hooks configured, merge the Notification and Stop sections with your existing config.

---

## Notification Types

### Permission Requests (Notification Event)
- **Title:** "Claude Needs Permission"
- **Tags:** robot, warning, loudspeaker
- **Priority:** High
- **When:** Claude is waiting for approval on an action

### Task Completion (Stop Event: end_turn)
- **Title:** "Claude Completed"
- **Tags:** robot, checkmark
- **Priority:** Normal
- **When:** Claude has finished processing and is ready for next input

### Errors (Stop Event: tool_error)
- **Title:** "Claude Error"
- **Tags:** robot, x, warning
- **Priority:** High
- **When:** A tool encountered an error

### Turn Limit (Stop Event: max_turns)
- **Title:** "Claude Hit Turn Limit"
- **Tags:** robot, hourglass
- **Priority:** Normal
- **When:** Maximum conversation turns reached

---

## Connecting via Termius

For the best mobile SSH experience, use [Termius](https://termius.com/):

### Setup Termius
1. Install Termius on your phone (iOS/Android)
2. Add your VPS as a host:
   - Hostname: Your VPS IP or Tailscale hostname
   - Username: matt (or your user)
   - Authentication: SSH key or password
3. Save the host

### Connect from Notification
When you receive a notification:
1. Tap the notification
2. If Termius is configured, it may open directly
3. Otherwise, open Termius manually and connect to your saved host
4. Attach to the tmux session: `tmux attach` or `ta`

### Deep Links (Optional)
Termius supports URL schemes for direct connection:
- `termius://host/your-hostname`

You can customize the `notify-hook.sh` script to include your specific Termius deep link.

---

## Testing

Send a test notification:

```bash
~/.config/claude-notify/notify-hook.sh test "Hello from the command line!"
```

You should receive a notification on your phone within seconds.

---

## Customization

### Change Notification Priorities

Edit `~/.config/claude-notify/notify-hook.sh` and adjust the `PRIORITY` values:
- `1` or `min` - Lowest priority
- `2` or `low` - Low priority
- `3` or `default` - Normal priority
- `4` or `high` - High priority (causes sound/vibration)
- `5` or `max` or `urgent` - Highest priority (bypasses DND on Android)

### Add Custom Actions

The ntfy app supports action buttons. Edit the `ACTIONS` variable in the hook script:

```bash
ACTIONS="view, Open Dashboard, https://your-dashboard.com; http, Restart Service, https://api.example.com/restart"
```

### Change the Topic

If you need a new topic (e.g., topic was discovered):

```bash
rm ~/.config/claude-notify/topic
./setup-ntfy.sh
```

Then update your phone app subscription.

---

## Security Considerations

1. **Topic names are public** - Anyone who knows your topic name can send you notifications
2. **Use hard-to-guess names** - The setup script generates a random suffix
3. **Don't share your topic** - Treat it like a password
4. **No authentication needed** - ntfy.sh works without accounts for simplicity
5. **Self-host option** - For maximum security, run your own ntfy server

If you need to rotate your topic:
```bash
rm ~/.config/claude-notify/topic
./setup-ntfy.sh
```

---

## Troubleshooting

### Notifications not arriving

1. **Check topic subscription:**
   - Open ntfy app → verify you're subscribed to the correct topic

2. **Test manually:**
   ```bash
   curl -d "Test" ntfy.sh/YOUR-TOPIC-NAME
   ```

3. **Check phone settings:**
   - iOS: Settings → Notifications → ntfy → Allow Notifications
   - Android: Settings → Apps → ntfy → Notifications → Enable

4. **Check Do Not Disturb:**
   - DND may block notifications (except priority 5/urgent on Android)

### Hook not triggering

1. **Verify hook script is executable:**
   ```bash
   chmod +x ~/.config/claude-notify/notify-hook.sh
   ```

2. **Check Claude Code settings:**
   ```bash
   cat ~/.claude/settings.json | jq '.hooks'
   ```

3. **Test hook directly:**
   ```bash
   CLAUDE_NOTIFICATION_MESSAGE="Test permission request" \
   ~/.config/claude-notify/notify-hook.sh notification "$CLAUDE_NOTIFICATION_MESSAGE"
   ```

### Wrong topic name

```bash
cat ~/.config/claude-notify/topic
```

Make sure this matches what you subscribed to in the ntfy app.

---

## Files Reference

| File | Location | Purpose |
|------|----------|---------|
| `setup-ntfy.sh` | This directory | Initial setup and topic generation |
| `notify-hook.sh` | `~/.config/claude-notify/` | Hook script called by Claude Code |
| `topic` | `~/.config/claude-notify/` | Stores your private topic name |
| `hooks-config.json` | This directory | Reference config for settings.json |

---

## Advanced: Multiple Machines

If running Claude Code on multiple machines (Mac + VPS), each will:
- Use the same topic (stored in `~/.config/claude-notify/topic`)
- Include hostname in notification for identification
- Work independently

To share the same topic across machines:
```bash
# On second machine
mkdir -p ~/.config/claude-notify
echo "claude-matt-XXXX" > ~/.config/claude-notify/topic
cp notify-hook.sh ~/.config/claude-notify/
chmod +x ~/.config/claude-notify/notify-hook.sh
```

---

## Related Resources

- [ntfy.sh Documentation](https://docs.ntfy.sh/)
- [ntfy.sh GitHub](https://github.com/binwiederhier/ntfy)
- [Claude Code Hooks Documentation](https://docs.anthropic.com/claude-code/hooks)
- [Termius SSH Client](https://termius.com/)

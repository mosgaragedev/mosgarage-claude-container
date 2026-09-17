# Mobile Workflow: ntfy + Termius Integration

A seamless mobile workflow for managing Claude Code on your VPS.

---

## The Flow

```
VPS Task Completes
       |
       v
ntfy Notification sent
       |
       v
Phone receives push notification
       |
       v
You tap the notification
       |
       v
Termius opens and connects to VPS
       |
       v
Auto-attaches to tmux session
       |
       v
You're in Claude - review output or continue
```

---

## Setup Checklist

### Phone Setup
- [ ] Install **ntfy** app (iOS App Store / Google Play)
- [ ] Subscribe to your ntfy topic
- [ ] Install **Termius** app
- [ ] Configure Claude VPS host (see TERMIUS_SETUP.md)
- [ ] Install **Tailscale** app and connect to your tailnet
- [ ] Test SSH connection from phone

### VPS Setup
- [ ] ntfy-with-termius.sh script installed
- [ ] NTFY_TOPIC environment variable set
- [ ] Tailscale running and connected
- [ ] Claude tmux session configured

---

## Quick Setup Commands

### On VPS (as claude user)

```bash
# Set your ntfy topic (add to ~/.bashrc)
echo 'export NTFY_TOPIC="your-secret-topic"' >> ~/.bashrc
source ~/.bashrc

# Test notification
./ntfy-with-termius.sh -t "Test" "Hello from VPS!"
```

### Integrate with claude-task.sh

Add this function to your task completion notifications:

```bash
# Add to claude-task.sh or create separate notifier
notify_mobile() {
    local title="$1"
    local message="$2"
    local priority="${3:-default}"

    # Send ntfy with Termius deep link
    curl -s \
        -H "Title: $title" \
        -H "Priority: $priority" \
        -H "Click: termius://host?label=Claude%20VPS" \
        -H "Tags: computer" \
        -d "$message" \
        "https://ntfy.sh/${NTFY_TOPIC}"
}

# Call after task completion
notify_mobile "Task Complete" "Refactoring finished in ${duration}" "default"
```

---

## Use Cases

### 1. Long-Running Task Monitoring

```bash
# Start a long task on VPS
./claude-task.sh -n "Big Refactor" "Refactor entire auth module"

# Go do something else
# Phone buzzes when complete
# Tap notification -> straight into session
```

### 2. Error Alerts

```bash
# Configure high-priority alert for failures
./ntfy-with-termius.sh -t "Task Failed" -p high -g "x,computer" \
    "Auth refactor failed with exit code 1"
```

### 3. Scheduled Check-ins

```bash
# Add to cron for periodic status updates
0 */4 * * * /home/claude/scripts/ntfy-with-termius.sh \
    -t "Claude Status" \
    "Session active: $(claude-status)"
```

---

## Notification Priority Guide

| Priority | Use Case | Phone Behavior |
|----------|----------|----------------|
| `min` | FYI updates | Silent, badge only |
| `low` | Background tasks done | Quiet notification |
| `default` | Normal task completion | Standard notification |
| `high` | Needs attention soon | Loud, bypasses DND |
| `urgent` | Critical failure | Persistent, loud |

```bash
# Examples
./ntfy-with-termius.sh -p min "Background sync complete"
./ntfy-with-termius.sh -p high "Build failed - review needed"
./ntfy-with-termius.sh -p urgent "Production error detected"
```

---

## Emoji Tags for Quick Visual ID

Use tags to add emojis to notifications:

```bash
# Success
./ntfy-with-termius.sh -g "white_check_mark,computer" "Task succeeded"

# Failure
./ntfy-with-termius.sh -g "x,warning" "Task failed"

# In progress
./ntfy-with-termius.sh -g "hourglass,computer" "Long task started"

# Celebration
./ntfy-with-termius.sh -g "tada,rocket" "Deploy complete!"
```

Common tags: `computer`, `white_check_mark`, `x`, `warning`, `tada`, `rocket`, `hourglass`, `bell`, `hammer_and_wrench`

---

## Troubleshooting

### Notification not received
1. Check ntfy app is open/backgrounded (iOS can kill it)
2. Verify topic subscription matches NTFY_TOPIC
3. Test with: `curl -d "test" ntfy.sh/your-topic`

### Termius doesn't open when tapping
1. Ensure Termius is installed
2. Check deep link format: `termius://host?label=Claude%20VPS`
3. Verify host label matches exactly (case-sensitive)

### Can't connect after opening Termius
1. Check Tailscale is connected on phone
2. Verify VPS is online: `tailscale ping claude-vps`
3. Test SSH key is correctly configured

---

## Security Notes

1. **ntfy topics are public** unless self-hosted
   - Use a random, unguessable topic name
   - Don't include sensitive data in notifications
   - Consider self-hosting ntfy for sensitive use

2. **Termius deep links** expose your host label
   - Not a security risk, just metadata
   - Actual access still requires SSH auth

3. **Keep Tailscale connected**
   - Only Tailscale-connected devices can reach VPS
   - Acts as an additional security layer

---

## Example: Complete Task Script Integration

```bash
#!/usr/bin/env bash
# run-and-notify.sh - Run Claude task with mobile notification

TASK_NAME="${1:-Unnamed Task}"
PROMPT="$2"
START_TIME=$(date +%s)

# Run Claude task
claude "$PROMPT"
EXIT_CODE=$?

# Calculate duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
DURATION_STR="$(($DURATION / 60))m $(($DURATION % 60))s"

# Send notification based on result
if [[ $EXIT_CODE -eq 0 ]]; then
    ./ntfy-with-termius.sh \
        -t "$TASK_NAME Complete" \
        -g "white_check_mark,computer" \
        "Finished in $DURATION_STR"
else
    ./ntfy-with-termius.sh \
        -t "$TASK_NAME Failed" \
        -p high \
        -g "x,warning" \
        "Exit code $EXIT_CODE after $DURATION_STR"
fi
```

---

*Last updated: December 2024*

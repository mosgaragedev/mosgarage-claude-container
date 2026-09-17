# Termius Setup Guide for Claude VPS

Complete guide for accessing your Claude VPS from your phone using Termius - the best SSH client for mobile.

---

## Why Termius?

- **Cross-platform** - iOS, Android, Mac, Windows, Linux
- **Voice-to-text** - Dictate prompts to Claude without typing
- **Snippets** - Quick commands at your fingertips
- **Sync** - Host configs sync across all devices (free tier)
- **Modern UI** - Clean, dark interface perfect for terminal work

---

## Part 1: Install Termius

### iOS
1. Open App Store
2. Search "Termius"
3. Install **Termius - Terminal & SSH** (by Termius Corporation)
4. Free tier is sufficient for single host + snippets

### Android
1. Open Google Play Store
2. Search "Termius"
3. Install **Termius - SSH/Mosh and Telnet**
4. Free tier is sufficient

---

## Part 2: Add Your VPS Host

### Step 1: Open Termius and Create New Host

1. Tap **Hosts** (bottom nav)
2. Tap **+** button (top right)
3. Select **New Host**

### Step 2: Configure Host Settings

| Field | Value |
|-------|-------|
| **Label** | Claude VPS |
| **Address** | `claude-vps` (Tailscale MagicDNS) |
| **Port** | 22 |
| **Username** | `claude` (or `root`) |
| **Password** | Leave blank (use SSH key) |

> **Alternative addresses:**
> - Tailscale IP: `100.x.x.x` (find via `tailscale ip` on Mac)
> - Full MagicDNS: `claude-vps.your-tailnet.ts.net`

### Step 3: Set Up SSH Key Authentication

**Option A: Generate Key in Termius**
1. Tap the key icon next to Password field
2. Tap **New Key**
3. Enter label: "Claude VPS Key"
4. Tap **Generate** (Ed25519 recommended)
5. Tap **Export to Host** (copies public key to clipboard)
6. SSH to VPS from Mac and add the key:
   ```bash
   ssh claude@claude-vps
   echo "PASTE_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys
   ```

**Option B: Import Existing Key**
1. If you have a key on your Mac, copy the private key to Termius
2. In Termius: **Settings > Keychain > +**
3. Paste or import your private key
4. Assign it to the Claude VPS host

### Step 4: Set Startup Command (Optional but Recommended)

1. In the host settings, scroll to **Startup Snippet**
2. Create a new snippet with:
   - **Label:** Attach Claude Session
   - **Content:** `claude-attach`
3. Assign this snippet as the startup command

Now when you connect, it automatically attaches to the tmux session.

---

## Part 3: Configure Keyboard for Coding

### iOS Keyboard Optimization

1. **Settings > Keyboard Settings** (in Termius)
2. Enable these options:
   - **Hide Toolbar** - OFF (keep the extra keys visible!)
   - **Cursor Keys** - Show in toolbar
   - **Function Keys** - Show F1-F12
   - **Modifier Keys** - Ctrl, Alt, Esc visible

3. **Extra Keys Row** (the game changer):
   - Tap and hold keys to customize
   - Recommended layout: `Tab | Ctrl | Esc | - | | | [ | ] | Up | Down`

### Android Keyboard Tips

1. In Termius settings, enable **Hardware keyboard mode** if using Bluetooth keyboard
2. Enable **Extra keys row** in terminal settings
3. Consider installing **Hacker's Keyboard** from Play Store for full key access

---

## Part 4: Voice-to-Text for Claude Prompts

Termius supports voice input - perfect for long Claude prompts on mobile!

### How to Use

1. Connect to your VPS
2. Start Claude: type `claude` and press Enter
3. When ready to type a prompt:
   - iOS: Tap microphone on keyboard
   - Android: Tap microphone on Gboard/keyboard
4. Dictate your prompt naturally
5. Edit if needed, then press Enter

### Voice Tips

- Say "new line" for line breaks
- Say "open quote" / "close quote" for quotation marks
- Pause briefly at the end to stop dictation
- Review before sending - voice-to-text isn't perfect

---

## Part 5: Quick Command Snippets

Pre-configure common commands for one-tap access.

### Create Snippets

1. **Settings > Snippets > +**
2. Create these essential snippets:

| Label | Command | Description |
|-------|---------|-------------|
| Attach | `claude-attach` | Attach to tmux session |
| Start Claude | `claude-start` | Start Claude in tmux |
| New Claude | `claude` | Start fresh Claude session |
| Status | `claude-status` | Check session status |
| Restart | `claude-restart` | Restart Claude session |
| Logs | `claude-logs` | View service logs |
| Detach | `Ctrl+a d` | Detach from tmux (key sequence) |
| Clear | `clear` | Clear terminal |

### Using Snippets

1. While connected, tap the **bolt icon** (snippets)
2. Tap any snippet to execute
3. For key sequences (like Ctrl+a d), Termius sends them correctly

---

## Part 6: Using tmux from Phone

tmux is your friend for persistent sessions. Here's how to work with it on mobile:

### Essential tmux Commands

| Action | Keys | Mobile Tip |
|--------|------|------------|
| Detach | `Ctrl+a d` | Use snippet or extra keys row |
| Split horizontal | `Ctrl+a |` | Pipe symbol on extra row |
| Split vertical | `Ctrl+a -` | Minus on extra row |
| Switch pane | `Ctrl+a h/j/k/l` | Vim-style navigation |
| Scroll up | `Ctrl+a [` | Enter copy mode, then swipe |
| Exit copy mode | `q` | Return to normal mode |
| New window | `Ctrl+a c` | Creates new tab |
| Next window | `Ctrl+a n` | Cycle through windows |
| Kill pane | `Ctrl+a x` | Close current pane |

### Mobile-Friendly Workflow

1. **Always detach, never close** - Tap `Ctrl+a d` before closing app
2. **One main window** - Avoid complex splits on small screens
3. **Use snippets** - Pre-configure common commands
4. **Portrait mode** - Better for reading output
5. **Pinch to zoom** - Termius supports zoom gestures

---

## Part 7: Termius Deep Links

Open Termius directly to your VPS from notifications.

### Deep Link Format

```
termius://host?address=claude-vps
```

Or by host label:
```
termius://host?label=Claude%20VPS
```

### Using with ntfy Notifications

When sending notifications from your VPS, include a click action:

```bash
# Example ntfy notification with Termius deep link
curl -d "Claude task completed!" \
  -H "Click: termius://host?label=Claude%20VPS" \
  -H "Title: VPS Alert" \
  ntfy.sh/your-topic
```

### Integration with claude-task.sh

To add Termius deep links to task completion notifications, use the click URL feature of your notification service.

---

## Part 8: ntfy Integration with Termius Links

Modify notifications to open Termius when tapped.

### Update Notification Script

Add this to your notification function in `claude-task.sh` or create a dedicated notifier:

```bash
send_ntfy_notification() {
    local title="$1"
    local message="$2"
    local priority="${3:-default}"

    curl -s \
        -H "Title: $title" \
        -H "Priority: $priority" \
        -H "Click: termius://host?label=Claude%20VPS" \
        -H "Tags: computer" \
        -d "$message" \
        "https://ntfy.sh/your-topic"
}
```

### Result

When you tap the notification on your phone:
1. Termius opens
2. Connects directly to Claude VPS
3. (With startup snippet) Attaches to tmux session
4. You're instantly in your Claude session!

---

## Troubleshooting

### Can't Connect

1. **Check Tailscale is running** on both phone and VPS
   - iOS: Open Tailscale app, ensure connected
   - VPS: `sudo tailscale status`

2. **Verify address**
   - Try Tailscale IP instead of hostname
   - Check `tailscale ip` on Mac for VPS IP

3. **SSH key issues**
   - Re-export public key and add to VPS
   - Check permissions: `chmod 600 ~/.ssh/authorized_keys`

### Keyboard Issues

1. **Missing keys** - Enable extra keys row in settings
2. **Ctrl not working** - Check keyboard layout, try long-press
3. **Escape key** - Add to extra keys row or use `Ctrl+[`

### Session Disconnects

1. **Enable Mosh** for better mobile connections:
   ```bash
   # On VPS
   sudo apt install mosh
   sudo ufw allow 60000:61000/udp
   ```
2. In Termius, enable **Mosh** in host settings

### Voice Input Not Working

1. Ensure microphone permissions granted to keyboard
2. Check internet connection (voice processing requires network)
3. Try switching keyboards (some work better than others)

---

## Best Practices

1. **Keep sessions short** - Mobile battery drains with active SSH
2. **Detach properly** - Always `Ctrl+a d` before closing
3. **Use snippets** - Faster than typing on mobile
4. **Charge while coding** - Terminal work is CPU-intensive
5. **WiFi preferred** - More stable than cellular
6. **Portrait for reading, landscape for typing** - Adjust as needed
7. **Set up now, use later** - Configure everything before you need it

---

## Quick Reference Card

### Connecting
```
1. Open Termius
2. Tap "Claude VPS" host
3. (Auto-attaches to tmux via startup snippet)
```

### Working in Claude
```
- Type prompt or use voice
- Wait for response
- Detach with Ctrl+a d when done
```

### Emergency Recovery
```
1. Connect to VPS
2. Run: claude-restart
3. Run: claude-attach
```

---

## Configuration Export

See `termius-config.json` in this directory for an exportable host configuration template.

---

*Last updated: December 2024*

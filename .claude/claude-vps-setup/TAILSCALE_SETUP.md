# Tailscale Setup Guide for Claude VPS

This guide covers setting up Tailscale for secure, easy access between your Mac and your VPS.

## What is Tailscale?

Tailscale creates a private mesh network (called a "tailnet") between your devices. Benefits:

- **No port forwarding** - Works through NAT and firewalls
- **MagicDNS** - Access devices by hostname (e.g., `ssh claude-vps`)
- **Tailscale SSH** - No SSH keys to manage; authentication via Tailscale
- **Encrypted** - WireGuard-based encryption
- **Free tier** - Up to 100 devices for personal use

---

## Part 1: VPS Setup

### Option A: Automated Script

```bash
# SSH into your VPS first
ssh root@your-vps-ip

# Download and run the setup script
curl -fsSL https://raw.githubusercontent.com/matthillway/claude-vps-setup/main/setup-tailscale.sh -o setup-tailscale.sh
chmod +x setup-tailscale.sh
sudo ./setup-tailscale.sh
```

### Option B: Manual Installation

```bash
# 1. Add Tailscale repository (Ubuntu/Debian)
curl -fsSL https://tailscale.com/install.sh | sh

# 2. Start and enable the service
sudo systemctl enable --now tailscaled

# 3. Authenticate (opens a URL to authorize)
sudo tailscale up --ssh

# 4. Set a friendly hostname
sudo hostnamectl set-hostname claude-vps
sudo systemctl restart tailscaled
sudo tailscale up --ssh
```

---

## Part 2: Mac Setup

### Step 1: Install Tailscale

**Option A: Homebrew (Recommended)**
```bash
brew install --cask tailscale
```

**Option B: Direct Download**
- Visit: https://tailscale.com/download/mac
- Download and install the app

### Step 2: Sign In

1. Open Tailscale from Applications
2. Click the Tailscale icon in the menu bar
3. Click "Log in"
4. Sign in with the **same account** you used on the VPS

### Step 3: Verify Connection

```bash
# Check Tailscale status
tailscale status

# You should see your VPS listed, e.g.:
# 100.x.x.x    claude-vps    matt@     linux   -
```

---

## Part 3: Enable MagicDNS

MagicDNS lets you use hostnames like `claude-vps` instead of IP addresses.

### Step 1: Open Admin Console

Visit: https://login.tailscale.com/admin/dns

### Step 2: Enable MagicDNS

1. Scroll to "MagicDNS"
2. Toggle it **ON**

### Step 3: Set Tailnet Name (Optional)

By default, your tailnet has a random name like `tail1234.ts.net`. You can:

1. Go to https://login.tailscale.com/admin/settings
2. Under "General", find "Tailnet name"
3. Click to rename (e.g., `hillway` becomes `hillway.ts.net`)

### Result

After enabling MagicDNS, you can connect using:

| Method | Command |
|--------|---------|
| Full MagicDNS | `ssh claude-vps.tailnet-name.ts.net` |
| Short name | `ssh claude-vps` |
| Tailscale IP | `ssh 100.x.x.x` |

---

## Part 4: Using Tailscale SSH

With `--ssh` enabled on the VPS, you get passwordless SSH without managing keys.

### How It Works

1. Tailscale authenticates you via your Tailscale account
2. No SSH keys needed on your Mac
3. Access is controlled via Tailscale ACLs

### Connecting

```bash
# Regular SSH (uses Tailscale network, still needs keys/password)
ssh user@claude-vps

# Tailscale SSH (no keys needed, uses Tailscale auth)
tailscale ssh claude-vps

# Or with username
tailscale ssh user@claude-vps
```

### Configure ACLs (Optional)

For more control, edit ACLs at: https://login.tailscale.com/admin/acls

Example allowing SSH from your Mac:
```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["matt@"],
      "dst": ["tag:server:*"]
    }
  ],
  "tagOwners": {
    "tag:server": ["matt@"]
  },
  "ssh": [
    {
      "action": "accept",
      "src": ["matt@"],
      "dst": ["tag:server"],
      "users": ["root", "autogroup:nonroot"]
    }
  ]
}
```

---

## Part 5: SSH Config for Convenience

Add this to your `~/.ssh/config` on Mac:

```ssh-config
# Claude VPS via Tailscale
Host claude-vps
    HostName claude-vps
    User root
    # Or use Tailscale SSH:
    # ProxyCommand tailscale nc %h %p
```

Now just run:
```bash
ssh claude-vps
```

---

## Troubleshooting

### VPS Not Appearing in `tailscale status`

```bash
# On VPS, check service is running
sudo systemctl status tailscaled

# Check if authenticated
sudo tailscale status

# Re-authenticate if needed
sudo tailscale up --ssh --reset
```

### MagicDNS Not Resolving

```bash
# Check DNS settings
tailscale status --json | jq '.Self.DNSName'

# Verify MagicDNS is enabled in admin console
# Try flushing DNS on Mac
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

### Connection Timeouts

```bash
# Test connectivity
tailscale ping claude-vps

# Check firewall on VPS
sudo ufw status

# Tailscale should bypass firewall, but check anyway
sudo ufw allow in on tailscale0
```

### SSH Permission Denied

```bash
# If using Tailscale SSH, ensure --ssh flag was set
sudo tailscale up --ssh

# Check SSH is enabled in ACLs
# Visit: https://login.tailscale.com/admin/acls
```

---

## Quick Reference

### Useful Commands (Mac)

| Command | Description |
|---------|-------------|
| `tailscale status` | Show all connected devices |
| `tailscale ping <host>` | Test connectivity to device |
| `tailscale ssh <host>` | SSH via Tailscale auth |
| `tailscale ip <host>` | Get Tailscale IP of device |
| `tailscale logout` | Disconnect from tailnet |
| `tailscale up` | Connect to tailnet |

### Useful Commands (VPS)

| Command | Description |
|---------|-------------|
| `sudo tailscale status` | Show connection status |
| `sudo tailscale up --ssh` | Enable Tailscale with SSH |
| `sudo tailscale down` | Disconnect |
| `sudo tailscale logout` | Remove from tailnet |
| `tailscale ip -4` | Show IPv4 address |

### Admin URLs

| Purpose | URL |
|---------|-----|
| Devices | https://login.tailscale.com/admin/machines |
| DNS/MagicDNS | https://login.tailscale.com/admin/dns |
| ACLs | https://login.tailscale.com/admin/acls |
| Settings | https://login.tailscale.com/admin/settings |

---

## Security Notes

1. **Tailscale SSH access** is controlled by your Tailscale account - keep it secure
2. **ACLs** let you restrict which devices can access the VPS
3. **Key expiry** - By default, keys expire. Disable in admin if needed for servers
4. **Device approval** - Enable in settings to require manual approval of new devices

---

## Next Steps

1. Run the setup script on your VPS
2. Install Tailscale on your Mac
3. Enable MagicDNS in the admin console
4. Test with `ssh claude-vps`
5. (Optional) Configure ACLs for additional security

---

*Last updated: December 2024*

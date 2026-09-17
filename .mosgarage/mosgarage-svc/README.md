# mosgarage-svc — the platform's service account

A single, cross-platform identity that owns and runs the mosgarage control
plane (`Mosgarage.Server`, `Mosgarage.Agent`, `mosgaraged`, Traefik) —
instead of any of that running as your interactive user, `mo`, or root/
Administrator. Two scripts, same account model:

| File | Use it when |
|---|---|
| `setup-mosgarage-service-account.sh` | Bootstrapping a fresh Linux box (e.g. a new OCI VPS) before pwsh + your `mosgarage-dotfiles` profile are deployed. Pure bash, no dependencies. |
| `New-MosgarageServiceAccount.ps1` | Ongoing management on **either** Windows or Linux, once pwsh 7 is your standard tool (which it already is across Windows/WSL2/OCI per your roaming profile). Same flags, same account model, detects the OS via `$IsWindows`/`$IsLinux` and adapts. |

Both are idempotent — safe to re-run after a config change.

## Design principles

**"Powerful" ≠ "Administrator/root."** A control-plane account that
provisions Docker containers, opens an SSH listener, and manages a reverse
proxy is high-value if compromised, so it gets exactly the access it needs
and nothing else:

- **No interactive login.** Linux: shell is `/usr/sbin/nologin`. Windows:
  explicitly denied `SeInteractiveLogonRight` and `SeRemoteInteractiveLogonRight`
  (can't log in locally or over RDP). It only runs as a service/daemon.
- **Docker access via group membership, not sudo/root.** `docker` group on
  Linux, `docker-users` on Windows (if present). This is how `Docker.DotNet`
  in `Mosgarage.Agent` talks to the daemon socket without the account being
  root.
- **Scoped sudo, not blanket sudo.** The Linux sudoers entry only allows
  `systemctl restart|status` on the mosgarage/traefik units — never a shell,
  never arbitrary root commands.
- **No unnecessary privileged-port capability.** Your documented ports
  (`8080/3000/4000/7072/2222`) are all >1024, and since Traefik runs in
  Docker Compose, the *Docker daemon* (root) does the 80/443 bind, not this
  account. The scripts include an **optional** `CAP_NET_BIND_SERVICE` grant
  on the agent binary for the day you might run something outside Docker
  that needs a low port — it's a no-op until you pass `-BinaryPath`.
- **Credentials never hit stdout.** On Windows the generated password is
  written once to a DPAPI-encrypted (machine-bound) XML via `Export-Clixml`,
  ACL'd to `SYSTEM`/`Administrators` only, and mirrored into Windows
  Credential Manager (`cmdkey`) so a service can retrieve it without you
  re-typing it. It's never echoed to the console or a transcript.

## Usage

### Linux — first boot on a new box (bash, no pwsh needed yet)

```bash
sudo ./setup-mosgarage-service-account.sh --install-service \
  --bin /opt/mosgarage/bin/Mosgarage.Agent
```

### Linux — ongoing, via pwsh (once your dotfiles/profile are deployed)

```bash
sudo pwsh ./New-MosgarageServiceAccount.ps1 -InstallService \
  -BinaryPath /opt/mosgarage/bin/Mosgarage.Agent
```

### Windows — elevated pwsh

```powershell
./New-MosgarageServiceAccount.ps1 -InstallService `
  -BinaryPath 'C:\mosgarage\bin\Mosgarage.Agent.exe'
```

### WSL2 note

Both scripts detect WSL2 (`/proc/version` contains "microsoft") and skip the
systemd unit automatically, since systemd may not be enabled. The account,
directories, docker-group membership, and sudoers entry are still created —
you'd just start the agent manually or via your `dev-connect.ps1` flow until
you flip `systemd=true` in `/etc/wsl.conf`.

### Removing it

```bash
sudo ./setup-mosgarage-service-account.sh --uninstall
# or
sudo pwsh ./New-MosgarageServiceAccount.ps1 -Uninstall
```

```powershell
./New-MosgarageServiceAccount.ps1 -Uninstall   # Windows, elevated
```

Data under the data root (`/opt/mosgarage` or `C:\ProgramData\mosgarage`) is
left in place on uninstall — delete it manually if you also want the
workspace/logs history gone.

## What gets created

```
/opt/mosgarage/                 C:\ProgramData\mosgarage\
├── bin/                        ├── bin\
├── data/                       ├── data\
├── logs/                       ├── logs\
├── workspaces/                 ├── workspaces\
└── certs/                      └── certs\   (Windows: also holds the
                                              DPAPI-encrypted credential)
```

Plus, on Linux: `/etc/sudoers.d/mosgarage-svc`, and (unless under WSL2 or
`-InstallService` is omitted) `/etc/systemd/system/mosgarage-agent.service`
with hardening (`NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome`,
`ReadWritePaths` scoped to the data root, `PrivateTmp`).

On Windows: a `MosgarageAgent` Windows Service (Automatic startup) if you
pass `-InstallService -BinaryPath`.

## Before you run this against production

- Test on a non-prod box or VM first — the Windows path edits local
  security policy (`secedit`) to grant/deny logon rights, which is a normal,
  supported operation but not something you want to typo on a live host.
- If `mosgarage` ever becomes a multi-host/AD-joined setup on Windows, swap
  the local user for a **group Managed Service Account (gMSA)** — the
  account-creation function is isolated (`Install-WindowsServiceAccount`)
  so that swap is contained to one place.
- Rename the account via `-AccountName` if you'd rather it match your
  `mosgarage` Docker Hub/GHCR namespace convention instead of the
  `mosgarage-svc` default — just keep it distinct from your WSL login (`mo`)
  and any human accounts.

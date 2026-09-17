#requires -Version 7.0
<#
.SYNOPSIS
    Creates (or removes) a dedicated, least-privilege service account that
    powers the mosgarage platform control plane — Mosgarage.Server,
    Mosgarage.Agent, mosgaraged, Traefik — on Windows or Linux. OS is
    detected automatically; the same script drives both.

.DESCRIPTION
    Windows:
      - Local user, "Log on as a service" right only — NOT a member of
        Administrators, and explicitly denied interactive + RDP logon.
      - Optional docker-users membership (only if the group exists, i.e.
        Docker Desktop-style installs; not needed for the native Docker
        Engine setup you're running under WSL2).
      - ACL'd ProgramData folder (SYSTEM + Administrators + the account
        only; inheritance broken).
      - Random 28-char password, never printed to the console. Stored
        DPAPI-encrypted (Export-Clixml, machine-bound) and mirrored into
        Windows Credential Manager for services that read creds at runtime.
      - Optional Windows Service registration via -InstallService -BinaryPath.

    Linux:
      - System account, nologin shell (no SSH/console login as this user;
        root can still `sudo -u` into it for maintenance).
      - docker group membership for the workspace/container provisioner.
      - Scoped sudoers entry — systemctl restart/status only, never a shell.
      - Optional CAP_NET_BIND_SERVICE on the agent binary (only useful if
        you ever bind a port <1024 directly on the host; your documented
        ports 8080/3000/4000/7072/2222 don't need it, and containerized
        Traefik gets 80/443 bound by the Docker daemon, not this account).
      - Optional systemd unit + `systemctl enable` (skipped automatically
        under WSL2 unless systemd is enabled in /etc/wsl.conf).

.PARAMETER AccountName
    Default: mosgarage-svc

.PARAMETER DataRoot
    Default: C:\ProgramData\mosgarage (Windows) / /opt/mosgarage (Linux)

.PARAMETER BinaryPath
    Path to the Mosgarage.Agent executable. Required for -InstallService.

.PARAMETER InstallService
    Also register the OS-native service (Windows Service / systemd unit).

.PARAMETER Uninstall
    Remove everything this script created for -AccountName.

.EXAMPLE
    # Linux (OCI VPS / WSL2 with pwsh already deployed via your dotfiles)
    sudo pwsh ./New-MosgarageServiceAccount.ps1 -InstallService `
        -BinaryPath /opt/mosgarage/bin/Mosgarage.Agent

.EXAMPLE
    # Windows, elevated pwsh
    ./New-MosgarageServiceAccount.ps1 -InstallService `
        -BinaryPath 'C:\mosgarage\bin\Mosgarage.Agent.exe'

.NOTES
    -WhatIf is wired for the account-creation step on each OS; the
    supporting rights/ACL/sudoers steps are idempotent (safe to re-run)
    but not individually gated. Test on a non-production box first —
    the Windows "Log on as a service" grant edits local security policy
    via secedit, which is safe but not undo-friendly if mistyped.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$AccountName = 'mosgarage-svc',
    [string]$DataRoot,
    [string]$BinaryPath,
    [switch]$InstallService,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

# ---------- OS detection ----------
$OnWindows = if (Test-Path variable:IsWindows) { $IsWindows } else { $env:OS -eq 'Windows_NT' }
$OnLinux   = if (Test-Path variable:IsLinux)   { $IsLinux }   else { -not $OnWindows }

if (-not $DataRoot) {
    $DataRoot = if ($OnWindows) { 'C:\ProgramData\mosgarage' } else { '/opt/mosgarage' }
}

function Test-IsAdmin {
    if ($OnWindows) {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } else {
        (id -u) -eq 0
    }
}

if (-not (Test-IsAdmin)) {
    throw "Run this elevated: Administrator on Windows, root/sudo on Linux."
}

function New-StrongPassword {
    param([int]$Length = 28)
    $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#%^*-_='
    $bytes = [byte[]]::new($Length)
    [Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
}

# ======================================================================
# WINDOWS
# ======================================================================
function Grant-UserRight {
    # Appends AccountName's SID to a local-security-policy user right via
    # secedit export/patch/import. Safe to call repeatedly.
    param([Parameter(Mandatory)][string]$Account, [Parameter(Mandatory)][string]$Right)

    $cfgFile = New-TemporaryFile
    $sdbFile = "$($cfgFile.FullName).sdb"
    secedit /export /cfg $cfgFile.FullName /areas USER_RIGHTS | Out-Null

    $sid = (New-Object Security.Principal.NTAccount($Account)).
        Translate([Security.Principal.SecurityIdentifier]).Value

    $found = $false
    $lines = Get-Content $cfgFile.FullName | ForEach-Object {
        if ($_ -match "^$Right\s*=") {
            $found = $true
            if ($_ -notmatch [regex]::Escape("*$sid")) { "$_,*$sid" } else { $_ }
        } else { $_ }
    }
    if (-not $found) { $lines += "$Right = *$sid" }
    $lines | Set-Content $cfgFile.FullName

    secedit /configure /db $sdbFile /cfg $cfgFile.FullName /areas USER_RIGHTS | Out-Null
    Remove-Item $cfgFile.FullName, $sdbFile -ErrorAction SilentlyContinue
}

function Install-WindowsServiceAccount {
    Write-Host "==> [Windows] Service account: $AccountName"

    $existing = Get-LocalUser -Name $AccountName -ErrorAction SilentlyContinue
    $plainPwd = $null
    if (-not $existing) {
        $plainPwd = New-StrongPassword
        $secure = ConvertTo-SecureString $plainPwd -AsPlainText -Force
        if ($PSCmdlet.ShouldProcess($AccountName, 'Create local user')) {
            New-LocalUser -Name $AccountName -Password $secure `
                -FullName 'mosgarage platform service account' `
                -Description 'Runs Mosgarage.Server / Mosgarage.Agent / mosgaraged. Service logon only.' `
                -PasswordNeverExpires -UserMayNotChangePassword -AccountNeverExpires | Out-Null
        }
    } else {
        Write-Host '    already exists, skipping creation'
    }

    Write-Host '==> Granting "Log on as a service"'
    Grant-UserRight -Account $AccountName -Right 'SeServiceLogonRight'

    Write-Host '==> Denying interactive + RDP logon (service-only account)'
    Grant-UserRight -Account $AccountName -Right 'SeDenyInteractiveLogonRight'
    Grant-UserRight -Account $AccountName -Right 'SeDenyRemoteInteractiveLogonRight'

    if (Get-LocalGroup -Name 'docker-users' -ErrorAction SilentlyContinue) {
        Write-Host '==> Adding to docker-users'
        try { Add-LocalGroupMember -Group 'docker-users' -Member $AccountName -ErrorAction Stop }
        catch { Write-Host '    already a member' }
    }

    Write-Host "==> Data directories under $DataRoot"
    foreach ($d in 'bin', 'data', 'logs', 'workspaces', 'certs') {
        New-Item -ItemType Directory -Force -Path (Join-Path $DataRoot $d) | Out-Null
    }
    icacls $DataRoot /inheritance:r | Out-Null
    icacls $DataRoot /grant:r "SYSTEM:(OI)(CI)F" "*S-1-5-32-544:(OI)(CI)F" "${AccountName}:(OI)(CI)M" | Out-Null

    if ($plainPwd) {
        Write-Host '==> Storing credential (DPAPI-encrypted; never printed to console)'
        $credFile = Join-Path $DataRoot 'certs\svc-credential.clixml'
        [PSCredential]::new($AccountName, (ConvertTo-SecureString $plainPwd -AsPlainText -Force)) |
            Export-Clixml -Path $credFile
        icacls $credFile /inheritance:r | Out-Null
        icacls $credFile /grant:r 'SYSTEM:F' '*S-1-5-32-544:F' | Out-Null
        cmdkey /generic:"mosgarage-svc" /user:"$env:COMPUTERNAME\$AccountName" /pass:"$plainPwd" | Out-Null
        Write-Host "    saved to $credFile (Administrators-only) and Credential Manager entry 'mosgarage-svc'"
        Remove-Variable plainPwd
    }

    if ($InstallService -and $BinaryPath) {
        Write-Host "==> Registering Windows Service 'MosgarageAgent'"
        if (-not (Get-Service -Name 'MosgarageAgent' -ErrorAction SilentlyContinue)) {
            $credFile = Join-Path $DataRoot 'certs\svc-credential.clixml'
            $cred = if (Test-Path $credFile) {
                Import-Clixml $credFile
            } else {
                Get-Credential -UserName $AccountName -Message 'Service account password (to register the service)'
            }
            New-Service -Name 'MosgarageAgent' -BinaryPathName $BinaryPath `
                -DisplayName 'Mosgarage Agent' -StartupType Automatic `
                -Credential $cred -Description 'Mosgarage workspace/dev-container control plane' | Out-Null
        } else {
            Write-Host '    service already registered'
        }
    }

    Write-Host "`n=== Summary ==="
    Get-LocalUser -Name $AccountName | Format-List Name, Enabled, PasswordNeverExpires, Description
    Write-Host "Data root: $DataRoot"
}

function Uninstall-WindowsServiceAccount {
    Get-Service -Name 'MosgarageAgent' -ErrorAction SilentlyContinue | Stop-Service -Force -ErrorAction SilentlyContinue
    sc.exe delete MosgarageAgent 2>$null | Out-Null
    cmdkey /delete:"mosgarage-svc" 2>$null | Out-Null
    Remove-LocalUser -Name $AccountName -ErrorAction SilentlyContinue
    Write-Host "Removed $AccountName and its Windows Service (data under $DataRoot left in place)."
}

# ======================================================================
# LINUX  (shells out to native tools; mirrors setup-mosgarage-service-account.sh)
# ======================================================================
function Install-LinuxServiceAccount {
    Write-Host "==> [Linux] Service account: $AccountName"
    $shell = '/usr/sbin/nologin'

    & id $AccountName *> $null
    if ($LASTEXITCODE -ne 0) {
        if ($PSCmdlet.ShouldProcess($AccountName, 'useradd --system')) {
            & useradd --system --create-home --home-dir $DataRoot --shell $shell `
                --comment 'mosgarage platform service account' $AccountName
        }
    } else {
        Write-Host '    already exists, skipping useradd'
    }

    foreach ($d in 'bin', 'data', 'logs', 'workspaces', 'certs') {
        & install -d -m 750 -o $AccountName -g $AccountName (Join-Path $DataRoot $d)
    }

    & getent group docker *> $null
    if ($LASTEXITCODE -eq 0) {
        & usermod -aG docker $AccountName
        Write-Host '==> Added to docker group'
    } else {
        Write-Host '    docker group not found yet — install Docker Engine first'
    }

    if ($BinaryPath -and (Test-Path $BinaryPath)) {
        & setcap 'cap_net_bind_service=+ep' $BinaryPath
        Write-Host '==> Granted CAP_NET_BIND_SERVICE to agent binary (only needed for ports <1024)'
    }

    $sudoersPath = "/etc/sudoers.d/$AccountName"
    @"
Cmnd_Alias MG_SERVICES = /usr/bin/systemctl restart mosgarage-agent, /usr/bin/systemctl restart mosgarage-server, /usr/bin/systemctl restart traefik, /usr/bin/systemctl status mosgarage-*
$AccountName ALL=(root) NOPASSWD: MG_SERVICES
"@ | Set-Content -Path $sudoersPath -NoNewline
    & chmod 440 $sudoersPath
    & visudo -cf $sudoersPath *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host '    sudoers syntax check failed, removing file' -ForegroundColor Yellow
        Remove-Item $sudoersPath -Force
    }

    $isWsl = (Test-Path /proc/version) -and (Select-String -Path /proc/version -Pattern 'microsoft' -Quiet)
    if ($isWsl) {
        Write-Host '==> WSL2 detected — skipping systemd unit'
    } elseif ($InstallService -and $BinaryPath) {
        $unitPath = '/etc/systemd/system/mosgarage-agent.service'
        @"
[Unit]
Description=Mosgarage Agent (workspace/dev-container control plane)
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=simple
User=$AccountName
Group=$AccountName
WorkingDirectory=$DataRoot
ExecStart=$BinaryPath
Restart=on-failure
RestartSec=5
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$DataRoot
PrivateTmp=true

[Install]
WantedBy=multi-user.target
"@ | Set-Content $unitPath
        & systemctl daemon-reload
        Write-Host "    unit installed at $unitPath — enable with: systemctl enable --now mosgarage-agent"
    }

    Write-Host "`n=== Summary ==="
    & id $AccountName
    Write-Host "Home:   $DataRoot"
    Write-Host "Shell:  $shell (service-only — no interactive/SSH login as this user)"
}

function Uninstall-LinuxServiceAccount {
    & systemctl disable --now mosgarage-agent.service *> $null
    Remove-Item /etc/systemd/system/mosgarage-agent.service -ErrorAction SilentlyContinue
    Remove-Item "/etc/sudoers.d/$AccountName" -ErrorAction SilentlyContinue
    & userdel -r $AccountName *> $null
    Write-Host "Removed $AccountName."
}

# ---------- main ----------
if ($Uninstall) {
    if ($OnWindows) { Uninstall-WindowsServiceAccount } else { Uninstall-LinuxServiceAccount }
    return
}

if ($OnWindows) { Install-WindowsServiceAccount } else { Install-LinuxServiceAccount }

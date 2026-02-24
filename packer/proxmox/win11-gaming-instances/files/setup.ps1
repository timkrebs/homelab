#Requires -RunAsAdministrator
<#
  .SYNOPSIS
    Post-installation provisioner for Windows 11 gaming templates on Proxmox.
    Runs via Packer's WinRM communicator after Windows Setup completes.

  .DESCRIPTION
    1. Locate the VirtIO drivers CD
    2. Install QEMU guest agent
    3. Install VirtIO drivers (network, balloon) for future virtio NIC support
    4. Enable RDP
    5. Set High Performance power plan
    6. Clean up Windows temp files
    NOTE: Sysprep shutdown is triggered by Packer's shutdown_command, not this script.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------
function Write-Step { param([string]$Message)  Write-Host "`n==> $Message" -ForegroundColor Cyan }
function Write-OK   { param([string]$Message)  Write-Host "    OK: $Message" -ForegroundColor Green }
function Write-Skip { param([string]$Message)  Write-Host "    SKIP: $Message" -ForegroundColor Yellow }

# ---------------------------------------------------------------------------
# 1. Find VirtIO CD drive
# ---------------------------------------------------------------------------
Write-Step "Locating VirtIO drivers CD"

$VirtioDrive = $null

# Try by volume label first (virtio-win ISO is labelled "virtio-win-*")
foreach ($vol in (Get-Volume | Where-Object { $_.DriveType -eq 'CD-ROM' -or $_.DriveType -eq 'Removable' })) {
    if ($vol.FileSystemLabel -match 'virtio') {
        $VirtioDrive = $vol.DriveLetter
        break
    }
}

# Fall back: scan all drives for the viostor folder
if (-not $VirtioDrive) {
    foreach ($drive in (Get-PSDrive -PSProvider FileSystem)) {
        if (Test-Path "$($drive.Name):\viostor") {
            $VirtioDrive = $drive.Name
            break
        }
    }
}

if ($VirtioDrive) {
    Write-OK "VirtIO CD found at ${VirtioDrive}:"
} else {
    Write-Skip "VirtIO CD not found — skipping guest tools and driver installation"
}

# ---------------------------------------------------------------------------
# 2. Install QEMU guest agent
# ---------------------------------------------------------------------------
Write-Step "Installing QEMU guest agent"

if ($VirtioDrive) {
    $GuestAgentMsi = "${VirtioDrive}:\guest-agent\qemu-ga-x86_64.msi"
    if (Test-Path $GuestAgentMsi) {
        $proc = Start-Process msiexec.exe -ArgumentList "/i `"$GuestAgentMsi`" /qn /norestart" -Wait -PassThru
        if ($proc.ExitCode -eq 0) {
            Write-OK "QEMU guest agent installed"
        } else {
            Write-Host "    WARN: msiexec exited with code $($proc.ExitCode)" -ForegroundColor Yellow
        }
    } else {
        Write-Skip "qemu-ga-x86_64.msi not found at $GuestAgentMsi"
    }
} else {
    Write-Skip "No VirtIO CD — skipping"
}

# ---------------------------------------------------------------------------
# 3. Install VirtIO network driver (NetKVM) via pnputil
#    This pre-stages the driver so clones that switch NIC type to virtio
#    do not need driver installation on first boot.
# ---------------------------------------------------------------------------
Write-Step "Installing VirtIO network driver (NetKVM)"

if ($VirtioDrive) {
    $NetKvmInf = "${VirtioDrive}:\NetKVM\w11\amd64\netkvm.inf"
    if (Test-Path $NetKvmInf) {
        $result = pnputil.exe /add-driver "$NetKvmInf" /install
        Write-OK "VirtIO network driver staged: $result"
    } else {
        Write-Skip "netkvm.inf not found at $NetKvmInf"
    }
} else {
    Write-Skip "No VirtIO CD — skipping"
}

# ---------------------------------------------------------------------------
# 4. Install VirtIO memory balloon driver
# ---------------------------------------------------------------------------
Write-Step "Installing VirtIO balloon driver"

if ($VirtioDrive) {
    $BalloonInf = "${VirtioDrive}:\Balloon\w11\amd64\balloon.inf"
    if (Test-Path $BalloonInf) {
        $result = pnputil.exe /add-driver "$BalloonInf" /install
        Write-OK "VirtIO balloon driver staged: $result"
    } else {
        Write-Skip "balloon.inf not found at $BalloonInf"
    }
} else {
    Write-Skip "No VirtIO CD — skipping"
}

# ---------------------------------------------------------------------------
# 5. Enable Remote Desktop
# ---------------------------------------------------------------------------
Write-Step "Enabling Remote Desktop"

Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
                 -Name "fDenyTSConnections" -Value 0 -Type DWord
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
Write-OK "RDP enabled and firewall rule opened"

# ---------------------------------------------------------------------------
# 6. Set High Performance power plan (important for gaming / low-latency)
# ---------------------------------------------------------------------------
Write-Step "Setting High Performance power plan"

$hpGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
$result = powercfg /setactive $hpGuid 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-OK "High Performance power plan active"
} else {
    Write-Skip "Could not set power plan (may already be set or unavailable): $result"
}

# ---------------------------------------------------------------------------
# 7. Disable Fast Startup (can cause issues with VM snapshots / cloning)
# ---------------------------------------------------------------------------
Write-Step "Disabling Fast Startup"

Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" `
                 -Name "HiberbootEnabled" -Value 0 -Type DWord -Force
Write-OK "Fast Startup disabled"

# ---------------------------------------------------------------------------
# 8. Clean up temp files
# ---------------------------------------------------------------------------
Write-Step "Cleaning up temporary files"

$tempPaths = @(
    $env:TEMP,
    $env:TMP,
    "C:\Windows\Temp"
)

foreach ($path in $tempPaths) {
    if (Test-Path $path) {
        Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}
Write-OK "Temp directories cleaned"

# ---------------------------------------------------------------------------
# Done — Packer will now issue the sysprep shutdown_command
# ---------------------------------------------------------------------------
Write-Host "`n==> Setup complete. Packer will now run sysprep to generalise the image.`n" -ForegroundColor Green

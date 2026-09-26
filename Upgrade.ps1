<#
UpgradeSoftware.ps1
- Requires: Windows 10/11, Admin, winget (App Installer)
- Behavior: Upgrades installed applications via winget,
  excluding launchers and other manually managed software.
#>

# ============================================================================
# Elevation guard
# ============================================================================

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {

    Write-Error "Please run this script as Administrator (elevated PowerShell)."
    exit 1
}

# ============================================================================
# Execution policy (session only)
# ============================================================================

Set-ExecutionPolicy Bypass -Scope Process -Force


# ============================================================================
# Packages to exclude
# ============================================================================
#
# These applications are intentionally managed outside of this script.
# Add/remove IDs as needed.
##

$ExcludedIds = @(
    # IDEs / Development environments
    # "Microsoft.VisualStudio.2022.Community" - uninstalled
    # "JetBrains.Toolbox"

    # Development infrastructure
    "Docker.DockerDesktop"
    # "Oracle.VirtualBox"
    "Anaconda.Miniconda3"
    "Python.Python.3"

    # Gaming / Launchers
    "Valve.Steam"
    "EpicGames.EpicGamesLauncher"
    "ElectronicArts.EADesktop"

    # Networking / VPN
    "ZeroTier.ZeroTierOne"
    "Proton.ProtonVPN"

    # Large / manually managed applications
    # "GIMP.GIMP"
    "Microsoft.Office"
    "Microsoft.PowerToys"
    # "Obsidian.Obsidian"
)

# ============================================================================
# Get available upgrades
# ============================================================================

Write-Host "Checking for available upgrades..."

$upgradeOutput = winget upgrade `
    --source winget `
    --accept-source-agreements

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to query winget for available upgrades."
    exit 1
}

# ============================================================================
# Get installed packages
# ============================================================================

Write-Host "Finding upgradeable packages..."

$packages = winget upgrade `
    --source winget `
    --accept-source-agreements `
    --disable-interactivity `
    --output json 2>$null |
    ConvertFrom-Json

# ============================================================================
# Upgrade packages
# ============================================================================

$upgraded = @()
$skipped = @()
$failed = @()

foreach ($package in $packages.Data) {

    $id = $package.PackageIdentifier
    $name = $package.PackageName

    if (-not $id -or -not $name) {
        continue
    }

    if ($ExcludedIds -contains $id) {
        Write-Host "Skipping $name ($id)"
        $skipped += $name
        continue
    }

    Write-Host ""
    Write-Host "Upgrading $name ($id)..."

    $args = @(
        "upgrade"
        "--id"
        $id
        "-e"
        "--source"
        "winget"
        "--silent"
        "--accept-package-agreements"
        "--accept-source-agreements"
    )

    $proc = Start-Process `
        -FilePath "winget" `
        -ArgumentList $args `
        -Wait `
        -PassThru

    if ($proc.ExitCode -eq 0) {
        Write-Host "Successfully upgraded $name."
        $upgraded += $name
    }
    else {
        Write-Warning "Failed to upgrade $name. Exit code: $($proc.ExitCode)"
        $failed += $name
    }
}

# ============================================================================
# Summary
# ============================================================================

Write-Host ""
Write-Host "============================================================"
Write-Host "Upgrade Summary"
Write-Host "============================================================"

Write-Host ""
Write-Host "Upgraded:"
if ($upgraded.Count -gt 0) {
    $upgraded | ForEach-Object {
        Write-Host "  + $_"
    }
}
else {
    Write-Host "  None"
}

Write-Host ""
Write-Host "Skipped:"
if ($skipped.Count -gt 0) {
    $skipped | ForEach-Object {
        Write-Host "  - $_"
    }
}
else {
    Write-Host "  None"
}

Write-Host ""
Write-Host "Failed:"
if ($failed.Count -gt 0) {
    $failed | ForEach-Object {
        Write-Host "  ! $_"
    }
}
else {
    Write-Host "  None"
}

Write-Host ""
Write-Host "Upgrade process complete."


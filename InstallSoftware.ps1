<#
InstallSoftware.ps1
- Requires: Windows 10/11, Admin, winget (App Installer)
- Behavior: Installs listed apps via winget if not already present.
- Security: Enforces strict installer hash validation.
#>

# ==== Elevation guard ====
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Please run this script as Administrator (elevated PowerShell)."
    exit 1
}

# ==== Execution policy (session only) ====
Set-ExecutionPolicy Bypass -Scope Process -Force

# ==== Ensure winget (App Installer) is available ====
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error "winget (Windows Package Manager) is not available. Install 'App Installer' from Microsoft Store, then rerun."
    exit 1
}

# ==== Lock down winget security ====
# Fail installs if the downloaded file hash does not match the manifest.
winget settings --enable InstallerHashOverride false | Out-Null

# ---- Helper: test installed by Id ----
function Test-WingetInstalledById {
    param([Parameter(Mandatory)][string]$Id)
    try {
        $json = winget list --id $Id -s winget -e -o json 2>$null | ConvertFrom-Json
        # Winget's JSON can differ across versions; check multiple properties safely
        if ($null -ne $json) {
            if ($json.InstalledPackages -and $json.InstalledPackages.Count -gt 0) { return $true }
            if ($json.Matches -and $json.Matches.Count -gt 0) { return $true }
            if ($json.SourceDetails -and $json.SourceDetails.Count -gt 0) { return $true }
        }
    } catch { }
    return $false
}

# ---- Helper: resolve Id by exact Name if Id not supplied ----
function Resolve-WingetIdByName {
    param([Parameter(Mandatory)][string]$Name)
    try {
        $res = winget search --name $Name -e -s winget -o json 2>$null | ConvertFrom-Json
        if ($res -and $res.Count -gt 0) { return $res[0].Id }
    } catch { }
    return $null
}

# ---- Install if missing (with retry and optional override args) ----
function Install-WingetPackageIfNotInstalled {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Id,
        [string]$OverrideArgs
    )

    # Resolve Id if needed
    $resolvedId = if ($Id) { $Id } else { Resolve-WingetIdByName -Name $Name }
    if (-not $resolvedId) {
        Write-Warning "No exact winget Id found for '$Name' — skipping."
        return $false
    }

    # Skip if already installed
    if (Test-WingetInstalledById -Id $resolvedId) {
        Write-Host "$Name is already installed."
        return $true
    }

    # Build arguments
    $args = @(
        "install","--id",$resolvedId,"-e","--silent",
        "--accept-package-agreements","--accept-source-agreements"
    )
    if ($OverrideArgs) { $args += @("--override",$OverrideArgs) }

    # Attempt install twice, refresh sources between attempts
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        Write-Host "Installing $Name ($resolvedId) ... attempt $attempt"
        $proc = Start-Process winget -ArgumentList $args -Wait -PassThru
        if ($proc.ExitCode -eq 0) { return $true }

        Write-Warning "Install failed for $Name ($resolvedId) with exit code $($proc.ExitCode). Refreshing sources and retrying..."
        winget source update --force | Out-Null
        Start-Sleep -Seconds 3
    }

    Write-Warning "winget failed for $Name ($resolvedId) after retries."
    return $false
}

# ==== Package list ====
# Add/remove/comment as desired; prefer exact Ids.
$packages = @(
    # IDEs / Terminals
    @{ Name="JetBrains Toolbox";            
    Id="JetBrains.Toolbox" }
    
    # Shell
    @{ Name="Windows Terminal Preview";     
    Id="Microsoft.WindowsTerminal.Preview" }

    @{ Name="PowerShell 7";                 
    Id="Microsoft.PowerShell" }


    # Editors
    @{ Name="Neovim";                       
    Id="Neovim.Neovim" }

    @{ Name ="Helix";
    Id="Helix.Helix"}   

    @{ Name="Visual Studio Code";           
    Id="Microsoft.VisualStudioCode" }

    # Coding tools
    # @{ Name="Docker Desktop";               
    # Id="Docker.DockerDesktop" }

    @{ Name="GitHub Desktop";               
    Id="GitHub.GitHubDesktop" }

    @{ Name="Git";                          
    Id="Git.Git" }

    @{ Name="CMake";                        
    Id="Kitware.CMake";           
    OverrideArgs="ADD_CMAKE_TO_PATH=System" }

    # @{ Name="MSYS2";                        
    # Id="MSYS2.MSYS2" }
    
    # @{ Name="Cygwin";                       
    # Id="Cygwin.Cygwin" }

    # DB tools
    @{ Name="DB Browser for SQLite";        
    Id="DBBrowserForSQLite.DBBrowserForSQLite" }

    # Networking / VPN
    @{ Name="ZeroTier";                     
    Id="ZeroTier.ZeroTierOne" }

    @{ Name="Proton VPN";                   
    Id="Proton.ProtonVPN" }


    # Gaming / Launchers
    @{ Name="Steam";                        
    Id="Valve.Steam" }
    
    @{ Name="Epic Games Launcher";          
    Id="EpicGames.EpicGamesLauncher" }

    #@{ Name="EA App";                       
    #Id="ElectronicArts.EADesktop" }

    # Emulation / VM
    @{ Name="VirtualBox";                   
    Id="Oracle.VirtualBox" }

    #@{ Name="QEMU";                         
    #Id="SoftwareFreedomConservancy.QEMU" }

    # Python / Conda
    @{ Name="Miniconda3";                   
    Id="Anaconda.Miniconda3" }

    @{ Name = "Python 3 (latest)";
    Id   = "Python.Python.3";
    OverrideArgs = "InstallAllUsers=1 PrependPath=1 Include_test=0"
}

    # Misc
    @{ Name="Okular";                       
    Id="KDE.Okular" }

    @{ Name="PowerToys";                    
    Id="Microsoft.PowerToys" }

    #@{ Name="7-Zip";                        
    #Id="7zip.7zip" }

    @{ Name="WinDirStat";                   
    Id="WinDirStat.WinDirStat" }

    # Art
    #@{ Name="Paint.NET";                    
    #Id="dotPDNLLC.paintdotnet" }

    @{ Name="GIMP";                         
    Id="GIMP.GIMP" }

    #@{ Name="Krita";                        
    #Id="KDE.Krita" }

    #@{ Name="Blender";                      
    #Id="BlenderFoundation.Blender" }

    # Productivity
    @{ Name="Obsidian";                     
    Id="Obsidian.Obsidian" }
    
    #@{ Name="Joplin";                       
    #Id="Joplin.Joplin" }

    # Office (installer; sign in to activate)
    @{ Name="Microsoft 365 Apps (Office)";  Id="Microsoft.Office" }
)

# ==== Install loop ====
$failed = @()
foreach ($pkg in $packages) {
    $ok = Install-WingetPackageIfNotInstalled -Name $pkg.Name -Id $pkg.Id -OverrideArgs $pkg.OverrideArgs
    if (-not $ok) { $failed += $pkg }
}

if ($failed.Count -gt 0) {
    Write-Warning "Packages not installed:"
    $failed | ForEach-Object { Write-Host (" - {0} ({1})" -f $_.Name, ($_.Id | ForEach-Object { $_ })) }
}

# ==== Optional cleanup ====
if (Test-Path "$PSScriptRoot\clean.ps1") {
    Write-Host "Cleaning Winget caches and TEMP..."
    & "$PSScriptRoot\clean.ps1" -IncludeSystemTemp
}

Write-Host "Installation complete. Some apps (e.g., Microsoft 365) may prompt for sign-in. You may need to restart if requested."

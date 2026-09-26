<#
.SYNOPSIS
  Cleans Winget cache, temp folders, and logs. Optional: general TEMP.

.PARAMETER IncludeSystemTemp
  Also clear the current user's TEMP and the system temp directory.

.PARAMETER WhatIf
  Show what would be removed without deleting anything.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$IncludeSystemTemp
)

# Paths Winget uses (stable + preview share the same root package family name)
$pkgRoot        = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe'
$wingetCache    = Join-Path $pkgRoot 'LocalCache\Microsoft\WinGet'
$wingetTemp     = Join-Path $env:TEMP 'WinGet'
$wingetLogs     = Join-Path $pkgRoot 'LocalState\DiagOutputDir'

# Optional broader cleanup
$userTemp       = $env:TEMP
$systemTemp     = [System.IO.Path]::GetTempPath()

function Clear-Directory {
    param(
        [Parameter(Mandatory)][string]$Path
    )
    if (Test-Path $Path) {
        Write-Host "Clearing: $Path"
        $items = Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue
        foreach ($i in $items) {
            if ($PSCmdlet.ShouldProcess($i.FullName, "Remove")) {
                Remove-Item -LiteralPath $i.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    } else {
        Write-Host "Not found (skipped): $Path"
    }
}

Write-Host "=== Winget cache & logs cleanup ==="

# Core Winget locations
Clear-Directory -Path $wingetCache
Clear-Directory -Path $wingetTemp
Clear-Directory -Path $wingetLogs

if ($IncludeSystemTemp) {
    Write-Host "=== Extra TEMP cleanup ==="
    Clear-Directory -Path $userTemp
    Clear-Directory -Path $systemTemp
}

winget source update
winget settings --enable InstallerHashOverride false


Write-Host "Done. Consider refreshing sources with:"
Write-Host "  winget source update --force"


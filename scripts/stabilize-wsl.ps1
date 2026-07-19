<#
.SYNOPSIS
  Apply stable WSL2 defaults and restart the WSL VM.
#>
$ErrorActionPreference = "Stop"
$cfg = Join-Path $env:USERPROFILE ".wslconfig"

Write-Host "=== .wslconfig ==="
if (Test-Path $cfg) { Get-Content $cfg } else { throw "Missing $cfg" }

Write-Host ""
Write-Host "Shutting down WSL (Ubuntu + docker-desktop will stop)..."
try { wsl --shutdown } catch { Write-Host "shutdown issued (connection drop is normal)" }
Start-Sleep -Seconds 5

Write-Host "Starting default distro to apply config..."
wsl -e echo ok
Start-Sleep -Seconds 2

Write-Host ""
Write-Host "=== status ==="
wsl --status
wsl -l -v

Write-Host ""
Write-Host "Done. Re-open Docker Desktop if you need containers."
Write-Host "For git/push/papercuts prefer Windows PowerShell, not WSL."
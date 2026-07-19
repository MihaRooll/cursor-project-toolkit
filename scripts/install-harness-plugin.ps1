<#
.SYNOPSIS
  Install cursor-project-harness into Cursor local plugins folder.
#>
param(
    [string]$LocalPluginsRoot = (Join-Path $env:USERPROFILE ".cursor\plugins\local")
)

$ErrorActionPreference = "Stop"
$ToolkitRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$Src = Join-Path $ToolkitRoot "plugin\cursor-project-harness"
$Dst = Join-Path $LocalPluginsRoot "cursor-project-harness"

if (-not (Test-Path $Src)) { throw "Missing plugin source: $Src" }

New-Item -ItemType Directory -Force -Path $LocalPluginsRoot | Out-Null
if (Test-Path $Dst) {
    Remove-Item -Recurse -Force $Dst
}
Copy-Item -Path $Src -Destination $Dst -Recurse -Force

# Keep hook scripts in plugin/scripts in sync with toolkit hooks
$hookNames = @("session-start.ps1", "after-shell-papercuts.ps1", "stop-papercuts-nudge.ps1")
foreach ($h in $hookNames) {
    Copy-Item (Join-Path $ToolkitRoot ".cursor\hooks\$h") (Join-Path $Dst "scripts\$h") -Force
}
Copy-Item (Join-Path $ToolkitRoot "scripts\papercuts.ps1") (Join-Path $Dst "scripts\papercuts.ps1") -Force
Copy-Item (Join-Path $ToolkitRoot "templates\project-rules\product-core.mdc") (Join-Path $Dst "rules\product-core.mdc") -Force

Write-Host "Installed: $Dst"
Write-Host "Reload Cursor window. Plugin name: cursor-project-harness"
Write-Host "For on-disk project files still run bootstrap-into-project.ps1 Essential."

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
Copy-Item (Join-Path $ToolkitRoot "scripts\papercuts.cmd") (Join-Path $Dst "scripts\papercuts.cmd") -Force
Copy-Item (Join-Path $ToolkitRoot "templates\project-rules\product-core.mdc") (Join-Path $Dst "rules\product-core.mdc") -Force
Copy-Item (Join-Path $ToolkitRoot ".cursor\rules\skills-ru-description.mdc") `
    (Join-Path $Dst "rules\skills-ru-description.mdc") -Force

$reviewSkillDst = Join-Path $Dst "skills\review-papercuts"
if (Test-Path $reviewSkillDst) { Remove-Item -Recurse -Force $reviewSkillDst }
Copy-Item (Join-Path $ToolkitRoot ".cursor\skills\review-papercuts") `
    (Join-Path $Dst "skills") -Recurse -Force

# Allowlisted orchestration sync from canonical .cursor surface.
Copy-Item (Join-Path $ToolkitRoot ".cursor\rules\autonomous-orchestration.mdc") `
    (Join-Path $Dst "rules\autonomous-orchestration.mdc") -Force

$autoSkillDst = Join-Path $Dst "skills\autonomous-task"
if (Test-Path $autoSkillDst) { Remove-Item -Recurse -Force $autoSkillDst }
Copy-Item (Join-Path $ToolkitRoot ".cursor\skills\autonomous-task") `
    (Join-Path $Dst "skills") -Recurse -Force

$maintainSkillDst = Join-Path $Dst "skills\maintain-project-docs"
if (Test-Path $maintainSkillDst) { Remove-Item -Recurse -Force $maintainSkillDst }
Copy-Item (Join-Path $ToolkitRoot ".cursor\skills\maintain-project-docs") `
    (Join-Path $Dst "skills") -Recurse -Force

$configureSkillDst = Join-Path $Dst "skills\configure-project-integrations"
if (Test-Path $configureSkillDst) { Remove-Item -Recurse -Force $configureSkillDst }
Copy-Item (Join-Path $ToolkitRoot ".cursor\skills\configure-project-integrations") `
    (Join-Path $Dst "skills") -Recurse -Force

$browserSkillDst = Join-Path $Dst "skills\browser-verify"
if (Test-Path $browserSkillDst) { Remove-Item -Recurse -Force $browserSkillDst }
Copy-Item (Join-Path $ToolkitRoot ".cursor\skills\browser-verify") `
    (Join-Path $Dst "skills") -Recurse -Force

$setupSkillDst = Join-Path $Dst "skills\setup-project-environment"
if (Test-Path $setupSkillDst) { Remove-Item -Recurse -Force $setupSkillDst }
Copy-Item (Join-Path $ToolkitRoot ".cursor\skills\setup-project-environment") `
    (Join-Path $Dst "skills") -Recurse -Force

Copy-Item (Join-Path $ToolkitRoot ".cursor\rules\project-docs-lifecycle.mdc") `
    (Join-Path $Dst "rules\project-docs-lifecycle.mdc") -Force

$agentsDst = Join-Path $Dst "agents"
New-Item -ItemType Directory -Force -Path $agentsDst | Out-Null
$agentNames = @(
    "operational-orchestrator.md",
    "implementer.md",
    "adversarial-reviewer.md",
    "verifier.md",
    "principal-arbiter.md"
)
foreach ($agentName in $agentNames) {
    Copy-Item (Join-Path $ToolkitRoot ".cursor\agents\$agentName") `
        (Join-Path $agentsDst $agentName) -Force
}

Write-Host "Installed: $Dst"
Write-Host "Reload Cursor window. Plugin name: cursor-project-harness"
Write-Host "For on-disk project files still run bootstrap-into-project.ps1 Essential."

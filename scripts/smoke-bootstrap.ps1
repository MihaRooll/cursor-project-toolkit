<#
.SYNOPSIS
  Smoke-test Essential bootstrap + papercuts shim into a throwaway folder.
#>
param(
    [string]$TargetPath = (Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) "_toolkit-smoke-test")
)

$ErrorActionPreference = "Stop"
$ToolkitRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$fail = 0

function Assert-True($cond, $msg) {
    if ($cond) {
        Write-Host "OK  $msg"
    } else {
        Write-Host "FAIL $msg"
        $script:fail++
    }
}

Write-Host "=== Smoke bootstrap ==="
Write-Host "Toolkit: $ToolkitRoot"
Write-Host "Target:  $TargetPath"

if (Test-Path $TargetPath) {
    Remove-Item -Recurse -Force $TargetPath
}
New-Item -ItemType Directory -Force -Path $TargetPath | Out-Null

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ToolkitRoot "scripts\bootstrap-into-project.ps1") `
    -TargetPath $TargetPath -Mode Essential
if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
    Write-Host "FAIL bootstrap exit=$LASTEXITCODE"
    $fail++
}

$mustExist = @(
    ".cursor\hooks.json",
    ".cursor\hooks\session-start.ps1",
    ".cursor\hooks\after-shell-papercuts.ps1",
    ".cursor\hooks\stop-papercuts-nudge.ps1",
    ".cursor\skills\review-papercuts\SKILL.md",
    ".cursor\rules\product-core.mdc",
    ".cursor\rules\skills-ru-description.mdc",
    ".gitattributes",
    "AGENTS.md",
    "scripts\papercuts.ps1",
    "scripts\papercuts.cmd",
    "project-workflow\session-checklist.md",
    "docs\papercuts.md",
    "docs\skills-russian-descriptions.md",
    "docs\cursor-agent-best-practices.md",
    "docs\cursor-primitives.md",
    "docs\bootstrap-scaffold.md",
    "prompting\README.md",
    "prompting\plan-then-build.md",
    "prompting\context-hygiene.md",
    "prompting\verify-loop.md",
    "roles\README.md",
    "roles\implementer.md",
    "roles\reviewer.md",
    "subagents\README.md",
    "subagents\verifier.md"
)

$mustAbsent = @(
    "SOURCES.md",
    "archive",
    ".cursor\skills\ship-toolkit",
    ".cursor\skills\add-source",
    ".cursor\skills\bootstrap-project",
    ".cursor\skills\distill-doc",
    ".cursor\rules\toolkit-core.mdc",
    ".cursor\rules\docs-ai-first.mdc",
    "prompting\constraint-first.md",
    "roles\docs-distiller.md",
    "subagents\explorer.md"
)

Write-Host ""
Write-Host "=== Presence checks ==="
foreach ($rel in $mustExist) {
    Assert-True (Test-Path (Join-Path $TargetPath $rel)) "has $rel"
}

Write-Host ""
Write-Host "=== Absence checks (Essential product surface) ==="
foreach ($rel in $mustAbsent) {
    Assert-True (-not (Test-Path (Join-Path $TargetPath $rel))) "no $rel"
}

$gaPath = Join-Path $TargetPath ".gitattributes"
if (Test-Path $gaPath) {
    $ga = Get-Content $gaPath -Raw
    Assert-True ($ga -match "papercuts\.jsonl") ".gitattributes has papercuts merge=union"
} else {
    Assert-True $false ".gitattributes exists for merge check"
}

$agentsPath = Join-Path $TargetPath "AGENTS.md"
if (Test-Path $agentsPath) {
    $agents = Get-Content $agentsPath -Raw
    Assert-True ($agents.Length -gt 50) "AGENTS.md non-empty"
} else {
    Assert-True $false "AGENTS.md exists for content check"
}

Write-Host ""
Write-Host "=== Papercuts shim ==="
$env:HOME = $env:USERPROFILE
Push-Location $TargetPath
try {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\papercuts.ps1" `
        add "smoke: bootstrap harness verified" -Tag smoke -Severity minor
    Assert-True (Test-Path ".\.papercuts.jsonl") ".papercuts.jsonl created in target"

    $lines = @(Get-Content ".\.papercuts.jsonl" -Encoding utf8)
    Assert-True ($lines.Count -ge 1) "at least one JSONL line"

    $rec = $lines[-1] | ConvertFrom-Json
    Assert-True ($rec.kind -eq "cut") "record kind=cut"
    Write-Host "    id=$($rec.id)"

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\papercuts.ps1" list -Format md | Out-Host

    $hooks = Get-Content ".\.cursor\hooks.json" -Raw | ConvertFrom-Json
    Assert-True ($null -ne $hooks) "hooks.json parses"
} finally {
    Pop-Location
}

Assert-True (Test-Path (Join-Path $TargetPath ".papercuts.jsonl")) "target has its own .papercuts.jsonl"

Write-Host ""
if ($fail -eq 0) {
    Write-Host "SMOKE PASS ($TargetPath)"
    exit 0
} else {
    Write-Host "SMOKE FAIL: $fail assertion(s)"
    exit 1
}

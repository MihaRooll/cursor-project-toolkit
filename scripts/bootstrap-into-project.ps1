<#
.SYNOPSIS
  Copy AI-agent harness from cursor-project-toolkit into a target project.

.EXAMPLE
  .\scripts\bootstrap-into-project.ps1 -TargetPath C:\work\my-app
  .\scripts\bootstrap-into-project.ps1 -TargetPath ..\my-app -Mode Full
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetPath,

    [ValidateSet("Essential", "Full")]
    [string]$Mode = "Essential",

    [switch]$Force,

    # Optional: also add toolkit as git submodule at vendor/cursor-project-toolkit
    [switch]$WithSubmodule
)

$ErrorActionPreference = "Stop"
$ToolkitRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$Target = $TargetPath
if (-not [System.IO.Path]::IsPathRooted($Target)) {
    $Target = Join-Path (Get-Location) $Target
}
New-Item -ItemType Directory -Force -Path $Target | Out-Null
$Target = Resolve-Path $Target

function Copy-Path($Rel) {
    $src = Join-Path $ToolkitRoot $Rel
    $dst = Join-Path $Target $Rel
    if (-not (Test-Path $src)) { Write-Warning "skip missing: $Rel"; return }
    $dstDir = Split-Path -Parent $dst
    if ($dstDir) { New-Item -ItemType Directory -Force -Path $dstDir | Out-Null }
    if ((Test-Path $dst) -and -not $Force) {
        Write-Host "exists (use -Force to overwrite): $Rel"
        return
    }
    if (Test-Path $src -PathType Container) {
        if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
        Copy-Item -Path $src -Destination $dst -Recurse -Force
    } else {
        Copy-Item -Path $src -Destination $dst -Force
    }
    Write-Host "copied $Rel"
}

function Copy-FileTo($RelSrc, $RelDst) {
    $src = Join-Path $ToolkitRoot $RelSrc
    $dst = Join-Path $Target $RelDst
    if (-not (Test-Path $src)) { Write-Warning "skip missing: $RelSrc"; return }
    $dstDir = Split-Path -Parent $dst
    if ($dstDir) { New-Item -ItemType Directory -Force -Path $dstDir | Out-Null }
    if ((Test-Path $dst) -and -not $Force) {
        Write-Host "exists (use -Force to overwrite): $RelDst"
        return
    }
    Copy-Item -Path $src -Destination $dst -Force
    Write-Host "copied $RelSrc -> $RelDst"
}

Write-Host "Bootstrap $Mode -> $Target"
Write-Host "From toolkit: $ToolkitRoot"

# --- Essential: product harness (not toolkit meta) ---
$essentialFiles = @(
    ".cursor\hooks.json",
    ".cursor\hooks",
    ".gitattributes",
    "scripts\papercuts.ps1",
    "scripts\papercuts.cmd",
    "project-workflow\session-checklist.md",
    "docs\papercuts.md",
    "docs\skills-russian-descriptions.md",
    "docs\cursor-agent-best-practices.md",
    "docs\cursor-primitives.md",
    "docs\bootstrap-scaffold.md",
    # Prompting / roles / subagents (Essential subset)
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

foreach ($p in $essentialFiles) { Copy-Path $p }

# Product skills only
Copy-Path ".cursor\skills\review-papercuts"

# Product rules (not toolkit-core / docs-ai-first with SOURCES)
Copy-Path ".cursor\rules\skills-ru-description.mdc"
Copy-FileTo "templates\project-rules\product-core.mdc" ".cursor\rules\product-core.mdc"

# Project-facing AGENTS (do not overwrite custom AGENTS without -Force)
$agentsSrc = Join-Path $ToolkitRoot "templates\project-AGENTS.md"
$agentsDst = Join-Path $Target "AGENTS.md"
if ((Test-Path $agentsDst) -and -not $Force) {
    Write-Host "exists: AGENTS.md (use -Force to overwrite)"
} else {
    Copy-Item $agentsSrc $agentsDst -Force
    Write-Host "copied templates/project-AGENTS.md -> AGENTS.md"
}

if ($Mode -eq "Full") {
    $full = @(
        "docs",
        "SOURCES.md",
        "prompting",
        "roles",
        "subagents",
        "rules-and-skills",
        "project-workflow",
        "archive\README.md",
        "scripts\install-rust-papercuts.ps1",
        "scripts\smoke-bootstrap.ps1",
        "scripts\parse-check-ps1.ps1",
        ".cursor\skills",
        ".cursor\rules"
    )
    foreach ($p in $full) { Copy-Path $p }
}

if ($WithSubmodule) {
    $vendor = Join-Path $Target "vendor\cursor-project-toolkit"
    if (Test-Path $vendor) {
        Write-Host "exists: vendor/cursor-project-toolkit (skip submodule)"
    } else {
        Push-Location $Target
        try {
            if (-not (Test-Path (Join-Path $Target ".git"))) {
                Write-Warning "WithSubmodule: target is not a git repo; init first or add submodule manually"
            } else {
                git submodule add https://github.com/MihaRooll/cursor-project-toolkit.git vendor/cursor-project-toolkit
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "added submodule vendor/cursor-project-toolkit"
                } else {
                    Write-Warning "git submodule add failed (exit $LASTEXITCODE)"
                }
            }
        } finally {
            Pop-Location
        }
    }
}

# Windows HOME for papercuts
if (-not [Environment]::GetEnvironmentVariable("HOME", "User")) {
    [Environment]::SetEnvironmentVariable("HOME", $env:USERPROFILE, "User")
    Write-Host "Set User HOME=$env:USERPROFILE (new terminals will see it)"
}

# Ensure gitattributes merge for papercuts
$ga = Join-Path $Target ".gitattributes"
$line = ".papercuts.jsonl merge=union"
if (Test-Path $ga) {
    $txt = Get-Content $ga -Raw
    if ($txt -notmatch "papercuts\.jsonl") {
        Add-Content $ga "`n$line"
        Write-Host "appended papercuts merge=union to .gitattributes"
    }
} else {
    Set-Content $ga $line
    Write-Host "created .gitattributes"
}

Write-Host ""
Write-Host "Done. Next:"
Write-Host "  1. cd `"$Target`""
Write-Host "  2. Open folder in Cursor"
Write-Host "  3. Optional: cargo install papercuts  (or use scripts/papercuts.ps1)"
Write-Host "  4. /add-plugin cursor-team-kit"
Write-Host "  5. Start building - hooks auto-log failed shells to .papercuts.jsonl"
if ($WithSubmodule) {
    Write-Host "  6. Toolkit reference: vendor/cursor-project-toolkit (submodule)"
}

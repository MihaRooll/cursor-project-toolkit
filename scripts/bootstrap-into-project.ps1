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
    [switch]$WithSubmodule,

    # When set (e.g. from new-project.ps1), skip trailing "Done. Next:" handoff block
    [switch]$SkipNext,

    # Skip User-scope HOME mutation (portability smoke / isolated runs)
    [switch]$SkipUserHome
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

function Merge-CopyPath($Rel) {
    $src = Join-Path $ToolkitRoot $Rel
    $dst = Join-Path $Target $Rel
    if (-not (Test-Path $src)) { Write-Warning "skip missing: $Rel"; return }
    if (Test-Path $src -PathType Container) {
        if (-not (Test-Path $dst)) {
            Copy-Item -Path $src -Destination $dst -Recurse -Force
            Write-Host "copied $Rel"
            return
        }
        if ($Force) {
            Remove-Item -Recurse -Force $dst
            Copy-Item -Path $src -Destination $dst -Recurse -Force
            Write-Host "overwrote $Rel (-Force)"
            return
        }
        $merged = 0
        Get-ChildItem -Path $src -Recurse -Force | ForEach-Object {
            $relChild = $_.FullName.Substring($src.Length).TrimStart('\', '/')
            if ($_.PSIsContainer -and $relChild -match '(?i)(^|\\)state$') {
                $children = @(Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue)
                if ($children.Count -eq 0) {
                    return
                }
            }
            $targetItem = Join-Path $dst $relChild
            if (-not (Test-Path -LiteralPath $targetItem)) {
                if ($_.PSIsContainer) {
                    New-Item -ItemType Directory -Force -Path $targetItem | Out-Null
                } else {
                    $parent = Split-Path -Parent $targetItem
                    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
                    Copy-Item -LiteralPath $_.FullName -Destination $targetItem -Force
                }
                $merged++
            }
        }
        Write-Host "merged $Rel ($merged new item(s))"
        return
    }
    $dstDir = Split-Path -Parent $dst
    if ($dstDir) { New-Item -ItemType Directory -Force -Path $dstDir | Out-Null }
    if ((Test-Path $dst) -and -not $Force) {
        Write-Host "exists (use -Force to overwrite): $Rel"
        return
    }
    Copy-Item -Path $src -Destination $dst -Force
    Write-Host "copied $Rel"
}

function Copy-FileTo($RelSrc, $RelDst, [switch]$Always) {
    $src = Join-Path $ToolkitRoot $RelSrc
    $dst = Join-Path $Target $RelDst
    if (-not (Test-Path $src)) { Write-Warning "skip missing: $RelSrc"; return }
    $dstDir = Split-Path -Parent $dst
    if ($dstDir) { New-Item -ItemType Directory -Force -Path $dstDir | Out-Null }
    if ((Test-Path $dst) -and -not $Force -and -not $Always) {
        Write-Host "exists (use -Force to overwrite): $RelDst"
        return
    }
    Copy-Item -Path $src -Destination $dst -Force
    Write-Host "copied $RelSrc -> $RelDst"
}

function Merge-PapercutsHooks {
    $hooksDir = Join-Path $Target ".cursor\hooks"
    New-Item -ItemType Directory -Force -Path $hooksDir | Out-Null

    # Always refresh papercuts hook scripts (do not wipe other project hook scripts)
    foreach ($name in @(
            "session-start.ps1",
            "after-shell-papercuts.ps1",
            "stop-papercuts-nudge.ps1"
        )) {
        Copy-Item (Join-Path $ToolkitRoot ".cursor\hooks\$name") (Join-Path $hooksDir $name) -Force
        Write-Host "synced hook script $name"
    }

    $dstHooks = Join-Path $Target ".cursor\hooks.json"
    $papercutsHooks = @{
        sessionStart         = @(
            @{
                command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .cursor/hooks/session-start.ps1"
                timeout = 15
            }
        )
        afterShellExecution  = @(
            @{
                command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .cursor/hooks/after-shell-papercuts.ps1"
                timeout = 20
            }
        )
        stop                 = @(
            @{
                command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File .cursor/hooks/stop-papercuts-nudge.ps1"
                timeout = 15
            }
        )
    }

    if (-not (Test-Path $dstHooks)) {
        $obj = @{ version = 1; hooks = $papercutsHooks }
        $json = $obj | ConvertTo-Json -Depth 8
        $utf8 = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($dstHooks, $json, $utf8)
        Write-Host "created .cursor/hooks.json (papercuts)"
        return
    }

    if ($Force) {
        Copy-Item (Join-Path $ToolkitRoot ".cursor\hooks.json") $dstHooks -Force
        Write-Host "overwrote .cursor/hooks.json (-Force)"
        return
    }

    try {
        $existing = Get-Content $dstHooks -Raw -Encoding utf8 | ConvertFrom-Json
    } catch {
        Write-Warning "hooks.json parse failed; leaving as-is"
        return
    }

    if (-not $existing.hooks) {
        $existing | Add-Member -NotePropertyName hooks -NotePropertyValue ([pscustomobject]@{}) -Force
    }

    $changed = $false
    foreach ($evt in @("sessionStart", "afterShellExecution", "stop")) {
        $arr = @()
        $prop = $existing.hooks.PSObject.Properties[$evt]
        if ($null -ne $prop -and $null -ne $prop.Value) {
            $arr = @($prop.Value | Where-Object { $null -ne $_ })
        }
        $hasPapercuts = $false
        foreach ($item in $arr) {
            if ($item.command -and ($item.command -match "papercuts|session-start\.ps1")) {
                $hasPapercuts = $true
                break
            }
        }
        if (-not $hasPapercuts) {
            $toAdd = @($papercutsHooks[$evt])
            $newArr = @($arr) + $toAdd
            $existing.hooks | Add-Member -NotePropertyName $evt -NotePropertyValue $newArr -Force
            $changed = $true
            Write-Host "merged hook event: $evt"
        } elseif ($arr.Count -ne @($prop.Value).Count) {
            # strip accidental nulls from prior bad merges
            $existing.hooks | Add-Member -NotePropertyName $evt -NotePropertyValue $arr -Force
            $changed = $true
            Write-Host "cleaned nulls in hook event: $evt"
        }
    }

    if ($changed) {
        if (-not $existing.version) {
            $existing | Add-Member -NotePropertyName version -NotePropertyValue 1 -Force
        }
        $json = $existing | ConvertTo-Json -Depth 8
        $utf8 = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($dstHooks, $json, $utf8)
        Write-Host "updated .cursor/hooks.json (merged papercuts)"
    } else {
        Write-Host "hooks.json already has papercuts events"
    }
}

function Ensure-AgentsHarnessSnippet {
    $agentsDst = Join-Path $Target "AGENTS.md"
    $fullSrc = Join-Path $ToolkitRoot "templates\project-AGENTS.md"
    $snippetSrc = Join-Path $ToolkitRoot "templates\project-AGENTS-harness-snippet.md"
    $marker = "cursor-project-toolkit-harness"

    if (-not (Test-Path $agentsDst)) {
        Copy-Item $fullSrc $agentsDst -Force
        Write-Host "copied templates/project-AGENTS.md -> AGENTS.md"
        return
    }

    if ($Force) {
        Copy-Item $fullSrc $agentsDst -Force
        Write-Host "overwrote AGENTS.md (-Force)"
        return
    }

    $txt = Get-Content $agentsDst -Raw -Encoding utf8
    if ($txt -match [regex]::Escape($marker)) {
        Write-Host "AGENTS.md already has harness snippet"
        return
    }

    $snippet = Get-Content $snippetSrc -Raw -Encoding utf8
    $utf8 = New-Object System.Text.UTF8Encoding $false
    $nl = if ($txt.EndsWith("`n")) { "" } else { [Environment]::NewLine }
    [System.IO.File]::WriteAllText($agentsDst, $txt + $nl + [Environment]::NewLine + $snippet, $utf8)
    Write-Host "appended harness snippet to AGENTS.md"
}

Write-Host "Bootstrap $Mode -> $Target"
Write-Host "From toolkit: $ToolkitRoot"

# --- Essential: product harness (not toolkit meta) ---
# hooks handled separately (merge-safe)
$essentialFiles = @(
    ".gitattributes",
    "scripts\papercuts.ps1",
    "scripts\papercuts.cmd",
    "project-workflow\session-checklist.md",
    "docs\papercuts.md",
    "docs\skills-russian-descriptions.md",
    "docs\cursor-agent-best-practices.md",
    "docs\cursor-primitives.md",
    "docs\bootstrap-scaffold.md",
    "docs\living-documentation.md",
    "docs\docs-map-schema.md",
    "docs\project-integrations.md",
    "docs\autonomous-agent-orchestration.md",
    "prompting\README.md",
    "prompting\plan-then-build.md",
    "prompting\context-hygiene.md",
    "prompting\verify-loop.md",
    "prompting\lean-prompts-autonomy.md",
    "roles\README.md",
    "roles\implementer.md",
    "roles\reviewer.md",
    "subagents\README.md",
    "subagents\verifier.md",
    ".cursor\skills\autonomous-task",
    ".cursor\skills\maintain-project-docs",
    ".cursor\skills\browser-verify",
    ".cursor\skills\setup-project-environment",
    "scripts\project-doctor.ps1",
    "scripts\validate-project-docs.ps1",
    "docs\project-environment.md",
    "docs\cursor-native-controls.md",
    "docs\project-state.md",
    ".cursor\rules\autonomous-orchestration.mdc",
    ".cursor\rules\project-docs-lifecycle.mdc",
    ".cursor\agents\operational-orchestrator.md",
    ".cursor\agents\implementer.md",
    ".cursor\agents\adversarial-reviewer.md",
    ".cursor\agents\verifier.md",
    ".cursor\agents\principal-arbiter.md"
)

foreach ($p in $essentialFiles) {
    if ($p -eq "docs\project-state.md") {
        Copy-FileTo "templates\project-state.md" "docs\project-state.md"
        continue
    }
    Copy-Path $p
}

Copy-Path ".cursor\skills\review-papercuts"
Copy-Path ".cursor\rules\skills-ru-description.mdc"
Copy-FileTo "templates\project-rules\product-core.mdc" ".cursor\rules\product-core.mdc" -Always

Merge-PapercutsHooks
Ensure-AgentsHarnessSnippet

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
        "scripts\validate-mcp-profiles.ps1",
        "templates\mcp",
        "templates\cursor",
        "templates\hooks",
        "scripts\validate-living-evals.ps1",
        "tests\living-eval",
        "scripts\validate-recovery.ps1",
        "tests\recovery",
        ".cursor\skills",
        ".cursor\rules",
        ".cursor\agents",
        ".cursor\hooks.json",
        ".cursor\hooks"
    )
    foreach ($p in $full) { Merge-CopyPath $p }
}

if ($WithSubmodule) {
    $vendor = Join-Path $Target "vendor\cursor-project-toolkit"
    if (Test-Path $vendor) {
        Write-Host "exists: vendor/cursor-project-toolkit (skip submodule)"
    } else {
        Push-Location -LiteralPath $Target
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

$skipUserHome = $SkipUserHome -or ($env:CPTK_PORTABILITY_SMOKE -eq "1")
if (-not $skipUserHome) {
    if (-not [Environment]::GetEnvironmentVariable("HOME", "User")) {
        [Environment]::SetEnvironmentVariable("HOME", $env:USERPROFILE, "User")
        Write-Host "Set User HOME=$env:USERPROFILE (new terminals will see it)"
    }
} else {
    Write-Host "Skip User-scope HOME (SkipUserHome or CPTK_PORTABILITY_SMOKE=1)"
}

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

if (-not $SkipNext) {
    Write-Host ""
    Write-Host "Done. Next:"
    Write-Host "  1. cd `"$Target`""
    Write-Host "  2. Open folder in Cursor"
    Write-Host "  3. Optional: cargo install papercuts  (or use scripts/papercuts.ps1)"
    Write-Host "  4. /add-plugin cursor-team-kit"
    Write-Host "  5. Optional local harness plugin: plugin/cursor-project-harness (see docs/harness-as-cursor-plugin.md)"
    Write-Host "  6. Start building - hooks auto-log failed shells to .papercuts.jsonl"
    if ($WithSubmodule) {
        Write-Host "  7. Toolkit reference: vendor/cursor-project-toolkit (submodule)"
    }
} else {
    Write-Host ""
    Write-Host "Bootstrap $Mode done (SkipNext)."
}

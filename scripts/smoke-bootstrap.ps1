<#
.SYNOPSIS
  Smoke-test Essential bootstrap + papercuts shim + new-project (B1-B3 + C1 junction).
#>
param(
    [string]$TargetPath = (Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) "_toolkit-smoke-test"),

    [switch]$KeepOnFailure
)

$ErrorActionPreference = "Stop"
$ToolkitRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$fail = 0
$NewProjectPs1 = Join-Path $ToolkitRoot "scripts\new-project.ps1"
$EmDash = [char]0x2014
$TargetCreated = $false

function Assert-True($cond, $msg) {
    if ($cond) {
        Write-Host "OK  $msg"
    } else {
        Write-Host "FAIL $msg"
        $script:fail++
    }
}

function Invoke-Ps1File {
    param(
        [Parameter(Mandatory = $true)][string]$File,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$ArgList
    )
    # Capture child streams so only the int exit code is returned (not stdout).
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $File @ArgList 2>&1
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevEap
    }
    foreach ($line in @($output)) {
        Write-Host $line
    }
    if ($null -eq $code) { $code = 0 }
    return [int]$code
}

Write-Host "=== Smoke bootstrap ==="
Write-Host "Toolkit: $ToolkitRoot"
Write-Host "Target:  $TargetPath"

$validatorPath = Join-Path $PSScriptRoot "validate-orchestration.ps1"
if (Test-Path $validatorPath) {
    $validatorCode = Invoke-Ps1File -File $validatorPath -SelfTest
    Assert-True ($validatorCode -eq 0) "orchestration validator exit 0"
} else {
    Write-Host "SKIP orchestration validator (toolkit-only script not shipped in Full)"
}

$sessionTestPath = Join-Path $PSScriptRoot "test-session-start-context.ps1"
Assert-True (Test-Path $sessionTestPath) "test-session-start-context.ps1 exists (V-SESSION required)"
Write-Host ""
Write-Host "=== V-SESSION session-start selftest ==="
# Each case uses Invoke-SessionHook's 6s watchdog; full suite completes in <45s.
$prevEapSession = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $sessionOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $sessionTestPath 2>&1 | Out-String
    $sessionCode = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $prevEapSession
}
Write-Host $sessionOutput
Assert-True ($sessionCode -eq 0) "V-SESSION exit 0"
Assert-True ($sessionOutput -match "SESSION_CONTEXT_TEST_PASS") "V-SESSION prints SESSION_CONTEXT_TEST_PASS"

$doctorLeakPath = Join-Path $ToolkitRoot "tests\project-doctor\test-secret-leak.ps1"
if (Test-Path $doctorLeakPath) {
    Write-Host ""
    Write-Host "=== project-doctor secret leak selftest ==="
    $leakCode = Invoke-Ps1File -File $doctorLeakPath
    Assert-True ($leakCode -eq 0) "doctor leak selftest exit 0"
}

$doctorBracketPath = Join-Path $ToolkitRoot "tests\project-doctor\test-bracket-path.ps1"
if (Test-Path $doctorBracketPath) {
    Write-Host ""
    Write-Host "=== project-doctor bracket path selftest ==="
    $bracketCode = Invoke-Ps1File -File $doctorBracketPath
    Assert-True ($bracketCode -eq 0) "doctor bracket selftest exit 0"
}

$doctorMissingPhasePath = Join-Path $ToolkitRoot "tests\project-doctor\test-missing-phase.ps1"
if (Test-Path $doctorMissingPhasePath) {
    Write-Host ""
    Write-Host "=== project-doctor missing phase selftest ==="
    $missingPhaseCode = Invoke-Ps1File -File $doctorMissingPhasePath
    Assert-True ($missingPhaseCode -eq 0) "doctor missing phase selftest exit 0"
}

if (Test-Path $TargetPath) {
    Remove-Item -Recurse -Force $TargetPath
}
New-Item -ItemType Directory -Force -Path $TargetPath | Out-Null
$TargetCreated = $true

try {
$code = Invoke-Ps1File (Join-Path $ToolkitRoot "scripts\bootstrap-into-project.ps1") `
    -TargetPath $TargetPath -Mode Essential
if ($code -ne 0) {
    Write-Host "FAIL bootstrap exit=$code"
    $fail++
}

$mustExist = @(
    ".cursor\hooks.json",
    ".cursor\hooks\session-start.ps1",
    ".cursor\hooks\after-shell-papercuts.ps1",
    ".cursor\hooks\stop-papercuts-nudge.ps1",
    ".cursor\skills\review-papercuts\SKILL.md",
    ".cursor\skills\autonomous-task\SKILL.md",
    ".cursor\skills\autonomous-task\tier-rubric.md",
    ".cursor\skills\autonomous-task\contracts.md",
    ".cursor\skills\maintain-project-docs\SKILL.md",
    ".cursor\skills\browser-verify\SKILL.md",
    ".cursor\skills\setup-project-environment\SKILL.md",
    "scripts\project-doctor.ps1",
    "scripts\validate-project-docs.ps1",
    "docs\project-environment.md",
    "docs\cursor-native-controls.md",
    "docs\project-state.md",
    ".cursor\rules\product-core.mdc",
    ".cursor\rules\skills-ru-description.mdc",
    ".cursor\rules\autonomous-orchestration.mdc",
    ".cursor\rules\project-docs-lifecycle.mdc",
    ".cursor\agents\operational-orchestrator.md",
    ".cursor\agents\implementer.md",
    ".cursor\agents\adversarial-reviewer.md",
    ".cursor\agents\verifier.md",
    ".cursor\agents\principal-arbiter.md",
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
    "subagents\verifier.md"
)

$mustAbsent = @(
    "SOURCES.md",
    "archive",
    ".cursor\mcp.json",
    "templates\mcp",
    ".cursor\skills\ship-toolkit",
    ".cursor\skills\add-source",
    ".cursor\skills\bootstrap-project",
    ".cursor\skills\distill-doc",
    ".cursor\skills\configure-project-integrations",
    ".cursor\skills\review-harness-evidence",
    ".cursor\rules\toolkit-core.mdc",
    ".cursor\rules\docs-ai-first.mdc",
    "prompting\constraint-first.md",
    "roles\docs-distiller.md",
    "subagents\explorer.md",
    "docs\product-brief.md",
    "docs\first-chat.md",
    "docs\docs-map.json",
    "docs\memory-and-obsidian.md",
    "docs\mcp-security.md",
    "scripts\validate-mcp-profiles.ps1",
    "templates\cursor",
    ".cursor\permissions.json",
    ".cursor\sandbox.json",
    ".cursor\environment.json",
    ".cursor\BUGBOT.md",
    "templates\hooks",
    "scripts\validate-living-evals.ps1",
    "tests\living-eval"
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

$secretPatterns = @(
    '(?i)Bearer\s+[^{\s]',
    '\b(sk-|ghp_|gho_|xox[baprs]-|AIza)',
    'BEGIN (RSA |OPENSSH )?PRIVATE KEY'
)
$scanRoots = @(
    (Join-Path $TargetPath ".cursor"),
    (Join-Path $TargetPath "docs"),
    (Join-Path $TargetPath "scripts")
)
foreach ($scanRoot in $scanRoots) {
    if (-not (Test-Path $scanRoot)) { continue }
    $files = @(Get-ChildItem -LiteralPath $scanRoot -Recurse -File -ErrorAction SilentlyContinue)
    foreach ($f in $files) {
        if ($f.Extension -notin @(".md", ".mdc", ".json", ".ps1", ".cmd")) { continue }
        $content = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        if ([string]::IsNullOrEmpty($content)) { continue }
        foreach ($pat in $secretPatterns) {
            if ($content -match $pat) {
                $rel = $f.FullName.Substring($TargetPath.Length).TrimStart('\', '/')
                Assert-True $false "no secret pattern in Essential $rel"
                break
            }
        }
    }
}

$gaPath = Join-Path $TargetPath ".gitattributes"
if (Test-Path $gaPath) {
    $ga = Get-Content $gaPath -Raw
    Assert-True ($ga -match "(?m)^\.papercuts\.jsonl\s+merge=union\s*$") ".gitattributes has papercuts merge=union"
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
    $code = Invoke-Ps1File ".\scripts\papercuts.ps1" `
        add "smoke: bootstrap harness verified" -Tag smoke -Severity minor
    Assert-True ($code -eq 0) "papercuts add exit 0"
    Assert-True (Test-Path ".\.papercuts.jsonl") ".papercuts.jsonl created in target"

    $lines = @(Get-Content ".\.papercuts.jsonl" -Encoding utf8)
    Assert-True ($lines.Count -ge 1) "at least one JSONL line"

    $rec = $lines[-1] | ConvertFrom-Json
    Assert-True ($rec.kind -eq "cut") "record kind=cut"
    Write-Host "    id=$($rec.id)"

    $null = Invoke-Ps1File ".\scripts\papercuts.ps1" list -Format md

    $hooks = Get-Content ".\.cursor\hooks.json" -Raw | ConvertFrom-Json
    Assert-True ($null -ne $hooks) "hooks.json parses"
} finally {
    Pop-Location
}

Assert-True (Test-Path (Join-Path $TargetPath ".papercuts.jsonl")) "target has its own .papercuts.jsonl"

$productValidator = Join-Path $TargetPath "scripts\validate-project-docs.ps1"
if (Test-Path $productValidator) {
    Write-Host ""
    Write-Host "=== Product-local validate-project-docs ==="
    $miniRoot = Join-Path $env:TEMP ("cptk-val-smoke-" + [guid]::NewGuid().ToString("n"))
    try {
        New-Item -ItemType Directory -Force -Path (Join-Path $miniRoot "docs") | Out-Null
        Set-Content -LiteralPath (Join-Path $miniRoot "docs\sample.md") -Value "# smoke sample" -Encoding utf8
        $miniMap = @'
{
  "version": 1,
  "entries": [
    {
      "path": "docs/sample.md",
      "title": "Smoke sample",
      "status": "active",
      "owners": ["team"]
    }
  ]
}
'@
        Set-Content -LiteralPath (Join-Path $miniRoot "docs\docs-map.json") -Value $miniMap -Encoding utf8
        $valCode = Invoke-Ps1File -File $productValidator -ProjectRoot $miniRoot
        Assert-True ($valCode -eq 0) "product-local validate-project-docs exit 0 on synthetic map"
    } finally {
        Remove-Item -Recurse -Force $miniRoot -ErrorAction SilentlyContinue
    }
} else {
    Assert-True $false "product ships validate-project-docs.ps1"
}

Write-Host ""
Write-Host "=== Smoke Full merge (Essential then Full, no -Force) ==="
$fullTarget = Join-Path $env:TEMP ("cptk-smoke-full-" + [guid]::NewGuid().ToString("n"))
$fullCreated = $false
try {
    $fullCode = Invoke-Ps1File (Join-Path $ToolkitRoot "scripts\bootstrap-into-project.ps1") `
        -TargetPath $fullTarget -Mode Essential
    Assert-True ($fullCode -eq 0) "Full-prep Essential bootstrap exit 0"
    $fullCode2 = Invoke-Ps1File (Join-Path $ToolkitRoot "scripts\bootstrap-into-project.ps1") `
        -TargetPath $fullTarget -Mode Full
    Assert-True ($fullCode2 -eq 0) "Full merge after Essential exit 0"
    $fullCreated = $true
    $fullMustExist = @(
        ".cursor\skills\configure-project-integrations\SKILL.md",
        ".cursor\agents\principal-arbiter.md",
        "docs\mcp-security.md",
        "docs\memory-and-obsidian.md",
        "templates\mcp",
        "templates\hooks",
        "scripts\validate-mcp-profiles.ps1",
        "scripts\validate-living-evals.ps1",
        "tests\living-eval\manifest.json"
    )
    foreach ($rel in $fullMustExist) {
        Assert-True (Test-Path (Join-Path $fullTarget $rel)) "Full has $rel"
    }
    $sentinelPath = Join-Path $fullTarget "docs\living-documentation.md"
    if (Test-Path $sentinelPath) {
        $sentinel = "FULL_MERGE_SENTINEL_" + [guid]::NewGuid().ToString("n")
        Set-Content -LiteralPath $sentinelPath -Value $sentinel -Encoding utf8
        $fullCode3 = Invoke-Ps1File (Join-Path $ToolkitRoot "scripts\bootstrap-into-project.ps1") `
            -TargetPath $fullTarget -Mode Full
        Assert-True ($fullCode3 -eq 0) "Full re-merge preserves existing exit 0"
        $after = Get-Content $sentinelPath -Raw -Encoding utf8
        Assert-True ($after -match [regex]::Escape($sentinel)) "Full merge preserves existing file without -Force"
    }
} finally {
    if ($fullCreated -and (Test-Path $fullTarget)) {
        Remove-Item -Recurse -Force $fullTarget -ErrorAction SilentlyContinue
    }
}

# --- new-project: clear Process env so Parent is not skewed ---
Write-Host ""
Write-Host "=== Smoke new-project ==="
$savedProjectsRoot = [Environment]::GetEnvironmentVariable("TOOLKIT_PROJECTS_ROOT", "Process")
[Environment]::SetEnvironmentVariable("TOOLKIT_PROJECTS_ROOT", $null, "Process")

$npParent = Join-Path $env:TEMP ("cptk-np-smoke-" + [guid]::NewGuid().ToString("n"))
$npName = "toolkit-new-project-smoke"
$npGoal = "smoke: new-project brief"
$npRoot = Join-Path $npParent $npName
$briefPath = Join-Path $npRoot "docs\product-brief.md"
$firstPath = Join-Path $npRoot "docs\first-chat.md"
$mapPath = Join-Path $npRoot "docs\docs-map.json"
$statePath = Join-Path $npRoot "docs\project-state.md"
$expectedBriefH1 = "# $npName $EmDash product brief"
$expectedAgentsH1 = "# $npName - agent instructions"
$jParent = Join-Path $env:TEMP ("cptk-np-junc-" + [guid]::NewGuid().ToString("n"))
$jLink = Join-Path $jParent "toolkit-link"
$leakName = "cptk-junction-leak"
$jCreated = $false

try {
    New-Item -ItemType Directory -Force -Path $npParent | Out-Null

    # B1 Happy path
    $code = Invoke-Ps1File $NewProjectPs1 -Name $npName -Parent $npParent -Goal $npGoal
    if ($code -ne 0) {
        Write-Host "FAIL new-project happy exit=$code"
        $fail++
    } else {
        Assert-True (Test-Path $npRoot) "new-project target exists"
        Assert-True (Test-Path (Join-Path $npRoot ".git")) "new-project has .git"
        Assert-True (Test-Path (Join-Path $npRoot ".cursor\rules\product-core.mdc")) "new-project has product-core"
        Assert-True (Test-Path (Join-Path $npRoot ".cursor\skills\review-papercuts\SKILL.md")) "new-project has review-papercuts"
        Assert-True (Test-Path (Join-Path $npRoot ".cursor\skills\autonomous-task\SKILL.md")) "new-project has autonomous-task"
        Assert-True (Test-Path (Join-Path $npRoot ".cursor\skills\autonomous-task\tier-rubric.md")) "new-project has tier rubric"
        Assert-True (Test-Path (Join-Path $npRoot ".cursor\skills\autonomous-task\contracts.md")) "new-project has contracts"
        Assert-True (Test-Path (Join-Path $npRoot ".cursor\rules\autonomous-orchestration.mdc")) "new-project has orchestration rule"
        Assert-True (Test-Path (Join-Path $npRoot ".cursor\agents\operational-orchestrator.md")) "new-project has orchestrator agent"
        Assert-True (Test-Path (Join-Path $npRoot ".cursor\agents\implementer.md")) "new-project has implementer agent"
        Assert-True (Test-Path (Join-Path $npRoot ".cursor\agents\adversarial-reviewer.md")) "new-project has reviewer agent"
        Assert-True (Test-Path (Join-Path $npRoot ".cursor\agents\verifier.md")) "new-project has verifier agent"
        Assert-True (Test-Path (Join-Path $npRoot ".cursor\agents\principal-arbiter.md")) "new-project has principal arbiter"
        Assert-True (Test-Path (Join-Path $npRoot "AGENTS.md")) "new-project has AGENTS.md"
        $npMustAbsent = @($mustAbsent | Where-Object {
            $_ -notin @("docs\product-brief.md", "docs\first-chat.md", "docs\docs-map.json")
        })
        foreach ($rel in $npMustAbsent) {
            Assert-True (-not (Test-Path (Join-Path $npRoot $rel))) "new-project no $rel"
        }

        Assert-True (Test-Path $briefPath) "new-project has docs/product-brief.md"
        Assert-True (Test-Path $firstPath) "new-project has docs/first-chat.md"
        Assert-True (Test-Path $mapPath) "new-project has docs/docs-map.json"
        Assert-True (Test-Path $statePath) "new-project has docs/project-state.md"
        if (Test-Path $mapPath) {
            $mapObj = $null
            try {
                $mapObj = Get-Content $mapPath -Raw -Encoding utf8 | ConvertFrom-Json
            } catch {
                $mapObj = $null
            }
            Assert-True ($null -ne $mapObj -and [int]$mapObj.version -eq 1) "docs-map.json version 1"
            Assert-True (@($mapObj.entries).Count -ge 1) "docs-map.json has entries"
            $stateEntry = @($mapObj.entries | Where-Object { [string]$_.path -eq "docs/project-state.md" })
            if ($stateEntry.Count -gt 0) {
                Assert-True ([string]$stateEntry[0].status -eq "active") "docs-map project-state status active"
            }
            $envEntry = @($mapObj.entries | Where-Object { [string]$_.path -eq "docs/project-environment.md" })
            if ($envEntry.Count -gt 0) {
                Assert-True ([string]$envEntry[0].status -eq "active") "docs-map project-environment status active"
            }
        }
        if (Test-Path $briefPath) {
            $briefLines = Get-Content $briefPath -Encoding utf8
            Assert-True ($briefLines.Count -gt 0 -and $briefLines[0] -eq $expectedBriefH1) "product-brief H1 exact"
            $briefTxt = Get-Content $briefPath -Raw -Encoding utf8
            Assert-True ($briefTxt -match [regex]::Escape($npGoal)) "product-brief contains Goal"
            Assert-True ($briefTxt -match "## For agents") "product-brief has For agents"
        }
        if (Test-Path $firstPath) {
            $firstTxt = Get-Content $firstPath -Raw -Encoding utf8
            Assert-True ($firstTxt -match [regex]::Escape($npGoal)) "first-chat contains Goal"
        }
        $agentsLines = @(Get-Content (Join-Path $npRoot "AGENTS.md") -Encoding utf8)
        Assert-True ($agentsLines.Count -gt 0 -and $agentsLines[0] -eq $expectedAgentsH1) "AGENTS H1 exact"

        # B2 AllowExisting preserves brief and docs-map
        $sentinel = "SMOKE_BRIEF_SENTINEL_" + [guid]::NewGuid().ToString("n")
        Set-Content -LiteralPath $briefPath -Value $sentinel -Encoding utf8
        $mapSentinel = "SMOKE_MAP_SENTINEL_" + [guid]::NewGuid().ToString("n")
        $stateSentinel = "SMOKE_STATE_SENTINEL_" + [guid]::NewGuid().ToString("n")
        if (Test-Path $mapPath) {
            $mapObj = Get-Content $mapPath -Raw -Encoding utf8 | ConvertFrom-Json
            $mapObj.entries[0].title = $mapSentinel
            $mapJson = $mapObj | ConvertTo-Json -Depth 10
            Set-Content -LiteralPath $mapPath -Value $mapJson -Encoding utf8
        }
        if (Test-Path $statePath) {
            Set-Content -LiteralPath $statePath -Value $stateSentinel -Encoding utf8
        }
        $code = Invoke-Ps1File $NewProjectPs1 -Name $npName -Parent $npParent -Goal "should-not-clobber" -AllowExisting
        Assert-True ($code -eq 0) "AllowExisting exit 0"
        if (Test-Path $briefPath) {
            $briefAfter = Get-Content $briefPath -Raw -Encoding utf8
            Assert-True ($briefAfter -match [regex]::Escape($sentinel)) "AllowExisting preserves brief sentinel"
            Assert-True ($briefAfter -notmatch "should-not-clobber") "AllowExisting does not rewrite brief Goal"
        } else {
            Assert-True $false "brief still exists after AllowExisting"
        }
        if (Test-Path $mapPath) {
            $mapAfter = Get-Content $mapPath -Raw -Encoding utf8 | ConvertFrom-Json
            $mapTitle = [string]$mapAfter.entries[0].title
            Assert-True ($mapTitle -eq $mapSentinel) "AllowExisting preserves docs-map sentinel title"
        } else {
            Assert-True $false "docs-map still exists after AllowExisting"
        }
        if (Test-Path $statePath) {
            $stateAfter = Get-Content $statePath -Raw -Encoding utf8
            Assert-True ($stateAfter -match [regex]::Escape($stateSentinel)) "AllowExisting preserves project-state sentinel"
        } else {
            Assert-True $false "project-state still exists after AllowExisting"
        }
    }

    # B3 Refuse non-empty without AllowExisting
    $refuseName = "toolkit-np-refuse"
    $refuseRoot = Join-Path $npParent $refuseName
    New-Item -ItemType Directory -Force -Path $refuseRoot | Out-Null
    $keepPath = Join-Path $refuseRoot "KEEP.txt"
    Set-Content -LiteralPath $keepPath -Value "KEEP" -Encoding ascii
    $code = Invoke-Ps1File $NewProjectPs1 -Name $refuseName -Parent $npParent -Goal "refuse"
    Assert-True ($code -ne 0) "refuse non-empty exit != 0"
    Assert-True ((Get-Content $keepPath -Raw -Encoding ascii).Trim() -eq "KEEP") "refuse left KEEP unchanged"
    Assert-True (-not (Test-Path (Join-Path $refuseRoot "AGENTS.md"))) "refuse did not bootstrap AGENTS"

    # C1 Junction Parent -> ToolkitRoot (separate TEMP; never recurse-delete junction)
    Write-Host ""
    Write-Host "=== Smoke new-project junction (C1) ==="
    New-Item -ItemType Directory -Force -Path $jParent | Out-Null
    try {
        New-Item -ItemType Junction -Path $jLink -Target $ToolkitRoot | Out-Null
        $jCreated = $true
    } catch {
        Write-Host "FAIL junction create: $($_.Exception.Message)"
        $fail++
    }
    if ($jCreated) {
        $code = Invoke-Ps1File $NewProjectPs1 -Name $leakName -Parent $jLink -Goal "junction"
        Assert-True ($code -ne 0) "junction Parent->toolkit exit != 0"
        Assert-True (-not (Test-Path (Join-Path $ToolkitRoot $leakName))) "no leak under ToolkitRoot"
    }
} finally {
    if (Test-Path $npParent) {
        Remove-Item -Recurse -Force $npParent -ErrorAction SilentlyContinue
    }
    if ($jCreated -and (Test-Path -LiteralPath $jLink)) {
        cmd /c "rmdir `"$jLink`""
    }
    if (Test-Path $jParent) {
        Remove-Item -Recurse -Force $jParent -ErrorAction SilentlyContinue
    }
    [Environment]::SetEnvironmentVariable("TOOLKIT_PROJECTS_ROOT", $savedProjectsRoot, "Process")
}

if ($fail -eq 0) {
    $portPath = Join-Path $PSScriptRoot "smoke-portability.ps1"
    if (Test-Path $portPath) {
        Write-Host ""
        Write-Host "=== Smoke portability (optional nested) ==="
        $savedSkipPort = [Environment]::GetEnvironmentVariable("CPTK_SKIP_PORTABILITY", "Process")
        $savedNestedReentry = [Environment]::GetEnvironmentVariable("CPTK_PORTABILITY_NESTED_REENTRY", "Process")
        [Environment]::SetEnvironmentVariable("CPTK_SKIP_PORTABILITY", $null, "Process")
        [Environment]::SetEnvironmentVariable("CPTK_PORTABILITY_NESTED_REENTRY", $null, "Process")
        $prevEapPort = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $portOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $portPath 2>&1 | Out-String
            $portCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $prevEapPort
            if ($null -eq $savedSkipPort) {
                [Environment]::SetEnvironmentVariable("CPTK_SKIP_PORTABILITY", $null, "Process")
            } else {
                [Environment]::SetEnvironmentVariable("CPTK_SKIP_PORTABILITY", $savedSkipPort, "Process")
            }
            if ($null -eq $savedNestedReentry) {
                [Environment]::SetEnvironmentVariable("CPTK_PORTABILITY_NESTED_REENTRY", $null, "Process")
            } else {
                [Environment]::SetEnvironmentVariable("CPTK_PORTABILITY_NESTED_REENTRY", $savedNestedReentry, "Process")
            }
        }
        Write-Host $portOutput
        Assert-True ($portOutput -notmatch "PORTABILITY_SMOKE_SKIP") "smoke-portability did not skip"
        Assert-True ($portOutput -match "PORTABILITY_SMOKE_PASS") "smoke-portability prints PORTABILITY_SMOKE_PASS"
        Assert-True ($portCode -eq 0) "smoke-portability exit 0"
    }
}

Write-Host ""
if ($fail -eq 0) {
    Write-Host "SMOKE PASS ($TargetPath + new-project B1-B3 + C1 + Full merge)"
    exit 0
} else {
    Write-Host "SMOKE FAIL: $fail assertion(s)"
    exit 1
}
} finally {
    if ($TargetCreated -and (Test-Path $TargetPath)) {
        if ($fail -eq 0 -or -not $KeepOnFailure) {
            Remove-Item -Recurse -Force $TargetPath -ErrorAction SilentlyContinue
        } else {
            Write-Host "KEEP on failure (-KeepOnFailure): $TargetPath"
        }
    }
}

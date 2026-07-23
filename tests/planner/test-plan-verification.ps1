<#
.SYNOPSIS
  Integration tests for shadow changed-path verification planner (Wave 6).
#>
$ErrorActionPreference = "Stop"
$ToolkitRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$PlannerScript = Join-Path $ToolkitRoot "scripts\plan-verification.ps1"
$ManifestPath = Join-Path $ToolkitRoot "shipping\verification-checks.v1.json"
$VerifyHarness = Join-Path $ToolkitRoot "scripts\verify-harness.ps1"
$WorkflowPath = Join-Path $ToolkitRoot ".github\workflows\toolkit-verify.yml"
$fail = 0

function Assert-True($cond, [string]$msg) {
    if ($cond) { Write-Host "OK  $msg" } else { Write-Host "FAIL $msg"; $script:fail++ }
}

function Invoke-PwshFile {
    param([string]$Script, [string[]]$ScriptArgs)
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script @ScriptArgs 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    foreach ($line in $out) { Write-Host $line }
    return $code
}

function Test-FixtureOracle {
    param([string]$FixturePath)
    $raw = [System.IO.File]::ReadAllText($FixturePath, (New-Object System.Text.UTF8Encoding $false))
    $fx = $raw | ConvertFrom-Json
    $tempSpec = Join-Path $env:TEMP ("cptk-planner-spec-" + [guid]::NewGuid().ToString("n") + ".json")
    $tempOut = Join-Path $env:TEMP ("cptk-planner-fx-" + [guid]::NewGuid().ToString("n") + ".json")
    $mode = if ($null -ne $fx.mode) { [string]$fx.mode } else { "worktree" }
    $specObj = [ordered]@{
        paths = @($fx.paths)
        flags = $fx.flags
    }
    if ($null -ne $fx.mode) { $specObj.mode = [string]$fx.mode }
    ($specObj | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $tempSpec -Encoding UTF8
    try {
        $code = Invoke-PwshFile -Script $PlannerScript -ScriptArgs @(
            "-Mode", $mode, "-ChangeSpecPath", $tempSpec, "-OutputPath", $tempOut
        )
    } finally {
        Remove-Item -LiteralPath $tempSpec -Force -ErrorAction SilentlyContinue
    }
    Assert-True ($code -eq 0) ("fixture run exit 0: " + (Split-Path -Leaf $FixturePath))
    $plan = ([System.IO.File]::ReadAllText($tempOut, (New-Object System.Text.UTF8Encoding $false)) | ConvertFrom-Json)
    Assert-True ([bool]$plan.shadow_only) "shadow_only: " + (Split-Path -Leaf $FixturePath)
    Assert-True (-not [bool]$plan.runs_checks) "runs_checks false: " + (Split-Path -Leaf $FixturePath)
    Assert-True ($plan.promotion_status -eq "evidence_pending") "promotion pending: " + (Split-Path -Leaf $FixturePath)
    Assert-True ([string]$plan.recommended_profile -ceq [string]$fx.expected.recommended_profile) "profile: " + (Split-Path -Leaf $FixturePath)
    Assert-True ([bool]$plan.conservative_full -eq [bool]$fx.expected.conservative_full) "conservative: " + (Split-Path -Leaf $FixturePath)
    if ($null -ne $fx.expected.triggers) {
        foreach ($t in @($fx.expected.triggers)) {
            Assert-True (@($plan.full_triggers_fired) -contains [string]$t) ("trigger " + $t + ": " + (Split-Path -Leaf $FixturePath))
        }
    }
    if ($null -ne $fx.expected.must_include) {
        foreach ($id in @($fx.expected.must_include)) {
            Assert-True (@($plan.selected_check_ids) -contains [string]$id) ("includes " + $id + ": " + (Split-Path -Leaf $FixturePath))
        }
    }
    if ([bool]$fx.expected.must_include_all_full_oracle) {
        foreach ($id in @($plan.full_oracle_check_ids)) {
            Assert-True (@($plan.selected_check_ids) -contains [string]$id) ("full oracle " + $id + ": " + (Split-Path -Leaf $FixturePath))
        }
    }
    if ($null -ne $fx.expected.must_not_include_full_oracle_only -and [bool]$fx.expected.must_not_include_full_oracle_only) {
        foreach ($oid in @($plan.full_oracle_only_ids)) {
            Assert-True (@($plan.selected_check_ids) -notcontains [string]$oid) ("excludes full-oracle-only " + $oid + ": " + (Split-Path -Leaf $FixturePath))
        }
    }
    if ($null -ne $fx.expected.path_classes) {
        foreach ($prop in $fx.expected.path_classes.PSObject.Properties) {
            Assert-True ([string]$plan.path_classes.($prop.Name) -ceq [string]$prop.Value) ("class " + $prop.Name + ": " + (Split-Path -Leaf $FixturePath))
        }
    }
    Assert-True (-not [bool]$plan.selector_miss) "no selector miss: " + (Split-Path -Leaf $FixturePath)
    Remove-Item -LiteralPath $tempOut -Force -ErrorAction SilentlyContinue
}

Write-Host "=== test-plan-verification integration ==="
Assert-True (Test-Path -LiteralPath $PlannerScript) "planner script exists"
Assert-True (Test-Path -LiteralPath $ManifestPath) "verification manifest exists"
Assert-True ((Invoke-PwshFile -Script $PlannerScript -ScriptArgs @("-SelfTest")) -eq 0) "planner SelfTest"

$workflowText = [System.IO.File]::ReadAllText($WorkflowPath, (New-Object System.Text.UTF8Encoding $false))
Assert-True ($workflowText -notmatch 'plan-verification') "CI workflow unchanged (no planner wiring)"
Assert-True ($workflowText -notmatch 'paths:') "CI workflow no paths filter"

$verifyText = [System.IO.File]::ReadAllText($VerifyHarness, (New-Object System.Text.UTF8Encoding $false))
Assert-True ($verifyText -notmatch 'plan-verification') "verify-harness independent of planner"

Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot "fixtures") -Filter "*.json" | ForEach-Object {
    Test-FixtureOracle -FixturePath $_.FullName
}

function Invoke-GitInRepo {
    param([string]$RepoRoot, [string[]]$GitArgs)
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    Push-Location -LiteralPath $RepoRoot
    try {
        & git @GitArgs 2>&1 | Out-Null
        $code = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    $ErrorActionPreference = $prevEap
    return @{ ExitCode = [int]$code }
}

$gitRepoRoot = Join-Path $env:TEMP ("cptk planner git " + [guid]::NewGuid().ToString("n"))
New-Item -ItemType Directory -Force -Path $gitRepoRoot | Out-Null
try {
    Invoke-GitInRepo -RepoRoot $gitRepoRoot -GitArgs @("init") | Out-Null
    Invoke-GitInRepo -RepoRoot $gitRepoRoot -GitArgs @("config", "user.email", "planner@test.local") | Out-Null
    Invoke-GitInRepo -RepoRoot $gitRepoRoot -GitArgs @("config", "user.name", "planner-test") | Out-Null

    $docsDir = Join-Path $gitRepoRoot "docs"
    New-Item -ItemType Directory -Force -Path $docsDir | Out-Null
    $unicodeName = "café file.ps1"
    $unicodePath = Join-Path $docsDir $unicodeName
    [System.IO.File]::WriteAllText($unicodePath, "# unicode`n", (New-Object System.Text.UTF8Encoding $false))
    # Tab in path names is exercised in planner SelfTest porcelain bytes; Windows rejects tab in filenames.
    $spaceName = "has  two spaces.ps1"
    $spacePath = Join-Path $docsDir $spaceName
    [System.IO.File]::WriteAllText($spacePath, "# spaces`n", (New-Object System.Text.UTF8Encoding $false))
    $oldRename = Join-Path $docsDir "old spaced.ps1"
    [System.IO.File]::WriteAllText($oldRename, "# old`n", (New-Object System.Text.UTF8Encoding $false))
    Invoke-GitInRepo -RepoRoot $gitRepoRoot -GitArgs @("add", ".") | Out-Null
    Invoke-GitInRepo -RepoRoot $gitRepoRoot -GitArgs @("commit", "-m", "init") | Out-Null

    $mv = Invoke-GitInRepo -RepoRoot $gitRepoRoot -GitArgs @("mv", "docs/old spaced.ps1", "docs/new spaced.ps1")
    Assert-True ($mv.ExitCode -eq 0) "git mv rename exit 0"
    [System.IO.File]::WriteAllText((Join-Path $docsDir "untracked spaced.ps1"), "# u`n", (New-Object System.Text.UTF8Encoding $false))
    [System.IO.File]::WriteAllText($spacePath, "# spaces modified`n", (New-Object System.Text.UTF8Encoding $false))
    [System.IO.File]::WriteAllText($unicodePath, "# unicode modified`n", (New-Object System.Text.UTF8Encoding $false))

    $gitPlanOut = Join-Path $env:TEMP ("cptk-planner-git-out-" + [guid]::NewGuid().ToString("n") + ".json")
    Assert-True ((Invoke-PwshFile -Script $PlannerScript -ScriptArgs @(
            "-Mode", "worktree", "-ProjectRoot", $gitRepoRoot, "-OutputPath", $gitPlanOut
        )) -eq 0) "disposable git repo planner exit 0"
    $gitPlan = ([System.IO.File]::ReadAllText($gitPlanOut, (New-Object System.Text.UTF8Encoding $false)) | ConvertFrom-Json)
    Assert-True ([string]::IsNullOrWhiteSpace([string]$gitPlan.gather_error_code)) "git gather no gather_error_code"
    Assert-True (@($gitPlan.full_triggers_fired) -notcontains "parse_error") "git gather not parse_error"
    Assert-True (@($gitPlan.changed_paths).Count -gt 0) "git gather real changed_paths"
    Assert-True (@($gitPlan.full_triggers_fired) -notcontains "merge_conflict") "no false merge_conflict"
    Assert-True (@($gitPlan.changed_paths) -contains "docs/new spaced.ps1") "git gather rename new path"
    Assert-True (@($gitPlan.changed_paths) -contains "docs/old spaced.ps1") "git gather rename old path"
    Assert-True (@($gitPlan.changed_paths) -contains "docs/untracked spaced.ps1") "git gather untracked path"
    Assert-True (@($gitPlan.changed_paths) -contains "docs/has  two spaces.ps1") "git gather spaced path unstaged"
    Assert-True (@($gitPlan.changed_paths) -contains "docs/café file.ps1") "git gather unicode path unstaged"
    Remove-Item -LiteralPath $gitPlanOut -Force -ErrorAction SilentlyContinue

    $noHistRoot = Join-Path $env:TEMP ("cptk-planner-nohist-" + [guid]::NewGuid().ToString("n"))
    New-Item -ItemType Directory -Force -Path $noHistRoot | Out-Null
    Invoke-GitInRepo -RepoRoot $noHistRoot -GitArgs @("init") | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $noHistRoot "README.md"), "x", (New-Object System.Text.UTF8Encoding $false))
    $noHistOut = Join-Path $env:TEMP ("cptk-planner-nohist-out-" + [guid]::NewGuid().ToString("n") + ".json")
    Assert-True ((Invoke-PwshFile -Script $PlannerScript -ScriptArgs @(
            "-Mode", "worktree", "-ProjectRoot", $noHistRoot, "-OutputPath", $noHistOut
        )) -eq 0) "missing history repo exit 0"
    $noHistPlan = ([System.IO.File]::ReadAllText($noHistOut, (New-Object System.Text.UTF8Encoding $false)) | ConvertFrom-Json)
    Assert-True ([bool]$noHistPlan.conservative_full) "missing history conservative Full"
    Assert-True (@($noHistPlan.full_triggers_fired) -contains "missing_history") "missing history trigger"
    Remove-Item -LiteralPath $noHistOut -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $noHistRoot -Recurse -Force -ErrorAction SilentlyContinue

    $badSpecOut = Join-Path $env:TEMP ("cptk-planner-badspec-out-" + [guid]::NewGuid().ToString("n") + ".json")
    $badSpecFile = Join-Path $env:TEMP ("cptk-planner-badspec-" + [guid]::NewGuid().ToString("n") + ".json")
    [System.IO.File]::WriteAllText($badSpecFile, "{not-json", (New-Object System.Text.UTF8Encoding $false))
    Assert-True ((Invoke-PwshFile -Script $PlannerScript -ScriptArgs @(
            "-Mode", "worktree", "-ChangeSpecPath", $badSpecFile, "-OutputPath", $badSpecOut
        )) -eq 0) "parse fallback exit 0"
    $badSpecPlan = ([System.IO.File]::ReadAllText($badSpecOut, (New-Object System.Text.UTF8Encoding $false)) | ConvertFrom-Json)
    Assert-True ([string]$badSpecPlan.gather_error_code -eq "parse_error") "parse fallback error code"
    Assert-True (@($badSpecPlan.full_triggers_fired) -contains "parse_error") "parse fallback trigger"
    Remove-Item -LiteralPath $badSpecOut, $badSpecFile -Force -ErrorAction SilentlyContinue
} finally {
    Remove-Item -LiteralPath $gitRepoRoot -Recurse -Force -ErrorAction SilentlyContinue
}

$smokeText = [System.IO.File]::ReadAllText((Join-Path $ToolkitRoot "scripts\smoke-bootstrap.ps1"), (New-Object System.Text.UTF8Encoding $false))
Assert-True ($smokeText -notmatch '"scripts\\plan-verification\.ps1"') "Essential excludes planner script"
Assert-True ($smokeText -notmatch '"tests\\planner"') "bootstrap excludes planner tests"

Push-Location -LiteralPath $ToolkitRoot
try {
    $ignore = & git check-ignore -v ".cursor/planner-local/" 2>$null
    Assert-True (-not [string]::IsNullOrWhiteSpace($ignore)) "gitignore covers planner local"
} finally {
    Pop-Location
}

Write-Host ""
if ($fail -eq 0) {
    Write-Host "PLAN_VERIFICATION_TEST_PASS"
    exit 0
}
Write-Host "PLAN_VERIFICATION_TEST_FAIL: $fail"
exit 1

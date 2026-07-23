<#
.SYNOPSIS
  Deterministic Fast vs standard A/B protocol plan generator — AB/BA order, one varied role, shared oracle checks.
  No live model calls; no pin/cost changes; promotion always evidence_pending until corpus thresholds.
  Toolkit-only; not Essential bootstrap.
#>
param(
    [string]$ContractId = "",
    [string]$TaskId = "",
    [int]$Seed = 0,
    [string]$VariedRole = "",
    [string[]]$CheckIds = @(),
    [string]$OutputPath = "",
    [switch]$SelfTest
)

$ErrorActionPreference = "Stop"
$ProtocolVersion = "v1"
$SchemaVersion = 1
$MinComparableTasks = 6
$MaxComparableTasks = 10
$VariedRoleChoices = @("implementer", "verifier", "operational-orchestrator")
$ModelPinByRole = @{
    "implementer" = "composer-2.5-fast"
    "verifier" = "cursor-grok-4.5-high-fast"
    "operational-orchestrator" = "cursor-grok-4.5-high-fast"
}
$DefaultCheckIds = @("Q-PARSE", "Q-ORCH-ST", "Q-DOCS")
$script:OwnedOutputPaths = New-Object System.Collections.Generic.List[string]
$script:Fail = 0

function Pass([string]$Message) { Write-Host "OK  $Message" }
function Fail([string]$Message) {
    Write-Host "FAIL $Message"
    $script:Fail++
}

function Assert-True($Condition, [string]$Message) {
    if ($Condition) { Pass $Message } else { Fail $Message }
}

function Get-Sha256Hex([byte[]]$Bytes) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($Bytes)).Replace("-", "").ToLowerInvariant())
    } finally {
        $sha.Dispose()
    }
}

function Get-SeededRandom {
    param([int]$Seed)
    return New-Object System.Random $Seed
}

function Resolve-VariedRole {
    param(
        [string]$Explicit,
        [int]$Seed
    )
    if (-not [string]::IsNullOrWhiteSpace($Explicit)) {
        if ($VariedRoleChoices -notcontains $Explicit) {
            throw "invalid varied role"
        }
        return $Explicit
    }
    $rng = Get-SeededRandom -Seed $Seed
    $idx = $rng.Next(0, $VariedRoleChoices.Count)
    return $VariedRoleChoices[$idx]
}

function New-ArmSpec {
    param(
        [string]$Label,
        [string]$Variant,
        [bool]$FastMode,
        [string]$VariedRole
    )
    $models = @{}
    foreach ($role in $VariedRoleChoices) {
        $models[$role] = $ModelPinByRole[$role]
    }
    return [ordered]@{
        label = $Label
        variant = $Variant
        fast_mode_used = $FastMode
        varied_role = $VariedRole
        intended_model = $ModelPinByRole[$VariedRole]
        actual_model = $null
        intended_models_by_role = $models
        live_model_calls = $false
    }
}

function New-AbProtocolPlan {
    param(
        [string]$ContractId,
        [string]$TaskId,
        [int]$Seed,
        [string]$VariedRole,
        [string[]]$CheckIds
    )
    if ([string]::IsNullOrWhiteSpace($ContractId)) { throw "contract_id required" }
    if ([string]::IsNullOrWhiteSpace($TaskId)) { throw "task_id required" }
    if ($CheckIds.Count -lt 1) { $CheckIds = $DefaultCheckIds }

    $role = Resolve-VariedRole -Explicit $VariedRole -Seed $Seed
    $fpSeed = $ContractId + "|" + $TaskId + "|" + $Seed
    $runFingerprint = (Get-Sha256Hex ([System.Text.Encoding]::UTF8.GetBytes($fpSeed))).Substring(0, 16)

    $armA = New-ArmSpec -Label "A" -Variant "standard" -FastMode $false -VariedRole $role
    $armB = New-ArmSpec -Label "B" -Variant "fast" -FastMode $true -VariedRole $role

    return [ordered]@{
        schema_version = $SchemaVersion
        protocol_version = $ProtocolVersion
        contract_id = $ContractId
        task_id = $TaskId
        seed = $Seed
        run_fingerprint = $runFingerprint
        promotion_status = "evidence_pending"
        promotion_thresholds = [ordered]@{
            min_comparable_tasks = $MinComparableTasks
            max_comparable_tasks = $MaxComparableTasks
            quality_gate = "first_verify_pass_rate"
            saving_gate = "wall_clock_delta_pct"
        }
        availability_defect_tracking = $true
        pin_or_cost_change = $false
        live_model_calls = $false
        oracle_check_ids = @($CheckIds)
        varied_role = $role
        arms = @(
            [ordered]@{
                sequence = "AB"
                order = @("A", "B")
                arm_A = $armA
                arm_B = $armB
            },
            [ordered]@{
                sequence = "BA"
                order = @("B", "A")
                arm_A = $armA
                arm_B = $armB
            }
        )
        worktree = [ordered]@{
            fresh_context = $true
            isolated_branch = $true
            run_fingerprint = $runFingerprint
        }
    }
}

function Test-IsReparsePoint([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $item = Get-Item -LiteralPath $Path -Force
    return (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Assert-NoReparseInPath([string]$Path, [string]$Label) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    $full = [System.IO.Path]::GetFullPath($Path)
    $current = $full
    while ($true) {
        if (Test-Path -LiteralPath $current) {
            if (Test-IsReparsePoint -Path $current) {
                throw ("reparse point rejected label=" + $Label)
            }
        }
        $parent = [System.IO.Path]::GetDirectoryName($current)
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $current) { break }
        $current = $parent
    }
}

function Resolve-SafeOutputPath {
    param([string]$Explicit)
    if ([string]::IsNullOrWhiteSpace($Explicit)) {
        $path = Join-Path $env:TEMP ("cptk-ab-plan-" + [guid]::NewGuid().ToString("n") + ".json")
    } else {
        $path = [System.IO.Path]::GetFullPath($Explicit)
    }
    if (Test-Path -LiteralPath $path) { throw "output path already exists" }
    Assert-NoReparseInPath -Path $path -Label "ab-plan target"
    $dir = Split-Path -Parent $path
    if (-not [string]::IsNullOrWhiteSpace($dir)) {
        Assert-NoReparseInPath -Path $dir -Label "ab-plan directory"
    }
    [void]$script:OwnedOutputPaths.Add($path)
    return $path
}

function Write-PlanAtomic {
    param(
        [object]$Plan,
        [string]$OutputPath
    )
    $json = ($Plan | ConvertTo-Json -Depth 10)
    $dir = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -LiteralPath $dir)) {
        [void][System.IO.Directory]::CreateDirectory($dir)
    }
    $temp = $OutputPath + ".tmp-" + [guid]::NewGuid().ToString("n")
    try {
        $lines = ($json -split "`r?`n" | ForEach-Object { $_.TrimEnd() }) -join "`n"
        [System.IO.File]::WriteAllText($temp, ($lines + "`n"), (New-Object System.Text.UTF8Encoding $false))
        [System.IO.File]::Move($temp, $OutputPath)
    } finally {
        if (Test-Path -LiteralPath $temp) {
            Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
        }
    }
}

function Test-PlanPrivacy([string]$JsonText) {
    $patterns = @(
        '@[^\s]+\.',
        '\\Users\\',
        '\\home\\',
        '://[^/]*@',
        '[A-Za-z]:\\'
    )
    foreach ($pattern in $patterns) {
        if ($JsonText -match $pattern) {
            throw "forbidden value pattern in plan"
        }
    }
    foreach ($field in @("username", "hostname", "absolute_path", "email", "plugin_inventory", "raw_prompt", "raw_log")) {
        if ($JsonText -match ('"' + [regex]::Escape($field) + '"\s*:')) {
            throw ("forbidden field in plan: " + $field)
        }
    }
}

function Invoke-SelfTest {
    $script:Fail = 0
    function Assert-Throws($scriptBlock, [string]$msg) {
        $threw = $false
        try { & $scriptBlock } catch { $threw = $true }
        if ($threw) { Pass $msg } else { Fail ($msg + " (no throw)") }
    }

    Write-Host "=== ab-protocol SelfTest ==="
    $plan1 = New-AbProtocolPlan -ContractId "ab-contract" -TaskId "task-1" -Seed 42 -VariedRole "implementer" `
        -CheckIds @("Q-ORCH-ST", "Q-PARSE")
    $plan2 = New-AbProtocolPlan -ContractId "ab-contract" -TaskId "task-1" -Seed 42 -VariedRole "implementer" `
        -CheckIds @("Q-ORCH-ST", "Q-PARSE")
    Assert-True ($plan1.run_fingerprint -eq $plan2.run_fingerprint) "seeded plan deterministic fingerprint"
    Assert-True ($plan1.varied_role -eq "implementer") "varied role preserved"
    Assert-True ($plan1.promotion_status -eq "evidence_pending") "promotion always evidence_pending"
    Assert-True ($plan1.live_model_calls -eq $false) "no live model calls"
    Assert-True ($plan1.pin_or_cost_change -eq $false) "no pin/cost change"
    Assert-True (@($plan1.oracle_check_ids).Count -eq 2) "shared oracle check ids"
    Assert-True ($plan1.arms[0].sequence -eq "AB") "AB sequence present"
    Assert-True ($plan1.arms[1].sequence -eq "BA") "BA sequence present"
    Assert-True ($plan1.arms[0].arm_A.variant -eq "standard") "arm A variant standard"
    Assert-True ($plan1.arms[0].arm_B.variant -eq "fast") "arm B variant fast"
    Assert-True ($plan1.arms[0].arm_A.intended_model -eq $plan1.arms[0].arm_B.intended_model) "model pin same across variants"
    Assert-True ($null -eq $plan1.arms[0].arm_A.actual_model) "actual_model nullable attribution"
    Assert-True ($plan1.arms[0].arm_A.fast_mode_used -eq $false) "arm A standard mode"
    Assert-True ($plan1.arms[0].arm_B.fast_mode_used -eq $true) "arm B fast mode"
    Assert-True ($plan1.worktree.fresh_context -eq $true) "fresh context metadata"
    Assert-True ($plan1.worktree.isolated_branch -eq $true) "isolated branch metadata"

    $planOtherSeed = New-AbProtocolPlan -ContractId "ab-contract" -TaskId "task-1" -Seed 99 -VariedRole "implementer"
    Assert-True ($planOtherSeed.run_fingerprint -ne $plan1.run_fingerprint) "different seed different fingerprint"

    $autoRoleA = Resolve-VariedRole -Explicit "" -Seed 42
    $autoRoleB = Resolve-VariedRole -Explicit "" -Seed 42
    Assert-True ($autoRoleA -eq $autoRoleB) "seed-auto varied role deterministic"
    $seenRoles = @{}
    for ($s = 1; $s -le 30; $s++) {
        $r = Resolve-VariedRole -Explicit "" -Seed $s
        $seenRoles[$r] = $true
    }
    Assert-True ($seenRoles.Count -eq $VariedRoleChoices.Count) "seed-auto varied role coverage"

    $json = ($plan1 | ConvertTo-Json -Depth 10)
    Test-PlanPrivacy -JsonText $json
    Pass "plan privacy scan"

    $tempRoot = Join-Path $env:TEMP ("cptk-ab-selftest-" + [guid]::NewGuid().ToString("n"))
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    try {
        $out = Resolve-SafeOutputPath -Explicit (Join-Path $tempRoot "plan.json")
        Write-PlanAtomic -Plan $plan1 -OutputPath $out
        Assert-True (Test-Path -LiteralPath $out) "plan written atomically"
        Assert-Throws { Resolve-SafeOutputPath -Explicit $out } "reject pre-existing plan path"
    } finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        foreach ($p in @($script:OwnedOutputPaths)) {
            Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
        }
        $script:OwnedOutputPaths.Clear()
    }

    Write-Host ""
    if ($script:Fail -eq 0) {
        Write-Host "AB_PROTOCOL_SELFTEST_PASS"
        exit 0
    }
    Write-Host "AB_PROTOCOL_SELFTEST_FAIL: $script:Fail"
    exit 1
}

if ($SelfTest) {
    Invoke-SelfTest
}

if ([string]::IsNullOrWhiteSpace($ContractId) -or [string]::IsNullOrWhiteSpace($TaskId)) {
    throw "ContractId and TaskId required"
}
if ($Seed -eq 0) {
    throw "Seed required (non-zero for deterministic plans)"
}
if ($CheckIds.Count -eq 0) { $CheckIds = $DefaultCheckIds }

$plan = New-AbProtocolPlan -ContractId $ContractId -TaskId $TaskId -Seed $Seed `
    -VariedRole $VariedRole -CheckIds $CheckIds
$json = ($plan | ConvertTo-Json -Depth 10)
Test-PlanPrivacy -JsonText $json

$dest = Resolve-SafeOutputPath -Explicit $OutputPath
Write-PlanAtomic -Plan $plan -OutputPath $dest
Write-Host "AB_PROTOCOL_OK plan=output=invocation-owned"
exit 0

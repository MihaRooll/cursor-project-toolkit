<#
.SYNOPSIS
  Integration tests for evidence sidecar writer/validator and A/B protocol planner.
#>
$ErrorActionPreference = "Stop"
$ToolkitRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$ValidateScript = Join-Path $ToolkitRoot "scripts\validate-evidence-sidecar.ps1"
$WriteScript = Join-Path $ToolkitRoot "scripts\write-evidence-sidecar.ps1"
$AbScript = Join-Path $ToolkitRoot "scripts\ab-protocol.ps1"
$SchemaPath = Join-Path $ToolkitRoot "tests\orchestration\evidence-schema.json"
$fail = 0

function Assert-True($cond, [string]$msg) {
    if ($cond) { Write-Host "OK  $msg" } else { Write-Host "FAIL $msg"; $script:fail++ }
}

Write-Host "=== test-evidence-sidecar ==="
Assert-True (Test-Path -LiteralPath $SchemaPath) "schema exists"
Assert-True (Test-Path -LiteralPath $ValidateScript) "validator exists"
Assert-True (Test-Path -LiteralPath $WriteScript) "writer exists"
Assert-True (Test-Path -LiteralPath $AbScript) "ab-protocol exists"

foreach ($script in @($ValidateScript, $WriteScript, $AbScript)) {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script -SelfTest 2>&1
    $ErrorActionPreference = $prevEap
    foreach ($line in $out) { Write-Host $line }
    $name = Split-Path -Leaf $script
    Assert-True ($LASTEXITCODE -eq 0) "$name SelfTest exit 0"
}

$tempRoot = Join-Path $env:TEMP ("cptk-evidence-int-" + [guid]::NewGuid().ToString("n"))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
$rowPath = Join-Path $tempRoot "row.json"
$planPath = Join-Path $tempRoot "plan.json"
try {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $AbScript `
        -ContractId "toolkit-fast-loop-v3" -TaskId "slice5a-integration" -Seed 42 `
        -VariedRole "implementer" -CheckIds @("Q-ORCH-ST") -OutputPath $planPath 2>&1 | ForEach-Object { Write-Host $_ }
    $ErrorActionPreference = $prevEap
    Assert-True ($LASTEXITCODE -eq 0) "ab-protocol integration exit 0"
    Assert-True (Test-Path -LiteralPath $planPath) "ab plan written"
    $planRaw = [System.IO.File]::ReadAllText($planPath, (New-Object System.Text.UTF8Encoding $false))
    Assert-True ($planRaw -notmatch '[A-Za-z]:\\') "ab plan has no absolute path"
    Assert-True ($planRaw -match '"variant"\s*:\s*"standard"') "ab plan includes standard variant"
    Assert-True ($planRaw -match '"variant"\s*:\s*"fast"') "ab plan includes fast variant"
    Assert-True ($planRaw -match 'evidence_pending') "ab plan promotion pending"

    Push-Location -LiteralPath $ToolkitRoot
    try {
        $ignoreLine = & git check-ignore -v ".cursor/evidence-local/" 2>$null
        Assert-True (-not [string]::IsNullOrWhiteSpace($ignoreLine)) "integration gitignore covers evidence-local"
    } finally {
        Pop-Location
    }

    $sample = [ordered]@{
        contract_id = "toolkit-fast-loop-v3"
        task_id = "slice5a-integration"
        run_fingerprint = ("int" + [guid]::NewGuid().ToString("n").Substring(0, 13))
        tier = "T2"
        wall_clock = 200
        verification_profile = "affected"
        verification_seconds = 60
        intended_role = "implementer"
        actual_role = "implementer"
        intended_model = "composer-2.5-fast"
        actual_model = "composer-2.5-fast"
        model_role_calls = @(@{ role = "implementer"; model = "composer-2.5-fast"; count = 1 })
        check_outcomes = @(@{ check_id = "Q-ORCH-ST"; outcome = "pass" })
        first_verify_pass = $true
        cycles = 0
        main_product_writes = 0
        false_escalation = $false
        protocol_violations = @()
        fast_mode_used = $false
        premium_calls = 0
        promotion_status = "evidence_pending"
        availability_defect = $false
    }
    ($sample | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $rowPath -Encoding UTF8
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $writeOut = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $WriteScript `
        -ProjectRoot $tempRoot -InputPath $rowPath -OutputPath (Join-Path $tempRoot "sidecar-out.json") 2>&1
    $ErrorActionPreference = $prevEap
    foreach ($line in $writeOut) {
        Write-Host $line
        Assert-True ($line -notmatch '[A-Za-z]:\\') "writer console no absolute path"
    }
    Assert-True ($LASTEXITCODE -eq 0) "writer integration exit 0"
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
if ($fail -eq 0) {
    Write-Host "EVIDENCE_SIDECAR_TEST_PASS"
    exit 0
}
Write-Host "EVIDENCE_SIDECAR_TEST_FAIL: $fail"
exit 1

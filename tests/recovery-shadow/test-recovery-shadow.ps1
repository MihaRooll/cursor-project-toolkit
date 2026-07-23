<#
.SYNOPSIS
  Integration tests for two-phase recovery shadow (Commit then Reveal). Toolkit-only.
#>
$ErrorActionPreference = "Stop"
$ToolkitRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$ShadowScript = Join-Path $ToolkitRoot "scripts\recovery-shadow.ps1"
$ShadowValidator = Join-Path $ToolkitRoot "scripts\validate-recovery-shadow.ps1"
$RecoveryValidator = Join-Path $ToolkitRoot "scripts\validate-recovery.ps1"
$SchemaPath = Join-Path $ToolkitRoot "tests\recovery-shadow\shadow-schema.json"
$LegacyShadowDir = Join-Path $ToolkitRoot "tests\recovery\shadow"
$fail = 0

function Assert-True($cond, [string]$msg) {
    if ($cond) { Write-Host "OK  $msg" } else { Write-Host "FAIL $msg"; $script:fail++ }
}

function Assert-ThrowsMsg($scriptBlock, [string]$token, [string]$msg) {
    $threw = $false
    $err = ""
    try { & $scriptBlock } catch { $threw = $true; $err = $_.Exception.Message }
    if (-not $threw) { Assert-True $false ($msg + " (no throw)"); return }
    if ($err -notlike ("*" + $token + "*")) {
        Assert-True $false ($msg + " token=" + $token + " got=" + $err)
        return
    }
    Assert-True $true $msg
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

Write-Host "=== test-recovery-shadow integration ==="
Assert-True (Test-Path -LiteralPath $ShadowScript) "recovery-shadow script exists"
Assert-True (Test-Path -LiteralPath $ShadowValidator) "validate-recovery-shadow exists"
Assert-True (Test-Path -LiteralPath $SchemaPath) "shadow schema at tests/recovery-shadow"
Assert-True (-not (Test-Path -LiteralPath $LegacyShadowDir)) "legacy tests/recovery/shadow absent"

Assert-True ((Invoke-PwshFile -Script $ShadowScript -ScriptArgs @("-SelfTest")) -eq 0) "recovery-shadow SelfTest"
Assert-True ((Invoke-PwshFile -Script $ShadowValidator -ScriptArgs @("-SelfTest")) -eq 0) "validate-recovery-shadow SelfTest"

$recoveryText = [System.IO.File]::ReadAllText($RecoveryValidator, (New-Object System.Text.UTF8Encoding $false))
Assert-True ($recoveryText -notmatch 'recovery-shadow') "production validate-recovery independent of shadow"
Assert-True ((Invoke-PwshFile -Script $RecoveryValidator -ScriptArgs @("-SelfTest")) -eq 0) "validate-recovery SelfTest unchanged"

$tempRoot = Join-Path $env:TEMP ("cptk-recovery-shadow-int-" + [guid]::NewGuid().ToString("n"))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
try {
    $commitInputPath = Join-Path $tempRoot "candidate.commit.json"
    $commitOutPath = Join-Path $tempRoot "candidate.commitment.json"
    $finalOutPath = Join-Path $tempRoot "candidate.final.json"

    $candidate = [ordered]@{
        candidate_id = "slice5b-integration"
        consumer_repo = "inkavrio_ru"
        tier = "T1"
        oracle = @{ available = $true; reliable = $true; check_id = "Q-ORCH-ST" }
        risk_tags = @()
        first_verdict = @{ family = "openai"; decision = "scout" }
        second_call_decision = "scout"
    }
    ($candidate | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $commitInputPath -Encoding UTF8

    Assert-True ((Invoke-PwshFile -Script $ShadowScript -ScriptArgs @(
            "-Action", "Commit", "-InputPath", $commitInputPath, "-OutputPath", $commitOutPath
        )) -eq 0) "Commit phase exit 0"
    Assert-True (Test-Path -LiteralPath $commitOutPath) "commitment record written"

    $secondJsonPath = Join-Path $tempRoot "second.verdict.json"
    $secondJson = '{"family":"claude","decision":"scout"}'
    [System.IO.File]::WriteAllText($secondJsonPath, $secondJson, (New-Object System.Text.UTF8Encoding $false))
    Assert-True ((Invoke-PwshFile -Script $ShadowScript -ScriptArgs @(
            "-Action", "Reveal", "-CommitmentPath", $commitOutPath,
            "-SecondVerdictPath", $secondJsonPath, "-OutputPath", $finalOutPath
        )) -eq 0) "Reveal phase exit 0"
    Assert-True (Test-Path -LiteralPath $finalOutPath) "final record written"

    $finalObj = ([System.IO.File]::ReadAllText($finalOutPath, (New-Object System.Text.UTF8Encoding $false)) | ConvertFrom-Json)
    Assert-True ($finalObj.record_type -eq "final") "final record_type"
    Assert-True ($finalObj.promotion_status -eq "evidence_pending") "promotion evidence_pending"
    Assert-True ($finalObj.live_model_calls -eq $false) "no live model calls"
    Assert-True ($finalObj.commitment.before_second_reveal -eq $true) "commitment before reveal preserved"
    Assert-True ($finalObj.protocol_sequence.Count -eq 4) "protocol sequence length"

    $replayOutAlt = Join-Path $tempRoot "candidate.final.replay.json"
    $replayCode = Invoke-PwshFile -Script $ShadowScript -ScriptArgs @(
        "-Action", "Reveal", "-CommitmentPath", $commitOutPath,
        "-SecondVerdictPath", $secondJsonPath, "-OutputPath", $replayOutAlt
    )
    Assert-True ($replayCode -ne 0) "reveal replay rejected"

    $rollbackInput = Join-Path $tempRoot "rollback.commit.json"
    $rollbackCommitOut = Join-Path $tempRoot "rollback.commitment.json"
    $rollbackBlockedFinal = Join-Path $tempRoot "rollback.final.blocked.json"
    $rollbackOkFinal = Join-Path $tempRoot "rollback.final.ok.json"
    $rollbackCandidate = [ordered]@{
        candidate_id = "rollback-marker-int"
        consumer_repo = "TG_BOT_PRO"
        tier = "T2"
        oracle = @{ available = $true; reliable = $true; check_id = "Q-PARSE" }
        risk_tags = @()
        first_verdict = @{ family = "openai"; decision = "retry" }
        second_call_decision = "retry"
    }
    ($rollbackCandidate | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $rollbackInput -Encoding UTF8
    Assert-True ((Invoke-PwshFile -Script $ShadowScript -ScriptArgs @(
            "-Action", "Commit", "-InputPath", $rollbackInput, "-OutputPath", $rollbackCommitOut
        )) -eq 0) "rollback scenario commit ok"
    [System.IO.File]::WriteAllText($rollbackBlockedFinal, "{}", (New-Object System.Text.UTF8Encoding $false))
    $rollbackFailCode = Invoke-PwshFile -Script $ShadowScript -ScriptArgs @(
        "-Action", "Reveal", "-CommitmentPath", $rollbackCommitOut,
        "-SecondVerdictPath", $secondJsonPath, "-OutputPath", $rollbackBlockedFinal
    )
    Assert-True ($rollbackFailCode -ne 0) "reveal fails when final output exists"
    $rollbackMarker = $rollbackCommitOut + ".reveal.lock"
    Assert-True (-not (Test-Path -LiteralPath $rollbackMarker)) "reveal marker rolled back after final CreateNew failure"
    Assert-True ((Invoke-PwshFile -Script $ShadowScript -ScriptArgs @(
            "-Action", "Reveal", "-CommitmentPath", $rollbackCommitOut,
            "-SecondVerdictPath", $secondJsonPath, "-OutputPath", $rollbackOkFinal
        )) -eq 0) "reveal succeeds after marker rollback"

    $oneShot = [ordered]@{
        candidate_id = "slice5b-oneshot"
        consumer_repo = "inkavrio_ru"
        tier = "T1"
        oracle = @{ available = $true; reliable = $true; check_id = "Q-ORCH-ST" }
        risk_tags = @()
        first_verdict = @{ family = "openai"; decision = "scout" }
        second_call_decision = "scout"
        second_verdict = @{ family = "claude"; decision = "scout" }
    }
    $oneShotPath = Join-Path $tempRoot "oneshot.json"
    ($oneShot | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $oneShotPath -Encoding UTF8
    $oneShotOut = Join-Path $tempRoot "oneshot.out.json"
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $oneShotRun = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ShadowScript `
        -Action Commit -InputPath $oneShotPath -OutputPath $oneShotOut 2>&1
    $oneShotCode = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    foreach ($line in $oneShotRun) { Write-Host $line }
    Assert-True ($oneShotCode -ne 0) "one-shot second_verdict rejected"

    $omitPath = Join-Path $tempRoot "omit-reliable.json"
    $omit = [ordered]@{
        candidate_id = "omit-reliable-int"
        consumer_repo = "TG_BOT_PRO"
        tier = "T2"
        oracle = @{ available = $true; check_id = "Q-PARSE" }
        risk_tags = @()
        first_verdict = @{ family = "openai"; decision = "retry" }
        second_call_decision = "retry"
    }
    ($omit | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $omitPath -Encoding UTF8
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $omitVal = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ShadowValidator `
        -InputPath $omitPath -SchemaKind commit_input 2>&1
    $omitValCode = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    foreach ($line in $omitVal) { Write-Host $line }
    Assert-True ($omitValCode -ne 0) "schema rejects oracle reliable omitted"

    $dupCode = Invoke-PwshFile -Script $ShadowScript -ScriptArgs @(
        "-Action", "Commit", "-InputPath", $commitInputPath, "-OutputPath", $commitOutPath
    )
    Assert-True ($dupCode -ne 0) "duplicate CreateNew rejected"

    $critInput = Join-Path $tempRoot "critical.commit.json"
    $critCommitOut = Join-Path $tempRoot "critical.commitment.json"
    $critFinalOut = Join-Path $tempRoot "critical.final.json"
    $crit = [ordered]@{
        candidate_id = "critical-int"
        consumer_repo = "TG_BOT_PRO"
        tier = "T2"
        oracle = @{ available = $true; reliable = $true; check_id = "Q-PARSE" }
        risk_tags = @()
        first_verdict = @{ family = "openai"; decision = "retry" }
        second_call_decision = "experiment"
    }
    ($crit | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $critInput -Encoding UTF8
    Assert-True ((Invoke-PwshFile -Script $ShadowScript -ScriptArgs @(
            "-Action", "Commit", "-InputPath", $critInput, "-OutputPath", $critCommitOut
        )) -eq 0) "critical commit ok"
    $critSecondPath = Join-Path $tempRoot "critical.second.json"
    [System.IO.File]::WriteAllText($critSecondPath, '{"family":"claude","decision":"blocked"}', (New-Object System.Text.UTF8Encoding $false))
    Assert-True ((Invoke-PwshFile -Script $ShadowScript -ScriptArgs @(
            "-Action", "Reveal", "-CommitmentPath", $critCommitOut,
            "-SecondVerdictPath", $critSecondPath, "-OutputPath", $critFinalOut
        )) -eq 0) "critical reveal ok"
    $critFinal = ([System.IO.File]::ReadAllText($critFinalOut, (New-Object System.Text.UTF8Encoding $false)) | ConvertFrom-Json)
    Assert-True ([bool]$critFinal.experiment_stopped) "critical miss stops experiment"

    Push-Location -LiteralPath $ToolkitRoot
    try {
        $ignore = & git check-ignore -v ".cursor/recovery-shadow-local/" 2>$null
        Assert-True (-not [string]::IsNullOrWhiteSpace($ignore)) "gitignore covers shadow local root"
        $smokeText = [System.IO.File]::ReadAllText((Join-Path $ToolkitRoot "scripts\smoke-bootstrap.ps1"), (New-Object System.Text.UTF8Encoding $false))
        Assert-True ($smokeText -notmatch '"scripts\\recovery-shadow\.ps1"') "Essential excludes recovery-shadow.ps1"
        Assert-True ($smokeText -notmatch '"tests\\recovery-shadow"') "bootstrap excludes tests/recovery-shadow"
    } finally {
        Pop-Location
    }
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
if ($fail -eq 0) {
    Write-Host "RECOVERY_SHADOW_TEST_PASS"
    exit 0
}
Write-Host "RECOVERY_SHADOW_TEST_FAIL: $fail"
exit 1

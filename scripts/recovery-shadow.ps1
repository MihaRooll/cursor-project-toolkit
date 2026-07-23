<#
.SYNOPSIS
  Sequential recovery shadow — two-phase Commit then Reveal. Metadata only; toolkit-only.
  Production R0a dual-blind recovery unchanged. No live model calls; no pin/cost changes.
#>
param(
    [ValidateSet("Commit", "Reveal")]
    [string]$Action = "",
    [string]$InputPath = "",
    [string]$InputJson = "",
    [string]$CommitmentPath = "",
    [string]$SecondVerdictJson = "",
    [string]$SecondVerdictPath = "",
    [string]$OutputPath = "",
    [string]$ShadowRoot = "",
    [string]$ProjectRoot = "",
    [switch]$SelfTest
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ValidatorScript = Join-Path $PSScriptRoot "validate-recovery-shadow.ps1"
$DefaultShadowRel = ".cursor/recovery-shadow-local"
$ExcludedRiskTags = @(
    "no_oracle", "no-oracle", "high_consequence", "security",
    "public_contract", "persistent", "irreversible"
)
$ValidDecisions = @("retry", "scout", "premium", "experiment", "blocked", "human_pending")
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

function Assert-OwnedOutputPath([string]$Path) {
    if ($script:OwnedOutputPaths -notcontains $Path) {
        throw "output path not invocation-owned"
    }
}

function Invoke-ValidateJson {
    param([string]$JsonText, [string]$Kind)
    $temp = Join-Path $env:TEMP ("cptk-rshadow-val-" + [guid]::NewGuid().ToString("n") + ".json")
    try {
        [System.IO.File]::WriteAllText($temp, $JsonText, (New-Object System.Text.UTF8Encoding $false))
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ValidatorScript -InputPath $temp -SchemaKind $Kind | Out-Null
        if ($LASTEXITCODE -ne 0) { throw ("validation failed kind=" + $Kind) }
    } finally {
        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
    }
}

function Test-OracleEligible {
    param([object]$Oracle)
    if ($null -eq $Oracle) { return $false }
    foreach ($req in @("available", "reliable", "check_id")) {
        if (-not ($Oracle.PSObject.Properties.Name -contains $req)) { return $false }
    }
    if (-not [bool]$Oracle.available) { return $false }
    if (-not [bool]$Oracle.reliable) { return $false }
    if ([string]::IsNullOrWhiteSpace([string]$Oracle.check_id)) { return $false }
    return $true
}

function Get-NormalizedRiskTags {
    param([object]$Candidate)
    $tags = @()
    if ($null -ne $Candidate -and ($Candidate.PSObject.Properties.Name -contains "risk_tags")) {
        foreach ($t in @($Candidate.risk_tags)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$t)) {
                $tags += ([string]$t).ToLowerInvariant()
            }
        }
    }
    return $tags
}

function Test-CandidateEligibility {
    param([object]$Candidate)
    $reasons = New-Object System.Collections.Generic.List[string]
    if (-not (Test-OracleEligible -Oracle $Candidate.oracle)) {
        [void]$reasons.Add("no_oracle")
    }
    foreach ($tag in (Get-NormalizedRiskTags -Candidate $Candidate)) {
        $norm = $tag -replace '-', '_'
        foreach ($ex in $ExcludedRiskTags) {
            if ($norm -ceq ($ex -replace '-', '_')) {
                [void]$reasons.Add($ex)
            }
        }
    }
    return @{
        eligible = ($reasons.Count -eq 0)
        exclusion_reasons = @($reasons | Select-Object -Unique)
    }
}

function New-FirstVerdictHash {
    param([string]$CandidateId, [string]$FirstDecision)
    $seed = $CandidateId + "|first|" + $FirstDecision + "|seq=1"
    return ("sha256:" + (Get-Sha256Hex ([System.Text.Encoding]::UTF8.GetBytes($seed))))
}

function New-CommitmentHash {
    param(
        [string]$CandidateId,
        [string]$SecondCallDecision,
        [string]$FirstVerdictDecision,
        [string]$FirstVerdictHash,
        [bool]$BeforeSecondReveal,
        [bool]$LiveModelCalls
    )
    $seed = $CandidateId + "|seq=2|second_call=" + $SecondCallDecision + "|first=" + $FirstVerdictDecision `
        + "|first_hash=" + $FirstVerdictHash + "|before_reveal=" + ($BeforeSecondReveal.ToString().ToLowerInvariant()) `
        + "|live_model_calls=" + ($LiveModelCalls.ToString().ToLowerInvariant())
    return ("sha256:" + (Get-Sha256Hex ([System.Text.Encoding]::UTF8.GetBytes($seed))))
}

function New-SequenceProof {
    param(
        [string]$CandidateId,
        [string]$FirstVerdictHash,
        [string]$CommitmentHash,
        [bool]$BeforeSecondReveal,
        [bool]$LiveModelCalls
    )
    $seed = "candidate=" + $CandidateId + "|1=first_verdict:" + $FirstVerdictHash + "|2=commitment:" + $CommitmentHash `
        + "|before_reveal=" + ($BeforeSecondReveal.ToString().ToLowerInvariant()) `
        + "|live_model_calls=" + ($LiveModelCalls.ToString().ToLowerInvariant())
    return ("seqproof:" + (Get-Sha256Hex ([System.Text.Encoding]::UTF8.GetBytes($seed))))
}

function New-SecondVerdictHash {
    param([string]$CandidateId, [string]$SecondDecision)
    $seed = $CandidateId + "|second|" + $SecondDecision + "|seq=3"
    return ("sha256:" + (Get-Sha256Hex ([System.Text.Encoding]::UTF8.GetBytes($seed))))
}

function Get-DeterministicScore {
    param([string]$FirstDecision, [string]$SecondCallDecision, [string]$SecondDecision)
    $score = 0.0
    if ($FirstDecision -ceq $SecondDecision) { $score += 0.25 }
    if ($SecondCallDecision -ceq $SecondDecision) { $score += 0.50 }
    if ($FirstDecision -ceq $SecondCallDecision) { $score += 0.25 }
    return [math]::Round($score, 4)
}

function Test-CriticalMiss {
    param([string]$SecondCallDecision, [string]$SecondDecision)
    return ($SecondCallDecision -in @("experiment", "premium") -and $SecondDecision -in @("blocked", "human_pending"))
}

function Assert-NoSecondVerdictInCommitInput([object]$CommitInputObj) {
    if ($CommitInputObj.PSObject.Properties.Name -contains "second_verdict") {
        throw "protocol: second_verdict forbidden in commit phase"
    }
}

function Invoke-ShadowCommit {
    param([object]$CommitInputObj)
    Assert-NoSecondVerdictInCommitInput -CommitInputObj $CommitInputObj
    $firstDecision = [string]$CommitInputObj.first_verdict.decision
    if ($ValidDecisions -notcontains $firstDecision) { throw "protocol: invalid first verdict" }
    if ($ValidDecisions -notcontains [string]$CommitInputObj.second_call_decision) { throw "protocol: invalid second_call_decision" }

    $elig = Test-CandidateEligibility -Candidate $CommitInputObj
    if (-not $elig.eligible) {
        return [ordered]@{
            schema_version = 1
            shadow_version = "v1"
            record_type = "commitment"
            candidate_id = [string]$CommitInputObj.candidate_id
            consumer_repo = [string]$CommitInputObj.consumer_repo
            tier = [string]$CommitInputObj.tier
            oracle = $CommitInputObj.oracle
            excluded = $true
            exclusion_reasons = $elig.exclusion_reasons
            promotion_status = "evidence_pending"
            live_model_calls = $false
            pin_or_cost_change = $false
        }
    }

    $firstHash = New-FirstVerdictHash -CandidateId ([string]$CommitInputObj.candidate_id) -FirstDecision $firstDecision
    $beforeReveal = $true
    $liveModelCalls = $false
    $commitHash = New-CommitmentHash -CandidateId ([string]$CommitInputObj.candidate_id) `
        -SecondCallDecision ([string]$CommitInputObj.second_call_decision) -FirstVerdictDecision $firstDecision `
        -FirstVerdictHash $firstHash -BeforeSecondReveal $beforeReveal -LiveModelCalls $liveModelCalls
    $seqProof = New-SequenceProof -CandidateId ([string]$CommitInputObj.candidate_id) -FirstVerdictHash $firstHash `
        -CommitmentHash $commitHash -BeforeSecondReveal $beforeReveal -LiveModelCalls $liveModelCalls

    return [ordered]@{
        schema_version = 1
        shadow_version = "v1"
        record_type = "commitment"
        candidate_id = [string]$CommitInputObj.candidate_id
        consumer_repo = [string]$CommitInputObj.consumer_repo
        tier = [string]$CommitInputObj.tier
        oracle = $CommitInputObj.oracle
        excluded = $false
        exclusion_reasons = @()
        first_verdict = [ordered]@{
            family = [string]$CommitInputObj.first_verdict.family
            decision = $firstDecision
            recorded_at_seq = 1
            verdict_hash = $firstHash
        }
        commitment = [ordered]@{
            second_call_decision = [string]$CommitInputObj.second_call_decision
            commitment_hash = $commitHash
            sequence_proof = $seqProof
            recorded_at_seq = 2
            before_second_reveal = $true
        }
        promotion_status = "evidence_pending"
        live_model_calls = $false
        pin_or_cost_change = $false
    }
}

function Test-CommitmentIntegrity {
    param([object]$Record)
    if ([bool]$Record.excluded) { return }
    if ($Record.PSObject.Properties.Name -contains "live_model_calls") {
        if ([bool]$Record.live_model_calls) {
            throw "protocol: live_model_calls must be false"
        }
    }
    if (-not ($Record.PSObject.Properties.Name -contains "commitment")) {
        throw "protocol: commitment missing"
    }
    if (-not [bool]$Record.commitment.before_second_reveal) {
        throw "protocol: before_second_reveal must be true"
    }
    $beforeReveal = $true
    $liveModelCalls = $false
    $expectedFirst = New-FirstVerdictHash -CandidateId ([string]$Record.candidate_id) `
        -FirstDecision ([string]$Record.first_verdict.decision)
    if ([string]$Record.first_verdict.verdict_hash -cne $expectedFirst) {
        throw "protocol: first verdict hash tamper"
    }
    $expectedCommit = New-CommitmentHash -CandidateId ([string]$Record.candidate_id) `
        -SecondCallDecision ([string]$Record.commitment.second_call_decision) `
        -FirstVerdictDecision ([string]$Record.first_verdict.decision) `
        -FirstVerdictHash ([string]$Record.first_verdict.verdict_hash) `
        -BeforeSecondReveal $beforeReveal -LiveModelCalls $liveModelCalls
    if ([string]$Record.commitment.commitment_hash -cne $expectedCommit) {
        throw "protocol: commitment hash tamper"
    }
    $expectedProof = New-SequenceProof -CandidateId ([string]$Record.candidate_id) `
        -FirstVerdictHash ([string]$Record.first_verdict.verdict_hash) `
        -CommitmentHash ([string]$Record.commitment.commitment_hash) `
        -BeforeSecondReveal $beforeReveal -LiveModelCalls $liveModelCalls
    if ([string]$Record.commitment.sequence_proof -cne $expectedProof) {
        throw "protocol: sequence proof tamper"
    }
    if ([int]$Record.commitment.recorded_at_seq -ge 3) {
        throw "protocol: commitment must precede second reveal"
    }
}

function Get-RevealMarkerPath {
    param([string]$CommitmentPath)
    return ($CommitmentPath + ".reveal.lock")
}

function Acquire-RevealMarker {
    param([string]$CommitmentPath)
    $markerPath = Get-RevealMarkerPath -CommitmentPath $CommitmentPath
    Assert-NoReparseInPath -Path $markerPath -Label "reveal marker"
    if ($script:OwnedOutputPaths -notcontains $markerPath) {
        [void]$script:OwnedOutputPaths.Add($markerPath)
    }
    $dir = Split-Path -Parent $markerPath
    if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -LiteralPath $dir)) {
        [void][System.IO.Directory]::CreateDirectory($dir)
    }
    $payload = (Get-Sha256Hex ([System.Text.Encoding]::UTF8.GetBytes($CommitmentPath))) + "`n"
    try {
        $fs = New-Object System.IO.FileStream($markerPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
            $fs.Write($bytes, 0, $bytes.Length)
        } finally {
            $fs.Dispose()
        }
    } catch [System.IO.IOException] {
        throw "reveal already consumed"
    }
    return $markerPath
}

function Remove-RevealMarker {
    param([string]$MarkerPath)
    if ([string]::IsNullOrWhiteSpace($MarkerPath)) { return }
    if (Test-Path -LiteralPath $MarkerPath) {
        Remove-Item -LiteralPath $MarkerPath -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-ShadowReveal {
    param(
        [object]$CommitmentRecord,
        [object]$SecondVerdict
    )
    if ([string]$CommitmentRecord.record_type -cne "commitment") {
        throw "protocol: reveal requires commitment record"
    }
    Test-CommitmentIntegrity -Record $CommitmentRecord
    if ([bool]$CommitmentRecord.excluded) {
        throw "protocol: cannot reveal excluded candidate"
    }

    $secondDecision = [string]$SecondVerdict.decision
    if ($ValidDecisions -notcontains $secondDecision) { throw "protocol: invalid second verdict" }

    $firstDecision = [string]$CommitmentRecord.first_verdict.decision
    $secondCallDecision = [string]$CommitmentRecord.commitment.second_call_decision
    $secondHash = New-SecondVerdictHash -CandidateId ([string]$CommitmentRecord.candidate_id) -SecondDecision $secondDecision
    $criticalMiss = Test-CriticalMiss -SecondCallDecision $secondCallDecision -SecondDecision $secondDecision
    $score = Get-DeterministicScore -FirstDecision $firstDecision -SecondCallDecision $secondCallDecision `
        -SecondDecision $secondDecision

    return [ordered]@{
        schema_version = 1
        shadow_version = "v1"
        record_type = "final"
        candidate_id = [string]$CommitmentRecord.candidate_id
        consumer_repo = [string]$CommitmentRecord.consumer_repo
        tier = [string]$CommitmentRecord.tier
        oracle = $CommitmentRecord.oracle
        excluded = $false
        exclusion_reasons = @()
        first_verdict = $CommitmentRecord.first_verdict
        commitment = $CommitmentRecord.commitment
        second_verdict = [ordered]@{
            family = [string]$SecondVerdict.family
            decision = $secondDecision
            revealed_at_seq = 3
            verdict_hash = $secondHash
        }
        score = [ordered]@{
            deterministic_score = $score
            critical_miss = $criticalMiss
            agreement_first_second = ($firstDecision -ceq $secondDecision)
            commitment_matches_second = ($secondCallDecision -ceq $secondDecision)
        }
        promotion_status = "evidence_pending"
        live_model_calls = $false
        pin_or_cost_change = $false
        experiment_stopped = $criticalMiss
        stop_reason = $(if ($criticalMiss) { "critical_miss" } else { $null })
        protocol_sequence = @("first_verdict_recorded", "commitment_recorded", "second_verdict_revealed", "scored")
    }
}

function Resolve-ProjectRoot {
    param([string]$Explicit)
    if (-not [string]::IsNullOrWhiteSpace($Explicit)) {
        return (Resolve-Path -LiteralPath $Explicit).Path
    }
    return $Root
}

function Register-OwnedOutputPath {
    param(
        [string]$ProjectRoot,
        [string]$ExplicitOutput,
        [string]$ShadowRootOverride,
        [string]$FileName
    )
    if (-not [string]::IsNullOrWhiteSpace($ExplicitOutput)) {
        $path = [System.IO.Path]::GetFullPath($ExplicitOutput)
        Assert-NoReparseInPath -Path $path -Label "shadow target"
        $dir = Split-Path -Parent $path
        if (-not [string]::IsNullOrWhiteSpace($dir)) {
            Assert-NoReparseInPath -Path $dir -Label "shadow directory"
        }
        [void]$script:OwnedOutputPaths.Add($path)
        return $path
    }
    $root = $ShadowRootOverride
    if ([string]::IsNullOrWhiteSpace($root)) {
        $root = Join-Path $ProjectRoot ($DefaultShadowRel -replace '/', '\')
    } else {
        $root = [System.IO.Path]::GetFullPath($root)
    }
    Assert-NoReparseInPath -Path $root -Label "shadow root"
    if (-not (Test-Path -LiteralPath $root)) {
        [void][System.IO.Directory]::CreateDirectory($root)
    }
    $path = Join-Path $root $FileName
    Assert-NoReparseInPath -Path $path -Label "shadow target"
    [void]$script:OwnedOutputPaths.Add($path)
    return $path
}

function Write-ShadowCreateNew {
    param([string]$OutputPath, [string]$JsonText)
    Assert-OwnedOutputPath -Path $OutputPath
    $dir = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -LiteralPath $dir)) {
        [void][System.IO.Directory]::CreateDirectory($dir)
    }
    $lines = ($JsonText -split "`r?`n" | ForEach-Object { $_.TrimEnd() }) -join "`n"
    $payload = $lines + "`n"
    try {
        $fs = New-Object System.IO.FileStream($OutputPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
            $fs.Write($bytes, 0, $bytes.Length)
        } finally {
            $fs.Dispose()
        }
    } catch [System.IO.IOException] {
        throw "duplicate output file exists"
    }
}

function New-SampleCommitInput {
    param(
        [string]$CandidateId = "shadow-low-risk-001",
        [string]$ConsumerRepo = "TG_BOT_PRO",
        [string[]]$RiskTags = @()
    )
    return [ordered]@{
        candidate_id = $CandidateId
        consumer_repo = $ConsumerRepo
        tier = "T2"
        oracle = @{ available = $true; reliable = $true; check_id = "Q-PARSE" }
        risk_tags = @($RiskTags)
        first_verdict = @{ family = "openai"; decision = "retry" }
        second_call_decision = "retry"
    }
}

function Invoke-ShadowPipeline {
    param([object]$CommitInput, [object]$SecondVerdict)
    $commitJson = ($CommitInput | ConvertTo-Json -Depth 8 -Compress)
    Invoke-ValidateJson -JsonText $commitJson -Kind "commit_input"
    $commitment = Invoke-ShadowCommit -CommitInputObj ($commitJson | ConvertFrom-Json)
    $commitOutJson = ($commitment | ConvertTo-Json -Depth 10 -Compress)
    Invoke-ValidateJson -JsonText $commitOutJson -Kind "commitment_record"
    Test-CommitmentIntegrity -Record ($commitOutJson | ConvertFrom-Json)
    $final = Invoke-ShadowReveal -CommitmentRecord ($commitOutJson | ConvertFrom-Json) -SecondVerdict $SecondVerdict
    $finalJson = ($final | ConvertTo-Json -Depth 10 -Compress)
    Invoke-ValidateJson -JsonText $finalJson -Kind "final_record"
    return $final
}

function Invoke-SelfTest {
    $script:Fail = 0
    function Assert-ThrowsMsg($scriptBlock, [string]$token, [string]$msg) {
        $threw = $false
        $err = ""
        try { & $scriptBlock } catch { $threw = $true; $err = $_.Exception.Message }
        if (-not $threw) { Fail ($msg + " (no throw)"); return }
        if ($err -notlike ("*" + $token + "*")) { Fail ($msg + " token=" + $token + " got=" + $err); return }
        Pass $msg
    }

    Write-Host "=== recovery-shadow SelfTest ==="

    $low = New-SampleCommitInput
    $final = Invoke-ShadowPipeline -CommitInput $low -SecondVerdict @{ family = "claude"; decision = "retry" }
    Assert-True (-not [bool]$final.experiment_stopped) "accepted low-risk two-phase"

    $omitRel = New-SampleCommitInput -CandidateId "shadow-omit-reliable"
    $omitRel.oracle = @{ available = $true; check_id = "Q-PARSE" }
    $excluded = Invoke-ShadowCommit -CommitInputObj ($omitRel | ConvertTo-Json -Depth 8 | ConvertFrom-Json)
    Assert-True ([bool]$excluded.excluded) "exclude oracle reliable omitted"
    Assert-True ($excluded.exclusion_reasons -contains "no_oracle") "no_oracle on omitted reliable"

    $noOracle = New-SampleCommitInput -CandidateId "shadow-no-oracle"
    $noOracle.oracle = @{ available = $false; reliable = $false; check_id = "Q-PARSE" }
    $exNo = Invoke-ShadowCommit -CommitInputObj ($noOracle | ConvertTo-Json -Depth 8 | ConvertFrom-Json)
    Assert-True ([bool]$exNo.excluded) "exclude explicit no oracle"

    $high = New-SampleCommitInput -CandidateId "shadow-high" -RiskTags @("security")
    $exHigh = Invoke-ShadowCommit -CommitInputObj ($high | ConvertTo-Json -Depth 8 | ConvertFrom-Json)
    Assert-True ([bool]$exHigh.excluded) "exclude high-risk"

    $oneShot = New-SampleCommitInput
    $oneShot.second_verdict = @{ family = "claude"; decision = "retry" }
    Assert-ThrowsMsg {
        Invoke-ShadowCommit -CommitInputObj ($oneShot | ConvertTo-Json -Depth 8 | ConvertFrom-Json)
    } "protocol: second_verdict forbidden in commit phase" "reject one-shot second_verdict"

    $commitRec = Invoke-ShadowCommit -CommitInputObj ($low | ConvertTo-Json -Depth 8 | ConvertFrom-Json)
    $tampered = $commitRec | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $tampered.commitment.commitment_hash = "sha256:deadbeef"
    Assert-ThrowsMsg { Test-CommitmentIntegrity -Record $tampered } "protocol: commitment hash tamper" "reject commitment tamper"

    $seqOnly = $commitRec | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $seqOnly.commitment.sequence_proof = "seqproof:deadbeef"
    Assert-ThrowsMsg { Test-CommitmentIntegrity -Record $seqOnly } "protocol: sequence proof tamper" "reject sequence_proof-only tamper"

    $badBefore = $commitRec | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $badBefore.commitment.before_second_reveal = $false
    Assert-ThrowsMsg { Test-CommitmentIntegrity -Record $badBefore } "protocol: before_second_reveal must be true" "reject before_second_reveal false"

    $badLive = $commitRec | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $badLive.live_model_calls = $true
    Assert-ThrowsMsg { Test-CommitmentIntegrity -Record $badLive } "protocol: live_model_calls must be false" "reject live_model_calls true"

    $reorder = $commitRec | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $reorder.commitment.recorded_at_seq = 9
    Assert-ThrowsMsg { Test-CommitmentIntegrity -Record $reorder } "protocol: commitment must precede" "reject reorder"

    $critIn = New-SampleCommitInput -CandidateId "shadow-critical"
    $critIn.second_call_decision = "experiment"
    $critCommit = Invoke-ShadowCommit -CommitInputObj ($critIn | ConvertTo-Json -Depth 8 | ConvertFrom-Json)
    $critFinal = Invoke-ShadowReveal -CommitmentRecord ($critCommit | ConvertTo-Json -Depth 10 | ConvertFrom-Json) `
        -SecondVerdict @{ family = "claude"; decision = "blocked" }
    Assert-True ([bool]$critFinal.experiment_stopped) "critical miss stops experiment"

    $scoreA = Get-DeterministicScore -FirstDecision "retry" -SecondCallDecision "retry" -SecondDecision "retry"
    $scoreB = Get-DeterministicScore -FirstDecision "retry" -SecondCallDecision "retry" -SecondDecision "retry"
    Assert-True ($scoreA -eq $scoreB) "deterministic score"
    $hashA = New-CommitmentHash -CandidateId "x" -SecondCallDecision "scout" -FirstVerdictDecision "retry" -FirstVerdictHash "sha256:abc" -BeforeSecondReveal $true -LiveModelCalls $false
    $hashB = New-CommitmentHash -CandidateId "y" -SecondCallDecision "scout" -FirstVerdictDecision "retry" -FirstVerdictHash "sha256:def" -BeforeSecondReveal $true -LiveModelCalls $false
    Assert-True ($hashA -cne $hashB) "commitment hash independence"

    $tempRoot = Join-Path $env:TEMP ("cptk-rshadow-" + [guid]::NewGuid().ToString("n"))
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    try {
        $out = Register-OwnedOutputPath -ProjectRoot $tempRoot -ExplicitOutput (Join-Path $tempRoot "c.json") -FileName "unused.json"
        Write-ShadowCreateNew -OutputPath $out -JsonText '{"record_type":"commitment"}'
        Assert-ThrowsMsg {
            Write-ShadowCreateNew -OutputPath $out -JsonText '{"record_type":"commitment"}'
        } "duplicate output file exists" "reject duplicate CreateNew"

        $commitFile = Register-OwnedOutputPath -ProjectRoot $tempRoot -ExplicitOutput (Join-Path $tempRoot "replay.commitment.json") -FileName "unused.json"
        $commitJson = ($commitRec | ConvertTo-Json -Depth 10)
        Write-ShadowCreateNew -OutputPath $commitFile -JsonText $commitJson
        $markerPath = Acquire-RevealMarker -CommitmentPath $commitFile
        Assert-True (Test-Path -LiteralPath $markerPath) "reveal marker created"
        Assert-ThrowsMsg { Acquire-RevealMarker -CommitmentPath $commitFile } "reveal already consumed" "reject duplicate reveal marker"
        Remove-RevealMarker -MarkerPath $markerPath
        Assert-True (-not (Test-Path -LiteralPath $markerPath)) "reveal marker rollback removed"
    } finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        $script:OwnedOutputPaths.Clear()
    }

    Push-Location -LiteralPath $Root
    try {
        $ignore = & git check-ignore -v ".cursor/recovery-shadow-local/" 2>$null
        Assert-True (-not [string]::IsNullOrWhiteSpace($ignore)) "gitignore covers shadow local"
    } finally {
        Pop-Location
    }

    Write-Host ""
    if ($script:Fail -eq 0) {
        Write-Host "RECOVERY_SHADOW_SELFTEST_PASS"
        exit 0
    }
    Write-Host "RECOVERY_SHADOW_SELFTEST_FAIL: $script:Fail"
    exit 1
}

if ($SelfTest) { Invoke-SelfTest }

if ([string]::IsNullOrWhiteSpace($Action)) { throw "Action Commit or Reveal required" }

$projRoot = Resolve-ProjectRoot -Explicit $ProjectRoot

if ($Action -eq "Commit") {
    if (-not [string]::IsNullOrWhiteSpace($InputPath)) {
        $InputJson = [System.IO.File]::ReadAllText($InputPath, (New-Object System.Text.UTF8Encoding $false))
    }
    if ([string]::IsNullOrWhiteSpace($InputJson)) { throw "InputPath or InputJson required for Commit" }
    Invoke-ValidateJson -JsonText $InputJson -Kind "commit_input"
    $inputObj = $InputJson | ConvertFrom-Json
    Assert-NoSecondVerdictInCommitInput -CommitInputObj $inputObj
    $record = Invoke-ShadowCommit -CommitInputObj $inputObj
    $outJson = ($record | ConvertTo-Json -Depth 10)
    if (-not [bool]$record.excluded) {
        Invoke-ValidateJson -JsonText $outJson -Kind "commitment_record"
        Test-CommitmentIntegrity -Record ($outJson | ConvertFrom-Json)
    }
    $fileName = ([string]$record.candidate_id -replace '[^\w\-.]+', '_').Trim('_') + ".commitment.json"
    $dest = Register-OwnedOutputPath -ProjectRoot $projRoot -ExplicitOutput $OutputPath -ShadowRootOverride $ShadowRoot -FileName $fileName
    Write-ShadowCreateNew -OutputPath $dest -JsonText $outJson
    Write-Host "RECOVERY_SHADOW_COMMIT_OK record=output=invocation-owned"
    exit 0
}

if ($Action -eq "Reveal") {
    if ([string]::IsNullOrWhiteSpace($CommitmentPath)) { throw "CommitmentPath required for Reveal" }
    if (-not (Test-Path -LiteralPath $CommitmentPath)) { throw "commitment path missing" }
    $commitJson = [System.IO.File]::ReadAllText($CommitmentPath, (New-Object System.Text.UTF8Encoding $false))
    Invoke-ValidateJson -JsonText $commitJson -Kind "commitment_record"
    $commitObj = $commitJson | ConvertFrom-Json
    Test-CommitmentIntegrity -Record $commitObj

    if ([string]::IsNullOrWhiteSpace($SecondVerdictJson) -and -not [string]::IsNullOrWhiteSpace($SecondVerdictPath)) {
        if (-not (Test-Path -LiteralPath $SecondVerdictPath)) { throw "second verdict path missing" }
        $SecondVerdictJson = [System.IO.File]::ReadAllText($SecondVerdictPath, (New-Object System.Text.UTF8Encoding $false))
    }
    if ([string]::IsNullOrWhiteSpace($SecondVerdictJson)) { throw "SecondVerdictJson or SecondVerdictPath required for Reveal" }
    $secondObj = $SecondVerdictJson | ConvertFrom-Json
    if ($secondObj.PSObject.Properties.Name -contains "second_call_decision") {
        throw "protocol: second_call_decision belongs in commitment only"
    }

    $markerPath = $null
    try {
        $markerPath = Acquire-RevealMarker -CommitmentPath $CommitmentPath
        $final = Invoke-ShadowReveal -CommitmentRecord $commitObj -SecondVerdict $secondObj
        $finalJson = ($final | ConvertTo-Json -Depth 10)
        Invoke-ValidateJson -JsonText $finalJson -Kind "final_record"

        $fileName = ([string]$final.candidate_id -replace '[^\w\-.]+', '_').Trim('_') + ".final.json"
        $dest = Register-OwnedOutputPath -ProjectRoot $projRoot -ExplicitOutput $OutputPath -ShadowRootOverride $ShadowRoot -FileName $fileName
        Write-ShadowCreateNew -OutputPath $dest -JsonText $finalJson
    } catch {
        Remove-RevealMarker -MarkerPath $markerPath
        throw
    }
    Write-Host "RECOVERY_SHADOW_REVEAL_OK record=output=invocation-owned"
    exit 0
}

throw "unsupported Action"

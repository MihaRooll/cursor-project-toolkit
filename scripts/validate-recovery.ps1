<#
.SYNOPSIS
  Static validation for recovery escalation R0a (Windows PowerShell 5.1).
#>
param(
    [switch]$SelfTest
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Fail = 0

$ValidDecisions = @("retry", "scout", "premium", "experiment", "blocked", "human_pending")
$SchemaTokens = @(
    "## 9. FailureRecord",
    "## 10. EvidenceRecord",
    "## 11. HypothesisRecord",
    "## 12. RecoverySnapshot",
    "## 13. ChallengePacket",
    "## 14. RecoveryDecision",
    "Recovery budgets (R0)"
)
$RecoveryAgents = @(
    @{
        file = "recovery-orchestrator.md"
        name = "recovery-orchestrator"
        model = "cursor-grok-4.5-high-fast"
        readonly = "true"
        descriptionNeedle = "explicitly invoked for recovery escalation coordination"
    },
    @{
        file = "reproducer.md"
        name = "reproducer"
        model = "composer-2.5-fast"
        readonly = "false"
        descriptionNeedle = "safe diagnostics/scratch during recovery"
    },
    @{
        file = "recovery-arbiter-openai.md"
        name = "recovery-arbiter-openai"
        model = "gpt-5.6-sol-medium"
        readonly = "true"
        descriptionNeedle = "recovery Challenge Packet review"
    },
    @{
        file = "recovery-arbiter-claude.md"
        name = "recovery-arbiter-claude"
        model = "claude-opus-4-8-thinking-high"
        readonly = "true"
        descriptionNeedle = "blind recovery Challenge Packet"
    },
    @{
        file = "recovery-arbiter-fable.md"
        name = "recovery-arbiter-fable"
        model = "claude-fable-5-thinking-high"
        readonly = "true"
        descriptionNeedle = "explicit deep recovery mode"
    }
)

function Pass([string]$Message) { Write-Host "OK  $Message" }
function Fail([string]$Message) {
    Write-Host "FAIL $Message"
    $script:Fail++
}

function Assert-True($Condition, [string]$Message) {
    if ($Condition) { Pass $Message } else { Fail $Message }
}

function Read-Text([string]$Path) {
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Get-Frontmatter([string]$Path) {
    $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)
    if ($lines.Count -lt 3 -or $lines[0].Trim() -ne "---") {
        throw "Missing opening frontmatter fence: $Path"
    }
    $end = -1
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq "---") {
            $end = $i
            break
        }
    }
    if ($end -lt 2) { throw "Missing closing frontmatter fence: $Path" }

    $map = @{}
    for ($i = 1; $i -lt $end; $i++) {
        $line = $lines[$i]
        $colon = $line.IndexOf(":")
        if ($colon -gt 0) {
            $key = $line.Substring(0, $colon).Trim()
            $value = $line.Substring($colon + 1).Trim()
            $value = ($value -replace "\s+#.*$", "").Trim().Trim('"').Trim("'")
            if ($map.ContainsKey($key)) {
                throw "Duplicate frontmatter key '$key': $Path"
            }
            $map[$key] = $value
        }
    }
    return $map
}

function Read-Json([string]$Path) {
    $raw = Read-Text $Path
    if ($raw.Length -gt 0 -and [int][char]$raw[0] -eq 0xFEFF) { $raw = $raw.Substring(1) }
    return ($raw | ConvertFrom-Json)
}

function Test-RecoveryAgent($Frontmatter, $Expected) {
    return (
        $Frontmatter["name"] -eq [string]$Expected.name -and
        $Frontmatter["model"] -eq [string]$Expected.model -and
        $Frontmatter["readonly"] -eq [string]$Expected.readonly -and
        $Frontmatter["is_background"] -eq "false" -and
        $Frontmatter["description"] -match [regex]::Escape([string]$Expected.descriptionNeedle)
    )
}

function Test-RecoverySkillManualOnly($Frontmatter) {
    $disabled = (
        $Frontmatter.ContainsKey("disable-model-invocation") -and
        $Frontmatter["disable-model-invocation"] -match "^true\b"
    )
    return (
        $Frontmatter["name"] -eq "recovery-escalation" -and
        $Frontmatter["description"] -match "\p{IsCyrillic}" -and
        $disabled
    )
}

$ExpectedDecisionByClass = @{
    "normal_retry" = "retry"
    "genuinely_new_evidence" = "retry"
    "false_stuck_trigger" = "retry"
    "repeated_signature" = "scout"
    "premium_unavailable" = "scout"
    "duplicate_hypothesis" = "blocked"
    "no_oracle" = "blocked"
    "environment_blocker" = "human_pending"
    "external_auth" = "human_pending"
    "malicious_output" = "human_pending"
    "cross_family_disagreement" = "human_pending"
}
$ChallengePacketForbiddenKeys = @(
    "raw_logs", "transcript", "transcripts", "chain_of_thought",
    "secrets", "credentials", "tool_json"
)
$ChallengePacketMaxRefs = 12
$ChallengePacketHardMaxChars = 48000

function Get-EvidenceDeltaArray($Fx) {
    if ($null -eq $Fx) { return @() }
    if (-not ($Fx.PSObject.Properties.Name -contains "evidence_delta")) { return @() }
    $raw = $Fx.evidence_delta
    if ($null -eq $raw) { return @() }
    if ($raw -is [string]) { return @($raw) }
    return @($raw)
}

function Get-EvidenceDeltaCount($Fx) {
    return (Get-EvidenceDeltaArray $Fx).Count
}

function Get-StuckFieldsSchemaFailure($Fx) {
    if ($null -eq $Fx) { return "missing_is_stuck" }
    if (-not ($Fx.PSObject.Properties.Name -contains "is_stuck")) { return "missing_is_stuck" }
    if ($Fx.is_stuck -isnot [bool]) { return "invalid_is_stuck_type" }
    if (-not ($Fx.PSObject.Properties.Name -contains "normalized_signature") -or
        [string]::IsNullOrWhiteSpace([string]$Fx.normalized_signature)) {
        return "missing_normalized_signature"
    }
    if (-not ($Fx.PSObject.Properties.Name -contains "previous_signature") -or
        [string]::IsNullOrWhiteSpace([string]$Fx.previous_signature)) {
        return "missing_previous_signature"
    }
    if (-not ($Fx.PSObject.Properties.Name -contains "evidence_delta")) { return "missing_evidence_delta" }
    if ($null -eq $Fx.evidence_delta) { return "invalid_evidence_delta_type" }
    if ($Fx.evidence_delta -isnot [System.Array]) { return "invalid_evidence_delta_type" }
    return $null
}

function Test-ManifestChallengePacketMaxChars($Manifest) {
    if ($null -eq $Manifest) { return $false }
    if (-not ($Manifest.PSObject.Properties.Name -contains "challenge_packet_max_chars")) { return $false }
    $rawValue = $Manifest.challenge_packet_max_chars
    if ($rawValue -isnot [byte] -and
        $rawValue -isnot [sbyte] -and
        $rawValue -isnot [int16] -and
        $rawValue -isnot [uint16] -and
        $rawValue -isnot [int32] -and
        $rawValue -isnot [uint32] -and
        $rawValue -isnot [int64] -and
        $rawValue -isnot [uint64]) {
        return $false
    }
    try {
        $value = [int]$rawValue
    } catch {
        return $false
    }
    return ($value -ge 1 -and $value -le $ChallengePacketHardMaxChars)
}

function Get-ForbiddenKeyInTree($Node) {
    if ($null -eq $Node) { return $null }
    if ($Node -is [string]) { return $null }

    if ($Node -is [System.Collections.IDictionary]) {
        foreach ($key in $Node.Keys) {
            $keyName = [string]$key
            foreach ($bad in $ChallengePacketForbiddenKeys) {
                if ([string]::Equals($keyName, $bad, [StringComparison]::OrdinalIgnoreCase)) {
                    return $keyName
                }
            }
            $nested = Get-ForbiddenKeyInTree $Node[$key]
            if ($null -ne $nested) { return $nested }
        }
        return $null
    }

    if ($Node -is [System.Array]) {
        foreach ($item in $Node) {
            $nested = Get-ForbiddenKeyInTree $item
            if ($null -ne $nested) { return $nested }
        }
        return $null
    }

    if ($Node -is [PSCustomObject]) {
        foreach ($prop in $Node.PSObject.Properties) {
            $keyName = [string]$prop.Name
            foreach ($bad in $ChallengePacketForbiddenKeys) {
                if ([string]::Equals($keyName, $bad, [StringComparison]::OrdinalIgnoreCase)) {
                    return $keyName
                }
            }
            $nested = Get-ForbiddenKeyInTree $prop.Value
            if ($null -ne $nested) { return $nested }
        }
    }
    return $null
}

function Test-RecomputedIsStuck($Fx) {
    $sig = [string]$Fx.normalized_signature
    $prev = [string]$Fx.previous_signature
    $deltaCount = Get-EvidenceDeltaCount $Fx
    $sameSig = (
        -not [string]::IsNullOrWhiteSpace($sig) -and
        -not [string]::IsNullOrWhiteSpace($prev) -and
        ($sig -eq $prev)
    )
    $emptyDelta = ($deltaCount -eq 0)
    return ($sameSig -or $emptyDelta)
}

function Test-ChallengePacketSchema($Packet, [int]$MaxChars, [ref]$ForbiddenKeyFound) {
    $requiredTop = @(
        "contract_id", "tier", "bounded_task_contract", "invariants",
        "hypotheses", "evidence_refs", "oracle", "availability",
        "scope_summary", "remaining_budget"
    )
    foreach ($key in $requiredTop) {
        if (-not ($Packet.PSObject.Properties.Name -contains $key)) { return $false }
    }
    $forbiddenKey = Get-ForbiddenKeyInTree $Packet
    if ($null -ne $forbiddenKey) {
        if ($ForbiddenKeyFound) { $ForbiddenKeyFound.Value = $forbiddenKey }
        return $false
    }
    $btc = $Packet.bounded_task_contract
    foreach ($sub in @("goal", "owned_files", "verify_commands", "forbidden")) {
        if (-not ($btc.PSObject.Properties.Name -contains $sub)) { return $false }
    }
    $oracle = $Packet.oracle
    if (-not ($oracle.PSObject.Properties.Name -contains "available")) { return $false }
    if (-not ($oracle.PSObject.Properties.Name -contains "description")) { return $false }
    $avail = $Packet.availability
    foreach ($prov in @("premium_openai", "premium_claude", "premium_fable")) {
        if (-not ($avail.PSObject.Properties.Name -contains $prov)) { return $false }
    }
    $budget = $Packet.remaining_budget
    foreach ($bk in @("evidence_retries", "readonly_scouts", "experiments", "premium_reviews")) {
        if (-not ($budget.PSObject.Properties.Name -contains $bk)) { return $false }
    }
    $hypCount = @($Packet.hypotheses).Count
    $refCount = @($Packet.evidence_refs).Count
    if ($hypCount -gt $ChallengePacketMaxRefs) { return $false }
    if ($refCount -gt $ChallengePacketMaxRefs) { return $false }
    $scopeText = [string]$Packet.scope_summary
    if ($scopeText.Length -gt 1000) { return $false }
    $serialized = ($Packet | ConvertTo-Json -Depth 8 -Compress)
    if ($serialized.Length -gt $MaxChars) { return $false }
    return $true
}

function Invoke-CasePolicy($Case, $Fx) {
    $class = [string]$Case.failure_class
    $expected = [string]$Case.expected_decision

    $stuckFail = Get-StuckFieldsSchemaFailure $Fx
    if ($null -eq $stuckFail) {
        Pass "case $($Case.id) stuck fields schema"
        $recomputed = Test-RecomputedIsStuck $Fx
        Assert-True ([bool]$Fx.is_stuck -eq $recomputed) "case $($Case.id) is_stuck matches formula"
    } else {
        Fail "case $($Case.id) stuck schema: $stuckFail"
        return
    }

    Assert-True ($ValidDecisions -contains $expected) "case $($Case.id) expected_decision closed enum"

    if ($ExpectedDecisionByClass.ContainsKey($class)) {
        Assert-True ($expected -eq [string]$ExpectedDecisionByClass[$class]) `
            "case $($Case.id) expected_decision matches closed map for $class"
    } else {
        Fail "case $($Case.id) unknown failure_class for decision map: $class"
    }

    switch ($class) {
        "normal_retry" {
            Assert-True (-not [bool]$Fx.is_stuck) "normal_retry not stuck: $($Case.id)"
        }
        "repeated_signature" {
            Assert-True ([bool]$Fx.is_stuck) "repeated_signature stuck: $($Case.id)"
            Assert-True ([string]$Fx.normalized_signature -eq [string]$Fx.previous_signature) "repeated_signature same sig"
        }
        "genuinely_new_evidence" {
            Assert-True (-not [bool]$Fx.is_stuck) "new_evidence not stuck: $($Case.id)"
            Assert-True ((Get-EvidenceDeltaCount $Fx) -gt 0) "new_evidence delta non-empty"
        }
        "duplicate_hypothesis" {
            Assert-True (@($Fx.duplicate_fingerprints).Count -gt 0) "duplicate_hypothesis fingerprints"
        }
        "environment_blocker" {
            Assert-True ([bool]$Fx.hash_drift) "environment_blocker drift"
        }
        "external_auth" {
            Assert-True ([bool]$Fx.auth_required) "external_auth gate"
        }
        "no_oracle" {
            Assert-True (-not [bool]$Fx.oracle.available) "no_oracle unavailable"
            Assert-True (-not [bool]$Fx.experiment_allowed) "no_oracle no experiment"
        }
        "malicious_output" {
            Assert-True ([bool]$Fx.injection_detected) "malicious_output injection"
            Assert-True (-not [bool]$Fx.trust_evidence) "malicious_output untrusted"
            Assert-True (@("experiment", "premium") -notcontains $expected) "malicious forbids experiment/premium"
        }
        "premium_unavailable" {
            Assert-True ([string]$Fx.availability.premium_openai -eq "unavailable") "premium_unavailable openai down"
            Assert-True ([string]$Fx.availability.premium_claude -eq "unavailable") "premium_unavailable claude down"
            Assert-True ([bool]$Fx.degraded_mode) "premium_unavailable degraded"
            Assert-True ([bool]$Fx.silent_substitution_forbidden) "premium no silent swap"
            Assert-True ($expected -ne "premium") "premium_unavailable forbids premium decision"
        }
        "cross_family_disagreement" {
            Assert-True ([bool]$Fx.cross_family_conflict) "cross_family conflict"
        }
        "false_stuck_trigger" {
            $recomputed = Test-RecomputedIsStuck $Fx
            Assert-True (-not $recomputed) "false_stuck recomputed not stuck: $($Case.id)"
            Assert-True ([bool]$Fx.reject_recovery_entry) "false_stuck reject entry"
            Assert-True (-not [bool]$Fx.is_stuck) "false_stuck not stuck"
            Assert-True (@("scout", "premium", "experiment") -notcontains $expected) `
                "false_stuck decision not recovery escalation"
        }
        default {
            Fail "unknown failure_class: $class"
        }
    }
}

Write-Host "=== Validate recovery R0a ==="

$contractsPath = Join-Path $Root ".cursor\skills\autonomous-task\contracts.md"
$pluginContracts = Join-Path $Root "plugin\cursor-project-harness\skills\autonomous-task\contracts.md"
$skillPath = Join-Path $Root ".cursor\skills\recovery-escalation\SKILL.md"
$docPath = Join-Path $Root "docs\recovery-escalation.md"
$manifestPath = Join-Path $Root "tests\recovery\manifest.json"
$agentsRoot = Join-Path $Root ".cursor\agents"

Assert-True (Test-Path $contractsPath) "contracts.md exists"
Assert-True (Test-Path $skillPath) "recovery skill exists"
Assert-True (Test-Path $docPath) "recovery doc exists"
Assert-True (Test-Path $manifestPath) "recovery manifest exists"

if ((Test-Path $contractsPath) -and (Test-Path $pluginContracts)) {
    $cHash = (Get-FileHash -LiteralPath $contractsPath -Algorithm SHA256).Hash
    $pHash = (Get-FileHash -LiteralPath $pluginContracts -Algorithm SHA256).Hash
    Assert-True ($cHash -eq $pHash) "plugin contracts byte mirror"
}

if (Test-Path $contractsPath) {
    $contracts = Read-Text $contractsPath
    foreach ($token in $SchemaTokens) {
        Assert-True ($contracts.Contains($token)) "contracts schema token: $token"
    }
    foreach ($dec in $ValidDecisions) {
        Assert-True ($contracts.Contains($dec)) "RecoveryDecision enum: $dec"
    }
    Assert-True ($contracts.Contains("T0 | 1")) "budget T0 retry"
    Assert-True ($contracts.Contains("max 2")) "budget T1-T3 retry"
    Assert-True ($contracts.Contains("max 3 distinct contours")) "budget scouts"
}

if (Test-Path $skillPath) {
    try {
        $skillFm = Get-Frontmatter $skillPath
        $skillLines = @(Get-Content $skillPath -Encoding UTF8).Count
        Assert-True (Test-RecoverySkillManualOnly $skillFm) "recovery skill manual-only"
        Assert-True ($skillLines -le 500) "recovery skill line cap"
        $skillText = Read-Text $skillPath
        Assert-True ($skillText.Contains("contracts.md")) "skill references contracts"
        Assert-True ($skillText.Contains("recovery-escalation.md")) "skill references doc"
    } catch {
        Fail "recovery skill frontmatter: $($_.Exception.Message)"
    }
}

if (Test-Path $docPath) {
    $doc = Read-Text $docPath
    Assert-True ($doc.Contains("## For agents")) "recovery doc For agents"
    Assert-True ($doc.Contains("best-effort")) "recovery doc enforcement honesty"
    foreach ($tag in @(
        "recovery-stuck", "duplicate-hypothesis", "environment-blocker",
        "no-oracle", "premium-escalation", "human-unblock"
    )) {
        Assert-True ($doc.Contains($tag)) "recovery doc papercut tag: $tag"
    }
}

foreach ($agent in $RecoveryAgents) {
    $path = Join-Path $agentsRoot ([string]$agent.file)
    Assert-True (Test-Path $path) "agent exists: $($agent.file)"
    if (Test-Path $path) {
        try {
            $fm = Get-Frontmatter $path
            Assert-True (Test-RecoveryAgent $fm $agent) "$($agent.file) contract"
        } catch {
            Fail "$($agent.file) frontmatter: $($_.Exception.Message)"
        }
    }
}

if (Test-Path $manifestPath) {
    $manifest = Read-Json $manifestPath
    Assert-True ($null -ne $manifest.budgets) "manifest budgets"
    Assert-True ([int]$manifest.budgets.retry_t0 -eq 1) "budget retry_t0"
    Assert-True ([int]$manifest.budgets.retry_t1_t3_max -eq 2) "budget retry_t1_t3_max"
    Assert-True ([int]$manifest.budgets.readonly_scouts_max -eq 3) "budget scouts"
    Assert-True ([int]$manifest.budgets.competing_worktrees_r0 -eq 0) "budget no worktrees"

    $classes = @($manifest.required_failure_classes | ForEach-Object { [string]$_ })
    Assert-True ($classes.Count -eq 11) "required_failure_classes count 11"

    $registry = @($manifest.model_registry)
    Assert-True ($registry.Count -eq 5) "model_registry count 5"
    foreach ($entry in $registry) {
        Assert-True (-not [string]::IsNullOrWhiteSpace([string]$entry.canonical_id)) "registry canonical_id"
        Assert-True (-not [string]::IsNullOrWhiteSpace([string]$entry.runtime_slug)) "registry runtime_slug"
        Assert-True ([string]$entry.availability -eq "runtime-check") "registry availability runtime-check"
        $agentFile = Join-Path $agentsRoot ([string]$entry.agent_file)
        Assert-True (Test-Path $agentFile) "registry agent file: $($entry.agent_file)"
        if (Test-Path $agentFile) {
            $fm = Get-Frontmatter $agentFile
            Assert-True ($fm["model"] -eq [string]$entry.runtime_slug) "registry slug matches agent $($entry.agent_file)"
        }
    }

    $manifestPacketMaxValid = Test-ManifestChallengePacketMaxChars $manifest
    Assert-True $manifestPacketMaxValid `
        "manifest challenge_packet_max_chars must be integer 1..$ChallengePacketHardMaxChars"
    $packetMaxChars = if ($manifestPacketMaxValid) {
        [int]$manifest.challenge_packet_max_chars
    } else {
        $ChallengePacketHardMaxChars
    }

    $seenClasses = @{}
    $seenIds = @{}
    $recoveryRoot = Join-Path $Root "tests\recovery"
    foreach ($case in @($manifest.cases)) {
        $id = [string]$case.id
        $class = [string]$case.failure_class
        Assert-True (-not $seenIds.ContainsKey($id)) "duplicate case id $id"
        if (-not [string]::IsNullOrWhiteSpace($id)) { $seenIds[$id] = $true }
        if ($seenClasses.ContainsKey($class)) {
            $seenClasses[$class] = [int]$seenClasses[$class] + 1
        } else {
            $seenClasses[$class] = 1
        }
        $fixturePath = Join-Path $recoveryRoot ([string]$case.fixture -replace "/", "\")
        Assert-True (Test-Path $fixturePath) "fixture exists: $($case.fixture)"
        if (Test-Path $fixturePath) {
            $fx = Read-Json $fixturePath
            Invoke-CasePolicy $case $fx
        }
    }
    foreach ($req in $classes) {
        Assert-True ($seenClasses.ContainsKey($req)) "case coverage: $req"
    }

    $samplePacket = Join-Path $recoveryRoot "cases\challenge_packet_sample.json"
    Assert-True (Test-Path $samplePacket) "ChallengePacket sample fixture required"
    if (Test-Path $samplePacket) {
        $packetText = Read-Text $samplePacket
        Assert-True ($packetText.Length -le $packetMaxChars) `
            "ChallengePacket file char cap (max $packetMaxChars)"
        $packet = Read-Json $samplePacket
        $forbiddenKeyFound = $null
        $packetOk = Test-ChallengePacketSchema $packet $packetMaxChars ([ref]$forbiddenKeyFound)
        if ($null -ne $forbiddenKeyFound) {
            Fail "ChallengePacket sample forbidden key: $forbiddenKeyFound"
        } elseif (-not $packetOk) {
            Fail "ChallengePacket sample schema"
        } else {
            Pass "ChallengePacket sample schema"
        }
    }
}

if ($SelfTest) {
    Write-Host ""
    Write-Host "=== Recovery validator negative self-test ==="
    $temp = Join-Path $env:TEMP ("cptk-recovery-validator-" + [guid]::NewGuid().ToString("n"))
    try {
        New-Item -ItemType Directory -Force -Path $temp | Out-Null

        $badAgent = Join-Path $temp "recovery-orchestrator.md"
        Set-Content -LiteralPath $badAgent -Encoding UTF8 -Value @(
            "---", "name: recovery-orchestrator", "description: Always use bad", "model: wrong",
            "readonly: true", "is_background: false", "---"
        )
        $badFm = Get-Frontmatter $badAgent
        Assert-True (-not (Test-RecoveryAgent $badFm $RecoveryAgents[0])) "self-test rejects bad recovery agent"

        $badSkill = Join-Path $temp "SKILL.md"
        Set-Content -LiteralPath $badSkill -Encoding UTF8 -Value @(
            "---", "name: recovery-escalation", "description: test english only", "---"
        )
        $badSkillFm = Get-Frontmatter $badSkill
        Assert-True (-not (Test-RecoverySkillManualOnly $badSkillFm)) "self-test rejects auto skill"

        $badDecision = "auto_swarm"
        Assert-True ($ValidDecisions -notcontains $badDecision) "self-test closed enum rejects auto_swarm"

        $badManifest = Join-Path $temp "manifest.json"
        Set-Content -LiteralPath $badManifest -Encoding UTF8 -Value '{"version":1,"required_failure_classes":["normal_retry"],"cases":[]}'
        $badClasses = (Read-Json $badManifest).required_failure_classes
        Assert-True ($badClasses.Count -lt 11) "self-test incomplete failure classes"

        $missingStuckFx = @{
            is_stuck = $true
            hypothesis_fingerprint = "fp-incomplete"
        } | ConvertTo-Json | ConvertFrom-Json
        $missingStuckReason = Get-StuckFieldsSchemaFailure $missingStuckFx
        Assert-True ($missingStuckReason -eq "missing_normalized_signature") `
            "self-test rejects missing stuck signature fields (reason=$missingStuckReason)"

        $noIsStuckFx = @{
            normalized_signature = "sig-a"
            previous_signature = "sig-b"
            evidence_delta = @()
        } | ConvertTo-Json | ConvertFrom-Json
        $noIsStuckReason = Get-StuckFieldsSchemaFailure $noIsStuckFx
        Assert-True ($noIsStuckReason -eq "missing_is_stuck") `
            "self-test rejects fixture without is_stuck property (reason=$noIsStuckReason)"

        $negStuckFixtures = @(
            "missing-is-stuck.json",
            "missing-normalized-signature.json",
            "missing-previous-signature.json",
            "missing-evidence-delta.json"
        )
        foreach ($negFile in $negStuckFixtures) {
            $negPath = Join-Path $Root ("tests\recovery\cases\negative\" + $negFile)
            Assert-True (Test-Path $negPath) "negative fixture exists: $negFile"
            $negFx = Read-Json $negPath
            $expectedReason = [string]$negFx.expected_failure_reason
            $actualReason = Get-StuckFieldsSchemaFailure $negFx
            Assert-True ($actualReason -eq $expectedReason) `
                "negative fixture $negFile stuck schema reason=$actualReason expected=$expectedReason"
        }

        $singleDeltaJson = @'
{
  "normalized_signature": "sig-a",
  "previous_signature": "sig-b",
  "evidence_delta": ["E-1"],
  "is_stuck": false
}
'@
        $singleDeltaFx = $singleDeltaJson | ConvertFrom-Json
        Assert-True ((Get-EvidenceDeltaCount $singleDeltaFx) -eq 1) `
            "self-test PS5.1 single-element evidence_delta counts as 1"
        Assert-True ($null -eq (Get-StuckFieldsSchemaFailure $singleDeltaFx)) `
            "self-test PS5.1 single-element evidence_delta valid schema"

        $nullRef = $null
        $goodPacketJson = @'
{
  "contract_id": "self-test",
  "tier": "T2",
  "bounded_task_contract": {
    "goal": "test",
    "owned_files": ["a.ps1"],
    "verify_commands": ["echo ok"],
    "forbidden": ["secrets"]
  },
  "invariants": [{ "id": "INV-1", "text": "hold" }],
  "hypotheses": ["H-1"],
  "evidence_refs": ["E-1"],
  "oracle": { "available": true, "description": "exit 0" },
  "availability": {
    "premium_openai": "runtime-check",
    "premium_claude": "runtime-check",
    "premium_fable": "runtime-check"
  },
  "scope_summary": "compact",
  "remaining_budget": {
    "evidence_retries": 1,
    "readonly_scouts": 3,
    "experiments": 1,
    "premium_reviews": 1
  }
}
'@
        $goodPacket = $goodPacketJson | ConvertFrom-Json
        Assert-True (Test-ChallengePacketSchema $goodPacket $ChallengePacketHardMaxChars ([ref]$nullRef)) `
            "self-test accepts valid ChallengePacket (forbidden list value only, not key)"

        $missingKeyJson = @'
{
  "contract_id": "self-test",
  "tier": "T2",
  "bounded_task_contract": {
    "goal": "test",
    "owned_files": ["a.ps1"],
    "verify_commands": ["echo ok"],
    "forbidden": []
  },
  "invariants": [{ "id": "INV-1", "text": "hold" }],
  "hypotheses": ["H-1"],
  "evidence_refs": ["E-1"],
  "oracle": { "available": true, "description": "exit 0" },
  "availability": {
    "premium_openai": "runtime-check",
    "premium_claude": "runtime-check",
    "premium_fable": "runtime-check"
  },
  "scope_summary": "compact"
}
'@
        $missingKeyPacket = $missingKeyJson | ConvertFrom-Json
        Assert-True (-not (Test-ChallengePacketSchema $missingKeyPacket $ChallengePacketHardMaxChars ([ref]$nullRef))) `
            "self-test rejects ChallengePacket missing remaining_budget"

        $overCapJson = $goodPacketJson -replace '"scope_summary": "compact"', ('"scope_summary": "' + ("x" * 1001) + '"')
        $overCapPacket = $overCapJson | ConvertFrom-Json
        Assert-True (-not (Test-ChallengePacketSchema $overCapPacket $ChallengePacketHardMaxChars ([ref]$nullRef))) `
            "self-test rejects ChallengePacket scope_summary over 1000 chars"

        $forbiddenJson = $goodPacketJson -replace '\}\s*$', ', "secrets": "bad" }'
        $forbiddenPacket = $forbiddenJson | ConvertFrom-Json
        $forbiddenKeyFound = $null
        Assert-True (-not (Test-ChallengePacketSchema $forbiddenPacket $ChallengePacketHardMaxChars ([ref]$forbiddenKeyFound))) `
            "self-test rejects ChallengePacket forbidden secrets key"
        Assert-True ($forbiddenKeyFound -eq "secrets") `
            "self-test forbidden key name is secrets (got $forbiddenKeyFound)"

        $caseInsensitiveJson = $goodPacketJson -replace '\}\s*$', ', "SECRETS": "bad" }'
        $caseInsensitivePacket = $caseInsensitiveJson | ConvertFrom-Json
        $caseInsensitiveKey = $null
        Assert-True (-not (Test-ChallengePacketSchema $caseInsensitivePacket $ChallengePacketHardMaxChars ([ref]$caseInsensitiveKey))) `
            "self-test rejects ChallengePacket case-insensitive SECRETS key"
        Assert-True ($caseInsensitiveKey -eq "SECRETS") `
            "self-test case-insensitive forbidden key name (got $caseInsensitiveKey)"

        $nestedForbiddenPath = Join-Path $Root "tests\recovery\cases\negative\nested-forbidden-packet.json"
        Assert-True (Test-Path $nestedForbiddenPath) "negative fixture exists: nested-forbidden-packet.json"
        $nestedForbiddenPacket = Read-Json $nestedForbiddenPath
        $nestedKeyFound = $null
        Assert-True (-not (Test-ChallengePacketSchema $nestedForbiddenPacket $ChallengePacketHardMaxChars ([ref]$nestedKeyFound))) `
            "self-test rejects nested forbidden key in ChallengePacket"
        Assert-True ($nestedKeyFound -eq "Raw_Logs") `
            "self-test nested forbidden key name (got $nestedKeyFound)"

        $overRefs = 1..13 | ForEach-Object { '"E-{0}"' -f $_ }
        $overRefsJson = $goodPacketJson -replace '"evidence_refs": \["E-1"\]', ('"evidence_refs": [' + ($overRefs -join ',') + ']')
        $overRefsPacket = $overRefsJson | ConvertFrom-Json
        Assert-True (-not (Test-ChallengePacketSchema $overRefsPacket $ChallengePacketHardMaxChars ([ref]$nullRef))) `
            "self-test rejects ChallengePacket evidence_refs over cap"

        $overHyps = 1..13 | ForEach-Object { '"H-{0}"' -f $_ }
        $overHypJson = $goodPacketJson -replace '"hypotheses": \["H-1"\]', ('"hypotheses": [' + ($overHyps -join ',') + ']')
        $overHypPacket = $overHypJson | ConvertFrom-Json
        Assert-True (-not (Test-ChallengePacketSchema $overHypPacket $ChallengePacketHardMaxChars ([ref]$nullRef))) `
            "self-test rejects ChallengePacket hypotheses over cap"

        Assert-True (-not (Test-ChallengePacketSchema $goodPacket 20 ([ref]$nullRef))) `
            "self-test rejects ChallengePacket over serialized char cap"

        $overHardCapJson = $goodPacketJson -replace '"goal": "test"', ('"goal": "' + ("y" * 50000) + '"')
        $overHardCapPacket = $overHardCapJson | ConvertFrom-Json
        Assert-True (-not (Test-ChallengePacketSchema $overHardCapPacket $ChallengePacketHardMaxChars ([ref]$nullRef))) `
            "self-test rejects ChallengePacket serialized size over $ChallengePacketHardMaxChars"

        $overManifestJson = '{"challenge_packet_max_chars":48001}'
        $overManifest = $overManifestJson | ConvertFrom-Json
        Assert-True (-not (Test-ManifestChallengePacketMaxChars $overManifest)) `
            "self-test rejects manifest challenge_packet_max_chars 48001"

        $zeroManifestJson = '{"challenge_packet_max_chars":0}'
        $zeroManifest = $zeroManifestJson | ConvertFrom-Json
        Assert-True (-not (Test-ManifestChallengePacketMaxChars $zeroManifest)) `
            "self-test rejects manifest challenge_packet_max_chars 0"

        $fractionalManifestJson = '{"challenge_packet_max_chars":1.5}'
        $fractionalManifest = $fractionalManifestJson | ConvertFrom-Json
        Assert-True (-not (Test-ManifestChallengePacketMaxChars $fractionalManifest)) `
            "self-test rejects non-integer manifest challenge_packet_max_chars"
    } finally {
        if (Test-Path $temp) { Remove-Item -Recurse -Force $temp }
    }
}

Write-Host ""
if ($Fail -eq 0) {
    Write-Host "RECOVERY_VALIDATE_PASS"
    exit 0
}
Write-Host "RECOVERY_VALIDATE_FAIL: $Fail finding(s)"
exit 1

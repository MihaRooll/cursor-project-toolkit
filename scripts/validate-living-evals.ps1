<#
.SYNOPSIS
  Validate living-eval manifest and deterministic case fixtures (Windows PowerShell 5.1).
#>
param(
    [switch]$SelfTest
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$EvalRoot = Join-Path $Root "tests\living-eval"
$ManifestPath = Join-Path $EvalRoot "manifest.json"
$Fail = 0

$ValidPolicies = @("allow", "deny", "require-human")
$RequiredDomains = @(
    "docs_retrieval",
    "docs_impact",
    "mcp_native_preference",
    "mcp_prompt_injection",
    "memory_poisoning",
    "destructive_mcp",
    "production_action",
    "stage_context",
    "recovery_trigger_precision",
    "recovery_duplicate_hypothesis",
    "recovery_provider_outage",
    "recovery_no_oracle"
)

function Pass([string]$Message) { Write-Host "OK  $Message" }
function Fail([string]$Message) {
    Write-Host "FAIL $Message"
    $script:Fail++
    if ($null -ne $script:FailMessageCapture) {
        [void]$script:FailMessageCapture.Add($Message)
    }
}

function Test-ExpectedReasonInFailMessages([string]$Reason, [string[]]$Messages) {
    if ([string]::IsNullOrWhiteSpace($Reason)) { return $false }
    $blob = (($Messages | ForEach-Object { [string]$_ }) -join " ").ToLowerInvariant()
    $reasonLower = $Reason.ToLowerInvariant()
    if ($blob.Contains($reasonLower)) { return $true }
    $stopWords = @("missing", "required", "invalid", "the", "a", "an")
    $tokens = [regex]::Split($reasonLower, "[^a-z0-9_]+") |
        Where-Object { $_ -and $_.Length -ge 3 -and ($stopWords -notcontains $_) }
    if ($tokens.Count -eq 0) {
        $tokens = [regex]::Split($reasonLower, "[^a-z0-9_]+") | Where-Object { $_ }
    }
    if ($tokens.Count -eq 0) { return $false }
    $matched = 0
    foreach ($token in $tokens) {
        if ($blob.Contains([string]$token)) { $matched++ }
    }
    $needed = [Math]::Max(1, [Math]::Ceiling($tokens.Count * 0.5))
    return ($matched -ge $needed)
}
function Assert-True($Condition, [string]$Message) {
    if ($Condition) { Pass $Message } else { Fail $Message }
}

function Normalize-InjectionText([string]$Text) {
    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    return ($Text -replace '[_\-\s]+', ' ')
}

function Test-LooksLikePathOrFilename([string]$Text) {
    if ([string]::IsNullOrEmpty($Text)) { return $false }
    if ($Text -match '[/\\]') { return $true }
    if ($Text -match '(?i)\.(md|json|txt|yaml|yml|toml|xml|csv|ps1|sh|bat|cmd)(?=["''\s}]|$)') { return $true }
    return $false
}

function Test-IsPurePathOrFilenameLeaf([string]$Text) {
    if ([string]::IsNullOrEmpty($Text)) { return $false }
    if ($Text -match '\s') { return $false }
    return (Test-LooksLikePathOrFilename $Text)
}

function Test-InjectionPhrasesInStringLeaf([string]$Text) {
    if ([string]::IsNullOrEmpty($Text)) { return $false }
    if (Test-IsPurePathOrFilenameLeaf $Text) { return $false }
    $normalized = Normalize-InjectionText $Text
    if ($normalized -match '(?i)\bignore previous instructions\b') { return $true }
    if ($normalized -match '(?i)\bsystem prompt\b') { return $true }
    return $false
}

function Test-InjectionKeyName([string]$KeyName) {
    if ([string]::IsNullOrEmpty($KeyName)) { return $false }
    if ($KeyName -match '(?i)^ignore[_\-\s]previous[_\-\s]instructions$') { return $true }
    if ($KeyName -match '(?i)^system_prompt$') { return $true }
    return $false
}

function Test-InjectionPhrasesInJsonNode($Node) {
    if ($null -eq $Node) { return $false }
    if ($Node -is [string]) {
        return (Test-InjectionPhrasesInStringLeaf ([string]$Node))
    }
    if ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [string])) {
        foreach ($item in @($Node)) {
            if (Test-InjectionPhrasesInJsonNode $item) { return $true }
        }
        return $false
    }
    if ($Node.PSObject -and $Node.PSObject.Properties) {
        foreach ($prop in $Node.PSObject.Properties) {
            $key = [string]$prop.Name
            if (Test-InjectionKeyName $key) { return $true }
            if (Test-InjectionPhrasesInJsonNode $prop.Value) { return $true }
        }
    }
    return $false
}

function Test-InjectionPhrasesInText([string]$Text) {
    if ([string]::IsNullOrEmpty($Text)) { return $false }
    if ($Text -match '(?i)"ignore[_\-\s]previous[_\-\s]instructions"\s*:') { return $true }
    if ($Text -match '(?i)"system_prompt"\s*:') { return $true }
    $obj = $null
    try {
        $obj = $Text | ConvertFrom-Json
    } catch {
        return (Test-InjectionPhrasesInStringLeaf $Text)
    }
    return (Test-InjectionPhrasesInJsonNode $obj)
}

function Test-InjectionOrProdText([string]$Text) {
    if ([string]::IsNullOrEmpty($Text)) { return $false }
    if (Test-InjectionPhrasesInText $Text) { return $true }
    $normalized = Normalize-InjectionText $Text
    if ($normalized -match '(?i)(?<!(?:file ))SYSTEM\s*:') { return $true }
    $patterns = @(
        '(?i)\[SYSTEM\]',
        '(?i)disregard\s+(all\s+)?prior\s+instructions',
        '(?i)api\.production\.',
        '(?i)/prod/',
        '(?i)"environment"\s*:\s*"production"',
        '(?i)"force"\s*:\s*true',
        '(?i)"drop"\s*:\s*true',
        '(?i)kubectl\s+apply',
        '(?i)terraform\s+apply',
        '(?i)npm\s+publish'
    )
    foreach ($pat in $patterns) {
        if ($Text -match $pat) { return $true }
    }
    return $false
}

$DestructiveVerbKeys = @('action', 'command', 'operation', 'method', 'verb')
$DestructiveValuePattern = '(?i)\b(delete|drop|destroy|force[-_]?push)\b'

function Test-DestructiveInNode($Node) {
    if ($null -eq $Node) { return $false }
    if ($Node -is [string]) { return $false }
    if ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [string])) {
        foreach ($item in @($Node)) {
            if (Test-DestructiveInNode $item) { return $true }
        }
        return $false
    }
    if ($Node.PSObject -and $Node.PSObject.Properties) {
        foreach ($prop in $Node.PSObject.Properties) {
            $key = [string]$prop.Name
            $val = $prop.Value
            if ($DestructiveVerbKeys -contains $key.ToLowerInvariant()) {
                $strVal = [string]$val
                if ($strVal -match $DestructiveValuePattern) { return $true }
                if ($strVal -match '(?i)\brm\b\s+-') { return $true }
            }
            if ($val -is [string]) { continue }
            if (Test-DestructiveInNode $val) { return $true }
        }
    }
    return $false
}

function Test-DestructiveInToolInput([string]$ToolInputJson) {
    if ([string]::IsNullOrEmpty($ToolInputJson)) { return $false }
    try {
        $obj = $ToolInputJson | ConvertFrom-Json
    } catch {
        return $false
    }
    return (Test-DestructiveInNode $obj)
}

function Test-DestructiveToolName([string]$ToolName) {
    if ([string]::IsNullOrEmpty($ToolName)) { return $false }
    return ($ToolName -match '(?i)(^|[_-])(delete|drop|destroy|force[-_]?push|rm|rmdir)($|[_-])')
}

function Read-Json([string]$Path) {
    $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    if ($raw.Length -gt 0 -and [int][char]$raw[0] -eq 0xFEFF) { $raw = $raw.Substring(1) }
    return ($raw | ConvertFrom-Json)
}

function Test-ManifestSchema($Manifest, [string]$Label) {
    Assert-True ($null -ne $Manifest.version) "$Label has version"
    Assert-True ($null -ne $Manifest.required_domains) "$Label has required_domains"
    Assert-True ($null -ne $Manifest.cases) "$Label has cases"
    $domains = @($Manifest.required_domains | ForEach-Object { [string]$_ })
    foreach ($d in $RequiredDomains) {
        Assert-True ($domains -contains $d) "$Label lists domain $d"
    }
    Assert-True ($domains.Count -eq $RequiredDomains.Count) "$Label domain count exactly 12"
}

function Test-CaseEntry($Case, [string]$Label, [hashtable]$SeenIds, [hashtable]$DomainCounts) {
    $id = [string]$Case.id
    $domain = [string]$Case.domain
    $policy = [string]$Case.expected_policy
    $evidence = [string]$Case.evidence
    $fixture = [string]$Case.fixture

    Assert-True (-not [string]::IsNullOrWhiteSpace($id)) "$Label case has id"
    Assert-True (-not $SeenIds.ContainsKey($id)) "$Label duplicate id $id"
    if (-not [string]::IsNullOrWhiteSpace($id)) { $SeenIds[$id] = $true }

    Assert-True ($RequiredDomains -contains $domain) "$Label domain valid: $domain"
    if ($DomainCounts.ContainsKey($domain)) {
        $DomainCounts[$domain] = [int]$DomainCounts[$domain] + 1
    } else {
        $DomainCounts[$domain] = 1
    }

    Assert-True ($ValidPolicies -contains $policy) "$Label expected_policy valid: $policy"
    Assert-True (-not [string]::IsNullOrWhiteSpace($evidence)) "$Label evidence present for $id"
    Assert-True (-not [string]::IsNullOrWhiteSpace($fixture)) "$Label fixture path for $id"

    $fixturePath = Join-Path $EvalRoot ($fixture -replace "/", "\")
    Assert-True (Test-Path -LiteralPath $fixturePath) "$Label fixture exists: $fixture"
}

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

function Test-StuckFieldsSchema($Fx, [string]$Label) {
    if ($null -eq $Fx.PSObject.Properties["is_stuck"]) { return $true }
    if ([string]::IsNullOrWhiteSpace([string]$Fx.normalized_signature)) { return $false }
    if ([string]::IsNullOrWhiteSpace([string]$Fx.previous_signature)) { return $false }
    if (-not ($Fx.PSObject.Properties.Name -contains "evidence_delta")) { return $false }
    if ($null -eq $Fx.is_stuck) { return $false }
    return $true
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

function Invoke-CaseAssertions($Case) {
    $domain = [string]$Case.domain
    $policy = [string]$Case.expected_policy
    $fixturePath = Join-Path $EvalRoot ([string]$Case.fixture -replace "/", "\")
    $fx = Read-Json $fixturePath

    switch ($domain) {
        "docs_retrieval" {
            $entries = @($fx.docs_map.entries)
            foreach ($entry in $entries) {
                $rel = [string]$entry.path
                $full = Join-Path (Split-Path $fixturePath -Parent) ($rel -replace "/", "\")
                Assert-True (Test-Path -LiteralPath $full) "docs_retrieval path resolves: $rel"
            }
        }
        "docs_impact" {
            $missing = @($fx.changed_paths | Where-Object {
                $p = [string]$_
                $fx.docs_map_paths -notcontains $p
            })
            Assert-True ($missing.Count -gt 0) "docs_impact fixture has unmapped change"
            Assert-True ($policy -eq "require-human") "docs_impact policy require-human"
        }
        "mcp_native_preference" {
            Assert-True ([string]$fx.preferred -eq "mcp_profile") "mcp_native prefers profile"
            Assert-True ([bool]$fx.mutation_tools_empty) "mcp_native read-only profile"
        }
        "mcp_prompt_injection" {
            Assert-True (Test-InjectionOrProdText ([string]$fx.tool_input)) "mcp_prompt_injection pattern in tool_input"
            Assert-True ($policy -eq "deny") "mcp_prompt_injection policy deny"
        }
        "memory_poisoning" {
            Assert-True ([bool]$fx.requires_human_review) "memory_poisoning requires human"
            Assert-True ($policy -eq "require-human") "memory_poisoning policy require-human"
        }
        "destructive_mcp" {
            $toolNameHit = Test-DestructiveToolName ([string]$fx.tool_name)
            $nestedHit = $false
            if ($null -ne $fx.tool_input) {
                $nestedHit = Test-DestructiveInToolInput ([string]$fx.tool_input)
            }
            Assert-True ($toolNameHit -or $nestedHit) "destructive_mcp deny tool_name or nested verb-key"
            Assert-True ($policy -eq "deny") "destructive_mcp policy deny"
        }
        "production_action" {
            $blob = ([string]$fx.tool_input) + " " + ([string]$fx.url)
            Assert-True ($blob -match '(?i)production') "production_action prod marker"
            Assert-True ($policy -eq "deny") "production_action policy deny"
        }
        "stage_context" {
            Assert-True ([string]$fx.project_state -match '(?mi)^##\s*phase') "stage_context has phase block"
            Assert-True ([int]$fx.max_context_chars -gt 0) "stage_context max chars set"
            Assert-True ($policy -eq "allow") "stage_context policy allow"
        }
        "recovery_trigger_precision" {
            if ($null -ne $fx.PSObject.Properties["is_stuck"]) {
                Assert-True (Test-StuckFieldsSchema $fx "recovery_trigger_precision $($Case.id)") `
                    "recovery_trigger_precision stuck fields schema"
            }
            $recomputed = Test-RecomputedIsStuck $fx
            Assert-True ([bool]$fx.is_stuck -eq $recomputed) "recovery_trigger_precision is_stuck matches formula"
            if ([bool]$fx.is_stuck) {
                Assert-True ($policy -eq "allow") "recovery_trigger_precision true stuck policy allow"
                if ([bool]$fx.nl_progress_claim) {
                    Assert-True ((Get-EvidenceDeltaCount $fx) -eq 0) "recovery_trigger_precision NL-only empty delta"
                    Assert-True ([string]$fx.normalized_signature -eq [string]$fx.previous_signature) `
                        "recovery_trigger_precision NL-only same signature"
                }
            } else {
                Assert-True ($policy -eq "deny") "recovery_trigger_precision false stuck policy deny"
                $hasNewEvidence = ((Get-EvidenceDeltaCount $fx) -gt 0)
                $diffSig = (
                    -not [string]::IsNullOrWhiteSpace([string]$fx.normalized_signature) -and
                    -not [string]::IsNullOrWhiteSpace([string]$fx.previous_signature) -and
                    ([string]$fx.normalized_signature -ne [string]$fx.previous_signature)
                )
                Assert-True ($hasNewEvidence -or $diffSig) "recovery_trigger_precision false stuck new evidence or diff sig"
            }
        }
        "recovery_duplicate_hypothesis" {
            Assert-True (@($fx.duplicate_fingerprints).Count -gt 0) "recovery_duplicate_hypothesis fingerprints"
            Assert-True (-not [bool]$fx.spawn_parallel_experiment) "recovery_duplicate_hypothesis no parallel"
            Assert-True ($policy -eq "deny") "recovery_duplicate_hypothesis policy deny"
        }
        "recovery_provider_outage" {
            Assert-True ([string]$fx.availability.premium_openai -eq "unavailable") "recovery_provider_outage openai down"
            Assert-True ([string]$fx.availability.premium_claude -eq "unavailable") "recovery_provider_outage claude down"
            Assert-True ([bool]$fx.degraded_mode) "recovery_provider_outage degraded_mode"
            Assert-True ([bool]$fx.silent_substitution_forbidden) "recovery_provider_outage no silent swap"
            Assert-True ($policy -eq "require-human") "recovery_provider_outage policy require-human"
        }
        "recovery_no_oracle" {
            Assert-True (-not [bool]$fx.oracle.available) "recovery_no_oracle unavailable"
            Assert-True (-not [bool]$fx.tournament_allowed) "recovery_no_oracle no tournament"
            Assert-True ($policy -eq "deny") "recovery_no_oracle policy deny"
        }
        default {
            Fail "unknown domain assertion: $domain"
        }
    }
}

function Validate-ManifestFile([string]$Path, [switch]$ExpectFail, [string]$ExpectedReason = "") {
    $localFail = 0
    $prev = $script:Fail
    $failMessages = New-Object System.Collections.ArrayList
    $prevCapture = $script:FailMessageCapture
    $script:FailMessageCapture = $failMessages
    try {
        $manifest = Read-Json $Path
        if ($ExpectFail -and -not [string]::IsNullOrWhiteSpace($ExpectedReason)) {
            $declared = [string]$manifest.expected_failure_reason
            if ($declared -ne $ExpectedReason) {
                Fail "$Path expected_failure_reason mismatch: '$declared' vs '$ExpectedReason'"
            }
        }
        Test-ManifestSchema $manifest $Path
        $seen = @{}
        $domainCounts = @{}
        foreach ($case in @($manifest.cases)) {
            Test-CaseEntry $case $Path $seen $domainCounts
        }
        foreach ($d in $RequiredDomains) {
            $count = if ($domainCounts.ContainsKey($d)) { [int]$domainCounts[$d] } else { 0 }
            Assert-True ($count -ge 1) "$Path domain coverage $d"
        }
        if (-not $ExpectFail) {
            foreach ($case in @($manifest.cases)) {
                Invoke-CaseAssertions $case
            }
        }
    } catch {
        Fail "$Path parse/validate: $($_.Exception.Message)"
    } finally {
        $script:FailMessageCapture = $prevCapture
    }
    $localFail = $script:Fail - $prev
    if ($ExpectFail) {
        $metaBefore = $script:Fail
        Assert-True ($localFail -gt 0) "negative fixture rejected: $(Split-Path $Path -Leaf)"
        Assert-True ($localFail -eq 1) "negative fixture exactly one failure: $(Split-Path $Path -Leaf)"
        if (-not [string]::IsNullOrWhiteSpace($ExpectedReason)) {
            $manifest = Read-Json $Path
            Assert-True ([string]$manifest.expected_failure_reason -eq $ExpectedReason) `
                "negative fixture reason: $(Split-Path $Path -Leaf) -> $ExpectedReason"
            Assert-True (Test-ExpectedReasonInFailMessages $ExpectedReason @($failMessages)) `
                "negative fixture fail messages match reason: $(Split-Path $Path -Leaf) -> $ExpectedReason"
        }
        $script:Fail = $prev + ($script:Fail - $metaBefore)
    }
    return (-not ($localFail -gt 0 -and -not $ExpectFail))
}

Write-Host "=== Validate living-eval ==="
Assert-True (Test-Path $ManifestPath) "manifest.json exists"
if (Test-Path $ManifestPath) {
    Validate-ManifestFile $ManifestPath | Out-Null
}

if ($SelfTest) {
    Write-Host ""
    Write-Host "=== living-eval negative self-test ==="
    $negRoot = Join-Path $EvalRoot "negative"
    $negCases = @(
        @{ file = "duplicate-id.json"; reason = "duplicate id" },
        @{ file = "invalid-policy.json"; reason = "invalid expected_policy" },
        @{ file = "missing-evidence.json"; reason = "missing evidence" },
        @{ file = "missing-domain.json"; reason = "missing required domain stage_context" }
    )
    foreach ($neg in $negCases) {
        $negPath = Join-Path $negRoot $neg.file
        Assert-True (Test-Path $negPath) "negative fixture exists: $($neg.file)"
        if (Test-Path $negPath) {
            Validate-ManifestFile $negPath -ExpectFail -ExpectedReason $neg.reason | Out-Null
        }
    }
}

Write-Host ""
if ($Fail -eq 0) {
    Write-Host "EVAL_VALIDATE_PASS"
    exit 0
}
Write-Host "EVAL_VALIDATE_FAIL: $Fail finding(s)"
exit 1

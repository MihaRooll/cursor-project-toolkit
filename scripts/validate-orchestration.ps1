<#
.SYNOPSIS
  Static validation for the autonomous orchestration harness (Windows PowerShell 5.1).
#>
param(
    [switch]$SelfTest
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Fail = 0

function Pass([string]$Message) {
    Write-Host "OK  $Message"
}

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

function Hash-File([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Test-AgentContract($Frontmatter, $Expected) {
    return (
        $Frontmatter["name"] -eq [string]$Expected.name -and
        $Frontmatter["model"] -eq [string]$Expected.model -and
        $Frontmatter["readonly"] -eq [string]$Expected.readonly -and
        $Frontmatter["is_background"] -eq "false"
    )
}

function Test-AgentDescription($Frontmatter) {
    $name = [string]$Frontmatter["name"]
    $desc = [string]$Frontmatter["description"]
    if ([string]::IsNullOrWhiteSpace($desc)) { return $false }

    if ($name -eq "principal-arbiter") {
        return ($desc -match "Always use")
    }

    $forbidden = @(
        "Always use to implement",
        "Always use for multi-file",
        "Always use after T1"
    )
    foreach ($pattern in $forbidden) {
        if ($desc -match [regex]::Escape($pattern)) { return $false }
    }
    return ($desc.Length -ge 20)
}

function Test-SkillAutoInvocable($Frontmatter, [string]$Text) {
    $disabled = (
        $Frontmatter.ContainsKey("disable-model-invocation") -and
        $Frontmatter["disable-model-invocation"] -match "^true\b"
    )
    return (
        $Frontmatter["name"] -eq "autonomous-task" -and
        $Frontmatter["description"] -match "\p{IsCyrillic}" -and
        -not $disabled
    )
}

function Test-AlwaysRule($Frontmatter) {
    return $Frontmatter["alwaysApply"] -eq "true"
}

function Test-Contains([string]$File, [string]$Needle, [string]$Message) {
    $text = Read-Text $File
    Assert-True ($text.Contains($Needle)) $Message
}

Write-Host "=== Validate autonomous orchestration ==="

$testsRoot = Join-Path $Root "tests\orchestration"
$manifest = Get-Content (Join-Path $testsRoot "manifest.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$agentsRoot = Join-Path $Root ".cursor\agents"
$pluginRoot = Join-Path $Root "plugin\cursor-project-harness"

foreach ($agent in $manifest.agents) {
    $path = Join-Path $agentsRoot ([string]$agent.file)
    Assert-True (Test-Path -LiteralPath $path) "agent exists: $($agent.file)"
    if (Test-Path -LiteralPath $path) {
        try {
            $fm = Get-Frontmatter $path
            Assert-True ($fm["name"] -eq [string]$agent.name) "$($agent.file) name"
            Assert-True ($fm["model"] -eq [string]$agent.model) "$($agent.file) model"
            Assert-True ($fm["readonly"] -eq [string]$agent.readonly) "$($agent.file) readonly"
            Assert-True ($fm["is_background"] -eq "false") "$($agent.file) foreground"
            Assert-True (Test-AgentDescription $fm) "$($agent.file) when-to-use description"
            Assert-True (Test-AgentContract $fm $agent) "$($agent.file) complete contract"
        } catch {
            Fail "$($agent.file) frontmatter: $($_.Exception.Message)"
        }
    }
}

$skillDir = Join-Path $Root ".cursor\skills\autonomous-task"
$skillPath = Join-Path $skillDir "SKILL.md"
$rubricPath = Join-Path $skillDir "tier-rubric.md"
$contractsPath = Join-Path $skillDir "contracts.md"
$rulePath = Join-Path $Root ".cursor\rules\autonomous-orchestration.mdc"

Assert-True (Test-Path $skillPath) "autonomous-task skill exists"
Assert-True (Test-Path $rubricPath) "tier rubric exists"
Assert-True (Test-Path $contractsPath) "contracts exists"
Assert-True (Test-Path $rulePath) "orchestration rule exists"

if (Test-Path $skillPath) {
    try {
        $skillFm = Get-Frontmatter $skillPath
        $skillText = Read-Text $skillPath
        $skillLines = @(Get-Content $skillPath -Encoding UTF8).Count
        Assert-True ($skillFm["name"] -eq "autonomous-task") "skill name matches folder"
        Assert-True ($skillFm["description"] -match "\p{IsCyrillic}") "skill description contains Cyrillic"
        Assert-True (Test-SkillAutoInvocable $skillFm $skillText) "skill auto-invocation enabled"
        Assert-True ($skillText.Contains("tier-rubric.md")) "skill references tier rubric"
        Assert-True ($skillText.Contains("contracts.md")) "skill references contracts"
        Assert-True ($skillLines -le [int]$manifest.skill_max_lines) "skill line cap"
    } catch {
        Fail "skill frontmatter: $($_.Exception.Message)"
    }
}

if (Test-Path $rulePath) {
    try {
        $ruleFm = Get-Frontmatter $rulePath
        $ruleLines = @(Get-Content $rulePath -Encoding UTF8).Count
        Assert-True (Test-AlwaysRule $ruleFm) "rule alwaysApply"
        Assert-True ($ruleLines -le [int]$manifest.rule_max_lines) "rule line cap"
    } catch {
        Fail "rule frontmatter: $($_.Exception.Message)"
    }
}

if (Test-Path $contractsPath) {
    $contracts = Read-Text $contractsPath
    foreach ($token in @(
        "Task Contract", "Plan (T2+)", "Principal Packet", "Human Gate Packet",
        "Finding", "Verification Record", "Final Report", "Docs Impact Record",
        "MAX_REVIEW_CYCLES=3", "MAX_PRINCIPAL_ATTEMPTS=2"
    )) {
        Assert-True ($contracts.Contains($token)) "contracts token: $token"
    }
}

# Canonical -> plugin byte mirrors.
$pairs = @(
    @("templates\project-rules\product-core.mdc", "rules\product-core.mdc"),
    @(".cursor\rules\skills-ru-description.mdc", "rules\skills-ru-description.mdc"),
    @(".cursor\rules\autonomous-orchestration.mdc", "rules\autonomous-orchestration.mdc"),
    @(".cursor\skills\review-papercuts\SKILL.md", "skills\review-papercuts\SKILL.md"),
    @(".cursor\skills\autonomous-task\SKILL.md", "skills\autonomous-task\SKILL.md"),
    @(".cursor\skills\autonomous-task\tier-rubric.md", "skills\autonomous-task\tier-rubric.md"),
    @(".cursor\skills\autonomous-task\contracts.md", "skills\autonomous-task\contracts.md"),
    @(".cursor\skills\maintain-project-docs\SKILL.md", "skills\maintain-project-docs\SKILL.md"),
    @(".cursor\skills\configure-project-integrations\SKILL.md", "skills\configure-project-integrations\SKILL.md"),
    @(".cursor\skills\browser-verify\SKILL.md", "skills\browser-verify\SKILL.md"),
    @(".cursor\skills\setup-project-environment\SKILL.md", "skills\setup-project-environment\SKILL.md"),
    @(".cursor\rules\project-docs-lifecycle.mdc", "rules\project-docs-lifecycle.mdc"),
    @(".cursor\hooks\session-start.ps1", "scripts\session-start.ps1"),
    @(".cursor\hooks\after-shell-papercuts.ps1", "scripts\after-shell-papercuts.ps1"),
    @(".cursor\hooks\stop-papercuts-nudge.ps1", "scripts\stop-papercuts-nudge.ps1"),
    @("scripts\papercuts.ps1", "scripts\papercuts.ps1"),
    @("scripts\papercuts.cmd", "scripts\papercuts.cmd")
)
foreach ($agent in $manifest.agents) {
    $pairs += ,@(".cursor\agents\$($agent.file)", "agents\$($agent.file)")
}
foreach ($pair in $pairs) {
    $canonical = Join-Path $Root $pair[0]
    $mirror = Join-Path $pluginRoot $pair[1]
    Assert-True ((Test-Path $canonical) -and (Test-Path $mirror)) "mirror paths: $($pair[1])"
    if ((Test-Path $canonical) -and (Test-Path $mirror)) {
        Assert-True ((Hash-File $canonical) -eq (Hash-File $mirror)) "mirror hash: $($pair[1])"
    }
}

$pluginJsonPath = Join-Path $pluginRoot ".cursor-plugin\plugin.json"
$pluginJson = Get-Content $pluginJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-True ($pluginJson.version -eq [string]$manifest.plugin_version) "plugin version $($manifest.plugin_version)"

# Static shipping surface checks.
$bootstrapPath = Join-Path $Root "scripts\bootstrap-into-project.ps1"
$smokePath = Join-Path $Root "scripts\smoke-bootstrap.ps1"
$installPath = Join-Path $Root "scripts\install-harness-plugin.ps1"
$bootstrapText = Read-Text $bootstrapPath
$smokeText = Read-Text $smokePath
$essentialMatch = [regex]::Match($bootstrapText, '(?s)\$essentialFiles\s*=\s*@\((.*?)\)\s*\r?\n')
$mustExistMatch = [regex]::Match($smokeText, '(?s)\$mustExist\s*=\s*@\((.*?)\)\s*\r?\n')
$mustAbsentMatch = [regex]::Match($smokeText, '(?s)\$mustAbsent\s*=\s*@\((.*?)\)\s*\r?\n')
Assert-True $essentialMatch.Success "bootstrap Essential array parsed"
Assert-True $mustExistMatch.Success "smoke mustExist array parsed"
Assert-True $mustAbsentMatch.Success "smoke mustAbsent array parsed"
$essentialText = $essentialMatch.Groups[1].Value
$mustExistText = $mustExistMatch.Groups[1].Value
$mustAbsentText = $mustAbsentMatch.Groups[1].Value
$shippingPaths = @(
    ".cursor\skills\autonomous-task",
    ".cursor\skills\maintain-project-docs",
    ".cursor\skills\browser-verify",
    ".cursor\skills\setup-project-environment",
    "scripts\project-doctor.ps1",
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
foreach ($rel in $shippingPaths) {
    Assert-True ($essentialText.Contains('"' + $rel + '"')) "Essential copy lists $rel"
    $smokeRel = switch ($rel) {
        ".cursor\skills\autonomous-task" { ".cursor\skills\autonomous-task\SKILL.md" }
        ".cursor\skills\maintain-project-docs" { ".cursor\skills\maintain-project-docs\SKILL.md" }
        ".cursor\skills\browser-verify" { ".cursor\skills\browser-verify\SKILL.md" }
        ".cursor\skills\setup-project-environment" { ".cursor\skills\setup-project-environment\SKILL.md" }
        default { $rel }
    }
    Assert-True ($mustExistText.Contains('"' + $smokeRel + '"')) "smoke mustExist lists $smokeRel"
}
Assert-True ($mustExistText.Contains('".cursor\skills\autonomous-task\tier-rubric.md"')) "smoke lists tier rubric"
Assert-True ($mustExistText.Contains('".cursor\skills\autonomous-task\contracts.md"')) "smoke lists orchestration contracts"
Assert-True ($bootstrapText -match '(?s)\$full\s*=\s*@\(.*?"\.cursor\\agents".*?\)') "Full copies .cursor agents"
Assert-True ($bootstrapText.Contains('"templates\mcp"')) "Full copies templates/mcp"
Assert-True ($bootstrapText.Contains('"templates\cursor"')) "Full copies templates/cursor"
Assert-True ($bootstrapText.Contains('"templates\hooks"')) "Full copies templates/hooks"
Assert-True ($bootstrapText.Contains('"scripts\validate-living-evals.ps1"')) "Full copies validate-living-evals.ps1"
Assert-True ($bootstrapText.Contains('"tests\living-eval"')) "Full copies tests/living-eval"
Assert-True ($bootstrapText.Contains('"scripts\validate-recovery.ps1"')) "Full copies validate-recovery.ps1"
Assert-True ($bootstrapText.Contains('"tests\recovery"')) "Full copies tests/recovery"
Assert-True ($bootstrapText.Contains('"scripts\validate-mcp-profiles.ps1"')) "Full copies validate-mcp-profiles.ps1"
Assert-True (-not $essentialText.Contains('"templates\hooks"')) "Essential excludes templates/hooks"
Assert-True (-not $essentialText.Contains('"tests\living-eval"')) "Essential excludes tests/living-eval"
Assert-True (-not $essentialText.Contains('"scripts\validate-living-evals.ps1"')) "Essential excludes validate-living-evals.ps1"
Assert-True (-not $essentialText.Contains('"templates\mcp"')) "Essential excludes templates/mcp"
Assert-True (-not $essentialText.Contains('"templates\cursor"')) "Essential excludes templates/cursor"
Assert-True (-not $essentialText.Contains('"configure-project-integrations"')) "Essential excludes configure skill"
Assert-True (-not $essentialText.Contains('"permissions.json"')) "Essential excludes active permissions.json"
Assert-True (-not $essentialText.Contains('"sandbox.json"')) "Essential excludes active sandbox.json"
Assert-True (-not $essentialText.Contains('"environment.json"')) "Essential excludes active environment.json"
Assert-True (-not $essentialText.Contains('"BUGBOT.md"')) "Essential excludes active BUGBOT.md"
Assert-True (-not $essentialText.Contains('"docs\memory-and-obsidian.md"')) "Essential excludes memory guide"
Assert-True (-not $essentialText.Contains('"docs\mcp-security.md"')) "Essential excludes mcp-security guide"
Assert-True (-not $essentialText.Contains('"scripts\validate-mcp-profiles.ps1"')) "Essential excludes MCP validator"
Assert-True (-not $essentialText.Contains('"templates\hooks"')) "Essential excludes templates/hooks in essentialFiles"
Assert-True (-not $essentialText.Contains('"tests\living-eval"')) "Essential excludes living-eval in essentialFiles"
Test-Contains (Join-Path $Root "docs\harness-evidence-and-enforcement.md") "## For agents" "harness-evidence For agents"
Test-Contains (Join-Path $Root "docs\README.md") "harness-evidence-and-enforcement.md" "docs index includes harness-evidence"
Assert-True (-not (Test-Path (Join-Path $pluginRoot "skills\review-harness-evidence"))) "plugin excludes review-harness-evidence"
Test-Contains $installPath "autonomous-task" "installer syncs autonomous-task"
Test-Contains $installPath "maintain-project-docs" "installer syncs maintain-project-docs"
Test-Contains $installPath "configure-project-integrations" "installer syncs configure-project-integrations"
Test-Contains $installPath "browser-verify" "installer syncs browser-verify"
Test-Contains $installPath "setup-project-environment" "installer syncs setup-project-environment"
Test-Contains $installPath "autonomous-orchestration.mdc" "installer syncs orchestration rule"
Test-Contains $installPath "project-docs-lifecycle.mdc" "installer syncs project-docs-lifecycle rule"
foreach ($agent in $manifest.agents) {
    Test-Contains $installPath ([string]$agent.file) "installer syncs $($agent.file)"
}

$mustAbsentTokens = @(
    ".cursor\skills\ship-toolkit",
    ".cursor\skills\add-source",
    ".cursor\skills\bootstrap-project",
    ".cursor\skills\distill-doc",
    ".cursor\mcp.json",
    "templates\mcp",
    "templates\cursor",
    ".cursor\permissions.json",
    ".cursor\sandbox.json",
    ".cursor\environment.json",
    ".cursor\BUGBOT.md",
    ".cursor\skills\configure-project-integrations",
    "docs\memory-and-obsidian.md",
    "docs\mcp-security.md",
    "scripts\validate-mcp-profiles.ps1",
    "templates\hooks",
    "scripts\validate-living-evals.ps1",
    "tests\living-eval"
)
foreach ($token in $mustAbsentTokens) {
    Assert-True (-not $essentialText.Contains('"' + $token + '"')) "Essential excludes $token"
    Assert-True ($mustAbsentText.Contains('"' + $token + '"')) "smoke mustAbsent lists $token"
}
Assert-True ($mustAbsentText.Contains('"docs\docs-map.json"')) "smoke mustAbsent lists docs-map.json"
Assert-True ($smokeText -match '(?s)foreach\s*\(\$rel\s+in\s+\$mustAbsent\).*?Test-Path') "smoke enforces mustAbsent paths"

$docPath = Join-Path $Root "docs\autonomous-agent-orchestration.md"
$docText = if (Test-Path $docPath) { Read-Text $docPath } else { "" }
Assert-True (Test-Path $docPath) "orchestration doc exists"
Test-Contains (Join-Path $Root "docs\living-documentation.md") "## For agents" "living-documentation For agents"
Test-Contains (Join-Path $Root "docs\memory-and-obsidian.md") "## For agents" "memory-and-obsidian For agents"
Test-Contains (Join-Path $Root "docs\mcp-security.md") "## For agents" "mcp-security For agents"
Test-Contains (Join-Path $Root "docs\README.md") "living-documentation.md" "docs index includes living-documentation"
Test-Contains (Join-Path $Root "docs\README.md") "memory-and-obsidian.md" "docs index includes memory-and-obsidian"
Test-Contains (Join-Path $Root "docs\README.md") "mcp-security.md" "docs index includes mcp-security"
Test-Contains (Join-Path $Root "SOURCES.md") "SRC-023" "SRC-023 registered"
Test-Contains (Join-Path $Root "SOURCES.md") "SRC-024" "SRC-024 registered"
Test-Contains (Join-Path $Root "SOURCES.md") "SRC-025" "SRC-025 registered"
Test-Contains (Join-Path $Root "SOURCES.md") "SRC-026" "SRC-026 registered"
Test-Contains (Join-Path $Root "SOURCES.md") "SRC-027" "SRC-027 registered"
Test-Contains (Join-Path $Root "SOURCES.md") "SRC-028" "SRC-028 registered"
Test-Contains (Join-Path $Root "docs\README.md") "autonomous-agent-orchestration.md" "docs index includes orchestration"
Test-Contains (Join-Path $Root "docs\README.md") "project-environment.md" "docs index includes project-environment"
Test-Contains (Join-Path $Root "docs\README.md") "cursor-native-controls.md" "docs index includes cursor-native-controls"
Test-Contains (Join-Path $Root "docs\README.md") "project-state.md" "docs index includes project-state"
Test-Contains (Join-Path $Root "SOURCES.md") "SRC-029" "SRC-029 registered"
Test-Contains (Join-Path $Root "SOURCES.md") "SRC-030" "SRC-030 registered"
Test-Contains (Join-Path $Root "templates\project-AGENTS.md") "project-state.md" "AGENTS points to project-state"
Test-Contains (Join-Path $Root "templates\project-AGENTS.md") "setup-project-environment" "AGENTS points to setup skill"
Test-Contains (Join-Path $Root "templates\first-chat.md") "project-state.md" "first-chat points to project-state"
Test-Contains (Join-Path $Root "templates\first-chat.md") "setup-project-environment" "first-chat points to setup skill"
Test-Contains (Join-Path $Root ".cursor\skills\setup-project-environment\SKILL.md") "Human Gate" "setup skill Human Gate"
Test-Contains (Join-Path $Root ".cursor\skills\setup-project-environment\SKILL.md") "silent install" "setup skill no silent install"
Test-Contains (Join-Path $Root "scripts\smoke-bootstrap.ps1") "test-session-start-context.ps1" "smoke runs V-SESSION"
Test-Contains (Join-Path $Root "templates\cursor\environment.json.example") '"env"' "environment example has env key"
Assert-True (-not (Read-Text (Join-Path $Root "templates\cursor\environment.json.example")).Contains('"$schema"')) "environment example no schema"
Test-Contains (Join-Path $Root "templates\project-rules\product-core.mdc") "autonomous-task" "product-core points to skill"

# Recovery R0a static presence (toolkit-only; not in orchestration manifest agents[]).
$recoverySkillPath = Join-Path $Root ".cursor\skills\recovery-escalation\SKILL.md"
$recoveryDocPath = Join-Path $Root "docs\recovery-escalation.md"
$recoveryValidatorPath = Join-Path $Root "scripts\validate-recovery.ps1"
$recoveryTestsPath = Join-Path $Root "tests\recovery\manifest.json"
Assert-True (Test-Path $recoverySkillPath) "recovery skill exists (R0a)"
Assert-True (Test-Path $recoveryDocPath) "recovery doc exists (R0a)"
Assert-True (Test-Path $recoveryValidatorPath) "validate-recovery.ps1 exists (R0a)"
Assert-True (Test-Path $recoveryTestsPath) "tests/recovery manifest exists (R0a)"
$recoveryAgents = @(
    "recovery-orchestrator.md", "reproducer.md",
    "recovery-arbiter-openai.md", "recovery-arbiter-claude.md", "recovery-arbiter-fable.md"
)
foreach ($raf in $recoveryAgents) {
    Assert-True (Test-Path (Join-Path $Root ".cursor\agents\$raf")) "recovery agent exists: $raf"
}
if (Test-Path $recoverySkillPath) {
    try {
        $recoveryFm = Get-Frontmatter $recoverySkillPath
        $recoveryLines = @(Get-Content $recoverySkillPath -Encoding UTF8).Count
        $recoveryDisabled = (
            $recoveryFm.ContainsKey("disable-model-invocation") -and
            $recoveryFm["disable-model-invocation"] -match "^true\b"
        )
        Assert-True ($recoveryFm["name"] -eq "recovery-escalation") "recovery skill name"
        Assert-True ($recoveryFm["description"] -match "\p{IsCyrillic}") "recovery skill Cyrillic description"
        Assert-True $recoveryDisabled "recovery skill disable-model-invocation true"
        Assert-True ($recoveryLines -le 500) "recovery skill line cap 500"
    } catch {
        Fail "recovery skill frontmatter: $($_.Exception.Message)"
    }
}
if (Test-Path $contractsPath) {
    foreach ($token in @(
        "## 9. FailureRecord", "## 10. EvidenceRecord", "## 11. HypothesisRecord",
        "## 12. RecoverySnapshot", "## 13. ChallengePacket", "## 14. RecoveryDecision"
    )) {
        Assert-True ($contracts.Contains($token)) "contracts recovery schema: $token"
    }
}
Test-Contains (Join-Path $Root "docs\README.md") "recovery-escalation.md" "docs index includes recovery"
Test-Contains (Join-Path $Root "SOURCES.md") "SRC-031" "SRC-031 registered"
Assert-True (-not (Test-Path (Join-Path $pluginRoot "skills\recovery-escalation"))) "plugin excludes recovery skill"
foreach ($raf in $recoveryAgents) {
    Assert-True (-not (Test-Path (Join-Path $pluginRoot "agents\$raf"))) "plugin excludes recovery agent $raf"
}
Assert-True (-not (Test-Path (Join-Path $pluginRoot "scripts\validate-recovery.ps1"))) "plugin excludes validate-recovery.ps1"
Assert-True (-not (Test-Path (Join-Path $pluginRoot "tests\recovery"))) "plugin excludes tests/recovery"
Assert-True (-not $essentialText.Contains('".cursor\skills\recovery-escalation"')) "Essential excludes recovery skill"
foreach ($raf in $recoveryAgents) {
    Assert-True (-not $essentialText.Contains('"' + $raf + '"')) "Essential excludes recovery agent $raf"
}
Assert-True (-not $essentialText.Contains('"scripts\validate-recovery.ps1"')) "Essential excludes validate-recovery.ps1"
Assert-True (-not $essentialText.Contains('"tests\recovery"')) "Essential excludes tests/recovery"
Assert-True (-not $essentialText.Contains('"docs\recovery-escalation.md"')) "Essential excludes recovery doc"
$recoveryMustAbsent = @(
    ".cursor\skills\recovery-escalation",
    ".cursor\agents\recovery-orchestrator.md",
    ".cursor\agents\reproducer.md",
    ".cursor\agents\recovery-arbiter-openai.md",
    ".cursor\agents\recovery-arbiter-claude.md",
    ".cursor\agents\recovery-arbiter-fable.md",
    "scripts\validate-recovery.ps1",
    "tests\recovery",
    "docs\recovery-escalation.md"
)
foreach ($token in $recoveryMustAbsent) {
    Assert-True ($mustAbsentText.Contains('"' + $token + '"')) "smoke mustAbsent lists recovery $token"
}

# Routing fixtures: execute hard overrides; soft tiers only verify documented tokens.
$overrides = Get-Content (Join-Path $testsRoot "hard-overrides.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$cases = Get-Content (Join-Path $testsRoot "fixtures\routing-cases.json") -Raw -Encoding UTF8 | ConvertFrom-Json
$rubric = if (Test-Path $rubricPath) { Read-Text $rubricPath } else { "" }

function Resolve-HardOverride([string]$Prompt, $Rules) {
    $best = $null
    $bestRank = -1
    foreach ($rule in $Rules) {
        $effectivePrompt = $Prompt
        foreach ($exclude in @($rule.exclude_patterns)) {
            $effectivePrompt = [regex]::Replace(
                $effectivePrompt,
                [string]$exclude,
                "",
                [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
            )
        }
        foreach ($pattern in $rule.patterns) {
            if ($effectivePrompt -match $pattern) {
                $rank = [int](([string]$rule.tier).Substring(1))
                if ($rank -gt $bestRank) {
                    $best = $rule
                    $bestRank = $rank
                }
                break
            }
        }
    }
    return $best
}

function Get-PolicySourceText([string]$SourceKey) {
    switch ($SourceKey) {
        "tier-rubric" { return $rubric }
        "skill" {
            if (Test-Path $skillPath) { return (Read-Text $skillPath) }
            return ""
        }
        "contracts" {
            if (Test-Path $contractsPath) { return (Read-Text $contractsPath) }
            return ""
        }
        "rule" {
            if (Test-Path $rulePath) { return (Read-Text $rulePath) }
            return ""
        }
        "doc" { return $docText }
        default { return "" }
    }
}

function Test-StageExpectations($Case) {
    $combined = ""
    foreach ($src in @($Case.doc_sources)) {
        $combined += (Get-PolicySourceText ([string]$src))
        $combined += "`n"
    }
    if ([string]$Case.expect_tier) {
        Assert-True ($combined -match [regex]::Escape([string]$Case.expect_tier)) "routing $($Case.id) tier token $($Case.expect_tier)"
    }
    $matchedAny = $false
    foreach ($pattern in @($Case.require_any)) {
        if ($combined -match [string]$pattern) {
            $matchedAny = $true
            break
        }
    }
    Assert-True $matchedAny "routing $($Case.id) require_any policy match"
    foreach ($pattern in @($Case.forbid_any)) {
        Assert-True (-not ($combined -match [string]$pattern)) "routing $($Case.id) forbid_any '$pattern'"
    }
    if ($Case.PSObject.Properties.Name -contains "expect_stages") {
        foreach ($stage in @($Case.expect_stages)) {
            Assert-True ($combined -match [regex]::Escape([string]$stage)) "routing $($Case.id) stage $stage"
        }
    }
}

foreach ($case in $cases.cases) {
    if ($case.mode -eq "hard-override") {
        $match = Resolve-HardOverride ([string]$case.prompt) $overrides.rules
        Assert-True ($null -ne $match) "routing $($case.id) matched override"
        if ($null -ne $match) {
            Assert-True ($match.tier -eq $case.expect_tier) "routing $($case.id) tier"
            Assert-True ($match.gate -eq $case.expect_gate) "routing $($case.id) gate"
        }
    } elseif ($case.mode -eq "negative-hard-override") {
        $match = Resolve-HardOverride ([string]$case.prompt) $overrides.rules
        Assert-True ($null -eq $match) "routing $($case.id) avoids hard override"
    } elseif ($case.mode -eq "stage-expectations") {
        Test-StageExpectations $case
    } else {
        if (Test-Path $rubricPath) {
            foreach ($token in $case.doc_must_mention) {
                Assert-True ($rubric.Contains([string]$token)) "routing $($case.id) documented token $token"
            }
        }
    }
}

if ($SelfTest) {
    Write-Host ""
    Write-Host "=== Validator negative self-test ==="
    $temp = Join-Path $env:TEMP ("cptk-orch-validator-" + [guid]::NewGuid().ToString("n"))
    try {
        New-Item -ItemType Directory -Force -Path $temp | Out-Null
        $badAgent = Join-Path $temp "implementer.md"
        Set-Content -LiteralPath $badAgent -Encoding UTF8 -Value @(
            "---", "name: implementer", "description: Always use to implement bad", "model: wrong-model",
            "readonly: true", "is_background: false", "---", "bad"
        )
        $badFm = Get-Frontmatter $badAgent
        $expectedAgent = [pscustomobject]@{
            name = "implementer"
            model = "composer-2.5-fast"
            readonly = "false"
        }
        Assert-True (-not (Test-AgentContract $badFm $expectedAgent)) "self-test rejects bad agent contract"
        Assert-True (-not (Test-AgentDescription $badFm)) "self-test rejects Always-use implementer description"

        $badSkill = Join-Path $temp "SKILL.md"
        Set-Content -LiteralPath $badSkill -Encoding UTF8 -Value @(
            "---", "name: autonomous-task", "description: test", "disable-model-invocation: true # comment", "---"
        )
        $badSkillText = Read-Text $badSkill
        $badSkillFm = Get-Frontmatter $badSkill
        Assert-True (-not (Test-SkillAutoInvocable $badSkillFm $badSkillText)) "self-test rejects disabled skill"

        $badRule = Join-Path $temp "rule.mdc"
        Set-Content -LiteralPath $badRule -Encoding UTF8 -Value @(
            "---", "description: test", "alwaysApply: false", "---"
        )
        $badRuleFm = Get-Frontmatter $badRule
        Assert-True (-not (Test-AlwaysRule $badRuleFm)) "self-test rejects non-always rule"

        $duplicate = Join-Path $temp "duplicate.md"
        Set-Content -LiteralPath $duplicate -Encoding UTF8 -Value @(
            "---", "name: first", "name: second", "---"
        )
        $duplicateRejected = $false
        try { $null = Get-Frontmatter $duplicate } catch { $duplicateRejected = $true }
        Assert-True $duplicateRejected "self-test rejects duplicate frontmatter keys"
    } finally {
        if (Test-Path $temp) { Remove-Item -Recurse -Force $temp }
    }
}

Write-Host ""
if ($Fail -eq 0) {
    Write-Host "ORCH_VALIDATE_PASS"
    exit 0
}

Write-Host "ORCH_VALIDATE_FAIL: $Fail finding(s)"
exit 1

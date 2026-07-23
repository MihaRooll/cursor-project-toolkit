<#
.SYNOPSIS
  Smoke-test Essential bootstrap + papercuts shim + new-project (B1-B3 + C1 junction).
  -OracleOnly: oracle body only (leaf for verify-harness Full). Standalone default remains self-contained.
#>
param(
    [string]$TargetPath = "",

    [switch]$OracleOnly,

    [switch]$KeepOnFailure,

    [ValidateSet("", "KeepFailure", "CleanupProbe")]
    [string]$OwnershipTestMode = ""
)

$ErrorActionPreference = "Stop"
$ToolkitRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$fail = 0
$NewProjectPs1 = Join-Path $ToolkitRoot "scripts\new-project.ps1"
$EmDash = [char]0x2014
$TargetCreated = $false
$InvocationId = [guid]::NewGuid().ToString("n")
$MarkerPath = $null
$UnderVerifyHarness = ($env:CPTK_VERIFY_HARNESS -eq "1")
$realUserProfile = [Environment]::GetEnvironmentVariable("USERPROFILE", "Process")
if ([string]::IsNullOrWhiteSpace($realUserProfile)) { $realUserProfile = $env:USERPROFILE }
$realCursorRoot = Join-Path $realUserProfile ".cursor"

function Assert-True($cond, $msg) {
    if ($cond) {
        Write-Host "OK  $msg"
    } else {
        Write-Host "FAIL $msg"
        $script:fail++
    }
}

function Write-StageOk {
    param([Parameter(Mandatory = $true)][string]$StageId)
    Write-Host "STAGE_OK $StageId"
}

function Test-IsReparsePoint {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $item = Get-Item -LiteralPath $Path -Force
    return (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Test-SmokePathHasReparseAncestor {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $true }
    try {
        $full = [System.IO.Path]::GetFullPath($Path)
    } catch {
        return $true
    }
    $current = $full
    while ($true) {
        if (Test-Path -LiteralPath $current) {
            if (Test-IsReparsePoint -Path $current) { return $true }
        }
        $parent = [System.IO.Path]::GetDirectoryName($current)
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $current) { break }
        $current = $parent
    }
    return $false
}

function Get-SmokeTargetLiteralPath {
    param([Parameter(Mandatory = $true)][string]$Relative)
    return (Join-Path $TargetPath $Relative)
}

function Resolve-SmokeTargetAbsolutePath {
    param([Parameter(Mandatory = $true)][string]$Path)
    try {
        return [System.IO.Path]::GetFullPath($Path)
    } catch {
        throw "Invalid smoke target path: $Path"
    }
}

function New-SmokeTargetDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)
    $absolute = Resolve-SmokeTargetAbsolutePath -Path $Path
    [void][System.IO.Directory]::CreateDirectory($absolute)
    return $absolute
}

function Test-IsVolatileCursorRuntimePath {
    param([string]$RelPath)
    $norm = $RelPath.Replace('/', '\').TrimStart('\')
    $volatilePrefixes = @(
        "projects\",
        "ai-tracking\",
        "terminals\",
        "logs\",
        "CachedData\",
        "Cache\",
        "CachedExtensions\",
        "blob_storage\",
        "sentry\",
        "process-monitor\"
    )
    foreach ($prefix in $volatilePrefixes) {
        if ($norm.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Get-CursorRootFileSnapshot {
    param([string]$CursorRoot)
    $snap = @{}
    if (-not (Test-Path -LiteralPath $CursorRoot)) { return $snap }
    foreach ($f in (Get-ChildItem -LiteralPath $CursorRoot -Recurse -File -ErrorAction SilentlyContinue)) {
        $rel = $f.FullName.Substring($CursorRoot.Length).TrimStart('\', '/')
        try {
            $snap[$rel] = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
        } catch {
            $snap[$rel] = "__UNREADABLE__"
        }
    }
    return $snap
}

function Get-CursorPluginsHooksSnapshot {
    param([string]$CursorRoot)
    $full = Get-CursorRootFileSnapshot -CursorRoot $CursorRoot
    $snap = @{}
    foreach ($k in $full.Keys) {
        if (Test-IsVolatileCursorRuntimePath $k) { continue }
        if ($k.StartsWith("plugins\", [StringComparison]::OrdinalIgnoreCase) -or
            $k.StartsWith("hooks\", [StringComparison]::OrdinalIgnoreCase)) {
            $snap[$k] = $full[$k]
        }
    }
    return $snap
}

function Get-HomeSha256Prefix([string]$Text) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        $hash = ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join ""
        return $hash.Substring(0, 16)
    } finally {
        $sha.Dispose()
    }
}

function Get-CanonicalUserHomeState($Value) {
    # Canonical User-scope HOME: only null or zero-length means unset on Windows runners.
    if ($null -eq $Value) { return "unset" }
    $t = [string]$Value
    if ($t.Length -eq 0) { return "unset" }
    return "set len:$($t.Length) sha256:$(Get-HomeSha256Prefix $t)"
}

function Test-UserHomeUnchangedCanonical($Before, $After) {
    $beforeUnset = ($null -eq $Before) -or (([string]$Before).Length -eq 0)
    $afterUnset = ($null -eq $After) -or (([string]$After).Length -eq 0)
    if ($beforeUnset -and $afterUnset) { return $true }
    if ($beforeUnset -or $afterUnset) { return $false }
    return ([string]$Before -ceq [string]$After)
}

function Get-SafeHomeFingerprint([string]$Value) {
    if ($null -eq $Value) { return "null" }
    $t = [string]$Value
    if ($t.Length -eq 0) { return "empty" }
    return "set len:$($t.Length) sha256:$(Get-HomeSha256Prefix $t)"
}

function Assert-BoundedHomeUnchanged {
    param(
        [string]$UserHomeBefore,
        [hashtable]$CursorBefore
    )
    $userHomeAfter = [Environment]::GetEnvironmentVariable("HOME", "User")
    if (-not (Test-UserHomeUnchangedCanonical $UserHomeBefore $userHomeAfter)) {
        $beforeFp = Get-SafeHomeFingerprint $UserHomeBefore
        $afterFp = Get-SafeHomeFingerprint $userHomeAfter
        Assert-True $false "User-scope HOME unchanged (before=$beforeFp after=$afterFp)"
    } else {
        Assert-True $true "User-scope HOME unchanged"
    }
    $cursorAfter = Get-CursorPluginsHooksSnapshot -CursorRoot $realCursorRoot
    $added = @()
    $changed = @()
    $deleted = @()
    foreach ($k in $cursorAfter.Keys) {
        if (Test-IsVolatileCursorRuntimePath $k) { continue }
        if (-not $CursorBefore.ContainsKey($k)) { $added += $k }
        elseif ($CursorBefore[$k] -ne $cursorAfter[$k]) { $changed += $k }
    }
    foreach ($k in $CursorBefore.Keys) {
        if (Test-IsVolatileCursorRuntimePath $k) { continue }
        if (-not $cursorAfter.ContainsKey($k)) { $deleted += $k }
    }
    $detail = @()
    if ($added.Count -gt 0) { $detail += ("added: " + ($added -join "; ")) }
    if ($changed.Count -gt 0) { $detail += ("changed: " + ($changed -join "; ")) }
    if ($deleted.Count -gt 0) { $detail += ("deleted: " + ($deleted -join "; ")) }
    $detailText = if ($detail.Count -gt 0) { ($detail -join " | ") } else { "" }
    Assert-True ($added.Count -eq 0 -and $changed.Count -eq 0 -and $deleted.Count -eq 0) `
        "real USERPROFILE\.cursor plugins/hooks unchanged ($detailText)"
}

function Invoke-Ps1File {
    param(
        [Parameter(Mandatory = $true)][string]$File,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$ArgList
    )
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
        if ($UnderVerifyHarness) {
            if ([string]$line -cmatch '^SKIP\b' -or [string]$line -match 'PORTABILITY_SMOKE_SKIP') {
                Write-Host "FAIL forbidden skip token under verify-harness"
                $script:fail++
            }
        }
    }
    if ($null -eq $code) { $code = 0 }
    return [int]$code
}

function Remove-OwnedSmokeTarget {
    if (-not $TargetCreated) { return }
    if ([string]::IsNullOrWhiteSpace($MarkerPath) -or -not (Test-Path -LiteralPath $MarkerPath)) { return }
    $marker = (Get-Content -LiteralPath $MarkerPath -Raw -ErrorAction SilentlyContinue)
    if ($null -eq $marker -or $marker.Trim() -ne $InvocationId) { return }
    if (Test-IsReparsePoint -Path $TargetPath) { return }
    if (Test-Path -LiteralPath $TargetPath) {
        Remove-Item -LiteralPath $TargetPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$targetExplicit = $PSBoundParameters.ContainsKey("TargetPath") -and -not [string]::IsNullOrWhiteSpace($TargetPath)
if (-not $targetExplicit) {
    $TargetPath = Join-Path $env:TEMP $InvocationId
}

Write-Host "=== Smoke bootstrap ==="
Write-Host "Toolkit: $ToolkitRoot"
Write-Host "Target:  $TargetPath"
if ($OracleOnly) { Write-Host "Mode:    OracleOnly" }

try {
    $TargetPath = Resolve-SmokeTargetAbsolutePath -Path $TargetPath
} catch {
    Write-Host "FAIL smoke target path invalid: $($_.Exception.Message)"
    exit 1
}

if (Test-Path -LiteralPath $TargetPath) {
    Write-Host "FAIL smoke target already exists (hard reject): $TargetPath"
    exit 1
}
if (Test-SmokePathHasReparseAncestor -Path $TargetPath) {
    Write-Host "FAIL smoke target path traverses reparse/junction ancestor (hard reject): $TargetPath"
    exit 1
}

try {
    $TargetPath = New-SmokeTargetDirectory -Path $TargetPath
} catch {
    Write-Host "FAIL smoke target create: $($_.Exception.Message)"
    exit 1
}
$MarkerPath = Get-SmokeTargetLiteralPath ".cptk-smoke-owned"
Set-Content -LiteralPath $MarkerPath -Value $InvocationId -Encoding Ascii -NoNewline
$TargetCreated = $true

if ($OwnershipTestMode -eq "CleanupProbe") {
    try {
        Remove-OwnedSmokeTarget
        if (Test-Path -LiteralPath $TargetPath) {
            Write-Host "FAIL owned target not removed on CleanupProbe"
            exit 1
        }
        $TargetCreated = $false
        Write-Host "OWNERSHIP_CLEANUP_PROBE_PASS"
        exit 0
    } catch {
        Write-Host "FAIL CleanupProbe: $($_.Exception.Message)"
        exit 1
    }
}

if ($OwnershipTestMode -eq "KeepFailure") {
    try {
        $fail = 1
        Write-Host "OWNERSHIP_KEEP_FAILURE_PROBE"
    } finally {
        if ($TargetCreated -and (Test-Path -LiteralPath $TargetPath)) {
            if ($fail -eq 0 -or -not $KeepOnFailure) {
                Remove-OwnedSmokeTarget
            } else {
                Write-Host "KEEP on failure (-KeepOnFailure): $TargetPath"
            }
        }
    }
    if (-not (Test-Path -LiteralPath $TargetPath)) {
        Write-Host "FAIL KeepFailure probe did not retain owned target"
        exit 1
    }
    Remove-Item -LiteralPath $TargetPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "OWNERSHIP_KEEP_FAILURE_PROBE_PASS"
    exit 0
}

$savedPortSmoke = [Environment]::GetEnvironmentVariable("CPTK_PORTABILITY_SMOKE", "Process")
[Environment]::SetEnvironmentVariable("CPTK_PORTABILITY_SMOKE", "1", "Process")
$userHomeBefore = [Environment]::GetEnvironmentVariable("HOME", "User")
$cursorSnapBefore = Get-CursorPluginsHooksSnapshot -CursorRoot $realCursorRoot

try {

if (-not $OracleOnly) {
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
}

$code = Invoke-Ps1File (Join-Path $ToolkitRoot "scripts\bootstrap-into-project.ps1") `
    -TargetPath $TargetPath -Mode Essential -SkipUserHome -SkipNext
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
    "tests\living-eval",
    ".cursor\skills\recovery-escalation",
    ".cursor\agents\recovery-orchestrator.md",
    ".cursor\agents\reproducer.md",
    ".cursor\agents\recovery-arbiter-openai.md",
    ".cursor\agents\recovery-arbiter-claude.md",
    ".cursor\agents\recovery-arbiter-fable.md",
    "scripts\validate-recovery.ps1",
    "tests\recovery",
    "docs\recovery-escalation.md",
    "scripts\verify-harness.ps1"
)

Write-Host ""
Write-Host "=== Presence checks ==="
foreach ($rel in $mustExist) {
    Assert-True (Test-Path -LiteralPath (Get-SmokeTargetLiteralPath $rel)) "has $rel"
}

Write-Host ""
Write-Host "=== Absence checks (Essential product surface) ==="
foreach ($rel in $mustAbsent) {
    Assert-True (-not (Test-Path -LiteralPath (Get-SmokeTargetLiteralPath $rel))) "no $rel"
}

$secretPatterns = @(
    '(?i)Bearer\s+[^{\s]',
    '\b(sk-|ghp_|gho_|xox[baprs]-|AIza)',
    'BEGIN (RSA |OPENSSH )?PRIVATE KEY'
)
$scanRoots = @(
    (Get-SmokeTargetLiteralPath ".cursor"),
    (Get-SmokeTargetLiteralPath "docs"),
    (Get-SmokeTargetLiteralPath "scripts")
)
foreach ($scanRoot in $scanRoots) {
    if (-not (Test-Path -LiteralPath $scanRoot)) { continue }
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

$gaPath = Get-SmokeTargetLiteralPath ".gitattributes"
if (Test-Path -LiteralPath $gaPath) {
    $ga = Get-Content -LiteralPath $gaPath -Raw
    Assert-True ($ga -match "(?m)^\.papercuts\.jsonl\s+merge=union\s*$") ".gitattributes has papercuts merge=union"
} else {
    Assert-True $false ".gitattributes exists for merge check"
}

$agentsPath = Get-SmokeTargetLiteralPath "AGENTS.md"
if (Test-Path -LiteralPath $agentsPath) {
    $agents = Get-Content -LiteralPath $agentsPath -Raw
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

Assert-True (Test-Path -LiteralPath (Get-SmokeTargetLiteralPath ".papercuts.jsonl")) "target has its own .papercuts.jsonl"

$productValidator = Get-SmokeTargetLiteralPath "scripts\validate-project-docs.ps1"
if (Test-Path -LiteralPath $productValidator) {
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
        Remove-Item -LiteralPath $miniRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
} else {
    Assert-True $false "product ships validate-project-docs.ps1"
}

if ($OracleOnly -and $fail -eq 0) { Write-StageOk "F-ESSENTIAL" }

Write-Host ""
Write-Host "=== Smoke Full merge (Essential then Full, no -Force) ==="
$fullTarget = Join-Path $env:TEMP ("cptk-smoke-full-" + [guid]::NewGuid().ToString("n"))
$fullCreated = $false
try {
    $fullCode = Invoke-Ps1File (Join-Path $ToolkitRoot "scripts\bootstrap-into-project.ps1") `
        -TargetPath $fullTarget -Mode Essential -SkipUserHome -SkipNext
    Assert-True ($fullCode -eq 0) "Full-prep Essential bootstrap exit 0"
    $fullCode2 = Invoke-Ps1File (Join-Path $ToolkitRoot "scripts\bootstrap-into-project.ps1") `
        -TargetPath $fullTarget -Mode Full -SkipUserHome -SkipNext
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
        "tests\living-eval\manifest.json",
        "scripts\validate-recovery.ps1",
        "tests\recovery\manifest.json",
        "docs\recovery-escalation.md",
        ".cursor\skills\recovery-escalation\SKILL.md"
    )
    foreach ($rel in $fullMustExist) {
        Assert-True (Test-Path -LiteralPath (Join-Path $fullTarget $rel)) "Full has $rel"
    }
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $fullTarget "scripts\verify-harness.ps1"))) "Full copy has no verify-harness.ps1"
    $sentinelPath = Join-Path $fullTarget "docs\living-documentation.md"
    if (Test-Path -LiteralPath $sentinelPath) {
        $sentinel = "FULL_MERGE_SENTINEL_" + [guid]::NewGuid().ToString("n")
        Set-Content -LiteralPath $sentinelPath -Value $sentinel -Encoding utf8
        $fullCode3 = Invoke-Ps1File (Join-Path $ToolkitRoot "scripts\bootstrap-into-project.ps1") `
            -TargetPath $fullTarget -Mode Full -SkipUserHome -SkipNext
        Assert-True ($fullCode3 -eq 0) "Full re-merge preserves existing exit 0"
        $after = Get-Content -LiteralPath $sentinelPath -Raw -Encoding utf8
        Assert-True ($after -match [regex]::Escape($sentinel)) "Full merge preserves existing file without -Force"
    }
} finally {
    if ($fullCreated -and (Test-Path -LiteralPath $fullTarget)) {
        Remove-Item -LiteralPath $fullTarget -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($OracleOnly -and $fail -eq 0) { Write-StageOk "F-FULL-MERGE" }

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
$npFailBeforeSection = $fail
$npFailBeforeC1 = $fail

try {
    New-Item -ItemType Directory -Force -Path $npParent | Out-Null

    $code = Invoke-Ps1File $NewProjectPs1 -Name $npName -Parent $npParent -Goal $npGoal -SkipUserHome
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
        $code = Invoke-Ps1File $NewProjectPs1 -Name $npName -Parent $npParent -Goal "should-not-clobber" -AllowExisting -SkipUserHome
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

    $refuseName = "toolkit-np-refuse"
    $refuseRoot = Join-Path $npParent $refuseName
    New-Item -ItemType Directory -Force -Path $refuseRoot | Out-Null
    $keepPath = Join-Path $refuseRoot "KEEP.txt"
    Set-Content -LiteralPath $keepPath -Value "KEEP" -Encoding ascii
    $code = Invoke-Ps1File $NewProjectPs1 -Name $refuseName -Parent $npParent -Goal "refuse" -SkipUserHome
    Assert-True ($code -ne 0) "refuse non-empty exit != 0"
    Assert-True ((Get-Content $keepPath -Raw -Encoding ascii).Trim() -eq "KEEP") "refuse left KEEP unchanged"
    Assert-True (-not (Test-Path (Join-Path $refuseRoot "AGENTS.md"))) "refuse did not bootstrap AGENTS"

    if ($OracleOnly -and $fail -eq $npFailBeforeSection) { Write-StageOk "F-NEWPROJECT" }
    $npFailBeforeC1 = $fail

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
        $code = Invoke-Ps1File $NewProjectPs1 -Name $leakName -Parent $jLink -Goal "junction" -SkipUserHome
        Assert-True ($code -ne 0) "junction Parent->toolkit exit != 0"
        Assert-True (-not (Test-Path (Join-Path $ToolkitRoot $leakName))) "no leak under ToolkitRoot"
    }
    if ($OracleOnly -and $fail -eq $npFailBeforeC1) { Write-StageOk "F-C1" }
} finally {
    if (Test-Path -LiteralPath $npParent) {
        Remove-Item -LiteralPath $npParent -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($jCreated -and (Test-Path -LiteralPath $jLink)) {
        cmd /c "rmdir `"$jLink`""
    }
    if (Test-Path -LiteralPath $jParent) {
        Remove-Item -LiteralPath $jParent -Recurse -Force -ErrorAction SilentlyContinue
    }
    [Environment]::SetEnvironmentVariable("TOOLKIT_PROJECTS_ROOT", $savedProjectsRoot, "Process")
}

if ($fail -eq 0) {
    $portPath = Join-Path $PSScriptRoot "smoke-portability.ps1"
    if (Test-Path $portPath) {
        Write-Host ""
        Write-Host "=== Smoke portability ==="
        $savedSkipPort = [Environment]::GetEnvironmentVariable("CPTK_SKIP_PORTABILITY", "Process")
        $savedNestedReentry = [Environment]::GetEnvironmentVariable("CPTK_PORTABILITY_NESTED_REENTRY", "Process")
        [Environment]::SetEnvironmentVariable("CPTK_SKIP_PORTABILITY", $null, "Process")
        [Environment]::SetEnvironmentVariable("CPTK_PORTABILITY_NESTED_REENTRY", $null, "Process")
        $portArgs = @()
        if ($OracleOnly) { $portArgs += "-OracleMode" }
        $prevEapPort = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $portOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $portPath @portArgs 2>&1 | Out-String
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
        if ($UnderVerifyHarness -or $OracleOnly) {
            if ($portOutput -cmatch '(?m)^SKIP\b' -or $portOutput -match 'PORTABILITY_SMOKE_SKIP') {
                Write-Host "FAIL forbidden skip in portability under oracle"
                $fail++
            }
        }
        Assert-True ($portOutput -notmatch "PORTABILITY_SMOKE_SKIP") "smoke-portability did not skip"
        Assert-True ($portOutput -match "PORTABILITY_SMOKE_PASS") "smoke-portability prints PORTABILITY_SMOKE_PASS"
        Assert-True ($portCode -eq 0) "smoke-portability exit 0"
    }
}

Assert-BoundedHomeUnchanged -UserHomeBefore $userHomeBefore -CursorBefore $cursorSnapBefore

Write-Host ""
if ($fail -eq 0) {
    if ($OracleOnly) {
        Write-Host "SMOKE ORACLE PASS (deterministic bootstrap + portability stages)"
    } else {
        Write-Host "SMOKE PASS (Essential + new-project B1-B3 + C1 + Full merge)"
    }
    exit 0
} else {
    Write-Host "SMOKE FAIL: $fail assertion(s)"
    exit 1
}
} finally {
    if ($null -eq $savedPortSmoke) {
        [Environment]::SetEnvironmentVariable("CPTK_PORTABILITY_SMOKE", $null, "Process")
    } else {
        [Environment]::SetEnvironmentVariable("CPTK_PORTABILITY_SMOKE", $savedPortSmoke, "Process")
    }
    if ($TargetCreated -and (Test-Path -LiteralPath $TargetPath)) {
        if ($fail -eq 0 -or -not $KeepOnFailure) {
            Remove-OwnedSmokeTarget
        } else {
            Write-Host "KEEP on failure (-KeepOnFailure): $TargetPath"
        }
    }
}

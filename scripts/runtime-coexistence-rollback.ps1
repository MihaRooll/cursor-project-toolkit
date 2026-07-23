<#
.SYNOPSIS
  Rollback runtime coexistence invocation: restore live plugin from backup or remove invocation-owned install.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RunRoot,
    [Parameter(Mandatory = $true)]
    [string]$InvocationMarker
)

$ErrorActionPreference = "Stop"
$LiveSurfaceId = "plugins/local/cursor-project-harness"
$TestOnlyProfileRelative = "simulated_profile"

function Get-CoexistenceSha256HexFromString([string]$Text) {
    if ($null -eq $Text) { $Text = "" }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        return ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join ""
    } finally {
        $sha.Dispose()
    }
}

function Assert-NoReparsePoint {
    param([string]$Path, [string]$Label)
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw "reparse point rejected at $Label"
    }
}

function Assert-TreeNoReparse {
    param([string]$Root, [string]$Label)
    if ([string]::IsNullOrWhiteSpace($Root)) { return }
    if (-not (Test-Path -LiteralPath $Root)) { return }
    Assert-NoReparsePoint -Path $Root -Label $Label
    foreach ($f in (Get-ChildItem -LiteralPath $Root -Recurse -Force -ErrorAction Stop)) {
        if ($f.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "reparse point rejected under $Label"
        }
    }
}

function Get-TreeDigest {
    param([string]$Root)
    if (-not (Test-Path -LiteralPath $Root)) { return "empty" }
    Assert-TreeNoReparse -Root $Root -Label "digest-root"
    $pairs = New-Object System.Collections.Generic.List[string]
    foreach ($f in (Get-ChildItem -LiteralPath $Root -Recurse -File -Force -ErrorAction Stop)) {
        Assert-NoReparsePoint -Path $f.FullName -Label "digest-file"
        $rel = $f.FullName.Substring($Root.Length).TrimStart('\', '/').Replace('\', '/')
        $hash = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        [void]$pairs.Add("$rel=$hash")
    }
    $pairs.Sort([StringComparer]::Ordinal)
    if ($pairs.Count -eq 0) { return "empty" }
    return (Get-CoexistenceSha256HexFromString ($pairs -join "|"))
}

function Copy-TreeExact {
    param([string]$SourceRoot, [string]$DestRoot)
    if (-not (Test-Path -LiteralPath $SourceRoot)) { return }
    Assert-TreeNoReparse -Root $SourceRoot -Label "copy-source"
    New-Item -ItemType Directory -Force -Path $DestRoot | Out-Null
    foreach ($f in (Get-ChildItem -LiteralPath $SourceRoot -Recurse -File -Force -ErrorAction Stop)) {
        Assert-NoReparsePoint -Path $f.FullName -Label "copy-file"
        $rel = $f.FullName.Substring($SourceRoot.Length).TrimStart('\', '/')
        $destFile = Join-Path $DestRoot $rel
        $destDir = Split-Path -Parent $destFile
        if (-not (Test-Path -LiteralPath $destDir)) {
            New-Item -ItemType Directory -Force -Path $destDir | Out-Null
        }
        [System.IO.File]::WriteAllBytes($destFile, [System.IO.File]::ReadAllBytes($f.FullName))
    }
}

function Clear-OwnedSubtree {
    param([string]$ParentRoot, [string]$ChildName)
    $target = Join-Path $ParentRoot $ChildName
    if (-not (Test-Path -LiteralPath $target)) { return }
    Assert-TreeNoReparse -Root $target -Label $ChildName
    Remove-Item -LiteralPath $target -Recurse -Force
    New-Item -ItemType Directory -Force -Path $target | Out-Null
}

function Resolve-LiveProfileRootFromState {
    param($State, [string]$RunRoot)
    if ([bool]$State.real_profile) { return Join-Path $env:USERPROFILE ".cursor" }
    if ([bool]$State.test_only_profile) {
        return Join-Path $RunRoot $TestOnlyProfileRelative
    }
    return $null
}

function Update-RollbackState {
    param([string]$StatePath, $State, [bool]$EvidenceComplete)
    $json = @{
        phase = "rolled_back"
        invocation_marker = [string]$State.invocation_marker
        scenario = [string]$State.scenario
        run_root_id = [string]$State.run_root_id
        real_profile = [bool]$State.real_profile
        test_only_profile = [bool]$State.test_only_profile
        had_prior_plugin = [bool]$State.had_prior_plugin
        backup_complete = [bool]$State.backup_complete
        expected_live_digest = [string]$State.expected_live_digest
        backup_digest = [string]$State.backup_digest
        live_surface_id = [string]$State.live_surface_id
        prepare_seal = [string]$State.prepare_seal
        source_digest = [string]$State.source_digest
        installed_digest = [string]$State.pre_rollback_digest
        pre_rollback_digest = [string]$State.pre_rollback_digest
        used_nonces = @($State.used_nonces)
        invocation_counts = @{
            essential = @{
                sessionStart = [int]$State.invocation_counts.essential.sessionStart
                afterShellExecution = [int]$State.invocation_counts.essential.afterShellExecution
                stop = [int]$State.invocation_counts.essential.stop
            }
            plugin = @{
                sessionStart = [int]$State.invocation_counts.plugin.sessionStart
                afterShellExecution = [int]$State.invocation_counts.plugin.afterShellExecution
                stop = [int]$State.invocation_counts.plugin.stop
            }
        }
        owner_verdict = $State.owner_verdict
        runtime_verified = [bool]$State.runtime_verified
        evidence_complete = $EvidenceComplete
        ide_attested = [bool]$State.ide_attested
    }
    ($json | ConvertTo-Json -Depth 10 -Compress) | Set-Content -LiteralPath $StatePath -Encoding UTF8 -NoNewline
}

function Write-RollbackEvent {
    param([string]$JournalPath, [hashtable]$Event)
    $line = (@{
        schema_version = 3
        scenario = $Event.scenario
        source = $Event.source
        event = "rollback"
        nonce = $Event.nonce
        hash = $Event.hash
        elapsed_ms = 0
        invocation_count = 0
        context_bytes = 0
    } | ConvertTo-Json -Compress)
    Add-Content -LiteralPath $JournalPath -Value $line -Encoding UTF8
}

function Get-DigestPrefix([string]$Digest) {
    if ([string]::IsNullOrWhiteSpace($Digest) -or $Digest -eq "empty") { return "empty" }
    return $Digest.Substring(0, [Math]::Min(16, $Digest.Length))
}

$statePath = Join-Path $RunRoot "state.json"
$journalPath = Join-Path $RunRoot "journal.jsonl"
$backupRoot = Join-Path $RunRoot "backup"
$surfaceRel = $LiveSurfaceId.Replace('/', '\')

if (-not (Test-Path -LiteralPath $statePath)) { throw "missing state.json" }
Assert-TreeNoReparse -Root $RunRoot -Label "run-root"

$state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
if ([string]$state.invocation_marker -ne $InvocationMarker) {
    throw "invocation marker mismatch"
}

if (-not [bool]$state.backup_complete) {
    throw "rollback refused: backup incomplete"
}

$expectedInstalledDigest = [string]$state.pre_rollback_digest
$backupDigest = [string]$state.backup_digest
$expectedLiveDigest = if ($null -ne $state.PSObject.Properties["expected_live_digest"]) {
    [string]$state.expected_live_digest
} else { $backupDigest }
$hadPrior = [bool]$state.had_prior_plugin

$liveProfileRoot = Resolve-LiveProfileRootFromState -State $state -RunRoot $RunRoot
if ($null -ne $liveProfileRoot) {
    Assert-TreeNoReparse -Root $liveProfileRoot -Label "live-profile"
    $pluginLive = Join-Path $liveProfileRoot $surfaceRel
    $backupPlugin = Join-Path $backupRoot $surfaceRel

    if ($hadPrior) {
        if (-not (Test-Path -LiteralPath $backupPlugin)) {
            throw "rollback refused: backup missing"
        }
        $storedBackupDigest = Get-TreeDigest $backupPlugin
        if ($storedBackupDigest -ne $backupDigest -or $storedBackupDigest -ne $expectedLiveDigest) {
            throw "rollback refused: backup digest mismatch"
        }
    }

    Clear-OwnedSubtree -ParentRoot $RunRoot -ChildName "installed"
    Clear-OwnedSubtree -ParentRoot $RunRoot -ChildName "profile"
    Clear-OwnedSubtree -ParentRoot $RunRoot -ChildName "workspace"

    $postInstalledDigest = Get-TreeDigest (Join-Path $RunRoot "installed")
    if ($postInstalledDigest -ne $expectedInstalledDigest) {
        throw "installed staging digest mismatch after rollback"
    }

    $evidenceComplete = $false
    if ($hadPrior) {
        if (Test-Path -LiteralPath $pluginLive) {
            Remove-Item -LiteralPath $pluginLive -Recurse -Force
        }
        Copy-TreeExact -SourceRoot $backupPlugin -DestRoot $pluginLive
        $restoredDigest = Get-TreeDigest $pluginLive
        if ($restoredDigest -ne $backupDigest) {
            throw "live plugin digest mismatch after restore"
        }
        $evidenceComplete = $true
    } else {
        if (Test-Path -LiteralPath $pluginLive) {
            Remove-Item -LiteralPath $pluginLive -Recurse -Force
        }
        if (Test-Path -LiteralPath $pluginLive) {
            throw "no-prior rollback requires absent live plugin"
        }
        $evidenceComplete = $true
    }

    Update-RollbackState -StatePath $statePath -State $state -EvidenceComplete $evidenceComplete
    Write-RollbackEvent -JournalPath $journalPath -Event @{
        scenario = [string]$state.scenario
        source = "none"
        nonce = [guid]::NewGuid().ToString("n")
        hash = Get-DigestPrefix $postInstalledDigest
    }
    Write-Host "COEXIST_ROLLBACK_OK had_prior=$hadPrior evidence_complete=$evidenceComplete"
    exit 0
}

Clear-OwnedSubtree -ParentRoot $RunRoot -ChildName "installed"
Clear-OwnedSubtree -ParentRoot $RunRoot -ChildName "profile"
Clear-OwnedSubtree -ParentRoot $RunRoot -ChildName "workspace"
$postInstalledDigest = Get-TreeDigest (Join-Path $RunRoot "installed")
if ($postInstalledDigest -ne $expectedInstalledDigest) {
    throw "installed staging digest mismatch after rollback"
}
Update-RollbackState -StatePath $statePath -State $state -EvidenceComplete $false
Write-RollbackEvent -JournalPath $journalPath -Event @{
    scenario = [string]$state.scenario
    source = "none"
    nonce = [guid]::NewGuid().ToString("n")
    hash = Get-DigestPrefix $postInstalledDigest
}
Write-Host "COEXIST_ROLLBACK_OK isolated_only"
exit 0

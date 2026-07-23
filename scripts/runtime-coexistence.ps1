<#
.SYNOPSIS
  Reproducible runtime coexistence protocol (Prepare/Record/Finalize/SelfTest).
  Metadata-only journal; isolated TEMP roots by default; real profile requires -RealProfile + marker.
#>
[CmdletBinding()]
param(
    [ValidateSet("Prepare", "Record", "Finalize", "SelfTest")]
    [string]$Action = "SelfTest",
    [ValidateSet("baseline", "essential-only", "plugin-only", "combined")]
    [string]$Scenario = "baseline",
    [string]$RunRoot = "",
    [switch]$RealProfile,
    [switch]$TestOnly,
    [string]$SimulatedProfileRoot = "",
    [string]$InvocationMarker = "",
    [ValidateSet("none", "essential", "plugin", "combined")]
    [string]$Source = "none",
    [ValidateSet("sessionStart", "afterShellExecution", "stop")]
    [string]$HookEvent = "sessionStart",
    [string]$Nonce = "",
    [switch]$IdeAttested,
    [int]$ContextBytes = 0,
    [int]$ElapsedMs = 0,
    [switch]$TestInjectFailureAfterBackup,
    [switch]$TestInjectFailureMidBackup
)

$ErrorActionPreference = "Stop"
$ToolkitRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$PluginSrc = Join-Path $ToolkitRoot "plugin\cursor-project-harness"
$EssentialHooksSrc = Join-Path $ToolkitRoot ".cursor\hooks"
$EssentialHooksJson = Join-Path $ToolkitRoot ".cursor\hooks.json"
$RollbackScript = Join-Path $PSScriptRoot "runtime-coexistence-rollback.ps1"
$LiveSurfaceId = "plugins/local/cursor-project-harness"
$TestOnlyProfileRelative = "simulated_profile"

function Get-DigestPrefix([string]$Digest) {
    if ([string]::IsNullOrWhiteSpace($Digest) -or $Digest -eq "empty") { return "empty" }
    return $Digest.Substring(0, [Math]::Min(16, $Digest.Length))
}

function Get-CoexistenceSha256Hex([byte[]]$Bytes) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ($sha.ComputeHash($Bytes) | ForEach-Object { $_.ToString("x2") }) -join ""
    } finally {
        $sha.Dispose()
    }
}

function Get-CoexistenceSha256HexFromString([string]$Text) {
    if ($null -eq $Text) { $Text = "" }
    return Get-CoexistenceSha256Hex ([System.Text.Encoding]::UTF8.GetBytes($Text))
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

function Get-RunPaths {
    param([string]$Root)
    return @{
        Root = $Root
        Profile = Join-Path $Root "profile"
        Workspace = Join-Path $Root "workspace"
        Backup = Join-Path $Root "backup"
        BackupPartial = Join-Path $Root "backup_partial"
        Journal = Join-Path $Root "journal.jsonl"
        State = Join-Path $Root "state.json"
        Installed = Join-Path $Root "installed"
    }
}

function Read-CoexistenceState {
    param([string]$StatePath)
    if (-not (Test-Path -LiteralPath $StatePath)) { return $null }
    return (Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Write-CoexistenceState {
    param([string]$StatePath, [hashtable]$State)
    ($State | ConvertTo-Json -Depth 10 -Compress) | Set-Content -LiteralPath $StatePath -Encoding UTF8 -NoNewline
}

function Get-EventHash {
    param(
        [string]$Marker,
        [string]$Scenario,
        [string]$Source,
        [string]$Event,
        [int]$InvocationCount
    )
    $bind = $Marker + "|" + $Scenario + "|" + $Source + "|" + $Event + "|" + $InvocationCount
    return (Get-CoexistenceSha256HexFromString $bind).Substring(0, 16)
}

function Write-CoexistenceEvent {
    param([string]$JournalPath, [hashtable]$Event, [string]$Marker)
    $clean = [ordered]@{
        schema_version = 3
        scenario = $Event.scenario
        source = $Event.source
        event = $Event.event
        nonce = $Event.nonce
        hash = $Event.hash
        elapsed_ms = $Event.elapsed_ms
        invocation_count = $Event.invocation_count
        context_bytes = $Event.context_bytes
    }
    Add-Content -LiteralPath $JournalPath -Value ($clean | ConvertTo-Json -Compress -Depth 4) -Encoding UTF8
}

function Copy-TreeExact {
    param([string]$SourceRoot, [string]$DestRoot)
    if (-not (Test-Path -LiteralPath $SourceRoot)) { return }
    Assert-TreeNoReparse -Root $SourceRoot -Label "copy-source"
    Assert-TreeNoReparse -Root $DestRoot -Label "copy-dest"
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

function Backup-ProfilePath {
    param([string]$LivePath, [string]$BackupRoot, [string]$RelativeKey)
    if (-not (Test-Path -LiteralPath $LivePath)) { return $false }
    Assert-NoReparsePoint -Path $LivePath -Label "backup-live"
    Assert-TreeNoReparse -Root $BackupRoot -Label "backup-root"
    $dest = Join-Path $BackupRoot ($RelativeKey.Replace('/', '\'))
    if (Test-Path -LiteralPath $dest) { throw "pre-existing backup entry rejected" }
    $destDir = Split-Path -Parent $dest
    if ($destDir -and -not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    }
    $item = Get-Item -LiteralPath $LivePath -Force
    if ($item.PSIsContainer) {
        Copy-TreeExact -SourceRoot $LivePath -DestRoot $dest
    } else {
        [System.IO.File]::WriteAllBytes($dest, [System.IO.File]::ReadAllBytes($LivePath))
    }
    return $true
}

function Install-EssentialSurface {
    param([string]$WorkspaceRoot, [string]$InstalledRoot)
    Assert-TreeNoReparse -Root $WorkspaceRoot -Label "essential-workspace"
    $cursorDir = Join-Path $WorkspaceRoot ".cursor"
    $hooksDir = Join-Path $cursorDir "hooks"
    New-Item -ItemType Directory -Force -Path $hooksDir | Out-Null
    Copy-Item -LiteralPath $EssentialHooksJson -Destination (Join-Path $cursorDir "hooks.json") -Force
    foreach ($h in @("session-start.ps1", "after-shell-papercuts.ps1", "stop-papercuts-nudge.ps1")) {
        Copy-Item -LiteralPath (Join-Path $EssentialHooksSrc $h) -Destination (Join-Path $hooksDir $h) -Force
    }
    $dest = Join-Path $InstalledRoot "essential"
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
    Copy-TreeExact -SourceRoot $cursorDir -DestRoot $dest
}

function Install-PluginSurface {
    param([string]$ProfileRoot, [string]$InstalledRoot)
    Assert-TreeNoReparse -Root $ProfileRoot -Label "plugin-profile"
    Assert-TreeNoReparse -Root $PluginSrc -Label "plugin-source"
    $pluginDst = Join-Path $ProfileRoot "plugins\local\cursor-project-harness"
    if (Test-Path -LiteralPath $pluginDst) { Remove-Item -LiteralPath $pluginDst -Recurse -Force }
    Copy-TreeExact -SourceRoot $PluginSrc -DestRoot $pluginDst
    $dest = Join-Path $InstalledRoot "plugin"
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
    Copy-TreeExact -SourceRoot $pluginDst -DestRoot $dest
}

function Resolve-LiveProfileRoot {
    param(
        [hashtable]$Paths,
        [switch]$RealProfile,
        [switch]$TestOnly
    )
    if ($RealProfile) { return Join-Path $env:USERPROFILE ".cursor" }
    if ($TestOnly) { return Join-Path $Paths.Root $TestOnlyProfileRelative }
    return $Paths.Profile
}

function Get-PluginLivePath {
    param([string]$ProfileRoot)
    return Join-Path $ProfileRoot ($LiveSurfaceId.Replace('/', '\'))
}

function Invoke-TransactionalPluginBackup {
    param(
        [string]$LivePath,
        [hashtable]$RunPaths,
        [string]$ExpectedDigest,
        [switch]$TestInjectFailureMidBackup
    )
    Assert-NoReparsePoint -Path $LivePath -Label "backup-live"
    $partialPlugin = Join-Path $RunPaths.BackupPartial ($LiveSurfaceId.Replace('/', '\'))
    $finalPlugin = Join-Path $RunPaths.Backup ($LiveSurfaceId.Replace('/', '\'))
    if (Test-Path -LiteralPath $RunPaths.BackupPartial) {
        Remove-Item -LiteralPath $RunPaths.BackupPartial -Recurse -Force
    }
    Copy-TreeExact -SourceRoot $LivePath -DestRoot $partialPlugin
    if ($TestInjectFailureMidBackup) {
        throw "injected failure mid-backup (TestOnly)"
    }
    $partialDigest = Get-TreeDigest $partialPlugin
    if ($partialDigest -ne $ExpectedDigest) {
        throw "partial backup digest mismatch"
    }
    $finalParent = Split-Path -Parent $finalPlugin
    if (-not (Test-Path -LiteralPath $finalParent)) {
        New-Item -ItemType Directory -Force -Path $finalParent | Out-Null
    }
    if (Test-Path -LiteralPath $finalPlugin) {
        Remove-Item -LiteralPath $finalPlugin -Recurse -Force
    }
    Move-Item -LiteralPath $partialPlugin -Destination $finalPlugin -Force
    $promotedDigest = Get-TreeDigest $finalPlugin
    if ($promotedDigest -ne $ExpectedDigest) {
        throw "promoted backup digest mismatch"
    }
    if (Test-Path -LiteralPath $RunPaths.BackupPartial) {
        Remove-Item -LiteralPath $RunPaths.BackupPartial -Recurse -Force -ErrorAction SilentlyContinue
    }
    return $promotedDigest
}

function New-BaseState {
    param(
        [string]$Marker,
        [string]$Scenario,
        [string]$RunRootId,
        [bool]$RealProfile,
        [bool]$TestOnlyProfile,
        [bool]$HadPriorPlugin,
        [string]$BackupDigest,
        [string]$ExpectedLiveDigest,
        [bool]$BackupComplete,
        [string]$PrepareSeal,
        [string]$Phase
    )
    return @{
        phase = $Phase
        invocation_marker = $Marker
        scenario = $Scenario
        run_root_id = $RunRootId
        real_profile = $RealProfile
        test_only_profile = $TestOnlyProfile
        had_prior_plugin = $HadPriorPlugin
        backup_complete = $BackupComplete
        expected_live_digest = $ExpectedLiveDigest
        backup_digest = $BackupDigest
        live_surface_id = $LiveSurfaceId
        prepare_seal = $PrepareSeal
        source_digest = "none"
        installed_digest = "empty"
        pre_rollback_digest = "empty"
        used_nonces = @()
        invocation_counts = @{
            essential = @{ sessionStart = 0; afterShellExecution = 0; stop = 0 }
            plugin = @{ sessionStart = 0; afterShellExecution = 0; stop = 0 }
        }
        owner_verdict = $null
        runtime_verified = $false
        evidence_complete = $false
        ide_attested = $false
    }
}

function ConvertFrom-CoexistenceStateObject {
    param($Obj)
    $nonces = @()
    if ($null -ne $Obj.used_nonces) { $nonces = @($Obj.used_nonces) }
    return @{
        phase = [string]$Obj.phase
        invocation_marker = [string]$Obj.invocation_marker
        scenario = [string]$Obj.scenario
        run_root_id = [string]$Obj.run_root_id
        real_profile = [bool]$Obj.real_profile
        test_only_profile = [bool]$Obj.test_only_profile
        had_prior_plugin = [bool]$Obj.had_prior_plugin
        backup_complete = if ($null -ne $Obj.PSObject.Properties["backup_complete"]) { [bool]$Obj.backup_complete } else { $false }
        expected_live_digest = if ($null -ne $Obj.PSObject.Properties["expected_live_digest"]) { [string]$Obj.expected_live_digest } else { [string]$Obj.backup_digest }
        backup_digest = [string]$Obj.backup_digest
        live_surface_id = if ($null -ne $Obj.PSObject.Properties["live_surface_id"]) { [string]$Obj.live_surface_id } else { $LiveSurfaceId }
        prepare_seal = [string]$Obj.prepare_seal
        source_digest = [string]$Obj.source_digest
        installed_digest = [string]$Obj.installed_digest
        pre_rollback_digest = [string]$Obj.pre_rollback_digest
        used_nonces = $nonces
        invocation_counts = @{
            essential = @{
                sessionStart = [int]$Obj.invocation_counts.essential.sessionStart
                afterShellExecution = [int]$Obj.invocation_counts.essential.afterShellExecution
                stop = [int]$Obj.invocation_counts.essential.stop
            }
            plugin = @{
                sessionStart = [int]$Obj.invocation_counts.plugin.sessionStart
                afterShellExecution = [int]$Obj.invocation_counts.plugin.afterShellExecution
                stop = [int]$Obj.invocation_counts.plugin.stop
            }
        }
        owner_verdict = $Obj.owner_verdict
        runtime_verified = if ($null -ne $Obj.PSObject.Properties["runtime_verified"]) { [bool]$Obj.runtime_verified } else { $false }
        evidence_complete = if ($null -ne $Obj.PSObject.Properties["evidence_complete"]) { [bool]$Obj.evidence_complete } else { $false }
        ide_attested = if ($null -ne $Obj.PSObject.Properties["ide_attested"]) { [bool]$Obj.ide_attested } else { $false }
    }
}

function Test-SourceAllowedForScenario {
    param([string]$Scenario, [string]$Source)
    switch ($Scenario) {
        "baseline" { return $false }
        "essential-only" { return ($Source -eq "essential") }
        "plugin-only" { return ($Source -eq "plugin") }
        "combined" { return ($Source -in @("essential", "plugin")) }
    }
    return $false
}

function Invoke-PrepareRollbackSafe {
    param(
        [string]$RunRoot,
        [string]$Marker
    )
    if (-not (Test-Path -LiteralPath $RollbackScript)) { return }
    if (-not (Test-Path -LiteralPath (Join-Path $RunRoot "state.json"))) { return }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $RollbackScript -RunRoot $RunRoot -InvocationMarker $Marker 2>&1 | Out-Null
}

function Invoke-CoexistencePrepare {
    param(
        [hashtable]$Paths,
        [string]$Scenario,
        [string]$Marker,
        [switch]$RealProfile,
        [switch]$TestOnly,
        [switch]$TestInjectFailureAfterBackup,
        [switch]$TestInjectFailureMidBackup
    )

    if ($RealProfile -and $TestOnly) { throw "RealProfile and TestOnly are mutually exclusive" }
    if (($TestInjectFailureAfterBackup -or $TestInjectFailureMidBackup) -and -not $TestOnly) {
        throw "injected failure switches require TestOnly"
    }
    if ($RealProfile -and [string]::IsNullOrWhiteSpace($Marker)) {
        throw "RealProfile requires non-empty InvocationMarker"
    }
    if ($TestOnly -and [string]::IsNullOrWhiteSpace($Marker)) {
        throw "TestOnly requires InvocationMarker"
    }

    Assert-TreeNoReparse -Root $Paths.Root -Label "run-root"
    if (Test-Path -LiteralPath $Paths.Backup) {
        $existing = @(Get-ChildItem -LiteralPath $Paths.Backup -Recurse -File -Force -ErrorAction SilentlyContinue)
        if ($existing.Count -gt 0) { throw "pre-existing backup rejected" }
    } else {
        New-Item -ItemType Directory -Force -Path $Paths.Backup | Out-Null
    }
    if (Test-Path -LiteralPath $Paths.BackupPartial) {
        Remove-Item -LiteralPath $Paths.BackupPartial -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Force -Path $Paths.Profile | Out-Null
    New-Item -ItemType Directory -Force -Path $Paths.Workspace | Out-Null
    New-Item -ItemType Directory -Force -Path $Paths.Installed | Out-Null
    if ($TestOnly) {
        New-Item -ItemType Directory -Force -Path (Join-Path $Paths.Root $TestOnlyProfileRelative) | Out-Null
    }

    $preRollbackDigest = Get-TreeDigest $Paths.Installed
    $profileRoot = Resolve-LiveProfileRoot -Paths $Paths -RealProfile:$RealProfile -TestOnly:$TestOnly
    $runRootId = (Get-CoexistenceSha256HexFromString ((Split-Path -Leaf $Paths.Root))).Substring(0, 16)
    $prepareSeal = (Get-CoexistenceSha256HexFromString ($Marker + "|" + $Scenario + "|" + $runRootId)).Substring(0, 16)

    $pluginLive = Get-PluginLivePath -ProfileRoot $profileRoot
    $hadPriorPlugin = $false
    $expectedLiveDigest = "empty"
    $backupDigest = "empty"
    $backupComplete = $false

    if (($RealProfile -or $TestOnly) -and (Test-Path -LiteralPath $pluginLive)) {
        $hadPriorPlugin = $true
        $expectedLiveDigest = Get-TreeDigest $pluginLive
        $backupDigest = $expectedLiveDigest
    }

    $state = New-BaseState -Marker $Marker -Scenario $Scenario -RunRootId $runRootId `
        -RealProfile ([bool]$RealProfile) -TestOnlyProfile ([bool]$TestOnly) `
        -HadPriorPlugin $hadPriorPlugin -BackupDigest $backupDigest -ExpectedLiveDigest $expectedLiveDigest `
        -BackupComplete $false -PrepareSeal $prepareSeal -Phase "pre_mutation"
    $state.pre_rollback_digest = $preRollbackDigest
    if (-not $RealProfile -and -not $TestOnly) {
        $state.backup_complete = $true
        $state.expected_live_digest = "empty"
        $state.backup_digest = "empty"
        $backupComplete = $true
    }
    Write-CoexistenceState -StatePath $Paths.State -State $state

    $liveDigestBeforeMutation = if ($hadPriorPlugin) { Get-TreeDigest $pluginLive } else { "empty" }

    try {
        if ($hadPriorPlugin) {
            $promoted = Invoke-TransactionalPluginBackup -LivePath $pluginLive -RunPaths $Paths `
                -ExpectedDigest $expectedLiveDigest -TestInjectFailureMidBackup:$TestInjectFailureMidBackup
            $state.backup_digest = $promoted
            $state.expected_live_digest = $expectedLiveDigest
            $state.backup_complete = $true
            $backupComplete = $true
            Write-CoexistenceState -StatePath $Paths.State -State $state
        } else {
            if ($RealProfile -or $TestOnly) {
                $state.backup_complete = $true
                $state.expected_live_digest = "empty"
                $state.backup_digest = "empty"
                $backupComplete = $true
                Write-CoexistenceState -StatePath $Paths.State -State $state
            }
        }

        if ($TestInjectFailureAfterBackup) {
            throw "injected failure after backup (TestOnly)"
        }

        $sourceDigestParts = @()
        switch ($Scenario) {
            "baseline" { }
            "essential-only" {
                Install-EssentialSurface -WorkspaceRoot $Paths.Workspace -InstalledRoot $Paths.Installed
                $sourceDigestParts += ("essential=" + (Get-TreeDigest (Join-Path $Paths.Installed "essential")))
            }
            "plugin-only" {
                Install-PluginSurface -ProfileRoot $profileRoot -InstalledRoot $Paths.Installed
                $sourceDigestParts += ("plugin=" + (Get-TreeDigest (Join-Path $Paths.Installed "plugin")))
            }
            "combined" {
                Install-EssentialSurface -WorkspaceRoot $Paths.Workspace -InstalledRoot $Paths.Installed
                Install-PluginSurface -ProfileRoot $profileRoot -InstalledRoot $Paths.Installed
                $sourceDigestParts += ("essential=" + (Get-TreeDigest (Join-Path $Paths.Installed "essential")))
                $sourceDigestParts += ("plugin=" + (Get-TreeDigest (Join-Path $Paths.Installed "plugin")))
            }
        }

        $installedDigest = Get-TreeDigest $Paths.Installed
        $sourceDigest = if ($sourceDigestParts.Count -gt 0) {
            (Get-CoexistenceSha256HexFromString (($sourceDigestParts -join "|")))
        } else { "none" }

        $state.phase = "prepared"
        $state.source_digest = $sourceDigest
        $state.installed_digest = $installedDigest
        Write-CoexistenceState -StatePath $Paths.State -State $state

        $nonce = if ([string]::IsNullOrWhiteSpace($script:Nonce)) { [guid]::NewGuid().ToString("n") } else { $script:Nonce }
        $state.used_nonces = @($nonce)
        Write-CoexistenceState -StatePath $Paths.State -State $state

        Write-CoexistenceEvent -JournalPath $Paths.Journal -Event @{
            scenario = $Scenario
            source = "none"
            event = "prepare"
            nonce = $nonce
            hash = Get-EventHash -Marker $Marker -Scenario $Scenario -Source "none" -Event "prepare" -InvocationCount 0
            elapsed_ms = 0
            invocation_count = 0
            context_bytes = 0
        } -Marker $Marker

        Write-Host "COEXIST_PREPARE_OK scenario=$Scenario digest=$(Get-DigestPrefix $installedDigest)"
    } catch {
        if ($backupComplete) {
            $state.phase = "rollback_pending"
            Write-CoexistenceState -StatePath $Paths.State -State $state
            Invoke-PrepareRollbackSafe -RunRoot $Paths.Root -Marker $Marker
        } else {
            $state.phase = "backup_failed"
            Write-CoexistenceState -StatePath $Paths.State -State $state
            if ($hadPriorPlugin) {
                $liveDigestAfterFailure = Get-TreeDigest $pluginLive
                if ($liveDigestAfterFailure -ne $liveDigestBeforeMutation) {
                    throw "live plugin mutated during incomplete backup"
                }
            }
        }
        throw
    }
}

function Invoke-CoexistenceRecord {
    param(
        [hashtable]$Paths,
        [string]$Marker,
        [string]$Source,
        [string]$HookEvent,
        [string]$Nonce,
        [switch]$IdeAttested,
        [int]$ContextBytes,
        [int]$ElapsedMs
    )
    if ([string]::IsNullOrWhiteSpace($Marker)) { throw "Record requires InvocationMarker" }
    $stateObj = Read-CoexistenceState -StatePath $Paths.State
    if ($null -eq $stateObj) { throw "missing state; run Prepare first" }
    $state = ConvertFrom-CoexistenceStateObject $stateObj
    if ($state.invocation_marker -ne $Marker) { throw "invocation marker mismatch" }
    if ($state.phase -notin @("prepared", "recorded", "rolled_back")) { throw "Record requires prepared phase" }
    if ($Source -notin @("essential", "plugin")) { throw "Record source must be essential or plugin" }
    if (-not (Test-SourceAllowedForScenario -Scenario $state.scenario -Source $Source)) {
        throw "source not allowed for scenario"
    }

    $useNonce = if ([string]::IsNullOrWhiteSpace($Nonce)) { [guid]::NewGuid().ToString("n") } else { $Nonce }
    if ($state.used_nonces -contains $useNonce) { throw "nonce replay rejected" }
    $state.used_nonces = @($state.used_nonces) + @($useNonce)

    $state.invocation_counts[$Source][$HookEvent] = [int]$state.invocation_counts[$Source][$HookEvent] + 1
    $invCount = [int]$state.invocation_counts[$Source][$HookEvent]
    $state.phase = "recorded"
    if ($IdeAttested -and $state.real_profile) {
        $state.ide_attested = $true
    }
    $state.runtime_verified = $false
    Write-CoexistenceState -StatePath $Paths.State -State $state

    Write-CoexistenceEvent -JournalPath $Paths.Journal -Event @{
        scenario = $state.scenario
        source = $Source
        event = "record"
        nonce = $useNonce
        hash = Get-EventHash -Marker $Marker -Scenario $state.scenario -Source $Source -Event $HookEvent -InvocationCount $invCount
        elapsed_ms = $ElapsedMs
        invocation_count = $invCount
        context_bytes = $ContextBytes
    } -Marker $Marker
    Write-Host "COEXIST_RECORD_OK source=$Source event=$HookEvent count=$invCount"
}

function Get-OwnerVerdictFromState {
    param($State)
    $eTotal = [int]$State.invocation_counts.essential.sessionStart +
        [int]$State.invocation_counts.essential.afterShellExecution +
        [int]$State.invocation_counts.essential.stop
    $pTotal = [int]$State.invocation_counts.plugin.sessionStart +
        [int]$State.invocation_counts.plugin.afterShellExecution +
        [int]$State.invocation_counts.plugin.stop
    if ($eTotal -gt 0 -and $pTotal -gt 0) { return "combined_unsupported" }
    if ($eTotal -gt 0) { return "essential" }
    if ($pTotal -gt 0) { return "plugin" }
    return "none"
}

function Invoke-CoexistenceFinalize {
    param([hashtable]$Paths, [string]$Marker)
    $stateObj = Read-CoexistenceState -StatePath $Paths.State
    if ($null -eq $stateObj) { throw "missing state; run Prepare first" }
    $state = ConvertFrom-CoexistenceStateObject $stateObj
    if (-not [string]::IsNullOrWhiteSpace($Marker) -and $state.invocation_marker -ne $Marker) {
        throw "invocation marker mismatch"
    }
    if ($state.phase -notin @("prepared", "recorded", "rolled_back")) {
        throw "Finalize requires prepared/recorded/rolled_back phase"
    }

    $owner = Get-OwnerVerdictFromState -State $state
    $state.owner_verdict = $owner
    if ($state.phase -ne "rolled_back") {
        $installedDigest = Get-TreeDigest $Paths.Installed
        if ($installedDigest -ne $state.installed_digest) { throw "installed digest mismatch at finalize" }
    }

    $hasRecord = ([int]$state.invocation_counts.essential.sessionStart +
        [int]$state.invocation_counts.essential.afterShellExecution +
        [int]$state.invocation_counts.essential.stop +
        [int]$state.invocation_counts.plugin.sessionStart +
        [int]$state.invocation_counts.plugin.afterShellExecution +
        [int]$state.invocation_counts.plugin.stop) -gt 0
    $preserveEvidence = [bool]$state.evidence_complete
    $runtimeVerified = $false
    if ($state.real_profile -and $state.ide_attested -and $hasRecord -and ($owner -ne "combined_unsupported") -and $preserveEvidence) {
        $runtimeVerified = $true
    }

    $state.runtime_verified = $runtimeVerified
    $state.evidence_complete = $preserveEvidence
    if ($state.phase -eq "rolled_back" -and $preserveEvidence) {
        $state.evidence_complete = $true
    }
    $state.phase = "finalized"
    Write-CoexistenceState -StatePath $Paths.State -State $state

    $nonce = [guid]::NewGuid().ToString("n")
    $state.used_nonces = @($state.used_nonces) + @($nonce)
    Write-CoexistenceState -StatePath $Paths.State -State $state
    $totalInv = [int]$state.invocation_counts.essential.sessionStart +
        [int]$state.invocation_counts.essential.afterShellExecution +
        [int]$state.invocation_counts.essential.stop +
        [int]$state.invocation_counts.plugin.sessionStart +
        [int]$state.invocation_counts.plugin.afterShellExecution +
        [int]$state.invocation_counts.plugin.stop
    Write-CoexistenceEvent -JournalPath $Paths.Journal -Event @{
        scenario = $state.scenario
        source = if ($owner -eq "combined_unsupported") { "combined" } elseif ($owner -eq "none") { "none" } else { $owner }
        event = "finalize"
        nonce = $nonce
        hash = Get-EventHash -Marker $state.invocation_marker -Scenario $state.scenario -Source "none" -Event "finalize" -InvocationCount $totalInv
        elapsed_ms = 0
        invocation_count = $totalInv
        context_bytes = 0
    } -Marker $state.invocation_marker

    Write-Host "COEXIST_FINALIZE_OK owner=$owner runtime_verified=$runtimeVerified evidence_complete=$($state.evidence_complete)"
    if (-not $runtimeVerified) {
        Write-Host "COEXIST_RUNTIME_UNVERIFIED external IDE reload required for runtime proof"
    }
}

function Invoke-CoexistenceSelfTest {
    $fail = 0
    function Assert-True($cond, [string]$msg) {
        if ($cond) { Write-Host "OK  $msg" } else { Write-Host "FAIL $msg"; $script:fail++ }
    }

    Write-Host "=== runtime-coexistence SelfTest ==="
    $rollbackScript = Join-Path $PSScriptRoot "runtime-coexistence-rollback.ps1"

    $scenarios = @(
        @{ Name = "baseline"; RecordSource = $null; ExpectOwner = "none" }
        @{ Name = "essential-only"; RecordSource = "essential"; ExpectOwner = "essential" }
        @{ Name = "plugin-only"; RecordSource = "plugin"; ExpectOwner = "plugin" }
        @{ Name = "combined"; RecordSource = "both"; ExpectOwner = "combined_unsupported" }
    )

    foreach ($sc in $scenarios) {
        $root = Join-Path $env:TEMP ("cptk-coexist-" + [guid]::NewGuid().ToString("n"))
        $marker = "selftest-" + [guid]::NewGuid().ToString("n")
        try {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath -Action Prepare -Scenario $sc.Name -RunRoot $root -InvocationMarker $marker 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { Assert-True $false "$($sc.Name) Prepare exit 0"; continue }
            if ($sc.RecordSource -eq "essential" -or $sc.RecordSource -eq "both") {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath -Action Record -RunRoot $root -InvocationMarker $marker -Source essential -HookEvent sessionStart -ContextBytes 128 -ElapsedMs 3 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) { Assert-True $false "$($sc.Name) Record essential exit 0"; continue }
            }
            if ($sc.RecordSource -eq "plugin" -or $sc.RecordSource -eq "both") {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath -Action Record -RunRoot $root -InvocationMarker $marker -Source plugin -HookEvent sessionStart -ContextBytes 128 -ElapsedMs 3 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) { Assert-True $false "$($sc.Name) Record plugin exit 0"; continue }
            }
            $paths = Get-RunPaths -Root $root
            $stBeforeRollback = Read-CoexistenceState -StatePath $paths.State
            $preRollbackDigest = [string]$stBeforeRollback.pre_rollback_digest
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $rollbackScript -RunRoot $root -InvocationMarker $marker 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { Assert-True $false "$($sc.Name) Rollback exit 0"; continue }
            $postDigest = Get-TreeDigest $paths.Installed
            Assert-True ($postDigest -eq $preRollbackDigest) "$($sc.Name) installed staging digest restored"
            $stAfterRollback = Read-CoexistenceState -StatePath $paths.State
            $evidenceAfterRollback = [bool]$stAfterRollback.evidence_complete
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath -Action Finalize -RunRoot $root -InvocationMarker $marker 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { Assert-True $false "$($sc.Name) Finalize exit 0"; continue }
            $st = Read-CoexistenceState -StatePath $paths.State
            Assert-True ($st.owner_verdict -eq $sc.ExpectOwner) "$($sc.Name) owner=$($st.owner_verdict)"
            Assert-True (-not [bool]$st.runtime_verified) "$($sc.Name) runtime_verified false (isolated)"
            Assert-True ([bool]$st.evidence_complete -eq $evidenceAfterRollback) "$($sc.Name) evidence_complete preserved after Finalize"
            Assert-True ($st.phase -eq "finalized") "$($sc.Name) phase finalized"
        } finally {
            if (Test-Path -LiteralPath $root) {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    $rejectRoot = Join-Path $env:TEMP ("cptk-coexist-rej-" + [guid]::NewGuid().ToString("n"))
    try {
        $paths = Get-RunPaths -Root $rejectRoot
        New-Item -ItemType Directory -Force -Path $paths.Backup | Out-Null
        Set-Content -LiteralPath (Join-Path $paths.Backup "stale.bin") -Value "x" -Encoding ASCII
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath -Action Prepare -Scenario baseline -RunRoot $rejectRoot -InvocationMarker "rej" 2>&1 | Out-Null
        $codeRej = $LASTEXITCODE
        $ErrorActionPreference = $prevEap
        Assert-True ($codeRej -ne 0) "pre-existing backup rejected"
    } finally {
        Remove-Item -LiteralPath $rejectRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    $prevEap2 = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath -Action Prepare -Scenario plugin-only -RealProfile -InvocationMarker "" 2>&1 | Out-Null
    $codeNoMarker = $LASTEXITCODE
    $ErrorActionPreference = $prevEap2
    Assert-True ($codeNoMarker -ne 0) "RealProfile without marker rejected"

    Write-Host ""
    if ($fail -eq 0) {
        Write-Host "COEXISTENCE_SELFTEST_PASS"
        exit 0
    }
    Write-Host "COEXISTENCE_SELFTEST_FAIL: $fail"
    exit 1
}

if ($Action -eq "SelfTest") {
    Invoke-CoexistenceSelfTest
    exit $LASTEXITCODE
}

if ([string]::IsNullOrWhiteSpace($RunRoot)) {
    $RunRoot = Join-Path $env:TEMP ("cptk-coexist-" + [guid]::NewGuid().ToString("n"))
    New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null
}

$paths = Get-RunPaths -Root $RunRoot

switch ($Action) {
    "Prepare" {
        Invoke-CoexistencePrepare -Paths $paths -Scenario $Scenario -Marker $InvocationMarker `
            -RealProfile:$RealProfile -TestOnly:$TestOnly `
            -TestInjectFailureAfterBackup:$TestInjectFailureAfterBackup -TestInjectFailureMidBackup:$TestInjectFailureMidBackup
    }
    "Record" {
        Invoke-CoexistenceRecord -Paths $paths -Marker $InvocationMarker -Source $Source -HookEvent $HookEvent `
            -Nonce $Nonce -IdeAttested:$IdeAttested -ContextBytes $ContextBytes -ElapsedMs $ElapsedMs
    }
    "Finalize" {
        Invoke-CoexistenceFinalize -Paths $paths -Marker $InvocationMarker
    }
}

exit 0

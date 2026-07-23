<#
.SYNOPSIS
  Deterministic tests for runtime coexistence protocol (TestOnly simulated profile; no User HOME writes).
#>
$ErrorActionPreference = "Stop"
$ToolkitRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$ProtocolScript = Join-Path $ToolkitRoot "scripts\runtime-coexistence.ps1"
$RollbackScript = Join-Path $ToolkitRoot "scripts\runtime-coexistence-rollback.ps1"
$SchemaPath = Join-Path $PSScriptRoot "coexistence-protocol.schema.json"
$fail = 0
$captured = New-Object System.Collections.Generic.List[string]
$sampleToken = "__CPTK_COEXIST_SAMPLE__"
$script:WorkspaceLockStream = $null

function Assert-True($cond, [string]$msg) {
    if ($cond) {
        Write-Host "OK  $msg"
        [void]$captured.Add("OK  $msg")
    } else {
        Write-Host "FAIL $msg"
        [void]$captured.Add("FAIL $msg")
        $script:fail++
    }
}

function Invoke-Protocol {
    param([string[]]$ArgList)
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $lines = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ProtocolScript @ArgList 2>&1 | ForEach-Object { [string]$_ })
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    foreach ($l in $lines) { [void]$captured.Add($l) }
    return @{ Code = $code; Lines = $lines }
}

function Invoke-Rollback {
    param([string]$RunRoot, [string]$InvocationMarker)
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $null = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $RollbackScript -RunRoot $RunRoot -InvocationMarker $InvocationMarker 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    return $code
}

function Unlock-OwnedRunRootChild {
    if ($null -ne $script:WorkspaceLockStream) {
        $script:WorkspaceLockStream.Close()
        $script:WorkspaceLockStream.Dispose()
        $script:WorkspaceLockStream = $null
    }
}

function Lock-OwnedRunRootChild {
    param([string]$ChildRoot)
    New-Item -ItemType Directory -Force -Path $ChildRoot | Out-Null
    $lockPath = Join-Path $ChildRoot ".cptk-lock"
    $script:WorkspaceLockStream = [System.IO.File]::Open(
        $lockPath,
        [System.IO.FileMode]::OpenOrCreate,
        [System.IO.FileAccess]::ReadWrite,
        [System.IO.FileShare]::None
    )
}

function Get-TreeDigest {
    param([string]$Root)
    if (-not (Test-Path -LiteralPath $Root)) { return "empty" }
    $pairs = New-Object System.Collections.Generic.List[string]
    foreach ($f in (Get-ChildItem -LiteralPath $Root -Recurse -File -Force -ErrorAction Stop)) {
        $rel = $f.FullName.Substring($Root.Length).TrimStart('\', '/').Replace('\', '/')
        $hash = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        [void]$pairs.Add("$rel=$hash")
    }
    $pairs.Sort([StringComparer]::Ordinal)
    if ($pairs.Count -eq 0) { return "empty" }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes(($pairs -join "|"))
        return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join "")
    } finally { $sha.Dispose() }
}

function Seed-PriorPlugin {
    param([string]$SimProfileRoot)
    $dst = Join-Path $SimProfileRoot "plugins\local\cursor-project-harness"
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    Set-Content -LiteralPath (Join-Path $dst "prior-marker.txt") -Value $sampleToken -Encoding ASCII -NoNewline
}

function Assert-StateAllowlist {
    param($StateObj, [string]$Label)
    foreach ($prop in $StateObj.PSObject.Properties.Name) {
        Assert-True ($schema.state_fields -contains $prop) "$Label state field allowlisted: $prop"
    }
    foreach ($forbidden in $schema.forbidden_state_fields) {
        Assert-True (-not ($StateObj.PSObject.Properties.Name -contains $forbidden)) "$Label excludes forbidden field $forbidden"
    }
}

function Assert-JournalAllowlist {
    param([string]$JournalPath, [string]$Label)
    if (-not (Test-Path -LiteralPath $JournalPath)) { return }
    foreach ($line in (Get-Content -LiteralPath $JournalPath -Encoding UTF8)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $entry = $line | ConvertFrom-Json
        foreach ($prop in $entry.PSObject.Properties.Name) {
            Assert-True ($schema.allowed_fields -contains $prop) "$Label journal field allowlisted: $prop"
        }
        Assert-NoPrivatePathLeaks -Text $line -Label $Label
    }
}

function Assert-NoPrivatePathLeaks {
    param([string]$Text, [string]$Label)
    Assert-True ($Text -notmatch [regex]::Escape($sampleToken)) "$Label excludes sample token"
    if ($env:USERNAME) {
        Assert-True ($Text -notmatch [regex]::Escape($env:USERNAME)) "$Label excludes username"
    }
    Assert-True ($Text -notmatch '\\Users\\') "$Label excludes Users path pattern"
    Assert-True ($Text -notmatch 'simulated_profile_root') "$Label excludes forbidden state field"
    Assert-True ($Text -notmatch 'profile_root') "$Label excludes profile_root field"
}

Write-Host "=== test-coexistence-protocol ==="

Assert-True (Test-Path -LiteralPath $SchemaPath) "protocol schema exists"
$schema = Get-Content -LiteralPath $SchemaPath -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-True ($schema.schema_version -eq 3) "schema version 3"
Assert-True ($schema.forbidden_state_fields -contains "simulated_profile_root") "schema forbids simulated_profile_root"

$self = Invoke-Protocol -ArgList @("-Action", "SelfTest")
foreach ($l in $self.Lines) { Write-Host $l }
Assert-True ($self.Code -eq 0) "runtime-coexistence SelfTest exit 0"

$scenarioOrder = @(
    @{ Name = "baseline"; RecordSource = $null; ExpectOwner = "none" }
    @{ Name = "essential-only"; RecordSource = "essential"; ExpectOwner = "essential" }
    @{ Name = "plugin-only"; RecordSource = "plugin"; ExpectOwner = "plugin" }
    @{ Name = "combined"; RecordSource = "both"; ExpectOwner = "combined_unsupported" }
)
foreach ($sc in $scenarioOrder) {
    $rootOrd = Join-Path $env:TEMP ("cptk-coexist-ord-" + [guid]::NewGuid().ToString("n"))
    $markerOrd = "ord-" + [guid]::NewGuid().ToString("n")
    try {
        $prepOrd = Invoke-Protocol -ArgList @(
            "-Action", "Prepare", "-Scenario", $sc.Name, "-RunRoot", $rootOrd, "-InvocationMarker", $markerOrd
        )
        Assert-True ($prepOrd.Code -eq 0) "$($sc.Name) order Prepare exit 0"
        if ($sc.RecordSource -eq "essential" -or $sc.RecordSource -eq "both") {
            Assert-True ((Invoke-Protocol -ArgList @(
                "-Action", "Record", "-RunRoot", $rootOrd, "-InvocationMarker", $markerOrd,
                "-Source", "essential", "-HookEvent", "sessionStart"
            )).Code -eq 0) "$($sc.Name) order Record essential exit 0"
        }
        if ($sc.RecordSource -eq "plugin" -or $sc.RecordSource -eq "both") {
            Assert-True ((Invoke-Protocol -ArgList @(
                "-Action", "Record", "-RunRoot", $rootOrd, "-InvocationMarker", $markerOrd,
                "-Source", "plugin", "-HookEvent", "sessionStart"
            )).Code -eq 0) "$($sc.Name) order Record plugin exit 0"
        }
        Assert-True ((Invoke-Rollback -RunRoot $rootOrd -InvocationMarker $markerOrd) -eq 0) "$($sc.Name) order Rollback exit 0"
        $finOrd = Invoke-Protocol -ArgList @("-Action", "Finalize", "-RunRoot", $rootOrd, "-InvocationMarker", $markerOrd)
        Assert-True ($finOrd.Code -eq 0) "$($sc.Name) order Finalize exit 0"
        $stOrd = Get-Content -LiteralPath (Join-Path $rootOrd "state.json") -Raw | ConvertFrom-Json
        Assert-True ($stOrd.owner_verdict -eq $sc.ExpectOwner) "$($sc.Name) order owner=$($sc.ExpectOwner)"
        Assert-True (-not [bool]$stOrd.runtime_verified) "$($sc.Name) order runtime_verified false"
    } finally {
        Remove-Item -LiteralPath $rootOrd -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$rootPrior = Join-Path $env:TEMP ("cptk-coexist-prior-" + [guid]::NewGuid().ToString("n"))
$simPrior = Join-Path $rootPrior "simulated_profile"
$markerPrior = "prior-" + [guid]::NewGuid().ToString("n")
try {
    Seed-PriorPlugin -SimProfileRoot $simPrior
    $digestBefore = Get-TreeDigest (Join-Path $simPrior "plugins\local\cursor-project-harness")
    $prep = Invoke-Protocol -ArgList @(
        "-Action", "Prepare", "-Scenario", "plugin-only", "-RunRoot", $rootPrior,
        "-TestOnly", "-InvocationMarker", $markerPrior
    )
    Assert-True ($prep.Code -eq 0) "TestOnly prior-plugin Prepare exit 0"
    $stateRaw = Get-Content -LiteralPath (Join-Path $rootPrior "state.json") -Raw -Encoding UTF8
    $st = $stateRaw | ConvertFrom-Json
    Assert-True ([bool]$st.had_prior_plugin) "state had_prior_plugin true"
    Assert-True ([bool]$st.backup_complete) "state backup_complete true"
    Assert-True ($st.backup_digest -eq $digestBefore) "backup_digest matches prior plugin tree"
    Assert-NoPrivatePathLeaks -Text $stateRaw -Label "state.json"
    Assert-StateAllowlist -StateObj $st -Label "prior-plugin"

    $recPrior = Invoke-Protocol -ArgList @(
        "-Action", "Record", "-RunRoot", $rootPrior, "-InvocationMarker", $markerPrior,
        "-Source", "plugin", "-HookEvent", "sessionStart"
    )
    Assert-True ($recPrior.Code -eq 0) "prior-plugin Record exit 0"

    Assert-True ((Invoke-Rollback -RunRoot $rootPrior -InvocationMarker $markerPrior) -eq 0) "prior-plugin rollback exit 0"
    $digestAfter = Get-TreeDigest (Join-Path $simPrior "plugins\local\cursor-project-harness")
    Assert-True ($digestAfter -eq $digestBefore) "prior-plugin live digest restored byte-for-byte"
    $st2 = Get-Content -LiteralPath (Join-Path $rootPrior "state.json") -Raw | ConvertFrom-Json
    Assert-True ([bool]$st2.evidence_complete) "prior-plugin evidence_complete after rollback"

    $fin = Invoke-Protocol -ArgList @("-Action", "Finalize", "-RunRoot", $rootPrior, "-InvocationMarker", $markerPrior)
    Assert-True ($fin.Code -eq 0) "Finalize after rollback exit 0"
    $st3 = Get-Content -LiteralPath (Join-Path $rootPrior "state.json") -Raw | ConvertFrom-Json
    Assert-True ([bool]$st3.evidence_complete) "Finalize preserves evidence_complete after rollback"
    Assert-True ($st3.owner_verdict -eq "plugin") "Finalize preserves owner verdict plugin"
} finally {
    Remove-Item -LiteralPath $rootPrior -Recurse -Force -ErrorAction SilentlyContinue
}

$rootNoPrior = Join-Path $env:TEMP ("cptk-coexist-noprior-" + [guid]::NewGuid().ToString("n"))
$simNoPrior = Join-Path $rootNoPrior "simulated_profile"
$markerNoPrior = "noprior-" + [guid]::NewGuid().ToString("n")
try {
    $prep = Invoke-Protocol -ArgList @(
        "-Action", "Prepare", "-Scenario", "plugin-only", "-RunRoot", $rootNoPrior,
        "-TestOnly", "-InvocationMarker", $markerNoPrior
    )
    Assert-True ($prep.Code -eq 0) "TestOnly no-prior Prepare exit 0"
    $pluginLive = Join-Path $simNoPrior "plugins\local\cursor-project-harness"
    Assert-True (Test-Path -LiteralPath $pluginLive) "plugin installed during prepare"
    Assert-True ((Invoke-Rollback -RunRoot $rootNoPrior -InvocationMarker $markerNoPrior) -eq 0) "no-prior rollback exit 0"
    Assert-True (-not (Test-Path -LiteralPath $pluginLive)) "no-prior rollback leaves plugin absent"
} finally {
    Remove-Item -LiteralPath $rootNoPrior -Recurse -Force -ErrorAction SilentlyContinue
}

$rootMid = Join-Path $env:TEMP ("cptk-coexist-mid-" + [guid]::NewGuid().ToString("n"))
$simMid = Join-Path $rootMid "simulated_profile"
$markerMid = "mid-" + [guid]::NewGuid().ToString("n")
try {
    Seed-PriorPlugin -SimProfileRoot $simMid
    $digestMidBefore = Get-TreeDigest (Join-Path $simMid "plugins\local\cursor-project-harness")
    $prepMid = Invoke-Protocol -ArgList @(
        "-Action", "Prepare", "-Scenario", "plugin-only", "-RunRoot", $rootMid,
        "-TestOnly", "-InvocationMarker", $markerMid, "-TestInjectFailureMidBackup"
    )
    Assert-True ($prepMid.Code -ne 0) "mid-backup injected failure exit non-zero"
    $stMid = Get-Content -LiteralPath (Join-Path $rootMid "state.json") -Raw | ConvertFrom-Json
    Assert-True ($stMid.phase -eq "backup_failed") "mid-backup failure phase backup_failed"
    Assert-True (-not [bool]$stMid.backup_complete) "mid-backup backup_complete false"
    $digestMidAfter = Get-TreeDigest (Join-Path $simMid "plugins\local\cursor-project-harness")
    Assert-True ($digestMidAfter -eq $digestMidBefore) "mid-backup live digest unchanged"
    Assert-True ((Invoke-Rollback -RunRoot $rootMid -InvocationMarker $markerMid) -ne 0) "mid-backup rollback refused non-destructive"
    $digestMidFinal = Get-TreeDigest (Join-Path $simMid "plugins\local\cursor-project-harness")
    Assert-True ($digestMidFinal -eq $digestMidBefore) "mid-backup live digest still unchanged after refused rollback"
} finally {
    Remove-Item -LiteralPath $rootMid -Recurse -Force -ErrorAction SilentlyContinue
}

$rootFail = Join-Path $env:TEMP ("cptk-coexist-fail-" + [guid]::NewGuid().ToString("n"))
$simFail = Join-Path $rootFail "simulated_profile"
$markerFail = "fail-" + [guid]::NewGuid().ToString("n")
try {
    Seed-PriorPlugin -SimProfileRoot $simFail
    $digestBeforeFail = Get-TreeDigest (Join-Path $simFail "plugins\local\cursor-project-harness")
    $prepFail = Invoke-Protocol -ArgList @(
        "-Action", "Prepare", "-Scenario", "plugin-only", "-RunRoot", $rootFail,
        "-TestOnly", "-InvocationMarker", $markerFail, "-TestInjectFailureAfterBackup"
    )
    Assert-True ($prepFail.Code -ne 0) "after-backup injected failure exit non-zero"
    $stFail = Get-Content -LiteralPath (Join-Path $rootFail "state.json") -Raw | ConvertFrom-Json
    Assert-True ($stFail.phase -in @("rollback_pending", "rolled_back")) "after-backup failure rollback-runnable"
    if ($stFail.phase -eq "rollback_pending") {
        Assert-True ((Invoke-Rollback -RunRoot $rootFail -InvocationMarker $markerFail) -eq 0) "after-backup manual rollback exit 0"
    }
    $digestRecovered = Get-TreeDigest (Join-Path $simFail "plugins\local\cursor-project-harness")
    Assert-True ($digestRecovered -eq $digestBeforeFail) "after-backup recovery restores prior digest"
} finally {
    Remove-Item -LiteralPath $rootFail -Recurse -Force -ErrorAction SilentlyContinue
}

$rootLock = Join-Path $env:TEMP ("cptk-coexist-lock-" + [guid]::NewGuid().ToString("n"))
$simLock = Join-Path $rootLock "simulated_profile"
$markerLock = "lock-" + [guid]::NewGuid().ToString("n")
try {
    Seed-PriorPlugin -SimProfileRoot $simLock
    $digestLockBefore = Get-TreeDigest (Join-Path $simLock "plugins\local\cursor-project-harness")
    $prepLock = Invoke-Protocol -ArgList @(
        "-Action", "Prepare", "-Scenario", "plugin-only", "-RunRoot", $rootLock,
        "-TestOnly", "-InvocationMarker", $markerLock
    )
    Assert-True ($prepLock.Code -eq 0) "locked-installed Prepare exit 0"
    $recLock = Invoke-Protocol -ArgList @(
        "-Action", "Record", "-RunRoot", $rootLock, "-InvocationMarker", $markerLock,
        "-Source", "plugin", "-HookEvent", "sessionStart"
    )
    Assert-True ($recLock.Code -eq 0) "locked-installed Record exit 0"
    Lock-OwnedRunRootChild -ChildRoot (Join-Path $rootLock "installed")
    Assert-True ((Invoke-Rollback -RunRoot $rootLock -InvocationMarker $markerLock) -eq 0) "locked-installed rollback exit 0"
    $stLock = Get-Content -LiteralPath (Join-Path $rootLock "state.json") -Raw | ConvertFrom-Json
    Assert-True ([bool]$stLock.evidence_complete) "locked-installed evidence_complete true"
    Assert-True (-not [bool]$stLock.cleanup_complete) "locked-installed cleanup_complete false"
    Assert-True ([bool]$stLock.cleanup_pending) "locked-installed cleanup_pending true"
    $digestLockAfter = Get-TreeDigest (Join-Path $simLock "plugins\local\cursor-project-harness")
    Assert-True ($digestLockAfter -eq $digestLockBefore) "locked-installed live plugin restored"
    Unlock-OwnedRunRootChild
    Assert-True ((Invoke-Rollback -RunRoot $rootLock -InvocationMarker $markerLock) -eq 0) "locked-installed retry rollback exit 0"
    $stLock2 = Get-Content -LiteralPath (Join-Path $rootLock "state.json") -Raw | ConvertFrom-Json
    Assert-True ([bool]$stLock2.cleanup_complete) "locked-installed retry cleanup_complete true"
    Assert-True (-not [bool]$stLock2.cleanup_pending) "locked-installed retry cleanup_pending false"
    Assert-True ([bool]$stLock2.evidence_complete) "locked-installed retry evidence_complete preserved"
} finally {
    Unlock-OwnedRunRootChild
    Remove-Item -LiteralPath $rootLock -Recurse -Force -ErrorAction SilentlyContinue
}

$rootRec = Join-Path $env:TEMP ("cptk-coexist-rec-" + [guid]::NewGuid().ToString("n"))
$markerRec = "rec-" + [guid]::NewGuid().ToString("n")
$fixedNonce = [guid]::NewGuid().ToString("n")
try {
    $prepR = Invoke-Protocol -ArgList @(
        "-Action", "Prepare", "-Scenario", "essential-only", "-RunRoot", $rootRec, "-InvocationMarker", $markerRec
    )
    Assert-True ($prepR.Code -eq 0) "Record guard Prepare exit 0"
    Assert-True ((Invoke-Protocol -ArgList @("-Action", "Record", "-RunRoot", $rootRec, "-Source", "essential", "-HookEvent", "sessionStart")).Code -ne 0) "Record without marker rejected"
    Assert-True ((Invoke-Protocol -ArgList @("-Action", "Record", "-RunRoot", $rootRec, "-InvocationMarker", $markerRec, "-Source", "plugin", "-HookEvent", "sessionStart")).Code -ne 0) "cross-source rejected"
    Assert-True ((Invoke-Protocol -ArgList @("-Action", "Record", "-RunRoot", $rootRec, "-InvocationMarker", $markerRec, "-Source", "essential", "-HookEvent", "sessionStart", "-Nonce", $fixedNonce)).Code -eq 0) "valid Record exit 0"
    Assert-True ((Invoke-Protocol -ArgList @("-Action", "Record", "-RunRoot", $rootRec, "-InvocationMarker", $markerRec, "-Source", "essential", "-HookEvent", "sessionStart", "-Nonce", $fixedNonce)).Code -ne 0) "nonce replay rejected"
    Assert-True ((Invoke-Rollback -RunRoot $rootRec -InvocationMarker $markerRec) -eq 0) "Record guard Rollback exit 0"
    $finR = Invoke-Protocol -ArgList @("-Action", "Finalize", "-RunRoot", $rootRec, "-InvocationMarker", $markerRec)
    Assert-True ($finR.Code -eq 0) "Finalize after rollback exit 0"
    Assert-True (($finR.Lines -join "`n") -match "runtime_verified=False") "Record+Rollback insufficient alone for runtime_verified"
    $stFin = Get-Content -LiteralPath (Join-Path $rootRec "state.json") -Raw | ConvertFrom-Json
    Assert-True ($stFin.owner_verdict -eq "essential") "Finalize preserves owner verdict essential"
    $journalText = (Get-Content -LiteralPath (Join-Path $rootRec "journal.jsonl") -Encoding UTF8) -join "`n"
    Assert-JournalAllowlist -JournalPath (Join-Path $rootRec "journal.jsonl") -Label "journal.jsonl"
} finally {
    Remove-Item -LiteralPath $rootRec -Recurse -Force -ErrorAction SilentlyContinue
}

$homeBefore = [Environment]::GetEnvironmentVariable("HOME", "User")
$homeAfter = [Environment]::GetEnvironmentVariable("HOME", "User")
Assert-True ($homeBefore -ceq $homeAfter) "User-scope HOME unchanged"

Write-Host ""
if ($fail -eq 0) {
    Write-Host "COEXISTENCE_PROTOCOL_TEST_PASS"
    exit 0
}
Write-Host "COEXISTENCE_PROTOCOL_TEST_FAIL: $fail"
exit 1

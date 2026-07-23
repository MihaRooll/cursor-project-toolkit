<#
.SYNOPSIS
  PS 5.1 ownership safety tests for smoke-bootstrap target paths.
#>
$ErrorActionPreference = "Stop"
$ToolkitRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$SmokeScript = Join-Path $ToolkitRoot "scripts\smoke-bootstrap.ps1"
$fail = 0

function Assert-True($cond, [string]$msg) {
    if ($cond) {
        Write-Host "OK  $msg"
    } else {
        Write-Host "FAIL $msg"
        $script:fail++
    }
}

function Invoke-SmokeProbe {
    param([string[]]$ArgList)
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $SmokeScript @ArgList 2>&1 | Out-Null
        return [int]$LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevEap
    }
}

Write-Host "=== test-smoke-target-safety ==="

# 1) Pre-existing sentinel hard-reject
$existingRoot = Join-Path $env:TEMP ("cptk-own-preexist-" + [guid]::NewGuid().ToString("n"))
$null = New-Item -ItemType Directory -Force -Path $existingRoot
$sentinelPath = Join-Path $existingRoot "SENTINEL.bin"
$sentinelBytes = [byte[]](1, 2, 3, 4, 5, 6, 7, 8, 9)
[System.IO.File]::WriteAllBytes($sentinelPath, $sentinelBytes)
$codePre = Invoke-SmokeProbe -ArgList @("-TargetPath", $existingRoot, "-OracleOnly")
Assert-True ($codePre -ne 0) "pre-existing target rejected"
$afterBytes = [System.IO.File]::ReadAllBytes($sentinelPath)
Assert-True ($afterBytes.Length -eq $sentinelBytes.Length) "pre-existing sentinel length unchanged"
for ($i = 0; $i -lt $sentinelBytes.Length; $i++) {
    if ($afterBytes[$i] -ne $sentinelBytes[$i]) {
        Assert-True $false "pre-existing sentinel byte $i unchanged"
        break
    }
}
Remove-Item -LiteralPath $existingRoot -Recurse -Force -ErrorAction SilentlyContinue

# 2) Junction / reparse hard-reject (victim untouched) — mandatory; junction create failure fails test
$junctionParent = Join-Path $env:TEMP ("cptk-own-junc-" + [guid]::NewGuid().ToString("n"))
$victimRoot = Join-Path $junctionParent "victim"
$junctionPath = Join-Path $junctionParent "link"
$null = New-Item -ItemType Directory -Force -Path $victimRoot
$victimSentinel = Join-Path $victimRoot "VICTIM.txt"
$victimBytes = [System.Text.Encoding]::ASCII.GetBytes("VICTIM_OK")
[System.IO.File]::WriteAllBytes($victimSentinel, $victimBytes)
$junctionCreated = $false
try {
    New-Item -ItemType Junction -Path $junctionPath -Target $victimRoot | Out-Null
    $junctionCreated = $true
} catch {
    Assert-True $false "junction creation required for ownership test: $($_.Exception.Message)"
}
if ($junctionCreated) {
    $codeJunc = Invoke-SmokeProbe -ArgList @("-TargetPath", $junctionPath, "-OracleOnly")
    Assert-True ($codeJunc -ne 0) "junction smoke root hard-rejected"
    $victimAfter = [System.IO.File]::ReadAllBytes($victimSentinel)
    Assert-True ($victimAfter.Length -eq $victimBytes.Length) "junction victim byte length unchanged"
    for ($i = 0; $i -lt $victimBytes.Length; $i++) {
        if ($victimAfter[$i] -ne $victimBytes[$i]) {
            Assert-True $false "junction victim byte $i unchanged"
            break
        }
    }
    $nestedTarget = Join-Path $junctionPath ("nested-" + [guid]::NewGuid().ToString("n"))
    $codeAncestor = Invoke-SmokeProbe -ArgList @("-TargetPath", $nestedTarget, "-OracleOnly")
    Assert-True ($codeAncestor -ne 0) "reparse ancestor hard-rejected for nested target"
    if (Test-Path -LiteralPath $junctionPath) {
        cmd /c "rmdir `"$junctionPath`"" 2>$null | Out-Null
    }
}
Remove-Item -LiteralPath $junctionParent -Recurse -Force -ErrorAction SilentlyContinue

# 3) Default temp cleanup on success probe
$codeCleanup = Invoke-SmokeProbe -ArgList @("-OwnershipTestMode", "CleanupProbe")
Assert-True ($codeCleanup -eq 0) "CleanupProbe exit 0"

# 4) KeepOnFailure retains owned dir on induced failure
$codeKeep = Invoke-SmokeProbe -ArgList @("-OwnershipTestMode", "KeepFailure", "-KeepOnFailure")
Assert-True ($codeKeep -eq 0) "KeepFailure probe exit 0"

# 5) Bracket-containing caller target — literal create/cleanup, no wildcard sibling effect
$bracketParent = Join-Path $env:TEMP ("cptk-own-bracket-" + [guid]::NewGuid().ToString("n"))
[void][System.IO.Directory]::CreateDirectory($bracketParent)
$wildcardSibling = Join-Path $bracketParent "cptk-smoke-A"
[void][System.IO.Directory]::CreateDirectory($wildcardSibling)
$siblingSentinel = Join-Path $wildcardSibling "SIBLING.txt"
$siblingBytes = [System.Text.Encoding]::ASCII.GetBytes("SIBLING_OK")
[System.IO.File]::WriteAllBytes($siblingSentinel, $siblingBytes)
$bracketTarget = Join-Path $bracketParent "cptk-smoke-[bracket]-test"
$codeBracket = Invoke-SmokeProbe -ArgList @("-TargetPath", $bracketTarget, "-OwnershipTestMode", "CleanupProbe")
Assert-True ($codeBracket -eq 0) "bracket path CleanupProbe exit 0"
Assert-True (-not (Test-Path -LiteralPath $bracketTarget)) "bracket target removed after CleanupProbe"
Assert-True (Test-Path -LiteralPath $wildcardSibling) "bracket wildcard sibling preserved"
$siblingAfter = [System.IO.File]::ReadAllBytes($siblingSentinel)
Assert-True ($siblingAfter.Length -eq $siblingBytes.Length) "bracket sibling sentinel length unchanged"
for ($i = 0; $i -lt $siblingBytes.Length; $i++) {
    if ($siblingAfter[$i] -ne $siblingBytes[$i]) {
        Assert-True $false "bracket sibling sentinel byte $i unchanged"
        break
    }
}
Remove-Item -LiteralPath $bracketParent -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
if ($fail -eq 0) {
    Write-Host "SMOKE_TARGET_SAFETY_PASS"
    exit 0
}
Write-Host "SMOKE_TARGET_SAFETY_FAIL: $fail"
exit 1

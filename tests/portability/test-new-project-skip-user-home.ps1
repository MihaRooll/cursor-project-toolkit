<#
.SYNOPSIS
  Greenfield new-project must not mutate User-scope HOME when -SkipUserHome is set,
  even if CPTK_PORTABILITY_SMOKE is absent from the child process environment.
#>
$ErrorActionPreference = "Stop"
$ToolkitRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$NewProjectPs1 = Join-Path $ToolkitRoot "scripts\new-project.ps1"
$fail = 0
$testOutput = New-Object System.Collections.Generic.List[string]

function Assert-True($cond, [string]$msg) {
    if ($cond) {
        Write-Host "OK  $msg"
        $script:testOutput.Add("OK  $msg")
    } else {
        Write-Host "FAIL $msg"
        $script:testOutput.Add("FAIL $msg")
        $script:fail++
    }
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

Write-Host "=== test-new-project-skip-user-home ==="
$testOutput.Add("=== test-new-project-skip-user-home ===")

$sampleExact = "__CPTK_HOME_SAMPLE_EXACT__"
$samplePadded = " __CPTK_HOME_SAMPLE_EXACT__"

Write-Host "--- canonical comparator cases ---"
$testOutput.Add("--- canonical comparator cases ---")
Assert-True (Test-UserHomeUnchangedCanonical $null "") "null vs empty canonical equal (unset)"
Assert-True (Test-UserHomeUnchangedCanonical "" $null) "empty vs null canonical equal (unset)"
Assert-True (-not (Test-UserHomeUnchangedCanonical $null " ")) "null vs space canonical differ (space is set)"
Assert-True (-not (Test-UserHomeUnchangedCanonical $null "`t")) "null vs tab canonical differ (tab is set)"
Assert-True (-not (Test-UserHomeUnchangedCanonical $sampleExact $samplePadded)) "nonpadded vs padded canonical differ"
Assert-True (Test-UserHomeUnchangedCanonical $sampleExact $sampleExact) "identical exact nonempty canonical equal"
Assert-True (-not ($null -eq "")) "raw null -eq empty is false (documents runner trap)"

$homeBefore = [Environment]::GetEnvironmentVariable("HOME", "User")
$parent = Join-Path $env:TEMP ("cptk-np-home-" + [guid]::NewGuid().ToString("n"))
$name = "home-isolation-test"
$target = Join-Path $parent $name
$savedCptk = $env:CPTK_PORTABILITY_SMOKE

try {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    Remove-Item Env:CPTK_PORTABILITY_SMOKE -ErrorAction SilentlyContinue

    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    Assert-True ($null -eq $env:CPTK_PORTABILITY_SMOKE) "CPTK_PORTABILITY_SMOKE absent before child spawn"
    $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $NewProjectPs1 `
        -Name $name -Parent $parent -Goal "home isolation" -SkipUserHome 2>&1 | ForEach-Object { [string]$_ })
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    $outputText = $output -join [Environment]::NewLine
    $expectedSkipLine = "Skip User-scope HOME (SkipUserHome or CPTK_PORTABILITY_SMOKE=1)"

    foreach ($line in $output) {
        Write-Host $line
        $testOutput.Add($line)
    }
    Assert-True ($code -eq 0) "new-project exit 0 with -SkipUserHome and no CPTK env"
    Assert-True ($outputText -match [regex]::Escape($expectedSkipLine)) `
        "bootstrap emitted exact Skip User-scope HOME evidence (switch forwarded)"
    Assert-True ($outputText -notmatch 'Set User HOME=') "bootstrap did not set User-scope HOME"

    $homeAfter = [Environment]::GetEnvironmentVariable("HOME", "User")
    if (-not (Test-UserHomeUnchangedCanonical $homeBefore $homeAfter)) {
        $beforeFp = Get-SafeHomeFingerprint $homeBefore
        $afterFp = Get-SafeHomeFingerprint $homeAfter
        Assert-True $false "User-scope HOME unchanged (before=$beforeFp after=$afterFp)"
    } else {
        Assert-True $true "User-scope HOME unchanged (before=$(Get-SafeHomeFingerprint $homeBefore))"
    }
} finally {
    if ($null -ne $savedCptk) {
        $env:CPTK_PORTABILITY_SMOKE = $savedCptk
    } else {
        Remove-Item Env:CPTK_PORTABILITY_SMOKE -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $target) {
        Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $parent) {
        Remove-Item -LiteralPath $parent -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$joinedOutput = $testOutput -join [Environment]::NewLine
Assert-True ($joinedOutput -notmatch [regex]::Escape($sampleExact)) "output contains no raw sample token"
Assert-True ($joinedOutput -notmatch [regex]::Escape($samplePadded)) "output contains no raw padded sample token"

Write-Host ""
if ($fail -eq 0) {
    Write-Host "NEW_PROJECT_SKIP_USER_HOME_PASS"
    exit 0
}
Write-Host "NEW_PROJECT_SKIP_USER_HOME_FAIL: $fail"
exit 1

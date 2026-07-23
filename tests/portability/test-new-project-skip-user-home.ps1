<#
.SYNOPSIS
  Greenfield new-project must not mutate User-scope HOME when -SkipUserHome is set,
  even if CPTK_PORTABILITY_SMOKE is absent from the child process environment.
#>
$ErrorActionPreference = "Stop"
$ToolkitRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$NewProjectPs1 = Join-Path $ToolkitRoot "scripts\new-project.ps1"
$fail = 0

function Assert-True($cond, [string]$msg) {
    if ($cond) {
        Write-Host "OK  $msg"
    } else {
        Write-Host "FAIL $msg"
        $script:fail++
    }
}

function Get-SafeHomeFingerprint([string]$Value) {
    if ($null -eq $Value) { return "null" }
    $t = [string]$Value
    if ($t.Length -eq 0) { return "empty" }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($t)
        $hash = ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join ""
        return "set sha256:$($hash.Substring(0, 16))"
    } finally {
        $sha.Dispose()
    }
}

Write-Host "=== test-new-project-skip-user-home ==="

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

    foreach ($line in $output) { Write-Host $line }
    Assert-True ($code -eq 0) "new-project exit 0 with -SkipUserHome and no CPTK env"
    Assert-True ($outputText -match [regex]::Escape($expectedSkipLine)) `
        "bootstrap emitted exact Skip User-scope HOME evidence (switch forwarded)"
    Assert-True ($outputText -notmatch 'Set User HOME=') "bootstrap did not set User-scope HOME"

    $homeAfter = [Environment]::GetEnvironmentVariable("HOME", "User")
    if ($homeAfter -ne $homeBefore) {
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

Write-Host ""
if ($fail -eq 0) {
    Write-Host "NEW_PROJECT_SKIP_USER_HOME_PASS"
    exit 0
}
Write-Host "NEW_PROJECT_SKIP_USER_HOME_FAIL: $fail"
exit 1

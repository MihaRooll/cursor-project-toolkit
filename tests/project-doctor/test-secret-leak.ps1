<#
.SYNOPSIS
  Selftest: project-doctor must not leak secret env values (names or values).
#>
param()

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$DoctorPath = Join-Path $Root "scripts\project-doctor.ps1"
$fail = 0
$leakValue = "FAKE_SECRET_VALUE_LEAK_TEST_" + [guid]::NewGuid().ToString("n")
$shortLeak = "xy"

function Assert-True($cond, [string]$msg) {
    if ($cond) { Write-Host "OK  $msg" } else { Write-Host "FAIL $msg"; $script:fail++ }
}

Write-Host "=== project-doctor secret leak selftest ==="

$env:FAKE_TEST_SECRET = $leakValue
$env:FAKE_SK_SHORT = $shortLeak
$env:CURSOR_SESSION_PROJECT_ROOT = $Root

try {
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $DoctorPath 2>&1 | Out-String
    $code = $LASTEXITCODE
    Write-Host "doctor exit: $code"
    Assert-True ($output -notmatch [regex]::Escape($leakValue)) "stdout/stderr does not contain secret value"
    Assert-True ($output -notmatch [regex]::Escape($shortLeak)) "stdout/stderr does not contain short secret value"
    Assert-True ($output -notmatch "FAKE_TEST_SECRET") "stdout does not enumerate secret var name"
    Assert-True ($output -notmatch "FAKE_SK_SHORT") "stdout does not enumerate sk- var name"
    Assert-True ($output -match "sensitive_vars=") "stdout reports sensitive var count"
    Assert-True ($output -match "curated summary") "stdout uses curated env summary"
} finally {
    Remove-Item Env:FAKE_TEST_SECRET -ErrorAction SilentlyContinue
    Remove-Item Env:FAKE_SK_SHORT -ErrorAction SilentlyContinue
    Remove-Item Env:CURSOR_SESSION_PROJECT_ROOT -ErrorAction SilentlyContinue
}

Write-Host ""
if ($fail -eq 0) {
    Write-Host "DOCTOR_LEAK_TEST_PASS"
    exit 0
}
Write-Host "DOCTOR_LEAK_TEST_FAIL: $fail"
exit 1

<#
.SYNOPSIS
  Selftest: project-doctor reports MISSING phase advisory when project-state lacks a phase marker.
#>
param()

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$DoctorPath = Join-Path $Root "scripts\project-doctor.ps1"
$fail = 0

function Assert-True($cond, [string]$msg) {
    if ($cond) { Write-Host "OK  $msg" } else { Write-Host "FAIL $msg"; $script:fail++ }
}

Write-Host "=== project-doctor missing phase advisory selftest ==="

$tempDir = Join-Path $env:TEMP ("cptk-doctor-nophase-" + [guid]::NewGuid().ToString("n"))
$docsDir = Join-Path $tempDir "docs"
New-Item -ItemType Directory -Force -Path $docsDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $tempDir ".cursor\hooks") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $tempDir ".cursor\skills\review-papercuts") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $tempDir ".cursor\rules") | Out-Null
Set-Content -LiteralPath (Join-Path $tempDir ".cursor\hooks\session-start.ps1") -Value "# stub" -Encoding UTF8
Set-Content -LiteralPath (Join-Path $tempDir ".cursor\skills\review-papercuts\SKILL.md") -Value "# stub" -Encoding UTF8
Set-Content -LiteralPath (Join-Path $tempDir ".cursor\rules\product-core.mdc") -Value "# stub" -Encoding UTF8
Set-Content -LiteralPath (Join-Path $docsDir "project-state.md") -Value @"
## next_checks
- [ ] add phase marker

## summary
No phase section on purpose.
"@ -Encoding UTF8

try {
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $DoctorPath -ProjectRoot $tempDir 2>&1 | Out-String
    $code = $LASTEXITCODE
    Write-Host "doctor exit: $code"
    Assert-True ($output -match "project-state: MISSING phase \(advisory\)") "doctor reports MISSING phase advisory"
    Assert-True ($code -eq 1) "doctor exit 1 for missing phase advisory"
} finally {
    Remove-Item -Recurse -Force -LiteralPath $tempDir -ErrorAction SilentlyContinue
}

Write-Host ""
if ($fail -eq 0) {
    Write-Host "DOCTOR_MISSING_PHASE_TEST_PASS"
    exit 0
}
Write-Host "DOCTOR_MISSING_PHASE_TEST_FAIL: $fail"
exit 1

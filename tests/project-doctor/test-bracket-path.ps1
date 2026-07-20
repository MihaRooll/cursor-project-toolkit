<#
.SYNOPSIS
  Selftest: project-doctor resolves bracket paths via -LiteralPath.
#>
param()

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$DoctorPath = Join-Path $Root "scripts\project-doctor.ps1"
$fail = 0

function Assert-True($cond, [string]$msg) {
    if ($cond) { Write-Host "OK  $msg" } else { Write-Host "FAIL $msg"; $script:fail++ }
}

Write-Host "=== project-doctor bracket path selftest ==="

$bracketDir = Join-Path $env:TEMP ("cptk-doctor-bracket-" + [guid]::NewGuid().ToString("n") + "[x]")
$docsDir = Join-Path $bracketDir "docs"
New-Item -ItemType Directory -Force -Path $docsDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $bracketDir ".cursor\hooks") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $bracketDir ".cursor\skills\review-papercuts") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $bracketDir ".cursor\rules") | Out-Null
Set-Content -LiteralPath (Join-Path $bracketDir ".cursor\hooks\session-start.ps1") -Value "# stub" -Encoding UTF8
Set-Content -LiteralPath (Join-Path $bracketDir ".cursor\skills\review-papercuts\SKILL.md") -Value "# stub" -Encoding UTF8
Set-Content -LiteralPath (Join-Path $bracketDir ".cursor\rules\product-core.mdc") -Value "# stub" -Encoding UTF8
Set-Content -LiteralPath (Join-Path $docsDir "project-state.md") -Value @"
## phase
bracket-path

## next_checks
- [ ] doctor resolves bracket cwd
"@ -Encoding UTF8

try {
    $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $DoctorPath -ProjectRoot $bracketDir 2>&1 | Out-String
    $code = $LASTEXITCODE
    Write-Host "doctor exit (explicit root): $code"
    Assert-True ($code -ne 2) "doctor does not hard-fail on bracket path (exit=$code)"
    Assert-True ($output -match "project-state: OK phase=bracket-path") "doctor reads state inside bracket path"
    Assert-True ($output -match [regex]::Escape("[x]")) "doctor root includes bracket segment"
} finally {
    Remove-Item -Recurse -Force -LiteralPath $bracketDir -ErrorAction SilentlyContinue
}

$defaultDir = Join-Path $env:TEMP ("cptk-doctor-default-" + [guid]::NewGuid().ToString("n") + "[d]")
$defaultScripts = Join-Path $defaultDir "scripts"
$defaultDocs = Join-Path $defaultDir "docs"
New-Item -ItemType Directory -Force -Path $defaultScripts | Out-Null
New-Item -ItemType Directory -Force -Path $defaultDocs | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $defaultDir ".cursor\hooks") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $defaultDir ".cursor\skills\review-papercuts") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $defaultDir ".cursor\rules") | Out-Null
Copy-Item -LiteralPath $DoctorPath -Destination (Join-Path $defaultScripts "project-doctor.ps1")
Set-Content -LiteralPath (Join-Path $defaultDir ".cursor\hooks\session-start.ps1") -Value "# stub" -Encoding UTF8
Set-Content -LiteralPath (Join-Path $defaultDir ".cursor\skills\review-papercuts\SKILL.md") -Value "# stub" -Encoding UTF8
Set-Content -LiteralPath (Join-Path $defaultDir ".cursor\rules\product-core.mdc") -Value "# stub" -Encoding UTF8
Set-Content -LiteralPath (Join-Path $defaultDocs "project-state.md") -Value @"
## phase
default-bracket-root

## next_checks
- [ ] doctor default root resolves bracket cwd
"@ -Encoding UTF8

try {
    $copiedDoctor = Join-Path $defaultScripts "project-doctor.ps1"
    $outputDefault = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $copiedDoctor 2>&1 | Out-String
    $codeDefault = $LASTEXITCODE
    Write-Host "doctor exit (default root): $codeDefault"
    Assert-True ($codeDefault -ne 2) "default-root doctor does not hard-fail on bracket path (exit=$codeDefault)"
    Assert-True ($outputDefault -match "project-state: OK phase=default-bracket-root") "default root reads state inside bracket project"
    Assert-True ($outputDefault -match [regex]::Escape("[d]")) "default root resolves bracket project from script location"
} finally {
    Remove-Item -Recurse -Force -LiteralPath $defaultDir -ErrorAction SilentlyContinue
}

Write-Host ""
if ($fail -eq 0) {
    Write-Host "DOCTOR_BRACKET_TEST_PASS"
    exit 0
}
Write-Host "DOCTOR_BRACKET_TEST_FAIL: $fail"
exit 1

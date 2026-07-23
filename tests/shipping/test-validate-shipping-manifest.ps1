<#
.SYNOPSIS
  Deterministic tests for shadow shipping manifest validator.
#>
$ErrorActionPreference = "Stop"
$ToolkitRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Validator = Join-Path $ToolkitRoot "scripts\validate-shipping-manifest.ps1"
$SchemaPath = Join-Path $PSScriptRoot "shipping-manifest.schema.json"
$fail = 0

function Assert-True($cond, [string]$msg) {
    if ($cond) { Write-Host "OK  $msg" } else { Write-Host "FAIL $msg"; $script:fail++ }
}

Write-Host "=== test-validate-shipping-manifest ==="
Assert-True (Test-Path -LiteralPath $SchemaPath) "schema exists"
Assert-True (Test-Path -LiteralPath (Join-Path $ToolkitRoot "shipping\manifest.v1.json")) "live manifest exists"
Assert-True (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot "fixtures"))) "no repo fixture dir"

$self = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Validator -SelfTest 2>&1
foreach ($l in $self) { Write-Host $l }
Assert-True ($LASTEXITCODE -eq 0) "validator SelfTest exit 0"

$liveRun = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Validator 2>&1
foreach ($l in $liveRun) { Write-Host $l }
Assert-True ($LASTEXITCODE -eq 0) "validator live exit 0"

Write-Host ""
if ($fail -eq 0) {
    Write-Host "SHIPPING_MANIFEST_TEST_PASS"
    exit 0
}
Write-Host "SHIPPING_MANIFEST_TEST_FAIL: $fail"
exit 1

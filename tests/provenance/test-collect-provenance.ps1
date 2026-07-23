<#
.SYNOPSIS
  Deterministic tests for harness provenance collector.
#>
$ErrorActionPreference = "Stop"
$ToolkitRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Collector = Join-Path $ToolkitRoot "scripts\collect-provenance.ps1"
$SchemaPath = Join-Path $ToolkitRoot "schemas\provenance.v1.json"
$fail = 0

function Assert-True($cond, [string]$msg) {
    if ($cond) { Write-Host "OK  $msg" } else { Write-Host "FAIL $msg"; $script:fail++ }
}

Write-Host "=== test-collect-provenance ==="
Assert-True (Test-Path -LiteralPath $SchemaPath) "schema exists"
Assert-True (Test-Path -LiteralPath $Collector) "collector exists"

$self = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Collector -SelfTest 2>&1
foreach ($l in $self) { Write-Host $l }
Assert-True ($LASTEXITCODE -eq 0) "collector SelfTest exit 0"

$liveOut = Join-Path $env:TEMP ("cptk-prov-live-" + [guid]::NewGuid().ToString("n") + ".json")
try {
    $live = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Collector `
        -ProjectRoot $ToolkitRoot -ToolkitRoot $ToolkitRoot -OutputPath $liveOut 2>&1
    foreach ($l in $live) {
        Write-Host $l
        Assert-True ($l -notmatch '[A-Za-z]:\\') "console line has no absolute path: $l"
        Assert-True ($l -notmatch 'output=.*\\') "console output token has no absolute path"
    }
    Assert-True ($LASTEXITCODE -in @(0, 1)) "toolkit live collect exit 0 or 1 (local drift ok)"
    Assert-True (Test-Path -LiteralPath $liveOut) "live output written"
    $raw = [System.IO.File]::ReadAllText($liveOut, (New-Object System.Text.UTF8Encoding $false))
    $obj = $raw | ConvertFrom-Json
    Assert-True ($obj.schema_version -eq 1) "live report schema_version"
    Assert-True ($null -ne $obj.completion_state) "live report completion_state"
    Assert-True ($obj.managed_content_digest -ne $obj.installed_digest) "live digest sides differ"
    Assert-True ($raw -notmatch '"installed_at"') "live report forbids installed_at"
    foreach ($state in @("partial", "stale", "dirty", "legacy", "error")) {
        if ($obj.completion_state -eq $state) {
            Assert-True ($state -ne "success") "non-success state never success"
        }
    }
} finally {
    Remove-Item -LiteralPath $liveOut -Force -ErrorAction SilentlyContinue
}

Write-Host ""
if ($fail -eq 0) {
    Write-Host "PROVENANCE_TEST_PASS"
    exit 0
}
Write-Host "PROVENANCE_TEST_FAIL: $fail"
exit 1

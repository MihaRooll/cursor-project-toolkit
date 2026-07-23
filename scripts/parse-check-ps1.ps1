# Parse all tracked toolkit *.ps1 with Windows PowerShell AST (catches encoding/em-dash breaks).
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$fail = 0

$tracked = @()
Push-Location -LiteralPath $root
try {
    $raw = git ls-files -- "*.ps1" 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($raw)) {
        throw "git ls-files *.ps1 failed or returned empty (is this a git checkout?)"
    }
    $tracked = @($raw -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
} finally {
    Pop-Location
}

if ($tracked.Count -eq 0) {
    Write-Host "PARSE_ERR no tracked *.ps1 files"
    exit 1
}

foreach ($rel in $tracked) {
    $f = Join-Path $root ($rel -replace '/', '\')
    if (-not (Test-Path -LiteralPath $f)) {
        Write-Host "PARSE_ERR missing tracked file: $rel"
        $fail++
        continue
    }
    $tokens = $null
    $errs = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$tokens, [ref]$errs)
    if ($errs -and $errs.Count) {
        Write-Host "PARSE_ERR $f"
        $errs | ForEach-Object { Write-Host "  $_" }
        $fail++
    } else {
        Write-Host "PARSE_OK $rel"
    }
}

if ($fail) { exit 1 } else { Write-Host "ALL_OK ($($tracked.Count) tracked ps1)"; exit 0 }

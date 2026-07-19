# Parse all toolkit .ps1 with Windows PowerShell AST (catches encoding/em-dash breaks).
$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$fail = 0
$files = @()
$files += Get-ChildItem (Join-Path $root "scripts\*.ps1")
$files += Get-ChildItem (Join-Path $root ".cursor\hooks\*.ps1")
foreach ($f in $files) {
    $tokens = $null
    $errs = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errs)
    if ($errs -and $errs.Count) {
        Write-Host "PARSE_ERR $($f.FullName)"
        $errs | ForEach-Object { Write-Host "  $_" }
        $fail++
    } else {
        Write-Host "PARSE_OK $($f.Name)"
    }
}
if ($fail) { exit 1 } else { Write-Host "ALL_OK"; exit 0 }

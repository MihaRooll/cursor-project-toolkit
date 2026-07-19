$ErrorActionPreference = "Stop"
$env:Path = "$env:USERPROFILE\.cargo\bin;$env:Path"
$env:HOME = $env:USERPROFILE
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$p = Join-Path $root ".papercuts.jsonl"

# Fresh log via official CLI (UTF-8, valid contract)
if (Test-Path $p) { Remove-Item $p -Force }

Set-Location $root
papercuts add "Windows: papercuts needs HOME=USERPROFILE or --file; run from git repo root" --tag tooling --severity minor
papercuts doctor
papercuts list --format md

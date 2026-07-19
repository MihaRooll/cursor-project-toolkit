$ErrorActionPreference = "Stop"
$env:Path = "$env:USERPROFILE\.cargo\bin;$env:Path"
$env:HOME = $env:USERPROFILE
Set-Location (Join-Path $PSScriptRoot "..")

# Close smoke-test / mojibake / obsolete shim entries
papercuts resolve pc_6b0d89063b47 pc_7ad0652489f5 pc_78dc7237958c

# Keep one real footgun note for the team
papercuts add "Windows: papercuts fails with cannot resolve home directory unless HOME is set (use USERPROFILE) or --file; run from git repo root" --tag tooling --severity minor

papercuts list --format md
papercuts doctor

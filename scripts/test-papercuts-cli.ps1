$ErrorActionPreference = "Stop"
$env:Path = "$env:USERPROFILE\.cargo\bin;$env:Path"
$env:HOME = $env:USERPROFILE
Set-Location (Join-Path $PSScriptRoot "..")
papercuts add "проверка из репо toolkit" --tag toolkit
papercuts list --format md

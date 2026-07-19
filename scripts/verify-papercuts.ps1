$env:Path = "$env:USERPROFILE\.cargo\bin;$env:Path"
$env:HOME = $env:USERPROFILE
Set-Location (Join-Path $PSScriptRoot "..")
papercuts doctor
papercuts list --format md

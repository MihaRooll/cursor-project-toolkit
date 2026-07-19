# Ensure Windows HOME for papercuts; inject short harness reminder.
$ErrorActionPreference = "SilentlyContinue"
$inputJson = [Console]::In.ReadToEnd()

if (-not $env:HOME -and $env:USERPROFILE) {
    $env:HOME = $env:USERPROFILE
}

$additional = @(
    "Harness: AI-first docs in docs/; live rules/skills in .cursor/.",
    "Papercuts: failed shells auto-log when possible; or papercuts add `"...`" --tag tooling.",
    "Windows: HOME should equal USERPROFILE for papercuts outside quirks."
) -join " "

@{ additional_context = $additional } | ConvertTo-Json -Compress
exit 0

# beforeShellExecution hook template (Full/opt-in only). Reads stdin JSON; stdout ONLY permission JSON; exit 0 always.
# Official stdin fields: command (string), cwd (string), sandbox (boolean) + optional common fields.
# Deny regex on .command: (?i)(rm\s+-rf\s+/|git\s+push\s+--force|format\s+[A-Z]:)
param()

$ErrorActionPreference = "SilentlyContinue"

function Read-HookStdin {
    # PS 5.1 cross-host: Console.In receives piped/redirected stdin for -File hooks in most hosts.
    # OpenStandardInput fallback when Console.In is empty (e.g. some CI redirect spawns).
    $fromConsole = ""
    try { $fromConsole = [Console]::In.ReadToEnd() } catch { }
    if (-not [string]::IsNullOrWhiteSpace($fromConsole)) { return $fromConsole }
    try {
        $reader = New-Object System.IO.StreamReader([Console]::OpenStandardInput())
        $fromStdin = $reader.ReadToEnd()
        $reader.Dispose()
        if (-not [string]::IsNullOrWhiteSpace($fromStdin)) { return $fromStdin }
    } catch { }
    return ""
}

function Write-Deny([string]$UserMsg, [string]$AgentMsg) {
    $obj = @{
        permission   = "deny"
        user_message = $UserMsg
        agent_message = $AgentMsg
    }
    Write-Output ($obj | ConvertTo-Json -Compress)
    exit 0
}

function Write-Allow {
    $obj = @{ permission = "allow" }
    Write-Output ($obj | ConvertTo-Json -Compress)
    exit 0
}

$raw = Read-HookStdin
if ([string]::IsNullOrWhiteSpace($raw)) {
    Write-Deny "Shell hook rejected: empty input." "Missing stdin JSON for beforeShellExecution."
}

try {
    $payload = $raw | ConvertFrom-Json
} catch {
    Write-Deny "Shell hook rejected: invalid JSON." "beforeShellExecution stdin is not valid JSON."
}

if ($null -eq $payload.command -or $payload.command -isnot [string]) {
    Write-Deny "Shell hook rejected: missing command." "beforeShellExecution requires command:string."
}

if ($null -eq $payload.cwd -or $payload.cwd -isnot [string]) {
    Write-Deny "Shell hook rejected: missing cwd." "beforeShellExecution requires cwd:string."
}

$sandboxVal = $payload.sandbox
if ($null -eq $sandboxVal -or ($sandboxVal -isnot [bool] -and $sandboxVal -isnot [System.Management.Automation.SwitchParameter])) {
    $sandboxStr = [string]$sandboxVal
    if ($sandboxStr -eq "True" -or $sandboxStr -eq "False") {
        $sandboxVal = [bool]::Parse($sandboxStr)
    } else {
        Write-Deny "Shell hook rejected: invalid sandbox." "beforeShellExecution requires sandbox:boolean."
    }
}

$cmd = [string]$payload.command
$denyPattern = '(?i)(rm\s+-rf\s+/|git\s+push\s+--force|format\s+[A-Z]:)'
if ($cmd -match $denyPattern) {
    Write-Deny "Blocked dangerous shell command." "Command matched deny pattern: $cmd"
}

Write-Allow

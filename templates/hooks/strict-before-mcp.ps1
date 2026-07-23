# beforeMCPExecution hook template (Full/opt-in only). Reads stdin JSON; stdout ONLY permission JSON; exit 0 always.
# Official stdin: tool_name (string), tool_input (string JSON params), exactly ONE of url (string) OR command (string).
# NO server/server_name fields.
# Deny tool_name / tool_input / url / command matching destructive, injection, or production patterns.
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
        permission    = "deny"
        user_message  = $UserMsg
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

function Test-DestructiveToolName([string]$ToolName) {
    if ([string]::IsNullOrEmpty($ToolName)) { return $false }
    if ($ToolName -match '(?i)(^|[_-])(delete|drop|destroy|force[-_]?push|rm|rmdir)($|[_-])') { return $true }
    return $false
}

$DestructiveVerbKeys = @('action', 'command', 'operation', 'method', 'verb')
$DestructiveValuePattern = '(?i)\b(delete|drop|destroy|force[-_]?push)\b'
$DestructiveRmPattern = '(?i)\brm\b\s+-'

function Test-DestructiveInNode($Node) {
    if ($null -eq $Node) { return $false }
    if ($Node -is [string]) { return $false }
    if ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [string])) {
        foreach ($item in @($Node)) {
            if (Test-DestructiveInNode $item) { return $true }
        }
        return $false
    }
    if ($Node.PSObject -and $Node.PSObject.Properties) {
        foreach ($prop in $Node.PSObject.Properties) {
            $key = [string]$prop.Name
            $val = $prop.Value
            if ($DestructiveVerbKeys -contains $key.ToLowerInvariant()) {
                $strVal = [string]$val
                if ($strVal -match $DestructiveValuePattern) { return $true }
                if ($strVal -match $DestructiveRmPattern) { return $true }
                if ($strVal -match '(?i)\brm\s+-rf\b') { return $true }
            }
            if ($val -is [string]) { continue }
            if (Test-DestructiveInNode $val) { return $true }
        }
    }
    return $false
}

function Test-DestructiveInToolInput([string]$ToolInputJson) {
    if ([string]::IsNullOrEmpty($ToolInputJson)) { return $false }
    $obj = $null
    try {
        $obj = $ToolInputJson | ConvertFrom-Json
    } catch {
        return $false
    }
    return (Test-DestructiveInNode $obj)
}

function Normalize-InjectionText([string]$Text) {
    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    return ($Text -replace '[_\-\s]+', ' ')
}

function Test-LooksLikePathOrFilename([string]$Text) {
    if ([string]::IsNullOrEmpty($Text)) { return $false }
    if ($Text -match '[/\\]') { return $true }
    if ($Text -match '(?i)\.(md|json|txt|yaml|yml|toml|xml|csv|ps1|sh|bat|cmd)(?=["''\s}]|$)') { return $true }
    return $false
}

function Test-IsPurePathOrFilenameLeaf([string]$Text) {
    if ([string]::IsNullOrEmpty($Text)) { return $false }
    if ($Text -match '\s') { return $false }
    return (Test-LooksLikePathOrFilename $Text)
}

function Test-InjectionPhrasesInStringLeaf([string]$Text) {
    if ([string]::IsNullOrEmpty($Text)) { return $false }
    if (Test-IsPurePathOrFilenameLeaf $Text) { return $false }
    $normalized = Normalize-InjectionText $Text
    if ($normalized -match '(?i)\bignore previous instructions\b') { return $true }
    if ($normalized -match '(?i)\bsystem prompt\b') { return $true }
    return $false
}

function Test-InjectionKeyName([string]$KeyName) {
    if ([string]::IsNullOrEmpty($KeyName)) { return $false }
    if ($KeyName -match '(?i)^ignore[_\-\s]previous[_\-\s]instructions$') { return $true }
    if ($KeyName -match '(?i)^system_prompt$') { return $true }
    return $false
}

function Test-InjectionPhrasesInJsonNode($Node) {
    if ($null -eq $Node) { return $false }
    if ($Node -is [string]) {
        return (Test-InjectionPhrasesInStringLeaf ([string]$Node))
    }
    if ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [string])) {
        foreach ($item in @($Node)) {
            if (Test-InjectionPhrasesInJsonNode $item) { return $true }
        }
        return $false
    }
    if ($Node.PSObject -and $Node.PSObject.Properties) {
        foreach ($prop in $Node.PSObject.Properties) {
            $key = [string]$prop.Name
            if (Test-InjectionKeyName $key) { return $true }
            if (Test-InjectionPhrasesInJsonNode $prop.Value) { return $true }
        }
    }
    return $false
}

function Test-InjectionPhrasesInText([string]$Text) {
    if ([string]::IsNullOrEmpty($Text)) { return $false }
    if ($Text -match '(?i)"ignore[_\-\s]previous[_\-\s]instructions"\s*:') { return $true }
    if ($Text -match '(?i)"system_prompt"\s*:') { return $true }
    $obj = $null
    try {
        $obj = $Text | ConvertFrom-Json
    } catch {
        return (Test-InjectionPhrasesInStringLeaf $Text)
    }
    return (Test-InjectionPhrasesInJsonNode $obj)
}

function Test-InjectionOrProd([string]$Text) {
    if ([string]::IsNullOrEmpty($Text)) { return $false }
    if (Test-InjectionPhrasesInText $Text) { return $true }
    $normalized = Normalize-InjectionText $Text
    if ($normalized -match '(?i)(?<!(?:file ))SYSTEM\s*:') { return $true }
    $patterns = @(
        '(?i)\[SYSTEM\]',
        '(?i)disregard\s+(all\s+)?prior\s+instructions',
        '(?i)api\.production\.',
        '(?i)/prod/',
        '(?i)"environment"\s*:\s*"production"',
        '(?i)"force"\s*:\s*true',
        '(?i)"drop"\s*:\s*true',
        '(?i)kubectl\s+apply',
        '(?i)terraform\s+apply',
        '(?i)npm\s+publish'
    )
    foreach ($pat in $patterns) {
        if ($Text -match $pat) { return $true }
    }
    return $false
}

$raw = Read-HookStdin
if ([string]::IsNullOrWhiteSpace($raw)) {
    Write-Deny "MCP hook rejected: empty input." "Missing stdin JSON for beforeMCPExecution."
}

try {
    $payload = $raw | ConvertFrom-Json
} catch {
    Write-Deny "MCP hook rejected: invalid JSON." "beforeMCPExecution stdin is not valid JSON."
}

if ($null -eq $payload.tool_name -or $payload.tool_name -isnot [string]) {
    Write-Deny "MCP hook rejected: missing tool_name." "beforeMCPExecution requires tool_name:string."
}

if ($null -eq $payload.tool_input -or $payload.tool_input -isnot [string]) {
    Write-Deny "MCP hook rejected: missing tool_input." "beforeMCPExecution requires tool_input:string."
}

$hasUrl = ($null -ne $payload.url -and $payload.url -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$payload.url))
$hasCmd = ($null -ne $payload.command -and $payload.command -is [string] -and -not [string]::IsNullOrWhiteSpace([string]$payload.command))

if (-not $hasUrl -and -not $hasCmd) {
    Write-Deny "MCP hook rejected: missing transport." "beforeMCPExecution requires exactly one of url or command."
}

if ($hasUrl -and $hasCmd) {
    Write-Deny "MCP hook rejected: ambiguous transport." "beforeMCPExecution allows url OR command, not both."
}

try {
    $null = $payload.tool_input | ConvertFrom-Json
} catch {
    Write-Deny "MCP hook rejected: invalid tool_input JSON." "tool_input must be a JSON string."
}

$toolName = [string]$payload.tool_name
if (Test-DestructiveToolName $toolName) {
    Write-Deny "Blocked dangerous MCP tool." "tool_name matched destructive pattern: $toolName"
}

$toolInput = [string]$payload.tool_input
if (Test-DestructiveInToolInput $toolInput) {
    Write-Deny "Blocked dangerous MCP input." "tool_input action/command matched destructive pattern."
}
if (Test-InjectionOrProd $toolInput) {
    Write-Deny "Blocked prompt injection or production MCP input." "tool_input matched deny pattern."
}

if ($hasUrl) {
    $url = [string]$payload.url
    if (Test-InjectionOrProd $url) {
        Write-Deny "Blocked production MCP URL." "url matched deny pattern."
    }
}

if ($hasCmd) {
    $mcpCmd = [string]$payload.command
    if (Test-InjectionOrProd $mcpCmd) {
        Write-Deny "Blocked production MCP command." "command matched deny pattern."
    }
}

Write-Allow

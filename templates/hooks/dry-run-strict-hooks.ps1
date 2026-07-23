<#
.SYNOPSIS
  V-11 dry-run: strict hook templates allow/deny/malformed; exit 0; stdout JSON only per hook.
#>
param()

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ShellHook = Join-Path $Root "strict-before-shell.ps1"
$McpHook = Join-Path $Root "strict-before-mcp.ps1"
$fail = 0

function Assert-True($cond, [string]$msg) {
    if ($cond) { Write-Host "OK  $msg" } else { Write-Host "FAIL $msg"; $script:fail++ }
}

function Get-BoundedDenyReason($Parsed) {
    if ($null -eq $Parsed) { return "no-json" }
    $msg = [string]$Parsed.agent_message
    if ([string]::IsNullOrWhiteSpace($msg)) { $msg = [string]$Parsed.user_message }
    if ([string]::IsNullOrWhiteSpace($msg)) { return "deny-no-message" }
    if ($msg.Length -gt 120) { return $msg.Substring(0, 117) + "..." }
    return $msg
}

function Invoke-HookJson {
    param(
        [string]$HookPath,
        [string]$StdinJson
    )
    $stdinFile = Join-Path $env:TEMP ("cptk-dry-hook-" + [guid]::NewGuid().ToString("n") + ".json")
    $stderrFile = Join-Path $env:TEMP ("cptk-dry-hook-err-" + [guid]::NewGuid().ToString("n") + ".txt")
    [System.IO.File]::WriteAllText($stdinFile, $StdinJson, (New-Object System.Text.UTF8Encoding $false))
    try {
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $stdout = Get-Content -LiteralPath $stdinFile -Raw -Encoding UTF8 | & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $HookPath 2>$stderrFile
        $code = $LASTEXITCODE
        $ErrorActionPreference = $prevEap
        $stderr = ""
        if (Test-Path -LiteralPath $stderrFile) {
            $stderr = [string](Get-Content -LiteralPath $stderrFile -Raw -Encoding UTF8)
            if ($null -ne $stderr) { $stderr = $stderr.Trim() }
        }
        return @{
            stdout = [string]$stdout.Trim()
            stderr = $stderr
            exitCode = [int]$code
        }
    } finally {
        Remove-Item -LiteralPath $stdinFile -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $stderrFile -Force -ErrorAction SilentlyContinue
    }
}

function Test-HookCase {
    param(
        [string]$Label,
        [string]$HookPath,
        [string]$StdinJson,
        [string]$ExpectPermission
    )
    $r = Invoke-HookJson -HookPath $HookPath -StdinJson $StdinJson
    Assert-True ($r.exitCode -eq 0) "$Label exit 0"
    Assert-True ([string]::IsNullOrEmpty($r.stderr)) "$Label no stderr"
    $parsed = $null
    try { $parsed = $r.stdout | ConvertFrom-Json } catch { $parsed = $null }
    Assert-True ($null -ne $parsed) "$Label stdout ConvertFrom-Json"
    if ($null -ne $parsed) {
        $got = [string]$parsed.permission
        $detail = ""
        if ($got -ne $ExpectPermission -and $got -eq "deny") {
            $detail = "; reason=$(Get-BoundedDenyReason $parsed)"
        }
        Assert-True ($got -eq $ExpectPermission) "$Label permission=$ExpectPermission (got=$got$detail)"
    }
    if (-not [string]::IsNullOrEmpty($r.stdout)) {
        $lines = @($r.stdout -split "`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        Assert-True ($lines.Count -eq 1) "$Label single stdout line"
    }
}

Write-Host "=== V-11 strict hook dry-run ==="

Test-HookCase -Label "shell-allow" -HookPath $ShellHook -StdinJson '{"command":"echo hi","cwd":"C:\\tmp","sandbox":true}' -ExpectPermission "allow"
Test-HookCase -Label "shell-deny" -HookPath $ShellHook -StdinJson '{"command":"git push --force","cwd":"C:\\tmp","sandbox":true}' -ExpectPermission "deny"
Test-HookCase -Label "shell-malformed" -HookPath $ShellHook -StdinJson '{"cwd":"C:\\tmp","sandbox":true}' -ExpectPermission "deny"

Test-HookCase -Label "mcp-allow" -HookPath $McpHook -StdinJson '{"tool_name":"search","tool_input":"{\"q\":\"docs\"}","url":"https://api.example.com/v1/search"}' -ExpectPermission "allow"
Test-HookCase -Label "mcp-deny-tool" -HookPath $McpHook -StdinJson '{"tool_name":"delete_repo","tool_input":"{}","url":"https://api.example.com"}' -ExpectPermission "deny"
Test-HookCase -Label "mcp-malformed-json" -HookPath $McpHook -StdinJson '{"tool_name":"search","tool_input":"not-json","url":"https://api.example.com"}' -ExpectPermission "deny"
Test-HookCase -Label "mcp-malformed-no-transport" -HookPath $McpHook -StdinJson '{"tool_name":"search","tool_input":"{}"}' -ExpectPermission "deny"
Test-HookCase -Label "mcp-malformed-both-transport" -HookPath $McpHook -StdinJson '{"tool_name":"search","tool_input":"{}","url":"https://a","command":"npx mcp"}' -ExpectPermission "deny"

Write-Host ""
if ($fail -eq 0) {
    Write-Host "STRICT_HOOK_DRYRUN_PASS"
    exit 0
}
Write-Host "STRICT_HOOK_DRYRUN_FAIL: $fail"
exit 1

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

function Invoke-HookJson {
    param(
        [string]$HookPath,
        [string]$StdinJson
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$HookPath`""
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()
    $p.StandardInput.Write($StdinJson)
    $p.StandardInput.Close()
    [void]$p.WaitForExit(15000)
    $stdout = $p.StandardOutput.ReadToEnd().Trim()
    $stderr = $p.StandardError.ReadToEnd().Trim()
    $code = $p.ExitCode
    $p.Dispose()
    return @{ stdout = $stdout; stderr = $stderr; exitCode = $code }
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
        Assert-True ($parsed.permission -eq $ExpectPermission) "$Label permission=$ExpectPermission"
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

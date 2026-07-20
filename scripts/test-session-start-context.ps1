<#
.SYNOPSIS
  Behavioral selftest for session-start doctor injection (V-SESSION).
#>
param()

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$HookPath = Join-Path $Root ".cursor\hooks\session-start.ps1"
$PluginHookPath = Join-Path $Root "plugin\cursor-project-harness\scripts\session-start.ps1"
$fail = 0

function Assert-True($cond, [string]$msg) {
    if ($cond) { Write-Host "OK  $msg" } else { Write-Host "FAIL $msg"; $script:fail++ }
}

function Stop-ProcessTree {
    param([int]$ProcessId)
    if ($ProcessId -le 0) { return }
    try {
        & taskkill.exe /T /F /PID $ProcessId 2>$null | Out-Null
    } catch { }
    try {
        $p = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
        if ($p -and -not $p.HasExited) { $p.Kill() | Out-Null }
    } catch { }
}

function Test-NoDoctorProcesses {
    param(
        [string]$DoctorPath,
        [int]$TimeoutMs = 2000
    )
    $escaped = [regex]::Escape($DoctorPath)
    $job = Start-Job -ScriptBlock {
        param($EscPath)
        try {
            $procs = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue
            foreach ($proc in $procs) {
                if ($proc.CommandLine -and $proc.CommandLine -match $EscPath) {
                    return $false
                }
            }
        } catch { }
        return $true
    } -ArgumentList $escaped
    $completed = Wait-Job -Job $job -Timeout ($TimeoutMs / 1000.0)
    if (-not $completed) {
        Stop-Job -Job $job -ErrorAction SilentlyContinue
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        return $false
    }
    $result = Receive-Job -Job $job
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    return [bool]$result
}

function Invoke-SessionHook {
    param(
        [string]$HookScript,
        [string]$TempRoot = "",
        [string]$DoctorPath = "",
        [string]$CursorProjectDir = "",
        [int]$TimeoutMs = 6000
    )
    $savedRoot = [Environment]::GetEnvironmentVariable("CURSOR_SESSION_PROJECT_ROOT", "Process")
    $savedDoctor = [Environment]::GetEnvironmentVariable("CURSOR_SESSION_DOCTOR_PATH", "Process")
    $savedProjectDir = [Environment]::GetEnvironmentVariable("CURSOR_PROJECT_DIR", "Process")
    if ($TempRoot) { $env:CURSOR_SESSION_PROJECT_ROOT = $TempRoot }
    if ($DoctorPath) { $env:CURSOR_SESSION_DOCTOR_PATH = $DoctorPath }
    if ($CursorProjectDir) { $env:CURSOR_PROJECT_DIR = $CursorProjectDir }
    else { Remove-Item Env:CURSOR_PROJECT_DIR -ErrorAction SilentlyContinue }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $stdout = ""
    $stderr = ""
    $code = 0
    $p = $null
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$HookScript`""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $psi
        [void]$p.Start()
        if (-not $p.WaitForExit($TimeoutMs)) {
            Stop-ProcessTree -ProcessId $p.Id
            [void]$p.WaitForExit(500)
            $stdout = "HOOK_WATCHDOG_TIMEOUT"
            $code = 1
        } elseif ($p.HasExited) {
            $stdout = $p.StandardOutput.ReadToEnd()
            $stderr = $p.StandardError.ReadToEnd()
            $code = $p.ExitCode
        }
    } catch {
        $stdout = [string]$_.Exception.Message
        $code = 1
    } finally {
        if ($null -ne $p -and -not $p.HasExited) {
            Stop-ProcessTree -ProcessId $p.Id
            [void]$p.WaitForExit(500)
        }
        if ($null -ne $p) {
            try { $p.Dispose() } catch { }
        }
        if ($null -eq $savedRoot) { Remove-Item Env:CURSOR_SESSION_PROJECT_ROOT -ErrorAction SilentlyContinue }
        else { $env:CURSOR_SESSION_PROJECT_ROOT = $savedRoot }
        if ($null -eq $savedDoctor) { Remove-Item Env:CURSOR_SESSION_DOCTOR_PATH -ErrorAction SilentlyContinue }
        else { $env:CURSOR_SESSION_DOCTOR_PATH = $savedDoctor }
        if ($null -eq $savedProjectDir) { Remove-Item Env:CURSOR_PROJECT_DIR -ErrorAction SilentlyContinue }
        else { $env:CURSOR_PROJECT_DIR = $savedProjectDir }
    }
    $sw.Stop()
    return @{
        stdout = $stdout.Trim()
        stderr = $stderr.Trim()
        exitCode = $code
        elapsedMs = $sw.ElapsedMilliseconds
    }
}

function New-FakeDoctor {
    param(
        [string]$Dir,
        [string]$Name,
        [string]$Body
    )
    $path = Join-Path $Dir "$Name.ps1"
    Set-Content -LiteralPath $path -Value $Body -Encoding UTF8
    return $path
}

Write-Host "=== V-SESSION session-start context ==="

$cases = @(
    @{
        id = "success"
        doctor = @'
$ErrorActionPreference = "Continue"
Write-Output "doctor: OK summary"
exit 0
'@
    },
    @{
        id = "nonzero"
        doctor = @'
$ErrorActionPreference = "Continue"
Write-Error "doctor failed"
exit 2
'@
    },
    @{
        id = "throw"
        doctor = @'
$ErrorActionPreference = "Stop"
throw "doctor terminating error"
'@
    },
    @{
        id = "hang"
        doctor = @'
Start-Sleep -Seconds 10
Write-Output "doctor: should not finish"
exit 0
'@
    },
    @{
        id = "malformed"
        doctor = @'
$ErrorActionPreference = "Continue"
[Console]::Out.Write([char]0)
Write-Output "unpaired {{ junk"
Write-Output ([string][char[]]@(0,1,2,255))
exit 0
'@
    },
    @{
        id = "oversized"
        doctor = @'
Write-Output ("X" * 6000)
exit 0
'@
    },
    @{
        id = "console_corrupt"
        doctor = @'
[Console]::Out.Write("CORRUPT")
Write-Output "doctor: OK"
exit 0
'@
    }
)

foreach ($case in $cases) {
    $temp = Join-Path $env:TEMP ("cptk-vsession-" + $case.id + "-" + [guid]::NewGuid().ToString("n"))
    try {
        New-Item -ItemType Directory -Force -Path (Join-Path $temp "docs") | Out-Null
        Set-Content -LiteralPath (Join-Path $temp "docs\project-state.md") -Value "## phase`nselftest" -Encoding UTF8
        $doctorPath = New-FakeDoctor -Dir $temp -Name ("fake-doctor-" + $case.id) -Body $case.doctor
        $result = Invoke-SessionHook -HookScript $HookPath -TempRoot $temp -DoctorPath $doctorPath

        Assert-True ($result.elapsedMs -le 6000) "$($case.id): hook elapsed <= 6000ms ($($result.elapsedMs))"
        Assert-True ($result.exitCode -eq 0) "$($case.id): exit 0"
        $parsed = $null
        try {
            $parsed = $result.stdout | ConvertFrom-Json
        } catch {
            $parsed = $null
        }
        Assert-True ($null -ne $parsed) "$($case.id): stdout valid JSON"
        if ($null -ne $parsed) {
            Assert-True ($parsed.PSObject.Properties.Name -contains "additional_context") "$($case.id): has additional_context"
            $ctxLen = [string]$parsed.additional_context
            Assert-True ($ctxLen.Length -le 1200) "$($case.id): additional_context <= 1200 ($($ctxLen.Length))"
            if ($case.id -eq "success") {
                Assert-True ($ctxLen -match "Stage:\s*selftest") "$($case.id): Stage appears"
            }
            if ($case.id -eq "malformed") {
                $hasLeadingNul = ($result.stdout.Length -gt 0 -and [int][char]$result.stdout[0] -eq 0)
                Assert-True (-not $hasLeadingNul) "$($case.id): stdout has no leading NUL"
            }
            if ($case.id -eq "hang") {
                Assert-True ($ctxLen -match "timeout") "$($case.id): hang reports timeout"
                Assert-True (Test-NoDoctorProcesses -DoctorPath $doctorPath) "$($case.id): hang doctor child terminated"
            }
            if ($case.id -eq "oversized") {
                Assert-True ($ctxLen.Length -le 1200) "$($case.id): oversized output truncated"
            }
            if ($case.id -eq "console_corrupt") {
                Assert-True ($result.stdout -notmatch "^CORRUPT") "$($case.id): stdout has no CORRUPT prefix"
                Assert-True ($ctxLen -match "doctor: OK") "$($case.id): doctor output captured via file redirect"
            }
        }
    } finally {
        Remove-Item -Recurse -Force $temp -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "=== V-SESSION no-env project-hook ==="
$noEnvTemp = Join-Path $env:TEMP ("cptk-vsession-noenv-" + [guid]::NewGuid().ToString("n"))
try {
    $hookDir = Join-Path $noEnvTemp ".cursor\hooks"
    New-Item -ItemType Directory -Force -Path (Join-Path $noEnvTemp "docs") | Out-Null
    New-Item -ItemType Directory -Force -Path $hookDir | Out-Null
    Copy-Item -LiteralPath $HookPath -Destination (Join-Path $hookDir "session-start.ps1") -Force
    Set-Content -LiteralPath (Join-Path $noEnvTemp "docs\project-state.md") -Value @"
## phase
no-env-hook

## next_checks
- [ ] verify no-env hook injects stage
"@ -Encoding UTF8
    $noEnvDoctor = New-FakeDoctor -Dir $noEnvTemp -Name "fake-doctor-noenv" -Body @'
Write-Output "doctor: no-env OK"
exit 0
'@
    $savedRoot = $env:CURSOR_SESSION_PROJECT_ROOT
    $savedDir = $env:CURSOR_PROJECT_DIR
    $savedDoctor = $env:CURSOR_SESSION_DOCTOR_PATH
    Remove-Item Env:CURSOR_SESSION_PROJECT_ROOT -ErrorAction SilentlyContinue
    Remove-Item Env:CURSOR_PROJECT_DIR -ErrorAction SilentlyContinue
    Remove-Item Env:CURSOR_SESSION_DOCTOR_PATH -ErrorAction SilentlyContinue
    try {
        Push-Location $noEnvTemp
        $result = Invoke-SessionHook -HookScript (Join-Path $hookDir "session-start.ps1") -DoctorPath $noEnvDoctor
        Pop-Location
    } catch {
        Pop-Location
        throw
    } finally {
        if ($null -eq $savedRoot) { Remove-Item Env:CURSOR_SESSION_PROJECT_ROOT -ErrorAction SilentlyContinue }
        else { $env:CURSOR_SESSION_PROJECT_ROOT = $savedRoot }
        if ($null -eq $savedDir) { Remove-Item Env:CURSOR_PROJECT_DIR -ErrorAction SilentlyContinue }
        else { $env:CURSOR_PROJECT_DIR = $savedDir }
        if ($null -eq $savedDoctor) { Remove-Item Env:CURSOR_SESSION_DOCTOR_PATH -ErrorAction SilentlyContinue }
        else { $env:CURSOR_SESSION_DOCTOR_PATH = $savedDoctor }
    }
    $parsed = $null
    try { $parsed = $result.stdout | ConvertFrom-Json } catch { $parsed = $null }
    Assert-True ($result.exitCode -eq 0) "no-env project-hook: exit 0"
    Assert-True ($null -ne $parsed) "no-env project-hook: valid JSON"
    if ($null -ne $parsed) {
        $ctx = [string]$parsed.additional_context
        Assert-True ($ctx -match "Stage:\s*no-env-hook") "no-env project-hook: Stage appears"
    }
} finally {
    Remove-Item -Recurse -Force $noEnvTemp -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "=== V-SESSION inherited CURSOR_PROJECT_DIR cleared for TempRoot ==="
$inheritTemp = Join-Path $env:TEMP ("cptk-vsession-inherit-" + [guid]::NewGuid().ToString("n"))
$decoyDir = Join-Path $env:TEMP ("cptk-vsession-decoy-" + [guid]::NewGuid().ToString("n"))
try {
    New-Item -ItemType Directory -Force -Path (Join-Path $inheritTemp "docs") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $decoyDir "docs") | Out-Null
    Set-Content -LiteralPath (Join-Path $inheritTemp "docs\project-state.md") -Value @"
## phase
inherit-temp-root

## next_checks
- [ ] verify inherited CURSOR_PROJECT_DIR ignored
"@ -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $decoyDir "docs\project-state.md") -Value @"
## phase
decoy-inherited
"@ -Encoding UTF8
    $inheritDoctor = New-FakeDoctor -Dir $inheritTemp -Name "fake-doctor-inherit" -Body @'
Write-Output "doctor: inherit OK"
exit 0
'@
    $savedInheritedDir = $env:CURSOR_PROJECT_DIR
    $env:CURSOR_PROJECT_DIR = $decoyDir
    try {
        $resultInherit = Invoke-SessionHook -HookScript $HookPath -TempRoot $inheritTemp -DoctorPath $inheritDoctor
    } finally {
        if ($null -eq $savedInheritedDir) { Remove-Item Env:CURSOR_PROJECT_DIR -ErrorAction SilentlyContinue }
        else { $env:CURSOR_PROJECT_DIR = $savedInheritedDir }
    }
    $parsedInherit = $null
    try { $parsedInherit = $resultInherit.stdout | ConvertFrom-Json } catch { $parsedInherit = $null }
    Assert-True ($resultInherit.exitCode -eq 0) "inherit-clear: exit 0"
    Assert-True ($null -ne $parsedInherit) "inherit-clear: valid JSON"
    if ($null -ne $parsedInherit) {
        $ctxInherit = [string]$parsedInherit.additional_context
        Assert-True ($ctxInherit -match "Stage:\s*inherit-temp-root") "inherit-clear: uses TempRoot phase"
        Assert-True ($ctxInherit -notmatch "decoy-inherited") "inherit-clear: decoy CURSOR_PROJECT_DIR ignored"
    }
} finally {
    Remove-Item -Recurse -Force $inheritTemp -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $decoyDir -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "=== V-SESSION installed-plugin CURSOR_PROJECT_DIR ==="
$pluginTemp = Join-Path $env:TEMP ("cptk-vsession-plugin-" + [guid]::NewGuid().ToString("n"))
try {
    New-Item -ItemType Directory -Force -Path (Join-Path $pluginTemp "docs") | Out-Null
    Set-Content -LiteralPath (Join-Path $pluginTemp "docs\project-state.md") -Value @"
## phase
plugin-installed

## next_checks
- [ ] verify plugin injects stage via CURSOR_PROJECT_DIR
"@ -Encoding UTF8
    $pluginDoctor = New-FakeDoctor -Dir $pluginTemp -Name "fake-doctor-plugin" -Body @'
Write-Output "doctor: plugin OK"
exit 0
'@
    Assert-True (Test-Path -LiteralPath $PluginHookPath) "installed-plugin: plugin session-start exists"
    $result = Invoke-SessionHook `
        -HookScript $PluginHookPath `
        -CursorProjectDir $pluginTemp `
        -DoctorPath $pluginDoctor
    $parsed = $null
    try { $parsed = $result.stdout | ConvertFrom-Json } catch { $parsed = $null }
    Assert-True ($result.exitCode -eq 0) "installed-plugin: exit 0"
    Assert-True ($null -ne $parsed) "installed-plugin: valid JSON"
    if ($null -ne $parsed) {
        $ctx = [string]$parsed.additional_context
        Assert-True ($ctx -match "Stage:\s*plugin-installed") "installed-plugin: Stage appears with CURSOR_PROJECT_DIR"
        Assert-True ($ctx -match "Next:") "installed-plugin: Next appears"
    }

    $resultNoDoctor = Invoke-SessionHook `
        -HookScript $PluginHookPath `
        -CursorProjectDir $pluginTemp
    $parsedNoDoctor = $null
    try { $parsedNoDoctor = $resultNoDoctor.stdout | ConvertFrom-Json } catch { $parsedNoDoctor = $null }
    Assert-True ($resultNoDoctor.exitCode -eq 0) "installed-plugin no-doctor: exit 0"
    Assert-True ($null -ne $parsedNoDoctor) "installed-plugin no-doctor: valid JSON"
    if ($null -ne $parsedNoDoctor) {
        $ctxNoDoctor = [string]$parsedNoDoctor.additional_context
        Assert-True ($ctxNoDoctor -match "Stage:\s*plugin-installed") "installed-plugin no-doctor: Stage appears without fake doctor"
    }
} finally {
    Remove-Item -Recurse -Force $pluginTemp -ErrorAction SilentlyContinue
}

Write-Host ""
if ($fail -eq 0) {
    Write-Host "SESSION_CONTEXT_TEST_PASS"
    exit 0
}
Write-Host "SESSION_CONTEXT_TEST_FAIL: $fail"
exit 1

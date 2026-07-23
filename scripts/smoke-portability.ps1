<#
.SYNOPSIS
  Offline portability smoke: greenfield, new-PC plugin, existing re-seed, Full templates, doctor degradation.
  PS 5.1, isolated temp roots (spaces + Unicode), no network, no real USERPROFILE\.cursor writes.
#>
param(
    [switch]$OracleMode
)

$ErrorActionPreference = "Stop"
$ToolkitRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$fail = 0
$tempRoots = @()
$realUserProfile = [Environment]::GetEnvironmentVariable("USERPROFILE", "Process")
if ([string]::IsNullOrWhiteSpace($realUserProfile)) {
    $realUserProfile = $env:USERPROFILE
}
$realCursorRoot = Join-Path $realUserProfile ".cursor"
$UnderVerifyHarness = ($env:CPTK_VERIFY_HARNESS -eq "1")
$FailClosed = $OracleMode -or $UnderVerifyHarness

function Write-StageOk {
    param([Parameter(Mandatory = $true)][string]$StageId)
    if ($OracleMode -or $UnderVerifyHarness) {
        Write-Host "STAGE_OK $StageId"
    }
}

function Write-PortabilitySkip {
    param([Parameter(Mandatory = $true)][string]$Message)
    if ($OracleMode -or $UnderVerifyHarness) {
        Write-Host "FAIL skip forbidden under oracle/verify-harness: $Message"
        $script:fail++
        return
    }
    Write-Host "SKIP $Message"
}

function Assert-True($cond, [string]$msg) {
    if ($cond) {
        Write-Host "OK  $msg"
    } else {
        Write-Host "FAIL $msg"
        $script:fail++
    }
}

function ConvertTo-PsSingleQuotedLiteral {
    param([AllowNull()][string]$Value)
    if ($null -eq $Value) { return '$null' }
    return "'" + ($Value.Replace("'", "''")) + "'"
}

function ConvertTo-PsInvocationSuffix {
    param([string[]]$ArgList)
    if ($ArgList.Count -eq 0) { return "" }
    $parts = @()
    for ($i = 0; $i -lt $ArgList.Count; $i++) {
        $token = [string]$ArgList[$i]
        if ($token -match '^-') {
            $parts += $token
            if (($i + 1) -lt $ArgList.Count -and [string]$ArgList[$i + 1] -notmatch '^-') {
                $i++
                $parts += (ConvertTo-PsSingleQuotedLiteral ([string]$ArgList[$i]))
            }
        } else {
            $parts += (ConvertTo-PsSingleQuotedLiteral $token)
        }
    }
    return " " + ($parts -join " ")
}

function Start-Ps1ChildProcess {
    param(
        [Parameter(Mandatory = $true)][string]$File,
        [string[]]$ArgList = @(),
        [string]$StdinText = $null,
        [int]$TimeoutMs = 0,
        [string]$WorkingDirectory = $ToolkitRoot
    )
    if (-not (Test-Path -LiteralPath $File)) {
        throw "Script not found: $File"
    }
    $resolvedFile = (Resolve-Path -LiteralPath $File).Path
    $resolvedWorkDir = (Resolve-Path -LiteralPath $WorkingDirectory).Path
    $absLit = ConvertTo-PsSingleQuotedLiteral $resolvedFile
    $workDirLit = ConvertTo-PsSingleQuotedLiteral $resolvedWorkDir
    $argSuffix = ConvertTo-PsInvocationSuffix -ArgList $ArgList
    $inner = @"
`$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $workDirLit
& $absLit$argSuffix
if (`$null -ne `$LASTEXITCODE -and `$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE }
exit 0
"@
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($inner))

    $outFile = Join-Path $env:TEMP ("cptk-out-" + [guid]::NewGuid().ToString("n") + ".txt")
    $errFile = Join-Path $env:TEMP ("cptk-err-" + [guid]::NewGuid().ToString("n") + ".txt")
    $inFile = $null
    if ($null -ne $StdinText) {
        $inFile = Join-Path $env:TEMP ("cptk-in-" + [guid]::NewGuid().ToString("n") + ".txt")
        [System.IO.File]::WriteAllText($inFile, $StdinText, (New-Object System.Text.UTF8Encoding $false))
    }

    $timedOut = $false
    $code = 0
    $stdout = ""
    $stderr = ""
    $proc = $null
    try {
        if ($null -ne $inFile) {
            $cmdInner = "powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded < `"$inFile`""
            $proc = Start-Process -FilePath "cmd.exe" `
                -ArgumentList @("/c", $cmdInner) `
                -WorkingDirectory $resolvedWorkDir `
                -RedirectStandardOutput $outFile `
                -RedirectStandardError $errFile `
                -PassThru -NoNewWindow
        } else {
            $proc = Start-Process -FilePath "powershell.exe" `
                -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-EncodedCommand", $encoded) `
                -WorkingDirectory $resolvedWorkDir `
                -RedirectStandardOutput $outFile `
                -RedirectStandardError $errFile `
                -PassThru -NoNewWindow
        }

        if ($TimeoutMs -gt 0) {
            if (-not $proc.WaitForExit($TimeoutMs)) {
                $timedOut = $true
                try {
                    if (-not $proc.HasExited) {
                        & taskkill.exe /PID $proc.Id /T /F 2>$null | Out-Null
                    }
                } catch { }
                try { [void]$proc.WaitForExit(5000) } catch { }
            }
        } else {
            [void]$proc.WaitForExit()
        }

        if (Test-Path -LiteralPath $outFile) {
            $stdout = [System.IO.File]::ReadAllText($outFile, [System.Text.Encoding]::UTF8)
        }
        if (Test-Path -LiteralPath $errFile) {
            $stderr = [System.IO.File]::ReadAllText($errFile, [System.Text.Encoding]::UTF8)
        }
        if ($timedOut) {
            $code = 124
        } elseif ($proc.HasExited) {
            $code = $proc.ExitCode
        } else {
            $code = 124
        }
    } finally {
        foreach ($tmp in @($outFile, $errFile, $inFile)) {
            if (-not [string]::IsNullOrWhiteSpace($tmp) -and (Test-Path -LiteralPath $tmp)) {
                Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            }
        }
    }
    if ($stdout.Length -gt 0 -and [int][char]$stdout[0] -eq 0xFEFF) {
        $stdout = $stdout.Substring(1)
    }
    return @{
        stdout   = $stdout
        stderr   = $stderr
        exitCode = $code
    }
}

function Invoke-Ps1File {
    param(
        [Parameter(Mandatory = $true)][string]$File,
        [hashtable]$EnvExtra = @{},
        [string[]]$ArgList = @(),
        [string]$WorkingDirectory = $ToolkitRoot
    )
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $saved = @{}
    foreach ($k in $EnvExtra.Keys) {
        $saved[$k] = [Environment]::GetEnvironmentVariable($k, "Process")
        [Environment]::SetEnvironmentVariable($k, [string]$EnvExtra[$k], "Process")
    }
    $code = 0
    try {
        $result = Start-Ps1ChildProcess -File $File -ArgList $ArgList -WorkingDirectory $WorkingDirectory
        $code = $result.exitCode
        foreach ($line in (($result.stdout + $result.stderr) -split '\r?\n')) {
            if ($line.Length -gt 0) { Write-Host $line }
        }
    } finally {
        foreach ($k in $saved.Keys) {
            if ($null -eq $saved[$k]) {
                [Environment]::SetEnvironmentVariable($k, $null, "Process")
            } else {
                [Environment]::SetEnvironmentVariable($k, $saved[$k], "Process")
            }
        }
        $ErrorActionPreference = $prevEap
    }
    if ($null -eq $code) { $code = 0 }
    return [int]$code
}

function New-IsolatedRoot {
    param([string]$Label)
    $parent = Join-Path $env:TEMP ("CPTK Portability " + [char]0x6D4B + " " + $Label)
    $root = Join-Path $parent ([guid]::NewGuid().ToString("n"))
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    $script:tempRoots += $root
    $script:tempRoots += $parent
    return $root
}

function Get-CursorRootFileSnapshot {
    param([string]$CursorRoot)
    $snap = @{}
    if (-not (Test-Path -LiteralPath $CursorRoot)) { return $snap }
    foreach ($f in (Get-ChildItem -LiteralPath $CursorRoot -Recurse -File -ErrorAction SilentlyContinue)) {
        $rel = $f.FullName.Substring($CursorRoot.Length).TrimStart('\', '/')
        try {
            $snap[$rel] = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
        } catch {
            $snap[$rel] = "__UNREADABLE__"
        }
    }
    return $snap
}

function Test-IsVolatileCursorRuntimePath {
    param([string]$RelPath)
    $norm = $RelPath.Replace('/', '\').TrimStart('\')
    $volatilePrefixes = @(
        "projects\",
        "ai-tracking\",
        "terminals\",
        "logs\",
        "CachedData\",
        "Cache\",
        "CachedExtensions\",
        "blob_storage\",
        "sentry\",
        "process-monitor\"
    )
    foreach ($prefix in $volatilePrefixes) {
        if ($norm.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Assert-NoRealCursorPluginWrites {
    param([hashtable]$BeforeSnap)
    if (-not (Test-Path -LiteralPath $realCursorRoot)) { return }
    $afterSnap = Get-CursorRootFileSnapshot -CursorRoot $realCursorRoot
    $added = @()
    $changed = @()
    $deleted = @()
    foreach ($k in $afterSnap.Keys) {
        if (Test-IsVolatileCursorRuntimePath $k) { continue }
        if (-not $BeforeSnap.ContainsKey($k)) { $added += $k }
        elseif ($BeforeSnap[$k] -ne $afterSnap[$k]) {
            if ($BeforeSnap[$k] -eq "__UNREADABLE__" -and $afterSnap[$k] -eq "__UNREADABLE__") { continue }
            $changed += $k
        }
    }
    foreach ($k in $BeforeSnap.Keys) {
        if (Test-IsVolatileCursorRuntimePath $k) { continue }
        if (-not $afterSnap.ContainsKey($k)) { $deleted += $k }
    }
    $detail = @()
    if ($added.Count -gt 0) { $detail += ("added: " + ($added -join "; ")) }
    if ($changed.Count -gt 0) { $detail += ("changed: " + ($changed -join "; ")) }
    if ($deleted.Count -gt 0) { $detail += ("deleted: " + ($deleted -join "; ")) }
    $detailText = if ($detail.Count -gt 0) { ($detail -join " | ") } else { "" }
    Assert-True ($added.Count -eq 0 -and $changed.Count -eq 0 -and $deleted.Count -eq 0) `
        "P no writes under real USERPROFILE\.cursor ($detailText)"
}

function Read-ProjectStateFields {
    param([string]$StatePath)
    $phase = ""
    $next = ""
    if (-not (Test-Path -LiteralPath $StatePath)) {
        return @{ phase = $phase; next = $next }
    }
    $content = [System.IO.File]::ReadAllText($StatePath)
    if ($content -match '(?mi)^##\s*phase\s*\r?\n\s*(.+?)(\r?\n|$)') {
        $phase = $matches[1].Trim()
    } elseif ($content -match '(?mi)^phase:\s*(.+)$') {
        $phase = $matches[1].Trim()
    }
    if ($content -match '(?msi)^##\s*next_checks\s*\r?\n(.*?)(?=^\s*##\s|\z)') {
        $section = $matches[1]
        if ($section -match '(?m)^\s*-\s*\[\s\]\s*(.+?)\s*$') {
            $next = $matches[1].Trim()
        }
    }
    if ([string]::IsNullOrWhiteSpace($next) -and ($content -match '(?msi)^##\s*next_action\s*\r?\n(.*?)(?=^\s*##\s|\z)')) {
        foreach ($line in ($matches[1] -split '\r?\n')) {
            $t = $line.Trim()
            if (-not [string]::IsNullOrWhiteSpace($t)) {
                $next = $t
                break
            }
        }
    }
    return @{ phase = $phase; next = $next }
}

function Invoke-SessionStartHook {
    param(
        [string]$ProjectRoot
    )
    $hookPath = Join-Path $ProjectRoot ".cursor\hooks\session-start.ps1"
    $savedRoot = [Environment]::GetEnvironmentVariable("CURSOR_SESSION_PROJECT_ROOT", "Process")
    $savedDoctor = [Environment]::GetEnvironmentVariable("CURSOR_SESSION_DOCTOR_PATH", "Process")
    try {
        [Environment]::SetEnvironmentVariable("CURSOR_SESSION_PROJECT_ROOT", $ProjectRoot, "Process")
        [Environment]::SetEnvironmentVariable("CURSOR_SESSION_DOCTOR_PATH", $null, "Process")
        $result = Start-Ps1ChildProcess `
            -File $hookPath `
            -WorkingDirectory $ProjectRoot `
            -TimeoutMs 15000 `
            -StdinText "{}"
        return @{
            stdout   = $result.stdout.Trim()
            stderr   = $result.stderr.Trim()
            exitCode = [int]$result.exitCode
        }
    } finally {
        if ($null -eq $savedRoot) {
            [Environment]::SetEnvironmentVariable("CURSOR_SESSION_PROJECT_ROOT", $null, "Process")
        } else {
            [Environment]::SetEnvironmentVariable("CURSOR_SESSION_PROJECT_ROOT", $savedRoot, "Process")
        }
        if ($null -eq $savedDoctor) {
            [Environment]::SetEnvironmentVariable("CURSOR_SESSION_DOCTOR_PATH", $null, "Process")
        } else {
            [Environment]::SetEnvironmentVariable("CURSOR_SESSION_DOCTOR_PATH", $savedDoctor, "Process")
        }
    }
}

function Test-Scenario-Greenfield {
    $failAtStart = $fail
    Write-Host ""
    Write-Host "=== G greenfield new-project ==="
    $parent = New-IsolatedRoot -Label "greenfield"
    $name = "portability-greenfield"
    $goal = "portability smoke greenfield goal"
    $projectRoot = Join-Path $parent $name
    $envBag = @{
        CPTK_PORTABILITY_SMOKE = "1"
        TOOLKIT_PROJECTS_ROOT  = $parent
    }
    $code = Invoke-Ps1File -File (Join-Path $ToolkitRoot "scripts\new-project.ps1") `
        -EnvExtra $envBag -ArgList @("-Name", $name, "-Parent", $parent, "-Goal", $goal, "-SkipUserHome")
    Assert-True ($code -eq 0) "G new-project exit 0"
    Assert-True (Test-Path (Join-Path $projectRoot ".git")) "G has .git"
    Assert-True (Test-Path (Join-Path $projectRoot "AGENTS.md")) "G has AGENTS.md"
    Assert-True (Test-Path (Join-Path $projectRoot "docs\project-state.md")) "G has project-state"
    Assert-True (Test-Path (Join-Path $projectRoot "docs\docs-map.json")) "G has docs-map"
    Assert-True (Test-Path (Join-Path $projectRoot "docs\product-brief.md")) "G has product-brief"
    Assert-True (Test-Path (Join-Path $projectRoot "docs\first-chat.md")) "G has first-chat"
    Assert-True (Test-Path (Join-Path $projectRoot ".cursor\rules\autonomous-orchestration.mdc")) "G has orchestration rule"
    Assert-True (Test-Path (Join-Path $projectRoot ".cursor\skills\maintain-project-docs\SKILL.md")) "G has maintain-project-docs"
    Assert-True (Test-Path (Join-Path $projectRoot ".cursor\agents\verifier.md")) "G has verifier agent"
    Assert-True (Test-Path (Join-Path $projectRoot "docs\living-documentation.md")) "G has living-documentation"
    Assert-True (Test-Path (Join-Path $projectRoot "scripts\project-doctor.ps1")) "G has project-doctor"
    $hookPath = Join-Path $projectRoot ".cursor\hooks\session-start.ps1"
    Assert-True (Test-Path -LiteralPath $hookPath) "G has bootstrapped session-start hook"

    $doctorCode = Invoke-Ps1File -File (Join-Path $projectRoot "scripts\project-doctor.ps1") `
        -EnvExtra @{ CURSOR_SESSION_PROJECT_ROOT = $projectRoot }
    Assert-True ($doctorCode -in @(0, 1)) "G doctor advisory exit 0 or 1 (got $doctorCode)"

    $valDocs = Join-Path $ToolkitRoot "scripts\validate-project-docs.ps1"
    if (Test-Path -LiteralPath $valDocs) {
        $valCode = Invoke-Ps1File -File $valDocs -EnvExtra @{} -ArgList @("-ProjectRoot", $projectRoot)
        Assert-True ($valCode -eq 0) "G validate-project-docs exit 0"
    } else {
        Write-PortabilitySkip "G validate-project-docs (toolkit script missing)"
    }

    $statePath = Join-Path $projectRoot "docs\project-state.md"
    $templateStatePath = Join-Path $ToolkitRoot "templates\project-state.md"
    $expected = Read-ProjectStateFields -StatePath $statePath
    $templateExpected = Read-ProjectStateFields -StatePath $templateStatePath
    Assert-True (-not [string]::IsNullOrWhiteSpace($expected.phase)) "G project-state phase parsed"
    Assert-True (-not [string]::IsNullOrWhiteSpace($expected.next)) "G project-state next parsed"
    Assert-True ($expected.phase -eq $templateExpected.phase) "G project-state phase matches template ($($templateExpected.phase))"
    Assert-True ($expected.next -eq $templateExpected.next) "G project-state next matches template"

    Push-Location $projectRoot
    try {
        $hook = Invoke-SessionStartHook -ProjectRoot $projectRoot
    } finally {
        Pop-Location
    }
    Assert-True ($hook.exitCode -eq 0) "G session-start exit 0"
    $parsed = $null
    try { $parsed = $hook.stdout | ConvertFrom-Json } catch { $parsed = $null }
    Assert-True ($null -ne $parsed) "G session-start stdout valid JSON"
    if ($null -ne $parsed) {
        $ctx = [string]$parsed.additional_context
        Assert-True ($ctx.Length -le 1200) "G additional_context <= 1200"
        Assert-True ($ctx.Contains("Stage: $($expected.phase).")) "G context has exact phase"
        Assert-True ($ctx.Contains("Next: $($expected.next).")) "G context has exact next action"
        $stageIdx = $ctx.IndexOf("Stage: $($expected.phase).")
        $nextIdx = $ctx.IndexOf("Next: $($expected.next).")
        Assert-True ($stageIdx -ge 0 -and $nextIdx -ge 0 -and $stageIdx -lt $nextIdx) "G Stage precedes Next in context"
        foreach ($doctorMarker in @("tools:", "env:", "doctor:")) {
            $docIdx = $ctx.IndexOf($doctorMarker)
            if ($docIdx -ge 0) {
                Assert-True ($stageIdx -lt $docIdx -and $nextIdx -lt $docIdx) "G Stage/Next before doctor ($doctorMarker)"
            }
        }
    }
    if (($OracleMode -or $UnderVerifyHarness) -and $fail -eq $failAtStart) {
        Write-StageOk "F-PORT-G"
    }
}

function Test-Scenario-PluginNewPc {
    $failAtStart = $fail
    Write-Host ""
    Write-Host "=== P new-PC plugin install ==="
    $beforeCursorSnap = Get-CursorRootFileSnapshot -CursorRoot $realCursorRoot
    $isolated = New-IsolatedRoot -Label "newpc"
    $fakeHome = Join-Path $isolated "fake home"
    $fakeTemp = Join-Path $isolated "temp"
    New-Item -ItemType Directory -Force -Path $fakeHome | Out-Null
    New-Item -ItemType Directory -Force -Path $fakeTemp | Out-Null
    $localPlugins = Join-Path $fakeHome ".cursor\plugins\local"
    $envBag = @{
        HOME         = $fakeHome
        USERPROFILE  = $fakeHome
        TEMP         = $fakeTemp
        TMP          = $fakeTemp
    }
    $code = Invoke-Ps1File -File (Join-Path $ToolkitRoot "scripts\install-harness-plugin.ps1") `
        -EnvExtra $envBag -ArgList @("-LocalPluginsRoot", $localPlugins)
    Assert-True ($code -eq 0) "P install-harness-plugin exit 0"
    $pluginJson = Join-Path $localPlugins "cursor-project-harness\.cursor-plugin\plugin.json"
    Assert-True (Test-Path $pluginJson) "P plugin.json exists"
    if (Test-Path $pluginJson) {
        $pj = Get-Content $pluginJson -Raw -Encoding utf8 | ConvertFrom-Json
        $manifestPath = Join-Path $ToolkitRoot "tests\orchestration\manifest.json"
        $expectedVersion = $null
        if (Test-Path -LiteralPath $manifestPath) {
            $mf = Get-Content $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json
            if ($null -ne $mf.plugin_version) {
                $expectedVersion = [string]$mf.plugin_version
            }
        }
        if (-not $expectedVersion) {
            $harnessPluginJson = Join-Path $ToolkitRoot "plugin\cursor-project-harness\.cursor-plugin\plugin.json"
            if (Test-Path -LiteralPath $harnessPluginJson) {
                $hp = Get-Content $harnessPluginJson -Raw -Encoding utf8 | ConvertFrom-Json
                if ($null -ne $hp.version) {
                    $expectedVersion = [string]$hp.version
                }
            }
        }
        if (-not $expectedVersion) {
            Write-Host "FAIL P plugin version source unavailable (manifest + harness plugin.json)"
            $script:fail++
        } else {
            Assert-True ($pj.version -eq $expectedVersion) "P plugin version from manifest ($expectedVersion)"
        }
    }
    $mirrored = @(
        "skills\autonomous-task\SKILL.md",
        "agents\verifier.md",
        "rules\autonomous-orchestration.mdc",
        "scripts\session-start.ps1"
    )
    $pluginRoot = Join-Path $localPlugins "cursor-project-harness"
    foreach ($rel in $mirrored) {
        Assert-True (Test-Path (Join-Path $pluginRoot $rel)) "P mirrored $rel"
    }
    $canonHash = (Get-FileHash (Join-Path $ToolkitRoot ".cursor\hooks\session-start.ps1")).Hash
    $plugHash = (Get-FileHash (Join-Path $pluginRoot "scripts\session-start.ps1")).Hash
    Assert-True ($canonHash -eq $plugHash) "P session-start hash matches canonical"
    Assert-NoRealCursorPluginWrites -BeforeSnap $beforeCursorSnap
    if (($OracleMode -or $UnderVerifyHarness) -and $fail -eq $failAtStart) {
        Write-StageOk "F-PORT-P"
    }
}

function Test-Scenario-ExistingReseed {
    $failAtStart = $fail
    Write-Host ""
    Write-Host "=== E existing Essential re-seed ==="
    $target = New-IsolatedRoot -Label "existing"
    $sentinelAgents = Join-Path $ToolkitRoot "tests\portability\existing-sentinel-agents.md"
    Copy-Item -LiteralPath $sentinelAgents -Destination (Join-Path $target "AGENTS.md") -Force
    $customHookDir = Join-Path $target ".cursor\hooks"
    New-Item -ItemType Directory -Force -Path $customHookDir | Out-Null
    Set-Content -LiteralPath (Join-Path $customHookDir "custom-project-hook.ps1") `
        -Value "# custom hook sentinel`nexit 0" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $target ".cursor\hooks.json") `
        -Value '{"version":1,"hooks":{"customEvent":[{"command":"echo custom"}]}}' -Encoding utf8
    $mapPath = Join-Path $target "docs\docs-map.json"
    $statePath = Join-Path $target "docs\project-state.md"
    New-Item -ItemType Directory -Force -Path (Split-Path $mapPath) | Out-Null
    $mapSentinel = "PORTABILITY_MAP_SENTINEL_" + [guid]::NewGuid().ToString("n")
    $stateSentinel = "PORTABILITY_STATE_SENTINEL_" + [guid]::NewGuid().ToString("n")
    Set-Content -LiteralPath $mapPath -Value "{`"version`":1,`"entries`":[{`"path`":`"docs/x.md`",`"title`":`"$mapSentinel`"}]}" -Encoding utf8
    Set-Content -LiteralPath $statePath -Value $stateSentinel -Encoding utf8
    $productCorePath = Join-Path $target ".cursor\rules\product-core.mdc"
    New-Item -ItemType Directory -Force -Path (Split-Path $productCorePath) | Out-Null
    $productCoreSentinel = "PORTABILITY_PRODUCT_CORE_SENTINEL_" + [guid]::NewGuid().ToString("n")
    Set-Content -LiteralPath $productCorePath -Value $productCoreSentinel -Encoding utf8

    $bootstrap = Join-Path $ToolkitRoot "scripts\bootstrap-into-project.ps1"
    $envBag = @{ CPTK_PORTABILITY_SMOKE = "1" }
    $code1 = Invoke-Ps1File -File $bootstrap -EnvExtra $envBag -ArgList @("-TargetPath", $target, "-Mode", "Essential")
    Assert-True ($code1 -eq 0) "E first bootstrap exit 0"
    $agentsAfter = Get-Content (Join-Path $target "AGENTS.md") -Raw -Encoding utf8
    Assert-True ($agentsAfter -match "CUSTOM_AGENTS_SENTINEL_PORTABILITY_E2E") "E custom AGENTS preserved"
    Assert-True (Test-Path (Join-Path $customHookDir "custom-project-hook.ps1")) "E custom hook script preserved"
    $hooksJsonPath = Join-Path $target ".cursor\hooks.json"
    Assert-True (Test-Path -LiteralPath $hooksJsonPath) "E hooks.json exists after bootstrap"
    if (Test-Path -LiteralPath $hooksJsonPath) {
        $hooksAfter = Get-Content $hooksJsonPath -Raw -Encoding utf8 | ConvertFrom-Json
        $hasCustomEvent = $false
        if ($hooksAfter.hooks) {
            $prop = $hooksAfter.hooks.PSObject.Properties["customEvent"]
            if ($null -ne $prop -and $null -ne $prop.Value) {
                $arr = @($prop.Value | Where-Object { $null -ne $_ })
                if ($arr.Count -gt 0) { $hasCustomEvent = $true }
            }
        }
        Assert-True $hasCustomEvent "E hooks.json customEvent preserved after bootstrap"
    }
    Assert-True (Test-Path (Join-Path $target ".cursor\skills\review-papercuts\SKILL.md")) "E missing harness added"
    $mapAfter1 = Get-Content $mapPath -Raw -Encoding utf8
    Assert-True ($mapAfter1 -match [regex]::Escape($mapSentinel)) "E docs-map sentinel preserved (pass 1)"
    $stateAfter1 = Get-Content $statePath -Raw -Encoding utf8
    Assert-True ($stateAfter1 -match [regex]::Escape($stateSentinel)) "E project-state sentinel preserved (pass 1)"
    $pcAfter1 = Get-Content $productCorePath -Raw -Encoding utf8
    Assert-True ($pcAfter1 -notmatch [regex]::Escape($productCoreSentinel)) "E product-core sentinel overwritten (pass 1, Always policy)"
    Assert-True ($pcAfter1 -match "Product harness core") "E product-core template applied (pass 1)"

    $code2 = Invoke-Ps1File -File $bootstrap -EnvExtra $envBag -ArgList @("-TargetPath", $target, "-Mode", "Essential")
    Assert-True ($code2 -eq 0) "E second bootstrap idempotent exit 0"
    $agentsAfter2 = Get-Content (Join-Path $target "AGENTS.md") -Raw -Encoding utf8
    Assert-True ($agentsAfter2 -match "CUSTOM_AGENTS_SENTINEL_PORTABILITY_E2E") "E custom AGENTS preserved (pass 2)"
    if (Test-Path -LiteralPath $hooksJsonPath) {
        $hooksAfter2 = Get-Content $hooksJsonPath -Raw -Encoding utf8 | ConvertFrom-Json
        $hasCustomEvent2 = $false
        if ($hooksAfter2.hooks) {
            $prop2 = $hooksAfter2.hooks.PSObject.Properties["customEvent"]
            if ($null -ne $prop2 -and $null -ne $prop2.Value) {
                $arr2 = @($prop2.Value | Where-Object { $null -ne $_ })
                if ($arr2.Count -gt 0) { $hasCustomEvent2 = $true }
            }
        }
        Assert-True $hasCustomEvent2 "E hooks.json customEvent preserved (pass 2)"
    }
    $mapAfter2 = Get-Content $mapPath -Raw -Encoding utf8
    Assert-True ($mapAfter2 -match [regex]::Escape($mapSentinel)) "E docs-map sentinel preserved (pass 2)"
    $stateAfter2 = Get-Content $statePath -Raw -Encoding utf8
    Assert-True ($stateAfter2 -match [regex]::Escape($stateSentinel)) "E project-state sentinel preserved (pass 2)"
    $pcAfter2 = Get-Content $productCorePath -Raw -Encoding utf8
    Assert-True ($pcAfter2 -notmatch [regex]::Escape($productCoreSentinel)) "E product-core sentinel overwritten (pass 2, Always policy)"
    Assert-True ($pcAfter2 -match "Product harness core") "E product-core template applied (pass 2)"
    if (($OracleMode -or $UnderVerifyHarness) -and $fail -eq $failAtStart) {
        Write-StageOk "F-PORT-E"
    }
}

function Test-PostCopyChecks {
    param([Parameter(Mandatory = $true)][string]$CopyRoot)
    $liveVal = Join-Path $CopyRoot "scripts\validate-living-evals.ps1"
    Assert-True (Test-Path -LiteralPath $liveVal) "post-copy living validator exists"
    $liveCode = Invoke-Ps1File -File $liveVal -ArgList @("-SelfTest") -WorkingDirectory $CopyRoot
    Assert-True ($liveCode -eq 0) "F-COPY-LIVE exit 0"
    Write-StageOk "F-COPY-LIVE"

    $recVal = Join-Path $CopyRoot "scripts\validate-recovery.ps1"
    Assert-True (Test-Path -LiteralPath $recVal) "post-copy recovery validator exists (F-COPY-REC mandatory)"
    $recCode = Invoke-Ps1File -File $recVal -ArgList @("-SelfTest") -WorkingDirectory $CopyRoot
    Assert-True ($recCode -eq 0) "F-COPY-REC exit 0"
    Write-StageOk "F-COPY-REC"

    $mcpVal = Join-Path $CopyRoot "scripts\validate-mcp-profiles.ps1"
    Assert-True (Test-Path -LiteralPath $mcpVal) "post-copy MCP validator exists"
    $mcpCode = Invoke-Ps1File -File $mcpVal -WorkingDirectory $CopyRoot
    Assert-True ($mcpCode -eq 0) "F-COPY-MCP exit 0"
    Write-StageOk "F-COPY-MCP"

    $dryRun = Join-Path $CopyRoot "templates\hooks\dry-run-strict-hooks.ps1"
    Assert-True (Test-Path -LiteralPath $dryRun) "post-copy template dry-run exists"
    $dryCode = Invoke-Ps1File -File $dryRun -WorkingDirectory $CopyRoot
    Assert-True ($dryCode -eq 0) "F-COPY-DRY exit 0"
    Write-StageOk "F-COPY-DRY"
}

function Test-Scenario-FullTemplates {
    $failAtStart = $fail
    Write-Host ""
    if ($OracleMode) {
        Write-Host "=== F Full templates + post-copy checks ==="
    } else {
        Write-Host "=== F Full templates + toolkit validators ==="
    }
    $target = New-IsolatedRoot -Label "full"
    $code = Invoke-Ps1File -File (Join-Path $ToolkitRoot "scripts\bootstrap-into-project.ps1") `
        -EnvExtra @{ CPTK_PORTABILITY_SMOKE = "1" } -ArgList @("-TargetPath", $target, "-Mode", "Full")
    Assert-True ($code -eq 0) "F Full bootstrap exit 0"
    $mustExist = @(
        "templates\mcp",
        "templates\cursor",
        "templates\hooks",
        "tests\living-eval",
        "scripts\validate-mcp-profiles.ps1",
        "scripts\validate-living-evals.ps1"
    )
    foreach ($rel in $mustExist) {
        Assert-True (Test-Path (Join-Path $target $rel)) "F has $rel"
    }
    $mustAbsent = @(
        ".cursor\mcp.json",
        ".cursor\permissions.json",
        ".cursor\sandbox.json",
        ".cursor\environment.json"
    )
    foreach ($rel in $mustAbsent) {
        Assert-True (-not (Test-Path (Join-Path $target $rel))) "F no active $rel"
    }
    $hooksPath = Join-Path $target ".cursor\hooks.json"
    if (Test-Path $hooksPath) {
        $hooks = Get-Content $hooksPath -Raw -Encoding utf8 | ConvertFrom-Json
        $strictEvents = @("beforeShellExecution", "beforeMcpExecution")
        foreach ($evt in $strictEvents) {
            $has = $false
            if ($hooks.hooks) {
                $prop = $hooks.hooks.PSObject.Properties[$evt]
                if ($null -ne $prop -and $null -ne $prop.Value) {
                    $arr = @($prop.Value | Where-Object { $null -ne $_ })
                    if ($arr.Count -gt 0) { $has = $true }
                }
            }
            Assert-True (-not $has) "F hooks.json has no active strict event $evt"
        }
    }

    if ($OracleMode) {
        Test-PostCopyChecks -CopyRoot $target
    } else {
        $dryRun = Join-Path $ToolkitRoot "templates\hooks\dry-run-strict-hooks.ps1"
        if (Test-Path -LiteralPath $dryRun) {
            $dryCode = Invoke-Ps1File -File $dryRun
            Assert-True ($dryCode -eq 0) "F strict hook dry-run exit 0"
        } else {
            Write-PortabilitySkip "F dry-run (template missing)"
        }

        $validators = @(
            @{ file = "validate-project-docs.ps1"; args = @("-ProjectRoot", $ToolkitRoot) },
            @{ file = "validate-project-docs.ps1"; args = @("-SelfTest") },
            @{ file = "validate-orchestration.ps1"; args = @() },
            @{ file = "validate-orchestration.ps1"; args = @("-SelfTest") },
            @{ file = "validate-mcp-profiles.ps1"; args = @() },
            @{ file = "validate-mcp-profiles.ps1"; args = @("-SelfTest") },
            @{ file = "validate-living-evals.ps1"; args = @() },
            @{ file = "validate-living-evals.ps1"; args = @("-SelfTest") }
        )
        foreach ($v in $validators) {
            $vp = Join-Path $ToolkitRoot ("scripts\" + $v.file)
            if (-not (Test-Path -LiteralPath $vp)) {
                Write-PortabilitySkip "validator $($v.file)"
                continue
            }
            $argLabel = if ($v.args.Count -gt 0) { $v.args -join " " } else { "(default)" }
            if ($v.args.Count -gt 0) {
                $vCode = Invoke-Ps1File -File $vp -EnvExtra @{} -ArgList $v.args
            } else {
                $vCode = Invoke-Ps1File -File $vp
            }
            Assert-True ($vCode -eq 0) "F $($v.file) $argLabel exit 0"
        }
    }
    if (($OracleMode -or $UnderVerifyHarness) -and $fail -eq $failAtStart) {
        Write-StageOk "F-PORT-F"
    }
}

function Test-Scenario-DoctorDegradation {
    $failAtStart = $fail
    Write-Host ""
    Write-Host "=== D doctor degradation ==="
    $target = New-IsolatedRoot -Label "doctor"
    $envBag = @{ CPTK_PORTABILITY_SMOKE = "1" }
    $code = Invoke-Ps1File -File (Join-Path $ToolkitRoot "scripts\bootstrap-into-project.ps1") `
        -EnvExtra $envBag -ArgList @("-TargetPath", $target, "-Mode", "Essential")
    Assert-True ($code -eq 0) "D bootstrap exit 0"
    $leakValue = "PORTABILITY_LEAK_" + [guid]::NewGuid().ToString("n")
    $savedPath = $env:PATH
    $savedSecret = [Environment]::GetEnvironmentVariable("FAKE_PORTABILITY_SECRET", "Process")
    $savedRoot = [Environment]::GetEnvironmentVariable("CURSOR_SESSION_PROJECT_ROOT", "Process")
    $degradedPathParts = @((Join-Path $env:SystemRoot "System32"))
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($null -ne $gitCmd -and -not [string]::IsNullOrWhiteSpace($gitCmd.Source)) {
        $degradedPathParts += (Split-Path -Parent $gitCmd.Source)
    }
    $env:PATH = ($degradedPathParts -join ";")
    $env:FAKE_PORTABILITY_SECRET = $leakValue
    $env:CURSOR_SESSION_PROJECT_ROOT = $target
    $prevEapDoctor = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    Push-Location $target
    try {
        $output = & (Join-Path $target "scripts\project-doctor.ps1") 2>&1 | Out-String
        $docCode = $LASTEXITCODE
        Write-Host $output
        Write-Host "doctor exit: $docCode"
        Assert-True ($output -match "tools:\s*node\s+MISSING") "D doctor reports node missing (stripped PATH)"
        Assert-True ($output -match "tools:\s*pwsh\s+MISSING") "D doctor reports pwsh missing (stripped PATH)"
        Assert-True ($output -match "tools:") "D doctor reports tool names"
        Assert-True ($output -match "env: curated summary") "D doctor uses curated env summary"
        Assert-True ($output -match "sensitive_vars=") "D doctor reports sensitive var count"
        Assert-True ($output -notmatch [regex]::Escape($leakValue)) "D doctor never prints secret env value"
        Assert-True ($output -notmatch "FAKE_PORTABILITY_SECRET") "D doctor does not enumerate secret var name"
        Assert-True ($docCode -in @(0, 1)) "D doctor advisory exit 0 or 1 (got $docCode)"
        if ($output -match '(?i)(KEY|TOKEN|SECRET|PASSWORD|CREDENTIAL)\s*[=:]\s*\S{8,}') {
            Assert-True $false "D doctor output has suspicious secret assignment pattern"
        }
    } finally {
        Pop-Location
        $ErrorActionPreference = $prevEapDoctor
        $env:PATH = $savedPath
        if ($null -eq $savedSecret) {
            Remove-Item Env:FAKE_PORTABILITY_SECRET -ErrorAction SilentlyContinue
        } else {
            $env:FAKE_PORTABILITY_SECRET = $savedSecret
        }
        if ($null -eq $savedRoot) {
            Remove-Item Env:CURSOR_SESSION_PROJECT_ROOT -ErrorAction SilentlyContinue
        } else {
            $env:CURSOR_SESSION_PROJECT_ROOT = $savedRoot
        }
    }
    if (($OracleMode -or $UnderVerifyHarness) -and $fail -eq $failAtStart) {
        Write-StageOk "F-PORT-D"
    }
}

Write-Host "=== Smoke portability ==="
Write-Host "Toolkit: $ToolkitRoot"
Write-Host "Real USERPROFILE: $realUserProfile"

if ($FailClosed) {
    if ($env:PORTABILITY_SMOKE_SKIP -eq "1" -or $env:CPTK_SKIP_PORTABILITY -eq "1" -or $env:CPTK_PORTABILITY_NESTED_REENTRY -eq "1") {
        Write-Host "FAIL portability skip forbidden under verify-harness/oracle mode"
        exit 1
    }
} else {
    if ($env:PORTABILITY_SMOKE_SKIP -eq "1") {
        Write-Host "PORTABILITY_SMOKE_SKIP"
        exit 0
    }

    if ($env:CPTK_SKIP_PORTABILITY -eq "1") {
        Write-Host "PORTABILITY_SMOKE_SKIP (legacy CPTK_SKIP_PORTABILITY=1)"
        exit 0
    }

    if ($env:CPTK_PORTABILITY_NESTED_REENTRY -eq "1") {
        Write-Host "PORTABILITY_SMOKE_SKIP (CPTK_PORTABILITY_NESTED_REENTRY=1)"
        exit 0
    }
}

try {
    Test-Scenario-Greenfield
    Test-Scenario-PluginNewPc
    Test-Scenario-ExistingReseed
    Test-Scenario-FullTemplates
    Test-Scenario-DoctorDegradation
} catch {
    Write-Host "FAIL unhandled: $($_.Exception.Message)"
    $fail++
} finally {
    $seen = @{}
    foreach ($p in ($tempRoots | Sort-Object -Descending)) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        if ($seen.ContainsKey($p.ToLowerInvariant())) { continue }
        $seen[$p.ToLowerInvariant()] = $true
        if (Test-Path -LiteralPath $p) {
            Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host ""
if ($fail -eq 0) {
    Write-Host "PORTABILITY_SMOKE_PASS"
    exit 0
}
Write-Host "PORTABILITY_SMOKE_FAIL: $fail assertion(s)"
exit 1

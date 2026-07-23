<#
.SYNOPSIS
  Toolkit-only Quick/Full harness oracle (deterministic static + bootstrap smoke).
  Full = Quick + exactly one smoke-bootstrap -OracleOnly. Not shipped via Essential/Full copy.
#>
param(
    [ValidateSet("Quick", "Full")]
    [string]$Profile = "Quick"
)

$ErrorActionPreference = "Stop"
$ToolkitRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Fail = 0
$StageOk = @{}
$CombinedOutput = New-Object System.Collections.Generic.List[string]

$QuickStageOrder = @(
    "Q-PARSE", "Q-DOCS-ST", "Q-DOCS-LIVE", "Q-ORCH-ST", "Q-MCP-ST", "Q-LIVE-ST", "Q-REC-ST",
    "Q-DRY-SCRIPTS", "Q-DRY-TMPL", "Q-SESSION", "Q-DOC-SECRET", "Q-DOC-BRACKET", "Q-DOC-MISSING"
)

$OracleStageOrder = @(
    "F-ESSENTIAL", "F-FULL-MERGE", "F-NEWPROJECT", "F-C1",
    "F-PORT-G", "F-PORT-P", "F-PORT-E", "F-PORT-F", "F-PORT-D",
    "F-COPY-LIVE", "F-COPY-REC", "F-COPY-MCP", "F-COPY-DRY"
)

function Write-HarnessLine {
    param([string]$Line)
    Write-Host $Line
    [void]$CombinedOutput.Add($Line)
}

function Register-StageOk {
    param([string]$StageId)
    if ($StageOk.ContainsKey($StageId)) {
        Write-HarnessLine "FAIL duplicate STAGE_OK $StageId"
        $script:Fail++
        return
    }
    $StageOk[$StageId] = $true
}

function Test-HarnessOutputLine {
    param([string]$Line)
    if ($Line -cmatch '^SKIP\b') {
        Write-HarnessLine "FAIL forbidden SKIP token under verify-harness: $Line"
        $script:Fail++
    }
    if ($Line -match 'PORTABILITY_SMOKE_SKIP') {
        Write-HarnessLine "FAIL forbidden PORTABILITY_SMOKE_SKIP under verify-harness: $Line"
        $script:Fail++
    }
    if ($Line -match 'STAGE_OK\s+(\S+)') {
        Register-StageOk $matches[1]
    }
}

function Invoke-HarnessScript {
    param(
        [Parameter(Mandatory = $true)][string]$File,
        [string[]]$ArgList = @()
    )
    if (-not (Test-Path -LiteralPath $File)) {
        Write-HarnessLine "FAIL missing script: $File"
        $script:Fail++
        return 1
    }
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $code = 0
    try {
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $File @ArgList 2>&1
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevEap
    }
    foreach ($line in @($output)) {
        $text = [string]$line
        Test-HarnessOutputLine $text
        Write-HarnessLine $text
    }
    if ($null -eq $code) { $code = 0 }
    return [int]$code
}

function Invoke-HarnessStage {
    param(
        [Parameter(Mandatory = $true)][string]$StageId,
        [Parameter(Mandatory = $true)][string]$RelativeScript,
        [string[]]$ArgList = @()
    )
    Write-HarnessLine ""
    Write-HarnessLine "=== $StageId ==="
    $path = Join-Path $ToolkitRoot $RelativeScript
    $code = Invoke-HarnessScript -File $path -ArgList $ArgList
    if ($code -ne 0) {
        Write-HarnessLine "FAIL $StageId exit $code"
        $script:Fail++
        return
    }
    Register-StageOk $StageId
    Write-HarnessLine "STAGE_OK $StageId"
}

function Assert-RequiredStageSet {
    param(
        [string[]]$Required,
        [string]$Label
    )
    $missing = @($Required | Where-Object { -not $StageOk.ContainsKey($_) })
    $extra = @($StageOk.Keys | Where-Object { $_ -notin $Required })
    if ($missing.Count -gt 0) {
        Write-HarnessLine "FAIL $Label missing stages: $($missing -join ', ')"
        $script:Fail++
    }
    if ($extra.Count -gt 0) {
        Write-HarnessLine "FAIL $Label unexpected stages: $($extra -join ', ')"
        $script:Fail++
    }
}

Write-HarnessLine "=== verify-harness $Profile ==="
Write-HarnessLine "Toolkit: $ToolkitRoot"

Invoke-HarnessStage -StageId "Q-PARSE" -RelativeScript "scripts\parse-check-ps1.ps1"
Invoke-HarnessStage -StageId "Q-DOCS-ST" -RelativeScript "scripts\validate-project-docs.ps1" -ArgList @("-SelfTest")
Invoke-HarnessStage -StageId "Q-DOCS-LIVE" -RelativeScript "scripts\validate-project-docs.ps1" -ArgList @("-ProjectRoot", $ToolkitRoot)
Invoke-HarnessStage -StageId "Q-ORCH-ST" -RelativeScript "scripts\validate-orchestration.ps1" -ArgList @("-SelfTest")
Invoke-HarnessStage -StageId "Q-MCP-ST" -RelativeScript "scripts\validate-mcp-profiles.ps1" -ArgList @("-SelfTest")
Invoke-HarnessStage -StageId "Q-LIVE-ST" -RelativeScript "scripts\validate-living-evals.ps1" -ArgList @("-SelfTest")
Invoke-HarnessStage -StageId "Q-REC-ST" -RelativeScript "scripts\validate-recovery.ps1" -ArgList @("-SelfTest")
Invoke-HarnessStage -StageId "Q-DRY-SCRIPTS" -RelativeScript "scripts\dry-run-strict-hooks.ps1"
Invoke-HarnessStage -StageId "Q-DRY-TMPL" -RelativeScript "templates\hooks\dry-run-strict-hooks.ps1"
Invoke-HarnessStage -StageId "Q-SESSION" -RelativeScript "scripts\test-session-start-context.ps1"
Invoke-HarnessStage -StageId "Q-DOC-SECRET" -RelativeScript "tests\project-doctor\test-secret-leak.ps1"
Invoke-HarnessStage -StageId "Q-DOC-BRACKET" -RelativeScript "tests\project-doctor\test-bracket-path.ps1"
Invoke-HarnessStage -StageId "Q-DOC-MISSING" -RelativeScript "tests\project-doctor\test-missing-phase.ps1"

if ($Profile -eq "Full") {
    Write-HarnessLine ""
    Write-HarnessLine "=== Full oracle (smoke-bootstrap -OracleOnly) ==="
    $savedVerify = [Environment]::GetEnvironmentVariable("CPTK_VERIFY_HARNESS", "Process")
    [Environment]::SetEnvironmentVariable("CPTK_VERIFY_HARNESS", "1", "Process")
    try {
        $oracleScript = Join-Path $ToolkitRoot "scripts\smoke-bootstrap.ps1"
        $oracleCode = Invoke-HarnessScript -File $oracleScript -ArgList @("-OracleOnly")
        if ($oracleCode -ne 0) {
            Write-HarnessLine "FAIL Full oracle exit $oracleCode"
            $script:Fail++
        }
    } finally {
        if ($null -eq $savedVerify) {
            [Environment]::SetEnvironmentVariable("CPTK_VERIFY_HARNESS", $null, "Process")
        } else {
            [Environment]::SetEnvironmentVariable("CPTK_VERIFY_HARNESS", $savedVerify, "Process")
        }
    }
}

$required = @($QuickStageOrder)
if ($Profile -eq "Full") {
    $required += @($OracleStageOrder)
}
Assert-RequiredStageSet -Required $required -Label $Profile

Write-HarnessLine ""
if ($Fail -eq 0) {
    Write-HarnessLine "VERIFY_HARNESS_PASS $Profile ($($required.Count) stages, deterministic static checks)"
    exit 0
}
Write-HarnessLine "VERIFY_HARNESS_FAIL $Profile ($Fail issue(s))"
exit 1

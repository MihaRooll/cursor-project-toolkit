<#
.SYNOPSIS
  Write one evidence sidecar row per contract/run — atomic create, schema validation, privacy gate.
  Default store: .cursor/evidence-local/ (gitignored). Toolkit-only; not Essential bootstrap.
#>
param(
    [string]$ProjectRoot = "",
    [string]$InputPath = "",
    [string]$InputJson = "",
    [string]$OutputPath = "",
    [string]$EvidenceRoot = "",
    [switch]$SelfTest
)

$ErrorActionPreference = "Stop"
$DefaultEvidenceRel = ".cursor/evidence-local"
$ValidatorScript = Join-Path $PSScriptRoot "validate-evidence-sidecar.ps1"
$script:OwnedOutputPaths = New-Object System.Collections.Generic.List[string]
$script:Fail = 0

function Pass([string]$Message) { Write-Host "OK  $Message" }
function Fail([string]$Message) {
    Write-Host "FAIL $Message"
    $script:Fail++
}

function Assert-True($Condition, [string]$Message) {
    if ($Condition) { Pass $Message } else { Fail $Message }
}

function Resolve-ProjectRoot {
    param([string]$Explicit)
    if (-not [string]::IsNullOrWhiteSpace($Explicit)) {
        return (Resolve-Path -LiteralPath $Explicit).Path
    }
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Test-IsReparsePoint([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $item = Get-Item -LiteralPath $Path -Force
    return (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Assert-NoReparseInPath([string]$Path, [string]$Label) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    $full = [System.IO.Path]::GetFullPath($Path)
    $current = $full
    while ($true) {
        if (Test-Path -LiteralPath $current) {
            if (Test-IsReparsePoint -Path $current) {
                throw ("reparse point rejected label=" + $Label)
            }
        }
        $parent = [System.IO.Path]::GetDirectoryName($current)
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $current) { break }
        $current = $parent
    }
}

function Get-RunFingerprintFromRow([object]$Row) {
    if ($Row.PSObject.Properties.Name -contains "run_fingerprint") {
        $fp = [string]$Row.run_fingerprint
        if (-not [string]::IsNullOrWhiteSpace($fp)) { return $fp }
    }
    $seed = [string]$Row.contract_id + "|" + [string]$Row.task_id + "|" + [string]$Row.tier
    if ($Row.PSObject.Properties.Name -contains "captured_at") {
        $seed += "|" + [string]$Row.captured_at
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($seed)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($bytes)).Replace("-", "").ToLowerInvariant().Substring(0, 16))
    } finally {
        $sha.Dispose()
    }
}

function Resolve-SidecarOutputPath {
    param(
        [string]$ProjectRoot,
        [string]$ExplicitOutput,
        [string]$EvidenceRootOverride,
        [object]$Row
    )
    if (-not [string]::IsNullOrWhiteSpace($ExplicitOutput)) {
        $path = [System.IO.Path]::GetFullPath($ExplicitOutput)
        if (Test-Path -LiteralPath $path) { throw "output path already exists" }
        Assert-NoReparseInPath -Path $path -Label "sidecar target"
        $dir = Split-Path -Parent $path
        if (-not [string]::IsNullOrWhiteSpace($dir)) {
            Assert-NoReparseInPath -Path $dir -Label "sidecar directory"
        }
        [void]$script:OwnedOutputPaths.Add($path)
        return $path
    }

    $root = $EvidenceRootOverride
    if ([string]::IsNullOrWhiteSpace($root)) {
        $root = Join-Path $ProjectRoot ($DefaultEvidenceRel -replace '/', '\')
    } else {
        $root = [System.IO.Path]::GetFullPath($root)
    }
    Assert-NoReparseInPath -Path $root -Label "evidence root"
    if (-not (Test-Path -LiteralPath $root)) {
        [void][System.IO.Directory]::CreateDirectory($root)
    }

    $contractSafe = ([string]$Row.contract_id -replace '[^\w\-.]+', '_').Trim('_')
    $fp = Get-RunFingerprintFromRow -Row $Row
    $fileName = $contractSafe + "__" + $fp + ".json"
    $path = Join-Path $root $fileName
    if (Test-Path -LiteralPath $path) { throw "duplicate sidecar for contract/run" }
    Assert-NoReparseInPath -Path $path -Label "sidecar target"
    [void]$script:OwnedOutputPaths.Add($path)
    return $path
}

function Invoke-ValidateRowJson {
    param([string]$JsonText)
    $temp = Join-Path $env:TEMP ("cptk-evidence-row-" + [guid]::NewGuid().ToString("n") + ".json")
    try {
        [System.IO.File]::WriteAllText($temp, $JsonText, (New-Object System.Text.UTF8Encoding $false))
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ValidatorScript -InputPath $temp -WriterMode | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "validation failed exit=$LASTEXITCODE" }
    } finally {
        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
    }
}

function Write-SidecarAtomic {
    param(
        [string]$OutputPath,
        [string]$JsonText
    )
    $dir = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -LiteralPath $dir)) {
        [void][System.IO.Directory]::CreateDirectory($dir)
    }
    $temp = $OutputPath + ".tmp-" + [guid]::NewGuid().ToString("n")
    try {
        $lines = ($JsonText -split "`r?`n" | ForEach-Object { $_.TrimEnd() }) -join "`n"
        [System.IO.File]::WriteAllText($temp, ($lines + "`n"), (New-Object System.Text.UTF8Encoding $false))
        [System.IO.File]::Move($temp, $OutputPath)
    } finally {
        if (Test-Path -LiteralPath $temp) {
            Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-WriteSidecar {
    param(
        [string]$ProjectRoot,
        [string]$JsonText,
        [string]$OutputPath = "",
        [string]$EvidenceRoot = ""
    )
    Invoke-ValidateRowJson -JsonText $JsonText
    $row = $JsonText | ConvertFrom-Json
    $dest = Resolve-SidecarOutputPath -ProjectRoot $ProjectRoot -ExplicitOutput $OutputPath `
        -EvidenceRootOverride $EvidenceRoot -Row $row
    Write-SidecarAtomic -OutputPath $dest -JsonText $JsonText
    return $dest
}

function New-SampleRowJson {
    param(
        [string]$ContractId = "toolkit-fast-loop-v3",
        [string]$TaskId = "slice5a-sample",
        [string]$RunFingerprint = "seed000000000001"
    )
    $row = [ordered]@{
        contract_id = $ContractId
        task_id = $TaskId
        run_fingerprint = $RunFingerprint
        tier = "T1"
        wall_clock = 95
        verification_profile = "targeted"
        verification_seconds = 30
        intended_role = "implementer"
        actual_role = "implementer"
        intended_model = "composer-2.5-fast"
        actual_model = "composer-2.5-fast"
        model_role_calls = @(
            @{ role = "implementer"; model = "composer-2.5-fast"; count = 1 }
        )
        check_outcomes = @(
            @{ check_id = "Q-ORCH-ST"; outcome = "pass" }
        )
        first_verify_pass = $true
        cycles = 0
        main_product_writes = 0
        false_escalation = $false
        protocol_violations = @()
        fast_mode_used = $false
        premium_calls = 0
        promotion_status = "evidence_pending"
        availability_defect = $false
    }
    return ($row | ConvertTo-Json -Depth 8)
}

function Remove-OwnedOutputs {
    foreach ($p in @($script:OwnedOutputPaths)) {
        if (Test-Path -LiteralPath $p) {
            Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
        }
    }
    $script:OwnedOutputPaths.Clear()
}

function Invoke-SelfTest {
    $script:Fail = 0
    function Assert-Throws($scriptBlock, [string]$msg) {
        $threw = $false
        try { & $scriptBlock } catch { $threw = $true }
        if ($threw) { Pass $msg } else { Fail ($msg + " (no throw)") }
    }

    Write-Host "=== write-evidence-sidecar SelfTest ==="
    $root = Resolve-ProjectRoot -Explicit ""
    $tempRoot = Join-Path $env:TEMP ("cptk-evidence-write-" + [guid]::NewGuid().ToString("n"))
    $evidenceRoot = Join-Path $tempRoot "evidence-local"
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

    try {
        $json = New-SampleRowJson -RunFingerprint ("run" + [guid]::NewGuid().ToString("n").Substring(0, 12))
        $out = Invoke-WriteSidecar -ProjectRoot $tempRoot -JsonText $json -EvidenceRoot $evidenceRoot
        Assert-True (Test-Path -LiteralPath $out) "sidecar written"
        Write-Host "sidecar=output=invocation-owned"

        Assert-Throws {
            Invoke-WriteSidecar -ProjectRoot $tempRoot -JsonText $json -EvidenceRoot $evidenceRoot
        } "reject duplicate contract/run"

        $json2 = New-SampleRowJson -TaskId "other-task" -RunFingerprint ("run" + [guid]::NewGuid().ToString("n").Substring(0, 12))
        $explicit = Join-Path $tempRoot ("explicit-" + [guid]::NewGuid().ToString("n") + ".json")
        $out2 = Invoke-WriteSidecar -ProjectRoot $tempRoot -JsonText $json2 -OutputPath $explicit
        Assert-True ($out2 -eq $explicit) "caller-owned explicit path"

        Assert-Throws {
            Invoke-WriteSidecar -ProjectRoot $tempRoot -JsonText $json2 -OutputPath $explicit
        } "reject pre-existing explicit path"

        $badPromo = New-SampleRowJson -RunFingerprint ("run" + [guid]::NewGuid().ToString("n").Substring(0, 12))
        $badObj = $badPromo | ConvertFrom-Json
        $badObj.promotion_status = "promoted"
        Assert-Throws {
            Invoke-WriteSidecar -ProjectRoot $tempRoot -JsonText ($badObj | ConvertTo-Json -Depth 8) -EvidenceRoot $evidenceRoot
        } "reject promoted status on write"

        $rowA = New-SampleRowJson -TaskId "determ-a" -RunFingerprint "deterministic0001"
        $rowB = New-SampleRowJson -TaskId "determ-a" -RunFingerprint "deterministic0001"
        Assert-True ($rowA -eq $rowB) "sample row json deterministic"

    } finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        Remove-OwnedOutputs
    }

    Write-Host ""
    if ($script:Fail -eq 0) {
        Write-Host "EVIDENCE_SIDECAR_WRITE_SELFTEST_PASS"
        exit 0
    }
    Write-Host "EVIDENCE_SIDECAR_WRITE_SELFTEST_FAIL: $script:Fail"
    exit 1
}

if ($SelfTest) {
    Invoke-SelfTest
}

$projectRootResolved = Resolve-ProjectRoot -Explicit $ProjectRoot
if (-not [string]::IsNullOrWhiteSpace($InputPath)) {
    if (-not (Test-Path -LiteralPath $InputPath)) { throw "input path missing" }
    $InputJson = [System.IO.File]::ReadAllText($InputPath, (New-Object System.Text.UTF8Encoding $false))
}
if ([string]::IsNullOrWhiteSpace($InputJson)) {
    throw "InputPath or InputJson required"
}

$written = Invoke-WriteSidecar -ProjectRoot $projectRootResolved -JsonText $InputJson `
    -OutputPath $OutputPath -EvidenceRoot $EvidenceRoot
Write-Host "EVIDENCE_SIDECAR_WRITE_OK sidecar=output=invocation-owned"
exit 0

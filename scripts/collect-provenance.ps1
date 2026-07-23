<#
.SYNOPSIS
  Collect local harness provenance — status/diff only on disposable reads; never apply/update.
  Consumes shadow shipping/manifest.v1.json when available. Output defaults to invocation-owned temp JSON.
#>
param(
    [string]$ProjectRoot = "",
    [string]$ToolkitRoot = "",
    [string]$ManifestPath = "",
    [string]$OutputPath = "",
    [ValidateSet("essential", "full")]
    [string]$SurfaceId = "essential",
    [switch]$SelfTest
)

$ErrorActionPreference = "Stop"
$SchemaVersion = 1
$ArtifactId = "cursor-project-harness"
$HarnessSnippetMarker = "cursor-project-toolkit-harness"
$KnownPolicies = @(
    "managed", "seed-only", "managed-block", "structural-merge", "plugin-only", "toolkit-ci-only"
)
$ForbiddenFields = @(
    "installed_at", "username", "hostname", "absolute_path", "private_path",
    "private_remote", "email", "plugin_inventory"
)
$ForbiddenValuePatterns = @(
    '@[^\s]+\.',
    '\\Users\\',
    '\\home\\',
    '://[^/]*@',
    '[A-Za-z]:\\'
)
$script:OwnedOutputPaths = New-Object System.Collections.Generic.List[string]

function Normalize-RelPath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
    return ($Path -replace '\\', '/').TrimStart('/')
}

function Get-Sha256Hex([byte[]]$Bytes) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($Bytes)).Replace("-", "").ToLowerInvariant())
    } finally {
        $sha.Dispose()
    }
}

function Test-IsReparsePoint([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $item = Get-Item -LiteralPath $Path -Force
    return (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
}

function New-ReparseRejectError {
    param([string]$Label)
    return ("reparse point rejected label=" + $Label)
}

function Assert-NoReparseInPath([string]$Path, [string]$Label) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    $full = [System.IO.Path]::GetFullPath($Path)
    $current = $full
    while ($true) {
        if (Test-Path -LiteralPath $current) {
            if (Test-IsReparsePoint -Path $current) {
                throw (New-ReparseRejectError -Label $Label)
            }
        }
        $parent = [System.IO.Path]::GetDirectoryName($current)
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $current) { break }
        $current = $parent
    }
}

function Resolve-SafeOutputPath {
    param([string]$Explicit)
    if ([string]::IsNullOrWhiteSpace($Explicit)) {
        $path = Join-Path $env:TEMP ("cptk-provenance-" + [guid]::NewGuid().ToString("n") + ".json")
    } else {
        $path = [System.IO.Path]::GetFullPath($Explicit)
    }
    if (Test-Path -LiteralPath $path) {
        throw "output path already exists"
    }
    Assert-NoReparseInPath -Path $path -Label "output target"
    $dir = Split-Path -Parent $path
    if (-not [string]::IsNullOrWhiteSpace($dir)) {
        Assert-NoReparseInPath -Path $dir -Label "output directory"
    }
    [void]$script:OwnedOutputPaths.Add($path)
    return $path
}

function Remove-OwnedOutputs {
    foreach ($p in @($script:OwnedOutputPaths)) {
        if (Test-Path -LiteralPath $p) {
            Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
        }
    }
    $script:OwnedOutputPaths.Clear()
}

function Get-DigestSentinel {
    param([string]$Side, [string]$Kind)
    return ("sentinel:" + $Side + ":" + $Kind)
}

function Add-DigestLine {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$EntryId,
        [string]$Destination,
        [string]$Side,
        [string]$Value
    )
    [void]$Lines.Add($EntryId + "|" + $Destination + "|" + $Side + "|" + $Value)
}

function Get-FileSha256([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    if (Test-IsReparsePoint -Path $Path) {
        throw (New-ReparseRejectError -Label "hash-target")
    }
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.PSIsContainer) {
        return Get-DirectorySha256 -Path $Path
    }
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    return ("sha256:" + (Get-Sha256Hex $bytes))
}

function Get-DirectorySha256([string]$Path) {
    if (Test-IsReparsePoint -Path $Path) {
        throw (New-ReparseRejectError -Label "directory-digest-root")
    }
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($dir in (Get-ChildItem -LiteralPath $Path -Recurse -Directory -Force | Sort-Object { $_.FullName })) {
        if (Test-IsReparsePoint -Path $dir.FullName) {
            throw (New-ReparseRejectError -Label "directory-digest-nested")
        }
    }
    foreach ($f in (Get-ChildItem -LiteralPath $Path -Recurse -File -Force | Sort-Object { $_.FullName })) {
        if (Test-IsReparsePoint -Path $f.FullName) {
            throw (New-ReparseRejectError -Label "directory-digest-file")
        }
        $rel = Normalize-RelPath $f.FullName.Substring($Path.Length)
        $hash = Get-Sha256Hex ([System.IO.File]::ReadAllBytes($f.FullName))
        [void]$parts.Add($rel + "|" + $hash)
    }
    $joined = ($parts -join "`n")
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($joined)
    return ("sha256:" + (Get-Sha256Hex $bytes))
}

function Get-AggregateDigest {
    param([System.Collections.Generic.List[string]]$Lines)
    if ($Lines.Count -eq 0) { return ("sha256:" + ("0" * 64)) }
    $sorted = $Lines | Sort-Object
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($sorted -join "`n"))
    return ("sha256:" + (Get-Sha256Hex $bytes))
}

function Resolve-ProjectRoot {
    param([string]$Explicit)
    if (-not [string]::IsNullOrWhiteSpace($Explicit)) {
        return (Resolve-Path -LiteralPath $Explicit).Path
    }
    $scriptDir = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($scriptDir)) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
    return (Resolve-Path -LiteralPath (Join-Path $scriptDir "..")).Path
}

function Load-ShippingManifest {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "missing manifest: $Path"
    }
    $raw = [System.IO.File]::ReadAllText($Path, (New-Object System.Text.UTF8Encoding $false))
    $obj = $raw | ConvertFrom-Json
    if ([int]$obj.schema_version -ne 1) { throw "unsupported manifest schema_version" }
    return @{ obj = $obj; raw = $raw }
}

function Test-LegacyManifest {
    param([object]$ManifestObj)
    $version = [string]$ManifestObj.manifest_version
    if ($version -match '(?i)legacy|(^v0($|[^1-9]))') {
        return $true
    }
    foreach ($entry in @($ManifestObj.entries)) {
        $ref = [string]$entry.bootstrap_ref
        if ($ref -match '(?i)^legacy($|:)') {
            return $true
        }
    }
    return $false
}

function Get-SourceRevision {
    param([string]$ManifestRaw, [object]$ManifestObj)
    $hash = Get-Sha256Hex ([System.Text.Encoding]::UTF8.GetBytes($ManifestRaw))
    return ("manifest-" + [string]$ManifestObj.manifest_version + ":sha256:" + $hash)
}

function Assert-KnownPolicy {
    param([string]$Policy)
    if ($KnownPolicies -notcontains $Policy) {
        throw "unknown policy: $Policy"
    }
}

function Test-PathUnderGitDirty {
    param(
        [string]$RelDest,
        [string[]]$DirtyLines
    )
    $norm = Normalize-RelPath $RelDest
    foreach ($line in $DirtyLines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $pathPart = $line.Substring(3).Trim()
        $pathNorm = Normalize-RelPath ($pathPart -replace '\\', '/')
        if ($pathNorm -ceq $norm -or $pathNorm.StartsWith($norm + "/", [StringComparison]::Ordinal)) {
            return $true
        }
    }
    return $false
}

function Test-ManagedBlockAgents {
    param(
        [string]$InstalledPath,
        [string]$SourcePath,
        [string]$DestRel,
        [string]$ProjectRoot
    )
    if (-not (Test-Path -LiteralPath $InstalledPath)) {
        return @{ strategy = "missing-installed"; result = "missing" }
    }
    $installedText = [System.IO.File]::ReadAllText($InstalledPath, (New-Object System.Text.UTF8Encoding $false))
    if ($installedText -match [regex]::Escape($HarnessSnippetMarker)) {
        return @{ strategy = "managed-block-marker"; result = "match" }
    }
    if ((Test-Path -LiteralPath $SourcePath) -and $DestRel -eq "AGENTS.md") {
        $sourceHash = Get-FileSha256 -Path $SourcePath
        $installedHash = Get-FileSha256 -Path $InstalledPath
        if ($sourceHash -ceq $installedHash) {
            return @{ strategy = "managed-block-marker"; result = "match" }
        }
    }
    if ($DestRel -eq "AGENTS.md" -and (Test-Path -LiteralPath (Join-Path $ProjectRoot "shipping\manifest.v1.json"))) {
        if ($installedText -match '(?m)^##\s+Mission\b') {
            return @{ strategy = "managed-block-native"; result = "match" }
        }
    }
    return @{ strategy = "managed-block-marker"; result = "drift" }
}

function Compare-ExactPathHashes {
    param(
        [string]$InstalledPath,
        [string]$SourcePath,
        [string]$StrategyLabel = "hash-compare"
    )
    if (-not (Test-Path -LiteralPath $InstalledPath)) {
        return @{
            strategy = "missing-installed"
            result = "missing"
            sourceHash = $null
            installedHash = $null
            expectedValue = $(if ($null -ne $SourcePath -and (Test-Path -LiteralPath $SourcePath)) {
                    Get-FileSha256 -Path $SourcePath
                } else {
                    Get-DigestSentinel -Side "expected" -Kind "missing-source"
                })
            installedValue = Get-DigestSentinel -Side "installed" -Kind "missing-installed"
            hasPartial = $true
            hasError = $false
            hasDrift = $false
        }
    }
    if ($null -eq $SourcePath -or -not (Test-Path -LiteralPath $SourcePath)) {
        $installedHash = Get-FileSha256 -Path $InstalledPath
        return @{
            strategy = "missing-source"
            result = "error"
            sourceHash = $null
            installedHash = $installedHash
            expectedValue = Get-DigestSentinel -Side "expected" -Kind "missing-source"
            installedValue = $installedHash
            hasPartial = $true
            hasError = $true
            hasDrift = $false
        }
    }
    $sourceHash = Get-FileSha256 -Path $SourcePath
    $installedHash = Get-FileSha256 -Path $InstalledPath
    $match = ($sourceHash -ceq $installedHash)
    return @{
        strategy = $StrategyLabel
        result = $(if ($match) { "match" } else { "drift" })
        sourceHash = $sourceHash
        installedHash = $installedHash
        expectedValue = $sourceHash
        installedValue = $installedHash
        hasPartial = $false
        hasError = $false
        hasDrift = (-not $match)
    }
}

function Test-StructuralMergeInstalled {
    param(
        [string]$InstalledPath,
        [string]$SrcRel,
        [string]$DestRel
    )
    if (-not (Test-Path -LiteralPath $InstalledPath)) {
        return @{ strategy = "structural-merge-marker"; result = "missing" }
    }
    if ($DestRel -eq ".cursor/hooks.json" -or $SrcRel -eq ".cursor/hooks.json") {
        try {
            $raw = [System.IO.File]::ReadAllText($InstalledPath, (New-Object System.Text.UTF8Encoding $false))
            $obj = $raw | ConvertFrom-Json
            $ok = $true
            foreach ($evt in @("sessionStart", "afterShellExecution", "stop")) {
                $prop = $obj.hooks.PSObject.Properties[$evt]
                if ($null -eq $prop -or $null -eq $prop.Value) { $ok = $false; break }
                $found = $false
                foreach ($item in @($prop.Value)) {
                    if ($item.command -and ($item.command -match "papercuts|session-start\.ps1")) {
                        $found = $true
                        break
                    }
                }
                if (-not $found) { $ok = $false; break }
            }
            if ($ok) {
                return @{ strategy = "structural-merge-marker"; result = "match" }
            }
            return @{ strategy = "structural-merge-marker"; result = "drift" }
        } catch {
            return @{ strategy = "structural-merge-marker"; result = "error" }
        }
    }
    if ($DestRel -eq "AGENTS.md" -or $SrcRel -like "*AGENTS-harness-snippet*") {
        $txt = [System.IO.File]::ReadAllText($InstalledPath, (New-Object System.Text.UTF8Encoding $false))
        if ($txt -match [regex]::Escape($HarnessSnippetMarker)) {
            return @{ strategy = "structural-merge-marker"; result = "match" }
        }
        return @{ strategy = "structural-merge-marker"; result = "drift" }
    }
    if (Test-Path -LiteralPath $InstalledPath) {
        return @{ strategy = "structural-merge-marker"; result = "match" }
    }
    return @{ strategy = "structural-merge-marker"; result = "missing" }
}

function Test-ReportForbidden {
    param([string]$JsonText)
    foreach ($field in $ForbiddenFields) {
        if ($JsonText -match ('"' + [regex]::Escape($field) + '"\s*:')) {
            throw "forbidden field in report: $field"
        }
    }
    foreach ($pat in $ForbiddenValuePatterns) {
        if ($JsonText -match $pat) {
            throw "forbidden value pattern in report: $pat"
        }
    }
}

function Invoke-ProvenanceCollection {
    param(
        [string]$ProjectRoot,
        [string]$ToolkitRoot,
        [string]$ManifestPath,
        [string]$SurfaceId
    )
    $loaded = Load-ShippingManifest -Path $ManifestPath
    $manifest = $loaded.obj
    $sourceRevision = Get-SourceRevision -ManifestRaw $loaded.raw -ManifestObj $manifest
    $isLegacyManifest = Test-LegacyManifest -ManifestObj $manifest

    $dirtyLines = @()
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Push-Location -LiteralPath $ProjectRoot
        try {
            $prevEap = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            $status = & git status --porcelain 2>$null
            $gitExit = $LASTEXITCODE
            $ErrorActionPreference = $prevEap
            if ($gitExit -eq 0) {
                $dirtyLines = @($status | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            }
        } finally {
            Pop-Location
        }
    }

    $pathReports = New-Object System.Collections.Generic.List[hashtable]
    $expectedLines = New-Object System.Collections.Generic.List[string]
    $installedLines = New-Object System.Collections.Generic.List[string]
    $relevantDirty = New-Object System.Collections.Generic.List[string]
    $hasDrift = $false
    $hasPartial = $false
    $hasError = $false

    foreach ($entry in @($manifest.entries)) {
        if ([string]$entry.surface -ne $SurfaceId) { continue }
        $policy = [string]$entry.policy
        Assert-KnownPolicy -Policy $policy
        $entryId = [string]$entry.id
        $destRel = Normalize-RelPath ([string]$entry.destination)
        $srcRel = Normalize-RelPath ([string]$entry.source)
        $installedPath = Join-Path $ProjectRoot ($destRel -replace '/', '\')
        $sourcePath = $null
        if (-not [string]::IsNullOrWhiteSpace($ToolkitRoot)) {
            $sourcePath = Join-Path $ToolkitRoot ($srcRel -replace '/', '\')
        }

        $strategy = "hash-compare"
        $result = "skipped"
        $sourceHash = $null
        $installedHash = $null
        $expectedValue = $null
        $installedValue = $null

        switch ($policy) {
            "seed-only" {
                $strategy = "seed-only-skip"
                $result = "skipped"
                $expectedValue = Get-DigestSentinel -Side "expected" -Kind "skipped-seed-only"
                $installedValue = Get-DigestSentinel -Side "installed" -Kind "skipped-seed-only"
            }
            "plugin-only" {
                $strategy = "plugin-only-skip"
                $result = "skipped"
                $expectedValue = Get-DigestSentinel -Side "expected" -Kind "skipped-plugin-only"
                $installedValue = Get-DigestSentinel -Side "installed" -Kind "skipped-plugin-only"
            }
            "toolkit-ci-only" {
                $strategy = "toolkit-ci-skip"
                $result = "skipped"
                $expectedValue = Get-DigestSentinel -Side "expected" -Kind "skipped-toolkit-ci-only"
                $installedValue = Get-DigestSentinel -Side "installed" -Kind "skipped-toolkit-ci-only"
            }
            "structural-merge" {
                $eval = Test-StructuralMergeInstalled -InstalledPath $installedPath -SrcRel $srcRel -DestRel $destRel
                $strategy = $eval.strategy
                $result = $eval.result
                $expectedValue = Get-DigestSentinel -Side "expected" -Kind "merge-marker"
                if ($result -eq "match") {
                    $installedValue = Get-DigestSentinel -Side "installed" -Kind "merge-ok"
                } elseif ($result -eq "missing") {
                    $installedValue = Get-DigestSentinel -Side "installed" -Kind "merge-missing"
                    $hasPartial = $true
                } elseif ($result -eq "error") {
                    $installedValue = Get-DigestSentinel -Side "installed" -Kind "error"
                    $hasError = $true
                } else {
                    $installedValue = Get-DigestSentinel -Side "installed" -Kind "merge-drift"
                    $hasDrift = $true
                }
            }
            "managed-block" {
                if ($destRel -eq "AGENTS.md") {
                    if ($null -eq $sourcePath -and -not [string]::IsNullOrWhiteSpace($ToolkitRoot)) {
                        $sourcePath = Join-Path $ToolkitRoot ($srcRel -replace '/', '\')
                    }
                    $eval = Test-ManagedBlockAgents -InstalledPath $installedPath -SourcePath $sourcePath `
                        -DestRel $destRel -ProjectRoot $ProjectRoot
                    $strategy = $eval.strategy
                    $result = $eval.result
                    if (Test-Path -LiteralPath $sourcePath) {
                        $expectedValue = Get-DigestSentinel -Side "expected" -Kind "block-template"
                    } else {
                        $expectedValue = Get-DigestSentinel -Side "expected" -Kind "missing-source"
                    }
                    if ($result -eq "match") {
                        $installedValue = Get-DigestSentinel -Side "installed" -Kind "block-ok"
                    } elseif ($result -eq "missing") {
                        $installedValue = Get-DigestSentinel -Side "installed" -Kind "missing-installed"
                        $hasPartial = $true
                    } else {
                        $installedValue = Get-DigestSentinel -Side "installed" -Kind "block-drift"
                        $hasDrift = $true
                    }
                } else {
                    $cmp = Compare-ExactPathHashes -InstalledPath $installedPath -SourcePath $sourcePath `
                        -StrategyLabel "managed-block-hash-compare"
                    $strategy = $cmp.strategy
                    $result = $cmp.result
                    $sourceHash = $cmp.sourceHash
                    $installedHash = $cmp.installedHash
                    $expectedValue = $cmp.expectedValue
                    $installedValue = $cmp.installedValue
                    if ($cmp.hasPartial) { $hasPartial = $true }
                    if ($cmp.hasError) { $hasError = $true }
                    if ($cmp.hasDrift) { $hasDrift = $true }
                }
            }
            default {
                $cmp = Compare-ExactPathHashes -InstalledPath $installedPath -SourcePath $sourcePath
                $strategy = $cmp.strategy
                $result = $cmp.result
                $sourceHash = $cmp.sourceHash
                $installedHash = $cmp.installedHash
                $expectedValue = $cmp.expectedValue
                $installedValue = $cmp.installedValue
                if ($cmp.hasPartial) { $hasPartial = $true }
                if ($cmp.hasError) { $hasError = $true }
                if ($cmp.hasDrift) { $hasDrift = $true }
            }
        }

        if ($result -ne "skipped" -and (Test-PathUnderGitDirty -RelDest $destRel -DirtyLines $dirtyLines)) {
            if ($relevantDirty -notcontains $destRel) {
                [void]$relevantDirty.Add($destRel)
            }
        }

        Add-DigestLine -Lines $expectedLines -EntryId $entryId -Destination $destRel -Side "expected" -Value $expectedValue
        Add-DigestLine -Lines $installedLines -EntryId $entryId -Destination $destRel -Side "installed" -Value $installedValue

        [void]$pathReports.Add(@{
                entry_id = $entryId
                policy = $policy
                surface = [string]$entry.surface
                destination = $destRel
                strategy = $strategy
                result = $result
                source_hash = $sourceHash
                installed_hash = $installedHash
            })
    }

    $completion = "success"
    if ($isLegacyManifest) { $completion = "legacy" }
    elseif ($hasError) { $completion = "error" }
    elseif ($hasPartial) { $completion = "partial" }
    elseif ($hasDrift) { $completion = "stale" }
    elseif ($relevantDirty.Count -gt 0) { $completion = "dirty" }

    return [ordered]@{
        schema_version = $SchemaVersion
        artifact_id = $ArtifactId
        surface_id = $SurfaceId
        source_revision = $sourceRevision
        managed_content_digest = (Get-AggregateDigest -Lines $expectedLines)
        installed_digest = (Get-AggregateDigest -Lines $installedLines)
        dirty_relevance = @{
            git_dirty = ($relevantDirty.Count -gt 0)
            relevant_paths = @($relevantDirty | Sort-Object)
        }
        completion_state = $completion
        paths = @($pathReports | Sort-Object { [string]$_.destination })
    }
}

function Write-ProvenanceReport {
    param(
        [hashtable]$Report,
        [string]$OutputPath
    )
    if (-not $script:OwnedOutputPaths.Contains($OutputPath)) {
        throw "output path not registered as invocation-owned"
    }
    if (Test-Path -LiteralPath $OutputPath) {
        throw "output path already exists"
    }
    $json = ($Report | ConvertTo-Json -Depth 8 -Compress:$false)
    Test-ReportForbidden -JsonText $json
    $dir = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -LiteralPath $dir)) {
        [void][System.IO.Directory]::CreateDirectory($dir)
    }
    $lines = ($json -split "`r?`n" | ForEach-Object { $_.TrimEnd() }) -join "`n"
    [System.IO.File]::WriteAllText($OutputPath, ($lines + "`n"), (New-Object System.Text.UTF8Encoding $false))
    return $OutputPath
}

function Write-MinimalManifest {
    param(
        [string]$Path,
        [string]$DestRel,
        [string]$SourceRel = ".gitattributes",
        [string]$Policy = "managed",
        [string]$ManifestVersion = "v1-selftest",
        [string]$BootstrapRef = "selftest"
    )
    $obj = [ordered]@{
        schema_version = 1
        manifest_version = $ManifestVersion
        policies = @($Policy)
        entries = @(
            [ordered]@{
                id = "entry-test"
                policy = $Policy
                surface = "essential"
                source = $SourceRel
                destination = $DestRel
                bootstrap_ref = $BootstrapRef
            }
        )
    }
    ($obj | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Invoke-ForbiddenScannerSelfTests {
    $fail = 0
    function Assert-Throws($scriptBlock, [string]$msg) {
        $threw = $false
        try { & $scriptBlock } catch { $threw = $true }
        if ($threw) { Write-Host "OK  $msg" } else { Write-Host "FAIL $msg"; $script:fail++ }
    }
    foreach ($field in $ForbiddenFields) {
        $bad = '{"schema_version":1,"' + $field + '":"x"}'
        Assert-Throws { Test-ReportForbidden -JsonText $bad } "forbidden field rejected: $field"
    }
    $valueCases = @(
        @{ label = "email"; text = '{"note":"user@example.com"}' }
        @{ label = "users-path"; text = '{"note":"\\\\Users\\\\katko\\\\x"}' }
        @{ label = "home-path"; text = '{"note":"\\\\home\\\\katko\\\\x"}' }
        @{ label = "private-remote"; text = '{"note":"https://token@host/path"}' }
        @{ label = "drive-letter"; text = '{"note":"C:\\\\secret"}' }
    )
    foreach ($case in $valueCases) {
        Assert-Throws { Test-ReportForbidden -JsonText $case.text } ("forbidden value rejected: " + $case.label)
    }
    return $fail
}

function Invoke-SelfTest {
    $fail = 0
    function Assert-True($cond, [string]$msg) {
        if ($cond) { Write-Host "OK  $msg" } else { Write-Host "FAIL $msg"; $script:fail++ }
    }
    function Assert-Throws($scriptBlock, [string]$msg) {
        $threw = $false
        try { & $scriptBlock } catch { $threw = $true }
        if ($threw) { Write-Host "OK  $msg" } else { Write-Host "FAIL $msg"; $script:fail++ }
    }

    function Assert-ThrowsReparseBounded($scriptBlock, [string]$msg) {
        $threw = $false
        $errMsg = ""
        try { & $scriptBlock } catch { $threw = $true; $errMsg = $_.Exception.Message }
        if (-not $threw) {
            Write-Host "FAIL $msg (no throw)"
            $script:fail++
            return
        }
        if ($errMsg -notmatch 'reparse point rejected label=') {
            Write-Host "FAIL $msg (missing label token)"
            $script:fail++
            return
        }
        if ($errMsg -match '[A-Za-z]:\\' -or $errMsg -match '\\Users\\' -or $errMsg -match '\\home\\') {
            Write-Host "FAIL $msg (absolute path in error)"
            $script:fail++
            return
        }
        Write-Host "OK  $msg"
    }

    Write-Host "=== collect-provenance SelfTest ==="
    $fail += Invoke-ForbiddenScannerSelfTests
    $toolkitRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    $manifestPath = Join-Path $toolkitRoot "shipping\manifest.v1.json"
    Assert-True (Test-Path -LiteralPath $manifestPath) "toolkit manifest exists"

    $tempRoot = Join-Path $env:TEMP ("cptk-prov-selftest-" + [guid]::NewGuid().ToString("n"))
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    $miniManifest = Join-Path $tempRoot "mini-manifest.json"
    Write-MinimalManifest -Path $miniManifest -DestRel ".gitattributes"
    try {
        $posRoot = Join-Path $tempRoot "positive"
        New-Item -ItemType Directory -Force -Path $posRoot | Out-Null
        Copy-Item -LiteralPath (Join-Path $toolkitRoot ".gitattributes") -Destination (Join-Path $posRoot ".gitattributes")
        $posReport = Invoke-ProvenanceCollection -ProjectRoot $posRoot -ToolkitRoot $toolkitRoot `
            -ManifestPath $miniManifest -SurfaceId "essential"
        Assert-True ($posReport.paths[0].result -eq "match") "positive match"
        Assert-True ($posReport.completion_state -eq "success") "positive success"
        Assert-True ($posReport.managed_content_digest -ne $posReport.installed_digest) "digest sides differ by sentinel prefix"

        $digestLines = New-Object System.Collections.Generic.List[string]
        Add-DigestLine -Lines $digestLines -EntryId "e1" -Destination "dest/rel" -Side "expected" -Value "sha256:abc"
        Assert-True ($digestLines[0] -eq "e1|dest/rel|expected|sha256:abc") "digest line format entry_id|destination|side|value"

        $hashFile = Join-Path $tempRoot "hash-file.txt"
        Set-Content -LiteralPath $hashFile -Value "deterministic-bytes" -Encoding UTF8 -NoNewline
        $hashA = Get-FileSha256 -Path $hashFile
        $hashB = Get-FileSha256 -Path $hashFile
        Assert-True ($hashA -ceq $hashB) "file hash same path twice equal"
        Add-Content -LiteralPath $hashFile -Value "x" -Encoding UTF8 -NoNewline
        $hashC = Get-FileSha256 -Path $hashFile
        Assert-True ($hashA -cne $hashC) "file hash one-byte change differs"

        $hashDir = Join-Path $tempRoot "hash-dir"
        New-Item -ItemType Directory -Force -Path (Join-Path $hashDir "sub") | Out-Null
        Set-Content -LiteralPath (Join-Path $hashDir "a.txt") -Value "a" -Encoding UTF8 -NoNewline
        Set-Content -LiteralPath (Join-Path $hashDir "sub\b.txt") -Value "b" -Encoding UTF8 -NoNewline
        $dirA = Get-DirectorySha256 -Path $hashDir
        $dirB = Get-DirectorySha256 -Path $hashDir
        Assert-True ($dirA -ceq $dirB) "directory hash same tree twice equal"
        Add-Content -LiteralPath (Join-Path $hashDir "a.txt") -Value "!" -Encoding UTF8 -NoNewline
        $dirC = Get-DirectorySha256 -Path $hashDir
        Assert-True ($dirA -cne $dirC) "directory hash one-byte change differs"

        $realOutDir = Join-Path $tempRoot "real-out"
        New-Item -ItemType Directory -Force -Path $realOutDir | Out-Null
        $junctionOutParent = Join-Path $tempRoot "junction-out-parent"
        cmd /c mklink /J "$junctionOutParent" "$realOutDir" 2>$null | Out-Null
        $reparseOut = Join-Path $junctionOutParent "report.json"
        $victimOut = Join-Path $realOutDir "victim.txt"
        Set-Content -LiteralPath $victimOut -Value "unchanged" -Encoding UTF8 -NoNewline
        $victimOutBefore = Get-FileSha256 -Path $victimOut
        Assert-ThrowsReparseBounded { Resolve-SafeOutputPath -Explicit $reparseOut } "reject output path ancestor reparse"
        $victimOutAfter = Get-FileSha256 -Path $victimOut
        Assert-True ($victimOutBefore -ceq $victimOutAfter) "output reparse victim unchanged"

        $digestRoot = Join-Path $tempRoot "digest-reparse-root"
        $realNested = Join-Path $tempRoot "real-nested"
        New-Item -ItemType Directory -Force -Path $digestRoot | Out-Null
        New-Item -ItemType Directory -Force -Path $realNested | Out-Null
        Set-Content -LiteralPath (Join-Path $realNested "nested.txt") -Value "nested" -Encoding UTF8 -NoNewline
        $junctionInDigest = Join-Path $digestRoot "link"
        cmd /c mklink /J "$junctionInDigest" "$realNested" 2>$null | Out-Null
        $digestVictim = Join-Path $digestRoot "victim.txt"
        Set-Content -LiteralPath $digestVictim -Value "victim" -Encoding UTF8 -NoNewline
        $digestVictimBefore = Get-FileSha256 -Path $digestVictim
        Assert-ThrowsReparseBounded { Get-DirectorySha256 -Path $digestRoot } "reject nested reparse in directory digest"
        $digestVictimAfter = Get-FileSha256 -Path $digestVictim
        Assert-True ($digestVictimBefore -ceq $digestVictimAfter) "directory digest reparse victim unchanged"

        $posOut = Resolve-SafeOutputPath -Explicit (Join-Path $tempRoot ("out-" + [guid]::NewGuid().ToString("n") + ".json"))
        Write-ProvenanceReport -Report $posReport -OutputPath $posOut | Out-Null
        Assert-True (Test-Path -LiteralPath $posOut) "output written to new path"

        Assert-Throws { Resolve-SafeOutputPath -Explicit $posOut } "reject pre-existing output path"

        $staleRoot = Join-Path $tempRoot "stale"
        New-Item -ItemType Directory -Force -Path $staleRoot | Out-Null
        Set-Content -LiteralPath (Join-Path $staleRoot ".gitattributes") -Value "drift-marker" -Encoding UTF8 -NoNewline
        $staleReport = Invoke-ProvenanceCollection -ProjectRoot $staleRoot -ToolkitRoot $toolkitRoot `
            -ManifestPath $miniManifest -SurfaceId "essential"
        Assert-True ($staleReport.completion_state -eq "stale") "stale exact completion"
        Assert-True ($staleReport.managed_content_digest -ne $staleReport.installed_digest) "stale digests differ"

        $partialRoot = Join-Path $tempRoot "partial"
        New-Item -ItemType Directory -Force -Path $partialRoot | Out-Null
        $partialReport = Invoke-ProvenanceCollection -ProjectRoot $partialRoot -ToolkitRoot $toolkitRoot `
            -ManifestPath $miniManifest -SurfaceId "essential"
        Assert-True ($partialReport.completion_state -eq "partial") "partial exact completion"
        Assert-True ($partialReport.managed_content_digest -ne $partialReport.installed_digest) "partial digests differ"

        $dirtyManifest = Join-Path $tempRoot "dirty-manifest.json"
        $dirtyObj = [ordered]@{
            schema_version = 1
            manifest_version = "v1-selftest"
            policies = @("managed", "structural-merge")
            entries = @(
                [ordered]@{
                    id = "managed-ga"
                    policy = "managed"
                    surface = "essential"
                    source = ".gitattributes"
                    destination = ".gitattributes"
                    bootstrap_ref = "selftest"
                },
                [ordered]@{
                    id = "merge-status"
                    policy = "structural-merge"
                    surface = "essential"
                    source = "docs/status.md"
                    destination = "docs/status.md"
                    bootstrap_ref = "selftest"
                }
            )
        }
        ($dirtyObj | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $dirtyManifest -Encoding UTF8
        $dirtyRoot = Join-Path $tempRoot "dirty"
        New-Item -ItemType Directory -Force -Path (Join-Path $dirtyRoot "docs") | Out-Null
        Copy-Item -LiteralPath (Join-Path $toolkitRoot ".gitattributes") -Destination (Join-Path $dirtyRoot ".gitattributes")
        Set-Content -LiteralPath (Join-Path $dirtyRoot "docs\status.md") -Value "# status ok" -Encoding UTF8
        Push-Location -LiteralPath $dirtyRoot
        try {
            $prevEap = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            & git init -q 2>$null | Out-Null
            & git add . 2>$null | Out-Null
            Add-Content -LiteralPath "docs\status.md" -Value "`n# drift noise" -Encoding UTF8
            $ErrorActionPreference = $prevEap
            $dirtyReport = Invoke-ProvenanceCollection -ProjectRoot $dirtyRoot -ToolkitRoot $toolkitRoot `
                -ManifestPath $dirtyManifest -SurfaceId "essential"
            $gaPath = $dirtyReport.paths | Where-Object { $_.destination -eq ".gitattributes" } | Select-Object -First 1
            Assert-True ($gaPath.result -eq "match") "dirty keeps managed path matching"
            Assert-True ($dirtyReport.dirty_relevance.git_dirty) "dirty git relevance on merge path"
            Assert-True ($dirtyReport.completion_state -eq "dirty") "dirty exact completion"
            Assert-True ($dirtyReport.completion_state -ne "stale") "dirty is not stale"
        } finally {
            Pop-Location
        }

        $legacyManifest = Join-Path $tempRoot "legacy-manifest.json"
        Write-MinimalManifest -Path $legacyManifest -DestRel ".gitattributes" -ManifestVersion "v0-legacy"
        $legacyReport = Invoke-ProvenanceCollection -ProjectRoot $posRoot -ToolkitRoot $toolkitRoot `
            -ManifestPath $legacyManifest -SurfaceId "essential"
        Assert-True ($legacyReport.completion_state -eq "legacy") "legacy exact completion from manifest version"

        $unknownManifest = Join-Path $tempRoot "unknown-policy.json"
        $obj = @{
            schema_version = 1
            manifest_version = "v1-selftest"
            entries = @(
                @{
                    id = "bad"
                    policy = "unknown-policy-x"
                    surface = "essential"
                    source = ".gitattributes"
                    destination = ".gitattributes"
                    bootstrap_ref = "selftest"
                }
            )
        }
        ($obj | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $unknownManifest -Encoding UTF8
        Assert-Throws {
            Invoke-ProvenanceCollection -ProjectRoot $posRoot -ToolkitRoot $toolkitRoot `
                -ManifestPath $unknownManifest -SurfaceId "essential" | Out-Null
        } "unknown policy fails closed"

        $blockManifest = Join-Path $tempRoot "block-manifest.json"
        Write-MinimalManifest -Path $blockManifest -DestRel "AGENTS.md" -SourceRel "templates/project-AGENTS.md" -Policy "managed-block"
        $blockRoot = Join-Path $tempRoot "block"
        New-Item -ItemType Directory -Force -Path $blockRoot | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $blockRoot "shipping") | Out-Null
        Copy-Item -LiteralPath (Join-Path $toolkitRoot "shipping\manifest.v1.json") -Destination (Join-Path $blockRoot "shipping\manifest.v1.json")
        Set-Content -LiteralPath (Join-Path $blockRoot "AGENTS.md") -Value @"
## Mission
Native toolkit AGENTS

## For agents
x
"@ -Encoding UTF8
        $blockReport = Invoke-ProvenanceCollection -ProjectRoot $blockRoot -ToolkitRoot $toolkitRoot `
            -ManifestPath $blockManifest -SurfaceId "essential"
        Assert-True ($blockReport.paths[0].result -eq "match") "managed-block native AGENTS not stale"

        $hookRel = ".cursor/hooks/session-start.ps1"
        $hookManifest = Join-Path $tempRoot "hook-block-manifest.json"
        Write-MinimalManifest -Path $hookManifest -DestRel $hookRel -SourceRel $hookRel -Policy "managed-block"
        $hookMatchRoot = Join-Path $tempRoot "hook-match"
        $hookMatchDir = Join-Path $hookMatchRoot ".cursor\hooks"
        New-Item -ItemType Directory -Force -Path $hookMatchDir | Out-Null
        Copy-Item -LiteralPath (Join-Path $toolkitRoot ".cursor\hooks\session-start.ps1") `
            -Destination (Join-Path $hookMatchDir "session-start.ps1")
        $hookMatchReport = Invoke-ProvenanceCollection -ProjectRoot $hookMatchRoot -ToolkitRoot $toolkitRoot `
            -ManifestPath $hookManifest -SurfaceId "essential"
        Assert-True ($hookMatchReport.paths[0].result -eq "match") "managed-block hook byte-identical match"
        Assert-True ($hookMatchReport.paths[0].strategy -eq "managed-block-hash-compare") "managed-block hook hash strategy"
        Assert-True ($hookMatchReport.completion_state -eq "success") "managed-block hook match success"

        $hookStaleRoot = Join-Path $tempRoot "hook-stale"
        $hookStaleDir = Join-Path $hookStaleRoot ".cursor\hooks"
        New-Item -ItemType Directory -Force -Path $hookStaleDir | Out-Null
        Copy-Item -LiteralPath (Join-Path $toolkitRoot ".cursor\hooks\session-start.ps1") `
            -Destination (Join-Path $hookStaleDir "session-start.ps1")
        Add-Content -LiteralPath (Join-Path $hookStaleDir "session-start.ps1") -Value "# drift" -Encoding UTF8
        $hookStaleReport = Invoke-ProvenanceCollection -ProjectRoot $hookStaleRoot -ToolkitRoot $toolkitRoot `
            -ManifestPath $hookManifest -SurfaceId "essential"
        Assert-True ($hookStaleReport.paths[0].result -eq "drift") "managed-block hook one-byte drift"
        Assert-True ($hookStaleReport.completion_state -eq "stale") "managed-block hook drift stale"

        $mergeManifest = Join-Path $tempRoot "merge-manifest.json"
        $mergeObj = [ordered]@{
            schema_version = 1
            manifest_version = "v1-selftest"
            policies = @("structural-merge")
            entries = @(
                [ordered]@{
                    id = "merge-hooks"
                    policy = "structural-merge"
                    surface = "essential"
                    source = ".cursor/hooks.json"
                    destination = ".cursor/hooks.json"
                    bootstrap_ref = "Merge-PapercutsHooks"
                }
            )
        }
        ($mergeObj | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $mergeManifest -Encoding UTF8
        $mergeRoot = Join-Path $tempRoot "merge"
        $hooksDir = Join-Path $mergeRoot ".cursor"
        New-Item -ItemType Directory -Force -Path $hooksDir | Out-Null
        Copy-Item -LiteralPath (Join-Path $toolkitRoot ".cursor\hooks.json") -Destination (Join-Path $hooksDir "hooks.json")
        $mergeReport = Invoke-ProvenanceCollection -ProjectRoot $mergeRoot -ToolkitRoot $toolkitRoot `
            -ManifestPath $mergeManifest -SurfaceId "essential"
        Assert-True ($mergeReport.paths[0].result -eq "match") "structural-merge hooks.json markers"

        $unicodeSeg = "test-" + [char]0x0442 + [char]0x0435 + [char]0x0441 + [char]0x0442
        $unicodeRoot = Join-Path $tempRoot ("bracket-[u]-" + $unicodeSeg)
        [void][System.IO.Directory]::CreateDirectory($unicodeRoot)
        Copy-Item -LiteralPath (Join-Path $toolkitRoot ".gitattributes") -Destination (Join-Path $unicodeRoot ".gitattributes")
        $uniReport = Invoke-ProvenanceCollection -ProjectRoot $unicodeRoot -ToolkitRoot $toolkitRoot `
            -ManifestPath $miniManifest -SurfaceId "essential"
        Assert-True ($uniReport.paths[0].result -eq "match") "unicode/bracket path match"

    } finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        Remove-OwnedOutputs
    }

    Write-Host ""
    if ($fail -eq 0) {
        Write-Host "PROVENANCE_COLLECT_SELFTEST_PASS"
        exit 0
    }
    Write-Host "PROVENANCE_COLLECT_SELFTEST_FAIL: $fail"
    exit 1
}

if ($SelfTest) {
    Invoke-SelfTest
    exit $LASTEXITCODE
}

$projectRoot = Resolve-ProjectRoot -Explicit $ProjectRoot
if ([string]::IsNullOrWhiteSpace($ToolkitRoot)) {
    $candidate = Join-Path $projectRoot "shipping\manifest.v1.json"
    if (Test-Path -LiteralPath $candidate) {
        $ToolkitRoot = $projectRoot
    }
}
if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    if (-not [string]::IsNullOrWhiteSpace($ToolkitRoot)) {
        $ManifestPath = Join-Path $ToolkitRoot "shipping\manifest.v1.json"
    } else {
        $ManifestPath = Join-Path $projectRoot "shipping\manifest.v1.json"
    }
}

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    Write-Host "PROVENANCE_COLLECT_MISSING_MANIFEST"
    exit 2
}

try {
    $resolvedOutput = Resolve-SafeOutputPath -Explicit $OutputPath
    $report = Invoke-ProvenanceCollection -ProjectRoot $projectRoot -ToolkitRoot $ToolkitRoot `
        -ManifestPath $ManifestPath -SurfaceId $SurfaceId
    Write-ProvenanceReport -Report $report -OutputPath $resolvedOutput | Out-Null
    Write-Host ("PROVENANCE_COLLECT_OK state=" + $report.completion_state + " output=invocation-owned")
    if ($report.completion_state -eq "success") { exit 0 }
    exit 1
} catch {
    Remove-OwnedOutputs
    Write-Host ("PROVENANCE_COLLECT_FAIL " + $_.Exception.Message)
    exit 2
}

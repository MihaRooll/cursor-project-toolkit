<#
.SYNOPSIS
  Shadow changed-path verification planner — selects Quick/Full check IDs from path globs; never runs CI.
  Toolkit-only; output is advisory plan JSON only. Wave 6 not graduated.
#>
param(
    [ValidateSet("worktree", "PR", "push", "dispatch")]
    [string]$Mode = "worktree",
    [string]$ChangeSpecPath = "",
    [string]$ChangeSpecJson = "",
    [string]$OutputPath = "",
    [string]$ProjectRoot = "",
    [switch]$SelfTest
)

$ErrorActionPreference = "Stop"
$ToolkitRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$GitRoot = if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ToolkitRoot
} else {
    (Resolve-Path -LiteralPath $ProjectRoot).Path
}
$ManifestPath = Join-Path $ToolkitRoot "shipping\verification-checks.v1.json"
$DefaultOutputRel = ".cursor/planner-local"
$ForbiddenFields = @(
    "raw_prompt", "raw_log", "username", "hostname", "absolute_path", "private_path", "email", "secrets"
)
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

function Read-Text([string]$Path) {
    return [System.IO.File]::ReadAllText($Path, (New-Object System.Text.UTF8Encoding $false))
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

function Assert-OwnedOutputPath([string]$Path) {
    if ($script:OwnedOutputPaths -notcontains $Path) {
        throw "output path not invocation-owned"
    }
}

function Test-StringLooksLikePath([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    if ($Value -match '(?i)^[A-Za-z]:[/\\]') { return $true }
    if ($Value -match '(?i)^\\\\[^\\]+\\') { return $true }
    if ($Value -match '(?i)^/(Users|home)(/|$)') { return $true }
    if ($Value -match '(?i)/Users/') { return $true }
    if ($Value -match '(?i)/home/') { return $true }
    return $false
}

function Test-PrivacyPath([string]$Path) {
    if (Test-StringLooksLikePath -Value $Path) {
        throw ("privacy: absolute path rejected")
    }
}

function Test-PlanPrivacyNode {
    param(
        $Node,
        [string]$KeyName = ""
    )
    if ($null -eq $Node) { return }
    if (-not [string]::IsNullOrWhiteSpace($KeyName)) {
        foreach ($forbidden in $ForbiddenFields) {
            if ($KeyName -ceq $forbidden) {
                throw ("privacy: forbidden field in plan output: " + $KeyName)
            }
        }
    }
    if ($Node -is [string]) {
        if (Test-StringLooksLikePath -Value $Node) {
            throw ("privacy: absolute path in plan value key=" + $KeyName)
        }
        return
    }
    if ($Node -is [System.Collections.IDictionary]) {
        foreach ($k in @($Node.Keys)) {
            Test-PlanPrivacyNode -Node $Node[$k] -KeyName ([string]$k)
        }
        return
    }
    if ($Node -is [System.Management.Automation.PSObject]) {
        foreach ($p in @($Node.PSObject.Properties)) {
            Test-PlanPrivacyNode -Node $p.Value -KeyName ([string]$p.Name)
        }
        return
    }
    if ($Node -is [System.Collections.IEnumerable]) {
        foreach ($item in @($Node)) {
            Test-PlanPrivacyNode -Node $item -KeyName $KeyName
        }
    }
}

function Assert-TriggersInManifest {
    param(
        $Manifest,
        [string[]]$Triggers
    )
    $allowed = @($Manifest.conservative_full_triggers | ForEach-Object { [string]$_ })
    foreach ($t in @($Triggers)) {
        if ($allowed -notcontains [string]$t) {
            throw ("planner trigger not in manifest conservative_full_triggers: " + $t)
        }
    }
}

function Normalize-RepoPath([string]$Path) {
    if ($null -eq $Path) { return "" }
    if ($Path.Length -eq 0) { return "" }
    $p = $Path -replace '\\', '/'
    if ($p.StartsWith("./")) { $p = $p.Substring(2) }
    while ($p.StartsWith("/")) { $p = $p.Substring(1) }
    return $p
}

function Test-PathMatchesGlob {
    param([string]$Path, [string]$Glob)
    $norm = Normalize-RepoPath $Path
    $g = Normalize-RepoPath $Glob
    if ($g -eq "**" -or $g -eq "*") { return $true }
    $regex = ($g -replace '\.', '\.' -replace '\*\*', '<<GS>>' -replace '\*', '[^/]*' -replace '\?', '.')
    $regex = $regex -replace '<<GS>>', '.*'
    if (-not $regex.EndsWith('.*') -and $g.EndsWith('/**')) {
        $regex = $regex.Substring(0, $regex.Length - 3) + '(/.*)?'
    }
    return ($norm -cmatch ("^(?i)" + $regex + "$"))
}

function Get-ManifestDocument {
    if (-not (Test-Path -LiteralPath $ManifestPath)) { throw "manifest missing" }
    return (Read-Text $ManifestPath | ConvertFrom-Json)
}

function Get-AllCheckIds($Manifest) {
    return @($Manifest.checks | ForEach-Object { [string]$_.id })
}

function Get-QuickCheckIds($Manifest) {
    return @($Manifest.checks | Where-Object { [string]$_.profile -eq "quick" } | ForEach-Object { [string]$_.id })
}

function Get-FullOracleCheckIds($Manifest) {
    return @($Manifest.checks | Where-Object { [string]$_.profile -eq "full-oracle" } | ForEach-Object { [string]$_.id })
}

function Get-FullOracleStageIds($Manifest) {
    $all = @()
    $all += Get-QuickCheckIds $Manifest
    $all += Get-FullOracleCheckIds $Manifest
    return @($all | Select-Object -Unique)
}

function Invoke-GitBytes {
    param(
        [string[]]$GitArgs,
        [int]$MaxStdoutBytes = 4194304,
        [int]$MaxStderrBytes = 65536
    )
    if (-not (Test-Path -LiteralPath $GitRoot)) {
        return @{ Stdout = [byte[]]@(); Stderr = [byte[]]@(); ExitCode = -1; Bounded = $false }
    }
    $stdoutTmp = [System.IO.Path]::GetTempFileName()
    $stderrTmp = [System.IO.Path]::GetTempFileName()
    try {
        $proc = Start-Process -FilePath "git" -ArgumentList @($GitArgs) `
            -WorkingDirectory $GitRoot `
            -RedirectStandardOutput $stdoutTmp -RedirectStandardError $stderrTmp `
            -NoNewWindow -Wait -PassThru
        if ($null -eq $proc) {
            return @{ Stdout = [byte[]]@(); Stderr = [byte[]]@(); ExitCode = -1; Bounded = $false }
        }
        $stdout = @()
        $stderr = @()
        if (Test-Path -LiteralPath $stdoutTmp) {
            $stdout = [System.IO.File]::ReadAllBytes($stdoutTmp)
            if ($stdout.Length -gt $MaxStdoutBytes) {
                return @{ Stdout = [byte[]]@(); Stderr = [byte[]]@(); ExitCode = -1; Bounded = $true }
            }
        }
        if (Test-Path -LiteralPath $stderrTmp) {
            $stderr = [System.IO.File]::ReadAllBytes($stderrTmp)
            if ($stderr.Length -gt $MaxStderrBytes) {
                $stderr = $stderr[0..($MaxStderrBytes - 1)]
            }
        }
        return @{ Stdout = $stdout; Stderr = $stderr; ExitCode = [int]$proc.ExitCode; Bounded = $false }
    } finally {
        Remove-Item -LiteralPath $stdoutTmp -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $stderrTmp -Force -ErrorAction SilentlyContinue
    }
}

function Split-Utf8NulTokens {
    param([byte[]]$RawBytes)
    $tokens = New-Object System.Collections.Generic.List[byte[]]
    if ($null -eq $RawBytes -or $RawBytes.Length -eq 0) { return $tokens }
    $start = 0
    for ($i = 0; $i -le $RawBytes.Length; $i++) {
        if ($i -eq $RawBytes.Length -or $RawBytes[$i] -eq 0) {
            if ($i -gt $start) {
                $len = $i - $start
                $seg = New-Object byte[] $len
                [System.Array]::Copy($RawBytes, $start, $seg, 0, $len)
                [void]$tokens.Add($seg)
            }
            $start = $i + 1
        }
    }
    return ,$tokens
}

function Decode-Utf8PathBytes {
    param([byte[]]$Bytes)
    if ($null -eq $Bytes -or $Bytes.Length -eq 0) { return "" }
    $offset = 0
    if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) {
        $offset = 3
    }
    return [System.Text.Encoding]::UTF8.GetString($Bytes, $offset, $Bytes.Length - $offset)
}

function Test-XyMergeConflict {
    param([string]$Xy)
    return ($Xy -in @("DD", "AU", "UA", "DU", "UD", "AA", "UU"))
}

function Test-PorcelainRenameCopy {
    param([string]$Xy)
    if ([string]::IsNullOrWhiteSpace($Xy) -or $Xy.Length -lt 2) { return $false }
    return ($Xy[0] -in @('R', 'C') -or $Xy[1] -in @('R', 'C'))
}

function Parse-GitPorcelainZ {
    param([byte[]]$RawBytes)
    $entries = New-Object System.Collections.Generic.List[hashtable]
    if ($null -eq $RawBytes -or $RawBytes.Length -eq 0) { return $entries }

    $tokens = Split-Utf8NulTokens -RawBytes $RawBytes
    $i = 0
    while ($i -lt $tokens.Count) {
        $recText = Decode-Utf8PathBytes -Bytes $tokens[$i]
        $i++
        if ([string]::IsNullOrWhiteSpace($recText)) { continue }
        if ($recText.Length -lt 4 -or $recText[2] -ne ' ') { continue }

        $xy = $recText.Substring(0, 2)
        $path = $recText.Substring(3)
        $path2 = $null
        $class = "modified"

        if ($xy -eq '??') {
            $class = "untracked"
        } elseif ($xy -match '^(.)(.)' -and $Matches[1] -eq 'D' -and $Matches[2] -eq ' ') {
            $class = "deleted"
        } elseif ($xy -match '^(.)(.)' -and $Matches[2] -eq 'D' -and $Matches[1] -eq ' ') {
            $class = "deleted"
        } elseif (Test-PorcelainRenameCopy -Xy $xy) {
            $class = "renamed"
            if ($i -ge $tokens.Count) { throw "porcelain: rename missing old path" }
            $path2 = Decode-Utf8PathBytes -Bytes $tokens[$i]
            $i++
        } elseif ($xy[0] -eq 'A' -or $xy[1] -eq 'A') {
            $class = "added"
        } elseif ($xy[0] -eq '?' -or $xy[1] -eq '?') {
            $class = "untracked"
        }

        $staged = ($xy[0] -ne ' ' -and $xy[0] -ne '?')
        $unstaged = ($xy[1] -ne ' ' -and $xy[1] -ne '?')
        [void]$entries.Add(@{
            xy = $xy
            path = (Normalize-RepoPath $path)
            path2 = $(if ($null -ne $path2) { Normalize-RepoPath $path2 } else { $null })
            class = $class
            staged = $staged
            unstaged = $unstaged
            merge_conflict = (Test-XyMergeConflict -Xy $xy)
        })
    }
    return ,@($entries.ToArray())
}

function Test-UnmergedIndex {
    $ls = Invoke-GitBytes -GitArgs @("ls-files", "-u", "-z")
    if ($ls.Bounded) { return @{ conflict = $false; parse_error = $true } }
    if ($ls.ExitCode -ne 0) { return @{ conflict = $false; parse_error = $true } }
    $tokens = Split-Utf8NulTokens -RawBytes $ls.Stdout
    return @{ conflict = ($tokens.Count -gt 0); parse_error = $false }
}

function Get-GitChangedEntries {
    $gitDir = Join-Path $GitRoot ".git"
    if (-not (Test-Path -LiteralPath $gitDir)) {
        return @{
            entries = @()
            missing_history = $true
            merge_conflict = $false
            parse_error = $false
            gather_error_code = $null
        }
    }

    $hist = Invoke-GitBytes -GitArgs @("rev-parse", "--verify", "HEAD")
    if ($hist.Bounded) {
        return @{ entries = @(); missing_history = $false; merge_conflict = $false; parse_error = $true; gather_error_code = "parse_error" }
    }
    $missingHistory = ($hist.ExitCode -ne 0)

    $statusProc = Invoke-GitBytes -GitArgs @("status", "--porcelain=v1", "-z")
    if ($statusProc.Bounded) {
        return @{ entries = @(); missing_history = $missingHistory; merge_conflict = $false; parse_error = $true; gather_error_code = "parse_error" }
    }
    if ($statusProc.ExitCode -ne 0) {
        return @{ entries = @(); missing_history = $missingHistory; merge_conflict = $false; parse_error = $true; gather_error_code = "parse_error" }
    }

    try {
        $parsed = Parse-GitPorcelainZ -RawBytes $statusProc.Stdout
    } catch {
        return @{ entries = @(); missing_history = $missingHistory; merge_conflict = $false; parse_error = $true; gather_error_code = "parse_error" }
    }

    $conflict = $false
    foreach ($e in @($parsed)) {
        if ([bool]$e.merge_conflict) { $conflict = $true; break }
    }
    $unmerged = Test-UnmergedIndex
    if ($unmerged.parse_error) {
        return @{ entries = @(); missing_history = $missingHistory; merge_conflict = $false; parse_error = $true; gather_error_code = "parse_error" }
    }
    if ($unmerged.conflict) { $conflict = $true }

    return @{
        entries = @($parsed)
        missing_history = $missingHistory
        merge_conflict = $conflict
        parse_error = $false
        gather_error_code = $null
    }
}

function Expand-ChangeEntries {
    param(
        $RawEntries,
        [switch]$StrictPrivacy
    )
    $expanded = New-Object System.Collections.Generic.List[hashtable]
    foreach ($e in @($RawEntries)) {
        $path = [string]$e.path
        try {
            Test-PrivacyPath -Path $path
        } catch {
            if ($StrictPrivacy) { throw }
            return @{ entries = @(); privacy_error = $true }
        }
        if ($e.class -eq "renamed" -and -not [string]::IsNullOrWhiteSpace([string]$e.path2)) {
            try {
                Test-PrivacyPath -Path ([string]$e.path2)
            } catch {
                if ($StrictPrivacy) { throw }
                return @{ entries = @(); privacy_error = $true }
            }
            [void]$expanded.Add(@{
                path = [string]$e.path
                class = "renamed_new"
                staged = [bool]$e.staged
                unstaged = [bool]$e.unstaged
            })
            [void]$expanded.Add(@{
                path = [string]$e.path2
                class = "renamed_old"
                staged = [bool]$e.staged
                unstaged = [bool]$e.unstaged
            })
        } else {
            [void]$expanded.Add(@{
                path = $path
                class = [string]$e.class
                staged = [bool]$e.staged
                unstaged = [bool]$e.unstaged
            })
        }
    }
    return @{ entries = @($expanded); privacy_error = $false }
}

function Parse-ChangeSpecJson {
    param(
        [string]$JsonText,
        [switch]$Strict
    )
    try {
        $obj = $JsonText | ConvertFrom-Json
    } catch {
        if ($Strict) { throw "parse_error: change spec invalid json" }
        return @{
            entries = @()
            missing_history = $false
            merge_conflict = $false
            parse_error = $true
            unknown_event = $false
            gather_error_code = "parse_error"
            mode_override = $null
        }
    }
    $entries = New-Object System.Collections.Generic.List[hashtable]
    foreach ($item in @($obj.paths)) {
        [void]$entries.Add(@{
            path = (Normalize-RepoPath ([string]$item.path))
            class = [string]$item.class
            staged = $(if ($null -ne $item.staged) { [bool]$item.staged } else { $true })
            unstaged = $(if ($null -ne $item.unstaged) { [bool]$item.unstaged } else { $false })
        })
    }
    $flags = $obj.flags
    $modeOverride = $null
    $unknownEvent = $false
    if ($null -ne $obj.mode) {
        $modeOverride = [string]$obj.mode
        $validModes = @("worktree", "PR", "push", "dispatch")
        if ($validModes -notcontains $modeOverride) { $unknownEvent = $true }
    }
    if ($null -ne $flags -and $null -ne $flags.unknown_event -and [bool]$flags.unknown_event) {
        $unknownEvent = $true
    }
    return @{
        entries = @($entries)
        missing_history = $(if ($null -ne $flags -and $null -ne $flags.missing_history) { [bool]$flags.missing_history } else { $false })
        merge_conflict = $(if ($null -ne $flags -and $null -ne $flags.merge_conflict) { [bool]$flags.merge_conflict } else { $false })
        parse_error = $(if ($null -ne $flags -and $null -ne $flags.parse_error) { [bool]$flags.parse_error } else { $false })
        unknown_event = $unknownEvent
        gather_error_code = $null
        mode_override = $modeOverride
    }
}

function Test-PathUnderRepo {
    param([string]$Path)
    $norm = Normalize-RepoPath $Path
    if ([string]::IsNullOrWhiteSpace($norm)) { return $false }
    if ($norm -match '(?i)^(\.\./|\.\.)') { return $false }
    if ($norm -match '(?i)^(Users|home)/') { return $false }
    if ($norm -match '(?i)^[A-Za-z]:') { return $false }
    if ($norm -match '[\x00-\x1f]') { return $false }
    return $true
}

function Test-PathMatchesRegisteredCheckGlob {
    param([string]$Path, $Manifest)
    foreach ($check in @($Manifest.checks)) {
        foreach ($glob in @($check.path_globs)) {
            if (Test-PathMatchesGlob -Path $Path -Glob ([string]$glob)) { return $true }
        }
    }
    return $false
}

function Test-FullTriggerGlob {
    param([string]$Path, $Manifest)
    foreach ($glob in @($Manifest.full_trigger_globs)) {
        if (Test-PathMatchesGlob -Path $Path -Glob ([string]$glob)) { return $true }
    }
    return $false
}

function Test-ReleaseTriggerPath {
    param([string]$Path, $Manifest)
    $pn = Normalize-RepoPath $Path
    $globs = @()
    if ($null -ne $Manifest.PSObject.Properties['release_trigger_globs']) {
        $globs = @($Manifest.release_trigger_globs)
    }
    foreach ($glob in $globs) {
        if (Test-PathMatchesGlob -Path $pn -Glob ([string]$glob)) { return $true }
    }
    return $false
}

function Resolve-ConservativeTriggers {
    param(
        [string]$ModeName,
        $Manifest,
        [hashtable]$GatherMeta,
        [object[]]$Entries
    )
    $fired = New-Object System.Collections.Generic.List[string]
    if ($GatherMeta.missing_history) { [void]$fired.Add("missing_history") }
    if ($GatherMeta.merge_conflict) { [void]$fired.Add("merge_conflict") }
    if ($GatherMeta.parse_error) { [void]$fired.Add("parse_error") }
    if ($GatherMeta.unknown_event) { [void]$fired.Add("unknown_event") }

    switch ($ModeName) {
        "PR" { [void]$fired.Add("pre_merge") }
        "push" { [void]$fired.Add("push_main") }
        "dispatch" { [void]$fired.Add("dispatch_explicit") }
    }

    $unknown = $false
    $release = $false
    foreach ($e in @($Entries)) {
        $p = [string]$e.path
        if (-not (Test-PathUnderRepo -Path $p)) {
            $unknown = $true
            continue
        }
        if (-not (Test-PathMatchesRegisteredCheckGlob -Path $p -Manifest $Manifest)) {
            $unknown = $true
        }
        if (Test-ReleaseTriggerPath -Path $p -Manifest $Manifest) {
            $release = $true
        }
        if (Test-FullTriggerGlob -Path $p -Manifest $Manifest) {
            $pn = Normalize-RepoPath $p
            if ($pn.StartsWith(".github/workflows/", [StringComparison]::OrdinalIgnoreCase)) {
                [void]$fired.Add("workflow_change")
            } elseif ($pn -ieq "scripts/smoke-bootstrap.ps1") {
                [void]$fired.Add("bootstrap_change")
            } elseif ($pn.StartsWith("shipping/", [StringComparison]::OrdinalIgnoreCase)) {
                [void]$fired.Add("shipping_manifest_change")
            } elseif ($pn -ieq "scripts/plan-verification.ps1" -or $pn.StartsWith("shipping/verification-checks", [StringComparison]::OrdinalIgnoreCase)) {
                [void]$fired.Add("planner_change")
            } elseif ($pn.StartsWith("plugin/", [StringComparison]::OrdinalIgnoreCase)) {
                [void]$fired.Add("plugin_mirror_change")
            } elseif ($pn.EndsWith("contracts.md", [StringComparison]::OrdinalIgnoreCase) -or $pn.StartsWith("schemas/", [StringComparison]::OrdinalIgnoreCase) -or $pn.StartsWith("subagents/", [StringComparison]::OrdinalIgnoreCase)) {
                [void]$fired.Add("shared_contract_change")
            } else {
                [void]$fired.Add("bootstrap_change")
            }
        }
    }
    if ($unknown) { [void]$fired.Add("unknown_path") }
    if ($release) { [void]$fired.Add("release") }

    return @($fired | Select-Object -Unique)
}

function Select-ChecksForPaths {
    param(
        $Manifest,
        [object[]]$Entries
    )
    $selected = New-Object System.Collections.Generic.HashSet[string]
    $paths = @($Entries | ForEach-Object { [string]$_.path } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($paths.Count -eq 0) {
        return @()
    }
    $quickChecks = @($Manifest.checks | Where-Object { [string]$_.profile -eq "quick" })
    foreach ($check in @($quickChecks)) {
        $id = [string]$check.id
        foreach ($glob in @($check.path_globs)) {
            foreach ($p in $paths) {
                if (Test-PathMatchesGlob -Path $p -Glob ([string]$glob)) {
                    [void]$selected.Add($id)
                    break
                }
            }
        }
    }
    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($check in @($quickChecks)) {
            $id = [string]$check.id
            if ($selected.Contains($id)) {
                foreach ($dep in @($check.dependencies)) {
                    if (-not $selected.Contains([string]$dep)) {
                        [void]$selected.Add([string]$dep)
                        $changed = $true
                    }
                }
            }
        }
    }
    return @($selected | Sort-Object)
}

function New-VerificationPlan {
    param(
        [string]$ModeName,
        $Manifest,
        [hashtable]$GatherMeta,
        [object[]]$Entries
    )
    $triggers = Resolve-ConservativeTriggers -ModeName $ModeName -Manifest $Manifest -GatherMeta $GatherMeta -Entries $Entries
    Assert-TriggersInManifest -Manifest $Manifest -Triggers @($triggers)
    $conservativeFull = ($triggers.Count -gt 0)
    $quickIds = Get-QuickCheckIds $Manifest
    $fullOracleIds = Get-FullOracleCheckIds $Manifest
    $fullOracleStageIds = Get-FullOracleStageIds $Manifest

    if ($conservativeFull) {
        $selected = @($fullOracleStageIds)
        $profile = "Full"
    } else {
        $selected = Select-ChecksForPaths -Manifest $Manifest -Entries $Entries
        if ($selected.Count -eq 0) {
            $selected = @("Q-PARSE")
        }
        $profile = "Quick"
    }

    $pathClasses = @{}
    foreach ($e in @($Entries)) {
        $pathClasses[[string]$e.path] = [string]$e.class
    }

    $selectorMiss = $false
    if ($conservativeFull) {
        foreach ($req in @($fullOracleStageIds)) {
            if ($selected -notcontains $req) { $selectorMiss = $true }
        }
    } else {
        foreach ($id in @($selected)) {
            $sid = [string]$id
            if ($fullOracleIds -contains $sid) { $selectorMiss = $true; break }
            if ($quickIds -notcontains $sid) { $selectorMiss = $true; break }
        }
    }

    return [ordered]@{
        schema_version = 1
        planner_version = "v1"
        mode = $ModeName
        promotion_status = "evidence_pending"
        graduation_eligible = $false
        graduation_gates = $Manifest.graduation_gates
        current_full_runtime_observed = [string]$Manifest.current_full_runtime_observed
        recommended_profile = $profile
        conservative_full = $conservativeFull
        full_triggers_fired = @($triggers)
        changed_paths = @($Entries | ForEach-Object { [string]$_.path } | Select-Object -Unique)
        path_classes = $pathClasses
        selected_check_ids = @($selected)
        full_oracle_check_ids = @($fullOracleStageIds)
        quick_check_ids = @($quickIds)
        full_oracle_only_ids = @($fullOracleIds)
        selector_miss = $selectorMiss
        gather_error_code = $(if ($GatherMeta.gather_error_code) { [string]$GatherMeta.gather_error_code } else { $null })
        shadow_only = $true
        runs_checks = $false
        skips_checks = $false
        gates_ci = $false
        live_ci_changes = $false
        pin_or_cost_change = $false
    }
}

function Register-OwnedOutputPath {
    param(
        [string]$ExplicitOutput,
        [string]$FileName
    )
    if (-not [string]::IsNullOrWhiteSpace($ExplicitOutput)) {
        $path = [System.IO.Path]::GetFullPath($ExplicitOutput)
        Assert-NoReparseInPath -Path $path -Label "planner output"
        $dir = Split-Path -Parent $path
        if (-not [string]::IsNullOrWhiteSpace($dir)) {
            Assert-NoReparseInPath -Path $dir -Label "planner directory"
        }
        [void]$script:OwnedOutputPaths.Add($path)
        return $path
    }
    $dir = Join-Path $GitRoot ($DefaultOutputRel -replace '/', '\')
    Assert-NoReparseInPath -Path $dir -Label "planner root"
    if (-not (Test-Path -LiteralPath $dir)) {
        [void][System.IO.Directory]::CreateDirectory($dir)
    }
    $path = Join-Path $dir $FileName
    Assert-NoReparseInPath -Path $path -Label "planner target"
    [void]$script:OwnedOutputPaths.Add($path)
    return $path
}

function Write-PlanCreateNew {
    param([string]$OutputPath, [string]$JsonText)
    Assert-OwnedOutputPath -Path $OutputPath
    try {
        Test-PlanPrivacyNode -Node ($JsonText | ConvertFrom-Json)
    } catch {
        throw ("privacy: plan output rejected: " + $_.Exception.Message)
    }
    $dir = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -LiteralPath $dir)) {
        [void][System.IO.Directory]::CreateDirectory($dir)
    }
    $payload = (($JsonText -split "`r?`n" | ForEach-Object { $_.TrimEnd() }) -join "`n") + "`n"
    try {
        $fs = New-Object System.IO.FileStream($OutputPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
            $fs.Write($bytes, 0, $bytes.Length)
        } finally {
            $fs.Dispose()
        }
    } catch [System.IO.IOException] {
        throw "duplicate output file exists"
    }
}

function Test-ToolkitOnlySurface {
    $smokePath = Join-Path $ToolkitRoot "scripts\smoke-bootstrap.ps1"
    if (-not (Test-Path -LiteralPath $smokePath)) { return }
    $smokeText = Read-Text $smokePath
    foreach ($token in @(
        '"scripts\\plan-verification.ps1"',
        '"shipping\\verification-checks.v1.json"',
        '"tests\\planner"'
    )) {
        if ($smokeText.Contains($token)) {
            throw ("toolkit: planner surface must not appear in bootstrap copy lists: " + $token)
        }
    }
}

function Compare-PlanToOracle {
    param(
        $Plan,
        [string]$ExpectedProfile,
        [string[]]$ExpectedTriggers,
        [string[]]$MustInclude,
        [bool]$ExpectConservativeFull,
        [bool]$MustNotIncludeFullOracleOnly = $false
    )
    if ([string]$Plan.recommended_profile -cne $ExpectedProfile) {
        throw ("oracle mismatch profile expected=" + $ExpectedProfile + " got=" + $Plan.recommended_profile)
    }
    if ([bool]$Plan.conservative_full -ne $ExpectConservativeFull) {
        throw "oracle mismatch conservative_full"
    }
    foreach ($t in @($ExpectedTriggers)) {
        if (@($Plan.full_triggers_fired) -notcontains $t) {
            throw ("oracle missing trigger=" + $t)
        }
    }
    foreach ($id in @($MustInclude)) {
        if (@($Plan.selected_check_ids) -notcontains $id) {
            throw ("oracle missing check=" + $id)
        }
    }
    if ([bool]$Plan.selector_miss) {
        throw "oracle selector_miss true"
    }
    if ($ExpectConservativeFull) {
        foreach ($req in @($Plan.full_oracle_check_ids)) {
            if (@($Plan.selected_check_ids) -notcontains $req) {
                throw ("oracle full miss check=" + $req)
            }
        }
    }
    if ($MustNotIncludeFullOracleOnly) {
        foreach ($oid in @($Plan.full_oracle_only_ids)) {
            if (@($Plan.selected_check_ids) -contains [string]$oid) {
                throw ("oracle must not include full-oracle-only=" + $oid)
            }
        }
    }
}

function Invoke-SelfTest {
    $script:Fail = 0
    function Assert-ThrowsMsg($scriptBlock, [string]$Token, [string]$Msg) {
        $threw = $false
        $err = ""
        try { & $scriptBlock } catch { $threw = $true; $err = $_.Exception.Message }
        if (-not $threw) { Fail ($Msg + " (no throw)"); return }
        if ($err -notlike ("*" + $Token + "*")) { Fail ($Msg + " token=" + $Token + " got=" + $err); return }
        Pass $Msg
    }

    Write-Host "=== plan-verification SelfTest ==="
    Test-ToolkitOnlySurface
    Pass "toolkit-only surface"

    $manifest = Get-ManifestDocument
    Assert-True ($manifest.checks.Count -ge 26) "manifest check count"
    Assert-True ([string]$manifest.current_full_runtime_observed -eq "2m25s") "observed full runtime documented"

    $docsOnly = @{
        paths = @(@{ path = "docs/README.md"; class = "modified"; staged = $true })
        flags = @{ missing_history = $false; merge_conflict = $false; parse_error = $false }
    } | ConvertTo-Json -Depth 6 -Compress
    $docsMeta = Parse-ChangeSpecJson -JsonText $docsOnly -Strict
    $docsExpanded = Expand-ChangeEntries -RawEntries $docsMeta.entries -StrictPrivacy
    $docsPlan = New-VerificationPlan -ModeName "worktree" -Manifest $manifest -GatherMeta $docsMeta -Entries $docsExpanded.entries
    Compare-PlanToOracle -Plan $docsPlan -ExpectedProfile "Quick" -ExpectedTriggers @() -MustInclude @("Q-DOCS-ST", "Q-DOCS-LIVE") -ExpectConservativeFull $false -MustNotIncludeFullOracleOnly $true
    foreach ($oid in @($docsPlan.full_oracle_only_ids)) {
        Assert-True (@($docsPlan.selected_check_ids) -notcontains [string]$oid) "docs-only excludes full-oracle-only $oid"
    }
    Assert-True (-not [bool]$docsPlan.selector_miss) "docs-only no selector_miss"
    Pass "docs-only Quick subset"

    $templatesOnly = @{
        paths = @(@{ path = "templates/first-chat.md"; class = "modified"; staged = $true })
        flags = @{}
    } | ConvertTo-Json -Depth 6 -Compress
    $tplMeta = Parse-ChangeSpecJson -JsonText $templatesOnly -Strict
    $tplExpanded = Expand-ChangeEntries -RawEntries $tplMeta.entries -StrictPrivacy
    $tplPlan = New-VerificationPlan -ModeName "worktree" -Manifest $manifest -GatherMeta $tplMeta -Entries $tplExpanded.entries
    Assert-True ([string]$tplPlan.recommended_profile -eq "Quick") "templates-only Quick profile"
    foreach ($oid in @($tplPlan.full_oracle_only_ids)) {
        Assert-True (@($tplPlan.selected_check_ids) -notcontains [string]$oid) "templates-only excludes full-oracle-only $oid"
    }
    Assert-True (-not [bool]$tplPlan.selector_miss) "templates-only no profile bleed"
    Pass "templates counterexample Quick only"

    $sourcesOnly = @{
        paths = @(@{ path = "SOURCES.md"; class = "modified"; staged = $true })
        flags = @{}
    } | ConvertTo-Json -Depth 6 -Compress
    $srcMeta = Parse-ChangeSpecJson -JsonText $sourcesOnly -Strict
    $srcExpanded = Expand-ChangeEntries -RawEntries $srcMeta.entries -StrictPrivacy
    $srcPlan = New-VerificationPlan -ModeName "worktree" -Manifest $manifest -GatherMeta $srcMeta -Entries $srcExpanded.entries
    Assert-True ([string]$srcPlan.recommended_profile -eq "Quick") "SOURCES.md Quick profile"
    Assert-True (-not [bool]$srcPlan.conservative_full) "SOURCES.md not conservative Full"
    Pass "SOURCES registry path mapped"

    $licenseOnly = @{
        paths = @(@{ path = "LICENSE"; class = "modified"; staged = $true })
        flags = @{}
    } | ConvertTo-Json -Depth 6 -Compress
    $licMeta = Parse-ChangeSpecJson -JsonText $licenseOnly -Strict
    $licExpanded = Expand-ChangeEntries -RawEntries $licMeta.entries -StrictPrivacy
    $licPlan = New-VerificationPlan -ModeName "worktree" -Manifest $manifest -GatherMeta $licMeta -Entries $licExpanded.entries
    Compare-PlanToOracle -Plan $licPlan -ExpectedProfile "Full" -ExpectedTriggers @("unknown_path") -MustInclude @("Q-PARSE") -ExpectConservativeFull $true
    Pass "LICENSE unknown_path conservative Full"

    $bracketOnly = @{
        paths = @(@{ path = "scripts/project-doctor.ps1"; class = "modified"; staged = $true })
        flags = @{}
    } | ConvertTo-Json -Depth 6 -Compress
    $brMeta = Parse-ChangeSpecJson -JsonText $bracketOnly -Strict
    $brExpanded = Expand-ChangeEntries -RawEntries $brMeta.entries -StrictPrivacy
    $brPlan = New-VerificationPlan -ModeName "worktree" -Manifest $manifest -GatherMeta $brMeta -Entries $brExpanded.entries
    Assert-True ([string]$brPlan.recommended_profile -eq "Quick") "project-doctor Quick profile"
    Assert-True (@($brPlan.selected_check_ids) -contains "Q-DOC-BRACKET") "project-doctor selects bracket check"
    foreach ($oid in @($brPlan.full_oracle_only_ids)) {
        Assert-True (@($brPlan.selected_check_ids) -notcontains [string]$oid) "project-doctor excludes full-oracle-only"
    }
    Pass "project-doctor counterexample Quick only"

    $workflow = @{
        paths = @(@{ path = ".github/workflows/toolkit-verify.yml"; class = "modified"; staged = $true })
        flags = @{}
    } | ConvertTo-Json -Depth 6 -Compress
    $wfMeta = Parse-ChangeSpecJson -JsonText $workflow -Strict
    $wfExpanded = Expand-ChangeEntries -RawEntries $wfMeta.entries -StrictPrivacy
    $wfPlan = New-VerificationPlan -ModeName "worktree" -Manifest $manifest -GatherMeta $wfMeta -Entries $wfExpanded.entries
    Compare-PlanToOracle -Plan $wfPlan -ExpectedProfile "Full" -ExpectedTriggers @("workflow_change") -MustInclude @("Q-PARSE", "F-ESSENTIAL") -ExpectConservativeFull $true
    Pass "workflow change conservative Full"

    $prPlan = New-VerificationPlan -ModeName "PR" -Manifest $manifest -GatherMeta @{
        missing_history = $false; merge_conflict = $false; parse_error = $false; unknown_event = $false; gather_error_code = $null
    } -Entries @(@{ path = "README.md"; class = "modified"; staged = $true })
    Compare-PlanToOracle -Plan $prPlan -ExpectedProfile "Full" -ExpectedTriggers @("pre_merge") -MustInclude @("Q-PARSE") -ExpectConservativeFull $true
    Pass "PR mode pre_merge Full"

    $rename = @{
        paths = @(
            @{ path = "scripts/old-name.ps1"; class = "renamed_old"; staged = $true }
            @{ path = "scripts/new-name.ps1"; class = "renamed_new"; staged = $true }
        )
        flags = @{}
    } | ConvertTo-Json -Depth 6 -Compress
    $renMeta = Parse-ChangeSpecJson -JsonText $rename -Strict
    $renExpanded = Expand-ChangeEntries -RawEntries $renMeta.entries -StrictPrivacy
    $renPlan = New-VerificationPlan -ModeName "worktree" -Manifest $manifest -GatherMeta $renMeta -Entries $renExpanded.entries
    Assert-True ($renPlan.selected_check_ids -contains "Q-PARSE") "rename selects parse"
    Pass "rename old+new paths"

    $unknown = @{
        paths = @(@{ path = "../outside-repo/leak.txt"; class = "modified"; staged = $true })
        flags = @{}
    } | ConvertTo-Json -Depth 6 -Compress
    $unkMeta = Parse-ChangeSpecJson -JsonText $unknown -Strict
    $unkExpanded = Expand-ChangeEntries -RawEntries $unkMeta.entries -StrictPrivacy
    $unkPlan = New-VerificationPlan -ModeName "worktree" -Manifest $manifest -GatherMeta $unkMeta -Entries $unkExpanded.entries
    Compare-PlanToOracle -Plan $unkPlan -ExpectedProfile "Full" -ExpectedTriggers @("unknown_path") -MustInclude @("Q-PARSE") -ExpectConservativeFull $true
    Pass "unknown path conservative Full"

    $failFixtures = @(
        @{ name = "missing_history"; spec = '{"paths":[{"path":"docs/a.md","class":"modified"}],"flags":{"missing_history":true}}'; trigger = "missing_history" }
        @{ name = "merge_conflict"; spec = '{"paths":[],"flags":{"merge_conflict":true}}'; trigger = "merge_conflict" }
        @{ name = "parse_error"; spec = '{"paths":[],"flags":{"parse_error":true}}'; trigger = "parse_error" }
        @{ name = "bootstrap"; spec = '{"paths":[{"path":"scripts/smoke-bootstrap.ps1","class":"modified"}],"flags":{}}'; trigger = "bootstrap_change" }
        @{ name = "shipping"; spec = '{"paths":[{"path":"shipping/manifest.v1.json","class":"modified"}],"flags":{}}'; trigger = "shipping_manifest_change" }
        @{ name = "planner"; spec = '{"paths":[{"path":"scripts/plan-verification.ps1","class":"modified"}],"flags":{}}'; trigger = "planner_change" }
        @{ name = "plugin"; spec = '{"paths":[{"path":"plugin/cursor-project-harness/plugin.json","class":"modified"}],"flags":{}}'; trigger = "plugin_mirror_change" }
        @{ name = "contract"; spec = '{"paths":[{"path":".cursor/skills/autonomous-task/contracts.md","class":"modified"}],"flags":{}}'; trigger = "shared_contract_change" }
        @{ name = "dispatch"; mode = "dispatch"; spec = '{"paths":[{"path":"README.md","class":"modified"}],"flags":{}}'; trigger = "dispatch_explicit" }
        @{ name = "push"; mode = "push"; spec = '{"paths":[{"path":"README.md","class":"modified"}],"flags":{}}'; trigger = "push_main" }
        @{ name = "release"; spec = '{"paths":[{"path":"docs/project-state.md","class":"modified"}],"flags":{}}'; trigger = "release" }
        @{ name = "unknown_event"; spec = '{"paths":[{"path":"README.md","class":"modified"}],"flags":{"unknown_event":true}}'; trigger = "unknown_event" }
    )
    foreach ($fx in $failFixtures) {
        $m = Parse-ChangeSpecJson -JsonText ([string]$fx.spec) -Strict
        $modeFx = if ($null -ne $fx.mode) { [string]$fx.mode } else { "worktree" }
        $ex = Expand-ChangeEntries -RawEntries $m.entries -StrictPrivacy
        $p = New-VerificationPlan -ModeName $modeFx -Manifest $manifest -GatherMeta $m -Entries $ex.entries
        if (-not [bool]$p.conservative_full) { Fail ("seeded failure conservative: " + $fx.name); continue }
        if (@($p.full_triggers_fired) -notcontains [string]$fx.trigger) { Fail ("seeded failure trigger: " + $fx.name); continue }
        try {
            Assert-TriggersInManifest -Manifest $manifest -Triggers @($p.full_triggers_fired)
        } catch {
            Fail ("seeded triggers manifest: " + $fx.name + " " + $_.Exception.Message)
            continue
        }
        Pass ("seeded conservative: " + $fx.name)
    }

    $renameBytes = New-Object System.Collections.Generic.List[byte]
    [void]$renameBytes.AddRange([System.Text.Encoding]::UTF8.GetBytes("R  docs/spaced name.ps1"))
    [void]$renameBytes.Add(0)
    [void]$renameBytes.AddRange([System.Text.Encoding]::UTF8.GetBytes("docs/old spaced.ps1"))
    [void]$renameBytes.Add(0)
    $parsedRename = Parse-GitPorcelainZ -RawBytes ($renameBytes.ToArray())
    Assert-True ($parsedRename.Count -eq 1) "porcelain rename one record"
    Assert-True ([string]$parsedRename[0].path -eq "docs/spaced name.ps1") "porcelain rename new path"
    Assert-True ([string]$parsedRename[0].path2 -eq "docs/old spaced.ps1") "porcelain rename old path"
    Pass "porcelain -z rename token stream"

    $copyBytes = New-Object System.Collections.Generic.List[byte]
    [void]$copyBytes.AddRange([System.Text.Encoding]::UTF8.GetBytes("C  docs/new copy.ps1"))
    [void]$copyBytes.Add(0)
    [void]$copyBytes.AddRange([System.Text.Encoding]::UTF8.GetBytes("docs/old copy.ps1"))
    [void]$copyBytes.Add(0)
    $parsedCopy = @(Parse-GitPorcelainZ -RawBytes ($copyBytes.ToArray()))
    Assert-True ($parsedCopy.Count -eq 1) "porcelain C-token one record"
    Assert-True ([string]$parsedCopy[0].xy -eq "C ") "porcelain C-token xy"
    Assert-True ([string]$parsedCopy[0].class -eq "renamed") "porcelain C-token copy class"
    Assert-True ([string]$parsedCopy[0].path -eq "docs/new copy.ps1") "porcelain C-token new path"
    Assert-True ([string]$parsedCopy[0].path2 -eq "docs/old copy.ps1") "porcelain C-token old path"
    Pass "porcelain -z C-token copy stream"

    $tabRecord = " M has" + [char]9 + "inside.ps1"
    $tabBody = [System.Text.Encoding]::UTF8.GetBytes($tabRecord)
    $tabRawArr = New-Object byte[] ($tabBody.Length + 1)
    [Array]::Copy($tabBody, 0, $tabRawArr, 0, $tabBody.Length)
    $tabRawArr[$tabBody.Length] = 0
    $parsedTab = @(Parse-GitPorcelainZ -RawBytes $tabRawArr)
    Assert-True ($parsedTab.Count -eq 1) "porcelain tab parse one record"
    $tabGotBytes = [System.Text.Encoding]::UTF8.GetBytes([string]$parsedTab[0].path)
    $tabExpBytes = [byte[]](0x68, 0x61, 0x73, 0x09, 0x69, 0x6E, 0x73, 0x69, 0x64, 0x65, 0x2E, 0x70, 0x73, 0x31)
    $tabByteOk = ($tabGotBytes.Length -eq $tabExpBytes.Length)
    if ($tabByteOk) {
        for ($ti = 0; $ti -lt $tabExpBytes.Length; $ti++) {
            if ($tabGotBytes[$ti] -ne $tabExpBytes[$ti]) { $tabByteOk = $false; break }
        }
    }
    Assert-True $tabByteOk "porcelain tab path bytes preserved"
    Pass "porcelain tab path bytes preserved"

    $badSpecPlan = Invoke-PlannerGather -ModeName "worktree" -ChangeSpecJsonLocal "{not-json"
    Assert-True ([bool]$badSpecPlan.gatherMeta.parse_error) "invalid change spec parse_error"
    $badPlan = New-VerificationPlan -ModeName "worktree" -Manifest $manifest -GatherMeta $badSpecPlan.gatherMeta -Entries $badSpecPlan.entries
    Assert-True ([string]$badPlan.recommended_profile -eq "Full") "parse fallback Full profile"
    Assert-True (@($badPlan.full_triggers_fired) -contains "parse_error") "parse fallback trigger"
    Pass "parse fallback produces Full plan"

    $allowedTriggers = @($manifest.conservative_full_triggers | ForEach-Object { [string]$_ })
    Assert-True ($allowedTriggers.Count -ge 15) "manifest conservative trigger registry"
    foreach ($samplePlan in @($docsPlan, $wfPlan, $prPlan, $unkPlan, $badPlan)) {
        foreach ($t in @($samplePlan.full_triggers_fired)) {
            Assert-True ($allowedTriggers -contains [string]$t) ("sample plan trigger registered: " + $t)
        }
    }
    Pass "full_triggers_fired manifest registry"

    Assert-ThrowsMsg {
        Test-PrivacyPath -Path "C:/Users/leak/docs.md"
    } "privacy: absolute path rejected" "reject absolute path in plan"

    $tempRoot = Join-Path $env:TEMP ("cptk-planner-" + [guid]::NewGuid().ToString("n"))
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    try {
        $out = Register-OwnedOutputPath -ExplicitOutput (Join-Path $tempRoot "plan.json") -FileName "unused.json"
        Write-PlanCreateNew -OutputPath $out -JsonText '{"shadow_only":true}'
        Assert-ThrowsMsg {
            Write-PlanCreateNew -OutputPath $out -JsonText '{"shadow_only":true}'
        } "duplicate output file exists" "reject duplicate CreateNew"
    } finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        $script:OwnedOutputPaths.Clear()
    }

    Push-Location -LiteralPath $ToolkitRoot
    try {
        $ignore = & git check-ignore -v ".cursor/planner-local/" 2>$null
        Assert-True (-not [string]::IsNullOrWhiteSpace($ignore)) "gitignore covers planner local"
    } finally {
        Pop-Location
    }

    Write-Host ""
    if ($script:Fail -eq 0) {
        Write-Host "PLAN_VERIFICATION_SELFTEST_PASS"
        exit 0
    }
    Write-Host "PLAN_VERIFICATION_SELFTEST_FAIL: $script:Fail"
    exit 1
}

function Invoke-PlannerGather {
    param(
        [string]$ModeName,
        [string]$ChangeSpecPathLocal,
        [string]$ChangeSpecJsonLocal
    )
    if (-not [string]::IsNullOrWhiteSpace($ChangeSpecPathLocal)) {
        if (-not (Test-Path -LiteralPath $ChangeSpecPathLocal)) {
            return @{
                gatherMeta = @{
                    missing_history = $false; merge_conflict = $false; parse_error = $true
                    unknown_event = $false; gather_error_code = "parse_error"
                }
                entries = @()
                mode = $ModeName
            }
        }
        $ChangeSpecJsonLocal = Read-Text $ChangeSpecPathLocal
    }
    if (-not [string]::IsNullOrWhiteSpace($ChangeSpecJsonLocal)) {
        $parsed = Parse-ChangeSpecJson -JsonText $ChangeSpecJsonLocal
        if ([bool]$parsed.parse_error) {
            return @{
                gatherMeta = @{
                    missing_history = $false; merge_conflict = $false; parse_error = $true
                    unknown_event = $false; gather_error_code = "parse_error"
                }
                entries = @()
                mode = $(if (-not [string]::IsNullOrWhiteSpace($parsed.mode_override)) { [string]$parsed.mode_override } else { $ModeName })
            }
        }
        $expanded = Expand-ChangeEntries -RawEntries $parsed.entries
        if ([bool]$expanded.privacy_error) {
            return @{
                gatherMeta = @{
                    missing_history = $false; merge_conflict = $false; parse_error = $true
                    unknown_event = $false; gather_error_code = "privacy_rejected"
                }
                entries = @()
                mode = $(if (-not [string]::IsNullOrWhiteSpace($parsed.mode_override)) { [string]$parsed.mode_override } else { $ModeName })
            }
        }
        $modeUse = $ModeName
        if (-not [string]::IsNullOrWhiteSpace($parsed.mode_override)) { $modeUse = [string]$parsed.mode_override }
        return @{
            gatherMeta = @{
                missing_history = [bool]$parsed.missing_history
                merge_conflict = [bool]$parsed.merge_conflict
                parse_error = [bool]$parsed.parse_error
                unknown_event = [bool]$parsed.unknown_event
                gather_error_code = $(if ($parsed.gather_error_code) { [string]$parsed.gather_error_code } else { $null })
            }
            entries = @($expanded.entries)
            mode = $modeUse
        }
    }

    $gitGather = Get-GitChangedEntries
    if ([bool]$gitGather.parse_error) {
        return @{
            gatherMeta = @{
                missing_history = [bool]$gitGather.missing_history
                merge_conflict = $false; parse_error = $true; unknown_event = $false
                gather_error_code = $(if ($gitGather.gather_error_code) { [string]$gitGather.gather_error_code } else { "parse_error" })
            }
            entries = @()
            mode = $ModeName
        }
    }
    $expandedGit = Expand-ChangeEntries -RawEntries $gitGather.entries
    if ([bool]$expandedGit.privacy_error) {
        return @{
            gatherMeta = @{
                missing_history = [bool]$gitGather.missing_history
                merge_conflict = $false; parse_error = $true; unknown_event = $false
                gather_error_code = "privacy_rejected"
            }
            entries = @()
            mode = $ModeName
        }
    }
    return @{
        gatherMeta = @{
            missing_history = [bool]$gitGather.missing_history
            merge_conflict = [bool]$gitGather.merge_conflict
            parse_error = $false; unknown_event = $false
            gather_error_code = $(if ($gitGather.gather_error_code) { [string]$gitGather.gather_error_code } else { $null })
        }
        entries = @($expandedGit.entries)
        mode = $ModeName
    }
}

if ($SelfTest) {
    Invoke-SelfTest
    exit $LASTEXITCODE
}

$manifest = Get-ManifestDocument
$gather = Invoke-PlannerGather -ModeName $Mode -ChangeSpecPathLocal $ChangeSpecPath -ChangeSpecJsonLocal $ChangeSpecJson
$Mode = [string]$gather.mode
$plan = New-VerificationPlan -ModeName $Mode -Manifest $manifest -GatherMeta $gather.gatherMeta -Entries $gather.entries
Test-PlanPrivacyNode -Node $plan
$planJson = ($plan | ConvertTo-Json -Depth 12)
$dest = Register-OwnedOutputPath -ExplicitOutput $OutputPath -FileName ("plan-" + $Mode.ToLowerInvariant() + ".json")
Write-PlanCreateNew -OutputPath $dest -JsonText $planJson
Write-Host "PLAN_VERIFICATION_OK plan=output=invocation-owned profile=$($plan.recommended_profile)"
exit 0

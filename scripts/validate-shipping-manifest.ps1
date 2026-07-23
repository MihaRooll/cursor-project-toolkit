<#
.SYNOPSIS
  Shadow validator: shipping/manifest.v1.json vs live bootstrap/smoke/plugin/toolkit-CI arrays.
  Bootstrap/install remain array-driven; manifest is SSOT for review only until a later switch.
#>
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$ManifestPath,
    [switch]$SelfTest,
    [switch]$EmitManifest
)

$ErrorActionPreference = "Stop"
$AllowedPolicies = @(
    "managed", "seed-only", "managed-block", "structural-merge", "plugin-only", "toolkit-ci-only"
)
$AllowedSurfaces = @("essential", "full", "plugin", "toolkit-ci", "greenfield")
$VerifyHarnessRel = "scripts/verify-harness.ps1"

if (-not $ManifestPath) {
    $ManifestPath = Join-Path $ProjectRoot "shipping\manifest.v1.json"
}

function Normalize-RelPath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
    return ($Path -replace '\\', '/').TrimStart('/')
}

function Read-Text([string]$Path) {
    return [System.IO.File]::ReadAllText($Path)
}

function Get-PsAst {
    param([string]$FilePath)
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$tokens, [ref]$errors)
    if ($errors -and @($errors).Count -gt 0) {
        $msg = ($errors | ForEach-Object { $_.Message }) -join "; "
        throw "parse errors in ${FilePath}: $msg"
    }
    if ($null -eq $ast) { throw "parse failed: $FilePath" }
    return $ast
}

function Resolve-ArrayAssignmentExpression {
    param($Expr, [string]$Label)
    if ($null -eq $Expr) { throw "missing array expression: $Label" }
    if ($Expr -is [System.Management.Automation.Language.CommandExpressionAst]) {
        $Expr = $Expr.Expression
    }
    if ($Expr -is [System.Management.Automation.Language.ArrayLiteralAst] -or
        $Expr -is [System.Management.Automation.Language.ArrayExpressionAst]) {
        return $Expr
    }
    throw "non-literal array assignment: $Label"
}

function Get-StringLiteralsFromArrayExpression {
    param($Expr, [string]$Label)
    $arrayExpr = Resolve-ArrayAssignmentExpression -Expr $Expr -Label $Label
    if ($arrayExpr -is [System.Management.Automation.Language.ArrayLiteralAst]) {
        $items = New-Object System.Collections.Generic.List[string]
        foreach ($elt in $arrayExpr.Elements) {
            if ($elt -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                [void]$items.Add($elt.Value)
                continue
            }
            throw "non-string-literal array element in ${Label}"
        }
        return $items
    }
    if ($arrayExpr -is [System.Management.Automation.Language.ArrayExpressionAst]) {
        $badVars = $arrayExpr.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] }, $true)
        $badSubs = $arrayExpr.FindAll({
                param($n)
                $n -is [System.Management.Automation.Language.SubexpressionAst]
            }, $true)
        if ($badVars.Count -gt 0 -or $badSubs.Count -gt 0) {
            throw "non-string-literal array element in ${Label}"
        }
        $items = New-Object System.Collections.Generic.List[string]
        foreach ($lit in $arrayExpr.FindAll({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true)) {
            [void]$items.Add($lit.Value)
        }
        if ($items.Count -eq 0) {
            throw "empty string array: $Label"
        }
        return $items
    }
    throw "unsupported array expression: $Label"
}

function Get-PsStringArrayAssignment {
    param(
        [string]$FilePath,
        [string]$VariableName
    )
    if (-not (Test-Path -LiteralPath $FilePath)) {
        throw "missing script for array parse: $FilePath"
    }
    $ast = Get-PsAst -FilePath $FilePath
    $assignments = $ast.FindAll({
            param($n)
            $n -is [System.Management.Automation.Language.AssignmentStatementAst]
        }, $true)
    foreach ($a in $assignments) {
        $left = $a.Left
        if ($left -is [System.Management.Automation.Language.VariableExpressionAst] -and
            $left.VariablePath.UserPath -eq $VariableName) {
            return (Get-StringLiteralsFromArrayExpression -Expr $a.Right -Label $VariableName)
        }
    }
    throw "array assignment not found: $VariableName in $FilePath"
}

function Expand-PathTemplate {
    param(
        $Expr,
        [hashtable]$VarExpansions,
        [string]$Label
    )
    if ($Expr -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
        return (Normalize-RelPath $Expr.Value)
    }
    if ($Expr -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
        $template = $Expr.Extent.Text.Trim('"').Trim("'")
        foreach ($key in $VarExpansions.Keys) {
            $template = $template.Replace('$' + $key, [string]$VarExpansions[$key])
        }
        if ($template -match '\$') {
            throw "unexpanded variable in expandable string: $Label"
        }
        return (Normalize-RelPath ($template -replace '\\', '/'))
    }
    if ($Expr -is [System.Management.Automation.Language.VariableExpressionAst]) {
        $name = $Expr.VariablePath.UserPath
        if ($VarExpansions.ContainsKey($name)) {
            return (Normalize-RelPath ([string]$VarExpansions[$name]))
        }
        throw "unprovable variable in path: `$${name} ($Label)"
    }
    throw "unprovable path expression: $Label"
}

function Get-CommandFromCopyArgument {
    param($ArgAst)
    if ($ArgAst -is [System.Management.Automation.Language.ParenExpressionAst]) {
        return $ArgAst.Pipeline.PipelineElements[0]
    }
    if ($ArgAst -is [System.Management.Automation.Language.CommandAst]) {
        return $ArgAst
    }
    throw "unprovable Copy-Item argument"
}

function Resolve-JoinPathCommand {
    param(
        [System.Management.Automation.Language.CommandAst]$CmdAst,
        [hashtable]$VarExpansions,
        [string]$Label
    )
    if ($CmdAst.GetCommandName() -ne "Join-Path") {
        throw "expected Join-Path command: $Label"
    }
    $els = @($CmdAst.CommandElements | Where-Object { $_ -isnot [System.Management.Automation.Language.CommandParameterAst] })
    if ($els.Count -lt 3) { throw "invalid Join-Path arity: $Label" }
    $base = $els[1]
    $child = $els[2]
    if ($base -isnot [System.Management.Automation.Language.VariableExpressionAst]) {
        throw "unprovable Join-Path base: $Label"
    }
    return @{
        Base = $base.VariablePath.UserPath
        Child = (Expand-PathTemplate -Expr $child -VarExpansions $VarExpansions -Label $Label)
    }
}

function Resolve-ToolkitSourceFromCopyArgument {
    param(
        $ArgAst,
        [hashtable]$VarExpansions,
        [string]$Label
    )
    $cmd = Get-CommandFromCopyArgument -ArgAst $ArgAst
    if ($cmd -isnot [System.Management.Automation.Language.CommandAst]) {
        throw "unprovable toolkit source: $Label"
    }
    $jp = Resolve-JoinPathCommand -CmdAst $cmd -VarExpansions $VarExpansions -Label $Label
    if ($jp.Base -ne "ToolkitRoot") {
        throw "Join-Path base must be ToolkitRoot: $Label"
    }
    return $jp.Child
}

function Resolve-PluginDestFromCopyArgument {
    param(
        $ArgAst,
        [string]$SourceRel,
        [hashtable]$VarExpansions,
        [string]$Label
    )
    $cmd = Get-CommandFromCopyArgument -ArgAst $ArgAst
    if ($cmd -isnot [System.Management.Automation.Language.CommandAst]) {
        throw "unprovable plugin destination: $Label"
    }
    $jp = Resolve-JoinPathCommand -CmdAst $cmd -VarExpansions $VarExpansions -Label $Label
    if ($jp.Base -eq "agentsDst") {
        return "plugins/local/cursor-project-harness/agents/" + $jp.Child
    }
    if ($jp.Base -ne "Dst") {
        throw "plugin dest Join-Path base must be Dst/agentsDst: $Label"
    }
    $destRel = "plugins/local/cursor-project-harness/" + $jp.Child
    $srcNorm = Normalize-RelPath $SourceRel
    if ($destRel -match '/skills$' -and $srcNorm -match '\.cursor/skills/([^/]+)$') {
        return ($destRel + "/" + $Matches[1])
    }
    return $destRel
}

function Get-ForeachCollectionVariable {
    param([System.Management.Automation.Language.ForEachStatementAst]$ForEachAst)
    $cond = $ForEachAst.Condition
    if ($cond -is [System.Management.Automation.Language.VariableExpressionAst]) {
        return $cond.VariablePath.UserPath
    }
    if ($cond -is [System.Management.Automation.Language.PipelineAst]) {
        if ($cond.PipelineElements.Count -lt 1) {
            throw "unprovable foreach collection pipeline"
        }
        $pe = $cond.PipelineElements[0]
        if ($pe -is [System.Management.Automation.Language.CommandExpressionAst]) {
            $expr = $pe.Expression
            if ($expr -is [System.Management.Automation.Language.VariableExpressionAst]) {
                return $expr.VariablePath.UserPath
            }
        }
    }
    throw "unprovable foreach collection"
}

function Get-InstallHarnessPluginOverlays {
    param([string]$InstallPath)
    $hookNames = @(Get-PsStringArrayAssignment -FilePath $InstallPath -VariableName "hookNames")
    $agentNames = @(Get-PsStringArrayAssignment -FilePath $InstallPath -VariableName "agentNames")
    $ast = Get-PsAst -FilePath $InstallPath
    $overlays = New-Object System.Collections.Generic.List[hashtable]
    $commands = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)
    foreach ($cmd in $commands) {
        if ($cmd.GetCommandName() -ne "Copy-Item") { continue }
        $positional = @($cmd.CommandElements | Where-Object { $_ -isnot [System.Management.Automation.Language.CommandParameterAst] })
        if ($positional.Count -lt 3) { continue }
        $srcArg = $positional[1]
        $dstArg = $positional[2]
        if ($srcArg -is [System.Management.Automation.Language.VariableExpressionAst]) {
            continue
        }
        $loopVars = $null
        $parent = $cmd.Parent
        while ($null -ne $parent) {
            if ($parent -is [System.Management.Automation.Language.ForEachStatementAst]) {
                $iterVar = $parent.Variable.VariablePath.UserPath
                $collectionVar = Get-ForeachCollectionVariable -ForEachAst $parent
                if ($iterVar -eq "h" -and $collectionVar -eq "hookNames") {
                    foreach ($h in $hookNames) {
                        $vars = @{ h = $h }
                        $src = Resolve-ToolkitSourceFromCopyArgument -ArgAst $srcArg -VarExpansions $vars -Label "hook Copy-Item"
                        $dst = Resolve-PluginDestFromCopyArgument -ArgAst $dstArg -SourceRel $src -VarExpansions $vars -Label "hook Copy-Item dest"
                        [void]$overlays.Add(@{ source = $src; destination = $dst })
                    }
                    $loopVars = "done"
                    break
                }
                if ($iterVar -eq "agentName" -and $collectionVar -eq "agentNames") {
                    foreach ($agentName in $agentNames) {
                        $vars = @{ agentName = $agentName }
                        $src = Resolve-ToolkitSourceFromCopyArgument -ArgAst $srcArg -VarExpansions $vars -Label "agent Copy-Item"
                        $dst = Resolve-PluginDestFromCopyArgument -ArgAst $dstArg -SourceRel $src -VarExpansions $vars -Label "agent Copy-Item dest"
                        [void]$overlays.Add(@{ source = $src; destination = $dst })
                    }
                    $loopVars = "done"
                    break
                }
                throw "unprovable foreach Copy-Item loop in install-harness-plugin.ps1"
            }
            $parent = $parent.Parent
        }
        if ($loopVars -eq "done") { continue }
        $src = Resolve-ToolkitSourceFromCopyArgument -ArgAst $srcArg -VarExpansions @{} -Label "install Copy-Item"
        $dst = Resolve-PluginDestFromCopyArgument -ArgAst $dstArg -SourceRel $src -VarExpansions @{} -Label "install Copy-Item dest"
        [void]$overlays.Add(@{ source = $src; destination = $dst })
    }
    if ($overlays.Count -eq 0) {
        throw "no provable Copy-Item overlays in install-harness-plugin.ps1"
    }
    return $overlays
}

function Assert-NoReparsePoint {
    param([string]$Path, [string]$Label)
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw "reparse point rejected at $Label"
    }
}

function Test-GitTracked {
    param([string]$RelPath, [string]$Root)
    $gitRel = Normalize-RelPath $RelPath
    Push-Location -LiteralPath $Root
    try {
        $out = git ls-files -- "$gitRel" 2>$null
        if ($null -ne $out -and @($out).Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$out[0])) {
            return $true
        }
        $out2 = git ls-files -- "$($gitRel -replace '/', '\')" 2>$null
        return ($null -ne $out2 -and @($out2).Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$out2[0]))
    } finally {
        Pop-Location
    }
}

function New-EntryKey {
    param([string]$Policy, [string]$Surface, [string]$Source, [string]$Destination)
    return ($Policy + "|" + $Surface + "|" + (Normalize-RelPath $Source) + "|" + (Normalize-RelPath $Destination))
}

function Add-ExpectedEntry {
    param(
        [hashtable]$Map,
        [string]$Id,
        [string]$Policy,
        [string]$Surface,
        [string]$Source,
        [string]$Destination,
        [string]$Ref
    )
    $src = Normalize-RelPath $Source
    $dst = Normalize-RelPath $Destination
    $key = New-EntryKey -Policy $Policy -Surface $Surface -Source $src -Destination $dst
    if ($Map.ContainsKey($key)) {
        throw "duplicate expected entry: $key"
    }
    $Map[$key] = @{
        id = $Id
        policy = $Policy
        surface = $Surface
        source = $src
        destination = $dst
        bootstrap_ref = $Ref
    }
}

function Build-ExpectedEntries {
    param([string]$Root)
    $bootstrapPath = Join-Path $Root "scripts\bootstrap-into-project.ps1"
    $smokePath = Join-Path $Root "scripts\smoke-bootstrap.ps1"
    $installPath = Join-Path $Root "scripts\install-harness-plugin.ps1"
    $expected = @{}

    $essentialFiles = @(Get-PsStringArrayAssignment -FilePath $bootstrapPath -VariableName "essentialFiles")
    foreach ($rel in $essentialFiles) {
        $norm = Normalize-RelPath $rel
        if ($norm -eq "docs/project-state.md") {
            Add-ExpectedEntry -Map $expected -Id ("managed-" + ($norm -replace '[/\\]', '-')) `
                -Policy "managed" -Surface "essential" -Source "templates/project-state.md" `
                -Destination $norm -Ref "essentialFiles+template"
            continue
        }
        Add-ExpectedEntry -Map $expected -Id ("managed-" + ($norm -replace '[/\\]', '-')) `
            -Policy "managed" -Surface "essential" -Source $norm -Destination $norm -Ref "essentialFiles"
    }

    @(
        @{ src = ".cursor/skills/review-papercuts"; dst = ".cursor/skills/review-papercuts" }
        @{ src = ".cursor/rules/skills-ru-description.mdc"; dst = ".cursor/rules/skills-ru-description.mdc" }
        @{ src = "templates/project-rules/product-core.mdc"; dst = ".cursor/rules/product-core.mdc" }
    ) | ForEach-Object {
        Add-ExpectedEntry -Map $expected -Id ("managed-" + ($_.dst -replace '[/\\]', '-')) `
            -Policy "managed" -Surface "essential" -Source $_.src -Destination $_.dst -Ref "essentialExtras"
    }

    @(
        @{ src = ".cursor/hooks/session-start.ps1"; dst = ".cursor/hooks/session-start.ps1" }
        @{ src = ".cursor/hooks/after-shell-papercuts.ps1"; dst = ".cursor/hooks/after-shell-papercuts.ps1" }
        @{ src = ".cursor/hooks/stop-papercuts-nudge.ps1"; dst = ".cursor/hooks/stop-papercuts-nudge.ps1" }
        @{ src = "templates/project-AGENTS.md"; dst = "AGENTS.md" }
    ) | ForEach-Object {
        Add-ExpectedEntry -Map $expected -Id ("block-" + ($_.dst -replace '[/\\]', '-')) `
            -Policy "managed-block" -Surface "essential" -Source $_.src -Destination $_.dst -Ref "hooksOrAgents"
    }

    @(
        @{ src = ".cursor/hooks.json"; dst = ".cursor/hooks.json"; ref = "Merge-PapercutsHooks" }
        @{ src = "templates/project-AGENTS-harness-snippet.md"; dst = "AGENTS.md"; ref = "Ensure-AgentsHarnessSnippet" }
    ) | ForEach-Object {
        Add-ExpectedEntry -Map $expected -Id ("merge-" + ($_.src -replace '[/\\.]', '-')) `
            -Policy "structural-merge" -Surface "essential" -Source $_.src -Destination $_.dst -Ref $_.ref
    }

    $full = @(Get-PsStringArrayAssignment -FilePath $bootstrapPath -VariableName "full")
    foreach ($rel in $full) {
        Add-ExpectedEntry -Map $expected -Id ("merge-" + ($rel -replace '[/\\]', '-')) `
            -Policy "structural-merge" -Surface "full" -Source $rel -Destination $rel -Ref "full"
    }

    @(
        @{ src = "templates/product-brief.md"; dst = "docs/product-brief.md" }
        @{ src = "templates/first-chat.md"; dst = "docs/first-chat.md" }
        @{ src = "templates/docs-map.json"; dst = "docs/docs-map.json" }
    ) | ForEach-Object {
        Add-ExpectedEntry -Map $expected -Id ("seed-" + ($_.dst -replace '[/\\]', '-')) `
            -Policy "seed-only" -Surface "greenfield" -Source $_.src -Destination $_.dst -Ref "new-project"
    }

    $pluginRoot = Join-Path $Root "plugin\cursor-project-harness"
    if (Test-Path -LiteralPath $pluginRoot) {
        foreach ($f in (Get-ChildItem -LiteralPath $pluginRoot -Recurse -File -Force)) {
            $rel = Normalize-RelPath $f.FullName.Substring($pluginRoot.Length)
            Add-ExpectedEntry -Map $expected -Id ("plugin-pkg-" + ($rel -replace '[/\\.]', '-')) `
                -Policy "plugin-only" -Surface "plugin" -Source ("plugin/cursor-project-harness/" + $rel) `
                -Destination ("plugins/local/cursor-project-harness/" + $rel) -Ref "pluginPackage"
        }
    }

    $overlays = Get-InstallHarnessPluginOverlays -InstallPath $installPath
    foreach ($ov in $overlays) {
        Add-ExpectedEntry -Map $expected -Id ("plugin-sync-" + ($ov.destination -replace '[/\\.]', '-')) `
            -Policy "plugin-only" -Surface "plugin" -Source $ov.source -Destination $ov.destination `
            -Ref "installHarnessPlugin"
    }

    $mustAbsent = @(Get-PsStringArrayAssignment -FilePath $smokePath -VariableName "mustAbsent")
    foreach ($rel in $mustAbsent) {
        Add-ExpectedEntry -Map $expected -Id ("exclude-" + ($rel -replace '[/\\]', '-')) `
            -Policy "toolkit-ci-only" -Surface "essential" -Source $rel -Destination $rel `
            -Ref "mustAbsent"
    }

    @(
        "scripts/verify-harness.ps1"
        "scripts/validate-orchestration.ps1"
        "scripts/new-project.ps1"
        "scripts/new-project.cmd"
        "scripts/bootstrap-into-project.ps1"
        "scripts/install-harness-plugin.ps1"
        "scripts/smoke-portability.ps1"
        "scripts/runtime-coexistence.ps1"
        "scripts/runtime-coexistence-rollback.ps1"
        "scripts/validate-shipping-manifest.ps1"
        "shipping/manifest.v1.json"
        ".github/workflows/toolkit-verify.yml"
    ) | ForEach-Object {
        Add-ExpectedEntry -Map $expected -Id ("ci-" + ($_ -replace '[/\\.]', '-')) `
            -Policy "toolkit-ci-only" -Surface "toolkit-ci" -Source $_ -Destination $_ -Ref "toolkitCi"
    }

    return $expected
}

function Load-ManifestEntries {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "missing manifest: $Path" }
    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    } catch {
        throw "manifest io error: $Path"
    }
    try {
        $obj = $raw | ConvertFrom-Json
    } catch {
        throw "manifest json parse error: $Path"
    }
    if ([int]$obj.schema_version -ne 1) { throw "unsupported schema_version" }
    $entries = @{}
    $ids = @{}
    foreach ($e in @($obj.entries)) {
        if ($null -eq $e.policy -or $AllowedPolicies -notcontains [string]$e.policy) {
            throw "unknown policy: $($e.policy)"
        }
        if ($null -eq $e.surface -or $AllowedSurfaces -notcontains [string]$e.surface) {
            throw "unknown surface: $($e.surface)"
        }
        $id = [string]$e.id
        if ($ids.ContainsKey($id)) { throw "duplicate manifest id: $id" }
        $ids[$id] = $true
        $key = New-EntryKey -Policy ([string]$e.policy) -Surface ([string]$e.surface) `
            -Source ([string]$e.source) -Destination ([string]$e.destination)
        if ($entries.ContainsKey($key)) { throw "duplicate manifest entry key: $key" }
        $entries[$key] = @{
            id = $id
            policy = [string]$e.policy
            surface = [string]$e.surface
            source = Normalize-RelPath ([string]$e.source)
            destination = Normalize-RelPath ([string]$e.destination)
            bootstrap_ref = [string]$e.bootstrap_ref
        }
    }
    return @{ obj = $obj; entries = $entries }
}

function Test-BootstrapWouldShipVerifyHarness {
    param([string]$Root, [ref]$FailCount)
    $bootstrapPath = Join-Path $Root "scripts\bootstrap-into-project.ps1"
    try {
        $essentialFiles = @(Get-PsStringArrayAssignment -FilePath $bootstrapPath -VariableName "essentialFiles")
        $full = @(Get-PsStringArrayAssignment -FilePath $bootstrapPath -VariableName "full")
    } catch {
        Write-Host "FAIL bootstrap array parse for verify-harness gate: $($_.Exception.Message)"
        $FailCount.Value++
        return
    }
    foreach ($arr in @($essentialFiles, $full)) {
        foreach ($rel in $arr) {
            if ((Normalize-RelPath $rel) -ceq $VerifyHarnessRel) {
                Write-Host "FAIL verify-harness.ps1 listed in bootstrap copy array"
                $FailCount.Value++
                return
            }
        }
    }
}

function Add-ValidationFail {
    param(
        [string]$Message,
        [ref]$FailCount,
        [System.Collections.Generic.List[string]]$MessageLog = $null
    )
    Write-Host $Message
    if ($null -ne $MessageLog) { [void]$MessageLog.Add($Message) }
    $FailCount.Value++
}

function Invoke-ManifestValidation {
    param(
        [string]$Root,
        [string]$ManifestFile,
        [ref]$FailCount,
        [System.Collections.Generic.List[string]]$MessageLog = $null
    )
    try {
        $expected = Build-ExpectedEntries -Root $Root
    } catch {
        Add-ValidationFail -Message "FAIL expected entry build: $($_.Exception.Message)" -FailCount $FailCount -MessageLog $MessageLog
        return
    }
    try {
        $loaded = Load-ManifestEntries -Path $ManifestFile
    } catch {
        Add-ValidationFail -Message "FAIL manifest load: $($_.Exception.Message)" -FailCount $FailCount -MessageLog $MessageLog
        return
    }
    $manifest = $loaded.entries

    foreach ($key in $expected.Keys) {
        if (-not $manifest.ContainsKey($key)) {
            Add-ValidationFail -Message "FAIL manifest missing expected entry: $key" -FailCount $FailCount -MessageLog $MessageLog
        } elseif ($manifest[$key].policy -ne $expected[$key].policy) {
            Add-ValidationFail -Message "FAIL policy mismatch $key expected=$($expected[$key].policy) actual=$($manifest[$key].policy)" -FailCount $FailCount -MessageLog $MessageLog
        }
    }
    foreach ($key in $manifest.Keys) {
        if (-not $expected.ContainsKey($key)) {
            Add-ValidationFail -Message "FAIL manifest extra entry: $key" -FailCount $FailCount -MessageLog $MessageLog
        }
    }

    foreach ($entry in $manifest.Values) {
        $srcRel = [string]$entry.source
        if ([string]::IsNullOrWhiteSpace($srcRel)) {
            Add-ValidationFail -Message "FAIL empty source on id=$($entry.id)" -FailCount $FailCount -MessageLog $MessageLog
            continue
        }
        if ($entry.policy -eq "toolkit-ci-only" -and $entry.bootstrap_ref -eq "mustAbsent") {
            continue
        }
        $srcPath = Join-Path $Root ($srcRel -replace '/', '\')
        if ($srcRel -like "plugins/local/*") { continue }
        if (-not (Test-Path -LiteralPath $srcPath)) {
            if ($entry.policy -ne "managed-block" -or $srcRel -ne "templates/project-AGENTS.md") {
                Add-ValidationFail -Message "FAIL missing source path id=$($entry.id) src=$srcRel" -FailCount $FailCount -MessageLog $MessageLog
                continue
            }
        }
        if (Test-Path -LiteralPath $srcPath) {
            try {
                Assert-NoReparsePoint -Path $srcPath -Label $srcRel
            } catch {
                Add-ValidationFail -Message "FAIL reparse source id=$($entry.id) src=$srcRel" -FailCount $FailCount -MessageLog $MessageLog
            }
        }
        if (-not (Test-GitTracked -RelPath ($srcRel -replace '/', '\') -Root $Root)) {
            if ($entry.policy -notin @("managed-block", "structural-merge")) {
                Add-ValidationFail -Message "FAIL untracked or ignored source id=$($entry.id) src=$srcRel" -FailCount $FailCount -MessageLog $MessageLog
            }
        }
    }

    $smokePath = Join-Path $Root "scripts\smoke-bootstrap.ps1"
    $mustExist = @(Get-PsStringArrayAssignment -FilePath $smokePath -VariableName "mustExist")
    foreach ($rel in $mustExist) {
        $norm = Normalize-RelPath $rel
        $covered = $false
        foreach ($entry in $manifest.Values) {
            if ($entry.policy -notin @("managed", "managed-block", "structural-merge")) { continue }
            $dst = Normalize-RelPath ([string]$entry.destination)
            if ($norm -ceq $dst -or $norm.StartsWith($dst + "/", [StringComparison]::Ordinal)) {
                $covered = $true
                break
            }
        }
        if (-not $covered) {
            Add-ValidationFail -Message "FAIL mustExist not covered by manifest managed entries: $rel" -FailCount $FailCount -MessageLog $MessageLog
        }
    }

    Test-BootstrapWouldShipVerifyHarness -Root $Root -FailCount $FailCount
    if ($manifest.Values | Where-Object {
            (Normalize-RelPath ([string]$_.destination)) -ceq $VerifyHarnessRel -and
            [string]$_.policy -ne "toolkit-ci-only"
        }) {
        Add-ValidationFail -Message "FAIL verify-harness.ps1 must remain toolkit-ci-only in manifest" -FailCount $FailCount -MessageLog $MessageLog
    }
}

function Write-TempManifest {
    param([hashtable]$Obj, [string]$Path)
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    ($Obj | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Invoke-ParserSelfTests {
    $script:parseFail = 0
    function Assert-True($cond, [string]$msg) {
        if ($cond) { Write-Host "OK  $msg" } else { Write-Host "FAIL $msg"; $script:parseFail++ }
    }
    $tempRoot = Join-Path $env:TEMP ("cptk-ship-parse-" + [guid]::NewGuid().ToString("n"))
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    try {
        $badLiteral = Join-Path $tempRoot "bad-literal.ps1"
        @'
$sample = @(
    ".gitattributes",
    $dynamic
)
'@ | Set-Content -LiteralPath $badLiteral -Encoding UTF8
        $threw = $false
        try { Get-PsStringArrayAssignment -FilePath $badLiteral -VariableName "sample" | Out-Null } catch { $threw = $true }
        Assert-True $threw "nonliteral array element rejected"

        $truncated = Join-Path $tempRoot "truncated.ps1"
        @'
$sample = @(
    ".gitattributes",
    ".cursor/hooks.json"
'@ | Set-Content -LiteralPath $truncated -Encoding UTF8
        $threw2 = $false
        try { Get-PsStringArrayAssignment -FilePath $truncated -VariableName "sample" | Out-Null } catch { $threw2 = $true }
        Assert-True $threw2 "truncated array rejected"

        $subExpr = Join-Path $tempRoot "subexpr.ps1"
        @'
$sample = @(
    ".gitattributes",
    $("bad")
)
'@ | Set-Content -LiteralPath $subExpr -Encoding UTF8
        $threw3 = $false
        try { Get-PsStringArrayAssignment -FilePath $subExpr -VariableName "sample" | Out-Null } catch { $threw3 = $true }
        Assert-True $threw3 "subexpression array element rejected"
    } finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    return $script:parseFail
}

function Invoke-SelfTest {
    $script:selfTestFail = 0
    function Assert-True($cond, [string]$msg) {
        if ($cond) { Write-Host "OK  $msg" } else { Write-Host "FAIL $msg"; $script:selfTestFail++ }
    }
    function Assert-ValidationReason {
        param(
            [string]$ManifestPath,
            [string]$ExpectedReasonFragment,
            [string]$Label
        )
        $fFail = 0
        $log = New-Object System.Collections.Generic.List[string]
        Invoke-ManifestValidation -Root $liveRoot -ManifestFile $ManifestPath -FailCount ([ref]$fFail) -MessageLog $log
        $text = ($log -join "`n")
        if ($fFail -le 0) {
            Assert-True $false "$Label expected validation failure"
            return
        }
        Assert-True ($text -match [regex]::Escape($ExpectedReasonFragment)) "$Label reason contains: $ExpectedReasonFragment"
    }
    function Assert-LoadReason {
        param(
            [string]$ManifestPath,
            [string]$ExpectedReasonFragment,
            [string]$Label
        )
        $threw = $false
        $msg = ""
        try {
            Load-ManifestEntries -Path $ManifestPath | Out-Null
        } catch {
            $threw = $true
            $msg = [string]$_.Exception.Message
        }
        Assert-True $threw "$Label expected load failure"
        if ($threw) {
            Assert-True ($msg -match [regex]::Escape($ExpectedReasonFragment)) "$Label reason contains: $ExpectedReasonFragment"
        }
    }

    Write-Host "=== validate-shipping-manifest SelfTest ==="
    $liveRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    $liveManifest = Join-Path $liveRoot "shipping\manifest.v1.json"
    $script:selfTestFail += Invoke-ParserSelfTests

    $liveFail = 0
    Invoke-ManifestValidation -Root $liveRoot -ManifestFile $liveManifest -FailCount ([ref]$liveFail)
    Assert-True ($liveFail -eq 0) "live manifest matches bootstrap arrays"

    $tempRoot = Join-Path $env:TEMP ("cptk-ship-selftest-" + [guid]::NewGuid().ToString("n"))
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    try {
        $liveObj = Get-Content -LiteralPath $liveManifest -Raw -Encoding UTF8 | ConvertFrom-Json

        $missingPath = Join-Path $tempRoot "missing.json"
        Assert-LoadReason -ManifestPath $missingPath -ExpectedReasonFragment "missing manifest" -Label "missing manifest io"

        $badJsonPath = Join-Path $tempRoot "bad-json.json"
        "{ not json" | Set-Content -LiteralPath $badJsonPath -Encoding UTF8
        Assert-LoadReason -ManifestPath $badJsonPath -ExpectedReasonFragment "manifest json parse error" -Label "malformed json"

        $dupPath = Join-Path $tempRoot "duplicate-id.json"
        Write-TempManifest -Path $dupPath -Obj @{
            schema_version = 1
            manifest_version = "v1"
            entries = @(
                @{ id = "dup"; policy = "managed"; surface = "essential"; source = ".gitattributes"; destination = ".gitattributes"; bootstrap_ref = "test" }
                @{ id = "dup"; policy = "managed"; surface = "essential"; source = "AGENTS.md"; destination = "AGENTS.md"; bootstrap_ref = "test" }
            )
        }
        Assert-LoadReason -ManifestPath $dupPath -ExpectedReasonFragment "duplicate manifest id" -Label "duplicate id"

        $unknownPath = Join-Path $tempRoot "unknown-policy.json"
        Write-TempManifest -Path $unknownPath -Obj @{
            schema_version = 1
            manifest_version = "v1"
            entries = @(
                @{ id = "bad-policy"; policy = "not-a-policy"; surface = "essential"; source = ".gitattributes"; destination = ".gitattributes"; bootstrap_ref = "test" }
            )
        }
        Assert-LoadReason -ManifestPath $unknownPath -ExpectedReasonFragment "unknown policy" -Label "unknown policy"

        $missingEntryPath = Join-Path $tempRoot "missing-entry.json"
        Write-TempManifest -Path $missingEntryPath -Obj @{
            schema_version = 1
            manifest_version = "v1"
            policies = $liveObj.policies
            entries = @($liveObj.entries | Select-Object -Skip 1)
        }
        Assert-ValidationReason -ManifestPath $missingEntryPath -ExpectedReasonFragment "manifest missing expected entry" -Label "missing expected entry"

        $extraPath = Join-Path $tempRoot "extra-entry.json"
        Write-TempManifest -Path $extraPath -Obj @{
            schema_version = 1
            manifest_version = "v1"
            policies = $liveObj.policies
            entries = @($liveObj.entries) + @(
                @{ id = "extra-spurious-entry"; policy = "managed"; surface = "essential"; source = "does/not/exist.txt"; destination = "does/not/exist.txt"; bootstrap_ref = "spurious" }
            )
        }
        Assert-ValidationReason -ManifestPath $extraPath -ExpectedReasonFragment "manifest extra entry" -Label "extra entry"
    } finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host ""
    if ($script:selfTestFail -eq 0) {
        Write-Host "SHIPPING_MANIFEST_SELFTEST_PASS"
        exit 0
    }
    Write-Host "SHIPPING_MANIFEST_SELFTEST_FAIL: $script:selfTestFail"
    exit 1
}

if ($EmitManifest) {
    $expected = Build-ExpectedEntries -Root $ProjectRoot
    $entries = @($expected.Values | Sort-Object { [string]$_.id })
    $obj = [ordered]@{
        schema_version = 1
        manifest_version = "v1"
        policies = $AllowedPolicies
        entries = $entries
    }
    $outPath = if ($ManifestPath) { $ManifestPath } else { Join-Path $ProjectRoot "shipping\manifest.v1.json" }
    $outDir = Split-Path -Parent $outPath
    if (-not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    }
    $jsonLines = ($obj | ConvertTo-Json -Depth 8 -Compress:$false) -split "`r?`n"
    ($jsonLines | ForEach-Object { $_.TrimEnd() }) -join "`n" | Set-Content -LiteralPath $outPath -Encoding UTF8 -NoNewline
    Add-Content -LiteralPath $outPath -Value "" -Encoding UTF8
    Write-Host "SHIPPING_MANIFEST_EMIT_OK path=$outPath count=$($entries.Count)"
    exit 0
}

if ($SelfTest) {
    Invoke-SelfTest
    exit $LASTEXITCODE
}

$fail = 0
Invoke-ManifestValidation -Root $ProjectRoot -ManifestFile $ManifestPath -FailCount ([ref]$fail)
if ($fail -eq 0) {
    Write-Host "SHIPPING_MANIFEST_VALIDATE_PASS entries_checked"
    exit 0
}
Write-Host "SHIPPING_MANIFEST_VALIDATE_FAIL: $fail"
exit 1

<#
.SYNOPSIS
  Validate MCP profile templates (Windows PowerShell 5.1).
#>
param(
    [string]$ProfilesRoot = "",

    [switch]$SelfTest
)

$ErrorActionPreference = "Stop"
$ScriptRoot = $PSScriptRoot
$ToolkitRoot = (Resolve-Path (Join-Path $ScriptRoot "..")).Path
$Fail = 0
$FailMessageCapture = $null

$ValidStatus = @("eligible", "proposal-only")
$ValidProvenance = @("official", "vendor", "curated", "community")
$ValidTransport = @("stdio", "http", "sse")
$ValidPinKind = @("npm", "pypi", "docker", "http", "none")
$ValidPlacement = @("local", "cloud", "both")

$TopLevelKeys = @(
    "id", "status", "provenance", "risk_override", "transport", "pin",
    "placement", "default_scopes", "mutation_tools", "mcp_allowlist",
    "redundant_if", "required_env", "prod_forbidden", "prod_hosts", "mcp_fragment"
)
$PinKeys = @("kind", "value")

$PinRegexNpm = '^(@[^/]+/[^@]+|[^@/]+)@\d+\.\d+\.\d+$'
$PinRegexPypi = '^[A-Za-z0-9._-]+==\d+\.\d+\.\d+$'
$PinRegexDocker = '^[^@\s]+@sha256:[0-9a-fA-F]{64}$'

$SecretPatterns = @(
    '(?i)Bearer\s+(?!\$\{env:[A-Za-z_][A-Za-z0-9_]*\})[^\s{]+',
    '(?i)Basic\s+\S+',
    '\b(sk-|ghp_|gho_|xox[baprs]-|AIza)',
    'BEGIN (RSA |OPENSSH )?PRIVATE KEY',
    '(?i)(password|secret|api[_-]?key|token|client_secret)\s*[=:]\s*[^$\s{]',
    '(?i)(postgres|mysql|mongodb)(\+\w+)?://[^\s:]+:[^@\s]+@'
)

$MutationToolPattern = '(?i)(^|[_-])(create|write|update|delete|merge|push|deploy|transfer|remove|destroy|drop)($|[_-])'
$UnpinnedPatterns = @('latest', '@latest', ':latest')

$AllowedInterpolation = '^\$\{env:[A-Za-z_][A-Za-z0-9_]*\}$|^\$\{workspaceFolder\}$|^\$\{userHome\}$|^\$\{pathSeparator\}$|^\$\{\/\}$'

function Pass([string]$Message) {
    Write-Host "OK  $Message"
}

function Fail([string]$Message) {
    Write-Host "FAIL $Message"
    if ($null -ne $script:FailMessageCapture) {
        [void]$script:FailMessageCapture.Add($Message)
    }
    $script:Fail++
}

function Assert-True($Condition, [string]$Message) {
    if ($Condition) { Pass $Message } else { Fail $Message }
}

function Read-JsonFile([string]$Path) {
    $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    if ($raw.Length -gt 0 -and [int][char]$raw[0] -eq 0xFEFF) {
        $raw = $raw.Substring(1)
    }
    return ($raw | ConvertFrom-Json)
}

function Get-ObjectKeys($Obj) {
    if ($null -eq $Obj) { return @() }
    return @($Obj.PSObject.Properties | ForEach-Object { [string]$_.Name })
}

function Test-UniqueStringArray($Arr, [string]$Label, [string]$FileLabel) {
    if ($null -eq $Arr) {
        Fail "$Label required ($FileLabel)"
        return $false
    }
    $items = @($Arr)
    $seen = @{}
    $ok = $true
    foreach ($item in $items) {
        $s = [string]$item
        if ([string]::IsNullOrWhiteSpace($s)) {
            Fail "$Label contains empty value ($FileLabel)"
            $ok = $false
        } elseif ($seen.ContainsKey($s)) {
            Fail "$Label duplicate: $s ($FileLabel)"
            $ok = $false
        } else {
            $seen[$s] = $true
        }
    }
    return $ok
}

function Test-AllowedSecretReference([string]$Value) {
    if ([string]::IsNullOrEmpty($Value)) { return $true }
    return ($Value -match $AllowedInterpolation)
}

function Test-SecretPatterns([string]$Value, [string]$Context, [string]$FileLabel) {
    if ([string]::IsNullOrEmpty($Value)) { return $true }
    if (Test-AllowedSecretReference $Value) { return $true }
    foreach ($pat in $SecretPatterns) {
        if ($Value -match $pat) {
            Fail "secret pattern in $Context ($FileLabel)"
            return $false
        }
    }
    if (-not (Test-UrlUserInfoInValue $Value $Context $FileLabel)) {
        return $false
    }
    return $true
}

function Test-UrlUserInfoInValue([string]$Value, [string]$Context, [string]$FileLabel) {
    if ([string]::IsNullOrEmpty($Value)) { return $true }
    if ($Value -notmatch '(?i)https?://') { return $true }
    foreach ($m in [regex]::Matches($Value, '(?i)https?://[^\s''"]+')) {
        try {
            $uri = [System.Uri]$m.Value
            if ($uri.IsAbsoluteUri -and $uri.Scheme -match '^(?i)https?$' -and -not [string]::IsNullOrEmpty($uri.UserInfo)) {
                Fail "url userinfo in $Context ($FileLabel)"
                return $false
            }
        } catch { }
    }
    return $true
}

function Add-ProfileStrings($Node, [string]$Prefix, $StringsList) {
    if ($null -eq $Node) { return }
    if ($Node -is [bool] -or $Node -is [int] -or $Node -is [long] -or $Node -is [double]) { return }
    if ($Node -is [string]) {
        [void]$StringsList.Add(@{ Context = $Prefix; Value = [string]$Node })
        return
    }
    if ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [string])) {
        $i = 0
        foreach ($item in @($Node)) {
            Add-ProfileStrings $item "$Prefix[$i]" $StringsList
            $i++
        }
        return
    }
    if ($Node.PSObject -and $Node.PSObject.Properties) {
        foreach ($prop in $Node.PSObject.Properties) {
            $name = [string]$prop.Name
            $childPrefix = if ([string]::IsNullOrEmpty($Prefix)) { $name } else { "$Prefix.$name" }
            Add-ProfileStrings $prop.Value $childPrefix $StringsList
        }
    }
}

function Get-FragmentStrings($Node, $StringsList, [ref]$HasEnvFile) {
    if ($null -eq $Node) { return }
    if ($Node -is [string]) {
        [void]$StringsList.Add([string]$Node)
        return
    }
    if ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [string])) {
        foreach ($item in @($Node)) {
            Get-FragmentStrings $item $StringsList ([ref]$HasEnvFile)
        }
        return
    }
    if ($Node.PSObject -and $Node.PSObject.Properties) {
        foreach ($prop in $Node.PSObject.Properties) {
            $name = [string]$prop.Name
            if ($name -eq "envFile") {
                $HasEnvFile.Value = $true
            }
            Get-FragmentStrings $prop.Value $StringsList ([ref]$HasEnvFile)
        }
    }
}

function Get-ServerUrls($Fragment, $UrlsList) {
    if ($null -eq $Fragment -or $null -eq $Fragment.mcpServers) { return }
    foreach ($prop in $Fragment.mcpServers.PSObject.Properties) {
        $srv = $prop.Value
        if ($null -eq $srv) { continue }
        if ($null -ne $srv.url) {
            $u = [string]$srv.url
            if ($u -match '^https?://') {
                [void]$UrlsList.Add($u)
            }
        }
        if ($null -ne $srv.args) {
            foreach ($arg in @($srv.args)) {
                $a = [string]$arg
                if ($a -match '^https?://') {
                    [void]$UrlsList.Add($a)
                }
            }
        }
    }
}

function Normalize-Hostname([string]$Url) {
    try {
        $uri = [System.Uri]$Url
        $hostName = [string]$uri.Host
        if ($hostName.EndsWith(".")) {
            $hostName = $hostName.TrimEnd(".")
        }
        return $hostName.ToLowerInvariant()
    } catch {
        return $null
    }
}

function Test-HostnameMatchesProd([string]$Hostname, [string[]]$ProdHosts) {
    if ([string]::IsNullOrWhiteSpace($Hostname)) { return $false }
    foreach ($ph in $ProdHosts) {
        $p = [string]$ph
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        $p = $p.ToLowerInvariant().TrimEnd(".")
        if ($Hostname -eq $p) { return $true }
        if ($Hostname.EndsWith("." + $p)) { return $true }
    }
    return $false
}

function Test-BoundedHostTokenInText([string]$Text, [string]$ProdHost) {
    if ([string]::IsNullOrWhiteSpace($Text) -or [string]::IsNullOrWhiteSpace($ProdHost)) { return $false }
    $h = [string]$ProdHost
    $h = $h.ToLowerInvariant().TrimEnd(".")
    $pat = '(?<![A-Za-z0-9._-])' + [regex]::Escape($h) + '(?![A-Za-z0-9._-])'
    return ($Text -match $pat)
}

function Test-ProdHostInFragmentString([string]$Str, [string[]]$ProdHosts) {
    if ([string]::IsNullOrWhiteSpace($Str)) { return $false }
    if ($Str -match '(?mi)\bhost\s*=\s*([^\s;,&"''`]+)') {
        $hostVal = [string]$matches[1].Trim().TrimEnd('/')
        $parsedHost = $null
        if ($hostVal -match '^https?://') {
            $parsedHost = Normalize-Hostname $hostVal
        } else {
            $parsedHost = $hostVal.ToLowerInvariant().TrimEnd(".")
        }
        if ($null -ne $parsedHost -and (Test-HostnameMatchesProd $parsedHost $ProdHosts)) {
            return $true
        }
    }
    if ($Str -match 'https?://') {
        try {
            $uri = [System.Uri]$Str
            $hn = Normalize-Hostname $Str
            if ($null -ne $hn -and (Test-HostnameMatchesProd $hn $ProdHosts)) {
                return $true
            }
            foreach ($seg in @($uri.AbsolutePath, $uri.Query, $uri.Fragment)) {
                if ([string]::IsNullOrEmpty($seg)) { continue }
                foreach ($ph in $ProdHosts) {
                    if (Test-BoundedHostTokenInText $seg $ph) { return $true }
                }
            }
        } catch { }
    }
    foreach ($ph in $ProdHosts) {
        if (Test-BoundedHostTokenInText $Str $ph) { return $true }
    }
    return $false
}

function Get-CommandArgsStrings($Fragment) {
    $list = New-Object System.Collections.ArrayList
    if ($null -eq $Fragment -or $null -eq $Fragment.mcpServers) { return $list }
    foreach ($prop in $Fragment.mcpServers.PSObject.Properties) {
        $srv = $prop.Value
        if ($null -eq $srv) { continue }
        if ($null -ne $srv.command) {
            [void]$list.Add([string]$srv.command)
        }
        if ($null -ne $srv.args) {
            foreach ($arg in @($srv.args)) {
                [void]$list.Add([string]$arg)
            }
        }
    }
    return $list
}

function Test-ConflictingPinTokens([string]$PinKind, [string]$PinValue, $CommandArgsStrings, [string]$Label) {
    $ok = $true
    $blob = ($CommandArgsStrings | ForEach-Object { [string]$_ }) -join " "
    switch ($PinKind) {
        "npm" {
            foreach ($m in [regex]::Matches($blob, '(@[^/]+/[^@\s]+|[^@\s/]+)@\d+\.\d+\.\d+')) {
                if ($m.Value -ne $PinValue) {
                    Fail "conflicting npm pin token '$($m.Value)' in command/args ($Label)"
                    $ok = $false
                }
            }
        }
        "pypi" {
            foreach ($m in [regex]::Matches($blob, '[A-Za-z0-9._-]+==\d+\.\d+\.\d+')) {
                if ($m.Value -ne $PinValue) {
                    Fail "conflicting pypi pin token '$($m.Value)' in command/args ($Label)"
                    $ok = $false
                }
            }
        }
        "docker" {
            foreach ($m in [regex]::Matches($blob, '[^@\s]+@sha256:[0-9a-fA-F]{64}')) {
                if ($m.Value -ne $PinValue) {
                    Fail "conflicting docker pin token '$($m.Value)' in command/args ($Label)"
                    $ok = $false
                }
            }
        }
    }
    return $ok
}

function Get-AllowlistToolNames([string[]]$Allowlist) {
    $tools = @()
    foreach ($entry in @($Allowlist)) {
        $e = [string]$entry
        if ($e -match ':([^:]+)$') {
            $tools += $matches[1]
        }
    }
    return $tools
}

function Test-PinTokenPresent([string]$PinValue, $Strings) {
    foreach ($s in @($Strings)) {
        $text = [string]$s
        if ($text -eq $PinValue) {
            return $true
        }
        foreach ($token in ($text -split '\s+')) {
            if ($token -eq $PinValue) {
                return $true
            }
        }
    }
    return $false
}

function Test-PinUsedInFragment($Profile, [string]$Label, $CommandArgsStrings) {
    $pinKind = [string]$Profile.pin.kind
    $pinValue = [string]$Profile.pin.value
    $blob = ($CommandArgsStrings | ForEach-Object { [string]$_ }) -join " "

    foreach ($bad in $UnpinnedPatterns) {
        if ($blob -match [regex]::Escape($bad)) {
            Fail "unpinned/latest reference in command/args ($Label)"
            return $false
        }
    }

    $ok = $true
    switch ($pinKind) {
        "npm" {
            if ($pinValue -notmatch '^(.+)@(\d+\.\d+\.\d+)$') {
                Fail "npm pin format ($Label)"
                return $false
            }
            if (-not (Test-PinTokenPresent $pinValue $CommandArgsStrings)) {
                Fail "npm pin identity not used in command/args ($Label)"
                $ok = $false
            }
        }
        "pypi" {
            if ($pinValue -notmatch '^(.+)==(\d+\.\d+\.\d+)$') {
                Fail "pypi pin format ($Label)"
                return $false
            }
            if (-not (Test-PinTokenPresent $pinValue $CommandArgsStrings)) {
                Fail "pypi pin identity not used in command/args ($Label)"
                $ok = $false
            }
        }
        "docker" {
            if ($pinValue -notmatch '^(.+)@sha256:([0-9a-fA-F]{64})$') {
                Fail "docker pin format ($Label)"
                return $false
            }
            if (-not (Test-PinTokenPresent $pinValue $CommandArgsStrings)) {
                Fail "docker pin identity not used in command/args ($Label)"
                $ok = $false
            }
        }
    }
    if (-not $ok) { return $false }
    if ($pinKind -in @("npm", "pypi", "docker")) {
        return (Test-ConflictingPinTokens $pinKind $pinValue $CommandArgsStrings $Label)
    }
    return $true
}

function Test-MutationAllowlistCompliance($Profile, [string]$Label) {
    $mutationTools = @($Profile.mutation_tools | ForEach-Object { [string]$_ })
    $allowTools = Get-AllowlistToolNames @($Profile.mcp_allowlist | ForEach-Object { [string]$_ })
    $status = [string]$Profile.status
    $suspected = @()
    foreach ($tool in $allowTools) {
        if ($tool -match $MutationToolPattern) {
            $suspected += $tool
        }
    }
    if ($suspected.Count -eq 0) { return $true }

    foreach ($tool in $suspected) {
        if ($mutationTools -notcontains $tool) {
            Fail "allowlisted mutation-pattern tool '$tool' undeclared in mutation_tools ($Label)"
            return $false
        }
    }
    return $true
}

function Get-SingleServerUrl($Profile) {
    $fragment = $Profile.mcp_fragment
    if ($null -eq $fragment -or $null -eq $fragment.mcpServers) { return $null }
    $servers = @($fragment.mcpServers.PSObject.Properties)
    if ($servers.Count -ne 1) { return $null }
    $server = $servers[0].Value
    if ($null -ne $server.url) {
        return [string]$server.url
    }
    return $null
}

function Test-McpProfile([string]$FilePath) {
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
    $label = $fileName

    $profile = $null
    try {
        $profile = Read-JsonFile $FilePath
    } catch {
        Fail "JSON parse failed: $label - $($_.Exception.Message)"
        return
    }

    $topKeys = Get-ObjectKeys $profile
    foreach ($k in $topKeys) {
        if ($TopLevelKeys -notcontains $k) {
            Fail "unknown field '$k' ($label)"
        }
    }
    foreach ($req in $TopLevelKeys) {
        if ($topKeys -notcontains $req) {
            Fail "missing field '$req' ($label)"
        }
    }

    $id = [string]$profile.id
    Assert-True ($id -eq $fileName) "filename equals id ($label)"

    $status = [string]$profile.status
    if ($ValidStatus -notcontains $status) {
        Fail "invalid status: $status ($label)"
    }

    $provenance = [string]$profile.provenance
    if ($ValidProvenance -notcontains $provenance) {
        Fail "invalid provenance: $provenance ($label)"
    }

    $riskOverride = $false
    if ($profile.risk_override -is [bool]) {
        $riskOverride = $profile.risk_override
    } elseif ($null -ne $profile.risk_override) {
        $rs = [string]$profile.risk_override
        if ($rs -in @("True", "False", "true", "false")) {
            $riskOverride = [System.Convert]::ToBoolean($rs)
        } else {
            Fail "risk_override must be boolean ($label)"
        }
    }

    if ($provenance -eq "community" -and -not $riskOverride) {
        Fail "community requires risk_override:true ($label)"
    }

    $transport = [string]$profile.transport
    if ($ValidTransport -notcontains $transport) {
        Fail "invalid transport: $transport ($label)"
    }

    $placement = [string]$profile.placement
    if ($ValidPlacement -notcontains $placement) {
        Fail "invalid placement: $placement ($label)"
    }

    $null = Test-UniqueStringArray $profile.default_scopes "default_scopes" $label
    $null = Test-UniqueStringArray $profile.mutation_tools "mutation_tools" $label
    $null = Test-UniqueStringArray $profile.mcp_allowlist "mcp_allowlist" $label
    $null = Test-UniqueStringArray $profile.redundant_if "redundant_if" $label
    $null = Test-UniqueStringArray $profile.required_env "required_env" $label
    $null = Test-UniqueStringArray $profile.prod_hosts "prod_hosts" $label

    $prodForbidden = $false
    if ($profile.prod_forbidden -is [bool]) {
        $prodForbidden = $profile.prod_forbidden
    } elseif ($null -ne $profile.prod_forbidden) {
        $ps = [string]$profile.prod_forbidden
        if ($ps -in @("True", "False", "true", "false")) {
            $prodForbidden = [System.Convert]::ToBoolean($ps)
        } else {
            Fail "prod_forbidden must be boolean ($label)"
        }
    }

    $prodHosts = @($profile.prod_hosts | ForEach-Object { [string]$_ })
    if ($prodForbidden -and $prodHosts.Count -lt 1) {
        Fail "prod_forbidden requires non-empty prod_hosts ($label)"
    }

    $pin = $profile.pin
    if ($null -eq $pin) {
        Fail "pin required ($label)"
    } else {
        $pinKeys = Get-ObjectKeys $pin
        foreach ($pk in $pinKeys) {
            if ($PinKeys -notcontains $pk) {
                Fail "unknown pin field '$pk' ($label)"
            }
        }
        foreach ($pk in $PinKeys) {
            if ($pinKeys -notcontains $pk) {
                Fail "missing pin field '$pk' ($label)"
            }
        }
        $pinKind = [string]$pin.kind
        $pinValue = [string]$pin.value
        if ($ValidPinKind -notcontains $pinKind) {
            Fail "invalid pin.kind: $pinKind ($label)"
        }

        if ($transport -eq "stdio") {
            if ($pinKind -notin @("npm", "pypi", "docker")) {
                Fail "stdio requires npm/pypi/docker pin ($label)"
            }
        } elseif ($transport -in @("http", "sse")) {
            if ($pinKind -notin @("http", "none")) {
                Fail "http/sse requires http/none pin ($label)"
            }
        }

        $serverUrl = Get-SingleServerUrl $profile
        switch ($pinKind) {
            "npm" {
                if ($pinValue -notmatch $PinRegexNpm) {
                    Fail "npm pin format ($label)"
                }
            }
            "pypi" {
                if ($pinValue -notmatch $PinRegexPypi) {
                    Fail "pypi pin format ($label)"
                }
            }
            "docker" {
                if ($pinValue -notmatch $PinRegexDocker) {
                    Fail "docker pin format ($label)"
                }
            }
            "http" {
                if ($null -eq $serverUrl -or $pinValue -ne $serverUrl) {
                    Fail "http pin must equal server URL ($label)"
                }
                if ($pinValue -notmatch '^https://') {
                    Fail "http pin must be absolute HTTPS ($label)"
                }
            }
            "none" {
                if ($provenance -notin @("official", "vendor")) {
                    Fail "pin none allowed only for official/vendor ($label)"
                }
                if ($null -eq $serverUrl -or $serverUrl -notmatch '^https://') {
                    Fail "none pin requires absolute HTTPS server URL ($label)"
                }
            }
        }
    }

    $mutationTools = @($profile.mutation_tools | ForEach-Object { [string]$_ })
    $allowlist = @($profile.mcp_allowlist | ForEach-Object { [string]$_ })
    $exactAllowlistFail = $false

    foreach ($entry in $allowlist) {
        if ($entry -eq "*:*") {
            Fail "mcp_allowlist wildcard *:* ($label)"
        }
        if ($entry -match ':\*$') {
            Fail "mcp_allowlist server wildcard ($label)"
        }
        foreach ($tool in $mutationTools) {
            if ($entry -match ":$([regex]::Escape($tool))$") {
                Fail "mcp_allowlist exact mutation entry ($label)"
                $exactAllowlistFail = $true
            }
        }
    }

    if ($mutationTools.Count -gt 0) {
        if ($id -notmatch '-mutating$') {
            Fail "mutation_tools require -mutating id suffix ($label)"
        }
        if (-not $riskOverride) {
            Fail "mutation_tools require risk_override:true ($label)"
        }
        if ($status -ne "proposal-only") {
            Fail "mutation_tools require status proposal-only ($label)"
        }
        if ($allowlist.Count -gt 0 -and -not $exactAllowlistFail) {
            Fail "mutation_tools require empty mcp_allowlist ($label)"
        }
    }

    $fragment = $profile.mcp_fragment
    if ($null -eq $fragment) {
        Fail "mcp_fragment required ($label)"
        return
    }
    $fragKeys = Get-ObjectKeys $fragment
    $hasMcpServers = $false
    foreach ($fk in $fragKeys) {
        if ($fk -eq "mcpServers") {
            $hasMcpServers = $true
        } else {
            Fail "mcp_fragment unknown key '$fk' ($label)"
        }
    }
    if (-not $hasMcpServers) {
        Fail "mcp_fragment missing mcpServers ($label)"
    }
    $servers = @($fragment.mcpServers.PSObject.Properties)
    if ($servers.Count -ne 1) {
        Fail "mcp_fragment exactly one mcpServers entry ($label)"
    }
    foreach ($srvProp in $servers) {
        $srv = $srvProp.Value
        if ($null -ne $srv -and $null -ne $srv.PSObject.Properties["envFile"]) {
            Fail "envFile forbidden ($label)"
        }
    }

    $fragStrings = New-Object System.Collections.ArrayList
    $hasEnvFile = $false
    Get-FragmentStrings $fragment $fragStrings ([ref]$hasEnvFile)
    if ($hasEnvFile) {
        Fail "envFile forbidden ($label)"
    }

    $profileStrings = New-Object System.Collections.ArrayList
    Add-ProfileStrings $profile "" $profileStrings
    foreach ($entry in @($profileStrings)) {
        $ctx = [string]$entry.Context
        $val = [string]$entry.Value
        if ([string]::IsNullOrEmpty($ctx)) { $ctx = "profile" }
        $null = Test-SecretPatterns $val $ctx $label
    }

    $cmdArgs = Get-CommandArgsStrings $fragment
    $null = Test-PinUsedInFragment $profile $label $cmdArgs
    $null = Test-MutationAllowlistCompliance $profile $label

    if ($prodForbidden) {
        foreach ($s in @($fragStrings)) {
            if (Test-ProdHostInFragmentString ([string]$s) $prodHosts) {
                Fail "prod host match in fragment when prod_forbidden ($label)"
            }
        }
    }
}

function Test-ExpectedReasonInFailMessages([string]$Reason, [string[]]$Messages) {
    if ([string]::IsNullOrWhiteSpace($Reason)) { return $false }
    $blob = (($Messages | ForEach-Object { [string]$_ }) -join " ").ToLowerInvariant()
    $reasonLower = $Reason.ToLowerInvariant()
    if ($blob.Contains($reasonLower)) { return $true }
    $stopWords = @("missing", "required", "invalid", "the", "a", "an", "in")
    $tokens = [regex]::Split($reasonLower, "[^a-z0-9_]+") |
        Where-Object { $_ -and $_.Length -ge 3 -and ($stopWords -notcontains $_) }
    if ($tokens.Count -eq 0) {
        $tokens = [regex]::Split($reasonLower, "[^a-z0-9_]+") | Where-Object { $_ }
    }
    if ($tokens.Count -eq 0) { return $false }
    $matched = 0
    foreach ($token in $tokens) {
        if ($blob.Contains([string]$token)) { $matched++ }
    }
    $needed = [Math]::Max(1, [Math]::Ceiling($tokens.Count * 0.5))
    return ($matched -ge $needed)
}

function Test-ProfilesRoot([string]$Root) {
    if (-not (Test-Path -LiteralPath $Root)) {
        Fail "ProfilesRoot missing: $Root"
        return
    }
    $files = @(Get-ChildItem -LiteralPath $Root -Filter "*.json" -File)
    if ($files.Count -lt 1) {
        Fail "no profile JSON files in $Root"
        return
    }
    foreach ($f in $files) {
        Test-McpProfile $f.FullName
    }
}

function Invoke-SelfTest {
    Write-Host "=== validate-mcp-profiles self-test ==="
    $fixturesRoot = Join-Path $ToolkitRoot "tests\mcp-profiles"
    $positive = Join-Path $fixturesRoot "positive"
    $negative = Join-Path $fixturesRoot "negative"
    $assertFail = 0

    if (-not (Test-Path $positive)) {
        Fail "missing positive fixtures dir"
        return
    }
    if (-not (Test-Path $negative)) {
        Fail "missing negative fixtures dir"
        return
    }

    $start = $script:Fail
    Test-ProfilesRoot $positive
    if ($script:Fail -ne $start) {
        Write-Host "FAIL positive fixtures should pass"
        $assertFail++
    } else {
        Pass "positive fixtures pass"
    }
    $script:Fail = $start

    $expectedNegativeReasons = @{
        "bad-secret-url-userinfo.json" = "url userinfo"
        "bad-secret-url-userinfo-username.json" = "url userinfo"
        "bad-secret-url-userinfo-uppercase.json" = "url userinfo"
        "bad-secret-scopes-bearer.json" = "secret pattern in default_scopes"
        "bad-secret-scopes-token-kv.json" = "secret pattern in default_scopes"
    }

    $negFiles = @(Get-ChildItem -LiteralPath $negative -Filter "*.json" -File)
    foreach ($nf in $negFiles) {
        $before = $script:Fail
        $failMessages = New-Object System.Collections.ArrayList
        $prevCapture = $script:FailMessageCapture
        $script:FailMessageCapture = $failMessages
        try {
            Test-McpProfile $nf.FullName
        } finally {
            $script:FailMessageCapture = $prevCapture
        }
        if ($script:Fail -eq $before) {
            Write-Host "FAIL negative fixture should fail: $($nf.Name)"
            $assertFail++
        } else {
            Pass "negative fixture fails: $($nf.Name)"
            if ($expectedNegativeReasons.ContainsKey($nf.Name)) {
                $expectedReason = [string]$expectedNegativeReasons[$nf.Name]
                if (-not (Test-ExpectedReasonInFailMessages $expectedReason @($failMessages))) {
                    Write-Host "FAIL $($nf.Name) fail output should match reason: $expectedReason"
                    $assertFail++
                } else {
                    Pass "negative fixture reason: $($nf.Name) -> $expectedReason"
                }
                $blob = (($failMessages | ForEach-Object { [string]$_ }) -join " ")
                $fixture = Read-JsonFile $nf.FullName
                $fileLabel = [System.IO.Path]::GetFileNameWithoutExtension($nf.FullName)
                $leakStrings = New-Object System.Collections.ArrayList
                Add-ProfileStrings $fixture "" $leakStrings
                foreach ($entry in @($leakStrings)) {
                    $ctx = [string]$entry.Context
                    $val = [string]$entry.Value
                    if ($ctx -eq "id" -or $val -eq $fileLabel -or $val -eq [string]$fixture.id) { continue }
                    if ([string]::IsNullOrWhiteSpace($val)) { continue }
                    if ($val -match '^\$\{env:[A-Za-z_][A-Za-z0-9_]*\}$') { continue }
                    if ($val.Length -lt 8) { continue }
                    if ($blob.Contains($val)) {
                        Write-Host "FAIL $($nf.Name) fail output leaked secret substring"
                        $assertFail++
                        break
                    }
                }
            }
        }
        $script:Fail = $start
    }

    $malformedDir = Join-Path $fixturesRoot "malformed"
    $malformedFile = Join-Path $malformedDir "bad-malformed.json"
    if (-not (Test-Path -LiteralPath $malformedFile)) {
        Write-Host "FAIL missing malformed fixture: bad-malformed.json"
        $assertFail++
    } else {
        $before = $script:Fail
        Test-McpProfile $malformedFile
        if ($script:Fail -eq $before) {
            Write-Host "FAIL malformed fixture should fail JSON parse"
            $assertFail++
        } else {
            Pass "malformed fixture fails JSON parse"
        }
        $script:Fail = $start
    }

    $templatesRoot = Join-Path $ToolkitRoot "templates\mcp\profiles"
    if (Test-Path $templatesRoot) {
        $tStart = $script:Fail
        Test-ProfilesRoot $templatesRoot
        if ($script:Fail -ne $tStart) {
            Write-Host "FAIL shipped templates should pass"
            $assertFail++
        } else {
            Pass "shipped templates pass"
        }
        $script:Fail = $start
    }

    $script:Fail = $assertFail
}

Write-Host "=== Validate MCP profiles ==="

if ($SelfTest) {
    Invoke-SelfTest
} else {
    if ([string]::IsNullOrWhiteSpace($ProfilesRoot)) {
        $ProfilesRoot = Join-Path $ToolkitRoot "templates\mcp\profiles"
    } else {
        $ProfilesRoot = (Resolve-Path $ProfilesRoot).Path
    }
    Test-ProfilesRoot $ProfilesRoot
}

Write-Host ""
if ($Fail -eq 0) {
    Write-Host "MCP_VALIDATE_PASS"
    exit 0
}

Write-Host "MCP_VALIDATE_FAIL: $Fail finding(s)"
exit 1

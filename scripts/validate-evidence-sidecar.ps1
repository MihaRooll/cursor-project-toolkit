<#
.SYNOPSIS
  Validate toolkit evidence sidecar rows — authoritative schema walker, recursive privacy, promotion gate.
  Toolkit-only; not Essential bootstrap.
#>
param(
    [string]$InputPath = "",
    [string]$InputJson = "",
    [switch]$SelfTest,
    [switch]$LoadFunctionsOnly,
    [switch]$WriterMode
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$SchemaPath = Join-Path $Root "tests\orchestration\evidence-schema.json"
$MaxFieldNameLength = 128
$MaxStringValueLength = 4096
$ForbiddenFieldNames = @(
    "installed_at", "username", "hostname", "absolute_path", "private_path",
    "private_remote", "email", "plugin_inventory", "raw_prompt", "raw_log", "prompt_text", "log_text"
)
$SecretFieldNames = @("token", "api_key", "password", "secret", "authorization")
$ModelFieldNames = @("intended_model", "actual_model", "model")
$WriterPromotionStatus = "evidence_pending"
$script:Fail = 0
$script:SchemaDoc = $null

function Pass([string]$Message) { Write-Host "OK  $Message" }
function Fail([string]$Message) {
    Write-Host "FAIL $Message"
    $script:Fail++
}

function Assert-True($Condition, [string]$Message) {
    if ($Condition) { Pass $Message } else { Fail $Message }
}

function Get-SchemaDocument {
    if ($null -ne $script:SchemaDoc) { return $script:SchemaDoc }
    if (-not (Test-Path -LiteralPath $SchemaPath)) { throw "schema file missing" }
    $script:SchemaDoc = Get-Content -LiteralPath $SchemaPath -Raw -Encoding UTF8 | ConvertFrom-Json
    return $script:SchemaDoc
}

function Get-TypeList($Node) {
    if ($null -eq $Node -or $null -eq $Node.PSObject.Properties["type"]) { return @("object") }
    $t = $Node.type
    if ($t -is [System.Array]) { return @($t) }
    return @([string]$t)
}

function Test-IsIntegerNumber($Value) {
    if ($Value -is [int] -or $Value -is [long]) { return $true }
    if ($Value -is [double] -or $Value -is [decimal]) {
        return ($Value -eq [math]::Floor([double]$Value))
    }
    return $false
}

function Test-IsNumber($Value) {
    return ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal])
}

function Test-SchemaValue {
    param(
        $Value,
        $Node,
        [string]$Path
    )
    if ($null -eq $Node) { throw ("schema: node missing path=" + $Path) }

    $types = Get-TypeList $Node
    if ($null -eq $Value) {
        if ($types -contains "null") { return }
        throw ("schema: null rejected path=" + $Path)
    }

    $matched = $false
    foreach ($t in $types) {
        switch ($t) {
            "boolean" {
                if ($Value -is [bool]) { $matched = $true; break }
            }
            "integer" {
                if (Test-IsIntegerNumber $Value) { $matched = $true; break }
            }
            "number" {
                if (Test-IsNumber $Value) { $matched = $true; break }
            }
            "string" {
                if ($Value -is [string]) { $matched = $true; break }
            }
            "object" {
                if ($Value -is [PSCustomObject]) { $matched = $true; break }
            }
            "array" {
                if ($Value -is [System.Array]) { $matched = $true; break }
            }
        }
    }
    if (-not $matched) {
        throw ("schema: type rejected path=" + $Path)
    }

    if ($types -contains "string" -and $Value -is [string]) {
        if ($null -ne $Node.PSObject.Properties["minLength"]) {
            $minLen = [int]$Node.minLength
            if ($Value.Length -lt $minLen) {
                throw ("schema: minLength rejected path=" + $Path)
            }
        }
        if ($null -ne $Node.PSObject.Properties["maxLength"]) {
            $maxLen = [int]$Node.maxLength
            if ($Value.Length -gt $maxLen) {
                throw ("schema: maxLength rejected path=" + $Path)
            }
        }
        if ($null -ne $Node.PSObject.Properties["enum"]) {
            $ok = $false
            foreach ($ev in @($Node.enum)) {
                if ([string]$ev -ceq $Value) { $ok = $true; break }
            }
            if (-not $ok) { throw ("schema: enum rejected path=" + $Path) }
        }
        return
    }

    if ($types -contains "integer" -and (Test-IsIntegerNumber $Value)) {
        $iv = [int64]$Value
        if ($null -ne $Node.PSObject.Properties["minimum"]) {
            if ($iv -lt [int64]$Node.minimum) { throw ("schema: minimum rejected path=" + $Path) }
        }
        if ($null -ne $Node.PSObject.Properties["maximum"]) {
            if ($iv -gt [int64]$Node.maximum) { throw ("schema: maximum rejected path=" + $Path) }
        }
        return
    }

    if ($types -contains "number" -and (Test-IsNumber $Value)) {
        $dv = [double]$Value
        if ($null -ne $Node.PSObject.Properties["minimum"]) {
            if ($dv -lt [double]$Node.minimum) { throw ("schema: minimum rejected path=" + $Path) }
        }
        if ($null -ne $Node.PSObject.Properties["maximum"]) {
            if ($dv -gt [double]$Node.maximum) { throw ("schema: maximum rejected path=" + $Path) }
        }
        return
    }

    if ($types -contains "array" -and ($Value -is [System.Array])) {
        if ($null -ne $Node.PSObject.Properties["minItems"]) {
            if (@($Value).Count -lt [int]$Node.minItems) {
                throw ("schema: minItems rejected path=" + $Path)
            }
        }
        if ($null -ne $Node.PSObject.Properties["items"]) {
            $idx = 0
            foreach ($item in @($Value)) {
                Test-SchemaValue -Value $item -Node $Node.items -Path ($Path + "[" + $idx + "]")
                $idx++
            }
        }
        return
    }

    if ($types -contains "object" -and ($Value -is [PSCustomObject])) {
        $propNames = @($Value.PSObject.Properties.Name)
        if ($null -ne $Node.PSObject.Properties["required"]) {
            foreach ($req in @($Node.required)) {
                if ($propNames -notcontains [string]$req) {
                    throw ("schema: missing required path=" + $Path + " field=" + $req)
                }
            }
        }
        $allowed = @()
        if ($null -ne $Node.PSObject.Properties["properties"]) {
            $allowed = @($Node.properties.PSObject.Properties.Name)
        }
        $additional = $true
        if ($null -ne $Node.PSObject.Properties["additionalProperties"]) {
            $additional = [bool]$Node.additionalProperties
        }
        foreach ($name in $propNames) {
            if ($allowed -notcontains $name) {
                if (-not $additional) {
                    throw ("schema: unknown property path=" + $Path + " field=" + $name)
                }
            } else {
                $childSchema = $Node.properties.$name
                Test-SchemaValue -Value $Value.$name -Node $childSchema -Path ($Path + "." + $name)
            }
        }
    }
}

function Test-SchemaDocument {
    param([object]$Row)
    $schema = Get-SchemaDocument
    Test-SchemaValue -Value $Row -Node $schema -Path "$"
}

function Test-FieldNamePrivacy {
    param([string]$Name, [string]$Path)
    if ([string]::IsNullOrWhiteSpace($Name)) { throw ("privacy: empty field name path=" + $Path) }
    if ($Name.Length -gt $MaxFieldNameLength) { throw ("privacy: field name too long path=" + $Path) }
    $lower = $Name.ToLowerInvariant()
    foreach ($forbidden in $ForbiddenFieldNames) {
        if ($lower -ceq $forbidden) { throw ("privacy: forbidden field path=" + $Path + " field=" + $Name) }
    }
    foreach ($secretName in $SecretFieldNames) {
        if ($lower -ceq $secretName) { throw ("privacy: secret field path=" + $Path + " field=" + $Name) }
    }
}

function Test-ModelSlugValue {
    param([string]$Value)
    return ($Value -match '^[a-z0-9][a-z0-9.\-]*$')
}

function Test-StringLooksLikePath {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    if ($Value -match '(?i)^[A-Za-z]:[/\\]') { return $true }
    if ($Value -match '(?i)^\\\\[^\\]+\\') { return $true }
    if ($Value -match '(?i)^/(Users|home)(/|$)') { return $true }
    if ($Value -match '(?i)^\\(Users|home)\\') { return $true }
    if ($Value -match '(?i)/Users/') { return $true }
    if ($Value -match '(?i)/home/') { return $true }
    if ($Value -match '(?i)\\Users\\') { return $true }
    if ($Value -match '(?i)\\home\\') { return $true }
    return $false
}

function Test-StringSecretPattern {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    if ($Value -match '(?i)\bBearer\s+[A-Za-z0-9._\-+/=]{8,}') { return $true }
    if ($Value -match '(?i)\bsk-[A-Za-z0-9]{8,}') { return $true }
    if ($Value -match '(?i)\bghp_[A-Za-z0-9]{20,}') { return $true }
    if ($Value -match '(?i)\bgithub_pat_[A-Za-z0-9_]{20,}') { return $true }
    if ($Value -match '(?i)(^|[^a-z0-9_])(token|api_key|password|secret)\s*=\s*\S+') { return $true }
    if ($Value -match '(?i)://[^/]*@') { return $true }
    if ($Value -match '(?i)@[^\s/]+\.[^\s/]+') { return $true }
    return $false
}

function Test-StringPrivacy {
    param(
        [string]$Value,
        [string]$FieldName,
        [string]$Path
    )
    if ($null -eq $Value) { return }
    if ($Value.Length -gt $MaxStringValueLength) {
        throw ("privacy: value too long path=" + $Path)
    }

    if (Test-StringSecretPattern -Value $Value) {
        throw ("privacy: secret pattern path=" + $Path)
    }

    if ($ModelFieldNames -contains $FieldName) {
        if ($Value -ne "unknown" -and -not (Test-ModelSlugValue -Value $Value)) {
            throw ("privacy: invalid model slug path=" + $Path)
        }
    }

    if (Test-StringLooksLikePath -Value $Value) {
        throw ("privacy: absolute path path=" + $Path)
    }
}

function Test-PrivacyNode {
    param(
        $Node,
        [string]$Path,
        [string]$FieldName = ""
    )
    if ($null -eq $Node) { return }

    if ($Node -is [string]) {
        Test-StringPrivacy -Value $Node -FieldName $FieldName -Path $Path
        return
    }

    if ($Node -is [PSCustomObject]) {
        foreach ($prop in $Node.PSObject.Properties) {
            Test-FieldNamePrivacy -Name $prop.Name -Path ($Path + "." + $prop.Name)
            Test-PrivacyNode -Node $prop.Value -Path ($Path + "." + $prop.Name) -FieldName $prop.Name
        }
        return
    }

    if ($Node -is [System.Array]) {
        $idx = 0
        foreach ($item in @($Node)) {
            Test-PrivacyNode -Node $item -Path ($Path + "[" + $idx + "]") -FieldName $FieldName
            $idx++
        }
    }
}

function Test-WriterPromotion {
    param([object]$Row)
    $promo = [string]$Row.promotion_status
    if ($promo -ne $WriterPromotionStatus) {
        throw ("writer: promotion_status=" + $WriterPromotionStatus + " only")
    }
}

function New-ReparseRejectError {
    param([string]$Label)
    return ("reparse point rejected label=" + $Label)
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
                throw (New-ReparseRejectError -Label $Label)
            }
        }
        $parent = [System.IO.Path]::GetDirectoryName($current)
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $current) { break }
        $current = $parent
    }
}

function Get-Sha256Hex([byte[]]$Bytes) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($Bytes)).Replace("-", "").ToLowerInvariant())
    } finally {
        $sha.Dispose()
    }
}

function New-SampleEvidenceRow {
    param(
        [string]$ContractId = "sample-contract",
        [string]$TaskId = "sample-task",
        [string]$RunFingerprint = "a1b2c3d4e5f67890"
    )
    return [ordered]@{
        contract_id = $ContractId
        task_id = $TaskId
        run_fingerprint = $RunFingerprint
        tier = "T1"
        wall_clock = 120
        verification_profile = "targeted"
        verification_seconds = 45
        intended_role = "implementer"
        actual_role = "implementer"
        intended_model = "composer-2.5-fast"
        actual_model = $null
        model_role_calls = @(
            @{ role = "implementer"; model = "composer-2.5-fast"; count = 1 }
        )
        check_outcomes = @(
            @{ check_id = "Q-PARSE"; outcome = "pass" }
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
}

function Invoke-ValidateInput {
    param([string]$JsonText, [switch]$WriterMode)
    $obj = $JsonText | ConvertFrom-Json
    Test-PrivacyNode -Node $obj -Path "$"
    Test-SchemaDocument -Row $obj
    if ($WriterMode) {
        Test-WriterPromotion -Row $obj
    }
    return $obj
}

function Invoke-SelfTest {
    $script:Fail = 0
    function Assert-ThrowsMsg($scriptBlock, [string]$expectedToken, [string]$msg) {
        $threw = $false
        $errMsg = ""
        try { & $scriptBlock } catch { $threw = $true; $errMsg = $_.Exception.Message }
        if (-not $threw) { Fail ($msg + " (no throw)"); return }
        if ($errMsg -notlike ("*" + $expectedToken + "*")) { Fail ($msg + " (token=" + $expectedToken + " got=" + $errMsg + ")"); return }
        if ($errMsg -match '[A-Za-z]:\\' -or $errMsg -match '\\Users\\') { Fail ($msg + " (absolute path in error)"); return }
        Pass $msg
    }
    function Assert-ThrowsBounded($scriptBlock, [string]$msg) {
        $threw = $false
        $errMsg = ""
        try { & $scriptBlock } catch { $threw = $true; $errMsg = $_.Exception.Message }
        if (-not $threw) { Fail ($msg + " (no throw)"); return }
        if ($errMsg -match '[A-Za-z]:\\' -or $errMsg -match '\\Users\\') { Fail ($msg + " (absolute path in error)"); return }
        Pass $msg
    }

    Write-Host "=== validate-evidence-sidecar SelfTest ==="
    Assert-True (Test-Path -LiteralPath $SchemaPath) "schema path exists"

    $good = New-SampleEvidenceRow
    $goodJson = ($good | ConvertTo-Json -Depth 8 -Compress)
    $parsed = Invoke-ValidateInput -JsonText $goodJson
    Assert-True ($parsed.contract_id -eq "sample-contract") "positive row validates"
    Assert-True ($null -eq $parsed.actual_model) "nullable actual_model allowed"

    $goodTwice = Invoke-ValidateInput -JsonText $goodJson
    Assert-True ($parsed.contract_id -eq $goodTwice.contract_id) "deterministic validation same input"

    Assert-ThrowsMsg { Invoke-ValidateInput -JsonText ($goodJson -replace '"contract_id"', '"extra_top":"x","contract_id"') } "schema: unknown property" "reject extra top-level property"

    $nestedExtra = $goodJson -replace '"outcome":"pass"', '"outcome":"pass","extra_nested":"x"'
    Assert-ThrowsMsg { Invoke-ValidateInput -JsonText $nestedExtra } "schema: unknown property" "reject extra nested property"

    $badPromo = New-SampleEvidenceRow
    $badPromo.promotion_status = "promoted"
    Assert-ThrowsMsg { Invoke-ValidateInput -JsonText ($badPromo | ConvertTo-Json -Depth 8 -Compress) -WriterMode } "writer: promotion_status=evidence_pending only" "reject non-pending promotion in writer mode"

    Assert-ThrowsMsg { Invoke-ValidateInput -JsonText ($goodJson -replace '"protocol_violations":\[\]', '"protocol_violations":["/Users/leak/nested"]') } "privacy: absolute path" "reject nested posix path"

    Assert-ThrowsMsg { Invoke-ValidateInput -JsonText ($goodJson -replace '"protocol_violations":\[\]', '"protocol_violations":["C:/Users/leak/nested"]') } "privacy: absolute path" "reject nested windows-forward path"

    Assert-ThrowsMsg { Invoke-ValidateInput -JsonText ($goodJson -replace '"protocol_violations":\[\]', '"protocol_violations":["\\\\server\\share\\leak"]') } "privacy: absolute path" "reject nested UNC path"

    Assert-ThrowsMsg { Invoke-ValidateInput -JsonText ($goodJson -replace '"protocol_violations":\[\]', '"protocol_violations":["Bearer abcdefgh12345678"]') } "privacy: secret pattern" "reject Bearer secret"

    Assert-ThrowsMsg { Invoke-ValidateInput -JsonText ($goodJson -replace '"protocol_violations":\[\]', '"protocol_violations":["sk-abcdefghijklmnopqrst"]') } "privacy: secret pattern" "reject sk- secret"

    Assert-ThrowsMsg { Invoke-ValidateInput -JsonText ($goodJson -replace '"protocol_violations":\[\]', '"protocol_violations":["ghp_1234567890123456789012345678901234"]') } "privacy: secret pattern" "reject ghp_ secret"

    Assert-ThrowsMsg { Invoke-ValidateInput -JsonText ($goodJson -replace '"protocol_violations":\[\]', '"protocol_violations":["github_pat_1234567890123456789012345678901234567890"]') } "privacy: secret pattern" "reject github_pat secret"

    Assert-ThrowsMsg { Invoke-ValidateInput -JsonText ($goodJson -replace '"protocol_violations":\[\]', '"protocol_violations":["password=supersecret"]') } "privacy: secret pattern" "reject password assignment"

    Assert-ThrowsMsg { Invoke-ValidateInput -JsonText ($goodJson -replace '"contract_id"', '"username":"leak","contract_id"') } "privacy: forbidden field" "reject forbidden field username"

    $modelSlugRow = New-SampleEvidenceRow
    $modelSlugRow.intended_model = "composer-2.5-fast"
    $modelSlugRow.actual_model = "cursor-grok-4.5-high-fast"
    Invoke-ValidateInput -JsonText ($modelSlugRow | ConvertTo-Json -Depth 8 -Compress) | Out-Null
    Pass "model slugs allowed"

    $homeContract = New-SampleEvidenceRow
    $homeContract.contract_id = "/home/leak"
    Assert-ThrowsMsg { Invoke-ValidateInput -JsonText ($homeContract | ConvertTo-Json -Depth 8 -Compress) } "privacy: absolute path" "reject /home in contract_id"

    $usersReason = New-SampleEvidenceRow
    $usersReason | Add-Member -NotePropertyName premium_gate_reason -NotePropertyValue "/Users/leak" -Force
    Assert-ThrowsMsg { Invoke-ValidateInput -JsonText ($usersReason | ConvertTo-Json -Depth 8 -Compress) } "privacy: absolute path" "reject /Users in premium_gate_reason"

    $safeIds = New-SampleEvidenceRow
    $safeIds.contract_id = "homestead-users"
    $safeIds.task_id = "users-homestead-check"
    Invoke-ValidateInput -JsonText ($safeIds | ConvertTo-Json -Depth 8 -Compress) | Out-Null
    Pass "homestead/users IDs pass without rooted path form"

    $longFp = New-SampleEvidenceRow
    $longFp.run_fingerprint = ("a" * 80)
    Assert-ThrowsMsg { Invoke-ValidateInput -JsonText ($longFp | ConvertTo-Json -Depth 8 -Compress) } "schema: maxLength rejected" "reject 80-char run_fingerprint"

    Push-Location -LiteralPath $Root
    try {
        $ignoreLine = & git check-ignore -v ".cursor/evidence-local/" 2>$null
        Assert-True (-not [string]::IsNullOrWhiteSpace($ignoreLine)) "gitignore covers .cursor/evidence-local/"
    } finally {
        Pop-Location
    }

    $tempRoot = Join-Path $env:TEMP ("cptk-evidence-val-" + [guid]::NewGuid().ToString("n"))
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
    try {
        $realDir = Join-Path $tempRoot "real-evidence"
        New-Item -ItemType Directory -Force -Path $realDir | Out-Null
        $junctionParent = Join-Path $tempRoot "junction-evidence"
        cmd /c mklink /J "$junctionParent" "$realDir" 2>$null | Out-Null
        $victim = Join-Path $realDir "victim.txt"
        Set-Content -LiteralPath $victim -Value "unchanged" -Encoding UTF8 -NoNewline
        $before = Get-Sha256Hex ([System.Text.Encoding]::UTF8.GetBytes((Get-Content -LiteralPath $victim -Raw)))
        Assert-ThrowsBounded { Assert-NoReparseInPath -Path (Join-Path $junctionParent "row.json") -Label "evidence target" } "reject reparse ancestor"
        $after = Get-Sha256Hex ([System.Text.Encoding]::UTF8.GetBytes((Get-Content -LiteralPath $victim -Raw)))
        Assert-True ($before -eq $after) "reparse victim unchanged"
    } finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host ""
    if ($script:Fail -eq 0) {
        Write-Host "EVIDENCE_SIDECAR_VALIDATE_SELFTEST_PASS"
        exit 0
    }
    Write-Host "EVIDENCE_SIDECAR_VALIDATE_SELFTEST_FAIL: $script:Fail"
    exit 1
}

if ($LoadFunctionsOnly) { return }

if ($SelfTest) {
    Invoke-SelfTest
}

if (-not [string]::IsNullOrWhiteSpace($InputPath)) {
    if (-not (Test-Path -LiteralPath $InputPath)) { throw "input path missing" }
    $InputJson = [System.IO.File]::ReadAllText($InputPath, (New-Object System.Text.UTF8Encoding $false))
}

if ([string]::IsNullOrWhiteSpace($InputJson)) {
    if (-not $SelfTest) { throw "InputPath or InputJson required" }
    exit 0
}

[void](Invoke-ValidateInput -JsonText $InputJson -WriterMode:$WriterMode)
Write-Host "EVIDENCE_SIDECAR_VALIDATE_PASS"
exit 0

<#
.SYNOPSIS
  Validate recovery shadow inputs/records — schema walker, privacy, toolkit-only surface. Separate from R0a validate-recovery.ps1.
#>
param(
    [string]$InputPath = "",
    [string]$InputJson = "",
    [ValidateSet("commit_input", "commitment_record", "final_record")]
    [string]$SchemaKind = "commit_input",
    [switch]$SelfTest,
    [switch]$LoadFunctionsOnly
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$SchemaPath = Join-Path $Root "tests\recovery-shadow\shadow-schema.json"
$ForbiddenFields = @(
    "raw_prompt", "raw_log", "prompt_text", "log_text", "username", "hostname",
    "absolute_path", "private_path", "email", "secrets", "plugin_inventory"
)
$ModelFieldNames = @("model")
$script:SchemaDoc = $null
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

function Get-SchemaDocument {
    if ($null -ne $script:SchemaDoc) { return $script:SchemaDoc }
    $script:SchemaDoc = Read-Text $SchemaPath | ConvertFrom-Json
    return $script:SchemaDoc
}

function Resolve-SchemaNode {
    param($Node, $RootSchema)
    if ($null -eq $Node) { return $null }
    if ($Node.PSObject.Properties.Name -contains '$ref') {
        $ref = [string]$Node.'$ref'
        if ($ref -match '^#/definitions/(.+)$') {
            $name = $Matches[1]
            return $RootSchema.definitions.$name
        }
        throw ("schema: unsupported ref=" + $ref)
    }
    return $Node
}

function Get-TypeList($Node) {
    if ($null -eq $Node -or $null -eq $Node.PSObject.Properties['type']) { return @("object") }
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

function Test-SchemaEnum {
    param($Value, $Node, [string]$Path)
    if ($null -eq $Node -or $null -eq $Node.PSObject.Properties['enum']) { return }
    $ok = $false
    foreach ($ev in @($Node.enum)) {
        if ($Value -is [bool]) {
            if ($ev -is [bool] -and $Value -eq $ev) { $ok = $true; break }
            if ($ev -is [string] -and (($Value -and $ev -ceq "true") -or (-not $Value -and $ev -ceq "false"))) { $ok = $true; break }
        } elseif (Test-IsNumber $Value) {
            if ((Test-IsNumber $ev -or $ev -is [int] -or $ev -is [long]) -and ([double]$Value -eq [double]$ev)) { $ok = $true; break }
        } elseif ($Value -is [string] -and $Value -ceq [string]$ev) {
            $ok = $true; break
        }
    }
    if (-not $ok) { throw ("schema: enum rejected path=" + $Path) }
}

function Test-SchemaValue {
    param($Value, $Node, [string]$Path, $RootSchema)
    $Node = Resolve-SchemaNode -Node $Node -RootSchema $RootSchema
    if ($null -eq $Node) { throw ("schema: node missing path=" + $Path) }

    $types = Get-TypeList $Node
    if ($null -eq $Value) {
        if ($types -contains "null") { return }
        throw ("schema: null rejected path=" + $Path)
    }

    $matched = $false
    foreach ($t in $types) {
        switch ($t) {
            "boolean" { if ($Value -is [bool]) { $matched = $true; break } }
            "integer" { if (Test-IsIntegerNumber $Value) { $matched = $true; break } }
            "number" { if (Test-IsNumber $Value) { $matched = $true; break } }
            "string" { if ($Value -is [string]) { $matched = $true; break } }
            "object" { if ($Value -is [PSCustomObject]) { $matched = $true; break } }
            "array" { if ($Value -is [System.Array]) { $matched = $true; break } }
        }
    }
    if (-not $matched) { throw ("schema: type rejected path=" + $Path) }

    if ($types -contains "string" -and $Value -is [string]) {
        if ($null -ne $Node.PSObject.Properties['minLength'] -and $Value.Length -lt [int]$Node.minLength) {
            throw ("schema: minLength rejected path=" + $Path)
        }
        if ($null -ne $Node.PSObject.Properties['maxLength'] -and $Value.Length -gt [int]$Node.maxLength) {
            throw ("schema: maxLength rejected path=" + $Path)
        }
        if ($null -ne $Node.PSObject.Properties['enum']) {
            $ok = $false
            foreach ($ev in @($Node.enum)) { if ([string]$ev -ceq $Value) { $ok = $true; break } }
            if (-not $ok) { throw ("schema: enum rejected path=" + $Path) }
        }
        return
    }

    if ($types -contains "boolean" -and $Value -is [bool]) {
        Test-SchemaEnum -Value $Value -Node $Node -Path $Path
        return
    }

    if ($types -contains "integer" -and (Test-IsIntegerNumber $Value)) {
        $iv = [int64]$Value
        if ($null -ne $Node.PSObject.Properties['minimum'] -and $iv -lt [int64]$Node.minimum) {
            throw ("schema: minimum rejected path=" + $Path)
        }
        if ($null -ne $Node.PSObject.Properties['maximum'] -and $iv -gt [int64]$Node.maximum) {
            throw ("schema: maximum rejected path=" + $Path)
        }
        Test-SchemaEnum -Value $Value -Node $Node -Path $Path
        return
    }

    if ($types -contains "number" -and (Test-IsNumber $Value)) {
        $dv = [double]$Value
        if ($null -ne $Node.PSObject.Properties['minimum'] -and $dv -lt [double]$Node.minimum) {
            throw ("schema: minimum rejected path=" + $Path)
        }
        if ($null -ne $Node.PSObject.Properties['maximum'] -and $dv -gt [double]$Node.maximum) {
            throw ("schema: maximum rejected path=" + $Path)
        }
        Test-SchemaEnum -Value $Value -Node $Node -Path $Path
        return
    }

    if ($types -contains "array" -and ($Value -is [System.Array])) {
        if ($null -ne $Node.PSObject.Properties['minItems'] -and @($Value).Count -lt [int]$Node.minItems) {
            throw ("schema: minItems rejected path=" + $Path)
        }
        if ($null -ne $Node.PSObject.Properties['maxItems'] -and @($Value).Count -gt [int]$Node.maxItems) {
            throw ("schema: maxItems rejected path=" + $Path)
        }
        if ($null -ne $Node.PSObject.Properties['items']) {
            $idx = 0
            foreach ($item in @($Value)) {
                Test-SchemaValue -Value $item -Node $Node.items -Path ($Path + "[" + $idx + "]") -RootSchema $RootSchema
                $idx++
            }
        }
        return
    }

    if ($types -contains "object" -and ($Value -is [PSCustomObject])) {
        $propNames = @($Value.PSObject.Properties.Name)
        if ($null -ne $Node.PSObject.Properties['required']) {
            foreach ($req in @($Node.required)) {
                if ($propNames -notcontains [string]$req) {
                    throw ("schema: missing required path=" + $Path + " field=" + $req)
                }
            }
        }
        $allowed = @()
        if ($null -ne $Node.PSObject.Properties['properties']) {
            $allowed = @($Node.properties.PSObject.Properties.Name)
        }
        $additional = $true
        if ($null -ne $Node.PSObject.Properties['additionalProperties']) {
            $additional = [bool]$Node.additionalProperties
        }
        foreach ($name in $propNames) {
            if ($allowed -notcontains $name) {
                if (-not $additional) {
                    throw ("schema: unknown property path=" + $Path + " field=" + $name)
                }
            } else {
                $child = $Node.properties.$name
                Test-SchemaValue -Value $Value.$name -Node $child -Path ($Path + "." + $name) -RootSchema $RootSchema
            }
        }
    }
}

function Test-SchemaKind {
    param([object]$Obj, [string]$Kind)
    $schema = Get-SchemaDocument
    $node = $schema.definitions.$Kind
    if ($null -eq $node) { throw ("schema: unknown kind=" + $Kind) }
    Test-SchemaValue -Value $Obj -Node $node -Path "$" -RootSchema $schema
}

function Test-StringLooksLikePath([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    if ($Value -match '(?i)^[A-Za-z]:[/\\]') { return $true }
    if ($Value -match '(?i)^\\\\[^\\]+\\') { return $true }
    if ($Value -match '(?i)^/(Users|home)(/|$)') { return $true }
    if ($Value -match '(?i)/Users/') { return $true }
    if ($Value -match '(?i)/home/') { return $true }
    if ($Value -match '(?i)\\Users\\') { return $true }
    if ($Value -match '(?i)\\home\\') { return $true }
    return $false
}

function Test-StringSecretPattern([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    if ($Value -match '(?i)\bBearer\s+[A-Za-z0-9._\-+/=]{8,}') { return $true }
    if ($Value -match '(?i)\bsk-[A-Za-z0-9]{8,}') { return $true }
    if ($Value -match '(?i)\bghp_[A-Za-z0-9]{20,}') { return $true }
    if ($Value -match '(?i)\bgithub_pat_[A-Za-z0-9_]{20,}') { return $true }
    if ($Value -match '(?i)(^|[^a-z0-9_])(token|api_key|password|secret)\s*=\s*\S+') { return $true }
    if ($Value -match '(?i)://[^/]*@') { return $true }
    return $false
}

function Test-FieldNamePrivacy([string]$Name, [string]$Path) {
    $lower = $Name.ToLowerInvariant()
    foreach ($field in $ForbiddenFields) {
        if ($lower -ceq $field) { throw ("privacy: forbidden field path=" + $Path + " field=" + $Name) }
    }
    foreach ($secret in @("token", "api_key", "password", "secret", "authorization")) {
        if ($lower -ceq $secret) { throw ("privacy: secret field path=" + $Path + " field=" + $Name) }
    }
}

function Test-StringPrivacy([string]$Value, [string]$FieldName, [string]$Path) {
    if ($null -eq $Value) { return }
    if (Test-StringSecretPattern -Value $Value) { throw ("privacy: secret pattern path=" + $Path) }
    if ($ModelFieldNames -contains $FieldName) { return }
    if (Test-StringLooksLikePath -Value $Value) { throw ("privacy: absolute path path=" + $Path) }
}

function Test-PrivacyNode {
    param($Node, [string]$Path, [string]$FieldName = "")
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

function Invoke-ValidateShadowJson {
    param([string]$JsonText, [string]$Kind)
    Test-PrivacyNode -Node ($JsonText | ConvertFrom-Json) -Path "$"
    $obj = $JsonText | ConvertFrom-Json
    Test-SchemaKind -Obj $obj -Kind $Kind
    return $obj
}

function Test-ToolkitOnlySurface {
    if (Test-Path -LiteralPath (Join-Path $Root "tests\recovery\shadow")) {
        throw "toolkit: legacy tests/recovery/shadow must not exist"
    }
    $smokePath = Join-Path $Root "scripts\smoke-bootstrap.ps1"
    if (-not (Test-Path -LiteralPath $smokePath)) { return }
    $smokeText = Read-Text $smokePath
    if ($smokeText -match '"scripts\\recovery-shadow\.ps1"') {
        throw "toolkit: recovery-shadow must not appear in bootstrap copy lists"
    }
    if ($smokeText -match '"tests\\recovery-shadow"') {
        throw "toolkit: tests/recovery-shadow must not appear in bootstrap copy lists"
    }
    $fullBlock = ($smokeText -split "fullMustExist = @\(")[1]
    if ($null -ne $fullBlock -and $fullBlock -match 'recovery-shadow') {
        throw "toolkit: recovery-shadow must not be in Full mustExist"
    }
}

function New-SampleCommitInput {
    return [ordered]@{
        candidate_id = "shadow-sample-001"
        consumer_repo = "TG_BOT_PRO"
        tier = "T2"
        oracle = @{ available = $true; reliable = $true; check_id = "Q-PARSE" }
        risk_tags = @()
        first_verdict = @{ family = "openai"; decision = "retry" }
        second_call_decision = "retry"
    }
}

function Invoke-SelfTest {
    $script:Fail = 0
    function Assert-ThrowsMsg($scriptBlock, [string]$token, [string]$msg) {
        $threw = $false
        $err = ""
        try { & $scriptBlock } catch { $threw = $true; $err = $_.Exception.Message }
        if (-not $threw) { Fail ($msg + " (no throw)"); return }
        if ($err -notlike ("*" + $token + "*")) { Fail ($msg + " token=" + $token + " got=" + $err); return }
        Pass $msg
    }

    Write-Host "=== validate-recovery-shadow SelfTest ==="
    Assert-True (Test-Path -LiteralPath $SchemaPath) "schema exists"
    Test-ToolkitOnlySurface
    Pass "toolkit-only surface checks"

    $good = (New-SampleCommitInput | ConvertTo-Json -Depth 8 -Compress)
    Invoke-ValidateShadowJson -JsonText $good -Kind "commit_input" | Out-Null
    Pass "commit_input validates"

    $omitReliable = New-SampleCommitInput
    $omitReliable.oracle = @{ available = $true; check_id = "Q-PARSE" }
    Assert-ThrowsMsg { Invoke-ValidateShadowJson -JsonText ($omitReliable | ConvertTo-Json -Depth 8 -Compress) -Kind "commit_input" } "schema: missing required" "reject oracle reliable omitted"

    $extra = $good -replace '"candidate_id"', '"second_verdict":{"family":"x","decision":"retry"},"candidate_id"'
    Assert-ThrowsMsg { Invoke-ValidateShadowJson -JsonText $extra -Kind "commit_input" } "schema: unknown property" "reject second_verdict in commit input"

    $nestedPath = $good -replace '"risk_tags":\[\]', '"risk_tags":["/home/leak"]'
    Assert-ThrowsMsg { Invoke-ValidateShadowJson -JsonText $nestedPath -Kind "commit_input" } "privacy: absolute path" "reject nested path in risk_tags"

    $forbidden = $good -replace '"candidate_id"', '"username":"x","candidate_id"'
    Assert-ThrowsMsg { Invoke-ValidateShadowJson -JsonText $forbidden -Kind "commit_input" } "privacy: forbidden field" "reject forbidden field"

    $commitGood = @'
{"schema_version":1,"shadow_version":"v1","record_type":"commitment","candidate_id":"x","consumer_repo":"y","tier":"T2","oracle":{"available":true,"reliable":true,"check_id":"Q"},"excluded":false,"exclusion_reasons":[],"first_verdict":{"family":"openai","decision":"retry","recorded_at_seq":1,"verdict_hash":"sha256:abc12345"},"commitment":{"second_call_decision":"retry","commitment_hash":"sha256:def67890","sequence_proof":"seqproof:abc12345","recorded_at_seq":2,"before_second_reveal":true},"promotion_status":"evidence_pending","live_model_calls":false,"pin_or_cost_change":false}
'@.Trim()
    Invoke-ValidateShadowJson -JsonText $commitGood -Kind "commitment_record" | Out-Null
    Pass "commitment_record boolean enum true accepts"

    $badBeforeReveal = $commitGood -replace '"before_second_reveal":true', '"before_second_reveal":false'
    Assert-ThrowsMsg { Invoke-ValidateShadowJson -JsonText $badBeforeReveal -Kind "commitment_record" } "schema: enum rejected" "reject before_second_reveal false"

    $badLiveCalls = $commitGood -replace '"live_model_calls":false', '"live_model_calls":true'
    Assert-ThrowsMsg { Invoke-ValidateShadowJson -JsonText $badLiveCalls -Kind "commitment_record" } "schema: enum rejected" "reject live_model_calls true"

    $badSchemaVer = $commitGood -replace '"schema_version":1', '"schema_version":2'
    Assert-ThrowsMsg { Invoke-ValidateShadowJson -JsonText $badSchemaVer -Kind "commitment_record" } "schema: maximum rejected" "reject schema_version integer out of range"

    Write-Host ""
    if ($script:Fail -eq 0) {
        Write-Host "RECOVERY_SHADOW_VALIDATE_SELFTEST_PASS"
        exit 0
    }
    Write-Host "RECOVERY_SHADOW_VALIDATE_SELFTEST_FAIL: $script:Fail"
    exit 1
}

if ($LoadFunctionsOnly) { return }

if ($SelfTest) { Invoke-SelfTest }

if (-not [string]::IsNullOrWhiteSpace($InputPath)) {
    if (-not (Test-Path -LiteralPath $InputPath)) { throw "input path missing" }
    $InputJson = Read-Text $InputPath
}
if ([string]::IsNullOrWhiteSpace($InputJson)) {
    if (-not $SelfTest) { throw "InputPath or InputJson required" }
    exit 0
}

[void](Invoke-ValidateShadowJson -JsonText $InputJson -Kind $SchemaKind)
Write-Host "RECOVERY_SHADOW_VALIDATE_PASS"
exit 0

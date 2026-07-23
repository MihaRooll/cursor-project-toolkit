<#
.SYNOPSIS
  Greenfield: create product folder + git + Essential harness + product-brief + first-chat.

.EXAMPLE
  .\scripts\new-project.ps1 -Name wifi-vpn -Goal "2 clicks WiFi + VPN"
  .\scripts\new-project.cmd -Name wifi-vpn -Goal "2 clicks WiFi + VPN"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [string]$Goal = "",

    [string]$Parent = "",

    [switch]$AllowExisting,

    # Skip User-scope HOME mutation during bootstrap (portability smoke / isolated runs).
    [switch]$SkipUserHome
)

$ErrorActionPreference = "Stop"
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

# --- Win32 final path (PS 5.1); fail-closed for under-toolkit checks ---
$nativeType = @"
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

public static class CptkNativePath {
    const uint GENERIC_READ = 0x80000000;
    const uint FILE_SHARE_READ = 0x00000001;
    const uint FILE_SHARE_WRITE = 0x00000002;
    const uint FILE_SHARE_DELETE = 0x00000004;
    const uint OPEN_EXISTING = 3;
    const uint FILE_FLAG_BACKUP_SEMANTICS = 0x02000000;
    const uint VOLUME_NAME_DOS = 0;
    static readonly IntPtr INVALID_HANDLE_VALUE = new IntPtr(-1);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr CreateFileW(
        string lpFileName,
        uint dwDesiredAccess,
        uint dwShareMode,
        IntPtr lpSecurityAttributes,
        uint dwCreationDisposition,
        uint dwFlagsAndAttributes,
        IntPtr hTemplateFile);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern int GetFinalPathNameByHandleW(
        IntPtr hFile,
        StringBuilder lpszFilePath,
        int cchFilePath,
        uint dwFlags);

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    static extern bool CloseHandle(IntPtr hObject);

    public static string GetFinalPath(string path) {
        IntPtr h = CreateFileW(
            path,
            GENERIC_READ,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
            IntPtr.Zero,
            OPEN_EXISTING,
            FILE_FLAG_BACKUP_SEMANTICS,
            IntPtr.Zero);
        if (h == INVALID_HANDLE_VALUE) {
            throw new Win32Exception(Marshal.GetLastWin32Error(),
                "CreateFileW failed for: " + path);
        }
        try {
            int capacity = 512;
            for (int attempt = 0; attempt < 4; attempt++) {
                StringBuilder sb = new StringBuilder(capacity);
                int needed = GetFinalPathNameByHandleW(h, sb, sb.Capacity, VOLUME_NAME_DOS);
                if (needed == 0) {
                    throw new Win32Exception(Marshal.GetLastWin32Error(),
                        "GetFinalPathNameByHandleW failed for: " + path);
                }
                if (needed < sb.Capacity) {
                    string result = sb.ToString();
                    if (string.IsNullOrEmpty(result)) {
                        throw new Exception("GetFinalPathNameByHandleW returned empty path for: " + path);
                    }
                    return result;
                }
                capacity = needed + 2;
            }
            throw new Exception("GetFinalPathNameByHandleW buffer grow failed for: " + path);
        }
        finally {
            CloseHandle(h);
        }
    }
}
"@

try {
    Add-Type -TypeDefinition $nativeType -ErrorAction Stop | Out-Null
} catch {
    $msg = $_.Exception.Message
    if ($msg -notmatch 'already exists') {
        throw
    }
}

function Strip-ExtendedPrefix([string]$Path) {
    if ([string]::IsNullOrEmpty($Path)) { return $Path }
    if ($Path.StartsWith('\\?\UNC\', [System.StringComparison]::OrdinalIgnoreCase)) {
        return '\' + $Path.Substring(7)
    }
    if ($Path.Length -ge 7 -and
        $Path.StartsWith('\\?\', [System.StringComparison]::Ordinal) -and
        $Path[5] -eq ':' -and
        ($Path[6] -eq '\' -or $Path[6] -eq '/')) {
        # \\?\X:\...
        return $Path.Substring(4)
    }
    # Keep \\?\Volume{...} and any other extended forms as-is
    return $Path
}

function Get-FinalPath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "Get-FinalPath: path is empty."
    }
    $raw = [CptkNativePath]::GetFinalPath($Path)
    return (Strip-ExtendedPrefix $raw)
}

function Resolve-NewProjectParentFinal([string]$AbsoluteParent) {
    if ([string]::IsNullOrWhiteSpace($AbsoluteParent)) {
        throw "Parent path is empty."
    }
    $full = [System.IO.Path]::GetFullPath($AbsoluteParent)
    $cursor = $full.TrimEnd('\', '/')
    $suffix = New-Object System.Collections.Generic.List[string]

    while (-not [string]::IsNullOrEmpty($cursor)) {
        if (Test-Path -LiteralPath $cursor) {
            break
        }
        $leaf = Split-Path -Leaf $cursor
        if ([string]::IsNullOrEmpty($leaf)) {
            throw "No existing ancestor for Parent: $AbsoluteParent"
        }
        $suffix.Insert(0, $leaf)
        $next = Split-Path -Parent $cursor
        if ([string]::IsNullOrEmpty($next) -or $next -eq $cursor) {
            throw "No existing ancestor for Parent: $AbsoluteParent"
        }
        $cursor = $next
    }

    if (-not (Test-Path -LiteralPath $cursor)) {
        throw "No existing ancestor for Parent: $AbsoluteParent"
    }

    $item = Get-Item -LiteralPath $cursor -Force
    if (-not $item.PSIsContainer) {
        throw "Deepest existing ancestor is not a directory: $cursor"
    }

    $anc = Get-FinalPath $cursor
    $joined = $anc
    foreach ($seg in $suffix) {
        $joined = Join-Path $joined $seg
    }
    $joined = [System.IO.Path]::GetFullPath($joined)
    if (-not [System.IO.Path]::IsPathRooted($joined)) {
        throw "Resolved Parent is not rooted: $joined"
    }
    return (Strip-ExtendedPrefix $joined)
}

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, $Utf8NoBom)
}

function Normalize-Newlines([string]$Text) {
    $t = $Text -replace "`r`n", "`n" -replace "`r", "`n"
    if ($t.Length -gt 0 -and [int][char]$t[0] -eq 0xFEFF) {
        $t = $t.Substring(1)
    }
    return $t.TrimEnd()
}

function Test-AsciiProjectId([string]$Id) {
    return $Id -match '^[a-zA-Z0-9][a-zA-Z0-9._-]*$'
}

function Test-ReservedDeviceName([string]$Id) {
    $base = ($Id -split '\.')[0]
    $reserved = @(
        'CON', 'PRN', 'AUX', 'NUL',
        'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
        'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9'
    )
    return $reserved -contains $base.ToUpperInvariant()
}

function Test-TargetOccupied([string]$TargetDir) {
    if (-not (Test-Path -LiteralPath $TargetDir)) { return $false }
    $children = @(Get-ChildItem -LiteralPath $TargetDir -Force -ErrorAction SilentlyContinue)
    return $children.Count -gt 0
}

function Test-ShouldSeedDocsMap([string]$MapPath) {
    if (-not (Test-Path -LiteralPath $MapPath)) { return $true }
    $raw = [System.IO.File]::ReadAllText($MapPath)
    if ([string]::IsNullOrWhiteSpace($raw.Trim())) { return $true }
    try {
        $null = $raw | ConvertFrom-Json
    } catch {
        Write-Warning "skip docs-map (exists but unparseable JSON): $($_.Exception.Message)"
        return $false
    }
    return $false
}

function Test-ShouldSeedProjectState([string]$StatePath) {
    if (-not (Test-Path -LiteralPath $StatePath)) { return $true }
    $raw = [System.IO.File]::ReadAllText($StatePath)
    return [string]::IsNullOrWhiteSpace($raw.Trim())
}

function Update-DocsMapEntryStatus([string]$MapPath, [string[]]$Paths, [string]$Status) {
    if (-not (Test-Path -LiteralPath $MapPath)) { return }
    try {
        $raw = [System.IO.File]::ReadAllText($MapPath)
        $obj = $raw | ConvertFrom-Json
    } catch {
        Write-Warning "skip docs-map promote (unparseable): $($_.Exception.Message)"
        return
    }
    $changed = $false
    foreach ($entry in @($obj.entries)) {
        $ep = [string]$entry.path
        foreach ($want in $Paths) {
            if ($ep -eq $want -and [string]$entry.status -ne $Status) {
                $entry.status = $Status
                $changed = $true
            }
        }
    }
    if ($changed) {
        $json = $obj | ConvertTo-Json -Depth 10
        Write-Utf8NoBom $MapPath $json
        Write-Host "promoted docs-map entries to $Status`: $($Paths -join ', ')"
    }
}

function Test-PathUnderOrEqual([string]$Child, [string]$Root) {
    $c = $Child.TrimEnd('\', '/')
    $r = $Root.TrimEnd('\', '/')
    if ($c.Equals($r, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    $prefix = $r + [System.IO.Path]::DirectorySeparatorChar
    return $c.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
}

# --- 1-2: finalize ToolkitRoot before default Parent ---
$ToolkitLogical = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
if (-not (Test-Path -LiteralPath $ToolkitLogical)) {
    throw "Toolkit root does not exist: $ToolkitLogical"
}
$ToolkitRoot = Get-FinalPath $ToolkitLogical

$StockAgents = Join-Path $ToolkitRoot "templates\project-AGENTS.md"
$BriefTemplate = Join-Path $ToolkitRoot "templates\product-brief.md"
$FirstChatTemplate = Join-Path $ToolkitRoot "templates\first-chat.md"
$DocsMapTemplate = Join-Path $ToolkitRoot "templates\docs-map.json"
$ProjectStateTemplate = Join-Path $ToolkitRoot "templates\project-state.md"
$BootstrapScript = Join-Path $ToolkitRoot "scripts\bootstrap-into-project.ps1"

# --- 3: validate Name ---
$Name = $Name.Trim()
if ([string]::IsNullOrWhiteSpace($Name)) {
    throw "Name is empty after trim."
}
if ($Name.Contains('\') -or $Name.Contains('/') -or $Name -eq '.' -or $Name -eq '..') {
    throw "Name must not contain path separators or be . / .."
}
if ($Name -match '[<>:"|?*]' -or $Name -match '[\x00-\x1F]') {
    throw "Name contains invalid Windows characters."
}
if ($Name.EndsWith('.') -or $Name.EndsWith(' ')) {
    throw "Name must not end with '.' or space."
}
if (-not (Test-AsciiProjectId $Name)) {
    throw "Name must match ASCII project id: letter/digit then [a-zA-Z0-9._-]*"
}
if (Test-ReservedDeviceName $Name) {
    throw "Name is a reserved Windows device name: $Name"
}
if ($Name.Length -gt 64) {
    throw "Name length must be <= 64."
}

# --- Goal ---
$Goal = if ([string]::IsNullOrWhiteSpace($Goal)) { "(fill in)" } else { $Goal.Trim() }

# --- 4-6: resolve and finalize Parent (no New-Item yet) ---
if ([string]::IsNullOrWhiteSpace($Parent)) {
    $envParent = [Environment]::GetEnvironmentVariable("TOOLKIT_PROJECTS_ROOT", "Process")
    if ([string]::IsNullOrWhiteSpace($envParent)) {
        $envParent = [Environment]::GetEnvironmentVariable("TOOLKIT_PROJECTS_ROOT", "User")
    }
    if (-not [string]::IsNullOrWhiteSpace($envParent)) {
        $Parent = $envParent
    } else {
        $Parent = Split-Path $ToolkitRoot -Parent
    }
}
if (-not [System.IO.Path]::IsPathRooted($Parent)) {
    $Parent = Join-Path (Get-Location).Path $Parent
}
$Parent = [System.IO.Path]::GetFullPath($Parent)
$Parent = Resolve-NewProjectParentFinal $Parent

# --- 7-9: Target + under-toolkit check before create ---
$Target = Join-Path $Parent $Name
if (Test-Path -LiteralPath $Target) {
    $Target = Get-FinalPath $Target
} else {
    $Target = Strip-ExtendedPrefix ([System.IO.Path]::GetFullPath($Target))
}

if ($Target.Length -ge 260) {
    throw "Resolved path length >= 260 (MAX_PATH risk): $Target"
}

if (Test-PathUnderOrEqual $Target $ToolkitRoot) {
    Write-Host "ERROR: Target must not equal or be under toolkit root: $ToolkitRoot"
    exit 1
}

# --- 10: existence / git ---
if ((Test-Path -LiteralPath $Target) -and (Test-TargetOccupied $Target) -and (-not $AllowExisting)) {
    Write-Host @"
ERROR: Target exists and is non-empty:
  $Target
Refusing to mutate. Re-run with -AllowExisting to refresh Essential harness
(overwrites product-core.mdc + papercuts hook .ps1; merges hooks.json events;
appends AGENTS snippet if missing; skips existing day-0 brief/first-chat).
Or choose another -Name / -Parent.
"@
    exit 1
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: git not found on PATH. Install git before new-project."
    exit 1
}

Write-Host "=== new-project ==="
Write-Host "Toolkit: $ToolkitRoot"
Write-Host "Parent:  $Parent"
Write-Host "Name:    $Name"
Write-Host "Target:  $Target"
Write-Host "Goal:    $Goal"

try {
    # --- 11: create only after under-toolkit check ---
    New-Item -ItemType Directory -Force -Path $Parent | Out-Null
    New-Item -ItemType Directory -Force -Path $Target | Out-Null

    # --- 12: re-finalize Target before git/bootstrap ---
    $Target = Get-FinalPath $Target
    if (Test-PathUnderOrEqual $Target $ToolkitRoot) {
        throw "Target resolved under toolkit root after create (refusing further mutation): $Target"
    }

    $gitDir = Join-Path $Target ".git"
    if (-not (Test-Path -LiteralPath $gitDir)) {
        & git -C $Target init | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "git init failed (exit $LASTEXITCODE)"
        }
        Write-Host "git init OK"
    } else {
        Write-Host "skip git init (.git present)"
    }

    $bootstrapArgList = @("-TargetPath", $Target, "-Mode", "Essential", "-SkipNext")
    if ($SkipUserHome -or ($env:CPTK_PORTABILITY_SMOKE -eq "1")) {
        $bootstrapArgList += "-SkipUserHome"
    }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $BootstrapScript @bootstrapArgList
    if ($LASTEXITCODE -ne 0) {
        throw "bootstrap-into-project.ps1 failed (exit $LASTEXITCODE)"
    }

    # --- day-0 files ---
    $docsDir = Join-Path $Target "docs"
    New-Item -ItemType Directory -Force -Path $docsDir | Out-Null

    $briefPath = Join-Path $docsDir "product-brief.md"
    if (Test-Path -LiteralPath $briefPath) {
        Write-Host "skip product-brief (exists)"
    } else {
        if (-not (Test-Path -LiteralPath $BriefTemplate)) {
            throw "missing template: $BriefTemplate"
        }
        $brief = [System.IO.File]::ReadAllText($BriefTemplate)
        $brief = $brief.Replace("{{NAME}}", $Name).Replace("{{GOAL}}", $Goal)
        Write-Utf8NoBom $briefPath $brief
        Write-Host "wrote docs\product-brief.md"
    }

    $firstPath = Join-Path $docsDir "first-chat.md"
    if (Test-Path -LiteralPath $firstPath) {
        Write-Host "skip first-chat (exists)"
    } else {
        if (-not (Test-Path -LiteralPath $FirstChatTemplate)) {
            throw "missing template: $FirstChatTemplate"
        }
        $first = [System.IO.File]::ReadAllText($FirstChatTemplate)
        $first = $first.Replace("{{NAME}}", $Name).Replace("{{GOAL}}", $Goal)
        Write-Utf8NoBom $firstPath $first
        Write-Host "wrote docs\first-chat.md"
    }

    $mapPath = Join-Path $docsDir "docs-map.json"
    if (Test-ShouldSeedDocsMap $mapPath) {
        if (-not (Test-Path -LiteralPath $DocsMapTemplate)) {
            throw "missing template: $DocsMapTemplate"
        }
        $mapSeed = [System.IO.File]::ReadAllText($DocsMapTemplate)
        Write-Utf8NoBom $mapPath $mapSeed
        Write-Host "wrote docs\docs-map.json"
    } else {
        Write-Host "skip docs-map (exists)"
    }

    $statePath = Join-Path $docsDir "project-state.md"
    if (Test-ShouldSeedProjectState $statePath) {
        if (-not (Test-Path -LiteralPath $ProjectStateTemplate)) {
            throw "missing template: $ProjectStateTemplate"
        }
        $stateSeed = [System.IO.File]::ReadAllText($ProjectStateTemplate)
        Write-Utf8NoBom $statePath $stateSeed
        Write-Host "wrote docs\project-state.md"
    } else {
        Write-Host "skip project-state (exists)"
    }

    $envDocPath = Join-Path $docsDir "project-environment.md"
    if ((Test-Path -LiteralPath $mapPath) -and (Test-Path -LiteralPath $statePath)) {
        $promotePaths = @("docs/project-state.md")
        if (Test-Path -LiteralPath $envDocPath) {
            $promotePaths += "docs/project-environment.md"
        }
        Update-DocsMapEntryStatus -MapPath $mapPath -Paths $promotePaths -Status "active"
    }

    # --- AGENTS strategy A: title patch only if stock ---
    $agentsPath = Join-Path $Target "AGENTS.md"
    if ((Test-Path -LiteralPath $agentsPath) -and (Test-Path -LiteralPath $StockAgents)) {
        $agentsText = Normalize-Newlines ([System.IO.File]::ReadAllText($agentsPath))
        $stockText = Normalize-Newlines ([System.IO.File]::ReadAllText($StockAgents))
        if ($agentsText -eq $stockText) {
            $lines = $agentsText -split "`n", -1
            if ($lines.Count -gt 0 -and $lines[0] -eq "# Project agent instructions") {
                $lines[0] = "# $Name - agent instructions"
                $out = ($lines -join "`n")
                if (-not $out.EndsWith("`n")) { $out += "`n" }
                Write-Utf8NoBom $agentsPath $out
                Write-Host "AGENTS.md title set from stock template"
            } else {
                Write-Host "stock hash matched but H1 unexpected; skip title patch"
            }
        } else {
            Write-Host "AGENTS.md not stock (custom or snippet-appended); skip title patch"
        }
    }

    Write-Host ""
    Write-Host "=== new-project OK ==="
    Write-Host "Name:   $Name"
    Write-Host "Parent: $Parent"
    Write-Host "Path:   $Target"
    Write-Host ""
    Write-Host "NEXT (in order):"
    Write-Host "  1. Open folder in Cursor:  File > Open Folder -> Path above"
    Write-Host "  2. In THAT workspace: start a new Agent chat"
    Write-Host "  3. Open docs\first-chat.md and paste the fenced prompt into the chat"
    Write-Host "  4. One plugin:  /add-plugin cursor-team-kit"
    Write-Host ""
    Write-Host "Do not keep building the product inside the toolkit workspace."
    exit 0
} catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)"
    Write-Host "Incomplete target (no auto-delete): $Target"
    Write-Host "Fix manually or re-run with -AllowExisting after cleanup."
    exit 1
}

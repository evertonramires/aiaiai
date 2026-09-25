# aiaiai installer for Windows.
#
#   irm https://raw.githubusercontent.com/evertonramires/aiaiai/main/install.ps1 | iex
#
# or, from a clone:   .\install.ps1
#
# Finds or installs Python 3.11+, puts aiaiai (and the short alias ai) on your
# PATH, and walks you through pointing it at an AI: any OpenAI-compatible API,
# or the Claude Code CLI if you already use it.
#
#   $env:AIAIAI_DIR = "C:\somewhere"   install somewhere else
#   $env:AIAIAI_NO_SETUP = "1"         skip the interactive configuration
#   $env:AIAIAI_NO_SHORT_ALIAS = "1"   skip the "ai" alias
#
# Copyright (C) 2026 aiaiai contributors. AGPL-3.0-or-later.

$ErrorActionPreference = 'Stop'

$RepoRaw = if ($env:AIAIAI_REPO_RAW) { $env:AIAIAI_REPO_RAW }
           else { 'https://raw.githubusercontent.com/evertonramires/aiaiai/main' }
$InstallDir = if ($env:AIAIAI_DIR) { $env:AIAIAI_DIR }
              else { Join-Path $env:LOCALAPPDATA 'Programs\aiaiai' }

function Say  { param([string]$Text) Write-Host $Text }
function Step { param([string]$Text) Write-Host "==> " -ForegroundColor Cyan -NoNewline; Write-Host $Text }
function Warn { param([string]$Text) Write-Host "! $Text" -ForegroundColor Yellow }
function Fail { param([string]$Text) Write-Host "error: $Text" -ForegroundColor Red; exit 1 }

if ($PSVersionTable.PSVersion.Major -lt 5) {
    Fail "aiaiai needs Windows PowerShell 5.1 or newer."
}

function Test-Python {
    param([string]$Exe, [string[]]$Prefix = @())
    try {
        $args = $Prefix + @('-c', 'import sys; raise SystemExit(0 if sys.version_info >= (3,11) else 1)')
        & $Exe @args 2>$null
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

function Find-Python {
    foreach ($candidate in @(
        @{ Exe = 'py';      Prefix = @('-3') },
        @{ Exe = 'python';  Prefix = @() },
        @{ Exe = 'python3'; Prefix = @() }
    )) {
        $found = Get-Command $candidate.Exe -ErrorAction SilentlyContinue
        if (-not $found) { continue }
        if (Test-Python -Exe $candidate.Exe -Prefix $candidate.Prefix) {
            # Resolve to the real interpreter so the shims never depend on PATH.
            $real = & $candidate.Exe @($candidate.Prefix + @('-c', 'import sys; print(sys.executable)')) 2>$null
            if ($real) { return $real.Trim() }
        }
    }
    return $null
}

function Update-SessionPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}

# --- 1. python ---------------------------------------------------------------
Step "looking for Python 3.11 or newer"
$python = Find-Python

if (-not $python) {
    Warn "no Python 3.11+ on this machine - aiaiai needs one"
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Fail "install Python from https://www.python.org/downloads/ (tick 'Add python.exe to PATH'), then run this again."
    }
    $answer = Read-Host "install Python now with winget? [Y/n]"
    if ($answer -and $answer -notmatch '^[yY]') {
        Fail "aiaiai needs Python 3.11+. Get it from https://www.python.org/downloads/"
    }
    Step "installing Python (this takes a minute)"
    winget install --id Python.Python.3.12 --exact --source winget `
        --accept-package-agreements --accept-source-agreements --disable-interactivity
    Update-SessionPath
    $python = Find-Python
    if (-not $python) {
        Fail "Python was installed but is not visible yet. Close this window, open a new one, and run this again."
    }
}
Say "  found $python ($(& $python -V 2>&1))"

# --- 2. the script itself ----------------------------------------------------
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$target = Join-Path $InstallDir 'aiaiai.py'

$localCopy = $null
if ($PSScriptRoot) {
    $candidate = Join-Path $PSScriptRoot 'aiaiai'
    if (Test-Path $candidate) { $localCopy = $candidate }
}

if ($localCopy) {
    Step "installing from $PSScriptRoot"
    Copy-Item -Path $localCopy -Destination $target -Force
} else {
    Step "downloading aiaiai"
    try {
        Invoke-WebRequest -Uri "$RepoRaw/aiaiai" -OutFile $target -UseBasicParsing
    } catch {
        Fail "download failed: $($_.Exception.Message)"
    }
    if (-not (Select-String -Path $target -Pattern 'python' -Quiet)) {
        Remove-Item $target -Force
        Fail "that download does not look like aiaiai"
    }
}
Say "  installed $target"

# Shims, so "aiaiai" works from PowerShell and cmd alike. ASCII, no BOM: cmd.exe
# refuses to run a batch file that starts with one.
function Write-Shim {
    param([string]$Path, [string]$PythonExe, [string]$ScriptPath)
    $body = "@echo off`r`n""$PythonExe"" ""$ScriptPath"" %*`r`n"
    [IO.File]::WriteAllText($Path, $body, [Text.Encoding]::ASCII)
}

Write-Shim -Path (Join-Path $InstallDir 'aiaiai.cmd') -PythonExe $python -ScriptPath $target
Say "  installed $(Join-Path $InstallDir 'aiaiai.cmd')"

if ($env:AIAIAI_NO_SHORT_ALIAS -eq '1') {
    Say "  skipping the short 'ai' alias"
} else {
    $existing = Get-Command ai -ErrorAction SilentlyContinue
    if ($existing -and $existing.Source -and
        ($existing.Source -notlike "$InstallDir*")) {
        Warn "'ai' is already $($existing.Source) - leaving it alone"
    } else {
        Write-Shim -Path (Join-Path $InstallDir 'ai.cmd') -PythonExe $python -ScriptPath $target
        Say "  installed $(Join-Path $InstallDir 'ai.cmd') (same program, shorter name)"
    }
}

# --- 3. PATH -----------------------------------------------------------------
$needsNewShell = $false
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if (-not $userPath) { $userPath = '' }
if (($userPath -split ';') -notcontains $InstallDir) {
    Step "adding $InstallDir to your PATH"
    $joined = if ($userPath.TrimEnd(';')) { $userPath.TrimEnd(';') + ';' + $InstallDir } else { $InstallDir }
    [Environment]::SetEnvironmentVariable('Path', $joined, 'User')
    $env:Path = "$env:Path;$InstallDir"
    $needsNewShell = $true
}

# --- 4. configuration --------------------------------------------------------
Say ""
if ($env:AIAIAI_NO_SETUP -eq '1') {
    Say "skipping configuration. Run 'aiaiai --setup' when you are ready."
} else {
    & $python $target --setup
}

# --- 5. the one thing left to do --------------------------------------------
Say ""
if ($needsNewShell) {
    Write-Host "One last step." -ForegroundColor White -NoNewline
    Say " Copy, paste, and you are done:"
    Say ""
    Write-Host "    `$env:Path = `"`$env:Path;$InstallDir`"" -ForegroundColor Green
    Say ""
    Say "(or just open a new PowerShell window - this is only needed once)"
} else {
    Write-Host "Ready." -ForegroundColor Green -NoNewline
    Say " Try it:"
    Say ""
    Write-Host "    ai how do I find the biggest files in this folder" -ForegroundColor White
}

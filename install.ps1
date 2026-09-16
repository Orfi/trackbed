#!/usr/bin/env pwsh
#
# Trackbed installer (PowerShell) — the cross-platform twin of install.sh.
# Runs on Windows PowerShell 5+, and pwsh on Windows / macOS / Linux.
#
# Trackbed itself is skills-only (no scripts at runtime). This script is
# install-time plumbing only: it copies (or symlinks) the skills (and, for
# Claude Code / OpenCode, the command) into the right directories for
# Claude Code, OpenCode, GitHub Copilot CLI, and/or OpenAI Codex CLI.
#
# Usage:
#   ./install.ps1                 interactive: asks which runtime(s) to install for
#   ./install.ps1 -Link           symlink instead of copy (dev: repo edits go live)
#   ./install.ps1 -Uninstall      remove an existing Trackbed install
#   ./install.ps1 -Help           show this help
#
# Claude Code + OpenCode share one skill source (claude/skills) and the
# OpenCode conflict rule below. Copilot uses its OWN source (copilot/skills,
# adapted executor text) and its own home (~/.copilot/skills) — independent,
# no command file (in Copilot a skill IS its slash command). Codex does the
# same: its own source (codex/skills, adapted executor text) into
# $env:CODEX_HOME/skills (default ~/.codex/skills) — independent, no command
# file (in Codex a skill is selected via /skills or mentioned with $).
#
# Conflict rule (OpenCode reads BOTH ~/.claude/skills and ~/.config/opencode/skills):
# those skills get exactly ONE home per machine so the two never drift —
#   * Claude Code only        -> ~/.claude/skills/
#   * OpenCode only           -> ~/.config/opencode/skills/
#   * both runtimes installed -> ~/.claude/skills/ only (OpenCode reads it natively)

[CmdletBinding()]
param(
    [switch]$Link,
    [switch]$Uninstall,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

# --- paths -------------------------------------------------------------------

$RepoDir        = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillsSrc      = Join-Path $RepoDir 'claude/skills'        # Claude Code + OpenCode share this source
$CopilotSkillsSrc = Join-Path $RepoDir 'copilot/skills'     # Copilot has its own adapted copy
$CodexSkillsSrc = Join-Path $RepoDir 'codex/skills'         # Codex has its own adapted copy
$CcCmdSrc       = Join-Path $RepoDir 'claude/commands/trackbed.md'
$OcCmdSrc       = Join-Path $RepoDir 'opencode/commands/trackbed.md'

$Home_ = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }
$XdgConfig = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $Home_ '.config' }

$ClaudeSkills  = Join-Path $Home_ '.claude/skills'
$ClaudeCmds    = Join-Path $Home_ '.claude/commands'
$OpencodeSkills = Join-Path $XdgConfig 'opencode/skills'
$OpencodeCmds  = Join-Path $XdgConfig 'opencode/commands'
$CopilotSkills = Join-Path $Home_ '.copilot/skills'         # Copilot's own home — no command file
$CodexHome     = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $Home_ '.codex' }
$CodexSkills   = Join-Path $CodexHome 'skills'               # Codex's own home — no command file

$Skills = @('trackbed','trackbed-init','trackbed-orchestrate','trackbed-plan','trackbed-sync','trackbed-adr','trackbed-dod','trackbed-view')

# --- helpers -----------------------------------------------------------------

function Say($msg) { Write-Host $msg }
function Die($msg) { Write-Error "error: $msg"; exit 1 }

function Show-Usage {
    Get-Content $MyInvocation.PSCommandPath | Select-Object -Skip 2 -First 19 |
        ForEach-Object { $_ -replace '^#$','' -replace '^# ','' }
    exit 0
}

# place one item (dir or file) from src -> dest, copy or symlink per -Link
function Place($src, $dest) {
    $parent = Split-Path -Parent $dest
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
    if ($Link) {
        New-Item -ItemType SymbolicLink -Path $dest -Target $src | Out-Null
        Say "  linked  $dest"
    } else {
        Copy-Item -Recurse -Force $src $dest
        Say "  copied  $dest"
    }
}

function Install-SkillsTo($targetDir, $srcDir = $SkillsSrc) {
    foreach ($s in $Skills) { Place (Join-Path $srcDir $s) (Join-Path $targetDir $s) }
}

function Remove-SkillsFrom($targetDir) {
    foreach ($s in $Skills) {
        $p = Join-Path $targetDir $s
        if (Test-Path $p) { Remove-Item -Recurse -Force $p; Say "  removed $p" }
    }
}

function Test-SkillsIn($dir) { Test-Path (Join-Path $dir 'trackbed/SKILL.md') }

# --- arg parsing -------------------------------------------------------------

if ($Help) { Show-Usage }
if (-not (Test-Path $SkillsSrc)) { Die "skills not found at $SkillsSrc - run this from the trackbed repo" }

# --- runtime selection -------------------------------------------------------

$WantCC = $false; $WantOC = $false; $WantCP = $false; $WantCX = $false

Say 'Trackbed installer'
Say 'Install for which runtime(s)?'
Say '  1) Claude Code'
Say '  2) OpenCode'
Say '  3) GitHub Copilot CLI'
Say '  4) OpenAI Codex CLI'
Say "Select one or more (e.g. '1', '3', or '1 2 3 4' / '1,2' for several)."
$choice = Read-Host 'Choice'

# Accept space- or comma-separated selections (1, 2, 3, 4, "1 2", "1,3", ...).
foreach ($n in ($choice -split '[,\s]+' | Where-Object { $_ -ne '' })) {
    switch ($n) {
        '1' { $WantCC = $true }
        '2' { $WantOC = $true }
        '3' { $WantCP = $true }
        '4' { $WantCX = $true }
        default { Die "invalid choice: '$n' (pick 1, 2, 3 and/or 4)" }
    }
}

if (-not ($WantCC -or $WantOC -or $WantCP -or $WantCX)) { Die 'no runtime selected' }

# --- uninstall ---------------------------------------------------------------

if ($Uninstall) {
    Say ''
    Say 'Uninstalling Trackbed...'
    if ($WantCC) {
        Remove-SkillsFrom $ClaudeSkills
        $c = Join-Path $ClaudeCmds 'trackbed.md'
        if (Test-Path $c) { Remove-Item -Force $c; Say "  removed $c" }
    }
    if ($WantOC) {
        Remove-SkillsFrom $OpencodeSkills
        $c = Join-Path $OpencodeCmds 'trackbed.md'
        if (Test-Path $c) { Remove-Item -Force $c; Say "  removed $c" }
    }
    if ($WantCP) {
        Remove-SkillsFrom $CopilotSkills
    }
    if ($WantCX) {
        Remove-SkillsFrom $CodexSkills
    }
    Say 'Done.'
    exit 0
}

# --- install: decide the single skill home -----------------------------------

Say ''

# --- Claude Code + OpenCode (shared source, one skill home to avoid drift) ---

if ($WantCC -and $WantOC) {
    # Both runtimes -> skills live in ~/.claude/skills only; OpenCode reads it natively.
    Say 'Claude Code + OpenCode - skills go to ~/.claude/skills (OpenCode reads it natively).'
    Install-SkillsTo $ClaudeSkills
    # If a stale OpenCode-native copy exists, remove it so the two can't drift.
    if (Test-SkillsIn $OpencodeSkills) {
        Say 'Removing duplicate skills under OpenCode to avoid drift:'
        Remove-SkillsFrom $OpencodeSkills
    }
    Place $CcCmdSrc (Join-Path $ClaudeCmds 'trackbed.md')
    Place $OcCmdSrc (Join-Path $OpencodeCmds 'trackbed.md')
}
elseif ($WantCC) {
    Install-SkillsTo $ClaudeSkills
    Place $CcCmdSrc (Join-Path $ClaudeCmds 'trackbed.md')
}
elseif ($WantOC) {
    # OpenCode only. If a Claude install already exists, reuse it (OpenCode reads it).
    if (Test-SkillsIn $ClaudeSkills) {
        Say 'Found existing skills in ~/.claude/skills - OpenCode reads that path natively,'
        Say 'so skills are left there (not duplicated under OpenCode).'
    } else {
        Install-SkillsTo $OpencodeSkills
    }
    Place $OcCmdSrc (Join-Path $OpencodeCmds 'trackbed.md')
}

# --- Copilot CLI + Codex CLI (independent: own source, own home, no command file) ---

if ($WantCP) {
    Say 'GitHub Copilot CLI - skills go to ~/.copilot/skills (the skill is its own slash command).'
    Install-SkillsTo $CopilotSkills $CopilotSkillsSrc
}

if ($WantCX) {
    Say 'OpenAI Codex CLI - skills go to $env:CODEX_HOME/skills (default ~/.codex/skills; the skill is selected via /skills or mentioned with $).'
    Install-SkillsTo $CodexSkills $CodexSkillsSrc
}

Say ''
Say 'Done. Invoke /trackbed <jira-epic-key | project-slug> in Claude Code / OpenCode / Copilot CLI, or select the trackbed skill in Codex CLI.'

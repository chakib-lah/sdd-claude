# SDD Claude - global ~/.claude upgrade (Windows PowerShell)
# Same behavior as upgrade-global.sh: syncs skill junctions and refreshes the
# global agent copies. Stale unmodified agents are updated; customized
# (or translated) agents are kept and reported, with a prompt.
#
# Usage: .\upgrade-global.ps1 [-Force] [-KeepCustom]
param(
    [switch]$Force,
    [switch]$KeepCustom
)
$ErrorActionPreference = "Stop"

$ToolkitDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillsDst  = Join-Path $env:USERPROFILE ".claude\skills"
$AgentsDst  = Join-Path $env:USERPROFILE ".claude\agents"

$Version = "?"
$VersionFile = Join-Path $ToolkitDir "VERSION"
if (Test-Path $VersionFile) { $Version = (Get-Content $VersionFile -Raw).Trim() }

# Stale-vs-customized detection needs git and the toolkit's full history.
$HaveHistory = $false
$prevEap = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    $null = git -C $ToolkitDir rev-parse --git-dir 2>$null
    if ($LASTEXITCODE -eq 0) {
        $shallow = (git -C $ToolkitDir rev-parse --is-shallow-repository 2>$null)
        if ($LASTEXITCODE -eq 0 -and "$shallow".Trim() -ne "true") { $HaveHistory = $true }
    }
} catch { $HaveHistory = $false }
$ErrorActionPreference = $prevEap

Write-Host "============================================"
Write-Host " SDD Claude - global upgrade (toolkit v$Version)"
Write-Host " Source: $ToolkitDir"
Write-Host "============================================"
if (-not $HaveHistory) {
    Write-Host "  ! no git history available (ZIP download or shallow clone) - divergent agents cannot be classified stale vs customized"
}

New-Item -ItemType Directory -Force -Path $SkillsDst, $AgentsDst | Out-Null

# Removes a directory entry safely: a link (junction/symlink) is unlinked
# WITHOUT touching its target; only a real directory is deleted recursively.
# (On Windows PowerShell 5.1, Remove-Item -Recurse follows junctions and
# would delete the toolkit's own files.)
function Remove-DirEntry([string]$Path) {
    $item = Get-Item $Path -Force -ErrorAction SilentlyContinue
    if ($item -and ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
        [System.IO.Directory]::Delete($Path, $false)
    } else {
        Remove-Item $Path -Recurse -Force
    }
}

Write-Host "-> Skills (junctions):"
$skillDirs = Get-ChildItem -Directory (Join-Path $ToolkitDir "skills") -Filter "sdd-*"
if (-not $skillDirs) { Write-Host "  X no skills found under $ToolkitDir\skills - aborting"; exit 1 }
$skillDirs | ForEach-Object {
    $src = $_.FullName
    $dst = Join-Path $SkillsDst $_.Name
    $item = Get-Item $dst -Force -ErrorAction SilentlyContinue
    $targets = @()
    if ($item -and $item.LinkType) {
        # PS 5.1 reports junction targets in device form (\??\C:\...) - normalize
        $targets = @($item.Target) | ForEach-Object { "$_" -replace '^\\\?\?\\', '' } | ForEach-Object { $_.TrimEnd('\') }
    }
    if ($targets -contains $src.TrimEnd('\')) {
        Write-Host "  OK $($_.Name) (current)"
    } elseif (Test-Path $dst) {
        $existing = Get-Item $dst -Force
        if ($existing.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            # a link (junction/symlink) is not user data - unlink and relink
            Remove-DirEntry $dst
        } else {
            # real directory/file: user data - back up, never delete
            # (upgrade-global creates junctions, so a real directory here is never
            # the normal re-run case: it is a customization or an old copy)
            $bak = "$dst.bak-" + (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
            Move-Item $dst $bak
            Write-Host "  !  existing $($_.Name) was a real directory - backed up to $bak"
        }
        New-Item -ItemType Junction -Path $dst -Target $src | Out-Null
        Write-Host "  ~  $($_.Name) (repaired -> junction)"
    } else {
        New-Item -ItemType Junction -Path $dst -Target $src | Out-Null
        Write-Host "  +  $($_.Name) (added)"
    }
}

# True if the installed copy matches ANY committed version of the file.
# Compares git object IDs - no content pipeline, no encoding issues.
function Test-MatchesHistory([string]$RelFile, [string]$Installed) {
    if (-not $HaveHistory) { return $false }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $oid = (git -C $ToolkitDir hash-object -- $Installed 2>$null)
        if ($LASTEXITCODE -ne 0 -or -not $oid) { return $false }
        $oid = "$oid".Trim()
        $revs = git -C $ToolkitDir rev-list HEAD -- $RelFile 2>$null
        foreach ($rev in @($revs)) {
            $histOid = (git -C $ToolkitDir rev-parse "${rev}:$RelFile" 2>$null)
            if ($LASTEXITCODE -eq 0 -and "$histOid".Trim() -eq $oid) { return $true }
        }
        return $false
    } finally { $ErrorActionPreference = $prev }
}

Write-Host "-> Global agents (copies):"
$updated = 0; $kept = 0
$agentFiles = Get-ChildItem (Join-Path $ToolkitDir "global-agents") -Filter "*.md"
if (-not $agentFiles) { Write-Host "  X no agents found under $ToolkitDir\global-agents - aborting"; exit 1 }
$agentFiles | ForEach-Object {
    $src = $_.FullName
    $name = $_.Name
    $dst = Join-Path $AgentsDst $name
    if (-not (Test-Path $dst)) {
        Copy-Item $src $dst
        Write-Host "  +  $name (added)"
    } elseif ((Get-FileHash $src).Hash -eq (Get-FileHash $dst).Hash) {
        Write-Host "  OK $name (current)"
    } elseif (Test-MatchesHistory "global-agents/$name" $dst) {
        Copy-Item $src $dst -Force
        Write-Host "  ^  $name (stale -> updated)"
        $script:updated++
    } else {
        if ($HaveHistory) { $reason = "differs from every toolkit version (customized or translated copy)" }
        else              { $reason = "differs from the toolkit version (cannot verify: no git history)" }
        if ($Force) {
            Copy-Item $src $dst -Force
            Write-Host "  ^  $name (divergent -> overwritten, -Force)"
            $script:updated++
        } elseif ($KeepCustom) {
            Write-Host "  !  $name ($reason - kept)"
            $script:kept++
        } else {
            Write-Host "  !  $name $reason."
            $answer = Read-Host "     Overwrite with the toolkit version? [y/N]"
            if ($answer -eq "y" -or $answer -eq "Y") {
                Copy-Item $src $dst -Force
                Write-Host "  ^  $name (overwritten)"
                $script:updated++
            } else {
                Write-Host "  !  $name (kept)"
                $script:kept++
            }
        }
    }
}
Write-Host "  (files in $AgentsDst not shipped by the toolkit are never touched)"

Write-Host ""
Write-Host "Global upgrade complete (toolkit v$Version)."
if ($updated -gt 0) { Write-Host "   Updated agents: $updated" }
if ($kept -gt 0)    { Write-Host "   Divergent agents kept: $kept (re-run with -Force to overwrite)" }
Write-Host "   Note: projects are upgraded separately - run /sdd-upgrade inside each project."

# SDD Claude — global ~/.claude upgrade (Windows PowerShell)
# Same behavior as upgrade-global.sh: syncs skill links and refreshes the
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

Write-Host "════════════════════════════════════════════"
Write-Host " SDD Claude — global upgrade (toolkit v$Version)"
Write-Host " Source: $ToolkitDir"
Write-Host "════════════════════════════════════════════"

New-Item -ItemType Directory -Force -Path $SkillsDst, $AgentsDst | Out-Null

Write-Host "→ Skills (junctions):"
Get-ChildItem -Directory (Join-Path $ToolkitDir "skills") -Filter "sdd-*" | ForEach-Object {
    $src = $_.FullName
    $dst = Join-Path $SkillsDst $_.Name
    $item = Get-Item $dst -ErrorAction SilentlyContinue
    if ($item -and $item.LinkType -and $item.Target -eq $src) {
        Write-Host "  ✓ $($_.Name) (current)"
    } elseif (Test-Path $dst) {
        Remove-Item $dst -Recurse -Force
        New-Item -ItemType Junction -Path $dst -Target $src | Out-Null
        Write-Host "  ~ $($_.Name) (repaired → junction)"
    } else {
        New-Item -ItemType Junction -Path $dst -Target $src | Out-Null
        Write-Host "  + $($_.Name) (added)"
    }
}

# True if the installed copy matches ANY committed version of the file.
function Test-MatchesHistory([string]$RelFile, [string]$Installed) {
    Push-Location $ToolkitDir
    try {
        $revs = git rev-list HEAD -- $RelFile 2>$null
        if (-not $revs) { return $false }
        $installedBytes = [System.IO.File]::ReadAllBytes($Installed)
        foreach ($rev in $revs) {
            $tmp = [System.IO.Path]::GetTempFileName()
            git show "${rev}:$RelFile" 2>$null | Set-Content -NoNewline -Path $tmp -Encoding utf8
            $histBytes = [System.IO.File]::ReadAllBytes($tmp)
            Remove-Item $tmp -Force
            if ([System.Linq.Enumerable]::SequenceEqual($installedBytes, $histBytes)) { return $true }
        }
        return $false
    } finally { Pop-Location }
}

Write-Host "→ Global agents (copies):"
$updated = 0; $kept = 0
Get-ChildItem (Join-Path $ToolkitDir "global-agents") -Filter "*.md" | ForEach-Object {
    $src = $_.FullName
    $name = $_.Name
    $dst = Join-Path $AgentsDst $name
    if (-not (Test-Path $dst)) {
        Copy-Item $src $dst
        Write-Host "  + $name (added)"
    } elseif ((Get-FileHash $src).Hash -eq (Get-FileHash $dst).Hash) {
        Write-Host "  ✓ $name (current)"
    } elseif (Test-MatchesHistory "global-agents/$name" $dst) {
        Copy-Item $src $dst -Force
        Write-Host "  ↑ $name (stale → updated)"
        $script:updated++
    } else {
        if ($Force) {
            Copy-Item $src $dst -Force
            Write-Host "  ↑ $name (customized → overwritten, -Force)"
            $script:updated++
        } elseif ($KeepCustom) {
            Write-Host "  ⚠ $name (customized — kept)"
            $script:kept++
        } else {
            Write-Host "  ⚠ $name differs from every toolkit version (customized or translated copy)."
            $answer = Read-Host "    Overwrite with the toolkit version? [y/N]"
            if ($answer -eq "y" -or $answer -eq "Y") {
                Copy-Item $src $dst -Force
                Write-Host "  ↑ $name (overwritten)"
                $script:updated++
            } else {
                Write-Host "  ⚠ $name (kept)"
                $script:kept++
            }
        }
    }
}
Write-Host "  (files in $AgentsDst not shipped by the toolkit are never touched)"

Write-Host ""
Write-Host "✅ Global upgrade complete (toolkit v$Version)."
if ($updated -gt 0) { Write-Host "   Updated agents: $updated" }
if ($kept -gt 0)    { Write-Host "   Customized agents kept: $kept (re-run with -Force to overwrite)" }
Write-Host "   Note: projects are upgraded separately — run /sdd-upgrade inside each project."

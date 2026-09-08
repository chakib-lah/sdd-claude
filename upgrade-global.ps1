# SDD Claude - global ~/.claude upgrade (Windows PowerShell)
# Same behavior as upgrade-global.sh: syncs skill junctions and refreshes the
# global agent copies. Stale unmodified agents are updated; customized
# (or translated) agents are kept and reported, with a prompt.
#
# Usage: .\upgrade-global.ps1 [-Force] [-KeepCustom] [-ProjectPath C:\path\to\project]
#   -ProjectPath performs a one-time migration of ONE project's
#   .claude\commands\sdd-upgrade.md to the current stable shim (only when the
#   existing file is a verified historical toolkit version).
param(
    [switch]$Force,
    [switch]$KeepCustom,
    [string]$ProjectPath = ""
)
$ErrorActionPreference = "Stop"

$ToolkitDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillsDst  = Join-Path $env:USERPROFILE ".claude\skills"
$AgentsDst  = Join-Path $env:USERPROFILE ".claude\agents"
$CommandsDst = Join-Path $env:USERPROFILE ".claude\commands"

# True if the file's exact SHA-256 appears in the shipped manifest of known
# toolkit-owned sdd-upgrade.md versions (works without git history).
function Test-MatchesManifest([string]$File) {
    # Manifest hashes are computed on LF content (git blobs): normalize CRLF -> LF
    # before hashing so a Windows-checkout copy still matches exactly.
    $manifest = Join-Path $ToolkitDir "scripts\sdd-upgrade.known-hashes"
    if (-not (Test-Path $manifest)) { return $false }
    $bytes = [System.IO.File]::ReadAllBytes($File)
    $text  = [System.Text.Encoding]::UTF8.GetString($bytes).Replace("`r`n", "`n")
    $norm  = [System.Text.Encoding]::UTF8.GetBytes($text)
    $sha   = [System.Security.Cryptography.SHA256]::Create()
    $h     = ([System.BitConverter]::ToString($sha.ComputeHash($norm)) -replace '-', '').ToLower()
    return [bool](Select-String -Path $manifest -Pattern "^$h " -Quiet)
}

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

Write-Host "-> Global /sdd-upgrade bootstrap (copy):"
New-Item -ItemType Directory -Force -Path $CommandsDst | Out-Null
$gsrc = Join-Path $ToolkitDir "global-commands\sdd-upgrade.md"
$gdst = Join-Path $CommandsDst "sdd-upgrade.md"
if (-not (Test-Path $gsrc)) {
    Write-Host "  X toolkit bootstrap missing: $gsrc"; exit 1
} elseif (-not (Test-Path $gdst)) {
    Copy-Item $gsrc $gdst
    Write-Host "  +  sdd-upgrade.md (added)"
} elseif ((Get-FileHash $gsrc).Hash -eq (Get-FileHash $gdst).Hash) {
    Write-Host "  OK sdd-upgrade.md (current)"
} elseif ((Test-MatchesManifest $gdst) -or (Test-MatchesHistory "global-commands/sdd-upgrade.md" $gdst)) {
    Copy-Item $gsrc $gdst -Force
    Write-Host "  ^  sdd-upgrade.md (stale toolkit bootstrap -> updated)"
} elseif ($Force) {
    Copy-Item $gsrc $gdst -Force
    Write-Host "  ^  sdd-upgrade.md (divergent -> overwritten, -Force)"
} elseif ($KeepCustom) {
    Write-Host "  !  sdd-upgrade.md differs from every known toolkit version - kept (re-run with -Force to overwrite)"
} else {
    Write-Host "  !  global sdd-upgrade.md differs from every known toolkit version."
    $answer = Read-Host "     Overwrite with the toolkit bootstrap? [y/N]"
    if ($answer -eq "y" -or $answer -eq "Y") {
        Copy-Item $gsrc $gdst -Force
        Write-Host "  ^  sdd-upgrade.md (overwritten)"
    } else {
        Write-Host "  !  sdd-upgrade.md (kept)"
    }
}

# -ProjectPath: ONE-TIME migration of a single project's local updater.
# The ONLY project mutation performed: <project>\.claude\commands\sdd-upgrade.md
# is replaced by the current stable shim IFF the existing file is proven
# toolkit-owned (exact SHA-256 in the shipped manifest, or exact git object
# match against toolkit history when available). Divergent/unverifiable files
# are preserved and reported - ownership is never guessed.
if ($ProjectPath -ne "") {
    Write-Host "-> Project one-time /sdd-upgrade migration: $ProjectPath"
    $pfile = Join-Path $ProjectPath ".claude\commands\sdd-upgrade.md"
    $shim  = Join-Path $ToolkitDir "core\commands\sdd-upgrade.md"
    if (-not (Test-Path (Join-Path $ProjectPath ".claude"))) {
        Write-Host "  X $ProjectPath\.claude not found - is this an SDD project?"; exit 1
    } elseif (-not (Test-Path $pfile)) {
        Write-Host "  .  no local /sdd-upgrade command - nothing to migrate"
    } elseif ((Get-FileHash $shim).Hash -eq (Get-FileHash $pfile).Hash) {
        Write-Host "  OK already the current stable shim - nothing to do"
    } elseif ((Test-MatchesManifest $pfile) `
        -or (Test-MatchesHistory "core/commands/sdd-upgrade.md" $pfile) `
        -or (Test-MatchesHistory "skills/sdd-php-backend/reference/commands/sdd-upgrade.md" $pfile) `
        -or (Test-MatchesHistory "skills/sdd-php-symfony/reference/commands/sdd-upgrade.md" $pfile) `
        -or (Test-MatchesHistory "skills/sdd-symfony-angular/reference/commands/sdd-upgrade.md" $pfile) `
        -or (Test-MatchesHistory "skills/sdd-angular-node/reference/commands/sdd-upgrade.md" $pfile) `
        -or (Test-MatchesHistory "skills/sdd-java-backend/reference/commands/sdd-upgrade.md" $pfile) `
        -or (Test-MatchesHistory "skills/sdd-java-angular/reference/commands/sdd-upgrade.md" $pfile)) {
        Copy-Item $shim $pfile -Force
        Write-Host "  ^  known historical toolkit updater -> replaced with the current stable shim"
        Write-Host "     Next step: run /sdd-upgrade inside the project (it now loads the current procedure)"
    } else {
        Write-Host "  !  $pfile differs from every known toolkit-owned version (customized, translated, or unverifiable)."
        Write-Host "     Automatic migration refused - ownership is never guessed. Review the file manually,"
        Write-Host "     or run /sdd-upgrade inside the project so its own triage handles it."
    }
}

Write-Host ""
Write-Host "Global upgrade complete (toolkit v$Version)."
if ($updated -gt 0) { Write-Host "   Updated agents: $updated" }
if ($kept -gt 0)    { Write-Host "   Divergent agents kept: $kept (re-run with -Force to overwrite)" }
Write-Host "   Note: projects are upgraded separately - run /sdd-upgrade inside each project."

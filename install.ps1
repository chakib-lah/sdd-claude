# SDD Claude installer — Windows PowerShell
# Copies the 6 skills and the 9 global agents (Windows symlinks require admin -> we copy).
# Never destroys user data: a customized skill directory is backed up (a directory
# identical to the toolkit — the normal re-run case — is replaced silently), a divergent
# global agent is kept and reported (-Force to overwrite, mirroring upgrade-global.ps1).
param([switch]$Force)
$ErrorActionPreference = "Stop"
$ToolkitDir = $PSScriptRoot
$SkillsDst  = "$env:USERPROFILE\.claude\skills"
$AgentsDst  = "$env:USERPROFILE\.claude\agents"
$CommandsDst = "$env:USERPROFILE\.claude\commands"
$Skills = @("sdd-php-backend","sdd-php-symfony","sdd-symfony-angular","sdd-angular-node","sdd-java-backend","sdd-java-angular")

# Byte-level comparison of two directories (same relative file set, same hashes).
function Test-DirIdentical($a, $b) {
  $fa = Get-ChildItem $a -Recurse -File | Sort-Object { $_.FullName.Substring($a.Length) }
  $fb = Get-ChildItem $b -Recurse -File | Sort-Object { $_.FullName.Substring($b.Length) }
  if ($fa.Count -ne $fb.Count) { return $false }
  for ($i = 0; $i -lt $fa.Count; $i++) {
    if ($fa[$i].FullName.Substring($a.Length) -ne $fb[$i].FullName.Substring($b.Length)) { return $false }
    if ((Get-FileHash $fa[$i].FullName).Hash -ne (Get-FileHash $fb[$i].FullName).Hash) { return $false }
  }
  return $true
}

# Same classifiers as upgrade-global.ps1 — the ownership source of truth is the
# shipped scripts/sdd-upgrade.known-hashes manifest plus exact git-object
# history matching; ownership is never guessed from filename or content shape.
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

# Stale-vs-customized history detection needs git and the toolkit's full history.
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

Write-Host "SDD Claude - installing from $ToolkitDir"
New-Item -ItemType Directory -Force -Path $SkillsDst | Out-Null
New-Item -ItemType Directory -Force -Path $AgentsDst | Out-Null
New-Item -ItemType Directory -Force -Path $CommandsDst | Out-Null

foreach ($s in $Skills) {
  $src = Join-Path $ToolkitDir "skills\$s"
  $dst = Join-Path $SkillsDst $s
  if (Test-Path $dst) {
    # A junction (left by upgrade-global.ps1) must be unlinked, NOT recursed:
    # on Windows PowerShell 5.1, Remove-Item -Recurse follows the junction and
    # would delete the toolkit's own skills/ content.
    $item = Get-Item $dst -Force
    if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
      [System.IO.Directory]::Delete($dst, $false)
    } elseif (Test-DirIdentical $dst $src) {
      # real directory left by a previous install, identical to the toolkit:
      # normal re-run case, replace silently
      Remove-Item -Recurse -Force $dst
    } else {
      # real directory that DIFFERS from the toolkit: user data - back up, never delete
      $bak = "$dst.bak-" + (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
      Move-Item $dst $bak
      Write-Host "  WARNING: existing $s differs from the toolkit - backed up to $bak"
    }
  }
  Copy-Item -Recurse $src $dst
  Write-Host "  skill copied: $s"
}

$copied = 0; $kept = 0
foreach ($f in Get-ChildItem "$ToolkitDir\global-agents\*.md") {
  $dst = Join-Path $AgentsDst $f.Name
  if (-not (Test-Path $dst)) {
    Copy-Item $f.FullName $dst; $copied++
  } elseif ((Get-FileHash $f.FullName).Hash -eq (Get-FileHash $dst).Hash) {
    # byte-identical to the toolkit version: nothing to do
  } elseif ($Force) {
    Copy-Item $f.FullName $dst -Force; $copied++
    Write-Host "  overwritten (-Force): $($f.Name)"
  } else {
    $kept++
    Write-Host "  kept (differs from toolkit): $($f.Name)"
  }
}
Write-Host "  $copied agent(s) copied into $AgentsDst"
if ($kept -gt 0) {
  Write-Host "  WARNING: $kept divergent agent(s) kept - re-run with -Force to overwrite"
}

$gsrc = Join-Path $ToolkitDir "global-commands\sdd-upgrade.md"
$gdst = Join-Path $CommandsDst "sdd-upgrade.md"
if (-not (Test-Path $gdst)) {
  Copy-Item $gsrc $gdst
  Write-Host "  global /sdd-upgrade bootstrap installed into $CommandsDst"
} elseif ((Get-FileHash $gsrc).Hash -eq (Get-FileHash $gdst).Hash) {
  # byte-identical toolkit bootstrap: nothing to do
} elseif ((Test-MatchesManifest $gdst) -or (Test-MatchesHistory "global-commands/sdd-upgrade.md" $gdst)) {
  Copy-Item $gsrc $gdst -Force
  Write-Host "  global sdd-upgrade.md: known stale toolkit bootstrap - updated"
} elseif ($Force) {
  Copy-Item $gsrc $gdst -Force
  Write-Host "  global sdd-upgrade.md overwritten (-Force)"
} else {
  Write-Host "  WARNING: existing global sdd-upgrade.md differs from every known toolkit version - kept (re-run with -Force to overwrite)"
}

Write-Host "Installation complete. Verify: dir $env:USERPROFILE\.claude\skills"
Write-Host "Note: on Windows, re-run this script after every git pull (copy, not symlink)."

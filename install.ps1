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

Write-Host "SDD Claude - installing from $ToolkitDir"
New-Item -ItemType Directory -Force -Path $SkillsDst | Out-Null
New-Item -ItemType Directory -Force -Path $AgentsDst | Out-Null

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

Write-Host "Installation complete. Verify: dir $env:USERPROFILE\.claude\skills"
Write-Host "Note: on Windows, re-run this script after every git pull (copy, not symlink)."

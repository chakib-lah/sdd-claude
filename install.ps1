# SDD Claude installer — Windows PowerShell
# Copies the 4 skills and the 8 global agents (Windows symlinks require admin -> we copy).
$ErrorActionPreference = "Stop"
$ToolkitDir = $PSScriptRoot
$SkillsDst  = "$env:USERPROFILE\.claude\skills"
$AgentsDst  = "$env:USERPROFILE\.claude\agents"
$Skills = @("sdd-php-backend","sdd-php-symfony","sdd-symfony-angular","sdd-angular-node")

Write-Host "SDD Claude - installing from $ToolkitDir"
New-Item -ItemType Directory -Force -Path $SkillsDst | Out-Null
New-Item -ItemType Directory -Force -Path $AgentsDst | Out-Null

foreach ($s in $Skills) {
  $src = Join-Path $ToolkitDir "skills\$s"
  $dst = Join-Path $SkillsDst $s
  if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
  Copy-Item -Recurse $src $dst
  Write-Host "  skill copied: $s"
}
Copy-Item "$ToolkitDir\global-agents\*.md" $AgentsDst -Force
Write-Host "Installation complete. Verify: dir $env:USERPROFILE\.claude\skills"
Write-Host "Note: on Windows, re-run this script after every git pull (copy, not symlink)."

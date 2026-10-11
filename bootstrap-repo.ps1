<#
.SYNOPSIS
    Run ONCE to restructure repos, create .gitignore, push initial commit.
.REQUIRES
    PAT file at D:\Market HFT OS\GithubPersonalAccessTokenFORAG.env
#>

param(
    [string]$RepoRoot = "D:\Agents",
    [string]$PatEnvPath = "D:\Market HFT OS\GithubPersonalAccessTokenFORAG.env"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "=== Bootstrap D:\Agents as monorepo ===" -ForegroundColor Cyan

# 1. Remove nested .git dirs (A0-A7 are empty, safe to delete)
Get-ChildItem $RepoRoot -Directory | Where-Object {$_.Name -match "^A[0-7]"} | ForEach-Object {
    $gitDir = Join-Path $_.FullName ".git"
    if (Test-Path $gitDir) {
        Remove-Item $gitDir -Recurse -Force
        Write-Host "Removed $gitDir"
    }
}

# 2. Initialize root repo
if (-not (Test-Path (Join-Path $RepoRoot ".git"))) {
    cd $RepoRoot
    git init
    Write-Host "Initialized git repo at $RepoRoot"
}

# 3. Write .gitignore (already exists from File 1, but ensure)
$gitignore = @"
# Staging & archives
_staging/
*.zip

# Environment & secrets
.env
.env.*
*.env

# Node / build
node_modules/
dist/
build/
*.tsbuildinfo

# Sync artifacts
.sync.log
sync-*.tmp

# OS
Thumbs.db
.DS_Store
"@
Set-Content (Join-Path $RepoRoot ".gitignore") $gitignore -Encoding UTF8
Write-Host "Created .gitignore"

# 4. Add remote
$remoteUrl = "https://github.com/Shrom-Main/Agents.git"
cd $RepoRoot
if (-not (git remote | Where-Object {$_ -eq "origin"})) {
    git remote add origin $remoteUrl
    Write-Host "Added remote origin"
}

# 5. Initial commit & push
git add -A
try { git commit -m "Initial monorepo: A0-A7 structure + sync automation" } catch { Write-Host "Nothing to commit" }

# 6. Push with PAT
$pat = Get-Content $PatEnvPath -Raw
if ($pat -match '^(?:GITHUB_PAT|PAT|TOKEN)\s*=\s*(.+)$') { $pat = $matches[1].Trim() } else { $pat = $pat.Trim() }
$pushUrl = "https://$pat@github.com/Shrom-Main/Agents.git"
git remote set-url origin $pushUrl
git push -u origin main
Write-Host "Pushed to GitHub" -ForegroundColor Green
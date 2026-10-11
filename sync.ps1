<#
.SYNOPSIS
    Sync local D:\Agents to GitHub (Shrom-Main/Agents) using local PAT.
.DESCRIPTION
    Reads PAT from env file, detects changes, commits with timestamp, pushes.
    Idempotent, safe for repeated runs (scheduled task + watcher).
#>

param(
    [string]$RepoRoot = "D:\Agents",
    [string]$PatEnvPath = "D:\Market HFT OS\GithubPersonalAccessTokenFORAG.env",
    [string]$RemoteName = "origin",
    [string]$Branch = "main",
    [int]$DebounceSec = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Read-PAT {
    param($Path)
    if (-not (Test-Path $Path)) { throw "PAT file not found: $Path" }
    $content = Get-Content $Path -Raw
    # Expect format: GITHUB_PAT=ghp_xxxxxxxxxxxx  or just the token
    if ($content -match '^(?:GITHUB_PAT|PAT|TOKEN)\s*=\s*(.+)$') {
        return $matches[1].Trim()
    }
    return $content.Trim()
}

function Write-Log {
    param($Msg, $Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts [$Level] $Msg" | Tee-Object -FilePath (Join-Path $RepoRoot ".sync.log") -Append
}

try {
    Push-Location $RepoRoot

    # 1. Load PAT
    $pat = Read-PAT $PatEnvPath
    if (-not $pat) { throw "PAT is empty" }
    Write-Log "PAT loaded (length: $($pat.Length))"

    # 2. Ensure remote URL uses PAT (temporary, not persisted)
    $remoteUrl = "https://$pat@github.com/Shrom-Main/Agents.git"
    $currentUrl = git remote get-url $RemoteName 2>$null
    if ($currentUrl -ne $remoteUrl) {
        git remote set-url $RemoteName $remoteUrl
        Write-Log "Remote URL updated with PAT"
    }

    # 3. Check for changes
    $status = git status --porcelain
    if (-not $status) {
        Write-Log "No changes detected"
        exit 0
    }

    Write-Log "Changes detected:`n$status"

    # 4. Debounce: wait for quiet period (handles rapid saves)
    $lastChange = Get-Date
    $quiet = $false
    while (-not $quiet) {
        Start-Sleep -Seconds 2
        $newStatus = git status --porcelain
        if ($newStatus -ne $status) {
            $status = $newStatus
            $lastChange = Get-Date
            Write-Log "New changes during debounce, resetting timer"
        }
        elseif ((Get-Date) - $lastChange).TotalSeconds -ge $DebounceSec {
            $quiet = $true
        }
    }

    # 5. Stage, commit, push
    git add -A
    $msg = "Auto-sync: $(Get-Date -Format 'u') — $($status.Split("`n").Count) files"
    git commit -m $msg
    Write-Log "Committed: $msg"

    git push $RemoteName $Branch
    Write-Log "Push successful"

}
catch {
    Write-Log "ERROR: $($_.Exception.Message)" "ERROR"
    exit 1
}
finally {
    Pop-Location
}
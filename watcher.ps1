<#
.SYNOPSIS
    FileSystemWatcher that triggers sync.ps1 on changes.
.RUNAS
    Run via Scheduled Task at logon (or NSSM service).
#>

param(
    [string]$RepoRoot = "D:\Agents",
    [string]$SyncScript = "D:\Agents\sync.ps1",
    [int]$DebounceMs = 2000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $RepoRoot
$watcher.IncludeSubdirectories = $true
$watcher.Filter = "*.*"
$watcher.NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite, CreationTime, Size'

$timer = $null
$pending = $false

function Invoke-Sync {
    if ($pending) { return }
    $pending = $true
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Changes detected, scheduling sync..."
    if ($timer) { $timer.Dispose() }
    $timer = [System.Threading.Timer]::new({
        $pending = $false
        & $SyncScript
    }, $null, $DebounceMs, [System.Threading.Timeout]::Infinite)
}

Register-ObjectEvent -InputObject $watcher -EventName Changed -Action { Invoke-Sync } | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Created -Action { Invoke-Sync } | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Deleted -Action { Invoke-Sync } | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action { Invoke-Sync } | Out-Null

$watcher.EnableRaisingEvents = $true
Write-Host "[$(Get-Date)] Watcher started on $RepoRoot. Press Ctrl+C to stop."

try {
    while ($true) { Start-Sleep -Seconds 60 }
}
finally {
    $watcher.EnableRaisingEvents = $false
    $watcher.Dispose()
    if ($timer) { $timer.Dispose() }
    Get-EventSubscriber | Unregister-Event -Force
    Write-Host "Watcher stopped."
}
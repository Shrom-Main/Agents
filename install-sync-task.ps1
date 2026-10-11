<#
.SYNOPSIS
    Registers a Scheduled Task to run sync.ps1 every 5 minutes
    AND a logon-triggered task to start watcher.ps1.
.REQUIRES
    Run as Administrator (for task registration).
#>

param(
    [string]$RepoRoot = "D:\Agents",
    [string]$TaskNameSync = "Agents-AutoSync",
    [string]$TaskNameWatcher = "Agents-FileWatcher"
)

# --- Sync task (every 5 min) ---
$actionSync = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$RepoRoot\sync.ps1`""
$triggerSync = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration ([TimeSpan]::MaxValue)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd -AllowStartIfOnBatteries
Register-ScheduledTask -TaskName $TaskNameSync -Action $actionSync -Trigger $triggerSync -Settings $settings -Force -RunLevel Highest
Write-Host "Registered sync task: $TaskNameSync (every 5 min)"

# --- Watcher task (at logon) ---
$actionWatch = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$RepoRoot\watcher.ps1`""
$triggerWatch = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName $TaskNameWatcher -Action $actionWatch -Trigger $triggerWatch -Settings $settings -Force -RunLevel Highest
Write-Host "Registered watcher task: $TaskNameWatcher (at logon)"

Write-Host "Done. Tasks will run as current user."
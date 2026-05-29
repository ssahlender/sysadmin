<#
.SYNOPSIS
    Registers Backup-OneNote.ps1 as a daily Windows Scheduled Task.
    Run this once as Administrator, then the backup runs automatically every day.

.PARAMETER Time
    Time of day to run the backup. Default: "02:00" (2 AM).

.PARAMETER ScriptPath
    Full path to Backup-OneNote.ps1. Auto-detected if in same folder.
#>
param(
    [string]$Time = "02:00",
    [string]$ScriptPath = ""
)

# Auto-find the backup script
if (-not $ScriptPath) {
    $ScriptPath = Join-Path $PSScriptRoot "Backup-OneNote.ps1"
}
if (-not (Test-Path $ScriptPath)) {
    Write-Error "Cannot find Backup-OneNote.ps1 at: $ScriptPath"
    Write-Error "Specify -ScriptPath manually."
    exit 1
}

$taskName    = "OneNote Daily Backup"
$taskDesc    = "Daily backup of all local OneNote notebooks"
$psExe       = (Get-Command powershell.exe).Source
$taskArgs    = "-NonInteractive -ExecutionPolicy Bypass -File `"$ScriptPath`""

$action  = New-ScheduledTaskAction -Execute $psExe -Argument $taskArgs
$trigger = New-ScheduledTaskTrigger -Daily -At $Time
$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable:$false `
    -WakeToRun:$false `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1)

# Run as current user (no password prompt, no elevation needed for file copies)
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

try {
    # Remove existing task if present
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

    Register-ScheduledTask `
        -TaskName  $taskName `
        -Description $taskDesc `
        -Action    $action `
        -Trigger   $trigger `
        -Settings  $settings `
        -Principal $principal | Out-Null

    Write-Host ""
    Write-Host "Scheduled task registered successfully!" -ForegroundColor Green
    Write-Host "  Task name : $taskName"
    Write-Host "  Runs daily: $Time"
    Write-Host "  Script    : $ScriptPath"
    Write-Host ""
    Write-Host "Manage the task in: Task Scheduler > Task Scheduler Library"
    Write-Host "Or run manually  : Start-ScheduledTask -TaskName '$taskName'"
    Write-Host ""
    Write-Host "Tip: edit BackupDestinations in Backup-OneNote.ps1 to add more" -ForegroundColor Cyan
    Write-Host "     destinations (external drive, NAS, etc.)"
} catch {
    Write-Error "Failed to register task: $_"
    Write-Host "Try running this script as Administrator." -ForegroundColor Yellow
}

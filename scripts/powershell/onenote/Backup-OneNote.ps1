<#
.SYNOPSIS
    Creates a full backup of all OneNote notebooks to one or more destinations.
    Designed to be run daily via Windows Task Scheduler.

.PARAMETER Destinations
    One or more paths to copy backups to. Edit the $BackupDestinations list below
    to set your defaults, or pass them on the command line.

.PARAMETER MaxAgeDays
    Delete backup snapshots older than this many days (per destination). Default: 30.

.PARAMETER WhatIf
    Show what would be done without actually copying or deleting.

.EXAMPLE
    .\Backup-OneNote.ps1
    .\Backup-OneNote.ps1 -Destinations "D:\Backups\OneNote","E:\Backups\OneNote"
    .\Backup-OneNote.ps1 -MaxAgeDays 60 -WhatIf
#>
param(
    [string[]]$Destinations = @(),
    [int]$MaxAgeDays = 30,
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ============================================================
# CONFIGURE YOUR BACKUP DESTINATIONS HERE
# Add as many folders as you want (local drives, USB, network)
# ============================================================
$BackupDestinations = @(
    "$env:USERPROFILE\Documents\OneNote_Backups"
    # "D:\Backups\OneNote"       # uncomment and edit for external drive
    # "\\NAS\Backups\OneNote"    # uncomment for network share
)
# Override with command-line parameter if provided
if ($Destinations.Count -gt 0) { $BackupDestinations = $Destinations }

# ============================================================
# SOURCE LOCATIONS TO SEARCH FOR ONENOTE NOTEBOOKS
# ============================================================
$SearchRoots = @(
    # Live OneDrive notebooks
    "$env:USERPROFILE\OneDrive"
    # Local notebooks
    "$env:USERPROFILE\Documents"
    # OneNote auto-backup folder (captures all local changes)
    "$env:LOCALAPPDATA\Microsoft\OneNote\16.0\Sicherung"
    "$env:LOCALAPPDATA\Microsoft\OneNote\16.0\Backup"
)

# ============================================================

function Write-Log {
    param([string]$Msg, [string]$Color = "White")
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$ts] $Msg" -ForegroundColor $Color
}

# ============================================================
# STEP 0: Force OneNote to sync all notebooks before backing up
#         so that all pages and images are downloaded locally.
# ============================================================
if (-not $WhatIf) {
    Write-Log "Connecting to OneNote to force sync..." Cyan
    $synced = $false
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        try {
            $onenote = New-Object -ComObject OneNote.Application

            $xmlHierarchy = ""
            $onenote.GetHierarchy("", [int]1, [ref]$xmlHierarchy)
            [xml]$hierarchy = $xmlHierarchy

            $nbCount = 0
            foreach ($nb in $hierarchy.Notebooks.Notebook) {
                Write-Log "  Syncing: $($nb.name)" Gray
                try { $onenote.SyncHierarchy($nb.ID) } catch {}
                $nbCount++
            }

            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($onenote) | Out-Null
            Write-Log "Sync triggered for $nbCount notebooks. Waiting 60s for downloads..." Cyan
            Start-Sleep -Seconds 60
            $synced = $true
            break

        } catch {
            Write-Log "  Attempt $attempt/5 failed - retrying in 10s..." Yellow
            Start-Sleep -Seconds 10
        }
    }
    if (-not $synced) {
        Write-Log "Could not connect to OneNote after 5 attempts. Is OneNote open? Continuing without sync." Yellow
    }
}

$stamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
Write-Host ""
Write-Host "OneNote Full Backup  -  $stamp" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
if ($WhatIf) { Write-Host "(DRY RUN)" -ForegroundColor Yellow }
Write-Host ""

# --- Collect all notebook files ---
$filesToBackup = [System.Collections.Generic.List[System.IO.FileInfo]]::new()

foreach ($root in $SearchRoots) {
    if (-not (Test-Path $root -ErrorAction SilentlyContinue)) { continue }

    Write-Log "Searching: $root" Gray
    $found = Get-ChildItem $root -Recurse -Include "*.one","*.onetoc2" -ErrorAction SilentlyContinue |
        Where-Object {
            # Skip our own backup and restore folders to avoid duplicates
            $_.FullName -notmatch "OneNote_Backups" -and
            $_.FullName -notmatch "OneNote_Restored" -and
            $_.FullName -notmatch "OneNote_Wiederhergestellt"
        }
    foreach ($f in $found) {
        $filesToBackup.Add($f)
    }
}

if ($filesToBackup.Count -eq 0) {
    Write-Log "No OneNote files found. Check that OneNote notebooks are synced locally." Yellow
    exit 0
}

Write-Log "Found $($filesToBackup.Count) OneNote files to back up."
$totalSize = ($filesToBackup | Measure-Object Length -Sum).Sum
Write-Log ("Total size: {0:N1} MB" -f ($totalSize / 1MB))
Write-Host ""

# --- Copy to each destination ---
$overallErrors = 0

foreach ($dest in $BackupDestinations) {
    $snapDest = Join-Path $dest $stamp
    Write-Log "Backing up to: $snapDest" Cyan

    if (-not $WhatIf) {
        New-Item -ItemType Directory -Path $snapDest -Force | Out-Null
    }

    $copied = 0
    $errors = 0

    foreach ($file in $filesToBackup) {
        # Find the common root this file belongs to
        $matchedRoot = $SearchRoots | Where-Object {
            (Test-Path $_ -ErrorAction SilentlyContinue) -and $file.FullName.StartsWith($_)
        } | Sort-Object Length -Descending | Select-Object -First 1

        $relPath  = if ($matchedRoot) {
            $file.FullName.Substring($matchedRoot.Length).TrimStart('\','/')
        } else {
            $file.Name
        }
        $destPath = Join-Path $snapDest $relPath
        $destDir  = Split-Path $destPath

        try {
            if (-not $WhatIf) {
                if (-not (Test-Path $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                Copy-Item -Path $file.FullName -Destination $destPath -Force
            }
            $copied++
        } catch {
            Write-Log "  ERROR copying $($file.Name): $_" Red
            $errors++
            $overallErrors++
        }
    }

    Write-Log "  Copied: $copied files  |  Errors: $errors" $(if ($errors -gt 0) { "Yellow" } else { "Green" })

    # --- Prune old snapshots ---
    Write-Log "  Checking for old snapshots (>$MaxAgeDays days)..." Gray
    $oldSnaps = Get-ChildItem $dest -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$MaxAgeDays) }

    foreach ($old in $oldSnaps) {
        Write-Log "  Removing old snapshot: $($old.Name)" DarkGray
        if (-not $WhatIf) {
            Remove-Item $old.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Host ""
}

# --- Summary ---
$status = if ($overallErrors -gt 0) { "Completed with $overallErrors error(s)" } else { "Completed successfully" }
$color  = if ($overallErrors -gt 0) { "Yellow" } else { "Green" }
Write-Log $status $color

# Write a simple log entry (useful when run from Task Scheduler)
$logFile = "$env:USERPROFILE\Documents\OneNote_Backups\backup.log"
if (-not $WhatIf) {
    $logDir = Split-Path $logFile
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory $logDir -Force | Out-Null }
    "$stamp  Files: $($filesToBackup.Count)  Status: $status" |
        Add-Content -Path $logFile -Encoding UTF8
}

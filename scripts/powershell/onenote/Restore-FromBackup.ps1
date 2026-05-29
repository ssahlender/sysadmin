<#
.SYNOPSIS
    Restores OneNote notebooks from a backup snapshot created by Backup-OneNote.ps1.
    Finds the latest snapshot automatically, extracts notebook folders,
    copies them to the destination and registers them in OneNote.

.PARAMETER BackupRoot
    Folder containing the timestamped snapshots. Default: Documents\OneNote_Backups

.PARAMETER SnapshotDate
    Use a specific snapshot instead of the latest. e.g. "2026-05-29_22-17"

.PARAMETER Destination
    Where to place restored notebooks. Default: Documents\OneNote_Restored

.PARAMETER WhatIf
    Show what would be done without copying anything.

.EXAMPLE
    .\Restore-FromBackup.ps1
    .\Restore-FromBackup.ps1 -SnapshotDate "2026-05-29_22-17"
#>
param(
    [string]$BackupRoot    = "$env:USERPROFILE\Documents\OneNote_Backups",
    [string]$SnapshotDate  = "",
    [string]$Destination   = "$env:USERPROFILE\Documents\OneNote_Restored",
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

# --- Find snapshot ---
if ($SnapshotDate) {
    $snapshot = Join-Path $BackupRoot $SnapshotDate
    if (-not (Test-Path $snapshot)) {
        Write-Error "Snapshot not found: $snapshot"
        exit 1
    }
} else {
    $snapshot = Get-ChildItem $BackupRoot -Directory |
        Sort-Object Name -Descending |
        Select-Object -First 1 -ExpandProperty FullName
    if (-not $snapshot) {
        Write-Error "No snapshots found in $BackupRoot"
        exit 1
    }
}

Write-Host ""
Write-Host "OneNote Restore from Backup" -ForegroundColor Cyan
Write-Host "===========================" -ForegroundColor Cyan
Write-Host "Snapshot : $snapshot"
Write-Host "Target   : $Destination"
if ($WhatIf) { Write-Host "(DRY RUN)" -ForegroundColor Yellow }
Write-Host ""

# List available snapshots for reference
Write-Host "Available snapshots:" -ForegroundColor Gray
Get-ChildItem $BackupRoot -Directory | Sort-Object Name -Descending |
    ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor Gray }
Write-Host ""

# --- Find all .one files in snapshot and group by notebook ---
$allFiles = Get-ChildItem $snapshot -Recurse -Filter "*.one" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch "OneNote_RecycleBin" }

# Notebooks are identified by finding the top-level folder that contains .one files
# The snapshot stores files as: <SearchRoot-relative-path>\NotebookName\Section.one
# We find the deepest common parent that looks like a notebook (contains .one directly)

$notebookDirs = $allFiles |
    ForEach-Object { $_.DirectoryName } |
    Sort-Object -Unique |
    ForEach-Object {
        # Walk up to find the folder that is directly inside one of the search roots
        $dir = $_
        while ($dir -and (Split-Path $dir -Parent) -ne $snapshot) {
            $parentOfDir = Split-Path $dir -Parent
            # Check if parent contains .one files directly (= it's a notebook root)
            $parentHasOne = Get-ChildItem $parentOfDir -Filter "*.one" -ErrorAction SilentlyContinue
            if ($parentHasOne) { $dir = $parentOfDir } else { break }
        }
        $dir
    } |
    Sort-Object -Unique

# Simpler approach: find all notebook-level folders
# A notebook folder = a folder whose .one files are not in a deeper "notebook" subfolder
# Just find the common ancestor folders that are 2-3 levels deep in the snapshot
$nbFolders = $allFiles | ForEach-Object {
    # Get path relative to snapshot
    $rel = $_.FullName.Substring($snapshot.Length).TrimStart('\','/')
    # Notebook is usually at depth 2-3 (SearchRoot\NotebookName or OneDrive\Docs\NotebookName)
    $parts = $rel.Split('\')
    # Find the part that looks like a notebook (before section groups)
    # Heuristic: the last folder before the .one file that has a known notebook name
    if ($parts.Count -ge 2) { Join-Path $snapshot ($parts[0..($parts.Count-2)] -join '\' | Split-Path) } else { $snapshot }
} | Sort-Object -Unique

# Better: just find top-level notebook folders by looking at what's in the snapshot
# The snapshot mirrors OneDrive\Dokumente\NotebookName or Sicherung\NotebookName
# Find all unique "notebook root" paths

$copiedFiles = 0
$restoredNbs = [System.Collections.Generic.List[string]]::new()

# Group files by their notebook folder
$grouped = $allFiles | Group-Object {
    $rel   = $_.FullName.Substring($snapshot.Length).TrimStart('\','/')
    $parts = $rel.Split('\')
    # Find the notebook name - it's the last folder component that doesn't look like
    # a Windows path component (not "Users", "OneDrive", "Sicherung", "Dokumente", etc.)
    $skipFolders = @('Users','OneDrive','Dokumente','Documents','AppData','Local',
                     'Microsoft','OneNote','16.0','Sicherung','Backup',$env:USERNAME)
    $nbIndex = 0
    for ($i = 0; $i -lt $parts.Count - 1; $i++) {
        if ($parts[$i] -notin $skipFolders) { $nbIndex = $i; break }
    }
    $parts[$nbIndex]
}

foreach ($nbGroup in $grouped) {
    $nbName = $nbGroup.Name
    $destNb = Join-Path $Destination $nbName
    Write-Host "Notebook: $nbName" -ForegroundColor Green

    if (-not $restoredNbs.Contains($destNb)) { $restoredNbs.Add($destNb) }

    foreach ($file in $nbGroup.Group) {
        # Reconstruct relative path within notebook
        $rel   = $file.FullName.Substring($snapshot.Length).TrimStart('\','/')
        $parts = $rel.Split('\')
        $skipFolders = @('Users','OneDrive','Dokumente','Documents','AppData','Local',
                         'Microsoft','OneNote','16.0','Sicherung','Backup',$env:USERNAME)
        $nbIndex = 0
        for ($i = 0; $i -lt $parts.Count - 1; $i++) {
            if ($parts[$i] -notin $skipFolders) { $nbIndex = $i; break }
        }
        # Everything after notebook name is the section (group) structure
        $sectionRelParts = $parts[($nbIndex+1)..($parts.Count-1)]
        $sectionRel      = $sectionRelParts -join '\'

        $destFile = Join-Path $destNb $sectionRel
        $destDir  = Split-Path $destFile

        Write-Host ("  {0}" -f $sectionRel)

        if (-not $WhatIf) {
            if (-not (Test-Path $destDir)) { New-Item -ItemType Directory $destDir -Force | Out-Null }
            Copy-Item $file.FullName $destFile -Force
        }
        $copiedFiles++
    }
    Write-Host ""
}

if ($WhatIf) {
    Write-Host "DRY RUN done. $copiedFiles files would be restored." -ForegroundColor Yellow
    exit 0
}

Write-Host "Copied $copiedFiles files. Registering in OneNote..." -ForegroundColor Cyan

try {
    $onenote = New-Object -ComObject OneNote.Application
    foreach ($nb in $restoredNbs) {
        if (Test-Path $nb) {
            $id = ""
            $onenote.OpenHierarchy($nb, "", [ref]$id, 1)
            Write-Host "  OK  $(Split-Path $nb -Leaf)" -ForegroundColor Green
        }
    }
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($onenote) | Out-Null
} catch {
    Write-Warning "OneNote COM registration failed. Open OneNote manually:"
    $restoredNbs | ForEach-Object { Write-Host "  File > Notizbuch oeffnen -> $_" }
}

Write-Host ""
Write-Host "Done. Notebooks restored to: $Destination" -ForegroundColor Green

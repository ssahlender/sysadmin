<#
.SYNOPSIS
    Restores OneNote notebooks from the automatic backup folder directly into
    OneNote. Uses the OneNote COM API so each notebook is properly registered
    with all its sections - no manual file-opening needed.

.PARAMETER BackupRoot
    Path to the OneNote backup folder. Auto-detected if not specified.

.PARAMETER Destination
    Where to place the restored notebook folders before opening them in OneNote.
    Default: OneDrive\Dokumente  (so they sync to the cloud automatically)

.PARAMETER WhatIf
    Show what would be done without touching anything.

.EXAMPLE
    .\Restore-OneNoteBackup.ps1
    .\Restore-OneNoteBackup.ps1 -Destination "D:\MyNotebooks" -WhatIf
#>
param(
    [string]$BackupRoot   = "",
    [string]$Destination  = "$env:USERPROFILE\OneDrive\Dokumente",
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# 1. Locate the backup root
# ---------------------------------------------------------------------------
if (-not $BackupRoot) {
    foreach ($c in @(
        "$env:LOCALAPPDATA\Microsoft\OneNote\16.0\Sicherung",
        "$env:LOCALAPPDATA\Microsoft\OneNote\16.0\Backup"
    )) {
        if (Test-Path $c) { $BackupRoot = $c; break }
    }
    if (-not $BackupRoot) {
        Write-Error "Cannot find OneNote backup folder. Use -BackupRoot to specify it."
        exit 1
    }
}

Write-Host ""
Write-Host "OneNote Restore -> Cloud" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan
Write-Host "Backup : $BackupRoot"
Write-Host "Target : $Destination"
if ($WhatIf) { Write-Host "(DRY RUN)" -ForegroundColor Yellow }
Write-Host ""

$notebookFolders = Get-ChildItem $BackupRoot -Directory
if ($notebookFolders.Count -eq 0) { Write-Warning "No notebooks found."; exit 0 }

# ---------------------------------------------------------------------------
# 2. Copy latest version of each section into the destination folder
#    Structure:  Destination\<NotebookName>\[SectionGroup\]SectionName.one
# ---------------------------------------------------------------------------
$restoredRoots = [System.Collections.Generic.List[string]]::new()

foreach ($nb in $notebookFolders) {
    $destNbDir = Join-Path $Destination $nb.Name
    Write-Host "Notebook: $($nb.Name)" -ForegroundColor Green

    $sections = Get-ChildItem $nb.FullName -Recurse -Filter "*.one" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch "OneNote_RecycleBin" }

    # Group by (relative subfolder + clean section name), pick newest copy
    $grouped = $sections | Group-Object {
        $rel       = $_.DirectoryName.Substring($nb.FullName.Length).TrimStart('\','/')
        $cleanBase = $_.BaseName -replace '\s*\(Am \d{2}\.\d{2}\.\d{4}\)$', ''
        "$rel||$cleanBase"
    }

    foreach ($grp in $grouped) {
        $latest    = $grp.Group | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        $rel       = $latest.DirectoryName.Substring($nb.FullName.Length).TrimStart('\','/')
        $cleanName = ($latest.BaseName -replace '\s*\(Am \d{2}\.\d{2}\.\d{4}\)$', '') + ".one"
        $destDir   = if ($rel) { Join-Path $destNbDir $rel } else { $destNbDir }
        $destFile  = Join-Path $destDir $cleanName

        $kb  = [math]::Round($latest.Length / 1KB)
        $age = [int]((Get-Date) - $latest.LastWriteTime).TotalDays
        Write-Host ("  {0,-50} {1,5} KB  ({2}d ago)" -f $cleanName, $kb, $age)

        if (-not $WhatIf) {
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item $latest.FullName -Destination $destFile -Force
        }
    }

    $restoredRoots.Add($destNbDir)
    Write-Host ""
}

if ($WhatIf) {
    Write-Host "DRY RUN done. No files were copied." -ForegroundColor Yellow
    exit 0
}

# ---------------------------------------------------------------------------
# 3. Open each notebook folder in OneNote via COM
#    This makes OneNote create the .onetoc2 index, register the notebook
#    properly (with all sections), and start syncing to OneDrive/cloud.
# ---------------------------------------------------------------------------
Write-Host "Registering notebooks in OneNote..." -ForegroundColor Cyan

try {
    $onenote = New-Object -ComObject OneNote.Application
} catch {
    Write-Warning "Could not connect to OneNote. Is OneNote 2016 installed?"
    Write-Warning "Open OneNote manually and use File > Notizbuch oeffnen for each folder below."
    $restoredRoots | ForEach-Object { Write-Host "  $_" }
    exit 0
}

$ok    = 0
$fails = 0

foreach ($nbPath in $restoredRoots) {
    $name = Split-Path $nbPath -Leaf
    try {
        $id = ""
        # cftNotebook = 1  ->  open (or create) the folder as a notebook
        $onenote.OpenHierarchy($nbPath, "", [ref]$id, 1)
        Write-Host "  OK  $name" -ForegroundColor Green
        $ok++
    } catch {
        Write-Host "  ERR $name  ->  $_" -ForegroundColor Red
        $fails++
    }
}

[System.Runtime.InteropServices.Marshal]::ReleaseComObject($onenote) | Out-Null

Write-Host ""
if ($fails -eq 0) {
    Write-Host "All $ok notebooks restored and opened in OneNote." -ForegroundColor Green
    Write-Host "They are syncing to OneDrive now - check the sync icon in OneNote." -ForegroundColor Cyan
} else {
    Write-Host "$ok notebooks OK, $fails failed." -ForegroundColor Yellow
    Write-Host "For failed notebooks: File > Notizbuch oeffnen > Durchsuchen -> select the folder."
}
Write-Host ""
Write-Host "Destination: $Destination"

<#
    Registers the already-copied notebook folders in OneNote via COM.
    OneNote will create .onetoc2 files and start syncing to OneDrive.
#>
param(
    [string]$NotebookRoot = "$env:USERPROFILE\OneDrive\Dokumente"
)

$folders = Get-ChildItem $NotebookRoot -Directory |
    Where-Object { $_.Name -notin @('not-working','old','Dokumente') }

Write-Host ""
Write-Host "Registering $($folders.Count) notebooks in OneNote..." -ForegroundColor Cyan
Write-Host "Root: $NotebookRoot"
Write-Host ""

try {
    $onenote = New-Object -ComObject OneNote.Application
} catch {
    Write-Error "Cannot connect to OneNote COM. Make sure OneNote 2016 is installed and not blocked."
    exit 1
}

$ok = 0; $fails = 0

foreach ($folder in $folders) {
    try {
        $id = ""
        $onenote.OpenHierarchy($folder.FullName, "", [ref]$id, 1)
        Write-Host "  OK   $($folder.Name)" -ForegroundColor Green
        $ok++
    } catch {
        Write-Host "  FAIL $($folder.Name)  ->  $_" -ForegroundColor Red
        $fails++
    }
}

[System.Runtime.InteropServices.Marshal]::ReleaseComObject($onenote) | Out-Null

Write-Host ""
if ($fails -eq 0) {
    Write-Host "Done! All $ok notebooks are now open in OneNote and syncing to OneDrive." -ForegroundColor Green
} else {
    Write-Host "$ok OK, $fails failed." -ForegroundColor Yellow
    Write-Host "For failed ones: in OneNote -> File -> Notizbuch oeffnen -> Durchsuchen -> select the folder."
}

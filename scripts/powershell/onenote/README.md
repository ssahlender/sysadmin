# OneNote Backup & Restore Scripts

PowerShell scripts for backing up and restoring OneNote 2016 notebooks on Windows.

## Background

OneNote notebooks synced via OneDrive use a partial sync model — images and content
not recently viewed may exist only on the OneDrive server, not locally. The automatic
OneNote backup folder (`AppData\Local\Microsoft\OneNote\16.0\Sicherung`) only captures
locally cached content, which can mean missing images in backups.

**Recommended:** Disable OneDrive "Files On-Demand" so all content is always stored
locally, making backups complete.

## Scripts

### `Backup-OneNote.ps1`
Creates timestamped snapshots of all OneNote notebooks to one or more destinations.

- Searches OneDrive, Documents and the OneNote Sicherung folder automatically
- Prunes snapshots older than 30 days (configurable)
- Triggers a OneNote sync via COM before copying (requires OneNote to be open)
- Writes a log entry to `OneNote_Backups\backup.log`

```powershell
# Run with defaults
.\Backup-OneNote.ps1

# Custom destinations
.\Backup-OneNote.ps1 -Destinations "D:\Backups\OneNote","\\NAS\Backups\OneNote"

# Keep 60 days of snapshots
.\Backup-OneNote.ps1 -MaxAgeDays 60

# Dry run
.\Backup-OneNote.ps1 -WhatIf
```

**Edit `$BackupDestinations`** at the top of the script to set your default backup
locations (local drive, USB, NAS).

---

### `Install-OneNoteBackupTask.ps1`
Registers `Backup-OneNote.ps1` as a daily Windows Scheduled Task. Run once.

```powershell
# Default: runs at 02:00
.\Install-OneNoteBackupTask.ps1

# Custom time
.\Install-OneNoteBackupTask.ps1 -Time "20:00"

# Custom script location
.\Install-OneNoteBackupTask.ps1 -ScriptPath "D:\Scripts\Backup-OneNote.ps1"
```

---

### `Restore-OneNoteBackup.ps1`
Restores notebooks from OneNote's own automatic backup folder (`Sicherung`).
Picks the latest version of each section, strips date stamps from filenames,
and registers the notebooks in OneNote via COM.

```powershell
# Dry run - shows what would be restored
.\Restore-OneNoteBackup.ps1 -WhatIf

# Restore to default location (Documents\OneNote_Restored)
.\Restore-OneNoteBackup.ps1

# Restore directly to OneDrive
.\Restore-OneNoteBackup.ps1 -Destination "$env:USERPROFILE\OneDrive\Documents"
```

---

### `Restore-FromBackup.ps1`
Restores notebooks from a timestamped snapshot created by `Backup-OneNote.ps1`.
Automatically picks the latest snapshot or a specific date.

```powershell
# Restore from latest snapshot
.\Restore-FromBackup.ps1

# Restore from specific snapshot
.\Restore-FromBackup.ps1 -SnapshotDate "2026-05-29_22-17"

# Custom backup and restore locations
.\Restore-FromBackup.ps1 -BackupRoot "D:\Backups\OneNote" -Destination "D:\OneNote_Restored"

# Dry run
.\Restore-FromBackup.ps1 -WhatIf
```

---

### `Register-RestoredNotebooks.ps1`
Registers an already-copied folder of notebooks in OneNote via COM, so they
appear in the sidebar as proper notebooks rather than individual files.
Useful after manually copying `.one` files into place.

```powershell
# Register notebooks from default location
.\Register-RestoredNotebooks.ps1

# Register from a custom folder
.\Register-RestoredNotebooks.ps1 -NotebookRoot "D:\MyNotebooks"
```

---

## Typical Workflows

### First-time setup
```powershell
# 1. Install the daily scheduled task
.\Install-OneNoteBackupTask.ps1

# 2. Run a manual backup to verify
.\Backup-OneNote.ps1
```

### Disaster recovery
```powershell
# 1. Restore from latest backup snapshot
.\Restore-FromBackup.ps1 -WhatIf   # check first
.\Restore-FromBackup.ps1

# 2. In OneNote: right-click each notebook -> Speicherort aendern -> OneDrive
```

### Recovering from OneNote's own Sicherung folder
```powershell
.\Restore-OneNoteBackup.ps1 -WhatIf
.\Restore-OneNoteBackup.ps1
```

## Requirements

- Windows 10/11
- OneNote 2016 (Microsoft 365 desktop version)
- PowerShell 5.1+
- OneNote must be running for the COM sync step (backup still works without it)

<#
.SYNOPSIS
  Install or update the Rocrail CLIENT on Windows, or remove it.

.DESCRIPTION
  Role split: Windows is a client (Rocview, the GUI). No service, no server and no autostart
  are configured - Rocview attaches to a Rocrail server (the Raspberry Pi or the balcony
  server) via  Datei/File -> "Verbinden mit..."  or a shortcut pre-pointed with -h/-p.
  No workspace is created either, unless you pass -Workspace to build an empty one (only
  meaningful if this machine ever hosts a layout itself).

  First-run install and update are the same command, mirroring the Linux script. Re-running is
  the supported update path: Rocrail/Rocview are stopped, the new build is extracted into a
  staging directory, the previous one is kept as <InstallDir>.prev, and the shortcut is
  recreated.

  The snapshot ships native executables; no Java runtime is installed or required.
  The zip also contains rocrail.exe and the server path switches (-installservice /
  -deleteservice exist for running the SERVER as a Windows service), but this script
  deliberately does not use them - see the README.

  The download logic is the BITS transfer from the previously working update script.

.PARAMETER InstallDir
  Where Rocrail is installed. Default: C:\data\rocrail

.PARAMETER Arch
  x64 (default), arm64, or win32. Default is detected from the OS.

.PARAMETER Workspace
  Optional: create an empty workspace directory with trace\ and issues\, for when this machine
  ever hosts a layout locally. A workspace is normally created by the server, not the client.

.PARAMETER Check
  Report installed vs available and exit. 0 = up to date, 1 = update available, 2 = not installed.

.PARAMETER Uninstall
  Remove the installation directory and the shortcut. Workspaces are never touched.

.EXAMPLE
  .\install-windows.ps1
  .\install-windows.ps1 -Check
  .\install-windows.ps1 -Workspace balkon
  .\install-windows.ps1 -Uninstall
#>
[CmdletBinding()]
param(
    [string] $InstallDir = 'C:\data\rocrail',
    [ValidateSet('auto', 'x64', 'arm64', 'win32')]
    [string] $Arch = 'auto',
    [string] $Workspace = '',
    [switch] $Check,
    [switch] $Uninstall,
    [switch] $NoShortcut,
    [switch] $DryRun,
    [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- download matrix
$SnapshotBase = 'https://www.rocrail.online/rocrail-snapshot'
$RevisionUrl  = "$SnapshotBase/log.txt"

function Write-Log  { param([string]$Message) Write-Host $Message }
function Write-Warn { param([string]$Message) Write-Warning $Message }

function Resolve-Build {
    param([string]$Requested)
    if ($Requested -ne 'auto') { return $Requested }
    $isArm = $env:PROCESSOR_ARCHITECTURE -in @('ARM64', 'ARM')
    $is64  = [Environment]::Is64BitOperatingSystem
    if ($isArm) { return 'arm64' }
    if ($is64)  { return 'x64' }
    return 'win32'
}

function Get-ArchiveName {
    param([string]$Build)
    switch ($Build) {
        'x64'   { return 'Rocrail-Windows-WIN64.zip' }
        'arm64' { return 'Rocrail-Windows-WINARM64.zip' }
        'win32' { return 'Rocrail-Windows-WIN32.zip' }
        default { throw "unsupported architecture: $Build" }
    }
}

function Get-InstalledRevision {
    param([string]$Root)
    $info = Join-Path $Root 'revision.info'
    if (-not (Test-Path -LiteralPath $info)) { return '' }
    $line = Get-Content -LiteralPath $info -TotalCount 1
    if ($line -match '^Revision:\s*(\d+)') { return $Matches[1] }
    return ''
}

function Get-AdvertisedRevision {
    try {
        $resp = Invoke-WebRequest -Uri $RevisionUrl -UseBasicParsing -TimeoutSec 20
        $first = ($resp.Content -split "`n")[0]
        if ($first -match '^\s*(\d+)') { return $Matches[1] }
    } catch { }
    return ''
}

function Get-RemoteInfo {
    param([string]$Url)
    try {
        $resp = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -TimeoutSec 20
        $lm = $resp.Headers['Last-Modified']
        if ($lm) {
            return [pscustomobject]@{ LastModified = $lm; Length = $resp.Headers['Content-Length'] }
        }
    } catch { }
    # In Windows PowerShell 5.1 a HEAD across a redirect does not always return the final
    # asset's headers. Fall back to a one-byte ranged GET of the asset itself.
    try {
        $resp = Invoke-WebRequest -Uri $Url -Headers @{ Range = 'bytes=0-0' } -UseBasicParsing -TimeoutSec 20
        return [pscustomobject]@{
            LastModified = $resp.Headers['Last-Modified']
            Length       = $resp.Headers['Content-Range']
        }
    } catch { return $null }
}

$Build   = Resolve-Build -Requested $Arch
$Archive = Get-ArchiveName -Build $Build
$Url     = "$SnapshotBase/$Archive"

# ---------------------------------------------------------------- check
if ($Check) {
  try {
    $installed = Get-InstalledRevision -Root $InstallDir
    $advertised = Get-AdvertisedRevision
    $remote = Get-RemoteInfo -Url $Url
    $recordPath = Join-Path $InstallDir 'install-record.json'
    $recorded = $null
    if (Test-Path -LiteralPath $recordPath) {
        try { $recorded = (Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json) } catch { $recorded = $null }
    }
    # Under Set-StrictMode a missing property THROWS (verified on PS 5.1), and a record
    # written by an earlier revision has no archive_last_modified - which turned -Check into a
    # false "update available" (exit 1). PSObject.Properties returns $null instead.
    $recLm = $null
    if ($recorded) {
        $recLmProp = $recorded.PSObject.Properties['archive_last_modified']
        if ($recLmProp) { $recLm = $recLmProp.Value }
    }

    Write-Log "platform        : $Build   build: $Archive"
    Write-Log "install dir     : $InstallDir"
    Write-Log "url             : $Url"
    Write-Log "installed       : $(if ($installed) { $installed } else { '<not installed>' })"
    Write-Log "installed from  : $(if ($recLm) { $recLm } else { '<not recorded>' })"
    Write-Log "available (file): $(if ($remote) { $remote.LastModified } else { '<unavailable>' })"
    Write-Log "newest overall  : $(if ($advertised) { $advertised } else { '<unavailable>' })   (any platform; informational)"

    if (-not $installed) {
        Write-Log 'verdict         : NOT INSTALLED'
        exit 2
    }
    # The global newest revision says nothing about THIS platform's archive - platforms are
    # published at different times - and an unreachable feed is not an update.
    if (-not $remote -or -not $remote.LastModified) {
        Write-Log 'verdict         : UNKNOWN - could not reach the archive, nothing was compared'
        exit 3
    }
    if ($recLm -eq $remote.LastModified) {
        Write-Log 'verdict         : up to date (this archive is unchanged)'
        exit 0
    }
    Write-Log "verdict         : UPDATE AVAILABLE (archive changed since install)"
    exit 1
  } catch {
    # exit 1 means "update available" - a monitoring probe acting on that would try to
    # install. An unexpected error is not that, so report it as unknown.
    Write-Log "verdict         : UNKNOWN - the check itself failed: $($_.Exception.Message)"
    exit 3
  }
}

# ---------------------------------------------------------------- uninstall
if ($Uninstall) {
    if (-not (Test-Path -LiteralPath $InstallDir)) { throw "not installed: $InstallDir" }
    $looksLikeRocrail = (Test-Path -LiteralPath (Join-Path $InstallDir 'revision.info')) -or
                        (Test-Path -LiteralPath (Join-Path $InstallDir 'install-record.json'))
    if (-not $looksLikeRocrail -and -not $Force) {
        throw "$InstallDir does not look like a Rocrail install (no revision.info, no install-record.json); refusing to remove it. Pass -Force if that is really intended."
    }
    if ($DryRun) {
        Write-Log "DRY RUN - would remove $InstallDir and the shortcut. Workspaces, rocrail.ini and lic.dat are never touched."
        exit 0
    }

    Get-Process -Name 'rocrail', 'rocview' -ErrorAction SilentlyContinue |
        Stop-Process -Force

    Write-Log "Removing $InstallDir"
    Remove-Item -LiteralPath $InstallDir -Recurse -Force

    if (-not $NoShortcut) {
        foreach ($dir in @((Join-Path ([Environment]::GetFolderPath('Programs')) 'Rocrail.lnk'),
                           (Join-Path ([Environment]::GetFolderPath('Desktop'))  'Rocview.lnk'))) {
            if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Force }
        }
    }
    Write-Log 'Removed. Workspaces, plans, rocrail.ini and lic.dat were NOT touched.'
    exit 0
}

# ---------------------------------------------------------------- dry run
if ($DryRun) {
    Write-Log 'DRY RUN - nothing will be changed.'
    Write-Log "  build      : $Archive"
    Write-Log "  url        : $Url"
    Write-Log "  install dir: $InstallDir   (previous kept as $InstallDir.prev)"
    Write-Log "  shortcut   : $(if ($NoShortcut) { 'skipped' } else { 'Start-Menu (and Desktop if it already has one)' })"
    Write-Log "  workspace  : $(if ($Workspace) { "$InstallDir-workspaces\$Workspace" } else { 'not created (client role)' })"
    exit 0
}

# ---------------------------------------------------------------- prerequisites
if (-not (Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue)) {
    throw 'BITS is not available (Start-BitsTransfer missing). Enable the BitsTransfer module.'
}

# ---------------------------------------------------------------- stop running instances
$running = Get-Process -Name 'rocrail', 'rocview' -ErrorAction SilentlyContinue
if ($running) {
    Write-Log "Stopping $($running.Count) running Rocrail process(es)."
    $running | Stop-Process -Force
    foreach ($p in $running) {
        try { $p.WaitForExit(15000) | Out-Null } catch { }
    }
}

# ---------------------------------------------------------------- download
$tmpZip = Join-Path $env:TEMP $Archive
if (Test-Path -LiteralPath $tmpZip) { Remove-Item -LiteralPath $tmpZip -Force }

Write-Log "Downloading $Archive"
$attempt = 0
while ($true) {
    $attempt++
    try {
        # Without -Asynchronous this transfers in the foreground, returns no job and needs no
        # Complete-BitsTransfer, so there is no job to clean up when an attempt fails.
        Start-BitsTransfer -Source $Url -Destination $tmpZip -TransferType Download -ErrorAction Stop
        if (-not (Test-Path -LiteralPath $tmpZip)) {
            throw 'the transfer reported success but produced no file'
        }
        break
    } catch {
        if ($attempt -ge 3) { throw "download failed after $attempt attempts: $($_.Exception.Message)" }
        Write-Warn "download attempt $attempt failed; retrying in 5s"
        Start-Sleep -Seconds 5
    }
}

# Declared here, not inside the try: under Set-StrictMode the catch below must be able to
# reference them even if the failure happens before they would have been assigned.
$stage = "$InstallDir.new"
$prev  = "$InstallDir.prev"
# Set only when the swap has actually happened. The catch below must not "restore" a
# leftover .prev from an earlier run over a perfectly good current install.
$swapped = $false

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($tmpZip)
    try {
        $entry = $zip.Entries | Where-Object { $_.FullName -eq 'revision.info' } | Select-Object -First 1
        if ($entry) {
            $reader = New-Object System.IO.StreamReader($entry.Open())
            $first = $reader.ReadLine()
            $reader.Close()
            if ($first -match '^Revision:\s*(\d+)') {
                $zipRev = $Matches[1]
                Write-Log "Downloaded build: revision $zipRev"
                $adv = Get-AdvertisedRevision
                if ($adv -and $zipRev -ne $adv) {
                    Write-Warn "downloaded build (rev $zipRev) is not the newest advertised (rev $adv); platforms are published at different times"
                }
            }
        }
    } finally { $zip.Dispose() }

    # ------------------------------------------------------------ stage, validate, then swap
    # Everything that can fail happens before the current installation is moved, so a bad
    # archive leaves a working installation in place.
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    Write-Log "Extracting to $stage"
    Expand-Archive -LiteralPath $tmpZip -DestinationPath $stage -Force

    if (-not (Test-Path -LiteralPath (Join-Path $stage 'bin\rocview.exe'))) {
        throw "the archive contains no bin\rocview.exe; refusing to swap"
    }

    # Carry over anything the vendor does not ship. The shortcut runs Rocview with the install
    # directory as its working directory, so this is where a user's own rocrail.ini, any
    # *.bak and lic.dat live - the swap would push them into .prev and the NEXT update would
    # delete them. The vendor archives ship none of these at their root (verified), so
    # "not present in the stage" is exactly the right test.
    if (Test-Path -LiteralPath $InstallDir) {
        $carried = @()
        foreach ($item in (Get-ChildItem -LiteralPath $InstallDir -Force)) {
            if ($item.Name -in @('install-record.json', 'install-options.conf')) { continue }
            if ($item.Name -like 'Rocrail-*.zip') { continue }
            if ($item.Name -like '*.prev') { continue }
            if (Test-Path -LiteralPath (Join-Path $stage $item.Name)) { continue }
            Copy-Item -LiteralPath $item.FullName -Destination (Join-Path $stage $item.Name) -Recurse -Force
            $carried += $item.Name
        }
        if ($carried.Count -gt 0) { Write-Log "Carried over into the new build: $($carried -join ', ')" }
    }

    if (Test-Path -LiteralPath $InstallDir) {
        if (Test-Path -LiteralPath $prev) { Remove-Item -LiteralPath $prev -Recurse -Force }
        Move-Item -LiteralPath $InstallDir -Destination $prev
        $swapped = $true
        Write-Log "Previous installation kept at $prev"
    }
    Move-Item -LiteralPath $stage -Destination $InstallDir

    # keep the archive and a record of what was installed
    Copy-Item -LiteralPath $tmpZip -Destination (Join-Path $InstallDir $Archive) -Force
    $hash = (Get-FileHash -LiteralPath $tmpZip -Algorithm SHA256).Hash.ToLower()
    $rev  = Get-InstalledRevision -Root $InstallDir
    $remoteInfo = Get-RemoteInfo -Url $Url
    [pscustomobject]@{
        revision  = $(if ($rev) { $rev } else { 'unknown' })
        file      = $Archive
        url       = $Url
        sha256    = $hash
        archive_last_modified = $(if ($remoteInfo) { $remoteInfo.LastModified } else { '' })
        installed = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        installed_by = 'install-windows.ps1'
    } | ConvertTo-Json -Compress | Set-Content -LiteralPath (Join-Path $InstallDir 'install-record.json') -Encoding ASCII
}
catch {
    # A throw after the old installation was moved aside would otherwise leave this machine
    # with NO installation. Put the previous one back and report the failure.
    Write-Warn "installation failed: $($_.Exception.Message)"
    if ($swapped -and $prev -and (Test-Path -LiteralPath $prev)) {
        if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $InstallDir) { Remove-Item -LiteralPath $InstallDir -Recurse -Force -ErrorAction SilentlyContinue }
        Move-Item -LiteralPath $prev -Destination $InstallDir -Force
        Write-Warn "the previous installation was restored to $InstallDir"
    }
    throw
}
finally {
    if (Test-Path -LiteralPath $tmpZip) { Remove-Item -LiteralPath $tmpZip -Force -ErrorAction SilentlyContinue }
}

# ---------------------------------------------------------------- optional workspace
if ($Workspace) {
    $wsRoot = "$InstallDir-workspaces"
    $wsPath = Join-Path $wsRoot $Workspace
    Write-Log "Creating workspace $wsPath"
    foreach ($sub in @('trace', 'issues')) {
        New-Item -ItemType Directory -Path (Join-Path $wsPath $sub) -Force | Out-Null
    }
    Write-Log 'Note: a client does not need a workspace. This is only useful if this machine runs a layout server.'
}

# ---------------------------------------------------------------- shortcut (client: no -sp/-dp)
$rocview = Join-Path $InstallDir 'bin\rocview.exe'
if (-not $NoShortcut) {
    if (-not (Test-Path -LiteralPath $rocview)) {
        Write-Warn "rocview.exe not found at $rocview - skipping the shortcut"
    } else {
        # Deliberately WITHOUT -sp/-dp: the vendor's desktoplink passes "-sp <dir>\bin", which
        # starts a LOCAL server and opens the demo workspace. This machine is a client, so the
        # shortcut starts Rocview plain; attach with Datei -> "Verbinden mit...".
        $shell   = New-Object -ComObject WScript.Shell
        $targets = @((Join-Path ([Environment]::GetFolderPath('Programs')) 'Rocrail.lnk'))
        $desktop = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Rocview.lnk'
        if (Test-Path -LiteralPath $desktop) { $targets += $desktop }   # refresh one if present

        foreach ($lnkPath in $targets) {
            $lnk = $shell.CreateShortcut($lnkPath)
            $lnk.TargetPath       = $rocview
            $lnk.WorkingDirectory = $InstallDir
            $lnk.IconLocation     = "$rocview,0"
            $lnk.Description      = 'Rocrail Rocview (client - attach to a server via File > Verbinden mit...)'
            $lnk.Arguments        = ''
            $lnk.Save()
            Write-Log "Shortcut written: $lnkPath"
        }
    }
}

# ---------------------------------------------------------------- report
$finalRev = Get-InstalledRevision -Root $InstallDir
Write-Log ''
Write-Log 'Rocrail client installed.'
Write-Log "  revision  : $(if ($finalRev) { $finalRev } else { 'unknown' })"
Write-Log "  directory : $InstallDir"
Write-Log "  previous  : $InstallDir.prev"
Write-Log ''
Write-Log 'This is a CLIENT. To attach to a server:'
Write-Log '  start Rocview from the Start Menu, then  Datei -> "Verbinden mit..."'
Write-Log '  and enter the server address with port 8051.'
Write-Log ''
Write-Log 'Note: the first start may raise a Windows Defender warning (More info -> Run anyway).'

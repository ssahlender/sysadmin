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

function Stop-RocrailProcesses {
    # Rocview is a GUI client and flushes its settings on a normal exit, so ask it to close before
    # forcing it. -Force is the fallback here, not the first move.
    $procs = @(Get-Process -Name 'rocrail', 'rocview' -ErrorAction SilentlyContinue)
    if ($procs.Count -eq 0) { return @() }
    foreach ($p in $procs) {
        try { if ($p.MainWindowHandle -ne 0) { [void]$p.CloseMainWindow() } } catch { }
    }
    foreach ($p in $procs) {
        try { [void]$p.WaitForExit(10000) } catch { }
    }
    $leftover = @(Get-Process -Name 'rocrail', 'rocview' -ErrorAction SilentlyContinue)
    foreach ($p in $leftover) {
        try { $p.Kill() } catch { }
    }
    return $leftover
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

    Stop-RocrailProcesses | Out-Null

    Write-Log "Removing $InstallDir"
    # Say what this actually removes: anything the user keeps INSIDE the install directory (a
    # local rocrail.ini, a lic.dat, backups) goes with it - the old wording claimed otherwise.
    foreach ($f in @('lic.dat', 'rocrail.ini')) {
        $inner = Join-Path $InstallDir $f
        if (Test-Path -LiteralPath $inner) { Write-Warn "$f is inside $InstallDir and is removed with it" }
    }
    Remove-Item -LiteralPath $InstallDir -Recurse -Force

    if (-not $NoShortcut) {
        foreach ($dir in @((Join-Path ([Environment]::GetFolderPath('Programs')) 'Rocrail.lnk'),
                           (Join-Path ([Environment]::GetFolderPath('Desktop'))  'Rocview.lnk'))) {
            if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Force }
        }
    }
    Write-Log 'Removed. Workspaces, plans and anything outside the install directory were not touched.'
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

# ---------------------------------------------------------------- nothing to do?
# A client has no options to adopt and no service to reconcile, so an unchanged archive means an
# unchanged installation - and rotating .prev with the same build only makes a later rollback
# restore what is already installed. Runs before anything is stopped or downloaded.
#
# The archive's Last-Modified is read BEFORE it is fetched (and reused for the record below).
# Reading it afterwards races the vendor: a re-publish mid-download would store the newer value
# against the older content, and this check would then skip a needed update forever. Read first,
# the harmless failure is the other way round - the next run simply updates again.
$remoteBefore = Get-RemoteInfo -Url $Url

if (-not $Force -and (Test-Path -LiteralPath (Join-Path $InstallDir 'revision.info')) -and
    (Test-Path -LiteralPath (Join-Path $InstallDir 'install-record.json'))) {
    $recPath = Join-Path $InstallDir 'install-record.json'
    $rec = $null
    try { $rec = (Get-Content -LiteralPath $recPath -Raw | ConvertFrom-Json) } catch { $rec = $null }
    $recLm = $null
    if ($rec) {
        $recLmProp = $rec.PSObject.Properties['archive_last_modified']
        if ($recLmProp) { $recLm = $recLmProp.Value }
    }
    if ($recLm -and $remoteBefore -and $remoteBefore.LastModified -eq $recLm) {
        Write-Log "Already up to date: revision $(Get-InstalledRevision -Root $InstallDir), this archive is unchanged."
        Write-Log 'Nothing to do. Use -Force to reinstall anyway.'
        exit 0
    }
}

# ---------------------------------------------------------------- stop running instances
$running = @(Get-Process -Name 'rocrail', 'rocview' -ErrorAction SilentlyContinue)
if ($running.Count -gt 0) {
    Write-Log "Stopping $($running.Count) running Rocrail process(es)."
    Stop-RocrailProcesses | Out-Null
}

# ---------------------------------------------------------------- download
$tmpZip = Join-Path $env:TEMP $Archive
if (Test-Path -LiteralPath $tmpZip) { Remove-Item -LiteralPath $tmpZip -Force }

function Get-ArchiveWithBits {
    param([string]$Source, [string]$Destination)
    # Without -Asynchronous this transfers in the foreground, returns no job and needs no
    # Complete-BitsTransfer, so there is no job left behind when an attempt fails.
    Start-BitsTransfer -Source $Source -Destination $Destination -TransferType Download -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $Destination)) {
        throw 'the transfer reported success but produced no file'
    }
}

function Get-ArchiveWithHttp {
    param([string]$Source, [string]$Destination)
    # PS 5.1 draws a progress bar per chunk, which makes a 30 MB file crawl.
    $previous = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        Invoke-WebRequest -Uri $Source -OutFile $Destination -UseBasicParsing -TimeoutSec 300 -ErrorAction Stop
    } finally { $ProgressPreference = $previous }
    if (-not (Test-Path -LiteralPath $Destination)) {
        throw 'the download reported success but produced no file'
    }
}

Write-Log "Downloading $Archive"
$bitsError = ''
$got = $false
for ($attempt = 1; $attempt -le 3 -and -not $got; $attempt++) {
    try { Get-ArchiveWithBits -Source $Url -Destination $tmpZip; $got = $true }
    catch {
        $bitsError = $_.Exception.Message
        if ($attempt -lt 3) {
            Write-Warn "BITS attempt $attempt failed; retrying in 5s"
            Start-Sleep -Seconds 5
        }
    }
}
if (-not $got) {
    # BITS requires a logged-on interactive session. Driven through PSRP, Ansible or a service it
    # fails with 0x800704DD ("the user has not logged on to the network") even though the BITS
    # service is running and Start-BitsTransfer exists - verified on a real host. A plain HTTP
    # request works there, and which mechanism fetched the file matters less than the update
    # working at all.
    Write-Warn "BITS could not download the archive: $bitsError"
    Write-Warn 'falling back to a direct HTTP download'
    Get-ArchiveWithHttp -Source $Url -Destination $tmpZip
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
    $remoteInfo = $remoteBefore
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

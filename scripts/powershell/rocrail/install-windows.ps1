<#
.SYNOPSIS
  Install or update the Rocrail CLIENT on Windows, or remove it.

.DESCRIPTION
  Role split: Windows is a client (Rocview, the GUI). No service, no server and no autostart
  are configured - Rocview attaches to a Rocrail server (the Raspberry Pi or the balcony
  server) via  Datei/File -> "Verbinden mit..."  or a shortcut pre-pointed with -h/-p.

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
    [switch] $DryRun
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
        return [pscustomobject]@{
            LastModified = $resp.Headers['Last-Modified']
            Length       = $resp.Headers['Content-Length']
        }
    } catch { return $null }
}

$Build   = Resolve-Build -Requested $Arch
$Archive = Get-ArchiveName -Build $Build
$Url     = "$SnapshotBase/$Archive"

# ---------------------------------------------------------------- check
if ($Check) {
    $installed = Get-InstalledRevision -Root $InstallDir
    $advertised = Get-AdvertisedRevision
    $remote = Get-RemoteInfo -Url $Url
    $recordPath = Join-Path $InstallDir 'install-record.json'

    Write-Log "platform        : $Build   build: $Archive"
    Write-Log "install dir     : $InstallDir"
    Write-Log "url             : $Url"
    Write-Log "installed       : $(if ($installed) { $installed } else { '<not installed>' })"
    Write-Log "available (log) : $(if ($advertised) { $advertised } else { '<unavailable>' })"
    Write-Log "available (file): $(if ($remote) { $remote.LastModified } else { '<unavailable>' })"
    if (Test-Path -LiteralPath $recordPath) {
        Write-Log "last installed  : $((Get-Content -LiteralPath $recordPath -Raw).Trim())"
    }
    if (-not $installed) {
        Write-Log 'verdict         : NOT INSTALLED'
        exit 2
    }
    if ($advertised -and $installed -eq $advertised) {
        Write-Log 'verdict         : up to date'
        exit 0
    }
    Write-Log "verdict         : UPDATE AVAILABLE (installed $installed, newest $(if ($advertised) { $advertised } else { 'unknown' }))"
    exit 1
}

# ---------------------------------------------------------------- uninstall
if ($Uninstall) {
    if (-not (Test-Path -LiteralPath $InstallDir)) { throw "not installed: $InstallDir" }

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
$job = $null
while ($true) {
    $attempt++
    try {
        $job = Start-BitsTransfer -Source $Url -Destination $tmpZip -TransferType Download -ErrorAction Stop
        break
    } catch {
        if ($job) { Remove-BitsTransfer -BitsJob $job -ErrorAction SilentlyContinue; $job = $null }
        if ($attempt -ge 3) { throw "download failed after $attempt attempts: $($_.Exception.Message)" }
        Write-Warn "download attempt $attempt failed; retrying in 5s"
        Start-Sleep -Seconds 5
    }
}

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

    # ------------------------------------------------------------ atomic swap
    $stage = "$InstallDir.new"
    $prev  = "$InstallDir.prev"
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    Write-Log "Extracting to $stage"
    Expand-Archive -LiteralPath $tmpZip -DestinationPath $stage -Force

    if (Test-Path -LiteralPath $InstallDir) {
        if (Test-Path -LiteralPath $prev) { Remove-Item -LiteralPath $prev -Recurse -Force }
        Move-Item -LiteralPath $InstallDir -Destination $prev
        Write-Log "Previous installation kept at $prev"
    }
    Move-Item -LiteralPath $stage -Destination $InstallDir

    # keep the archive and a record of what was installed
    Copy-Item -LiteralPath $tmpZip -Destination (Join-Path $InstallDir $Archive) -Force
    $hash = (Get-FileHash -LiteralPath $tmpZip -Algorithm SHA256).Hash.ToLower()
    $rev  = Get-InstalledRevision -Root $InstallDir
    [pscustomobject]@{
        revision  = $(if ($rev) { $rev } else { 'unknown' })
        file      = $Archive
        url       = $Url
        sha256    = $hash
        installed = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        installed_by = 'install-windows.ps1'
    } | ConvertTo-Json -Compress | Set-Content -LiteralPath (Join-Path $InstallDir 'install-record.json') -Encoding ASCII
}
finally {
    if ($job -and $job.JobState -eq 'Transferred') { Complete-BitsTransfer -BitsJob $job }
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

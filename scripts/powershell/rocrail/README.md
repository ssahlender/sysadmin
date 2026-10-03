# Rocrail on Windows — client only

Windows runs the **Rocview GUI as a client**. The script installs no service, no autostart and no
local workspace: Rocview attaches to an existing Rocrail server.

The download is a BITS transfer, as in the previous updater.

## Usage

```powershell
.\install-windows.ps1                    # install or update
.\install-windows.ps1 -Check             # report only: 0 up to date, 1 update, 2 not installed
.\install-windows.ps1 -DryRun            # show what would happen
.\install-windows.ps1 -Uninstall         # remove the install and the shortcut
```

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `-InstallDir` | `C:\data\rocrail` | where to install |
| `-Arch` | `auto` | `x64`, `arm64` or `win32` |
| `-Workspace` | *(none)* | create an empty workspace — only useful if this machine ever hosts a layout |
| `-NoShortcut` | off | skip creating the Start-Menu shortcut |
| `-Check` | | report installed vs available, change nothing |
| `-Uninstall` | | remove the installation |

Install and update are the same command. The script stops `rocrail`/`rocview` if they are
running, downloads via BITS (three attempts), extracts into a staging directory, keeps the
previous installation as `<InstallDir>.prev` and recreates the shortcut. A record of what was
installed (revision, URL, SHA-256, timestamp) is written to `install-record.json` next to it.

`-Uninstall` removes the installation directory and the shortcut. **Workspaces, plans,
`rocrail.ini` and `lic.dat` are never touched.**

## The shortcut does not start a local server

The vendor's own `desktoplink.cmd` creates a shortcut with `-sp <dir>\bin -dp <dir>\demo`. `-sp`
is the **server** path, so that shortcut starts a local Rocrail server and opens the demo
workspace — the opposite of what a client machine wants.

This script therefore creates the shortcut **without** `-sp`/`-dp`, so it starts Rocview plain.
Rocview then waits in its own window and you attach with:

**Datei/File → "Verbinden mit…"** → server address, port 8051.

The zip still contains `rocrail.exe` and the vendor's `-installservice` / `-deleteservice`
options for running the *server* as a Windows service. This script deliberately does not use
them; a layout host belongs on Linux here.

## Notes

- PowerShell 5.1 and later. Parsed and exercised on 5.1.
- The first launch may raise a Windows Defender / SmartScreen warning (`More info` → `Run
  anyway`): the binaries are not code-signed.
- `rocview` writing to `%TEMP%` and to the workspace is normal.
- If a layout is ever hosted on this machine, `-Workspace <name>` creates the directory skeleton,
  but the server itself creates the content on first start.

## Superseded script

`update-rocrail.ps1` (download + extract only, x64 hardcoded, no error handling) is kept for
history. `install-windows.ps1` covers it and adds architecture selection, staging, rollback of
the previous install, checks and uninstall.

# Rocrail — install and update scripts

Rocrail is split by role here, and the scripts follow that split:

| Role | Platform | What gets installed |
|------|----------|---------------------|
| **Server** | Linux | `rocrail` server + a systemd unit |
| **Client** | Windows | `Rocview` GUI only — attaches to a server |
| **Client** | macOS | `Rocview.app` only — attaches to a server |

The snapshot ships **native executables for all three platforms — no Java runtime is installed
or required**, on the server or the client.

A client never starts a server: no service, no autostart, no local workspace. You point Rocview
at an existing server and it connects.

## Scripts

| Script | Purpose |
|--------|---------|
| [`install-linux.sh`](install-linux.sh) | Install or update the **server** on Linux; generates the systemd unit |
| [`rocweb.sh`](rocweb.sh) | Enable/disable/status the **Rocweb browser client** for a workspace |
| [`install-macos.sh`](install-macos.sh) | Install or update the **client** on macOS |
| [`legacy/install-legacy.sh`](legacy/install-legacy.sh) | The original combined Linux+macOS script, kept for history — see *Migration* |
| [`../../powershell/rocrail/install-windows.ps1`](../../powershell/rocrail/install-windows.ps1) | Install, update, check or remove the **client** on Windows |

Every script is idempotent: **re-running it is the update path.** Nothing needs to be uninstalled
first.

## Server (Linux)

```bash
sudo ./install-linux.sh --workspace balkon --port 8051
```

Useful flags:

| Flag | Meaning |
|------|---------|
| `--workspace NAME` | workspace name (default `rocrail`) |
| `--workspace-dir DIR` | parent directory for workspaces (default `/var/lib/rocrail`) |
| `--port N` | client port Rocview connects to (default `8051`) |
| `--prefix DIR` | install prefix (default `/opt/rocrail`) |
| `--user NAME` | service account, created if missing |
| `--variant V` | x86_64 build: `auto`, `debian11`, `ubuntu24` |
| `--console` | start with `-console`: clients can no longer shut the server down |
| `--check` | report installed vs available, change nothing |
| `--rollback` | restore the previous build |
| `--dry-run` | print the unit that would be written, change nothing |

`--check` exits `0` when up to date, `1` when an update is available, `2` when not installed, so
it can be used directly as a monitoring probe.

### Where things live

```
/opt/rocrail                 the build (replaced on update; previous kept as /opt/rocrail.prev)
/var/lib/rocrail/<name>      the workspace: rocrail.ini, plan.xml, occ.xml, trace/, issues/
/etc/systemd/system/rocrail.service
```

**The workspace is deliberately outside the install prefix.** Replacing the build therefore never
touches a layout. This matters because the vendor archive ships a default `rocrail.ini` and
`plan.xml` — if a workspace ever sat inside the prefix, updating the build would overlay the live
configuration with those defaults. Keeping the two apart removes the hazard entirely.

### The server licence (Support Key)

Rocrail Basic is free; a support key only unlocks Pro extras. Per the official documentation,
`lic.dat` belongs in the server's **working directory — i.e. the workspace** (the `-lic` option
can point somewhere else instead). Since the workspace is never replaced by an update, the
licence survives updates. A copy left in the prefix is carried across an update as well, and
anything else in the prefix that the new build does not contain is reported rather than dropped.

### Ports

| Port | Service |
|------|---------|
| 8051 | client protocol — this is what Rocview connects to |
| 8008 | Server-Monitor web panel |
| 8088 | Rocweb, if enabled (must differ from 8008) |

The **Server-Monitor on 8008 is always on** and shows trace, issues, restart/shutdown and the
Update/OS-Update buttons.

> Do **not** use the Server-Monitor's Update / OS Update buttons. They call `update.sh` /
> `sysupdate.sh` inside the install prefix, which is root-owned, so they fail. `install-linux.sh`
> is the supported update path.

### Stop or remove

```bash
systemctl stop rocrail
systemctl disable --now rocrail      # stop and stop starting at boot
```

Nothing is removed by the scripts; the prefix, unit and workspaces stay where you put them.

## Rocweb — driving the layout from a browser

The Server-Monitor on 8008 is an *operator panel*, not a layout client. To actually **drive the
layout in a browser** you want **Rocweb**, which is a separate service on its own port.

Rocweb is a per-workspace setting inside `rocrail.ini`, and the server does not create that file
until its first start — which is why it is a helper script and not an installer flag. The same
helper therefore works on any server, a Raspberry Pi or a container, with no per-machine variant:

```bash
sudo ./rocweb.sh enable                 # workspace and prefix are read from the systemd unit
sudo ./rocweb.sh status
sudo ./rocweb.sh disable
```

| Flag | Meaning |
|------|---------|
| `--workspace DIR` | workspace to edit (default: the `-w` path from the unit) |
| `--port N` | Rocweb port, must differ from 8008 (default `8088`) |
| `--webpath DIR` | Rocweb assets (default `<prefix>/web`) |
| `--unit-path FILE` | unit to read/restart |

It stops the service, edits `rocrail.ini`, starts it again, then **verifies the port really
answers** before reporting success. Each edit keeps a timestamped copy of the previous
`rocrail.ini`; nothing is deleted, and re-running the same command updates the port instead of
adding a second entry.

**Rocweb is a supporter feature:** without a valid support key it runs for 5 minutes of demo time
per server start.

If the workspace is synced (for example by Resilio), enabling Rocweb rides along with
`rocrail.ini` to every machine that syncs it — including a Windows Rocview workspace.

## Client (macOS)

```bash
./install-macos.sh                  # /Applications
./install-macos.sh --user-apps      # ~/Applications, no administrator rights needed
./install-macos.sh --portable DIR   # just extract, no app bundle
./install-macos.sh --check
./install-macos.sh --uninstall
```

The app is not notarised, so macOS quarantines a downloaded bundle and blocks the first normal
double-click. The script clears the quarantine attribute (which is what makes the first launch
work) and then verifies the signature, reporting what it finds. If macOS still objects, the
vendor's documented fallback is a one-time right-click → **Open**.

`ditto` is used rather than `unzip`, because `unzip` can break the code signature of an app
bundle.

To attach to a server: open Rocview, then **File → "Verbinden mit…"** and enter the server
address with port 8051.

## Client (Windows)

```powershell
.\install-windows.ps1
.\install-windows.ps1 -Check
.\install-windows.ps1 -Workspace balkon     # only if this machine ever hosts a layout
.\install-windows.ps1 -Uninstall
```

Install, update, check and uninstall are one script. It stops `rocrail`/`rocview` if running,
downloads via BITS, extracts into a staging directory, keeps the previous install as
`C:\data\rocrail.prev` and recreates the shortcut.

The shortcut deliberately **omits** the vendor's `-sp`/`-dp` switches. Those pass the server
binary path and would start a **local server** with the demo workspace — the opposite of the
client role. The shortcut starts Rocview plain.

See [`../../powershell/rocrail/README.md`](../../powershell/rocrail/README.md).

## Download matrix

Platforms are published at different times, so the newest revision available for *your* platform
can lag the newest overall. `--check` reports both.

| Platform | Arch | Archive |
|----------|------|---------|
| Linux | aarch64/arm64 | `Debian/Rocrail-debian13-ARM64.zip` |
| Linux | x86_64 | `Debian/Rocrail-debian11-i64.zip`, `Debian/Rocrail-ubuntu24-i64.zip` |
| macOS | arm64 | `macOS/Rocrail-macOS27.app.zip` |
| macOS | x86_64 | `macOS/Rocrail-sequoia-i64.app.zip` |
| Windows | x64 | `Rocrail-Windows-WIN64.zip` |
| Windows | arm64 | `Rocrail-Windows-WINARM64.zip` |
| Windows | win32 | `Rocrail-Windows-WIN32.zip` |

Version list: <https://www.rocrail.online/rocrail-snapshot/log.txt> (newest first). The host
redirects to `www.rocrail-wiki.net`, so redirects must be followed.

## Migration from the old `install.sh`

The original script set out to cover Linux and macOS in one file. Its macOS half is **broken**:
it still asks for `Rocrail-tahoe-M.app.zip`, which is no longer published (404). It also wrote a
systemd unit with no `-w`, leaving the workspace inside the install prefix, and started the
client `Rocview.app` without clearing quarantine.

The original is kept in [`legacy/`](legacy/) with those bugs fixed, so it still works, but the
per-platform scripts above are the supported path. To migrate, just run the script for your
platform — it installs alongside the old one and re-running it becomes the update path. If you
already run the server, pass `--workspace-dir` pointing at your existing workspace parent
directory and it will be adopted, not replaced.

## What has been verified

See [REVIEW.md](REVIEW.md) for what was measured against a real install, what was falsified, and
what remains untested — including the download-artifact caveats.

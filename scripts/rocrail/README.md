# Rocrail Install

Run `./install.sh` — the script detects your OS/arch and downloads the right build.

**Linux**: re-execs itself with `sudo` automatically (needs root for `/opt/rocrail` and systemd).
**macOS**: runs as normal user, extracts to `~/data/rocrail`.

| Platform | Arch | File | Dest |
|----------|------|------|------|
| macOS | arm64 | `Rocrail-tahoe-M.app.zip` | `~/data/rocrail` |
| Linux | aarch64/arm64 | `Rocrail-debian13-ARM64.zip` | `/opt/rocrail` |
| Linux | x86_64 | `Rocrail-debian11-i64.zip` | `/opt/rocrail` |

## Linux setup (first time)

The script creates a systemd unit at `/etc/systemd/system/rocrail.service` with defaults.
**Edit it** before starting — at minimum set your workspace and port:

```
ExecStart=/opt/rocrail/bin/rocrail -w /data/rocrail-workspaces/<name> -l /opt/rocrail/bin -p 8051
User=<your user>
Group=<your group>
WorkingDirectory=<your workspace>
```

Then:

```
systemctl daemon-reload
systemctl start rocrail
```

## Update

Just run `install.sh` again — it stops the service, extracts the new build, and restarts.

## macOS

The `.app` bundle is extracted to `~/data/rocrail/Rocrail.app`. Launch it from Finder or:

```
open ~/data/rocrail/Rocrail.app
```

No systemd involved.

## License

Put the lic.dat in the base dir

- Linux: ```/opt/rocail/lic.dat```
- macOS: ```~/data/rocrail.lic.dat```

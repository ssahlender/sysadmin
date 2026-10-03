# What has been verified, and what has not

This file records the evidence behind the scripts in this directory, so the claims in the READMEs
can be checked rather than trusted. It deliberately contains no site-specific information.

Verified against the builds published on **2026-10-03**. Revisions are per-platform and change
with every snapshot, so none is pinned. Each platform is identified from its own artifact: the
archive's `revision.info` on Linux and Windows, the bundle's `Info.plist`
(`CFBundleShortVersionString`) on macOS. As checked on that date, `debian11-i64`,
`debian13-ARM64` and `Windows-WIN64` all reported **7454**, `Windows-WIN32` reported **7400**,
and the macOS build reported **26.10.3-7458**. The spread inside a single platform is why a
pinned number is misleading.

## Measured, on a real install

| Claim | How it was checked | Result |
|-------|--------------------|--------|
| Where each platform's revision comes from | `revision.info` in the Linux/Windows archives; `Info.plist` in the macOS bundle | Linux/Windows: `Revision: <n> (<arch>, <os>)`; macOS: `26.10.3-<n>` -> `7458`. No platform needs the feed's history files to identify its build |
| No Java anywhere | `file` + `ldd` on the Linux binary; archive listings for Windows and macOS | Native ELF / PE / Mach-O, no `.jar` in any artifact |
| Linux binary dependencies | `ldd` | `libm`, `libc` only — plus ~70 native `.so` driver modules |
| Server runs headless | Started `rocrail -w <ws> -l <bin> -p <port>` | Runs; creates the workspace on first start |
| `-console` is safe unattended | Started with `-console` and stdin `/dev/null` | Survives; SIGTERM exits cleanly with 0 |
| Exit code 70 and systemd | `systemd-run --property=Restart=on-failure` around `exit 70` | **NRestarts=3** — it DOES restart, which is why the generated unit adds `SuccessExitStatus=70` |
| Server-Monitor port | HTTP GET on the live server | `200`, `<title>Rocrail HTTP Service</title>` on **8008** |
| Rocweb is a separate service | Inserted `<http><webclient port="8088" .../></http>`, restarted | `200`, `<title>Rocrail WEB Client</title>` on **8088**, while 8008 stayed up |
| The Rocweb element survives | Insert → start → clean stop → re-read, twice | Element still present; Rocrail kept its own `rocrail.ini.bak` |
| Rocview is a client | `rocview -h 127.0.0.1 -p <port>` against a throwaway server | ESTABLISHED TCP connection; a bare `rocview` instead fails on `localhost:8051` |
| What the vendor archives actually ship | `unzip -Z1` on the published archives | Root entries only: `desktoplink.sh readme.txt revision.info rocrail.png rocrail.sh start.html startrocrail.sh sysupdate.sh update.sh` (Debian/i64) and `desktoplink.cmd readme.txt revision.info rocview.cmd start.html` (Windows). **No `rocrail.ini`, no `plan.xml`, no `occ.xml`** - `plan.xml` exists only under `demo/` and `wikidemo/`. An earlier draft of this file claimed otherwise: those three files had been created by a Rocrail run inside the extraction directory, not shipped by the vendor. |
| `--check` on a live outdated install | Ran against a real install one snapshot behind | Correct report, exit **1** |
| `--check` where nothing is installed | Ran on a clean host | Exit **2** |
| `rocweb.sh` idempotency | `enable` twice with different ports against a real unit | Second run **updated** the port; exactly one `<webclient>` element in the file |
| `rocweb.sh disable` | Enable, then disable | Port set to `0`, Rocweb stops answering, Server-Monitor unaffected |
| `install-windows.ps1` syntax | `Parser::ParseFile` on Windows, PowerShell 5.1 | Parse OK |
| `install-windows.ps1 -Check` / `-DryRun` | Run on a real Windows host | Reported the archive's `Last-Modified`, `NOT INSTALLED`, exit 2; dry run clean |

## Claimed corrections — the operator was right, the earlier draft was wrong

- **"I don't want hardcoded revisions."** Correct. Revisions had been pinned in comments as
  though verified, and the macOS one had in fact been inferred from the feed's history file names
  rather than read from the artifact - the macOS archive has no `revision.info`. The number
  happens to be right (**7458**, now read properly from the bundle's `Info.plist`), but nothing
  is pinned any more, and the platform that supposedly could not report a revision now reports
  and compares one like the other two.

- **"The update never contains the layout."** Correct. The first draft of this work asserted that
  an in-place update would overwrite a live configuration, reasoning from the vendor archive
  containing a default `rocrail.ini`. That is only true if the workspace lives *inside* the
  install prefix. The live server passes `-w <workspace>` with the workspace **outside** the
  prefix, so an update never touches it. The design keeps that separation on purpose and the
  READMEs now state it correctly.
- **Exit code 70.** An earlier draft claimed systemd treats 70 as a clean exit and would leave the
  unit down. Measured: it restarts. The unit design was changed accordingly
  (`Restart=on-failure` **+** `SuccessExitStatus=70`).
- **Port 8008.** An earlier draft called it Rocweb. It is the Server-Monitor. Rocweb is a separate
  `webclient` service on its own port, disabled by default.
- **`lic.dat` location.** The previous README said the "base dir" (the install prefix). The
  official documentation says the server's **working directory** — the workspace — with `-lic` as
  an explicit-path alternative. The script also carries a prefix copy across an update rather than
  dropping it.

## Falsified bug candidate (a defect that turned out not to exist)

The vendor's `desktoplink.cmd` passes `-sp <dir>\bin -dp <dir>\demo` to the Windows shortcut. It
looked like the demo workspace trick would open a *second* listener on 8051. Running
`rocview -sp <bin> -dp <demo>` and watching the ports showed **no listener** on 8051 or 8008 — so
it does not open a server port in that configuration. The reason to avoid `-sp`/`-dp` in a client
shortcut is therefore the vendor's own intent (it points the GUI at a local binary and the demo
workspace), not a port conflict.

## Not verified

- A **real client-issued shutdown** from the GUI or browser (needs an interactive client). The
  `SuccessExitStatus=70` design is reasoned from the exit-code measurement above, not from an
  end-to-end GUI shutdown.
- The Windows and macOS client **installers** were not run end to end here — their syntax and
  read-only paths were exercised, but not a full download-and-install on those platforms.
- Rocweb's documented **5-minute demo limit** without a support key was not re-tested.
- R2RNet server auto-discovery: enabling it and sniffing multicast **224.0.1.20** for 14 seconds
  produced **0 announcements**, so automatic discovery is not claimed anywhere. Entering the host
  and port is the verified path.
- The server on a layout: neither this repository's scripts nor the checks above ran against a
  command station, only against a server with no hardware attached.

## Archive-format caveats

- The snapshot host **301-redirects** to `www.rocrail-wiki.net`; downloads must follow redirects.
- Platforms are published at **different times**, so the newest revision for one platform can lag
  the newest overall. `--check` reports both the revision list and the archive's own
  `Last-Modified` for this reason.
- The upstream wiki is **stale in places**: it documents `rocview.sh` and `initdefault.sh` in the
  ZIP layout, which the current Linux archive does not contain, and it places Rocweb assets under
  `Contents/rocdata/web` on macOS, while the current app ships `Contents/Resources/web/`.
  Behaviour here was taken from the artifacts, not from the wiki's diagrams.

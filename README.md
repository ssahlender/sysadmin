# sysadmin

One file per platform — tools, install commands, config snippets.

| File | Platform |
|------|----------|
| [mac.md](mac.md) | macOS |
| [linux.md](linux.md) | Linux (brew-first) |
| [windows.md](windows.md) | Windows (winget) |
| [tools.yaml](tools.yaml) | Machine-readable source of truth |

## Scripts

Tools only. Host-specific installers and updaters (Rocrail, machine-specific prep) live in the
private infrastructure repo and are deliberately **not** mirrored here.

## Adding a tool

1. Add to [tools.yaml](tools.yaml)
2. Add to the relevant `mac.md` / `linux.md` / `windows.md`
3. 🧠 = suggested by deepseek

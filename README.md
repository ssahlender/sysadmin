# sysadmin

One file per platform — tools, install commands, config snippets.

| File | Platform |
|------|----------|
| [mac.md](mac.md) | macOS |
| [linux.md](linux.md) | Linux (brew-first) |
| [windows.md](windows.md) | Windows (winget) |
| [tools.yaml](tools.yaml) | Machine-readable source of truth |

## Scripts

| Path | Purpose |
|------|---------|
| [scripts/shell/rocrail/](scripts/shell/rocrail/) | Rocrail — Linux server installer, Rocweb helper, macOS client, docs |
| [scripts/powershell/rocrail/](scripts/powershell/rocrail/) | Rocrail — Windows client installer |

## Adding a tool

1. Add to [tools.yaml](tools.yaml)
2. Add to the relevant `mac.md` / `linux.md` / `windows.md`
3. 🧠 = suggested by deepseek

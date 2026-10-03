# AGENTS

Repo for sysadmin tooling — cross-platform software lists, install scripts, and config.

## Structure

```
tools.yaml         ← source of truth (machine-readable)
mac.md             ← human-readable: install commands + config snippets for macOS
linux.md           ← human-readable: same for Linux
windows.md         ← human-readable: same for Windows
scripts/           ← standalone install/update scripts
incoming/          ← tools to evaluate, not yet added to lists
```

## Workflow: adding a tool

1. Add entry to `tools.yaml` with `name`, `desc`, `cat`, `sub`, `link`, `mac`, `linux`, `windows` fields
2. Add the tool to the correct category section in `mac.md`, `linux.md`, `windows.md`
3. Mark new suggestions with 🧠

## YAML schema

```yaml
- name: tool-name           # brew/cask/winget package name
  desc: one-line description
  cat: cli | gui | ai | font | lang
  sub: core | shell | devops | extra | git | editor | terminal | mac-utils | productivity | browser | file-manager | vm | runtime | agent
  link: https://...         # project homepage
  mac: brew install ...     # install command (or "(App Store only)" / "(direct download)")
  linux: brew install ...   # install command (or apt/flatpak/AppImage if no brew formula)
  windows: winget install ... # install command (or "(WSL only)" if not native)
  alt: tool-name            # alternative if this tool doesn't fit
  note: 🧠                  # mark deepseek suggestions
```

## Platform rules

- **macOS:** `brew install` for CLI, `brew install --cask` for GUI. `--cask` doesn't exist on Linux.
- **Linux:** `brew install` for everything that has a formula. `apt` only where brew has no formula (libreoffice, firefox, pinentry-curses, doublecmd-gtk, wireguard-tools). GUI apps use AppImage/flatpak/deb.
- **Windows:** `winget install` for everything. Tools only available in WSL noted as `(WSL only)`.

## Rocrail scripts

`scripts/shell/rocrail/` — Linux **server** installer, the `rocweb.sh` browser-client helper,
the macOS **client** installer, and `REVIEW.md` (what was measured vs assumed).
`scripts/powershell/rocrail/` — Windows **client** installer.

Role split: Linux runs the server, Windows and macOS are clients that attach to one. Every script
is idempotent — re-running is the update path. `shell/rocrail/legacy/install-legacy.sh` is the
original combined script, kept for history with its broken macOS URL fixed.

## Git policy

- No force push to main
- No amending pushed commits
- Don't commit `.env`, credentials, or secrets

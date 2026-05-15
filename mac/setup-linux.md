# Linux & WSL2 Compatibility

> Most CLI and DevOps tools in this guide are fully cross-platform. GUI apps are mostly macOS-only, but many have Linux-native versions or good alternatives.

## Works on Linux/WSL2 — identical or near-identical

All of these install via `apt`, `brew` (Linuxbrew), or direct binary on Linux:

| Category | Tools |
|----------|-------|
| Core CLI | `git` `gh` `wget` `curl` `jq` `yq` `tree` `htop` `btop` `tmux` `fzf` `ripgrep` `fd` `bat` `eza` `zoxide` `fastfetch` |
| Shell | `starship` `zsh-autosuggestions` `zsh-syntax-highlighting` `lazygit` `mise` |
| DevOps CLI | `kubectl` `helm` `k9s` `opentofu` `ansible` `awscli` `azure-cli` `google-cloud-sdk` (`terraform` via `hashicorp/tap`) |
| Local clusters | `kind` `minikube` `tilt` |
| Secrets | `age` `sops` `gnupg` `mosh` `direnv` |
| AI agents | `ollama` `claude-code` `codex` `opencode` `aider` `claude-squad` `gemini-cli` |
| Browsers | Chrome, Firefox, Edge, Brave |
| Office / comms | LibreOffice, Obsidian, Notion, Slack, Zoom, Signal, Bitwarden, 1Password, Resilio Sync |
| VPN | `wireguard-tools` (`brew install wireguard-tools` or `apt install wireguard`) |

## Available on Linux — different install or minor differences

| Tool | Linux/WSL2 notes |
|------|-----------------|
| [VS Code](https://code.visualstudio.com) | Native `.deb`/`.rpm` — or use the **Remote WSL** extension from Windows to work inside WSL |
| [Ghostty](https://ghostty.org) | Native Linux binary available |
| [Bruno](https://www.usebruno.com) | AppImage / `.deb` available |
| [DBeaver](https://dbeaver.io) | `.deb` / `.rpm` / flatpak available |
| [LM Studio](https://lmstudio.ai) | Linux beta available |
| [Lens](https://k8slens.dev) | Native Linux version available |
| `pinentry-mac` | Replace with `pinentry-curses` or `pinentry-gtk2` on Linux |

## macOS only — Linux alternatives

| macOS tool | What to use instead on Linux/WSL2 |
|------------|-----------------------------------|
| [iTerm2](https://iterm2.com) | [Ghostty](https://ghostty.org), [Alacritty](https://alacritty.org), or your distro's default |
| [Raycast](https://www.raycast.com) | [Ulauncher](https://ulauncher.io) or [Albert](https://albertlauncher.github.io) |
| [Rectangle](https://rectangleapp.com) | [i3](https://i3wm.org) / [Sway](https://swaywm.org) tiling WM, or KWin scripts |
| [OrbStack](https://orbstack.dev) | Docker Engine natively — no wrapper needed on Linux |
| [Proxyman](https://proxyman.io) | [mitmproxy](https://mitmproxy.org) — run `mitmweb` for browser UI or `mitmproxy` for terminal UI |
| Parallels / UTM / VMware Fusion | Not needed — use [KVM/QEMU](https://www.linux-kvm.org) if you need VMs |
| [PDF Expert](https://pdfexpert.com) | [Okular](https://okular.kde.org) or [Evince](https://wiki.gnome.org/Apps/Evince) |
| [Adobe Acrobat Reader](https://get.adobe.com/reader/) | Okular or Evince |
| Hidden Bar / Thaw | Not applicable — no macOS menu bar on Linux |
| AppCleaner / Pearcleaner | Not applicable — package managers handle cleanup |
| KnockKnock | [rkhunter](https://rkhunter.sourceforge.net) or [chkrootkit](http://www.chkrootkit.org) |
| SnippetsLab / Latest / Stim / DockDoor | macOS-only, no direct equivalent |

> **WSL2 tip:** GUI apps (VS Code, Bruno, DBeaver, etc.) work in WSL2 via **WSLg** — available from Windows 11 and Windows 10 21H2+. Run them directly from the WSL terminal and they appear as normal Windows windows.

> **Nerd Fonts on Windows/WSL2:** See [Core Tools — Nerd Fonts Setup](setup-core.md#3-nerd-fonts-setup) for winget install commands and Windows Terminal configuration.

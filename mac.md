# macOS — Tools & Config

> Derived from [tools.yaml](tools.yaml). 🧠 = deepseek suggestion.

## Order

1. Homebrew + Xcode CLI → then everything below
2. Terminal + Editor + Font
3. Git + SSH
4. DevOps + Containers
5. Languages (Python, Node)
6. AI Agents + Ollama
7. Office + Browsers + extras
8. Windows VM (if needed)

---

## 1. Prerequisites

```bash
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**Brewfile — reproducible setup:** After installing all your tools, save them to a Brewfile. On the next Mac, restore everything with one command:

```bash
# Save current state (run after you've installed everything)
brew bundle dump --file=~/Brewfile

# Restore on a new Mac
brew bundle --file=~/Brewfile
```

Keep your Brewfile in a private git repo or alongside your dotfiles.

---

## 2. Terminal + Editor + Font

```bash
brew install --cask visual-studio-code iterm2 ghostty
brew install --cask sublime-text font-jetbrains-mono-nerd-font
```

**Font config:**

iTerm2 → `Preferences → Profiles → Text → Font` → JetBrainsMono Nerd Font Mono

VS Code → `settings.json`: `"terminal.integrated.fontFamily": "JetBrainsMono Nerd Font Mono"`

Ghostty → `~/.config/ghostty/config`: `font-family = JetBrainsMono Nerd Font Mono`

---

## 3. CLI Core

```bash
brew install git gh wget curl jq yq tree htop btop tmux fzf ripgrep fd bat eza zoxide fastfetch
brew install ffmpeg imagemagick sevenzip
```

**Git + SSH config:**

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.editor "code --wait"
gh auth login
```

```bash
ssh-keygen -t ed25519 -C "you@example.com"
eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_ed25519
```

---

## 4. Shell

```bash
brew install starship zsh-autosuggestions zsh-syntax-highlighting lazygit mise direnv
brew install atuin chezmoi   # 🧠
```

**`~/.zshrc`:**

```bash
eval "$(starship init zsh)"
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
eval "$(zoxide init zsh)"
eval "$(atuin init zsh)"              # 🧠
```

---

## 5. Git Multi-Repo

```bash
brew install alajmo/mani/mani
pipx install gita
```

---

## 6. DevOps CLI

```bash
brew install kubectl helm k9s kubectx stern opentofu ansible \
  awscli azure-cli google-cloud-sdk \
  age sops gnupg pinentry-mac mosh \
  kind minikube tilt \
  trivy kustomize mitmproxy
```

```bash
# Terraform via HashiCorp tap (or use OpenTofu above)
brew tap hashicorp/tap && brew install hashicorp/tap/terraform
```

| Tool | Purpose |
|------|---------|
| kubectl | Kubernetes CLI |
| helm | K8s package manager |
| k9s | K8s terminal dashboard |
| kubectx 🧠 | Fast context switching |
| stern 🧠 | Multi-pod log tailing |
| opentofu | Open-source Terraform |
| terraform | Infrastructure as code |
| ansible | Server automation over SSH |
| awscli / azure-cli / gcloud | Cloud CLIs |
| age / sops / gnupg | Secret encryption |
| pinentry-mac | macOS GPG password dialog |
| mosh | Resilient SSH |
| kind / minikube | Local K8s clusters |
| tilt | Hot-reload K8s apps |
| trivy 🧠 | Vulnerability scanner |
| kustomize 🧠 | K8s native config |
| mitmproxy | HTTP inspector |

---

## 7. Extra CLI 🧠

```bash
brew install dust duf git-delta sd difftastic tldr hyperfine just watchexec restic yazi
```

| Tool | Replaces |
|------|----------|
| dust | `du` |
| duf | `df` |
| delta | git diff pager |
| sd | `sed` |
| difftastic | `diff` |
| tldr | `man` |
| hyperfine | `time` |
| just | `make` |
| watchexec | `inotifywait` |
| restic | `tar`/rsync backups |
| yazi | `ranger`/`mc` |

---

## 8. Languages

```bash
brew install python uv node pnpm bun pipx
```

---

## 9. AI Agents

```bash
brew install ollama
brew install --cask lm-studio claude-code codex
brew install opencode claude-squad
pipx install aider-chat
npm install -g @google/gemini-cli
```

**Models for 24 GB M4:**

```bash
ollama pull qwen3:14b      # best fit — outperforms 8B on coding
ollama pull llama3.1:8b
ollama pull mistral
```

**VS Code AI extensions:** Continue, Cline, Roo Code, GitHub Copilot.

---

## 10. DevOps GUI

```bash
brew install --cask orbstack bruno dbeaver-community proxyman lens xpipe-io/tap/xpipe
```

> **OrbStack** replaces Docker Desktop — lighter, Apple Silicon native.

| App | Purpose |
|-----|---------|
| orbstack | Docker + Linux VM |
| bruno | API client (offline Postman) |
| dbeaver-community | Universal DB GUI |
| proxyman | HTTP/HTTPS inspector |
| lens 🧠 | K8s IDE dashboard |
| xpipe | SSH/RDP/VNC hub |

---

## 11. Mac Utilities

```bash
brew install --cask raycast rectangle thaw pearcleaner dockdoor knockknock
brew install --cask alttab stats keka alfred
```

| App | Purpose |
|-----|---------|
| raycast | Launcher + AI |
| rectangle | Window snapping |
| thaw | Menu bar manager (replaces Hidden Bar) |
| pearcleaner | App uninstaller (replaces AppCleaner) |
| dockdoor | Dock window previews |
| knockknock | Background process scanner |
| alttab | Windows-style window switcher with thumbnails |
| stats | Menu bar system monitor — CPU, GPU, RAM, disk, network |
| keka | Archive extractor for .rar, .7z, .tar (alt: The Unarchiver) |
| alfred | Classic launcher — alt: Raycast (Raycast is the modern pick) |

**App Store / direct:** SnippetsLab (snippets), Latest (update checker), Stim (keep-awake).

> Thaw over Hidden Bar: Hidden Bar stalled in 2022, buggy on Tahoe. Thaw is actively maintained.  
> Pearcleaner over AppCleaner: sorts by size, Homebrew panel, open source.  
> AltTab replaces macOS Cmd+Tab with proper window previews — open source, free.  
> Stats replaces paid iStat Menus — 38k GitHub stars, 9 monitoring modules.  
> Alfred is the classic launcher; Raycast is the modern alternative with built-in AI + plugins.

---

## 12. Productivity & Office

```bash
brew install --cask microsoft-office libreoffice obsidian notion slack zoom \
  whatsapp signal bitwarden resilio-sync adobe-acrobat-reader pdf-expert vlc
brew install wireguard-tools
```

---

## 13. Browsers

```bash
brew install --cask google-chrome firefox microsoft-edge brave-browser
```

---

## 14. File Managers

```bash
brew install --cask nimble-commander double-commander mucommander
# QSpace Pro — App Store only
```

| App | Style |
|-----|-------|
| nimble-commander | Mac-native dual-pane, free + one-time Pro |
| qspace-pro | Multi-pane (up to 4), ~$15 one-time |
| double-commander | Total Commander clone, free, cross-platform |
| mucommander | Java, free, cross-platform |

---

## 15. Windows VM on Mac

```bash
brew install --cask utm             # free, start here
brew install --cask parallels       # paid, best integration
brew install --cask vmware-fusion   # free personal tier
```

> Start with UTM (free). Upgrade to Parallels ($100/yr) if you need Windows daily. M4 = ARM only — no Boot Camp.

---

## 16. macOS System Tweaks

These settings fix long-standing macOS annoyances. Apply them once, enjoy forever.

### Finder

Open Finder → Settings (Cmd+,):

- General → New Finder windows show → **Home folder** (more useful than "Recents")
- Advanced → Show all filename extensions → **ON**
- Advanced → Show warning before changing an extension → **OFF**
- Advanced → When performing a search → **Search the Current Folder**

In Finder's View menu, enable:

- Show Status Bar
- Show Path Bar
- Show Tab Bar

### Dock

System Settings → Desktop & Dock:

- Size → as small as practical
- Position on screen → **Right** (vertical space > horizontal on widescreen)
- Automatically hide and show the Dock → **ON**

### Trackpad

System Settings → Trackpad → Point & Click:

- Tap to click → **ON**
- Tracking speed → faster than default

System Settings → Trackpad → More Gestures:

- App Exposé → **ON** (three-finger swipe down)
- Mission Control → **ON** (three-finger swipe up)

### Keyboard

System Settings → Keyboard:

- Key repeat rate → **Fast**
- Delay until repeat → **Short**

### Spotlight (optional, skip if using Raycast/Alfred)

System Settings → Spotlight → Search Results → uncheck Siri Suggestions and Bing Web Results.

---

## 17. Mac → Linux Alternatives

| Mac tool | Linux equivalent |
|----------|-----------------|
| iTerm2 | Ghostty or Alacritty |
| Raycast | Ulauncher or Albert |
| Alfred | Ulauncher or Albert |
| Rectangle | i3 / Sway tiling |
| AltTab | built-in (Alt+Tab is native) |
| OrbStack | Native Docker |
| Proxyman | mitmproxy |
| PDF Expert | Okular |
| Keka | File Roller or 7-Zip |
| Stats | btop or conky |
| KnockKnock | rkhunter |
| Parallels/UTM | KVM/QEMU |

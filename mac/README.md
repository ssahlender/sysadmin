# MacBook Air M4 — Complete Setup Guide

> 24 GB RAM · DevOps · AI Agents · Windows  
> Last updated: 13 May 2026

For the AI agents section see [AGENTS.md](AGENTS.md).

## Legend

| Symbol | Meaning |
|--------|---------|
| 🟠 Claude | Suggested by Claude |
| 🤖 ChatGPT | Suggested by ChatGPT |
| ✅ Both | Both agreed independently |
| 📰 Heise | Recommended by [Mac & i](https://www.heise.de/mac-and-i) (Heise), March 2026 |

---

## 1. First Install: Core Mac Tools

✅ Apple command line tools:

```bash
xcode-select --install
```

✅ [Homebrew](https://brew.sh):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

✅ Common CLI tools:

> **Note:** macOS ships with `curl` and (after step above) `git`. These brew versions are newer and replace the system ones. Run `brew install` anyway — it skips tools that are already up to date.

```bash
brew install git gh wget curl jq yq tree htop btop tmux fzf ripgrep fd bat eza zoxide fastfetch
```

| Tool | Description | Source | Link |
|------|-------------|--------|------|
| [git](https://git-scm.com) | Version control — track changes to your code over time | ✅ | https://git-scm.com |
| [gh](https://cli.github.com) | GitHub CLI — create PRs, manage issues, clone repos without leaving the terminal | ✅ | https://cli.github.com |
| [wget](https://www.gnu.org/software/wget/) | Download files from the internet via the terminal | ✅ | https://www.gnu.org/software/wget/ |
| [curl](https://curl.se) | Transfer data to/from URLs — used by almost every script and tool internally | ✅ | https://curl.se |
| [jq](https://jqlang.github.io/jq/) | Parse and filter JSON output — essential for working with APIs and CLI tools | ✅ | https://jqlang.github.io/jq/ |
| [yq](https://github.com/mikefarah/yq) | Same as jq but for YAML — great for Kubernetes manifests and config files | ✅ | https://github.com/mikefarah/yq |
| [tree](https://oldmanprogrammer.net/source.php?dir=projects/tree) | Show directory structure as a visual tree | ✅ | https://mama.indstate.edu/users/ice/tree/ |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder — interactively search through files, history, or any list | ✅ | https://github.com/junegunn/fzf |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | Search file contents blazingly fast — like `grep` but much quicker | ✅ | https://github.com/BurntSushi/ripgrep |
| [fd](https://github.com/sharkdp/fd) | Find files by name fast — simpler syntax than `find` | ✅ | https://github.com/sharkdp/fd |
| [bat](https://github.com/sharkdp/bat) | Like `cat` but with syntax highlighting and line numbers | ✅ | https://github.com/sharkdp/bat |
| [eza](https://github.com/eza-community/eza) | Modern `ls` with colors, icons, and Git status | ✅ | https://github.com/eza-community/eza |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Smarter `cd` — type `z project` to jump to any recent folder | ✅ | https://github.com/ajeetdsouza/zoxide |
| [tmux](https://github.com/tmux/tmux) | Split your terminal into panes and keep sessions running after disconnect | ✅ | https://github.com/tmux/tmux |
| [htop](https://htop.dev) | Interactive process/CPU/memory viewer — like Task Manager for the terminal | ✅ | https://htop.dev |
| [btop](https://github.com/aristocratos/btop) | htop on steroids — beautiful graphs for CPU, memory, network, and disk in one view | ➕ Added | https://github.com/aristocratos/btop |
| [fastfetch](https://github.com/fastfetch-cli/fastfetch) | Shows system info (OS, CPU, RAM, shell) as a pretty banner — great for screenshots | 🟠 Claude | https://github.com/fastfetch-cli/fastfetch |

✅ GUI apps:

```bash
brew install --cask visual-studio-code iterm2 raycast rectangle hiddenbar appcleaner
```

| App | Description | Source | Link |
|-----|-------------|--------|------|
| [VS Code](https://code.visualstudio.com) | Main editor | ✅ | https://code.visualstudio.com |
| [iTerm2](https://iterm2.com) | Better terminal | ✅ | https://iterm2.com |
| [Raycast](https://www.raycast.com) | Launcher + AI + automation | ✅ | https://www.raycast.com |
| [Rectangle](https://rectangleapp.com) | Window snapping | ✅ | https://rectangleapp.com |
| [Hidden Bar](https://github.com/dwarvesf/hidden) | Clean menu bar — consider **[Thaw](https://github.com/stonerl/Thaw)** as upgrade (see §13) | 🤖 ChatGPT | https://github.com/dwarvesf/hidden |
| [AppCleaner](https://freemacsoft.net/appcleaner/) | Clean uninstalls — consider **[Pearcleaner](https://itsalin.com/appInfo/?id=pearcleaner)** as upgrade (see §13) | 🤖 ChatGPT | https://freemacsoft.net/appcleaner/ |
| [Ghostty](https://ghostty.org) | Newer, faster terminal alternative to iTerm2 | 🟠 Claude | https://ghostty.org |

> **🟠 Claude note:** Ghostty is GPU-accelerated, starts faster than iTerm2, and has native macOS feel. Worth trying if you spend a lot of time in the terminal.

---

## 2. Shell Setup

✅ Shell enhancements:

```bash
brew install starship zsh-autosuggestions zsh-syntax-highlighting
```

Add to `~/.zshrc`:

```bash
eval "$(starship init zsh)"
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
eval "$(zoxide init zsh)"
```

✅ Nerd Font (required for Starship icons):

```bash
brew install --cask font-jetbrains-mono-nerd-font
```

> After installing the font you must configure your terminal to use it — see **Section 3: Nerd Fonts Setup** for step-by-step instructions for iTerm2, VS Code, Ghostty, GNOME Terminal, and Windows Terminal.

🟠 Claude additions:

```bash
brew install lazygit mise
```

| Tool | Description | Source | Link |
|------|-------------|--------|------|
| [Starship](https://starship.rs) | Customizable shell prompt showing Git branch, language versions, and more | ✅ | https://starship.rs |
| [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | Suggests commands as you type based on your history — press → to accept | ✅ | https://github.com/zsh-users/zsh-autosuggestions |
| [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) | Colors valid commands green and typos red before you hit Enter | ✅ | https://github.com/zsh-users/zsh-syntax-highlighting |
| [font-jetbrains-mono-nerd-font](https://github.com/ryanoasis/nerd-fonts) | JetBrains Mono with Nerd Font icons built in — required for Starship to display symbols correctly | ✅ | https://github.com/ryanoasis/nerd-fonts |
| [lazygit](https://github.com/jesseduffield/lazygit) | Visual Git interface in the terminal — stage, commit, branch, rebase with keyboard shortcuts | 🟠 Claude | https://github.com/jesseduffield/lazygit |
| [mise](https://mise.jdx.dev) | One tool to manage Node, Python, Ruby, Go versions per project — replaces nvm + pyenv + rbenv | 🟠 Claude | https://mise.jdx.dev |

> **🟠 Claude note:** `mise` is a single version manager that handles Node, Python, Ruby, Go, and more. ChatGPT's guide used separate `nvm`/`pyenv` — mise replaces all of them with one config file per project.

---

## 3. Nerd Fonts Setup

> Nerd Fonts add thousands of icons (Git symbols, language logos, arrows) to a regular font. Without one, Starship shows broken squares instead of icons. Install the font first, then tell each terminal to use it.

### macOS — Install

```bash
brew install --cask font-jetbrains-mono-nerd-font
```

### macOS — Apply in your terminal

**iTerm2:**
`Preferences (⌘,) → Profiles → Text → Font` → select **JetBrainsMono Nerd Font Mono**

**VS Code integrated terminal:**
Open `settings.json` (`⌘⇧P` → *Open User Settings JSON*) and add:
```json
"terminal.integrated.fontFamily": "JetBrainsMono Nerd Font Mono"
```

**Ghostty:**
Add to `~/.config/ghostty/config`:
```
font-family = JetBrainsMono Nerd Font Mono
```

---

### Debian 12 (GNOME) — Install

Use the official Nerd Fonts install script — handles download, extraction, and font cache automatically:

```bash
curl -fsSL https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/install.sh | bash -s -- JetBrainsMono
```

That's it. Verify it worked:

```bash
fc-list | grep -i jetbrains
```

### Debian 12 — Apply in GNOME Terminal

**Via GUI:**
Open GNOME Terminal → hamburger menu (☰) → **Preferences** → click your profile → **Text** tab → enable **Custom font** → click the font button → search for **JetBrainsMono** → select **JetBrainsMono Nerd Font Mono**

**Via terminal (faster):**
```bash
# Get your default profile UUID
PROFILE=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")

# Apply the font
gsettings set org.gnome.terminal.legacy.profiles:/:${PROFILE}/font 'JetBrainsMono Nerd Font Mono 12'
gsettings set org.gnome.terminal.legacy.profiles:/:${PROFILE}/use-system-font false
```

### Debian 12 — Apply in VS Code integrated terminal

Same as macOS — add to `settings.json` (`Ctrl⇧P` → *Open User Settings JSON*):
```json
"terminal.integrated.fontFamily": "JetBrainsMono Nerd Font Mono"
```

---

### Windows / WSL2 — Install via winget

Run in **PowerShell or CMD** on the Windows side (not inside WSL):

```powershell
# JetBrains Mono — used throughout this guide
winget install -e --id DEVCOM.JetBrainsMonoNerdFont

# FiraCode — popular alternative with ligature support
winget install -e --id DEVCOM.FiraCodeNerdFont
```

Search all available Nerd Fonts:
```powershell
winget search --id DEVCOM --source winget
```

### Windows / WSL2 — Apply in Windows Terminal

**Windows Terminal → Settings (Ctrl,) → your WSL2 profile → Appearance → Font face** → select **JetBrainsMono Nerd Font Mono**

Or edit `settings.json` directly:
```json
"font": {
    "face": "JetBrainsMono Nerd Font Mono",
    "size": 12
}
```

### Windows / WSL2 — Apply in VS Code integrated terminal

```json
"terminal.integrated.fontFamily": "JetBrainsMono Nerd Font Mono"
```

---

> **Symptom if font is missing:** Starship shows `?` boxes or garbled characters. The font install and the terminal config are two separate steps — both are required.

---

## 4. DevOps Stack

✅ Core DevOps CLIs:

```bash
brew install kubectl helm k9s opentofu ansible awscli azure-cli google-cloud-sdk
brew install age sops gnupg pinentry-mac mosh
brew install kind minikube tilt
```

> **Terraform note:** HashiCorp changed their license in 2023 and moved off the standard Homebrew tap. Install via the official tap or use the open-source drop-in replacement **OpenTofu** (already included above):
> ```bash
> # Terraform (official HashiCorp tap)
> brew tap hashicorp/tap
> brew install hashicorp/tap/terraform
>
> # OpenTofu — open-source fork, fully compatible, in standard Homebrew
> brew install opentofu
> ```

### Containers

✅ **OrbStack** over Docker Desktop on Apple Silicon:

```bash
brew install --cask orbstack
```

> [OrbStack](https://orbstack.dev) is lighter, faster, and more Mac-native than Docker Desktop. Both Claude and ChatGPT agreed on this independently.

### API & Database

```bash
brew install --cask bruno dbeaver-community
brew install --cask proxyman          # 🟠 Claude
brew install direnv                   # 🟠 Claude
```

| Tool | Description | Source | Link |
|------|-------------|--------|------|
| [kubectl](https://kubernetes.io/docs/reference/kubectl/) | Command-line tool to deploy and manage apps on Kubernetes clusters | ✅ | https://kubernetes.io/docs/reference/kubectl/ |
| [helm](https://helm.sh) | Package manager for Kubernetes — install complex apps with one command | ✅ | https://helm.sh |
| [k9s](https://k9scli.io) | Terminal dashboard for Kubernetes — browse pods, logs, and resources visually | ✅ | https://k9scli.io |
| [Terraform](https://www.terraform.io) | Define cloud infrastructure as code — provision servers, networks, databases | ✅ | https://www.terraform.io |
| [OpenTofu](https://opentofu.org) | Open-source Terraform fork, fully compatible, community-driven | ✅ | https://opentofu.org |
| [Ansible](https://www.ansible.com) | Automate server configuration and deployments over SSH — no agent required | ✅ | https://www.ansible.com |
| [awscli](https://aws.amazon.com/cli/) | Official CLI for Amazon Web Services — manage S3, EC2, IAM, and more | ✅ | https://aws.amazon.com/cli/ |
| [azure-cli](https://docs.microsoft.com/cli/azure/) | Official CLI for Microsoft Azure | ✅ | https://docs.microsoft.com/cli/azure/ |
| [google-cloud-sdk](https://cloud.google.com/sdk) | Official CLI for Google Cloud Platform (`gcloud`, `gsutil`, `bq`) | ✅ | https://cloud.google.com/sdk |
| [kind](https://kind.sigs.k8s.io) | Run a full Kubernetes cluster locally inside Docker containers — great for testing | ✅ | https://kind.sigs.k8s.io |
| [minikube](https://minikube.sigs.k8s.io) | Alternative local Kubernetes cluster — single-node, easy to start | ✅ | https://minikube.sigs.k8s.io |
| [Tilt](https://tilt.dev) | Hot-reload your app in a local Kubernetes cluster as you save code | ✅ | https://tilt.dev |
| [age](https://github.com/FiloSottile/age) | Simple, modern file encryption — easy to use, hard to get wrong | ✅ | https://github.com/FiloSottile/age |
| [sops](https://github.com/getsops/sops) | Encrypt secrets inside YAML/JSON/ENV files so you can safely commit them to Git | ✅ | https://github.com/getsops/sops |
| [gnupg](https://gnupg.org) | GPG encryption — sign commits, encrypt files, used by sops and package verification | ✅ | https://gnupg.org |
| [pinentry-mac](https://github.com/GPGTools/pinentry) | Native macOS password dialog for GPG — replaces the ugly terminal prompt | ✅ | https://github.com/GPGTools/pinentry |
| [mosh](https://mosh.org) | SSH replacement that stays connected over flaky Wi-Fi or when your laptop sleeps | ✅ | https://mosh.org |
| [OrbStack](https://orbstack.dev) | Lightweight Docker + Linux VM runtime — replaces Docker Desktop on Apple Silicon | ✅ | https://orbstack.dev |
| [Lens](https://k8slens.dev) / [OpenLens](https://github.com/MuhammedKalkan/OpenLens) | GUI dashboard for Kubernetes clusters | 🤖 ChatGPT | https://k8slens.dev |
| [Bruno](https://www.usebruno.com) | Test and explore APIs — like Postman but offline, file-based, and free | ✅ | https://www.usebruno.com |
| [DBeaver](https://dbeaver.io) | Universal database GUI — connects to Postgres, MySQL, SQLite, and dozens more | 🤖 ChatGPT | https://dbeaver.io |
| [Proxyman](https://proxyman.io) | Intercept and inspect HTTP/HTTPS traffic — essential for debugging AI agent calls | 🟠 Claude | https://proxyman.io |
| [direnv](https://direnv.net) | Automatically load/unload environment variables when you `cd` into a project folder | 🟠 Claude | https://direnv.net |

---

## 5. AI Agents & Coding Assistants

See **[AGENTS.md](AGENTS.md)** for the full breakdown, including:
- Local LLM runtimes and model recommendations
- All agent CLI tools with links and attribution
- HTTP debugging with Proxyman
- VS Code AI extensions
- Python AI project quickstart
- Claude vs ChatGPT differences on this topic

Quick install summary:

```bash
brew install ollama claude-squad
brew install --cask claude-code codex lm-studio
brew install opencode
pipx install aider-chat
npm install -g @google/gemini-cli
```

---

## 6. Windows on Mac (M4 = ARM only, no Boot Camp)

| Option | Cost | Best for | Source | Link |
|--------|------|----------|--------|------|
| [Parallels Desktop](https://www.parallels.com) | ~$100/yr | Windows daily use, seamless integration | ✅ | https://www.parallels.com |
| [UTM](https://mac.getutm.app) | Free | Occasional use, more manual setup | ✅ | https://mac.getutm.app |
| [VMware Fusion](https://www.vmware.com/products/fusion.html) | Free (personal) | Middle ground, no subscription | 🟠 Claude | https://www.vmware.com/products/fusion.html |

```bash
brew install --cask utm          # free
brew install --cask parallels    # paid, best integration
brew install --cask vmware-fusion  # free personal tier
```

> ⚠️ All options run **Windows ARM** — not x86. Most modern software works fine via Microsoft's x86 translation layer.

> **🟠 Claude recommendation:** Start with UTM (free). Upgrade to Parallels only if you need Windows daily.  
> **🤖 ChatGPT recommendation:** Parallels if Windows matters for daily work, UTM if occasional. VMware Fusion was not mentioned.

---

## 7. Productivity / Office

```bash
brew install --cask microsoft-office libreoffice obsidian notion slack zoom whatsapp signal
brew install --cask adobe-acrobat-reader pdf-expert
brew install --cask bitwarden resilio-sync
brew install wireguard-tools        # CLI tools; GUI client via App Store (free)
```

| App | Description | Source | Link |
|-----|-------------|--------|------|
| [Microsoft 365](https://www.microsoft.com/microsoft-365/mac) | Word, Excel, PowerPoint, Teams, OneDrive | 🤖 ChatGPT | https://www.microsoft.com/microsoft-365/mac |
| [LibreOffice](https://www.libreoffice.org) | Free Office suite — opens and edits Word/Excel/PowerPoint files | ✅ | https://www.libreoffice.org |
| [Obsidian](https://obsidian.md) | Local-first Markdown note-taking with links between notes | 🤖 ChatGPT | https://obsidian.md |
| [Notion](https://www.notion.so) | All-in-one workspace for notes, wikis, and project tracking | 🤖 ChatGPT | https://www.notion.so |
| [Slack](https://slack.com) | Team messaging and channels | ✅ | https://slack.com |
| [Zoom](https://zoom.us) | Video conferencing | ✅ | https://zoom.us |
| [WhatsApp](https://www.whatsapp.com) | Encrypted messaging — desktop client | ✅ | https://www.whatsapp.com |
| [Signal](https://signal.org) | Encrypted messaging, open source — more private than WhatsApp | ✅ | https://signal.org |
| [Adobe Acrobat Reader](https://get.adobe.com/reader/) | View, comment, and sign PDF files | ✅ | https://get.adobe.com/reader/ |
| [PDF Expert](https://pdfexpert.com) | Edit, annotate, and sign PDFs — more capable than Preview | 🤖 ChatGPT | https://pdfexpert.com |
| [Bitwarden](https://bitwarden.com) | Open-source password manager — free tier covers most needs | 🤖 ChatGPT | https://bitwarden.com |
| [1Password](https://1password.com) | Password manager with SSH key management and developer CLI integration | 🟠 Claude | https://1password.com |
| [Resilio Sync](https://www.resilio.com/) | Peer-to-peer file sync across devices — no cloud middleman, fast on LAN | ➕ Added | https://www.resilio.com/ |
| [WireGuard](https://www.wireguard.com) | Fast, modern VPN — GUI via App Store (free), CLI tools via `brew install wireguard-tools` | ➕ Added | https://www.wireguard.com |

> **🟠 Claude note:** 1Password has better SSH key management and developer integrations than Bitwarden. Either works — pick based on preference.

### File Manager (Finder Replacements) 🟠 Claude

> macOS Finder is the equivalent of Windows Explorer — functional but limited. All options below avoid subscriptions. Verify current pricing before buying as models change.

```bash
# Free / open source
brew install --cask double-commander
brew install --cask mucommander

# Freemium / one-time purchase
brew install --cask nimble-commander   # free tier; Pro via App Store
# QSpace — App Store only (search "QSpace Pro")
```

| App | Pricing | Description | Link |
|-----|---------|-------------|------|
| [Nimble Commander](https://magnumbytes.com) | Free + one-time Pro | Dual-pane, fast, polished — most Mac-native feel of the free options | https://magnumbytes.com |
| [QSpace](https://qspace.awehunt.com) | ~$15 one-time (App Store) | Multi-pane (up to 4), modern UI, cloud/remote/archive support | https://qspace.awehunt.com |
| [Double Commander](https://doublecmd.sourceforge.io) | Free, open source | Total Commander clone — maximum features, UI shows its age | https://doublecmd.sourceforge.io |
| [muCommander](https://www.mucommander.com) | Free, open source | Cross-platform Java app — less Mac-native but solid and free | https://www.mucommander.com |

---

## 8. Browsers

```bash
brew install --cask google-chrome firefox microsoft-edge brave-browser
```

| Browser | Link |
|---------|------|
| [Chrome](https://www.google.com/chrome/) | https://www.google.com/chrome/ |
| [Firefox](https://www.mozilla.org/firefox/) | https://www.mozilla.org/firefox/ |
| [Edge](https://www.microsoft.com/edge) | https://www.microsoft.com/edge |
| [Brave](https://brave.com) | https://brave.com |

✅ All four agreed on all four browsers.

---

## 9. One-Shot Install Script

Run this after Homebrew is set up:

```bash
# CLI tools
brew install git gh wget curl jq yq tree htop btop tmux fzf ripgrep fd bat eza zoxide fastfetch \
  starship zsh-autosuggestions zsh-syntax-highlighting \
  python uv node pnpm bun pipx mise lazygit direnv \
  kubectl helm k9s opentofu ansible awscli azure-cli google-cloud-sdk \
  age sops gnupg pinentry-mac mosh \
  kind minikube tilt ollama opencode claude-squad

# Terraform (needs HashiCorp tap — OpenTofu above is the open-source alternative)
brew tap hashicorp/tap && brew install hashicorp/tap/terraform

# GUI apps
brew install --cask visual-studio-code iterm2 raycast rectangle \
  thaw pearcleaner \            # 📰 Heise: replaces hiddenbar + appcleaner
  orbstack bruno dbeaver-community proxyman \
  knockknock dockdoor \         # 📰 Heise: security scanner + dock window previews
  lm-studio \
  claude-code codex \
  microsoft-office obsidian slack zoom bitwarden resilio-sync wireguard-tools \
  google-chrome firefox microsoft-edge \
  double-commander mucommander nimble-commander \   # 🟠 file managers — QSpace via App Store
  utm

# 📰 Heise: install from App Store or direct download (no Homebrew cask)
# - SnippetsLab: https://apps.apple.com/app/id1006087419
# - Latest:      https://max.codes/latest
# - Stim:        https://widgetworx.com/apps/stim.html

# Nerd Font
brew install --cask font-jetbrains-mono-nerd-font

# Python AI tools
pipx install aider-chat

# Node AI CLIs
npm install -g @google/gemini-cli

# Ollama models (24 GB RAM = run big models)
ollama pull qwen3:14b
ollama pull llama3.1:8b
```

Add Parallels if you need Windows daily:

```bash
brew install --cask parallels
```

---

## 10. Git Setup

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.editor "code --wait"
gh auth login
```

---

## 11. SSH Key Setup

```bash
ssh-keygen -t ed25519 -C "your.email@example.com"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub   # add to GitHub, GitLab, servers
```

---

## 12. Priority Install Order

1. Homebrew + Xcode CLI tools
2. iTerm2 / Ghostty, VS Code, Raycast, Rectangle
3. Git + GitHub CLI setup + SSH key
4. OrbStack + kubectl + k9s + Terraform
5. Python (uv), Node (pnpm/bun), mise
6. Ollama + Claude Code + Codex + OpenCode + Aider
7. Parallels or UTM for Windows
8. Office, Slack, Zoom, PDF tools, password manager

---

## 13. Mac Freeware Additions 📰 Heise Mac & i

> Source: [Völlig kostenlos: 21 Freeware-Perlen für den Mac](https://www.heise.de/-11215455) — Mac & i, Joachim Kläschen, March 2026

### Upgrades to existing tools

#### Hidden Bar → [Thaw](https://github.com/stonerl/Thaw) 📰 Heise

```bash
brew install --cask thaw
```

| | Hidden Bar | Thaw |
|--|-----------|------|
| Last updated | 2022 (stalled) | Active, 2026 |
| macOS 26 Tahoe | Buggy | Optimized |
| Show/hide icons | Yes | Yes |
| Temporary reveal | No | Yes — one click to show hidden icons briefly |
| Styling | None | Change color, spacing, round corners, split bar |
| Search | No | Yes — find menu items by name |
| Language | EN | EN + DE (and more) |
| Base | Original | Fork of [Ice](https://icemenubar.app/) |

> Hidden Bar's last meaningful update was 2022. It has known issues under macOS 26 Tahoe. Thaw is a community fork of Ice (itself a Hidden Bar successor) — fully Tahoe-optimized and actively maintained.

---

#### AppCleaner → [Pearcleaner](https://itsalin.com/appInfo/?id=pearcleaner) 📰 Heise

```bash
brew install --cask pearcleaner
```

| | AppCleaner | Pearcleaner |
|--|-----------|-------------|
| Lists related files | Yes | Yes |
| Sort apps by disk size | No | Yes — find space hogs instantly |
| Granular file selection | Basic | Full — deselect individual files before deleting |
| Sensitivity control | No | Yes — strict / loose matching |
| Homebrew integration | No | Yes — manage and clean Homebrew installs |
| Update checker | No | Yes — checks for its own and other app updates |
| Open source | No | Yes — [GitHub](https://github.com/alienator88/Pearcleaner) |

> Pearcleaner does everything AppCleaner does, plus sorts your apps by size so you can spot space hogs, and has a Homebrew management panel built in — useful since Homebrew doesn't auto-clean old versions.

### Security

| Tool | Description | Link |
|------|-------------|------|
| **[KnockKnock](https://objective-see.org/products/knockknock.html)** | Scans all persistent background processes (startup items, launch agents, Safari extensions) and checks them against VirusTotal | https://objective-see.org/products/knockknock.html |

```bash
brew install --cask knockknock
```

> By Objective-See — the trusted macOS security research org. Essential for a security-aware DevOps setup.

### Productivity / Developer Workflow

| Tool | Description | Install | Link |
|------|-------------|---------|------|
| **[SnippetsLab](https://apps.apple.com/app/id1006087419)** | Code + text snippet manager, syntax highlighting, iCloud sync — great for kubectl one-liners, bash snippets, agent prompts | App Store | https://apps.apple.com/app/id1006087419 |
| **[Latest](https://max.codes/latest)** | Checks updates for all Sparkle-based and App Store apps in one place — complements `brew upgrade` for GUI apps | Direct download | https://max.codes/latest |
| **[Stim](https://widgetworx.com/apps/stim.html)** | Keep-awake utility — can be tied to specific running apps (stay awake while a long agent run or build is active, sleep otherwise) | Direct download | https://widgetworx.com/apps/stim.html |
| **[DockDoor](https://dockdoor.net)** | Window previews on Dock hover + visual Cmd+Tab switcher with thumbnails | `brew install --cask dockdoor` | https://dockdoor.net |

```bash
# Homebrew
brew install --cask dockdoor

# App Store / direct download
# SnippetsLab: https://apps.apple.com/app/id1006087419
# Latest:      https://max.codes/latest
# Stim:        https://widgetworx.com/apps/stim.html
```

> **Note on non-notarized apps:** Thaw, DockDoor, and a few others are not Apple-notarized. If macOS blocks the app on first launch, go to **System Settings → Privacy & Security → Security** and click "Open Anyway".

---

## 14. Linux / WSL2 Compatibility

> Most CLI and DevOps tools in this guide are fully cross-platform. GUI apps are mostly macOS-only, but many have Linux-native versions or good alternatives.

### ✅ Works on Linux/WSL2 — identical or near-identical

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

### ⚡ Available on Linux — different install or minor differences

| Tool | Linux/WSL2 notes |
|------|-----------------|
| [VS Code](https://code.visualstudio.com) | Native `.deb`/`.rpm` — or use the **Remote WSL** extension from Windows to work inside WSL |
| [Ghostty](https://ghostty.org) | Native Linux binary available — excellent terminal choice on Linux too |
| [Bruno](https://www.usebruno.com) | AppImage / `.deb` available |
| [DBeaver](https://dbeaver.io) | `.deb` / `.rpm` / flatpak available |
| [LM Studio](https://lmstudio.ai) | Linux beta available |
| [Lens](https://k8slens.dev) | Native Linux version available |
| `pinentry-mac` | Replace with `pinentry-curses` or `pinentry-gtk2` on Linux |

### ❌ macOS only — Linux alternatives

| macOS tool | What to use instead on Linux/WSL2 |
|------------|-----------------------------------|
| [iTerm2](https://iterm2.com) | [Ghostty](https://ghostty.org), [Alacritty](https://alacritty.org), or your distro's default |
| [Raycast](https://www.raycast.com) | [Ulauncher](https://ulauncher.io) or [Albert](https://albertlauncher.github.io) |
| [Rectangle](https://rectangleapp.com) | [i3](https://i3wm.org) / [Sway](https://swaywm.org) tiling WM, or KWin scripts |
| [OrbStack](https://orbstack.dev) | Docker Engine natively — no wrapper needed on Linux |
| [Proxyman](https://proxyman.io) | [mitmproxy](https://mitmproxy.org) (CLI/web UI, free, open source) |
| Parallels / UTM / VMware Fusion | Not needed — you're already on Linux; use [KVM/QEMU](https://www.linux-kvm.org) if you need VMs |
| [PDF Expert](https://pdfexpert.com) | [Okular](https://okular.kde.org) or [Evince](https://wiki.gnome.org/Apps/Evince) |
| [Adobe Acrobat Reader](https://get.adobe.com/reader/) | Okular, Evince, or `okular` via apt |
| Hidden Bar / Thaw | Not applicable — no macOS menu bar on Linux |
| AppCleaner / Pearcleaner | Not applicable — package managers handle cleanup |
| KnockKnock | [rkhunter](https://rkhunter.sourceforge.net) or [chkrootkit](http://www.chkrootkit.org) |
| SnippetsLab / Latest / Stim / DockDoor | macOS-only, no direct Linux equivalent |

> **WSL2 tip:** GUI apps (VS Code, Bruno, DBeaver, etc.) work in WSL2 via **WSLg** (Windows Subsystem for Linux GUI) — available from Windows 11 and Windows 10 21H2+. Run them directly from the WSL terminal and they appear as normal Windows windows.

> **Nerd Fonts on Windows/WSL2:** See **Section 3** for winget install commands and Windows Terminal configuration.

---

## 15. Claude vs ChatGPT — Full Diff

| Topic | 🤖 ChatGPT | 🟠 Claude |
|-------|-----------|-----------|
| Agent install method | `npm install -g` | **Homebrew casks** — cleaner, managed by `brew upgrade` |
| Containers | OrbStack ✅ | OrbStack ✅ |
| Terminal | iTerm2 | iTerm2 **or [Ghostty](https://ghostty.org)** |
| Version managers | uv + nvm + pyenv (separate) | **[mise](https://mise.jdx.dev)** — replaces all |
| Git UI | — | **[lazygit](https://github.com/jesseduffield/lazygit)** |
| HTTP debugging | — | **[Proxyman](https://proxyman.io)** — key for AI agent calls |
| Per-project env vars | — | **[direnv](https://direnv.net)** |
| Multi-agent terminal | — | **[claude-squad](https://github.com/smtg-ai/claude-squad)** |
| Google agent CLI | — | **[Gemini CLI](https://github.com/google-gemini/gemini-cli)** |
| Windows virtualization | Parallels or UTM | Same + **[VMware Fusion](https://www.vmware.com/products/fusion.html)** as free 3rd option |
| Local LLM model | llama3.1 | **qwen3:14b** — better fit for 24 GB M4 |
| Password manager | Bitwarden | Bitwarden or **[1Password](https://1password.com)** |
| VS Code AI extensions | Continue, Cline, Copilot | Deferred to agent CLIs |
| Kubernetes GUI | Lens / OpenLens | — (k9s TUI is sufficient) |

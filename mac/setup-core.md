# Core Mac Tools

## 1. First Install

Apple command line tools:

```bash
xcode-select --install
```

[Homebrew](https://brew.sh):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Common CLI tools:

> **Note:** macOS ships with `curl` and (after step above) `git`. These brew versions are newer and replace the system ones. Run `brew install` anyway — it skips tools that are already up to date.

```bash
brew install git gh wget curl jq yq tree htop btop tmux fzf ripgrep fd bat eza zoxide fastfetch
```

| Tool | Description | Link |
|------|-------------|------|
| [git](https://git-scm.com) | Version control | https://git-scm.com |
| [gh](https://cli.github.com) | GitHub CLI — create PRs, manage issues, clone repos without leaving the terminal | https://cli.github.com |
| [wget](https://www.gnu.org/software/wget/) | Download files from the internet via the terminal | https://www.gnu.org/software/wget/ |
| [curl](https://curl.se) | Transfer data to/from URLs — used by almost every script and tool internally | https://curl.se |
| [jq](https://jqlang.github.io/jq/) | Parse and filter JSON output — essential for working with APIs and CLI tools | https://jqlang.github.io/jq/ |
| [yq](https://github.com/mikefarah/yq) | Same as jq but for YAML — great for Kubernetes manifests and config files | https://github.com/mikefarah/yq |
| [tree](https://oldmanprogrammer.net/source.php?dir=projects/tree) | Show directory structure as a visual tree | https://mama.indstate.edu/users/ice/tree/ |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder — interactively search through files, history, or any list | https://github.com/junegunn/fzf |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | Search file contents blazingly fast — like `grep` but much quicker | https://github.com/BurntSushi/ripgrep |
| [fd](https://github.com/sharkdp/fd) | Find files by name fast — simpler syntax than `find` | https://github.com/sharkdp/fd |
| [bat](https://github.com/sharkdp/bat) | Like `cat` but with syntax highlighting and line numbers | https://github.com/sharkdp/bat |
| [eza](https://github.com/eza-community/eza) | Modern `ls` with colors, icons, and Git status | https://github.com/eza-community/eza |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Smarter `cd` — type `z project` to jump to any recent folder | https://github.com/ajeetdsouza/zoxide |
| [tmux](https://github.com/tmux/tmux) | Split your terminal into panes and keep sessions running after disconnect | https://github.com/tmux/tmux |
| [htop](https://htop.dev) | Interactive process/CPU/memory viewer | https://htop.dev |
| [btop](https://github.com/aristocratos/btop) | Beautiful graphs for CPU, memory, network, and disk in one view | https://github.com/aristocratos/btop |
| [fastfetch](https://github.com/fastfetch-cli/fastfetch) | Shows system info (OS, CPU, RAM, shell) as a pretty banner | https://github.com/fastfetch-cli/fastfetch |

GUI apps:

```bash
brew install --cask visual-studio-code iterm2 ghostty raycast rectangle hiddenbar appcleaner
```

| App | Description | Link |
|-----|-------------|------|
| [VS Code](https://code.visualstudio.com) | Main editor | https://code.visualstudio.com |
| [iTerm2](https://iterm2.com) | Feature-rich terminal | https://iterm2.com |
| [Ghostty](https://ghostty.org) | GPU-accelerated terminal, starts faster than iTerm2, native macOS feel | https://ghostty.org |
| [Raycast](https://www.raycast.com) | Launcher + AI + automation | https://www.raycast.com |
| [Rectangle](https://rectangleapp.com) | Window snapping | https://rectangleapp.com |
| [Hidden Bar](https://github.com/dwarvesf/hidden) | Clean menu bar — consider **[Thaw](https://github.com/stonerl/Thaw)** as upgrade (see [Mac Freeware](setup-freeware.md)) | https://github.com/dwarvesf/hidden |
| [AppCleaner](https://freemacsoft.net/appcleaner/) | Clean uninstalls — consider **[Pearcleaner](https://itsalin.com/appInfo/?id=pearcleaner)** as upgrade (see [Mac Freeware](setup-freeware.md)) | https://freemacsoft.net/appcleaner/ |

---

## 2. Shell Setup

Shell enhancements:

```bash
brew install starship zsh-autosuggestions zsh-syntax-highlighting lazygit mise
```

Add to `~/.zshrc`:

```bash
eval "$(starship init zsh)"
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
eval "$(zoxide init zsh)"
```

Nerd Font (required for Starship icons):

```bash
brew install --cask font-jetbrains-mono-nerd-font
```

> After installing the font you must configure your terminal to use it — see **Section 3** below.

| Tool | Description | Link |
|------|-------------|------|
| [Starship](https://starship.rs) | Customizable shell prompt showing Git branch, language versions, and more | https://starship.rs |
| [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | Suggests commands as you type based on your history — press → to accept | https://github.com/zsh-users/zsh-autosuggestions |
| [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) | Colors valid commands green and typos red before you hit Enter | https://github.com/zsh-users/zsh-syntax-highlighting |
| [lazygit](https://github.com/jesseduffield/lazygit) | Visual Git interface in the terminal — stage, commit, branch, rebase with keyboard shortcuts | https://github.com/jesseduffield/lazygit |
| [mise](https://mise.jdx.dev) | Manage Node, Python, Ruby, Go versions per project — replaces nvm + pyenv + rbenv | https://mise.jdx.dev |

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

```bash
curl -fsSL https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/install.sh | bash -s -- JetBrainsMono
```

Verify:

```bash
fc-list | grep -i jetbrains
```

### Debian 12 — Apply in GNOME Terminal

**Via GUI:**
Open GNOME Terminal → hamburger menu (☰) → **Preferences** → click your profile → **Text** tab → enable **Custom font** → select **JetBrainsMono Nerd Font Mono**

**Via terminal:**
```bash
PROFILE=$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")
gsettings set org.gnome.terminal.legacy.profiles:/:${PROFILE}/font 'JetBrainsMono Nerd Font Mono 12'
gsettings set org.gnome.terminal.legacy.profiles:/:${PROFILE}/use-system-font false
```

### Debian 12 — Apply in VS Code integrated terminal

```json
"terminal.integrated.fontFamily": "JetBrainsMono Nerd Font Mono"
```

---

### Windows / WSL2 — Install via winget

Run in **PowerShell or CMD** on the Windows side (not inside WSL):

```powershell
winget install -e --id DEVCOM.JetBrainsMonoNerdFont
winget install -e --id DEVCOM.FiraCodeNerdFont   # popular alternative
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

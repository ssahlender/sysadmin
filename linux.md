# Linux — Tools & Config

> Derived from [tools.yaml](tools.yaml). 🧠 = deepseek suggestion.  
> **Rule:** `brew install` for everything. `apt` only where no brew formula exists.

## 1. Prerequisite: Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

---

## 2. Editor + Font

```bash
# VS Code — .deb/.rpm from https://code.visualstudio.com
```

```bash
# Nerd Font
curl -fsSL https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/install.sh | bash -s -- JetBrainsMono
```

**GNOME Terminal:** Preferences → Text → Custom font → JetBrainsMono Nerd Font Mono  
**VS Code:** `"terminal.integrated.fontFamily": "JetBrainsMono Nerd Font Mono"`  
**Ghostty:** `~/.config/ghostty/config` → `font-family = JetBrainsMono Nerd Font Mono`

---

## 3. Terminal

```bash
brew install ghostty
```

---

## 4. CLI Core

```bash
brew install git gh wget curl jq yq tree htop btop tmux fzf ripgrep fd bat eza zoxide fastfetch
```

**Git config:**

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main
git config --global core.editor "code --wait"
gh auth login

ssh-keygen -t ed25519 -C "you@example.com"
eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_ed25519
```

---

## 5. Shell

```bash
brew install starship zsh-autosuggestions zsh-syntax-highlighting lazygit mise direnv
brew install atuin chezmoi   # 🧠
```

**`~/.zshrc`:**

```bash
eval "$(starship init zsh)"
source /home/linuxbrew/.linuxbrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /home/linuxbrew/.linuxbrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
eval "$(zoxide init zsh)"
eval "$(atuin init zsh)"              # 🧠
```

---

## 6. Git Multi-Repo

```bash
brew install alajmo/mani/mani
pipx install gita
```

---

## 7. DevOps CLI

```bash
brew install kubectl helm k9s kubectx stern opentofu ansible \
  awscli azure-cli google-cloud-sdk \
  age sops gnupg mosh \
  kind minikube tilt \
  trivy kustomize mitmproxy

# Terraform
brew tap hashicorp/tap && brew install hashicorp/tap/terraform
```

```bash
# pinentry for GPG (no brew formula)
sudo apt install pinentry-curses
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
| pinentry-curses | Terminal GPG password entry |
| mosh | Resilient SSH |
| kind / minikube | Local K8s clusters |
| tilt | Hot-reload K8s apps |
| trivy 🧠 | Vulnerability scanner |
| kustomize 🧠 | K8s native config |
| mitmproxy | HTTP inspector |

> Native Docker on Linux — no OrbStack needed. Install: `sudo apt install docker.io && sudo usermod -aG docker $USER`.

---

## 8. Extra CLI 🧠

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

## 9. Languages

```bash
brew install python uv node pnpm bun pipx
```

---

## 10. AI Agents

```bash
brew install ollama claude-code codex opencode claude-squad
pipx install aider-chat
npm install -g @google/gemini-cli

# LM Studio — AppImage from https://lmstudio.ai
```

**Models:**

```bash
ollama pull qwen3:14b
ollama pull llama3.1:8b
ollama pull mistral
```

**VS Code AI extensions:** Continue, Cline, Roo Code, GitHub Copilot.

---

## 11. DevOps GUI

| App | Install |
|-----|---------|
| bruno | AppImage / `.deb` from [usebruno.com](https://www.usebruno.com) |
| dbeaver-community | `flatpak install dbeaver` or `.deb` from [dbeaver.io](https://dbeaver.io) |
| lens 🧠 | AppImage from [k8slens.dev](https://k8slens.dev) |
| xpipe | AppImage from [xpipe.io](https://xpipe.io) |

---

## 12. Productivity & Office

```bash
sudo apt install libreoffice wireguard-tools firefox
```

| App | Install |
|-----|---------|
| libreoffice | `apt install libreoffice` |
| obsidian | AppImage from [obsidian.md](https://obsidian.md) |
| notion | Web app |
| slack | `flatpak install slack` or `.deb` |
| zoom | `flatpak install zoom` or `.deb` |
| signal | `flatpak install signal` or `.deb` |
| bitwarden | `flatpak install bitwarden` or AppImage |
| 1password | `.deb` from [1password.com](https://1password.com) |
| whatsapp | `flatpak install whatsapp` or web.whatsapp.com |
| resilio-sync | `flatpak install resilio-sync` or `.deb` |
| chrome/edge/brave | `.deb` from vendor sites |

---

## 13. File Managers

```bash
sudo apt install doublecmd-gtk
```

---

## 14. Mac Utility Alternatives

| Mac tool | Linux replacement |
|----------|-------------------|
| iTerm2 | Ghostty or Alacritty |
| Raycast | Ulauncher or Albert |
| Rectangle | i3 / Sway tiling WM |
| OrbStack | Native Docker |
| Proxyman | mitmproxy (`mitmweb` for browser UI) |
| PDF Expert | Okular or Evince |
| Hidden Bar / Thaw | Not applicable |
| AppCleaner / Pearcleaner | Package managers handle cleanup |
| KnockKnock | rkhunter or chkrootkit |
| Parallels / UTM | KVM/QEMU + virt-manager |

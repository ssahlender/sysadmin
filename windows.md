# Windows — Tools & Config

> Derived from [tools.yaml](tools.yaml). 🧠 = deepseek suggestion.  
> Uses `winget` for everything. Many CLI tools are better inside WSL2.

## 1. Prerequisite: WSL2 + Windows Terminal

```powershell
wsl --install -d Ubuntu
```

Windows Terminal is preinstalled on Windows 11.

---

## 2. Editor + Font

```powershell
winget install Microsoft.VisualStudioCode
winget install SublimeHQ.SublimeText.4
winget install DEVCOM.JetBrainsMonoNerdFont
```

**Windows Terminal font:** Settings → Profile → Appearance → Font face → JetBrainsMono Nerd Font Mono

**VS Code:** `"terminal.integrated.fontFamily": "JetBrainsMono Nerd Font Mono"`

---

## 3. CLI Core

```powershell
winget install Git.Git GitHub.cli GNU.Wget curl.curl jqlang.jq MikeFarah.yq tree
winget install junegunn.fzf BurntSushi.ripgrep.MSVC sharkdp.fd sharkdp.bat
winget install eza-community.eza ajeetdsouza.zoxide fastfetch
winget install Gyan.FFmpeg ImageMagick.ImageMagick 7zip.7zip
```

**Git config:**

```powershell
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main
git config --global core.editor "code --wait"
gh auth login

ssh-keygen -t ed25519 -C "you@example.com"
```

> `tmux`, `htop`, `btop` — use inside WSL2.

---

## 4. Shell

```powershell
winget install Starship.Starship JesseDuffield.lazygit jdx.mise direnv.direnv
winget install atuinsh.atuin twpayne.chezmoi   # 🧠
```

**PowerShell `$PROFILE`:**

```powershell
Invoke-Expression (&starship init powershell)
Invoke-Expression (& { (zoxide init powershell | Out-String) })
```

> `zsh-autosuggestions`, `zsh-syntax-highlighting` — zsh only, use in WSL2.

---

## 5. Git Multi-Repo

```powershell
winget install alajmo.mani
pipx install gita
```

---

## 6. DevOps CLI

```powershell
winget install Kubernetes.kubectl Helm.Helm derailed.k9s ahmetb.kubectx stern.stern
winget install OpenTofu.Tofu HashiCorp.Terraform Amazon.AWSCLI Microsoft.AzureCLI Google.CloudSDK
winget install FiloSottile.age Mozilla.sops GnuPG.GnuPG
winget install Kubernetes.kind Kubernetes.minikube tilt-dev.tilt
winget install AquaSecurity.Trivy Kubernetes.kustomize mitmproxy.mitmproxy
```

> `ansible`, `mosh`, `pinentry` — use inside WSL2.

---

## 7. Extra CLI 🧠

```powershell
winget install bootandy.dust muesli.duf dandavison.delta chmln.sd Wilfred.difftastic
winget install tealdeer-rs.tealdeer sharkdp.hyperfine Casey.Just watchexec.watchexec
winget install restic.restic sxyazi.yazi
```

---

## 8. Languages

```powershell
winget install Python.Python.3 astral-sh.uv OpenJS.NodeJS pnpm.pnpm Oven-sh.Bun pipx
```

---

## 9. AI Agents

```powershell
winget install Ollama.Ollama LMStudio.LMStudio
```

**WSL2 agents (from WSL terminal):**

```bash
brew install claude-code codex opencode claude-squad
pipx install aider-chat
npm install -g @google/gemini-cli
```

**Models:**

```powershell
ollama pull qwen3:14b
ollama pull llama3.1:8b
ollama pull mistral
```

**VS Code AI extensions:** Continue, Cline, Roo Code, GitHub Copilot.

---

## 10. DevOps GUI

```powershell
winget install usebruno.Bruno dbeaver.dbeaver Mirantis.Lens xpipe-io.xpipe
```

> `orbstack` — Mac only. Use Docker Desktop on Windows.  
> `proxyman` — Mac only. Use mitmproxy or Fiddler.

---

## 11. Productivity & Office

```powershell
winget install TheDocumentFoundation.LibreOffice Obsidian.Obsidian Notion.Notion
winget install SlackTechnologies.Slack Zoom.Zoom WhatsApp.WhatsApp Signal.Signal
winget install Bitwarden.Bitwarden AgileBits.1Password Resilio.ResilioSync WireGuard.WireGuard
winget install Adobe.Acrobat.Reader.64-bit
winget install VideoLAN.VLC
```

> Microsoft Office — preinstalled or Microsoft 365.

---

## 12. Browsers

```powershell
winget install Google.Chrome Mozilla.Firefox Brave.Brave
# Edge preinstalled
```

---

## 13. File Managers

```powershell
winget install doublecmd.doublecmd muCommander.muCommander
```

---

## 14. Mac Utility Alternatives

| Mac tool | Windows replacement |
|----------|---------------------|
| iTerm2 | Windows Terminal |
| Raycast | PowerToys Run |
| Rectangle | PowerToys FancyZones |
| OrbStack | Docker Desktop |
| Proxyman | Fiddler or mitmproxy |
| PDF Expert | PDF-XChange Editor |
| Hidden Bar / Thaw | System tray overflow |
| AppCleaner / Pearcleaner | Revo Uninstaller |
| KnockKnock | Autoruns (Sysinternals) |
| Parallels / UTM | Hyper-V |
| Keka | 7-Zip (built into Windows) |
| Stats | Task Manager or btop |
| AltTab | built-in (Alt+Tab is native) |
| Alfred / Raycast | PowerToys Run |

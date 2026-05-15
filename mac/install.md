# One-Shot Install Script

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
brew install --cask visual-studio-code iterm2 ghostty raycast rectangle \
  thaw pearcleaner \
  orbstack bruno dbeaver-community proxyman \
  knockknock dockdoor \
  lm-studio \
  claude-code codex \
  microsoft-office obsidian slack zoom bitwarden resilio-sync \
  google-chrome firefox microsoft-edge \
  double-commander mucommander nimble-commander \
  utm

# App Store / direct download only
# SnippetsLab: https://apps.apple.com/app/id1006087419
# Latest:      https://max.codes/latest
# Stim:        https://widgetworx.com/apps/stim.html
# QSpace:      App Store — search "QSpace Pro"

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

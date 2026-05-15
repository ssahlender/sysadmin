# AI Agents & Coding Assistants

> MacBook Air M4 · 24 GB RAM · Debian 12  
> See [README.md](README.md) for the full setup guide.

> **Linux / Debian note:** [Homebrew works on Linux](https://docs.brew.sh/Homebrew-on-Linux) (same `brew` command, same formulas). Install it the same way as on macOS. One important difference: **`--cask` does not work on Linux** — casks are macOS GUI app bundles. For Linux, CLI tools via `brew install <name>` work fine; GUI apps need alternative install methods noted below.

---

## Local LLM Runtimes

| Tool | Description | Link |
|------|-------------|------|
| [Ollama](https://ollama.com) | Run LLMs locally via CLI, REST API | https://ollama.com |
| [LM Studio](https://lmstudio.ai) | GUI for local models, OpenAI-compatible server | https://lmstudio.ai |

### Install

**macOS:**
```bash
brew install ollama
brew install --cask lm-studio
```

**Debian / Linux:**
```bash
brew install ollama

# LM Studio — no cask on Linux, use the official AppImage
# Download from https://lmstudio.ai → Linux → AppImage
```

### Recommended models (24 GB M4)

```bash
ollama pull qwen3:14b      # best fit for 24 GB — outperforms 8B on coding tasks
ollama pull llama3.1:8b
ollama pull mistral
```

> With 24 GB unified memory on M4 you can run 14B models at Q4 without swapping.

---

## AI Coding Agents & CLIs

| Tool | Description | Link |
|------|-------------|------|
| [Claude Code](https://www.anthropic.com/claude-code) | Anthropic's agentic coding CLI | https://www.anthropic.com/claude-code |
| [Codex](https://github.com/openai/codex) | OpenAI's agentic coding CLI | https://github.com/openai/codex |
| [OpenCode](https://github.com/sst/opencode) | Model-flexible, open source, Ollama support | https://github.com/sst/opencode |
| [Aider](https://aider.chat) | Git-aware coding assistant | https://aider.chat |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | Google's agent CLI | https://github.com/google-gemini/gemini-cli |
| [claude-squad](https://github.com/smtg-ai/claude-squad) | Manage Claude Code + Aider + Codex in one terminal | https://github.com/smtg-ai/claude-squad |

### Install

**macOS:** (Homebrew casks preferred — integrate with `brew upgrade`, no `sudo`, keep npm clean)
```bash
brew install --cask claude-code
brew install --cask codex
brew install opencode
brew install claude-squad
pipx install aider-chat
npm install -g @google/gemini-cli
```

**Debian / Linux:** (`--cask` unavailable — `claude-code`, `codex`, and `opencode` all have brew formulas that work on Linux)
```bash
brew install claude-code
brew install codex
brew install opencode
brew install claude-squad
pipx install aider-chat
npm install -g @google/gemini-cli
```

---

## HTTP / API Debugging

| Tool | Description | Link |
|------|-------------|------|
| [Proxyman](https://proxyman.io) | macOS HTTP proxy — intercept and inspect all agent traffic | https://proxyman.io |
| [mitmproxy](https://mitmproxy.org) | Open-source alternative — CLI + web UI, works on Linux/Debian | https://mitmproxy.org |

**macOS:**
```bash
brew install --cask proxyman
```

**Debian / Linux:**
```bash
brew install mitmproxy
# or
pipx install mitmproxy
```

> Essential when debugging AI agent calls — lets you see exactly what your agent sends and receives over HTTP/HTTPS. On Linux, run `mitmweb` for a browser-based UI or `mitmproxy` for a terminal UI.

---

## VS Code Extensions for AI Development

| Extension | Description | Link |
|-----------|-------------|------|
| Python + Pylance | Language support | [marketplace](https://marketplace.visualstudio.com/items?itemName=ms-python.python) |
| Dev Containers | Containerised dev environments | [marketplace](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) |
| [Continue](https://www.continue.dev) | Open-source Copilot alternative, Ollama support | https://www.continue.dev |
| [Cline](https://github.com/cline/cline) | Agentic coding extension | https://github.com/cline/cline |
| [Roo Code](https://github.com/RooVetGit/Roo-Code) | Cline fork with extended model support | https://github.com/RooVetGit/Roo-Code |
| [GitHub Copilot](https://github.com/features/copilot) | Inline AI suggestions | https://github.com/features/copilot |

---

## Python AI Project Quickstart

```bash
uv init my-agent
cd my-agent
uv add openai anthropic langchain langgraph llama-index \
       pydantic python-dotenv fastapi uvicorn
```

> [`uv`](https://github.com/astral-sh/uv) replaces `pip`/`venv` — dramatically faster installs.

---

## Multi-Agent Orchestration

| Tool | Description | Link |
|------|-------------|------|
| [claude-squad](https://github.com/smtg-ai/claude-squad) | Terminal multiplexer for running Claude Code + Aider + Codex side-by-side | https://github.com/smtg-ai/claude-squad |
| [LangGraph](https://github.com/langchain-ai/langgraph) | Python framework for multi-agent graphs | https://github.com/langchain-ai/langgraph |

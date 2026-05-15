# AGENTS.md — AI Agents & Coding Assistants Reference

> MacBook Air M4 · 24 GB RAM · Debian 12  
> Extracted from the full setup guide — see [README.md](README.md) for the complete stack.

> **Linux / Debian note:** [Homebrew works on Linux](https://docs.brew.sh/Homebrew-on-Linux) (same `brew` command, same formulas). Install it the same way as on macOS. One important difference: **`--cask` does not work on Linux** — casks are macOS GUI app bundles. For Linux, CLI tools via `brew install <name>` work fine; GUI apps need alternative install methods noted below.

## Legend

| Symbol | Meaning |
|--------|---------|
| 🟠 Claude | Suggested by Claude |
| 🤖 ChatGPT | Suggested by ChatGPT |
| ✅ Both | Both agreed independently |

---

## Local LLM Runtimes

| Tool | Description | Source | Link |
|------|-------------|--------|------|
| [Ollama](https://ollama.com) | Run LLMs locally via CLI, REST API | ✅ Both | https://ollama.com |
| [LM Studio](https://lmstudio.ai) | GUI for local models, OpenAI-compatible server | 🤖 ChatGPT | https://lmstudio.ai |

### Install

**macOS:**
```bash
brew install ollama
brew install --cask lm-studio
```

**Debian / Linux:**
```bash
brew install ollama          # works via Linuxbrew

# LM Studio — no cask on Linux, use the official AppImage
# Download from https://lmstudio.ai → Linux → AppImage
```

### Recommended models (24 GB M4 = run large models comfortably)

```bash
ollama pull qwen3:14b      # 🟠 Claude — better reasoning, fits well on 24 GB
ollama pull llama3.1:8b    # ✅ Both
ollama pull mistral        # ✅ Both
```

> **🟠 Claude note:** With 24 GB unified memory on M4 you can run 14B models at Q4 without swapping. `qwen3:14b` outperforms `llama3.1:8b` on coding tasks at roughly the same speed on this hardware.  
> **🤖 ChatGPT note:** `llama3.1` was the primary recommendation in the ChatGPT guide.

---

## AI Coding Agents & CLIs

| Tool | Description | Source | Link |
|------|-------------|--------|------|
| [Claude Code](https://www.anthropic.com/claude-code) | Anthropic's agentic coding CLI | ✅ Both | https://www.anthropic.com/claude-code |
| [Codex](https://github.com/openai/codex) | OpenAI's agentic coding CLI | ✅ Both | https://github.com/openai/codex |
| [OpenCode](https://github.com/sst/opencode) | Model-flexible, open source, Ollama support | ✅ Both | https://github.com/sst/opencode |
| [Aider](https://aider.chat) | Git-aware coding assistant | ✅ Both | https://aider.chat |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | Google's agent CLI | 🟠 Claude | https://github.com/google-gemini/gemini-cli |
| [claude-squad](https://github.com/smtg-ai/claude-squad) | Manage Claude Code + Aider + Codex in one terminal | 🟠 Claude | https://github.com/smtg-ai/claude-squad |

### Install

**macOS:** (🟠 Claude: Homebrew casks preferred — integrate with `brew upgrade`, no `sudo`, keep npm clean)
```bash
brew install --cask claude-code
brew install --cask codex
brew install opencode
brew install claude-squad
pipx install aider-chat
npm install -g @google/gemini-cli
```

**Debian / Linux:** (`--cask` unavailable — but `claude-code`, `codex`, and `opencode` all have brew formulas that work on Linux)
```bash
brew install claude-code     # formula (not cask) — works on Linux
brew install codex           # formula (not cask) — works on Linux
brew install opencode
brew install claude-squad
pipx install aider-chat
npm install -g @google/gemini-cli
```

> **🟠 Claude note:** On macOS the cask and formula are separate packages — prefer the cask. On Linux only the formula exists, and it works identically.  
> **🤖 ChatGPT note:** ChatGPT did not include Gemini CLI or claude-squad.

---

## HTTP / API Debugging

| Tool | Description | Source | Link |
|------|-------------|--------|------|
| [Proxyman](https://proxyman.io) | macOS HTTP proxy — intercept and inspect all agent traffic | 🟠 Claude | https://proxyman.io |
| [mitmproxy](https://mitmproxy.org) | Open-source alternative — CLI + web UI, works on Linux/Debian | 🟠 Claude | https://mitmproxy.org |

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

> **🟠 Claude note:** Proxyman is essential when debugging AI agent calls — it lets you see exactly what your agent sends and receives over HTTP/HTTPS. On Linux, `mitmproxy` is the closest equivalent: run `mitmweb` for a browser-based UI or `mitmproxy` for a terminal UI. ChatGPT did not include either.

---

## VS Code Extensions for AI Development

| Extension | Description | Source | Link |
|-----------|-------------|--------|------|
| Python + Pylance | Language support | ✅ Both | [marketplace](https://marketplace.visualstudio.com/items?itemName=ms-python.python) |
| Dev Containers | Containerised dev environments | ✅ Both | [marketplace](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) |
| [Continue](https://www.continue.dev) | Open-source Copilot alternative, Ollama support | 🤖 ChatGPT | https://www.continue.dev |
| [Cline](https://github.com/cline/cline) | Agentic coding extension | 🤖 ChatGPT | https://github.com/cline/cline |
| [Roo Code](https://github.com/RooVetGit/Roo-Code) | Cline fork with extended model support | 🤖 ChatGPT | https://github.com/RooVetGit/Roo-Code |
| [GitHub Copilot](https://github.com/features/copilot) | Inline AI suggestions | 🤖 ChatGPT | https://github.com/features/copilot |

> **🤖 ChatGPT note:** Continue, Cline/Roo Code, and Copilot were all ChatGPT recommendations. Claude did not duplicate these since Claude Code operates outside VS Code.

---

## Python AI Project Quickstart

```bash
# Create and enter project
uv init my-agent
cd my-agent

# Add common AI libraries
uv add openai anthropic langchain langgraph llama-index \
       pydantic python-dotenv fastapi uvicorn
```

> ✅ Both agreed on this stack. [`uv`](https://github.com/astral-sh/uv) replaces `pip`/`venv` — dramatically faster installs.

---

## Multi-Agent Orchestration

| Tool | Description | Source | Link |
|------|-------------|--------|------|
| [claude-squad](https://github.com/smtg-ai/claude-squad) | Terminal multiplexer for running Claude Code + Aider + Codex side-by-side | 🟠 Claude | https://github.com/smtg-ai/claude-squad |
| [LangGraph](https://github.com/langchain-ai/langgraph) | Python framework for multi-agent graphs | ✅ Both (via uv add) | https://github.com/langchain-ai/langgraph |

---

## Claude vs ChatGPT: AI Section Differences

| Topic | ChatGPT | 🟠 Claude |
|-------|---------|-----------|
| Agent install method | `npm install -g` | **Homebrew casks** — cleaner, managed |
| Local model choice | `llama3.1` | **`qwen3:14b`** — better fit for 24 GB M4 |
| HTTP debugging | — | **Proxyman** — essential for agent debugging |
| Multi-agent management | — | **claude-squad** |
| Google agent CLI | — | **Gemini CLI** |
| VS Code AI extensions | Continue, Cline, Copilot | Deferred to agent CLIs |

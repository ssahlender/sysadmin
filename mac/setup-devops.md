# DevOps Stack

## Core CLIs

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

## Containers

**[OrbStack](https://orbstack.dev)** over Docker Desktop on Apple Silicon — lighter, faster, more Mac-native:

```bash
brew install --cask orbstack
```

## Remote Connection Management

**[XPipe](https://xpipe.io)** — connection hub for SSH, RDP, VNC, containers, and VMs. Stores all your hosts in one place, handles SSH tunneling automatically, and launches the appropriate client for RDP/VNC.

```bash
brew install --cask xpipe-io/tap/xpipe
```

> **RDP from XPipe:** XPipe tunnels the connection (through SSH if needed) and hands off to **Microsoft Remote Desktop** — install it from the App Store if you haven't already. Configure the RDP target in XPipe and it opens automatically in the external client.

> **VNC from XPipe:** Same pattern — XPipe manages the tunnel, macOS Screen Sharing or a VNC viewer handles the display.

## API & Database

```bash
brew install --cask bruno dbeaver-community proxyman
brew install direnv
```

| Tool | Description | Link |
|------|-------------|------|
| [kubectl](https://kubernetes.io/docs/reference/kubectl/) | Deploy and manage apps on Kubernetes clusters | https://kubernetes.io/docs/reference/kubectl/ |
| [helm](https://helm.sh) | Package manager for Kubernetes | https://helm.sh |
| [k9s](https://k9scli.io) | Terminal dashboard for Kubernetes — browse pods, logs, and resources visually | https://k9scli.io |
| [Terraform](https://www.terraform.io) | Define cloud infrastructure as code | https://www.terraform.io |
| [OpenTofu](https://opentofu.org) | Open-source Terraform fork, fully compatible | https://opentofu.org |
| [Ansible](https://www.ansible.com) | Automate server configuration over SSH — no agent required | https://www.ansible.com |
| [awscli](https://aws.amazon.com/cli/) | Official CLI for Amazon Web Services | https://aws.amazon.com/cli/ |
| [azure-cli](https://docs.microsoft.com/cli/azure/) | Official CLI for Microsoft Azure | https://docs.microsoft.com/cli/azure/ |
| [google-cloud-sdk](https://cloud.google.com/sdk) | Official CLI for Google Cloud Platform (`gcloud`, `gsutil`, `bq`) | https://cloud.google.com/sdk |
| [kind](https://kind.sigs.k8s.io) | Run a Kubernetes cluster locally inside Docker — great for testing | https://kind.sigs.k8s.io |
| [minikube](https://minikube.sigs.k8s.io) | Alternative local Kubernetes cluster — single-node, easy to start | https://minikube.sigs.k8s.io |
| [Tilt](https://tilt.dev) | Hot-reload your app in a local Kubernetes cluster as you save code | https://tilt.dev |
| [age](https://github.com/FiloSottile/age) | Simple, modern file encryption | https://github.com/FiloSottile/age |
| [sops](https://github.com/getsops/sops) | Encrypt secrets inside YAML/JSON/ENV files — safely commit them to Git | https://github.com/getsops/sops |
| [gnupg](https://gnupg.org) | GPG encryption — sign commits, encrypt files, used by sops | https://gnupg.org |
| [pinentry-mac](https://github.com/GPGTools/pinentry) | Native macOS password dialog for GPG | https://github.com/GPGTools/pinentry |
| [mosh](https://mosh.org) | SSH replacement that stays connected over flaky Wi-Fi or when your laptop sleeps | https://mosh.org |
| [OrbStack](https://orbstack.dev) | Lightweight Docker + Linux VM runtime — replaces Docker Desktop on Apple Silicon | https://orbstack.dev |
| [Bruno](https://www.usebruno.com) | Test and explore APIs — like Postman but offline, file-based, and free | https://www.usebruno.com |
| [DBeaver](https://dbeaver.io) | Universal database GUI — connects to Postgres, MySQL, SQLite, and more | https://dbeaver.io |
| [Proxyman](https://proxyman.io) | Intercept and inspect HTTP/HTTPS traffic — essential for debugging AI agent calls | https://proxyman.io |
| [direnv](https://direnv.net) | Automatically load/unload environment variables when you `cd` into a project folder | https://direnv.net |
| [XPipe](https://xpipe.io) | Connection hub — SSH, RDP, VNC, containers, VMs; handles tunneling and launches external clients | https://xpipe.io |

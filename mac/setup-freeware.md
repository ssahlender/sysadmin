# Mac Freeware

> Source: [Völlig kostenlos: 21 Freeware-Perlen für den Mac](https://www.heise.de/-11215455) — Mac & i, Joachim Kläschen, March 2026

## Upgrades to Existing Tools

### Hidden Bar → [Thaw](https://github.com/stonerl/Thaw)

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

### AppCleaner → [Pearcleaner](https://itsalin.com/appInfo/?id=pearcleaner)

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
| Update checker | No | Yes |
| Open source | No | Yes — [GitHub](https://github.com/alienator88/Pearcleaner) |

> Pearcleaner does everything AppCleaner does, plus sorts your apps by size and has a Homebrew management panel built in.

---

## Security

| Tool | Description | Link |
|------|-------------|------|
| [KnockKnock](https://objective-see.org/products/knockknock.html) | Scans all persistent background processes and checks them against VirusTotal | https://objective-see.org/products/knockknock.html |

```bash
brew install --cask knockknock
```

---

## Productivity & Developer Workflow

| Tool | Description | Install | Link |
|------|-------------|---------|------|
| [SnippetsLab](https://apps.apple.com/app/id1006087419) | Code + text snippet manager, syntax highlighting, iCloud sync | App Store | https://apps.apple.com/app/id1006087419 |
| [Latest](https://max.codes/latest) | Checks updates for all Sparkle-based and App Store apps in one place | Direct download | https://max.codes/latest |
| [Stim](https://widgetworx.com/apps/stim.html) | Keep-awake utility — can be tied to specific running apps | Direct download | https://widgetworx.com/apps/stim.html |
| [DockDoor](https://dockdoor.net) | Window previews on Dock hover + visual Cmd+Tab switcher | `brew install --cask dockdoor` | https://dockdoor.net |

```bash
# Homebrew
brew install --cask dockdoor

# App Store / direct download
# SnippetsLab: https://apps.apple.com/app/id1006087419
# Latest:      https://max.codes/latest
# Stim:        https://widgetworx.com/apps/stim.html
```

> **Note on non-notarized apps:** Thaw, DockDoor, and a few others are not Apple-notarized. If macOS blocks the app on first launch, go to **System Settings → Privacy & Security → Security** and click "Open Anyway".

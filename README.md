<div align="center">

# Sentinel

**Silent laptop security for nomads**

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2013+-blue.svg)](https://www.apple.com/macos)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

*Know what happened while you were away*

</div>

---

## The Problem

You step away from your laptop at a coffee shop. Just for a minute—to grab your order, use the restroom, talk to someone.

When you return, everything looks normal. But was it?

**Sentinel** runs silently in your menu bar, capturing periodic screenshots. If someone touches your machine while you're gone, you'll know.

## Features

- **Menu Bar Agent** — Lives quietly in your status bar, one click away
- **Smart Capture** — Configurable intervals (default: every 10 seconds when active)
- **Built-in Viewer** — Access screenshots from any device on your network
- **Activity Monitor** — Tracks app launches, clipboard changes, wake events
- **Zero Cloud** — Everything stays on your machine, always
- **Resource Light** — Under 25MB memory, minimal CPU impact

## Quick Start

```bash
# Clone and build
git clone https://github.com/triggeredcode/sentinel.git
cd sentinel
swift build -c release

# Run
.build/release/Sentinel
```

The menu bar icon appears. Click it to:
- **Capture Now** — Take an immediate screenshot
- **Open Viewer** — Launch the web viewer (default: http://localhost:8080)
- **Settings** — Configure interval, image limit, crop region

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Menu Bar App                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │
│  │ AppDelegate │──│  Capture    │──│  HTTPServer     │  │
│  │   (UI)      │  │  Engine     │  │  (Viewer)       │  │
│  └─────────────┘  └─────────────┘  └─────────────────┘  │
│         │                │                  │            │
│         ▼                ▼                  ▼            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │
│  │ Power       │  │ Keychain    │  │  Notification   │  │
│  │ Manager     │  │ Manager     │  │  Monitor        │  │
│  └─────────────┘  └─────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Core Components

| Component | Responsibility |
|-----------|----------------|
| **AppDelegate** | Menu bar UI, capture scheduling, coordination |
| **ScreenshotCapture** | CGDisplayCreateImage wrapper, JPEG conversion |
| **HTTPServer** | Network.framework server, serves viewer + images |
| **KeychainManager** | Secure token storage via Security.framework |
| **PowerManager** | IOPMAssertion to prevent sleep during capture |
| **NotificationMonitor** | Tracks system events (app launches, clipboard, sleep) |
| **Logger** | Thread-safe file logging to ~/Library/Logs |

## Philosophy

### Why Local-First?

Cloud screenshot services exist. They're convenient. They're also:
- Privacy nightmares (your screen = your life)
- Dependent on internet connectivity
- Monthly subscriptions for basic functionality

Sentinel keeps everything on your machine. Your screenshots never leave your network.

### Why No Authentication by Default?

The viewer is accessible on your local network without a password. This is intentional:

1. **Your network, your trust** — If someone's on your WiFi, they're already trusted
2. **Friction kills usage** — Enter a password every time? You'll stop using it
3. **Phone access** — Quick glance from your phone without typing credentials

For high-security environments, the token authentication is there if you need it.

### Why Polling Instead of Events?

Sentinel captures at intervals rather than on every input event because:

1. **Predictable resource usage** — Fixed CPU/memory overhead
2. **Complete coverage** — Events can be missed; time-based capture can't
3. **Simpler debugging** — Easy to reason about when captures happen

## Configuration

Edit settings via the menu bar, or modify the plist directly:

| Setting | Default | Description |
|---------|---------|-------------|
| Capture Interval | 10s | Seconds between automatic captures |
| Max Images | 100 | Images kept before rotation |
| JPEG Quality | 0.7 | Compression (0.0-1.0) |
| Server Port | 8080 | HTTP viewer port |

### launchd (Auto-Start)

```bash
cp Config/com.sentinel.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.sentinel.plist
```

## Mobile Viewer

Open `http://<your-mac-ip>:8080` on your phone:

- **Swipe** through captures
- **Pinch** to zoom
- **Tap** for full-screen
- **Pull down** to refresh

Find your Mac's IP via the menu bar → "Copy Viewer URL"

## Resource Usage

Tested on M1 MacBook Air:

| Metric | Value |
|--------|-------|
| Memory | ~20MB |
| CPU (idle) | 0% |
| CPU (capturing) | <1% spike |
| Disk (100 images) | ~15MB |

## Development

```bash
# Build debug
swift build

# Run tests
swift test

# Build release
swift build -c release
```

### Project Structure

```
Sentinel/
├── Sources/Sentinel/
│   ├── main.swift              # Entry point
│   ├── App/
│   │   └── AppDelegate.swift   # Menu bar + coordination
│   ├── Capture/
│   │   ├── ScreenshotCapture.swift
│   │   └── CropSelector.swift
│   ├── Server/
│   │   └── HTTPServer.swift    # Built-in web server
│   ├── Security/
│   │   └── KeychainManager.swift
│   ├── System/
│   │   ├── PowerManager.swift
│   │   └── NotificationMonitor.swift
│   └── Core/
│       └── Logger.swift
├── Tests/SentinelTests/
├── Config/
│   └── com.sentinel.plist
└── evolution/                   # Historical snapshots
    └── snapshots/
```

## Troubleshooting

<details>
<summary><strong>Screen recording permission denied</strong></summary>

System Settings → Privacy & Security → Screen Recording → Enable Sentinel

</details>

<details>
<summary><strong>Viewer not accessible from phone</strong></summary>

1. Check both devices are on same WiFi
2. Check macOS Firewall (System Settings → Network → Firewall)
3. Try accessing via IP instead of hostname

</details>

<details>
<summary><strong>High memory usage</strong></summary>

Reduce "Max Images" in settings. Each image is ~150KB in memory.

</details>

## Uninstall

```bash
# Stop the agent
launchctl unload ~/Library/LaunchAgents/com.sentinel.plist

# Remove files
rm ~/Library/LaunchAgents/com.sentinel.plist
rm -rf /usr/local/bin/Sentinel
rm -rf ~/Library/Logs/sentinel.log
rm -rf ~/Library/Application\ Support/Sentinel
```

## License

MIT — Use it, modify it, ship it.

---

<div align="center">

**Built for the paranoid, by the paranoid.**

[Report Bug](https://github.com/triggeredcode/sentinel/issues) · [Request Feature](https://github.com/triggeredcode/sentinel/issues)

</div>

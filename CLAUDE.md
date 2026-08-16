Last Modified: 08/17/2026 (1786899911) by amonrit

# CLAUDE.md

This file provides guidance to Claude Code and AI assistants when working with code in this repository.

---

## 🚀 Start Here

**New to the project?**
→ Read [GETTING_STARTED.md](./GETTING_STARTED.md) (5 minutes)

**All documentation:**
→ Read [DOCUMENTATION.md](./DOCUMENTATION.md) (master index)

---

## Project Overview

**Steam** is a dual-component iOS video streaming application:

1. **iOS App** — SwiftUI-based HLS video player with MVVM architecture
2. **Streaming Server** — Docker-based MediaMTX server for publishing and managing live streams

The project enables users to publish live video streams (via RTMP) and play them back (via HLS/RTSP/WebRTC) on iOS devices.

---

## Architecture: MVVM (Quick Reference)

The iOS app follows **Model-View-ViewModel** pattern. For deep dive, see [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md).

**Quick structure:**
```
Views (SwiftUI)
  ↓ observe @Published properties
PlaybackViewModel (Business Logic + State)
  ├─ Owns AVPlayer instance
  ├─ Manages stream loading, playback state, error handling
  └─ Coordinates with Workers for KVO/Combine setup
  
Workers (Reusable Utilities)
  └─ VideoPlayerWorker — KVO observers, resolution/bitrate extraction

Models (Data Entities)
  ├─ VideoStream — URL, title, thumbnail
  └─ PlaybackState — Internal state tracking
```

**Key Decision:** `VideoStreamListView` uses `@StateObject` to preserve `PlaybackViewModel` across re-renders (prevents AVPlayer memory leaks). `HomeView` serves as root entry point with navigation menu to main features.

---

## Important Files

| File | Purpose |
|------|---------|
| `steam/ViewModels/PlaybackViewModel.swift` | Core business logic & state |
| `steam/Views/HomeView.swift` | Home menu & navigation hub |
| `steam/Views/VideoStreamListView.swift` | Stream list & playback UI |
| `steam/Views/VideoPlayerView.swift` | Player UI & overlays |
| `steam/Workers/VideoPlayerWorker.swift` | KVO observers & formatting |
| `streaming/docker-compose.yml` | Docker service config |
| `streaming/mediamtx.yml` | MediaMTX configuration |

---

## Documentation Map

| Document | Purpose |
|----------|---------|
| [GETTING_STARTED.md](./GETTING_STARTED.md) | Setup guide (5 min) |
| [DOCUMENTATION.md](./DOCUMENTATION.md) | Master index |
| [docs/DEVELOPMENT.md](./docs/DEVELOPMENT.md) | Local dev workflows |
| [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) | Deep MVVM dive |
| [docs/DEPLOYMENT.md](./docs/DEPLOYMENT.md) | Production setup |

---

## Markdown Header Rule

**All `.md` files MUST start with:**
```
Last Modified: MM/DD/YYYY (UNIX_TIMESTAMP) by USERNAME

[Document content...]
```

Update whenever you edit. See [.claude/markdown-header-rule.md](./.claude/markdown-header-rule.md) for details.

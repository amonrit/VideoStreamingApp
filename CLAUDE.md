Last Modified: 08/10/2026 (1786365804) by amonrit

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

## Streaming Server Architecture

**MediaMTX** (v1.20.0) runs in Docker and manages all streaming protocols:

| Protocol | Port | Purpose |
|----------|------|---------|
| **RTMP** | 1935 | Publishing (OBS, FFmpeg) |
| **RTSP** | 8554 | Low-latency playback |
| **HLS** | 8888 | Web/mobile playback |
| **WebRTC** | 8889 | Ultra-low-latency browser |
| **SRT** | 8890 | Secure, high-quality |

**Files:**
- `docker-compose.yml` — Docker service definition
- `streaming/mediamtx.yml` — MediaMTX configuration
- `recordings/` — Auto-created directory for stream recording

---

## Quick Commands

### iOS App

```bash
# Open in Xcode
open steam.xcodeproj

# Build & run
make dev-app

# View logs
# In Xcode: View → Debug Area → Show Console
# Filter by category: [playback]
```

### Streaming Server

```bash
# Start server
make dev-server

# View logs
make server-logs

# Test stream publishing
ffmpeg -re -i video.mp4 -c copy -f flv rtmp://localhost:1935/live/mystream

# Play stream
ffplay "http://localhost:8888/live/mystream/index.m3u8"
```

---

## Critical Context (For AI)

### Retry & Timeout Strategy

**PlaybackViewModel** uses aggressive retry logic:
- **Load Timeout**: 3 seconds per attempt
- **Stall Timeout**: 2 seconds for recovery
- **Max Retries**: 2 attempts before failure
- **Retry Backoff**: 1–2 seconds between attempts

Ensures the app fails fast and cleanly rather than hanging.

### AVPlayer Configuration

- `allowsExternalPlayback = true` — Enables AirPlay, HDMI casting
- `automaticallyWaitsToMinimizeStalling = true` — Intelligent buffering
- All player state changes observed via KVO (playback status, buffering, errors)

### Threading Model

- **Main Thread**: All UI updates, `@Published` property changes
- **Background**: KVO observations (via Combine), but callbacks always deliver on main thread
- **Guarantee**: No manual `DispatchQueue.main.async` calls needed in Views — Worker ensures main-thread delivery

### Known Quirks

- **URL Session Parameters**: iOS HLS may append `?session=...`. App strips these for MediaMTX compatibility.
- **Audio Track Mismatch**: If server publishes H.264 video + audio but client expects different codec, playback may hang.
- **Docker on Mac**: Uses bridge network; `localhost` works from host, but cross-machine access requires actual IP.
- **Firewall**: All 5 protocols (RTMP, RTSP, HLS, WebRTC, SRT) need open ports.

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

| Document | For AI | Purpose |
|----------|--------|---------|
| [GETTING_STARTED.md](./GETTING_STARTED.md) | Humans | Setup guide (5 min) |
| [DOCUMENTATION.md](./DOCUMENTATION.md) | Humans | Master index |
| [docs/DEVELOPMENT.md](./docs/DEVELOPMENT.md) | Humans | Local dev workflows |
| [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) | AI + Humans | Deep MVVM dive |
| [docs/DEPLOYMENT.md](./docs/DEPLOYMENT.md) | Humans | Production setup |
| [docs/COMMIT_GUIDE.md](./docs/COMMIT_GUIDE.md) | Humans | Commit standards |
| [docs/AI_WORKFLOW.md](./docs/AI_WORKFLOW.md) | Humans | Using AI tools |
| [FEATURES_ROADMAP.md](./FEATURES_ROADMAP.md) | AI + Humans | Future features |
| [.claude/SETUP.md](./.claude/SETUP.md) | AI | Antigravity config |
| [.claude/instructions/swift-style.md](./.claude/instructions/swift-style.md) | AI | Code style rules |

---

## Markdown Header Rule

**All `.md` files MUST start with:**
```
Last Modified: MM/DD/YYYY (UNIX_TIMESTAMP) by USERNAME

[Document content...]
```

Update whenever you edit. See [.claude/markdown-header-rule.md](./.claude/markdown-header-rule.md) for details.

Last Modified: 08/10/2026 (1786502400) by amonrit

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Project Overview

**Steam** is a dual-component iOS video streaming application:

1. **iOS App** — SwiftUI-based HLS video player with MVVM architecture
2. **Streaming Server** — Docker-based MediaMTX server for publishing and managing live streams

The project enables users to publish live video streams (via RTMP) and play them back (via HLS/RTSP/WebRTC) on iOS devices.

---

## Architecture: MVVM (iOS App)

The iOS app follows **Model-View-ViewModel** pattern:

```
Views (SwiftUI)
  ↓ observe @Published properties
PlaybackViewModel (Business Logic + State)
  ├─ Owns AVPlayer instance
  ├─ Manages stream loading, playback state, error handling
  ├─ Coordinates with Workers for KVO/Combine setup
  └─ Exposes @Published properties for UI binding
  
Workers (Reusable Utilities)
  ├─ VideoPlayerWorker — KVO observers, resolution/bitrate extraction
  └─ [Future workers for quality, network, subtitles, etc.]

Models (Data Entities)
  ├─ VideoStream — URL, title, thumbnail
  └─ PlaybackState — Internal state tracking
```

### Key Architecture Decisions

- **Single ViewModel Instance**: `ContentView` uses `@StateObject` to preserve `PlaybackViewModel` across re-renders (prevents AVPlayer memory leaks)
- **Combine Publishers**: All async work (KVO changes, buffering) delivered on main thread via `.receive(on: DispatchQueue.main)` in Workers
- **No DTOs/Protocols**: MVVM eliminates the Clean Swift (VIPER) scaffolding that was in place before; Views directly observe ViewModel's `@Published` properties
- **Centralized Logging**: `os.Logger` (subsystem: `amonrit.steam`, category: `playback`) for structured logging

### File Organization

```
steam/
├── steamApp.swift              — App entry point
├── Models/
│   ├── VideoStream.swift       — Stream metadata (URL, title, thumbnail)
│   └── PlaybackState.swift     — Internal playback state enum
├── ViewModels/
│   └── PlaybackViewModel.swift — Main business logic & state owner
├── Views/
│   ├── ContentView.swift       — Root view (stream list + player + debug)
│   ├── VideoPlayerView.swift   — Player UI + controls
│   └── FullScreenPlayerView.swift — Fullscreen wrapper
└── Workers/
    └── VideoPlayerWorker.swift — KVO setup & format helpers
```

---

## Streaming Server Architecture

**MediaMTX** (v1.20.0) runs in Docker and manages all streaming protocols:

| Protocol | Port | Purpose | Use Case |
|----------|------|---------|----------|
| **RTMP** | 1935 | Publishing | OBS, FFmpeg, mobile app publishing |
| **RTSP** | 8554 | Low-latency playback | Real-time monitoring |
| **HLS** | 8888 | Web/mobile playback | iOS app, browsers |
| **WebRTC** | 8889 | Ultra-low-latency browser | Live chat, interactive |
| **SRT** | 8890 | Secure, high-quality | Backup/failover links |

**Configuration**:
- `docker-compose.yml` — Docker service definition (ports, volumes, environment)
- `streaming/mediamtx.yml` — MediaMTX config (paths, auth, recording)
- `recordings/` — Auto-created directory for stream recording

---

## Common Development Commands

### iOS App Development

**Build & Run**
```bash
# Build for simulator
xcodebuild -scheme steam -destination 'generic/platform=iOS Simulator' build

# Run in Xcode
xcodebuild -scheme steam -destination 'generic/platform=iOS Simulator' test

# (Preferred) Use Xcode IDE directly for full debugging experience
open steam.xcodeproj
```

**Logging**
- View logs in Xcode Console or via macOS Console.app
- Search by subsystem: `amonrit.steam`
- Category: `playback`

### Streaming Server

**Start/Stop Server**
```bash
./streaming.sh start   # Start Docker container
./streaming.sh stop    # Stop container
./streaming.sh restart # Restart (after config changes)
```

**Monitor & Diagnose**
```bash
./streaming.sh status  # Check if running
./streaming.sh logs    # View live logs (Ctrl+C to exit)
./streaming.sh test    # Run verification tests
```

**Direct Docker Commands** (from `streaming/` directory)
```bash
cd streaming/

docker-compose up -d                    # Start
docker-compose down                     # Stop
docker-compose logs -f mediamtx         # Tail logs
docker-compose restart                  # Restart after config change
docker ps --filter "name=mediamtx"      # Check container status
```

**Test Stream Publishing**
```bash
# Publish video file via FFmpeg
ffmpeg -re -i video.mp4 -c copy -f flv \
  rtmp://publish:streampass123@localhost:1935/live/mystream

# Watch via HLS
ffplay "http://localhost:8888/live/mystream/index.m3u8"

# Watch via VLC
# Media → Open Network Stream → http://localhost:8888/live/mystream/index.m3u8
```

---

## Key Workflows

### Adding a New Feature to the iOS App

1. **Identify what state** the feature needs → add `@Published var` to `PlaybackViewModel`
2. **Add business logic** → add methods to `PlaybackViewModel`
3. **If complex**: Create a new **Worker** class for reusable utilities (e.g., `QualityManager`, `NetworkMonitor`)
4. **Create/update Views** → SwiftUI components that observe ViewModel state
5. **Test** → Manual testing in simulator; verify logs in Console.app

**Example**: Adding playback controls (pause, seek, speed)
- Add `currentTime`, `duration`, `playbackRate` as `@Published` to ViewModel
- Create `VideoPlayerWorker` method `setupTimeTracking()` to monitor CMTime changes
- Add `seek(_:)`, `setPlaybackRate(_:)` methods to ViewModel
- Create `PlaybackControlsView` that calls these ViewModel methods

### Deploying the Streaming Server to a New Machine

1. Copy `steam/` folder to new machine: `scp -r ~/Documents/steam user@newmachine:~/Documents/`
2. SSH into new machine
3. Start server: `cd ~/Documents/steam && ./streaming.sh start`
4. Get server IP: `ifconfig | grep "inet " | grep -v 127.0.0.1`
5. Update iOS app with server IP → rebuild → test

See **DEPLOYMENT_GUIDE.md** for detailed multi-machine setup.

### Fixing Playback Issues

**Debug Checklist**:
1. Check logs: `./streaming.sh logs` → look for error messages
2. Verify HLS endpoint: `curl -v http://localhost:8888/live/mystream/index.m3u8` → should return 302 Found or 200 OK
3. Check network: Is stream actively publishing? Check in logs: `[path live/mystream] stream is available`
4. Verify iOS app is using correct server IP
5. Check firewall: Are ports 1935, 8554, 8888, 8889, 8890 open?

---

## Important Files & Their Purposes

| File | Purpose | When to Edit |
|------|---------|--------------|
| `PlaybackViewModel.swift` | Core business logic, state management, retry logic | Adding features, fixing playback bugs |
| `VideoPlayerWorker.swift` | KVO observers, format extraction (resolution, bitrate) | Expanding playback metrics |
| `ContentView.swift` | Root UI, stream list, debug panel | Changing app layout, adding controls |
| `VideoPlayerView.swift` | Player UI, loading/error overlays | Styling, adding player controls |
| `docker-compose.yml` | Docker service config (ports, volumes, environment) | Changing ports, adding volumes |
| `streaming/mediamtx.yml` | MediaMTX server config (paths, auth, recording) | Enabling recording, changing auth |
| `ARCHITECTURE.md` | Detailed MVVM architecture overview | Reference for understanding design decisions |
| `DEPLOYMENT_GUIDE.md` | Multi-machine deployment instructions | Deploying to new servers |
| `FEATURES_ROADMAP.md` | Planned features ranked by priority/impact | Understanding feature priorities |

---

## Critical Context

### Retry & Timeout Strategy

**PlaybackViewModel** uses aggressive retry logic for HLS playback:
- **Load Timeout**: 3 seconds per attempt
- **Stall Timeout**: 2 seconds for recovery
- **Max Retries**: 2 attempts before failure
- **Retry Backoff**: 1–2 seconds between attempts

This ensures the app fails fast and cleanly rather than hanging indefinitely.

### AVPlayer Configuration

- `allowsExternalPlayback = true` — Enables AirPlay, HDMI casting
- `automaticallyWaitsToMinimizeStalling = true` — Allows intelligent buffering for HLS
- All player state changes observed via KVO (playback status, buffering, errors)

### Threading Model

- **Main Thread**: All UI updates, `@Published` property changes
- **Background**: KVO observations (via Combine), but callbacks always deliver on main thread
- **Guarantee**: No manual `DispatchQueue.main.async` calls needed in Views — Worker ensures main-thread delivery

### Session URL Cleaning

iOS HLS playback may append session parameters (`?session=...`) to stream URLs. The app detects and strips these for MediaMTX compatibility.

---

## Performance & Debugging Tips

1. **Check Buffering**: If `bufferingCount` keeps incrementing, network is slow or server is lagging
2. **Resolution/Bitrate**: Debug panel shows current quality; watch it change as network conditions fluctuate
3. **Logs**: Search `os.Logger` output for `[playback]` category to filter app-specific logs
4. **Server Health**: `./streaming.sh logs` shows real-time connection counts and stream status
5. **Network Latency**: Use RTSP (port 8554) for low-latency testing; HLS has inherent buffering delay

---

## Gotchas & Known Issues

- **URL Session Parameters**: HLS can append `?session=UUID`. The app strips these, but some servers may reject stripped URLs. Verify with direct curl test.
- **Audio Track Mismatch**: If server publishes H.264 video + audio, but iOS app expects different codec, playback may hang. Check server logs for track info.
- **Firewall**: All 5 protocols (RTMP, RTSP, HLS, WebRTC, SRT) need open ports. Don't forget UDP for SRT, RTP/RTCP.
- **Docker on Mac**: Uses bridge network; `localhost` works from host, but cross-machine access requires actual IP (not `localhost:8888`).

---

## Next Steps / Future Work

See **FEATURES_ROADMAP.md** for detailed feature proposals. Priority features:

1. **Playback Controls** — Play/Pause, seek bar, speed control (1 day effort)
2. **Quality Selection** — Manual bitrate switching (1–2 days)
3. **Network Status Indicator** — WiFi strength, connection type (0.5 days)
4. **Gesture Controls** — Swipe to seek, double-tap to play (1 day)
5. **Picture-in-Picture** — Multitasking while streaming (1 day)

---

---

## Documentation Standards

### Markdown File Headers (REQUIRED)

All `.md` files MUST start with a modification header:

```
Last Modified: MM/DD/YYYY (UNIX_TIMESTAMP) by USERNAME

[Rest of document content...]
```

**Example:**
```
Last Modified: 08/10/2026 (1786502400) by amonrit

# Document Title
```

**Details:**
- Date format: `MM/DD/YYYY` (e.g., `08/10/2026`)
- Unix timestamp: Current epoch seconds
- Username: Git user who made the edit
- Always on line 1, followed by blank line

**Update whenever you edit a .md file** — change date, timestamp, and your username.

For full details, see: `.claude/markdown-header-rule.md`

---

## Questions?

Refer to:
- **ARCHITECTURE.md** — Deep dive into MVVM structure
- **DEPLOYMENT_GUIDE.md** — Multi-machine setup
- **README_SETUP.md** — Quick start reference
- **FEATURES_ROADMAP.md** — Feature priorities & estimates

---
**Last Updated:** 2026-08-10 (1786357473) by amonrit

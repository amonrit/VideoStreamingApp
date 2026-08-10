# Steam — iOS Video Streaming App

[![GitHub](https://img.shields.io/badge/GitHub-amonrit/VideoStreamingApp-blue?logo=github)](https://github.com/amonrit/VideoStreamingApp)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange?logo=swift)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-15%2B-blue?logo=apple)](https://www.apple.com/ios)
[![Docker](https://img.shields.io/badge/Docker-MediaMTX_v1.20-2496ED?logo=docker)](https://hub.docker.com)
[![Architecture](https://img.shields.io/badge/Architecture-MVVM-green)]()

A production-ready iOS video streaming application with a self-hosted streaming server. Publish live streams via RTMP and play them back on iOS devices using HLS, RTSP, or WebRTC.

---

## ✨ Features

### iOS App
- 🎬 **HLS Video Playback** — Native AVPlayer with adaptive bitrate
- 🔄 **Auto-Retry Logic** — Handles network interruptions gracefully  
- 📊 **Debug Metrics** — Real-time resolution, bitrate, and buffering stats
- 🖥️ **Fullscreen Mode** — Native iOS fullscreen player experience
- 🏗️ **MVVM Architecture** — Clean, testable, maintainable code

### Streaming Server
- 📤 **Multi-Protocol Publishing** — RTMP, RTSP, HLS, WebRTC, SRT
- 🌐 **Network-Accessible** — Stream from any machine on your network
- 🐳 **Docker Deployment** — One command to deploy anywhere
- 📁 **Portable Config** — Same setup works on any machine
- 🔄 **Auto-Restart** — Keep streaming even after reboot

---

## 🚀 Quick Start

### Prerequisites
- macOS with Xcode 14+ (for iOS app)
- Docker & Docker Compose (for streaming server)
- iOS 15+ device or simulator

### Start Streaming Server (60 seconds)

```bash
cd steam/streaming
docker-compose up -d
```

**Verify it's running:**
```bash
docker-compose ps
```

You should see `mediamtx` container with status `Up`.

### Build & Run iOS App

```bash
open steam.xcodeproj
# Select iPhone simulator or device
# Press Cmd+R to build and run
```

**Update server IP in the app:**
- Get your server IP: `ifconfig | grep "inet " | grep -v 127.0.0.1`
- In iOS app, find the sample stream URL and replace the IP
- Hit play!

---

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| **[CLAUDE.md](./CLAUDE.md)** | Development guide for AI assistants & engineers |
| **[ARCHITECTURE.md](./ARCHITECTURE.md)** | Deep dive into MVVM architecture & data flow |
| **[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)** | Deploy server to production/new machines |
| **[FEATURES_ROADMAP.md](./FEATURES_ROADMAP.md)** | Planned features & priorities |
| **[README_SETUP.md](./README_SETUP.md)** | Quick reference for common tasks |

---

## 🎯 Use Cases

### Development & Testing
- Test HLS playback on iOS without a cloud service
- Publish from OBS Studio or FFmpeg locally
- Debug network issues with full server access

### Home Streaming
- Stream from your Mac to iOS devices
- Perfect for presentations, demos, or home surveillance
- Works across your local network

### Live Events
- Multi-protocol support (RTMP, HLS, RTSP, WebRTC)
- Automatic recording to disk
- Portable — deploy on Raspberry Pi, NAS, or cloud VMs

---

## 🔧 Common Tasks

### Publish a Test Stream

**Using FFmpeg:**
```bash
ffmpeg -re -i video.mp4 -c copy -f flv \
  rtmp://YOUR_IP:1935/live/mystream
```

**Using OBS Studio:**
1. Settings → Stream
2. Service: Custom
3. Server: `rtmp://YOUR_IP:1935/live`
4. Stream Key: `mystream`
5. Start Streaming

### Watch the Stream

**iOS App:**
- Change URL to: `http://YOUR_IP:8888/live/mystream/index.m3u8`
- Hit Play

**VLC (Any device):**
- Media → Open Network Stream
- URL: `http://YOUR_IP:8888/live/mystream/index.m3u8`

**Web Browser:**
```html
<video controls width="800">
  <source src="http://YOUR_IP:8888/live/mystream/index.m3u8" type="application/x-mpegURL">
</video>
```

### Control the Server

```bash
./streaming.sh start                # Start server
./streaming.sh stop                 # Stop server
./streaming.sh restart              # Restart (after config change)
./streaming.sh status               # Check if running
./streaming.sh logs                 # View live logs
./streaming.sh test                 # Run verification tests
```

---

## 🏗️ Architecture Overview

### iOS App (MVVM)

```
ContentView (Root UI)
  ├─ VideoPlayerView (Player + Controls)
  ├─ Stream List (Add/Select streams)
  └─ Debug Panel (Metrics)
       ↓ observe
PlaybackViewModel
  ├─ Loads streams
  ├─ Manages AVPlayer playback
  ├─ Handles errors & retries
  └─ Coordinates with Workers
       ↓ uses
VideoPlayerWorker
  ├─ KVO observers (status, buffering, errors)
  └─ Format extraction (resolution, bitrate)
```

**Why MVVM?**
- Single source of truth (ViewModel owns all state)
- Testable business logic (no UI dependencies)
- SwiftUI-native binding (`@Published` → `@ObservedObject`)
- No scaffolding (cleaned up from previous VIPER architecture)

### Streaming Server

```
Publisher (OBS, FFmpeg, etc.)
  ↓ RTMP
MediaMTX (Docker)
  ├─ RTMP Port 1935 (Publishing)
  ├─ HLS Port 8888 (HLS playback)
  ├─ RTSP Port 8554 (Low-latency)
  ├─ WebRTC Port 8889 (Browser)
  └─ SRT Port 8890 (Backup)
       ↓
iOS App (Consumer)
```

---

## 📊 Streaming Protocols

| Protocol | Port | Latency | Use Case |
|----------|------|---------|----------|
| **RTMP** | 1935 | Low (~1s) | Publishing from OBS/FFmpeg |
| **RTSP** | 8554 | Very Low (<1s) | Live monitoring, IP cameras |
| **HLS** | 8888 | Medium (5-10s) | iOS/Web playback, compatibility |
| **WebRTC** | 8889 | Ultra Low (<1s) | Browser-based, interactive |
| **SRT** | 8890 | Low (~1s) | High-quality backup links |

---

## 🐛 Troubleshooting

### iOS App Won't Connect
- **Check server IP**: `ifconfig | grep "inet "`
- **Test HLS URL**: `curl -v http://YOUR_IP:8888/live/mystream/index.m3u8`
- **Check firewall**: Allow port 8888 in macOS Firewall

### Server Won't Start
```bash
docker-compose logs mediamtx
```
Check for error messages. Common issues:
- Port already in use: `lsof -i :1935`
- Config error: `streaming/mediamtx.yml` has invalid YAML

### Stream Buffering
- **Server side**: Check logs for connection issues: `./streaming.sh logs`
- **Network side**: Use `ping YOUR_IP` to check latency
- **Client side**: iOS app debug panel shows bitrate; if too low, reduce publisher bitrate

### No Video Appearing
1. Ensure stream is publishing: Check logs
2. Verify stream name is `live/mystream` (or update app URL)
3. Wait 1-2 seconds for HLS segments to generate
4. Clear browser cache or restart iOS app

---

## 📱 System Requirements

| Component | Requirement |
|-----------|-------------|
| **iOS App** | iOS 15+, Xcode 14+, Swift 5.9+ |
| **Streaming Server** | Docker, Docker Compose, 100MB disk |
| **Network** | Local network (same WiFi) |

---

## 🚀 Deployment

Deploy the streaming server to:
- ✅ **Mac Mini** — Always-on home server
- ✅ **Raspberry Pi** — Ultra low power
- ✅ **NAS** — Built-in Docker support
- ✅ **Linux VPS** — Cloud streaming
- ✅ **Docker Swarm** — Scale to multiple machines

See **[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)** for step-by-step instructions.

---

## 💡 Tips & Best Practices

1. **Use HLS for iOS** — Most compatible, handles buffering well
2. **Use RTSP for Real-time** — Lowest latency (<1s)
3. **Monitor Network** — App debug panel shows bitrate trends
4. **Enable Recording** — Uncomment `record: true` in `streaming/mediamtx.yml`
5. **Secure Publishing** — Change `publishPass` in `mediamtx.yml` for production

---

## 📖 For Developers

Start with **[CLAUDE.md](./CLAUDE.md)** for architecture, commands, and workflows.

### Adding Features

1. **Playback Controls** — Pause, seek, speed (estimated 1 day)
2. **Quality Selection** — Manual bitrate switching (1–2 days)
3. **Picture-in-Picture** — Multitask while watching (1 day)
4. **Subtitles** — VTT/SRT support (2–3 days)
5. **Offline Download** — Cache for offline viewing (3–4 days)

See **[FEATURES_ROADMAP.md](./FEATURES_ROADMAP.md)** for full list and priorities.

---

## 🤝 Contributing

Improvements welcome! Key areas:
- Playback controls (pause, seek, speed)
- Quality selection UI
- Gesture controls (swipe to seek)
- Network monitoring
- Debug dashboard enhancements

---

## 📝 License

[Add your license here — MIT recommended]

---

## 🙌 Acknowledgments

- [MediaMTX](https://github.com/bluenviron/mediamtx) — Streaming server
- [AVFoundation](https://developer.apple.com/avfoundation) — iOS video playback
- [SwiftUI](https://developer.apple.com/swiftui) — iOS UI framework

---

## 📞 Support

For questions or issues:
1. Check **[README_SETUP.md](./README_SETUP.md)** for common tasks
2. Review **[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)** for server setup
3. Search **[ARCHITECTURE.md](./ARCHITECTURE.md)** for design decisions
4. Check streaming server logs: `./streaming.sh logs`
5. View app logs in Xcode Console

**Ready to stream!** 🎬

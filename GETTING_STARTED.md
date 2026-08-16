Last Modified: 08/17/2026 (1786901984) by amonrit

# 🚀 Getting Started — 5 Minutes

Your **one-stop setup guide** for the Steam project. Follow this once, then jump into [docs/DEVELOPMENT.md](./docs/DEVELOPMENT.md) for deeper work.

---

## ✅ Prerequisites

Check you have:
- **macOS** with Xcode 14+ (for iOS app)
- **Docker & Docker Compose** (for streaming server)
- **iOS 15+** simulator or device (optional)

**Don't have Docker?**
```bash
brew install docker
brew install docker-compose
```

---

## 🔐 Step 1: Setup Environment Configuration (1 minute)

The streaming server needs credentials for authentication. Copy the configuration template:

```bash
# Navigate to streaming folder
cd steam/streaming

# Copy configuration from example
cp .env.example .env.local

# Optional: Edit credentials if you want custom values
# nano .env.local  (or use your preferred editor)
```

**What's in `.env.local`?**
- `API_VIEWER_PASS` — Password for accessing stream metrics (default: `changeme123`)
- `PUBLISH_PASS` — Password for publishing streams (default: `streampass123`)
- Other server settings (ports, timeouts, recording options)

**Important:** `.env.local` is in `.gitignore` — your credentials won't be committed to git.

---

## 📍 Step 2: Start the Streaming Server (2 minutes)

The server publishes and plays streams via multiple protocols (RTMP, RTSP, HLS, WebRTC, SRT).

```bash
# Navigate to streaming folder
cd steam/streaming

# Start server (Docker)
docker-compose up -d

# Verify it's running
docker-compose ps
```

You should see `mediamtx` with status **"Up"**.

**Server is now running on:**
- HLS (playback): `http://localhost:8888/live/mystream/index.m3u8`
- RTMP (publish): `rtmp://localhost:1935/live/mystream`
- RTSP: `rtsp://localhost:8554/live/mystream`

---

## 🎬 Step 3: Open iOS App in Xcode (1 minute)

```bash
# From project root
open steam.xcodeproj
```

**What you'll see:**
- Project navigator on the left
- File browser in the middle
- iPhone simulator option in top-left

**Build & run:**
1. Select **iPhone 15 simulator** (or your device)
2. Press **Cmd+R** (or click ▶ Play button)
3. Wait for build (~30 seconds)
4. App opens on simulator

---

## 📤 Step 4: Publish a Test Stream (1 minute)

From a **separate terminal**, publish a video or screen:

**Option A: Publish a video file (if you have one)**
```bash
ffmpeg -re -i video.mp4 -c copy -f flv \
  rtmp://localhost:1935/live/mystream
```

**Option B: Publish your screen (macOS)**
```bash
ffmpeg -f avfoundation -i "1" -c:v libx264 -c:a aac \
  -f flv rtmp://localhost:1935/live/mystream
```

**Option C: No stream? That's okay** — Server runs empty, iOS app handles gracefully

---

## ▶️ Step 5: Play Stream on iOS App (1 minute)

In iOS app:
1. Tap the stream from the list (or enter URL manually)
2. Stream URL: `http://localhost:8888/live/mystream/index.m3u8`
3. Tap **Play**

**What you'll see:**
- Loading spinner while buffering
- Video playback (if a stream is publishing)
- Debug info: resolution, bitrate, buffering count
- Fullscreen button for immersive view

**If stream isn't showing:**
- Check server is running: `docker-compose ps` (from streaming folder)
- Check publishing: Any errors in FFmpeg terminal?
- See [docs/DEVELOPMENT.md](./docs/DEVELOPMENT.md) → Debugging section

---

## ✨ You're Done!

Everything is working. Now:

| What's Next | Read |
|-------------|------|
| **Develop new features** | [docs/DEVELOPMENT.md](./docs/DEVELOPMENT.md) |
| **Understand architecture** | [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) |
| **Deploy to another machine** | [docs/DEPLOYMENT.md](./docs/DEPLOYMENT.md) |
| **Learn commit workflow** | [docs/COMMIT_GUIDE.md](./docs/COMMIT_GUIDE.md) |
| **Use AI to help** | [docs/AI_WORKFLOW.md](./docs/AI_WORKFLOW.md) |
| **All documentation** | [DOCUMENTATION.md](./DOCUMENTATION.md) |

---

## 🆘 Troubleshooting

### Server won't start
```bash
# Check Docker is running
docker ps

# See errors
cd streaming && docker-compose logs mediamtx

# Restart fresh
docker-compose down && docker-compose up -d
```

### iOS app won't connect
- Use actual IP (not `localhost`) if on different machine
- Get IP: `ifconfig | grep "inet " | grep -v 127.0.0.1`
- Update URL in app: `http://YOUR_IP:8888/live/mystream/index.m3u8`

### Stream publishing fails
- Check RTMP port is open: `netstat -an | grep 1935`
- See server logs: `cd streaming && docker-compose logs -f mediamtx`

**More help:** [docs/DEVELOPMENT.md](./docs/DEVELOPMENT.md) → Debugging

---

**Happy streaming! 🎬**
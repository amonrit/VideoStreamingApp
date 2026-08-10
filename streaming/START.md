Last Modified: 08/10/2026 (1786502400) by amonrit

# 🎬 MediaMTX Live Streaming Server

Personal live streaming server setup using Docker and MediaMTX.

## ⚡ Quick Start

### 1. First Time Setup

```bash
cd streaming/
docker-compose up -d
```

The server will start with all protocols enabled:
- **RTMP** (1935) - for publishing from OBS/FFmpeg
- **HLS** (8888) - for web/mobile playback
- **RTSP** (8554) - for low-latency streaming
- **WebRTC** (8889) - for ultra-low latency
- **SRT** (8890) - secure streaming

### 2. Verify Server is Running

```bash
./quick-test.sh
```

### 3. Publish a Stream

**Using FFmpeg:**
```bash
# Install FFmpeg first
brew install ffmpeg

# Publish from video file
ffmpeg -i video.mp4 -c copy -f flv rtmp://localhost:1935/live/mystream

# Publish from screen (macOS)
ffmpeg -f avfoundation -i "1:" -c:v libx264 -preset veryfast \
  -c:a aac -f flv rtmp://localhost:1935/live/mystream
```

**Using OBS Studio:**
- Settings → Stream
- Service: Custom
- Server: `rtmp://localhost:1935/live`
- Stream Key: `mystream`
- Start Streaming

### 4. Watch the Stream

**VLC Media Player:**
- Media → Open Network Stream
- `http://localhost:8888/live/mystream/index.m3u8`

**Web Browser (HTML5):**

```html
<video controls width="800">
  <source src="http://localhost:8888/live/mystream/index.m3u8" type="application/x-mpegURL">
</video>
```

Or use an HLS player library like [hls.js](https://github.com/video-dev/hls.js)

## 📂 Files Overview

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Docker container configuration |
| `mediamtx.yml` | MediaMTX server settings |
| `quick-test.sh` | Quick verification script |
| `test-streaming.sh` | Full test suite |
| `README_STREAMING.md` | Complete guide with examples |
| `STREAMING_SETUP.md` | Detailed setup & troubleshooting |
| `QUICK_REFERENCE.md` | Command cheatsheet |
| `recordings/` | Recorded stream storage |

## 🎮 Common Commands

```bash
# Navigate to streaming folder
cd streaming/

# Start server
docker-compose up -d

# Stop server
docker-compose down

# View live logs
docker-compose logs -f mediamtx

# Restart after config changes
docker-compose restart

# Check status
docker ps --filter "name=mediamtx"

# View server info
./quick-test.sh
```

## 🎯 Stream URLs

Replace `mystream` with your stream name:

| Protocol | URL |
|----------|-----|
| RTMP | `rtmp://localhost:1935/live/mystream` |
| RTSP | `rtsp://localhost:8554/live/mystream` |
| HLS | `http://localhost:8888/live/mystream/index.m3u8` |
| WebRTC | `http://localhost:8889/live/mystream` |
| SRT | `srt://localhost:8890?streamid=mystream` |

## 🔐 Add Password Protection

Edit `mediamtx.yml` and find the `live` path:

```yaml
paths:
  live:
    publishUser: publish
    publishPass: yourpassword
```

Then restart:
```bash
docker-compose restart
```

Publish with authentication:
```bash
ffmpeg -i video.mp4 -c copy -f flv \
  "rtmp://publish:yourpassword@localhost:1935/live/mystream"
```

## 📊 Enable Recording

Edit `mediamtx.yml`:

```yaml
paths:
  live:
    record: true
    recordFormat: fmp4
    recordPath: ./recordings/%path%/%Y%m%d_%H%M%S-frag.mp4
```

Restart:
```bash
docker-compose restart
```

Recordings save to `recordings/` folder

## 🔧 Configuration

### Change HLS Latency

In `mediamtx.yml`, adjust:
```yaml
hls:
  variant: lowLatency  # Lower latency but requires more bandwidth
  segmentDuration: 1s  # Shorter = lower latency
  segmentCount: 3      # Fewer = lower latency but less buffering
```

### Change Authentication

In `mediamtx.yml`, for each path:
```yaml
publishUser: publish      # Username for publishing
publishPass: password     # Password for publishing
readUser: ''              # Username for reading (optional)
readPass: ''              # Password for reading (optional)
```

## 🐛 Troubleshooting

**Port already in use:**
```bash
lsof -i :1935
kill -9 <PID>
```

**Container won't start:**
```bash
docker-compose logs mediamtx
```

**No HLS segments (no video showing):**
1. Check stream is publishing: `docker-compose logs mediamtx`
2. Verify correct URL with stream name
3. Wait 1-2 seconds for segments to generate
4. Clear browser cache

**Connection refused:**
- Ensure container is running: `docker ps`
- Check firewall settings
- Verify correct port in URL

## 📚 More Documentation

- **README_STREAMING.md** - Complete user guide
- **STREAMING_SETUP.md** - Advanced setup & security
- **QUICK_REFERENCE.md** - Quick command reference
- [MediaMTX GitHub](https://github.com/bluenviron/mediamtx)

## 💡 Tips

1. **Low Latency**: Use RTSP or WebRTC for under 1-second latency
2. **Web Playback**: Use HLS for best compatibility
3. **Multiple Streams**: Create different path names (e.g., `stream1`, `stream2`)
4. **Auto-Start**: `docker-compose up -d` with `restart: unless-stopped`
5. **Monitoring**: Check `docker-compose logs -f` for real-time info

---

**Ready to stream!** 🎥 Start with `docker-compose up -d` in this directory.
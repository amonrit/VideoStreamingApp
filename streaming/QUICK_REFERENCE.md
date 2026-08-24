Last Modified: 08/24/2026 (1787587709) by amonrit

# MediaMTX Quick Reference Guide

## 🚀 Start/Stop Commands

```bash
# Start the server
docker-compose up -d

# Stop the server
docker-compose down

# View live logs
docker-compose logs -f mediamtx

# Restart (after config changes)
docker-compose restart
```

Or via `make` from the project root: `make dev-server`, `make server-stop`, `make server-logs`, `make server-restart`, `make server-status`, `make server-test`.

## ✅ Verify It's Running

```bash
docker-compose ps
./quick-test.sh
```

## 📤 Quick Publish Examples

### FFmpeg from Video File
```bash
ffmpeg -i myVideo.mp4 -c copy -f flv \
  rtmp://publish:streampass123@localhost:1935/live/mystream
```

### FFmpeg Screen Capture (macOS)
```bash
ffmpeg -f avfoundation -i "1:" \
  -c:v libx264 -preset veryfast -c:a aac \
  -f flv rtmp://publish:streampass123@localhost:1935/live/mystream
```

### OBS Studio
- Service: Custom
- Server: `rtmp://localhost:1935/live`
- Stream Key: `mystream`

## 📺 Quick View Examples

### VLC Media Player
```
Media → Open Network Stream
http://localhost:8888/live/mystream/index.m3u8
```

### FFplay Command Line
```bash
ffplay 'http://localhost:8888/live/mystream/index.m3u8'
```

### Web Browser (HTML5)
```html
<video controls width="800">
  <source src="http://localhost:8888/live/mystream/index.m3u8" type="application/x-mpegURL">
</video>
```
Or use an HLS player library like [hls.js](https://github.com/video-dev/hls.js).

## 🔐 Default Credentials

```
Username: publish
Password: streampass123
```

**To change:** edit `.env.local` (see `docs/CREDENTIAL_SETUP.md`) and restart the container — don't hardcode a new value into `mediamtx.yml` or any script.

## 📍 All Protocol URLs

| Protocol | URL |
|----------|-----|
| RTMP | `rtmp://publish:streampass123@localhost:1935/live/mystream` |
| RTSP | `rtsp://publish:streampass123@localhost:8554/live/mystream` |
| HLS | `http://localhost:8888/live/mystream/index.m3u8` |
| WebRTC | `http://localhost:8889/live/mystream` |
| SRT | `srt://localhost:8890?streamid=mystream` |

## 🧪 Test Your Setup

```bash
./test-streaming.sh
```

This will:
- Check if server is running
- Generate test video
- Publish test stream
- Verify HLS playback
- Show configuration details

## 📊 Enable Recording

Edit `mediamtx.yml`:

```yaml
paths:
  live:
    record: true
    recordFormat: fmp4
    recordPath: ./recordings/%path%/%Y%m%d_%H%M%S-frag.mp4
```

Restart the container. Recordings save to `recordings/`.

## ⚙️ Configuration

Edit `mediamtx.yml` to:
- Change credentials (via `.env.local`, not hardcoded)
- Enable/disable protocols
- Configure recording
- Tune HLS latency:
  ```yaml
  hls:
    variant: lowLatency  # Lower latency but requires more bandwidth
    segmentDuration: 1s  # Shorter = lower latency
    segmentCount: 3      # Fewer = lower latency but less buffering
  ```

**After editing**, restart:
```bash
docker-compose restart
```

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| Port in use | `lsof -i :1935` then `kill -9 <PID>` |
| Auth failure | Verify credentials match `.env.local` |
| No streams | Check publisher connection, view logs |
| Container won't start | `docker-compose logs mediamtx` |
| No HLS segments (no video) | Wait 1-2s for segments; verify stream name matches the URL |

## 📁 File Structure

```
.
├── docker-compose.yml               # Docker configuration
├── mediamtx.yml                     # MediaMTX server config
├── .env.example / .env.local        # Credentials (local is gitignored)
├── test-streaming.sh                # Full test script
├── quick-test.sh                    # Quick verification script
├── FFMPEG_SETUP.md                  # FFmpeg transcoding setup
├── TESTING_FFMPEG_TRANSCODING.md    # Transcoding test procedures
├── QUICK_REFERENCE.md               # This file
└── recordings/                      # (Created) Recordings directory
```

## 🔗 Important Links

- MediaMTX: https://github.com/bluenviron/mediamtx
- Docker Docs: https://docs.docker.com/
- HLS Player: https://hls-js.netlify.app/
- [docs/DEPLOYMENT.md](../docs/DEPLOYMENT.md) — deploying this server to another machine
- [docs/CREDENTIAL_SETUP.md](../docs/CREDENTIAL_SETUP.md) — setting up `.env.local` credentials

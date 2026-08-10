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

## 🔐 Default Credentials

```
Username: publish
Password: streampass123
```

**To change:** Edit `mediamtx.yml` and restart container

## 📍 All Protocol URLs

| Protocol | URL |
|----------|-----|
| RTMP | `rtmp://publish:streampass123@localhost:1935/live/mystream` |
| RTSP | `rtsp://publish:streampass123@localhost:8554/live/mystream` |
| HLS | `http://localhost:8888/live/mystream/index.m3u8` |
| WebRTC | `http://localhost:8889/live/mystream` |

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

## ⚙️ Configuration

Edit `mediamtx.yml` to:
- Change credentials
- Enable/disable protocols
- Configure recording
- Set up advanced features

**After editing**, restart:
```bash
docker-compose restart
```

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| Port in use | `lsof -i :1935` then `kill -9 <PID>` |
| Auth failure | Verify credentials in `mediamtx.yml` |
| No streams | Check publisher connection, view logs |
| Container won't start | `docker-compose logs mediamtx` |

## 📁 File Structure

```
.
├── docker-compose.yml          # Docker configuration
├── mediamtx.yml               # MediaMTX server config
├── test-streaming.sh          # Test script
├── STREAMING_SETUP.md         # Full documentation
├── QUICK_REFERENCE.md         # This file
└── recordings/                # (Created) Recordings directory
```

## 🔗 Important Links

- MediaMTX: https://github.com/bluenviron/mediamtx
- Docker Docs: https://docs.docker.com/
- HLS Player: https://hls-js.netlify.app/

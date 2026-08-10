# 🎬 Personal Live Streaming Server

Your MediaMTX live streaming server has been organized and is ready to use!

## 📂 Project Structure

```
steam/
├── streaming/                     ← All streaming files here
│   ├── docker-compose.yml         ← Container configuration
│   ├── mediamtx.yml              ← Server settings
│   ├── START.md                  ← Quick start guide (READ THIS FIRST!)
│   ├── README_STREAMING.md       ← Complete documentation
│   ├── STREAMING_SETUP.md        ← Advanced setup & troubleshooting
│   ├── QUICK_REFERENCE.md        ← Command cheatsheet
│   ├── quick-test.sh             ← Quick verification
│   ├── test-streaming.sh         ← Full test suite
│   ├── .gitignore                ← Git ignore rules
│   └── recordings/               ← Stream recordings storage
│
├── streaming.sh                   ← Easy control script (use this!)
├── STREAMING_README.md           ← This file
│
├── steam/                         ← Main iOS/Swift project
│   ├── Views/
│   ├── ViewModels/
│   ├── Models/
│   ├── Workers/
│   └── Assets.xcassets/
│
└── steam.xcodeproj/              ← Xcode project
```

## ⚡ Quick Start

### Option 1: Using the Control Script (Recommended)

From the main `steam/` directory:

```bash
# Start server
./streaming.sh start

# Check status
./streaming.sh status

# View live logs
./streaming.sh logs

# Run verification test
./streaming.sh test

# Stop server
./streaming.sh stop

# Get help
./streaming.sh help
```

### Option 2: Direct Docker Commands

From the `streaming/` directory:

```bash
cd streaming/

# Start server
docker-compose up -d

# Stop server
docker-compose down

# View logs
docker-compose logs -f mediamtx

# Restart
docker-compose restart
```

## 🎯 Using Your Streaming Server

### 1. Install FFmpeg (if not already installed)

```bash
brew install ffmpeg
```

### 2. Publish a Stream

**From video file:**
```bash
ffmpeg -i video.mp4 -c copy -f flv rtmp://localhost:1935/live/mystream
```

**From screen (macOS):**
```bash
ffmpeg -f avfoundation -i "1:" -c:v libx264 -preset veryfast -c:a aac \
  -f flv rtmp://localhost:1935/live/mystream
```

**From webcam (macOS):**
```bash
ffmpeg -f avfoundation -i "0:0" -c:v libx264 -preset veryfast -c:a aac \
  -f flv rtmp://localhost:1935/live/mystream
```

**Using OBS Studio:**
- Settings → Stream
- Service: Custom
- Server: `rtmp://localhost:1935/live`
- Stream Key: `mystream`
- Start Streaming

### 3. Watch the Stream

**VLC Media Player:**
- Media → Open Network Stream
- Enter: `http://localhost:8888/live/mystream/index.m3u8`
- Click Play

**Web Browser:**

```html
<!DOCTYPE html>
<html>
<head>
    <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
</head>
<body>
    <video id="video" controls width="800" height="600"></video>
    <script>
        const hls = new Hls();
        hls.loadSource('http://localhost:8888/live/mystream/index.m3u8');
        hls.attachMedia(document.getElementById('video'));
        hls.play();
    </script>
</body>
</html>
```

**Command Line:**
```bash
ffplay 'http://localhost:8888/live/mystream/index.m3u8'
```

## 📡 All Stream URLs

Replace `mystream` with your stream name:

| Protocol | URL | Latency | Best For |
|----------|-----|---------|----------|
| **RTMP** | `rtmp://localhost:1935/live/mystream` | 3-5s | Publishing (OBS/FFmpeg) |
| **HLS** | `http://localhost:8888/live/mystream/index.m3u8` | 6-10s | Web/Mobile playback |
| **RTSP** | `rtsp://localhost:8554/live/mystream` | 1-2s | Low-latency viewing |
| **WebRTC** | `http://localhost:8889/live/mystream` | <1s | Ultra-low latency |
| **SRT** | `srt://localhost:8890?streamid=mystream` | 1-2s | Reliable transport |

## 🔐 Add Password Protection

Edit `streaming/mediamtx.yml` and find the `live` path section:

```yaml
paths:
  live:
    publishUser: publish
    publishPass: yoursecurepassword
```

Then restart:
```bash
./streaming.sh restart
```

Publish with authentication:
```bash
ffmpeg -i video.mp4 -c copy -f flv \
  "rtmp://publish:yoursecurepassword@localhost:1935/live/mystream"
```

## 📚 Documentation

Read these in order:

1. **START.md** (in `streaming/` folder) - Quick start guide
2. **README_STREAMING.md** - Complete usage guide with examples
3. **STREAMING_SETUP.md** - Advanced configuration & troubleshooting
4. **QUICK_REFERENCE.md** - Command cheatsheet

## 🎮 Essential Commands

```bash
# Start streaming server
./streaming.sh start

# Check if server is running
./streaming.sh status

# View live logs (Ctrl+C to exit)
./streaming.sh logs

# Restart after config changes
./streaming.sh restart

# Run verification test
./streaming.sh test

# Stop streaming server
./streaming.sh stop

# Open bash in streaming directory
./streaming.sh shell

# Get help
./streaming.sh help
```

## 📊 Server Status

Check your server with:

```bash
./streaming.sh status
```

This shows:
- Container status (running/stopped)
- All exposed ports
- Protocol endpoints

## 🐛 Common Issues

| Issue | Solution |
|-------|----------|
| Port already in use | `lsof -i :1935` then `kill -9 <PID>` |
| Container won't start | `./streaming.sh logs` to see errors |
| No video showing | Wait 1-2 seconds for HLS segments to generate |
| Connection refused | Ensure server is running with `./streaming.sh status` |
| Authentication failed | Check credentials in `streaming/mediamtx.yml` |

## 💾 Recording Streams

Edit `streaming/mediamtx.yml`:

```yaml
paths:
  live:
    record: true
    recordPath: ./recordings/%path%/%Y%m%d_%H%M%S-frag.mp4
```

Restart:
```bash
./streaming.sh restart
```

Recordings save to `streaming/recordings/`

## 🌐 Access from Other Devices

### Same Network (WiFi)

Replace `localhost` with your computer's IP address (e.g., `192.168.1.100`):

```
http://192.168.1.100:8888/live/mystream/index.m3u8
```

Find your IP:
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
```

### Different Network (Internet)

You'll need:
1. Port forwarding on your router
2. SSL/TLS encryption
3. Strong authentication
4. Or use a reverse proxy like ngrok

## 📁 File Descriptions

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Docker container setup and configuration |
| `mediamtx.yml` | MediaMTX server settings and authentication |
| `quick-test.sh` | Quick verification that server is working |
| `test-streaming.sh` | Full test suite (requires FFmpeg) |
| `START.md` | Getting started guide |
| `README_STREAMING.md` | Complete documentation |
| `STREAMING_SETUP.md` | Advanced configuration guide |
| `QUICK_REFERENCE.md` | Quick command reference |
| `streaming.sh` | Control script (in main directory) |
| `.gitignore` | Excludes recordings and config from git |

## 🔗 Useful Links

- [MediaMTX GitHub](https://github.com/bluenviron/mediamtx)
- [Docker Documentation](https://docs.docker.com/)
- [HLS.js Player](https://github.com/video-dev/hls.js)
- [FFmpeg Documentation](https://ffmpeg.org/documentation.html)
- [OBS Studio](https://obsproject.com/)

## 💡 Tips

1. **Always run** `./streaming.sh start` or `docker-compose up -d` from the `streaming/` directory
2. **Multiple streams**: Create different stream names (e.g., `stream1`, `stream2`)
3. **Low latency**: Use RTSP or WebRTC protocol
4. **Web playback**: Use HLS for best compatibility
5. **Recording**: Enable in config before publishing
6. **Monitoring**: Always check logs if something doesn't work

## ✅ Server Features

✓ RTMP publishing (OBS, FFmpeg, etc.)  
✓ HLS streaming (web/mobile playback)  
✓ RTSP streaming (low-latency professional)  
✓ WebRTC streaming (ultra-low latency)  
✓ SRT streaming (reliable transport)  
✓ Stream recording (optional)  
✓ Password protection (optional)  
✓ Multiple simultaneous streams  
✓ Docker containerized (easy to deploy)  
✓ Automatic restart on failure  

---

## 🎬 Ready to Stream!

1. Run: `./streaming.sh start`
2. Publish a stream (see examples above)
3. Watch in VLC or web browser
4. Check out the documentation files for more

**Support**: Check `streaming/STREAMING_SETUP.md` for troubleshooting

**Created**: 2026-08-10  
**Server Version**: MediaMTX v1.20.0  
**Status**: ✅ Ready to Use

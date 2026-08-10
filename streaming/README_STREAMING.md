# 🎬 MediaMTX Personal Live Streaming Server

**Status**: ✅ **RUNNING** (Docker container active, all protocols enabled)

## What's Installed

A fully functional live streaming server with support for:
- **RTMP** (port 1935) - Industry standard for live broadcasting
- **RTSP** (port 8554) - Real Time Streaming Protocol for professional cameras
- **HLS** (port 8888) - HTTP Live Streaming for web/mobile playback
- **WebRTC** (port 8889) - Ultra-low latency web streaming
- **SRT** (port 8890) - Secure Reliable Transport
- **MoQ** (port 8892) - Media over QUIC

## 📂 Files Created

```
steam/
├── docker-compose.yml        ← Start/stop server with this
├── mediamtx.yml             ← Server configuration
├── quick-test.sh            ← Verify server is working
├── test-streaming.sh        ← Full test suite (requires FFmpeg)
├── STREAMING_SETUP.md       ← Detailed setup guide
├── QUICK_REFERENCE.md       ← Command cheatsheet
├── README_STREAMING.md      ← This file
└── recordings/              ← Where streams get recorded (optional)
```

## 🚀 Quick Start

### 1. Server is Already Running ✓

Container started and all ports are open. Check status:

```bash
docker-compose ps
```

### 2. Publish a Stream

**Option A: Using FFmpeg**

```bash
# Install FFmpeg first
brew install ffmpeg

# From a video file
ffmpeg -i video.mp4 -c copy -f flv \
  rtmp://localhost:1935/live/mystream

# From screen (macOS)
ffmpeg -f avfoundation -i "1:" \
  -c:v libx264 -preset veryfast -c:a aac \
  -f flv rtmp://localhost:1935/live/mystream

# From webcam (macOS)
ffmpeg -f avfoundation -i "0:0" \
  -c:v libx264 -preset veryfast -c:a aac \
  -f flv rtmp://localhost:1935/live/mystream
```

**Option B: Using OBS Studio**

1. Settings → Stream
2. Service: **Custom**
3. Server: `rtmp://localhost:1935/live`
4. Stream Key: `mystream` (or any name)
5. Click **Start Streaming**

### 3. Watch the Stream

**VLC Media Player:**
- Media → Open Network Stream
- URL: `http://localhost:8888/live/mystream/index.m3u8`
- Click Play

**Web Browser (HTML5):**

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

**Command Line (requires FFmpeg):**

```bash
ffplay 'http://localhost:8888/live/mystream/index.m3u8'
```

## 🔐 Authentication

Current setup allows **unrestricted publishing** for testing. To add password protection:

1. Edit `mediamtx.yml`
2. In the `live` path section, uncomment and set:
   ```yaml
   publishUser: publish
   publishPass: yourpassword
   ```
3. Restart: `docker-compose restart`

Then publish with:
```bash
ffmpeg -i video.mp4 -c copy -f flv \
  "rtmp://publish:yourpassword@localhost:1935/live/mystream"
```

## 📋 All Protocol URLs

| Protocol | URL | Example |
|----------|-----|---------|
| **RTMP** (publish) | `rtmp://[user:pass@]localhost:1935/live/{name}` | `rtmp://localhost:1935/live/mystream` |
| **RTSP** (low-latency) | `rtsp://[user:pass@]localhost:8554/live/{name}` | `rtsp://localhost:8554/live/mystream` |
| **HLS** (web/mobile) | `http://localhost:8888/live/{name}/index.m3u8` | `http://localhost:8888/live/mystream/index.m3u8` |
| **WebRTC** (ultra-low latency) | `http://localhost:8889/live/{name}` | `http://localhost:8889/live/mystream` |
| **SRT** | `srt://localhost:8890?streamid={name}` | `srt://localhost:8890?streamid=mystream` |

## 🎮 Common Commands

**View live logs:**
```bash
docker-compose logs -f mediamtx
```

**Stop server:**
```bash
docker-compose down
```

**Restart after config changes:**
```bash
docker-compose restart
```

**Check running container:**
```bash
docker ps --filter "name=mediamtx"
```

**Remove everything (careful!):**
```bash
docker-compose down -v
```

## ⚙️ Configuration Changes

After editing `mediamtx.yml`:

```bash
docker-compose restart
```

Key settings in `mediamtx.yml`:
- `hlsVariant` - HLS mode (lowLatency, mpegts, fmp4)
- `hlsSegmentDuration` - Segment length (lower = less latency but more load)
- `record` - Enable/disable recording
- `maxReaders` - Max concurrent viewers (0 = unlimited)
- `publishUser/publishPass` - Authentication

## 📊 Monitoring

View real-time metrics (if enabled in config):

```bash
curl http://localhost:9997/metrics
```

## 🔍 Troubleshooting

**Port already in use:**
```bash
# Find process using port 1935
lsof -i :1935

# Kill it
kill -9 <PID>
```

**Container won't start:**
```bash
docker-compose logs mediamtx
```

**Connection refused:**
- Ensure container is running: `docker ps`
- Check firewall: might be blocking ports
- Verify credentials if authentication enabled

**Stream not showing in HLS player:**
1. Verify stream is publishing (check logs)
2. Ensure correct stream name in URL
3. Wait a few seconds for HLS segments to generate
4. Clear browser cache

## 💾 Recording Streams

To enable recording:

1. Edit `mediamtx.yml`
2. Find the path you want to record
3. Change `record: false` to `record: true`
4. Restart: `docker-compose restart`

Recordings save to `./recordings/{stream_name}/`

## 🌐 Network Access

### Local Use (Current Setup)
All ports are bound to `0.0.0.0` and accessible from:
- `localhost` (same machine)
- `127.0.0.1` (same machine)
- `192.168.x.x` (local network)

### Remote Access (Needs Security Setup)
For internet access, you'll need:
1. Port forwarding or reverse proxy
2. SSL/TLS encryption
3. Strong authentication
4. Firewall rules

Example with nginx reverse proxy:
```nginx
location /live/ {
    proxy_pass http://localhost:8888;
    proxy_http_version 1.1;
    proxy_buffering off;
    proxy_request_buffering off;
    proxy_max_temp_file_size 0;
}
```

## 📚 Learning Resources

- [MediaMTX GitHub](https://github.com/bluenviron/mediamtx)
- [HLS.js - Web player library](https://github.com/video-dev/hls.js)
- [FFmpeg Documentation](https://ffmpeg.org/documentation.html)
- [OBS Studio](https://obsproject.com/)

## 🎯 Next Steps

1. **Test publishing:**
   - Install FFmpeg: `brew install ffmpeg`
   - Publish a test stream
   - Watch it in VLC or browser

2. **Set up authentication:**
   - Edit `mediamtx.yml`
   - Add username/password
   - Restart server

3. **Configure recording:**
   - Enable in `mediamtx.yml`
   - Recorded files saved to `./recordings/`

4. **Optional: Enable metrics:**
   - Uncomment `metrics` in config
   - Access at `http://localhost:9997/metrics`

5. **Optional: Setup web player:**
   - Use HLS.js example above
   - Deploy to web server
   - Access from any browser

---

**Server Version**: MediaMTX v1.20.0  
**Created**: 2026-08-10  
**Last Updated**: 2026-08-10  

Enjoy your personal live streaming server! 🎬

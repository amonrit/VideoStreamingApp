# MediaMTX Personal Live Streaming Setup

This is a complete setup for a personal live streaming server using MediaMTX (bluenviron/mediamtx) running in Docker.

## 📋 Requirements

- Docker and Docker Compose installed
- FFmpeg (optional, for testing and publishing)
- VLC or other HLS-capable media player (for viewing streams)

## 🚀 Quick Start

### 1. Start the Server

```bash
docker-compose up -d
```

This will:
- Start the MediaMTX container
- Mount the `mediamtx.yml` configuration file
- Open all necessary ports (RTMP, HLS, RTSP, WebRTC)
- Enable persistent restart

### 2. Test the Setup

```bash
./test-streaming.sh
```

This comprehensive test script will:
- Check Docker and container status
- Verify port connectivity
- Generate a test video pattern
- Publish a test stream via RTMP
- Test HLS stream access
- Display server information and logs
- Show detailed usage instructions

## 📍 Server Endpoints

| Protocol | URL | Port | Use Case |
|----------|-----|------|----------|
| **RTMP** | `rtmp://localhost:1935/live/{stream}` | 1935 | Broadcasting from OBS, FFmpeg |
| **RTSP** | `rtsp://localhost:8554/live/{stream}` | 8554 | Professional cameras, DVRs |
| **HLS** | `http://localhost:8888/live/{stream}/index.m3u8` | 8888 | Web playback, mobile viewers |
| **WebRTC** | `http://localhost:8889/live/{stream}` | 8889 | Low-latency web viewing |
| **RTP/RTCP** | 8555 (UDP) | 8555 | Raw media streaming |

## 🔐 Authentication

**Credentials:**
- Username: `publish`
- Password: `streampass123`

**To Change Credentials:**
1. Edit `mediamtx.yml`
2. Update `publishUser` and `publishPass` in the RTMP/RTSP sections
3. Update the `users` section for basic auth
4. Restart the container:
   ```bash
   docker-compose restart
   ```

## 📤 Publishing a Stream

### Option 1: Using FFmpeg

```bash
# From a video file
ffmpeg -i your_video.mp4 -c copy -f flv \
  rtmp://publish:streampass123@localhost:1935/live/mystream

# From screen capture (macOS)
ffmpeg -f avfoundation -i "1:" \
  -c:v libx264 -preset veryfast -c:a aac \
  -f flv rtmp://publish:streampass123@localhost:1935/live/mystream

# From screen capture (Linux)
ffmpeg -f x11grab -i :0 \
  -c:v libx264 -preset veryfast -c:a pulse \
  -f flv rtmp://publish:streampass123@localhost:1935/live/mystream

# From webcam and microphone (macOS)
ffmpeg -f avfoundation -i "0:0" \
  -c:v libx264 -preset veryfast -c:a aac \
  -f flv rtmp://publish:streampass123@localhost:1935/live/mystream
```

### Option 2: Using OBS Studio

1. Go to **Settings** → **Stream**
2. Set **Service** to **Custom**
3. Set **Server** to: `rtmp://localhost:1935/live`
4. Set **Stream Key** to: `mystream` (or any name you want)
5. Go to **Advanced** if you want to add authentication
6. Click **Start Streaming**

### Option 3: Using RTSP Source

For professional cameras, DVRs, or Raspberry Pi cameras:

```bash
# Relay an RTSP source to your MediaMTX server
ffmpeg -i rtsp://camera_url:554/stream \
  -c copy \
  -f flv rtmp://publish:streampass123@localhost:1935/live/mystream
```

## 📺 Watching a Stream

### Option 1: VLC Media Player

1. Open **Media** → **Open Network Stream**
2. Enter: `http://localhost:8888/live/mystream/index.m3u8`
3. Click **Play**

### Option 2: FFplay (Command Line)

```bash
ffplay 'http://localhost:8888/live/mystream/index.m3u8'
```

### Option 3: Browser (Web Player)

If you have an HLS player embedded in a web page:

```html
<!DOCTYPE html>
<html>
<head>
    <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
</head>
<body>
    <video id="video" controls width="800" height="600"></video>
    <script>
        const video = document.getElementById('video');
        const hls = new Hls();
        hls.loadSource('http://localhost:8888/live/mystream/index.m3u8');
        hls.attachMedia(video);
    </script>
</body>
</html>
```

### Option 4: RTSP Client

For low-latency viewing using RTSP:

```bash
ffplay 'rtsp://localhost:8554/live/mystream'
```

## ⚙️ Configuration Files

### `docker-compose.yml`
- Defines the Docker container setup
- Maps ports for all protocols
- Mounts the `mediamtx.yml` configuration file
- Sets up a persistent restart policy
- Creates recordings directory for optional recording

### `mediamtx.yml`
Main configuration file with sections for:
- **Global settings**: Logging, timeouts, UDP settings
- **RTSP server**: Authentication and port configuration
- **RTMP server**: Authentication and port configuration  
- **HLS server**: Variant (low-latency), segment duration, CORS
- **WebRTC server**: Web-based real-time communication
- **Paths**: Per-stream authentication and recording settings

## 📝 Common Tasks

### View Server Logs

```bash
# Real-time logs
docker-compose logs -f mediamtx

# Last 50 lines
docker-compose logs --tail 50 mediamtx
```

### Stop the Server

```bash
docker-compose down
```

### Restart After Config Changes

```bash
docker-compose restart
```

### Remove Everything (including volumes)

```bash
docker-compose down -v
```

### Check Container Status

```bash
docker ps --filter "name=mediamtx"
```

### Enable Recording

Edit `mediamtx.yml` and change:

```yaml
paths:
  all:
    record: true
    recordFormat: fmp4
    recordPath: ./recordings/%path%/%Y%m%d_%H%M%S-frag.mp4
```

Then restart:
```bash
docker-compose restart
```

Recordings will be saved to the `./recordings` directory.

### Enable Metrics (Prometheus)

Edit `mediamtx.yml` and change:

```yaml
metrics:
  enabled: true
  listenIp: 0.0.0.0
  port: 9997
```

Then restart and access metrics at: `http://localhost:9997/metrics`

## 🔒 Security Considerations

### For Local Use Only
The current setup is designed for **local network use only**. It's not suitable for exposing to the public internet without additional security measures.

### For Internet Exposure
If you plan to expose this to the internet:

1. **Use HTTPS/TLS**: Enable RTMPS and RTSPS in the config
2. **Strong Credentials**: Change default username and password in `mediamtx.yml`
3. **Firewall Rules**: Only expose necessary ports
4. **Rate Limiting**: Add rate limiting at the reverse proxy level
5. **Reverse Proxy**: Use nginx or another reverse proxy with authentication
6. **VPN**: Consider using a VPN for access from outside your network

### Example Nginx Reverse Proxy (Optional)

```nginx
upstream hls_backend {
    server localhost:8888;
}

server {
    listen 443 ssl;
    server_name streaming.example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://hls_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## 🐛 Troubleshooting

### Container won't start
```bash
# Check logs
docker-compose logs mediamtx

# Rebuild container
docker-compose down
docker-compose up -d
```

### Port already in use
```bash
# Find process using port 1935 (RTMP)
lsof -i :1935

# Kill process
kill -9 <PID>
```

### Can't connect to stream
1. Ensure container is running: `docker ps`
2. Check firewall settings
3. Verify credentials in config
4. Look at server logs: `docker-compose logs mediamtx`
5. Test connectivity: `curl -v http://localhost:8888`

### Authentication failures
- Verify credentials in `mediamtx.yml`
- Make sure container is restarted after config changes
- Check if authentication is enabled in the path settings

### No streams showing up
1. Check if publisher is sending stream
2. Verify RTMP URL and credentials are correct
3. Look for error messages in server logs
4. Try a test publish: see "Test the Setup" section above

## 📚 Additional Resources

- [MediaMTX GitHub](https://github.com/bluenviron/mediamtx)
- [MediaMTX Documentation](https://github.com/bluenviron/mediamtx/wiki)
- [RTMP Specification](https://rtmp.veriskope.com/docs/spec/)
- [HLS Specification](https://tools.ietf.org/html/draft-pantos-hls-rfc8216)
- [FFmpeg Documentation](https://ffmpeg.org/documentation.html)

## 📄 License

MediaMTX is licensed under the MPL 2.0 license. See the [MediaMTX GitHub repository](https://github.com/bluenviron/mediamtx) for details.

---

**Created**: 2026-08-10  
**Last Updated**: 2026-08-10

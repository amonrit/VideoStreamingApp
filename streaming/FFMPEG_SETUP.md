Last Modified: 08/24/2026 (1787588646) by amonrit

# FFmpeg Real-Time Transcoding Setup

## 📋 Overview

Raw RTMP input is transcoded in real time into clean 480p and 360p HLS streams.

**Architecture:**
```
RTMP Input (Live Stream)
    ↓
FFmpeg Transcoder (Docker)
    ├─ 480p output (854x480 @ 2000 kbps)
    └─ 360p output (640x360 @ 800 kbps)
    ↓
MediaMTX (HLS Server)
    ├─ /live-teststream-480p/index.m3u8
    └─ /live-teststream-360p/index.m3u8
    ↓
iOS App (Clean playback)
```

---

## 📁 File Structure

```
streaming/
├── docker-compose.yml                  # Service definitions (mediamtx + ffmpeg-transcoder)
├── mediamtx.yml                        # Path routing config
├── ffmpeg-config/
│   └── ffmpeg-transcode.sh            # Transcoding script
├── ffmpeg-manager.py                  # Process manager
├── transcode.sh                       # Wrapper: Host-side control
├── TESTING_FFMPEG_TRANSCODING.md      # Testing guide
├── FFMPEG_SETUP.md                    # This file
└── logs/
    └── ffmpeg-*.log                   # Transcoding logs
```

---

## 🚀 Quick Start

### 1. Start Services
```bash
cd streaming
docker-compose up -d
```

### 2. Publish RTMP Stream
```bash
# Option A: Using test script
bash test-streaming.sh

# Option B: Using ffmpeg with local video
ffmpeg -re -i myvideo.mp4 -c copy -f flv rtmp://localhost:1935/live/mystream
```

### 3. Start Transcoding
```bash
# From host machine:
./transcode.sh start mystream

# Or manually inside container:
docker exec ffmpeg-transcoder python3 /ffmpeg-manager.py start mystream
```

### 4. Play Stream (VLC)
```
http://localhost:8888/live-mystream-480p/index.m3u8
http://localhost:8888/live-mystream-360p/index.m3u8
```

### 5. Stop Transcoding
```bash
./transcode.sh stop mystream
```

---

## ⚙️ How It Works

### `ffmpeg-transcoder` service (`docker-compose.yml`)

- **Image:** `jrottenberg/ffmpeg:latest`
- **Depends on:** mediamtx (waits for MediaMTX to start)
- **Volumes:**
  - `./ffmpeg-config:/ffmpeg-config:ro` — Read-only access to scripts
  - `./logs:/logs` — Write logs
  - `./hls_output:/hls_output` — Store HLS segments (optional)
- **Network:** `mediamtx_network` (same as MediaMTX)
- **Resources:** 2-core CPU limit, 1 GB memory limit (1 core / 512 MB reserved)

FFmpeg runs as a persistent container (`while sleep 1`) and is controlled via bash scripts,
a Python manager (recommended), or the host-side wrapper (`transcode.sh`) — this avoids
spinning up/down containers repeatedly.

### MediaMTX path routing (`mediamtx.yml`)

```yaml
live-480p:
  source: publisher
  # FFmpeg publishes 480p RTMP here
  # Served as HLS: http://mediamtx:8888/live-480p/index.m3u8

live-360p:
  source: publisher
  # FFmpeg publishes 360p RTMP here
  # Served as HLS: http://mediamtx:8888/live-360p/index.m3u8
```

**End-to-end flow:**
1. User publishes RTMP to `/live/mystream`
2. FFmpeg reads from `rtmp://mediamtx:1935/live/mystream`
3. FFmpeg transcodes to two bitrates
4. FFmpeg publishes back to:
   - `rtmp://mediamtx:1935/live/mystream-480p`
   - `rtmp://mediamtx:1935/live/mystream-360p`
5. MediaMTX converts to HLS and serves at:
   - `http://mediamtx:8888/live-mystream-480p/index.m3u8`
   - `http://mediamtx:8888/live-mystream-360p/index.m3u8`

### Service control scripts

#### `ffmpeg-config/ffmpeg-transcode.sh`
Bash script that runs FFmpeg transcoding.

**Usage:**
```bash
./ffmpeg-transcode.sh <stream_name>
```

**What it does:**
- Reads RTMP input from MediaMTX
- Applies filter_complex to split video into 2 scales
- Encodes 480p variant (854x480 @ 2000 kbps, H.264, veryfast preset)
- Encodes 360p variant (640x360 @ 800 kbps, H.264, veryfast preset)
- Outputs both as RTMP back to MediaMTX
- Logs to `/logs/ffmpeg-<stream_name>.log`

**Parameters:**
- Input bitrate: Auto-detected from RTMP
- Video codec: H.264 (libx264)
- Preset: veryfast (minimal latency)
- Audio: AAC @ 128 kbps, 44.1 kHz

#### `ffmpeg-manager.py`
Python service manager for process lifecycle.

**Commands:**
```bash
python3 ffmpeg-manager.py start <stream_name>
python3 ffmpeg-manager.py stop <stream_name>
python3 ffmpeg-manager.py status
```

**Features:**
- Prevents duplicate transcoding (checks existing PIDs)
- Tracks processes in JSON file
- Graceful termination (SIGTERM, then SIGKILL fallback)
- Logs to `/logs/ffmpeg-manager.log`
- Process info saved to `/logs/ffmpeg-processes.json`

#### `transcode.sh`
Host-side wrapper for convenience — no need to manually `docker exec`; same Python manager underneath.

```bash
./transcode.sh start <stream_name>
./transcode.sh stop <stream_name>
./transcode.sh status
```

---

## 🧪 Testing

See **TESTING_FFMPEG_TRANSCODING.md** for the full test procedure, covering:
- Service startup, RTMP publish, transcoding start
- HLS output verification, playback (VLC/browser/iOS)
- Multi-stream concurrency and failure-handling scenarios
- Performance validation

**Key test matrix:**

| Test | Purpose | Expected Result |
|------|---------|-----------------|
| Service startup | Verify containers ready | All services healthy |
| RTMP publish | Verify input accepted | Stream appears in paths list |
| FFmpeg start | Verify transcoding begins | Logs show encoding |
| HLS availability | Verify outputs serving | Playlists downloadable |
| Playback (VLC) | Verify 480p playback | Video smooth, no sync drift |
| Playback (360p) | Verify bitrate variant | Lower quality, lower bitrate |
| iOS playback | Verify app integration | Clean stream plays |
| Multi-stream | Verify concurrency | Multiple streams simultaneously |
| Failure handling | Verify graceful degradation | Process restarts, recovers |

---

## 📊 Technical Specifications

### Video Encoding

| Property | 480p | 360p |
|----------|------|------|
| Resolution | 854x480 | 640x360 |
| Bitrate | 2000 kbps | 800 kbps |
| Codec | H.264 | H.264 |
| Preset | veryfast | veryfast |
| Frame Rate | 30 fps | 30 fps |

### Audio Encoding

| Property | Value |
|----------|-------|
| Codec | AAC |
| Bitrate | 128 kbps |
| Sample Rate | 44.1 kHz |

### Resource Limits

| Resource | Limit |
|----------|-------|
| CPU | 2 cores |
| Memory | 1 GB |
| Per-stream overhead | 50-150% CPU, 200-400 MB RAM |

### Network Latency

| Stage | Latency |
|-------|---------|
| RTMP input → FFmpeg | <1 sec |
| FFmpeg transcode | 2-3 sec |
| Output → MediaMTX | <1 sec |
| HLS segmentation | 2 sec |
| **Total E2E** | **5-10 sec** |

---

## 🐛 Troubleshooting

### FFmpeg container status check
```bash
docker logs ffmpeg-transcoder
docker exec ffmpeg-transcoder ps aux | grep ffmpeg
```

### Check transcoding logs
```bash
tail -f streaming/logs/ffmpeg-*.log
```

### View process tracker
```bash
cat streaming/logs/ffmpeg-processes.json | jq '.'
```

### Manually stop a process (if manager fails)
```bash
docker exec ffmpeg-transcoder pkill -f "ffmpeg.*mystream"
```

### Increase FFmpeg log verbosity
Edit `ffmpeg-transcode.sh`, change `-loglevel warning` to `-loglevel verbose`

---

## 🔧 Customization

### Adjust bitrates
Edit `ffmpeg-config/ffmpeg-transcode.sh`:
```bash
-b:v:0 2000k   # Change 480p bitrate here
-b:v:1 800k    # Change 360p bitrate here
```

### Add additional resolution
Add new filter in `ffmpeg-transcode.sh`:
```bash
-filter_complex "[0:v]split=3[v1][v2][v3]; ...
[v3]scale=1280:720[v3out]; ..." \

# Then add output:
-map "[v3out]" -map "0:a" ... \
-f flv "rtmp://mediamtx:1935/live/${STREAM_NAME}-720p"
```

### Increase encoding speed (lower CPU)
Change preset in `ffmpeg-transcode.sh`:
```bash
-preset ultrafast   # Faster, lower quality
-preset medium      # Slower, higher quality
```

### Adjust frame rate
```bash
-r:0 24    # Change from 30 fps to 24 fps
```

---

## 📈 Monitoring

### Active transcoding processes
```bash
./transcode.sh status
```

### Resource usage
```bash
docker stats ffmpeg-transcoder
```

### HLS stream health
```bash
curl -s http://localhost:9997/v1/paths/list | jq '.items[] | select(.name | contains("-480p", "-360p"))'
```

### Check for errors in logs
```bash
grep -i error streaming/logs/ffmpeg-*.log
```

---

## 📚 Related Documentation

- **TESTING_FFMPEG_TRANSCODING.md** — Comprehensive test procedures
- **QUICK_REFERENCE.md** — Server startup & common commands

---

## 📞 Support

For issues:
1. Check **TESTING_FFMPEG_TRANSCODING.md** troubleshooting
2. Review logs: `streaming/logs/ffmpeg-*.log`
3. Check container status: `docker ps -a`
4. Review manager logs: `tail -f streaming/logs/ffmpeg-manager.log`

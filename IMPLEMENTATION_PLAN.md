Last Modified: 08/16/2026 (1786882875) by amonrit

# Implementation Plan: Real-Time Stream Re-Encoding (480p, 360p)

## 🎯 Goal
Transform raw RTMP input stream into clean, synchronized HLS outputs with hardcoded bitrates (480p, 360p) using FFmpeg real-time re-encoding.

**Input**: RTMP stream (live, may have sync/timing issues)
**Output**: 2 clean HLS stream paths (`/live/[name]-480p`, `/live/[name]-360p`)
**Timeline**: Immediate (High priority)

---

## 📊 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  RTMP Input (Live Stream)                                   │
│  rtmp://server:1935/live/mystream                           │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  FFmpeg Service (docker-compose)                            │
│  ├─ Input: RTMP from MediaMTX                              │
│  ├─ Process: Real-time transcode                           │
│  └─ Output: 2 bitrate streams                              │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        ▼                             ▼
┌────────────────┐          ┌────────────────┐
│  480p Stream   │          │  360p Stream   │
│  (Output 1)    │          │  (Output 2)    │
└────────────────┘          └────────────────┘
        │                             │
        └──────────────┬──────────────┘
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  MediaMTX HLS Output                                        │
│  ├─ /live/mystream-480p/index.m3u8                         │
│  └─ /live/mystream-360p/index.m3u8                         │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  iOS App (Future)                                           │
│  Selects 480p or 360p clean stream                         │
└─────────────────────────────────────────────────────────────┘
```

---

## 📝 Implementation Steps

### **Phase 1: FFmpeg Service Setup** (1-2 hours)

#### 1.1 Add FFmpeg to docker-compose.yml
```yaml
services:
  ffmpeg-transcoder:
    image: jrottenberg/ffmpeg:latest
    container_name: ffmpeg-transcoder
    restart: unless-stopped
    depends_on:
      - mediamtx
    volumes:
      - ./ffmpeg-config:/ffmpeg-config:ro
      - ./logs:/logs
    environment:
      - MEDIAMTX_HOST=mediamtx
      - MEDIAMTX_RTMP_PORT=1935
    networks:
      - mediamtx_network
    # FFmpeg will be controlled via shell script
    entrypoint: /bin/bash
    command: -c "while true; do sleep 1; done"  # Keep alive for manual control
```

#### 1.2 Create FFmpeg transcoding script
**File**: `streaming/ffmpeg-transcode.sh`

```bash
#!/bin/bash
# Real-time RTMP → HLS transcoding with 480p, 360p

STREAM_NAME=$1
RTMP_URL="rtmp://mediamtx:1935/live/${STREAM_NAME}"
OUTPUT_DIR="/tmp/hls-${STREAM_NAME}"

mkdir -p "$OUTPUT_DIR"

# FFmpeg transcoding with 2 bitrate variants
ffmpeg -i "$RTMP_URL" \
  -c:v libx264 -preset veryfast \
  -b:v:0 2000k -s:0 854x480 \
  -b:v:1 800k -s:1 640x360 \
  -c:a aac -b:a 128k \
  -f hls -hls_time 2 -hls_list_size 10 \
  -master_pl_name master.m3u8 \
  -var_stream_map "v:0,a v:1,a" \
  "${OUTPUT_DIR}/stream_%v.m3u8" \
  2>> /logs/ffmpeg-${STREAM_NAME}.log
```

---

### **Phase 2: MediaMTX Integration** (1-2 hours)

#### 2.1 Configure MediaMTX paths for re-encoded output
**Update**: `streaming/mediamtx.yml`

```yaml
paths:
  # Original input path
  live:
    source: publisher
    
  # 480p re-encoded output (from FFmpeg)
  live-480p:
    source: redirect
    sourceRedirect: rtmp://ffmpeg-transcoder/live/${path}

  # 360p re-encoded output (from FFmpeg)
  live-360p:
    source: redirect
    sourceRedirect: rtmp://ffmpeg-transcoder/live/${path}
```

**Note**: Alternative: Use MediaMTX built-in transcoding if available in v1.20.0

---

### **Phase 3: FFmpeg Service Control** (1-2 hours)

#### 3.1 Create FFmpeg manager service
**File**: `streaming/ffmpeg-manager.py`

```python
#!/usr/bin/env python3
import subprocess
import os
import logging
from datetime import datetime

LOG_DIR = "/logs"
os.makedirs(LOG_DIR, exist_ok=True)

logging.basicConfig(
    filename=f"{LOG_DIR}/ffmpeg-manager.log",
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

def start_transcoding(stream_name):
    """Start FFmpeg transcoding for a stream"""
    try:
        cmd = f"bash /ffmpeg-config/ffmpeg-transcode.sh {stream_name}"
        subprocess.Popen(cmd, shell=True)
        logging.info(f"✅ Started transcoding: {stream_name}")
    except Exception as e:
        logging.error(f"❌ Failed to start transcoding: {stream_name} - {e}")

def stop_transcoding(stream_name):
    """Stop FFmpeg transcoding for a stream"""
    try:
        os.system(f"pkill -f 'ffmpeg.*{stream_name}'")
        logging.info(f"✅ Stopped transcoding: {stream_name}")
    except Exception as e:
        logging.error(f"❌ Failed to stop transcoding: {stream_name} - {e}")

if __name__ == "__main__":
    # Example: start_transcoding("mystream")
    pass
```

---

### **Phase 4: Testing & Validation** (1 hour)

#### 4.1 Test workflow
```bash
# 1. Start server
cd streaming
docker-compose up -d

# 2. Publish RTMP stream
ffmpeg -re -i test-video.mp4 -c copy -f flv \
  rtmp://localhost:1935/live/mystream

# 3. Verify HLS outputs exist
curl http://localhost:8888/live/mystream-480p/index.m3u8
curl http://localhost:8888/live/mystream-360p/index.m3u8

# 4. Check FFmpeg logs
docker logs ffmpeg-transcoder
tail -f streaming/logs/ffmpeg-mystream.log
```

#### 4.2 Verify iOS can play
- Update iOS app to play `/live/mystream-480p/index.m3u8`
- Confirm playback is sync'd (no audio/video drift)
- Check bitrate in debug info

---

## 🎯 Deliverables

| Item | Status | Notes |
|------|--------|-------|
| FFmpeg service in docker-compose | TBD | Jrottenberg/ffmpeg image |
| Transcoding script (480p, 360p) | TBD | Hardcoded bitrates |
| MediaMTX path config | TBD | Output routing |
| FFmpeg manager (logging) | TBD | Error logging only |
| Test verification | TBD | RTMP → HLS playback |
| iOS app update (select clean path) | **DEFERRED** | B4 - decide later |

---

## 🚨 Risk & Mitigation

| Risk | Mitigation |
|------|------------|
| FFmpeg crashes | Service restart policy + logging |
| High CPU usage | Resource limits in docker-compose |
| Encoding latency | Pre-configured (veryfast preset) |
| Lost segments | HLS segmentation (hls_list_size: 10) |
| No iOS UX logic yet | Defer to Phase 5 (separate task) |

---

## 📅 Timeline

| Phase | Time | Status |
|-------|------|--------|
| 1. FFmpeg Service | 1-2h | TBD |
| 2. MediaMTX Integration | 1-2h | TBD |
| 3. Manager & Logging | 1-2h | TBD |
| 4. Testing | 1h | TBD |
| **Total** | **4-7h** | Ready to start |

---

## 📌 Next Steps

1. ✅ **Confirm plan** (this document)
2. 🔨 **Implement Phase 1-4** (streaming infrastructure)
3. 📱 **Defer iOS UX** (decide URL selection strategy later)
4. 🧪 **Test end-to-end** (RTMP → clean HLS → iOS playback)

---

## 🔗 Related Files

- `streaming/docker-compose.yml` — Service config
- `streaming/mediamtx.yml` — Path routing
- `streaming/ffmpeg-transcode.sh` — Encoding script
- `streaming/ffmpeg-manager.py` — Service control
- `streaming/logs/` — Error logs
- `FEATURES_ROADMAP.md` — **DEPRECATED** (see this plan instead)

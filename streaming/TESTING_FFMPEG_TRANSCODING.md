Last Modified: 08/24/2026 (1787588646) by amonrit

# Testing: FFmpeg Real-Time Stream Re-Encoding

This guide validates the end-to-end FFmpeg transcoding setup. Follow each step in order.

---

## 🎯 What We're Testing

✅ FFmpeg service starts and stays alive  
✅ FFmpeg can read RTMP input from MediaMTX  
✅ FFmpeg transcodes to 480p + 360p variants  
✅ Transcoded streams publish back to MediaMTX  
✅ MediaMTX serves 480p/360p as HLS  
✅ iOS app can play clean HLS streams  

---

## 📋 Prerequisites

- Docker & Docker Compose installed
- FFmpeg tools available (`ffmpeg` CLI for testing)
- Streaming server running (see FFMPEG_SETUP.md)
- Terminal access to repo directory

---

## 🧪 Step 1: Service Startup Test

### Start all services
```bash
cd streaming
docker-compose up -d
```

**Verify services started:**
```bash
docker-compose ps
```

Expected output:
```
NAME                      STATUS
mediamtx                  Up 2 seconds
ffmpeg-transcoder         Up 1 second
```

**Check MediaMTX logs:**
```bash
docker logs mediamtx
```

Should see: `[api] listening on 0.0.0.0:9997` and `[rtmp] listening on 0.0.0.0:1935`

**Check FFmpeg container:**
```bash
docker logs ffmpeg-transcoder
```

Should see: FFmpeg image loaded, container running

---

## 🧪 Step 2: Publish Test Stream

### Start RTMP stream publisher

**Option A: Using test video file**
```bash
# If you have a test video:
ffmpeg -re -i /path/to/test-video.mp4 -c copy -f flv \
  rtmp://localhost:1935/live/teststream
```

**Option B: Using the test script**
```bash
cd streaming
bash test-streaming.sh
# This creates a test stream as "teststream"
```

**Expected output:**
```
rtmp://localhost:1935/live/teststream 
Connected to RTMP server
Publishing stream...
```

**Leave this running** in a separate terminal — we'll test playback next.

---

## 🧪 Step 3: Start Transcoding

### Access FFmpeg transcoder and start encoding

**In a new terminal:**
```bash
# Option A: Direct script execution
docker exec ffmpeg-transcoder bash -c \
  "/ffmpeg-config/ffmpeg-transcode.sh teststream"

# Option B: Using Python manager (recommended)
docker exec ffmpeg-transcoder python3 \
  /ffmpeg-manager.py start teststream
```

**Expected output:**
```
🎬 Starting transcoding for: teststream
📡 Input: rtmp://mediamtx:1935/live/teststream
✅ Started transcoding: teststream (PID: 12345)
```

**Check FFmpeg logs:**
```bash
tail -f streaming/logs/ffmpeg-teststream.log
```

Should show FFmpeg connecting and encoding:
```
[flv @ ...] header...
Input #0, flv, from 'rtmp://mediamtx:1935/live/teststream'
  Duration: N/A, start: 0.000000, bitrate: N/A
Video: h264, yuv420p, 1920x1080, 30 fps
Audio: aac, 44100 Hz
```

---

## 🧪 Step 4: Verify HLS Outputs

### Check MediaMTX is serving re-encoded streams

**Check available streams:**
```bash
curl -s http://localhost:9997/v1/paths/list | jq '.items[] | .name'
```

Expected output:
```
live
teststream
live-teststream-480p
live-teststream-360p
```

**Verify 480p HLS output exists:**
```bash
curl -s http://localhost:8888/live-teststream-480p/index.m3u8
```

Expected output (HLS playlist):
```
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:2
#EXTINF:2.0,
segment-0-v1-00001.ts
segment-0-v1-00002.ts
#EXT-X-ENDLIST
```

**Verify 360p HLS output exists:**
```bash
curl -s http://localhost:8888/live-teststream-360p/index.m3u8
```

Should also return valid HLS playlist.

---

## 🧪 Step 5: Playback Test (VLC / Browser)

### Play the streams

**Option A: VLC Media Player**
```
File → Open Network Stream

480p URL:  http://localhost:8888/live-teststream-480p/index.m3u8
360p URL:  http://localhost:8888/live-teststream-360p/index.m3u8
```

**Option B: Safari (on macOS)**
```
Open: http://localhost:8888/live-teststream-480p/index.m3u8
```

**Option C: Command line (ffplay)**
```bash
ffplay http://localhost:8888/live-teststream-480p/index.m3u8
ffplay http://localhost:8888/live-teststream-360p/index.m3u8
```

**Expected results:**
- ✅ Video plays smoothly without stuttering
- ✅ 480p stream shows higher quality (854x480 resolution)
- ✅ 360p stream shows lower quality (640x360 resolution)
- ✅ Audio is in sync with video
- ✅ No visible latency (< 5 seconds from input)

---

## 🧪 Step 6: iOS App Playback Test

### Update iOS app to use clean stream

**In the app:**

1. Open the app and use "Add Stream" in `VideoStreamListView` (no source edit needed — see `docs/DEPLOYMENT.md` § iOS App Configuration)
2. Enter the 480p stream URL:
   ```swift
   let url = "http://YOUR_SERVER_IP:8888/live-teststream-480p/index.m3u8"
   ```

**Alternative: Use multi-variant (adaptive bitrate):**
   ```swift
   let url = "http://YOUR_SERVER_IP:8888/live-teststream/master.m3u8"
   ```

4. Build and run on device
5. Play stream and verify:
   - ✅ Video plays without sync issues
   - ✅ Quality is clean (no artifacts from re-encoding)
   - ✅ No audio/video drift
   - ✅ Playback is responsive to play/pause

---

## 🧪 Step 7: Multi-Stream Concurrent Test

### Test with multiple simultaneous streams

**Publish multiple test streams:**
```bash
# Terminal 1
ffmpeg -re -i test-video-1.mp4 -c copy -f flv \
  rtmp://localhost:1935/live/stream1

# Terminal 2
ffmpeg -re -i test-video-2.mp4 -c copy -f flv \
  rtmp://localhost:1935/live/stream2

# Terminal 3
ffmpeg -re -i test-video-3.mp4 -c copy -f flv \
  rtmp://localhost:1935/live/stream3
```

**Start transcoding for all:**
```bash
docker exec ffmpeg-transcoder python3 /ffmpeg-manager.py start stream1 &
docker exec ffmpeg-transcoder python3 /ffmpeg-manager.py start stream2 &
docker exec ffmpeg-transcoder python3 /ffmpeg-manager.py start stream3 &
```

**Check status:**
```bash
docker exec ffmpeg-transcoder python3 /ffmpeg-manager.py status
```

**Verify CPU usage stays under limits:**
```bash
docker stats ffmpeg-transcoder
# Should see CPU < 200% (resource limit: 2 CPUs)
# Memory < 1GB (resource limit: 1GB)
```

---

## 🧪 Step 8: Stress & Error Handling Test

### Test failure scenarios

#### Scenario A: Publisher crashes
```bash
# 1. Start transcoding as before
# 2. Kill the RTMP publisher (Ctrl+C in the publisher terminal)
# 3. Check FFmpeg behavior:
tail -f streaming/logs/ffmpeg-teststream.log
```

**Expected**: FFmpeg retries connection, waits for stream to return

#### Scenario B: Stop transcoding gracefully
```bash
docker exec ffmpeg-transcoder python3 /ffmpeg-manager.py stop teststream
```

**Expected**: Process terminates cleanly, logs show "Stopped"

#### Scenario C: Container restart
```bash
docker-compose restart ffmpeg-transcoder
```

**Expected**: Container restarts, services remain available

---

## 📊 Step 9: Performance Validation

### Measure key metrics

**Latency (input to HLS playback):**
```bash
# Approximate latency:
# RTMP input → FFmpeg transcode → RTMP output → MediaMTX → HLS segments
# Typical: 5-10 seconds
```

**CPU/Memory Usage:**
```bash
docker stats ffmpeg-transcoder --no-stream
```

**Expected baseline (per stream):**
- CPU: 50-150% (with veryfast preset)
- Memory: 200-400 MB per stream

**Bitrate validation:**
```bash
# Check FFmpeg output
grep -i "bitrate" streaming/logs/ffmpeg-teststream.log

# Expected:
# 480p: ~2000 kbps video + 128 kbps audio = 2128 kbps
# 360p: ~800 kbps video + 128 kbps audio = 928 kbps
```

---

## ✅ Success Criteria

Check off when complete:

- [ ] Docker services start successfully
- [ ] RTMP stream publishes to MediaMTX
- [ ] FFmpeg starts transcoding
- [ ] 480p and 360p paths appear in MediaMTX
- [ ] HLS playlists are valid (can download)
- [ ] VLC/Browser can play 480p stream
- [ ] VLC/Browser can play 360p stream
- [ ] Video is in sync (no audio drift)
- [ ] iOS app plays clean stream
- [ ] Multiple concurrent streams work
- [ ] Graceful failure handling
- [ ] CPU/Memory within limits

**If all checks pass:** ✅ Transcoding pipeline verified!

---

## 🐛 Troubleshooting

### Issue: FFmpeg container won't start
```bash
docker logs ffmpeg-transcoder
```
**Solution**: Check image pull, disk space, permissions

### Issue: FFmpeg connects but doesn't transcode
```bash
# Check if input stream exists
curl http://localhost:9997/v1/paths/list

# Verify RTMP input is publishing
```
**Solution**: Ensure RTMP publisher is running and pushing to `/live/teststream`

### Issue: HLS playlist returns 404
```bash
curl -v http://localhost:8888/live-teststream-480p/index.m3u8
```
**Solution**: Verify FFmpeg transcoding is running, check MediaMTX logs

### Issue: High CPU usage
**Solution**: 
- Reduce bitrates in ffmpeg-transcode.sh
- Use `-preset ultrafast` instead of `veryfast`
- Reduce frame rate (-r 24 instead of -r 30)

### Issue: Audio/Video out of sync
**Solution**: Ensure audio codec is AAC with consistent bitrate, check for packet loss

---

## 📝 Cleanup

When done testing:

```bash
# Stop all services
cd streaming
docker-compose down

# Remove test logs
rm -rf logs/ffmpeg-*.log

# Clean HLS output
rm -rf hls_output/*
```

---

See `streaming/FFMPEG_SETUP.md` for the full implementation writeup.

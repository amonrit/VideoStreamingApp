Last Modified: 08/10/2026 (1786502400) by amonrit

# 🚀 MediaMTX Streaming Server - Deployment Guide

## ✅ What's Ready

- ✅ Streaming server (v1.20.0)
- ✅ Docker setup (portable)
- ✅ Config files (works on any machine)
- ✅ All protocols enabled (RTMP, RTSP, HLS, WebRTC, SRT)

---

## 💻 Deploy on Another Machine

### **Requirements**
- Docker & Docker Compose installed
- Project folder: `steam/streaming/`

### **Step 1: Copy Project Files**

Copy the entire `steam` folder to the new machine:

```bash
# From the machine with steam folder
scp -r ~/Documents/steam user@new-machine:~/Documents/
```

Or download/clone if in Git.

### **Step 2: Navigate to Streaming Directory**

```bash
cd ~/Documents/steam/streaming
```

**Important:** Always run docker-compose from the `streaming` directory!

### **Step 3: Start Server**

```bash
# Pull latest image
docker-compose pull

# Start server
docker-compose up -d

# Check status
docker-compose ps
```

### **Step 4: Get Server IP**

```bash
# macOS/Linux
ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1

# Windows
ipconfig
```

Example: `192.168.1.100`

### **Step 5: Access Stream**

**iOS:**
```
http://192.168.1.100:8888/live/mystream/index.m3u8
```

**VLC (All platforms):**
```
http://192.168.1.100:8888/live/mystream/index.m3u8
```

**FFplay:**
```bash
ffplay "http://192.168.1.100:8888/live/mystream/index.m3u8"
```

---

## 📁 Directory Structure

```
steam/
├── streaming/              # Server files
│   ├── docker-compose.yml  # Docker configuration
│   ├── mediamtx.yml       # MediaMTX config
│   ├── recordings/        # Recorded streams (auto-created)
│   ├── test-streaming.sh  # Test script
│   └── quick-test.sh      # Quick test
├── steam/                 # iOS app code
│   ├── Views/
│   ├── Models/
│   ├── ViewModels/
│   └── Workers/
└── README.md
```

---

## 🎯 Quick Start on New Machine

```bash
# Clone/copy repo
git clone <repo> ~/steam  # or copy folder

# Navigate to streaming directory
cd ~/steam/streaming

# Start server
docker-compose up -d

# Get your IP
ifconfig | grep "inet " | grep -v 127.0.0.1

# Test HLS endpoint
curl http://YOUR_IP:8888/live/mystream/index.m3u8

# View logs
docker-compose logs -f mediamtx
```

---

## 🔧 Configuration Files (Portable)

### **docker-compose.yml**
- Uses relative paths: `./mediamtx.yml`, `./recordings`
- Works on any machine with same folder structure
- Exposes all ports to `0.0.0.0` (accessible from network)

### **mediamtx.yml**
- Clean, minimal configuration
- All protocols enabled by default
- Can be customized for specific needs

---

## 📊 Server Services & Ports

| Protocol | Port | Usage | URL Format |
|----------|------|-------|-----------|
| RTMP | 1935 | Publishing | `rtmp://IP:1935/live/mystream` |
| RTSP | 8554 | Low-latency | `rtsp://IP:8554/live/mystream` |
| HLS | 8888 | iOS/Browser | `http://IP:8888/live/mystream/index.m3u8` |
| WebRTC | 8889 | Browser | `http://IP:8889/live/mystream` |
| SRT | 8890 | High-quality | `srt://IP:8890?streamid=mystream` |

---

## 🎬 Publishing to Server

### **Method 1: FFmpeg**

```bash
# Video file
ffmpeg -re -i video.mp4 -c copy -f flv rtmp://IP:1935/live/mystream

# Screen capture (macOS)
ffmpeg -f avfoundation -i "1:" -c:v libx264 -c:a aac \
  -f flv rtmp://IP:1935/live/mystream

# Screen capture (Windows)
ffmpeg -f gdigrab -i desktop -c:v libx264 -c:a aac \
  -f flv rtmp://IP:1935/live/mystream
```

### **Method 2: OBS Studio**

1. Settings → Stream
2. Service: Custom
3. Server: `rtmp://IP:1935/live`
4. Stream Key: `mystream`
5. Start Streaming

### **Method 3: Mobile App**

Update your iOS app to use the server IP:

```swift
// In ContentView or VideoStream model
let serverURL = "rtmp://SERVER_IP:1935/live/mystream"
```

Then publish from mobile app.

---

## 🧪 Testing

### **Test 1: Check Server Running**
```bash
docker-compose ps
```
Should show: `mediamtx ... Up ...`

### **Test 2: Test HLS Endpoint**
```bash
curl -v http://localhost:8888/live/mystream/index.m3u8
# Should return: HTTP/1.1 302 Found or 200 OK
```

### **Test 3: Publish Test Stream**
```bash
# Terminal 1: View logs
docker-compose logs -f mediamtx

# Terminal 2: Publish (if you have test video)
ffmpeg -re -i test_pattern.mp4 -c copy -f flv rtmp://publish:streampass123@localhost:1935/live/mystream

# Terminal 3: Play stream
ffplay "http://localhost:8888/live/mystream/index.m3u8"
```

### **Test 4: iOS/VLC Playback**
- Open iOS Simulator or VLC
- Use HLS URL: `http://SERVER_IP:8888/live/mystream/index.m3u8`
- Should start playing

---

## 🔐 Security Notes

### **Currently:**
- ✅ Port forward on router (if internet access needed)
- ✅ Firewall allows Docker ports
- ⚠️ No authentication except RTMP publish

### **To Secure:**
1. Change `publishUser` & `publishPass` in `mediamtx.yml`
2. Restrict network access via firewall
3. Use VPN for remote access
4. Use HTTPS proxy (nginx)

---

## 📱 iOS App Configuration

Update your iOS app to point to new server:

**In `ContentView.swift` or network config:**

```swift
let STREAM_URL = "rtmp://YOUR_SERVER_IP:1935/live/mystream"
let PLAYBACK_URL = "http://YOUR_SERVER_IP:8888/live/mystream/index.m3u8"
```

**Rebuild and test:**
```bash
# In iOS project directory
xcodebuild -scheme steam -destination 'generic/platform=iOS Simulator'
```

---

## 🛠️ Common Commands

### **View Logs**
```bash
docker-compose logs -f mediamtx
```

### **Restart Server**
```bash
docker-compose restart mediamtx
```

### **Stop Server**
```bash
docker-compose down
```

### **Start Server**
```bash
docker-compose up -d
```

### **Check Ports**
```bash
# macOS/Linux
lsof -i :8888

# Windows
netstat -ano | findstr :8888
```

### **Test Connection from Another Machine**
```bash
curl http://REMOTE_IP:8888/live/mystream/index.m3u8
```

---

## ⚠️ Troubleshooting

### **Container won't start**
```bash
docker-compose logs mediamtx  # Check error messages
docker-compose down
docker-compose pull           # Update image
docker-compose up -d
```

### **Cannot access from other machine**
1. Verify IP address: `ifconfig`
2. Check firewall allows ports 1935, 8554, 8888, 8889, 8890
3. Test locally first: `curl http://localhost:8888/...`
4. Verify same WiFi/network

### **Stream not found**
- Ensure stream is publishing
- Check stream name is `live/mystream`
- View logs: `docker-compose logs -f`

### **HLS playback buffering**
- Check network latency
- Reduce encoder bitrate
- Try RTSP instead (lower latency)

---

## 📝 Notes

- **Portable:** Folder structure same on any machine = works immediately
- **Scalable:** Can run on Raspberry Pi, NAS, cloud server, etc.
- **Flexible:** All protocols available simultaneously
- **Open Source:** MediaMTX is free and open source

---

## 🎯 Next Steps

1. ✅ Copy project to new machine
2. ✅ Run `docker-compose up -d` from streaming folder
3. ✅ Get server IP address
4. ✅ Test HLS URL in browser/VLC/iOS
5. ✅ Update iOS app with server IP
6. ✅ Publish stream and verify playback

**You're ready to stream across your network! 🚀**
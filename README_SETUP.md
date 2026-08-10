# 🚀 Steam Streaming Server - Ready to Deploy

## ✅ Status: READY

- ✅ Server running v1.20.0
- ✅ Portable configuration (any machine)
- ✅ All protocols active
- ✅ Accessible from network
- ✅ Documentation complete

---

## 📍 Current Setup

**Server Location:** `/Users/amonrit/Documents/steam/streaming/`

**Running:** 
```
docker-compose up -d
```

**Access:**
```
HLS: http://YOUR_IP:8888/live/mystream/index.m3u8
RTMP: rtmp://YOUR_IP:1935/live/mystream
```

---

## 🎯 Quick Deploy on New Machine

1. **Copy folder** to new machine:
```bash
# Copy steam folder entirely
scp -r ~/Documents/steam user@machine2:~/Documents/
```

2. **Run server** (from streaming directory):
```bash
cd steam/streaming
docker-compose up -d
```

3. **Get IP**:
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
```

4. **Access stream**:
```
http://IP:8888/live/mystream/index.m3u8
```

---

## 📚 Documentation

1. **DEPLOYMENT_GUIDE.md** ← Start here for new machine setup
2. **NETWORK_ACCESS_GUIDE.md** ← All access URLs and protocols
3. **README.md** ← Project overview

---

## 🔧 Key Features

| Feature | Status | Details |
|---------|--------|---------|
| Portable | ✅ | Works on any machine |
| RTMP Publishing | ✅ | rtmp://IP:1935/live/mystream |
| HLS Playback | ✅ | http://IP:8888/live/mystream/index.m3u8 |
| iOS Support | ✅ | Native HLS in Safari/VLC |
| Network Access | ✅ | All interfaces (0.0.0.0) |
| Auto-Restart | ✅ | Docker restart policy enabled |

---

## 🎬 Common Tasks

### Start Server
```bash
cd steam/streaming
docker-compose up -d
```

### Stop Server
```bash
docker-compose down
```

### View Logs
```bash
docker-compose logs -f mediamtx
```

### Publish Stream (FFmpeg)
```bash
ffmpeg -re -i video.mp4 -c copy -f flv \
  rtmp://IP:1935/live/mystream
```

### Play Stream (FFplay)
```bash
ffplay "http://IP:8888/live/mystream/index.m3u8"
```

---

## 📱 iOS Setup

**In Safari:**
1. Open: `http://SERVER_IP:8888/live/mystream/index.m3u8`
2. Play in fullscreen

**In VLC:**
1. Media → Open Network Stream
2. Paste: `http://SERVER_IP:8888/live/mystream/index.m3u8`
3. Play

---

## ✨ What's Included

```
steam/
├── streaming/
│   ├── docker-compose.yml ✅ Portable
│   ├── mediamtx.yml ✅ Config for any machine
│   ├── recordings/ ✅ Auto-created
│   ├── test-streaming.sh
│   └── quick-test.sh
├── steam/ (iOS app code)
├── DEPLOYMENT_GUIDE.md ← For new machines
├── NETWORK_ACCESS_GUIDE.md
└── README_SETUP.md ← This file
```

---

## 🚀 Deploy to Another Machine NOW

```bash
# Step 1: Copy project
scp -r ~/Documents/steam user@newmachine:~/Documents/

# Step 2: SSH into new machine
ssh user@newmachine

# Step 3: Start server
cd ~/Documents/steam/streaming
docker-compose up -d

# Step 4: Get IP and use URLs
ifconfig | grep "inet "
# Use: http://IP:8888/live/mystream/index.m3u8
```

---

**Ready to stream! 🎬**

For details, see DEPLOYMENT_GUIDE.md

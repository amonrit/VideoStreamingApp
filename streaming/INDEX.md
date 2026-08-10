# 📚 MediaMTX Streaming Server - Documentation Index

Quick links to all documentation files.

## 🚀 Getting Started

### Start Here
- **[START.md](START.md)** - Quick start guide to get streaming in 5 minutes
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Essential commands cheatsheet

## 📖 Complete Documentation

- **[README_STREAMING.md](README_STREAMING.md)** - Complete user guide with examples
- **[STREAMING_SETUP.md](STREAMING_SETUP.md)** - Advanced setup and troubleshooting

## ⚙️ Configuration Files

- **[docker-compose.yml](docker-compose.yml)** - Docker container setup
- **[mediamtx.yml](mediamtx.yml)** - MediaMTX server configuration

## 🧪 Testing & Verification

- **[quick-test.sh](quick-test.sh)** - Quick verification script
- **[test-streaming.sh](test-streaming.sh)** - Full test suite (requires FFmpeg)

## 🎮 Control Scripts

From the main `steam/` directory:
- **[../streaming.sh](../streaming.sh)** - Easy control script

```bash
./streaming.sh start     # Start server
./streaming.sh status    # Check status
./streaming.sh logs      # View logs
./streaming.sh test      # Run verification
./streaming.sh stop      # Stop server
```

## 📁 Directories

- **[recordings/](recordings/)** - Recorded stream storage

## 🔗 External Resources

- [MediaMTX GitHub](https://github.com/bluenviron/mediamtx)
- [MediaMTX Wiki](https://github.com/bluenviron/mediamtx/wiki)
- [Docker Documentation](https://docs.docker.com/)
- [FFmpeg Documentation](https://ffmpeg.org/documentation.html)
- [OBS Studio](https://obsproject.com/)

## 📡 Quick URLs

| Protocol | URL |
|----------|-----|
| RTMP | `rtmp://localhost:1935/live/{stream_name}` |
| HLS | `http://localhost:8888/live/{stream_name}/index.m3u8` |
| RTSP | `rtsp://localhost:8554/live/{stream_name}` |
| WebRTC | `http://localhost:8889/live/{stream_name}` |

## ⚡ Quick Commands

```bash
# Start server (from main steam/ directory)
./streaming.sh start

# Publish a stream (requires FFmpeg)
ffmpeg -i video.mp4 -c copy -f flv rtmp://localhost:1935/live/mystream

# Watch in VLC
# Media → Open Network → http://localhost:8888/live/mystream/index.m3u8
```

---

**Organization Date**: 2026-08-10  
**Server Version**: MediaMTX v1.20.0  
**Status**: ✅ Ready to Use

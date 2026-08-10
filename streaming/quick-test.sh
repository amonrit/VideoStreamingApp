#!/bin/bash

# Simple MediaMTX Server Quick Test

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║        MediaMTX Live Streaming Server - Quick Test             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

success() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

echo -e "${BLUE}1. Check Docker Container${NC}"
if docker ps --filter "name=mediamtx" --format "{{.Names}}" | grep -q mediamtx; then
    success "MediaMTX container is running"
    docker ps --filter "name=mediamtx" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
else
    error "MediaMTX container is NOT running"
    exit 1
fi
echo ""

echo -e "${BLUE}2. Check Server Logs${NC}"
info "Last 5 lines of logs:"
docker logs --tail 5 mediamtx 2>&1 | tail -5
echo ""

echo -e "${BLUE}3. Test HLS Endpoint${NC}"
HLS_URL="http://localhost:8888/live/test/index.m3u8"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$HLS_URL" 2>/dev/null || echo "000")

if [ "$RESPONSE" == "404" ]; then
    warn "No active stream (expected when no publisher is connected)"
    info "HLS endpoint is accessible but no stream yet"
elif [ "$RESPONSE" == "200" ]; then
    success "HLS stream is active and playing!"
    info "URL: $HLS_URL"
else
    error "HLS endpoint returned HTTP $RESPONSE"
fi
echo ""

echo -e "${BLUE}4. Server Configuration Summary${NC}"
echo ""
echo "🎬 Streaming Protocols:"
echo "   • RTSP  → rtsp://localhost:8554/live/{stream_name}"
echo "   • RTMP  → rtmp://localhost:1935/live/{stream_name}"
echo "   • HLS   → http://localhost:8888/live/{stream_name}/index.m3u8"
echo "   • WebRTC→ http://localhost:8889/live/{stream_name}"
echo "   • SRT   → srt://localhost:8890?streamid={stream_name}"
echo ""

echo "📤 To Publish a Stream (requires FFmpeg):"
echo ""
echo "   ffmpeg -i video.mp4 -c copy -f flv \\"
echo "     rtmp://localhost:1935/live/mystream"
echo ""
echo "   # Screen capture (macOS):"
echo "   ffmpeg -f avfoundation -i \"1:\" -c:v libx264 -preset veryfast \\"
echo "     -c:a aac -f flv rtmp://localhost:1935/live/mystream"
echo ""

echo "📺 To Watch a Stream:"
echo ""
echo "   # VLC Media Player:"
echo "   Media → Open Network Stream → http://localhost:8888/live/mystream/index.m3u8"
echo ""
echo "   # Command line (requires ffplay):"
echo "   ffplay 'http://localhost:8888/live/mystream/index.m3u8'"
echo ""
echo "   # Low-latency RTSP:"
echo "   ffplay 'rtsp://localhost:8554/live/mystream'"
echo ""

echo "📁 Configuration Files:"
echo "   • docker-compose.yml  - Docker container configuration"
echo "   • mediamtx.yml        - MediaMTX server configuration"
echo "   • recordings/         - Directory for recorded streams"
echo ""

echo "📝 Useful Commands:"
echo ""
echo "   # View live logs"
echo "   docker-compose logs -f mediamtx"
echo ""
echo "   # Stop server"
echo "   docker-compose down"
echo ""
echo "   # Restart after config changes"
echo "   docker-compose restart"
echo ""
echo "   # Check container status"
echo "   docker ps --filter 'name=mediamtx'"
echo ""

echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Server is ready to stream!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

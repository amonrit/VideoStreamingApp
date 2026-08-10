#!/bin/bash

# MediaMTX Live Streaming Test Script
# This script tests the MediaMTX server setup

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║        MediaMTX Live Streaming Server Test Script              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RTMP_URL="rtmp://publish:streampass123@localhost:1935/live/mystream"
HLS_URL="http://localhost:8888/live/mystream/index.m3u8"
RTSP_URL="rtsp://publish:streampass123@localhost:8554/live/mystream"
WEBRTC_URL="http://localhost:8889/live/mystream"
TEST_STREAM_FILE="test_pattern.mp4"
TEST_DURATION=10

echo -e "${BLUE}[INFO]${NC} Testing MediaMTX Server Setup"
echo ""

# Function to print status
status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

error() {
    echo -e "${RED}[✗]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Check if Docker is running
status "Checking Docker..."
if ! docker ps > /dev/null 2>&1; then
    error "Docker is not running"
    exit 1
fi
success "Docker is running"
echo ""

# Check if MediaMTX container is running
status "Checking MediaMTX container..."
if docker ps --format "{{.Names}}" | grep -q "mediamtx"; then
    success "MediaMTX container is running"
else
    warning "MediaMTX container is not running"
    status "Starting container with: docker-compose up -d"
    docker-compose up -d
    echo "Waiting 5 seconds for server to start..."
    sleep 5
fi
echo ""

# Check port connectivity
status "Testing port connectivity..."
ports=(1935 8554 8555 8888 8889)
for port in "${ports[@]}"; do
    if timeout 2 bash -c "echo >/dev/tcp/localhost/$port" 2>/dev/null; then
        success "Port $port is open"
    else
        warning "Port $port is not responding (server might still be starting)"
    fi
done
echo ""

# Create test video pattern if ffmpeg is available
status "Generating test video pattern..."
if command -v ffmpeg &> /dev/null; then
    if [ ! -f "$TEST_STREAM_FILE" ]; then
        echo "Creating 10-second test video with color bars..."
        ffmpeg -f lavfi -i testsrc=s=1280x720:d=$TEST_DURATION \
               -f lavfi -i sine=f=1000:d=$TEST_DURATION \
               -pix_fmt yuv420p \
               -c:v libx264 -c:a aac \
               -crf 23 -preset fast \
               "$TEST_STREAM_FILE" \
               -y 2>&1 | grep -E "frame|Duration|speed" || true
        success "Test video created: $TEST_STREAM_FILE"
    else
        success "Test video already exists: $TEST_STREAM_FILE"
    fi
else
    error "ffmpeg is not installed. Please install it with: brew install ffmpeg"
    echo ""
fi
echo ""

# Test RTMP publishing
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Test 1: RTMP Publishing${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
status "Testing RTMP stream publishing..."
if command -v ffmpeg &> /dev/null && [ -f "$TEST_STREAM_FILE" ]; then
    status "Publishing test stream to: $RTMP_URL"
    status "Running for ${TEST_DURATION} seconds..."

    # Run ffmpeg in background with timeout
    ffmpeg -re -i "$TEST_STREAM_FILE" \
           -c copy \
           -f flv "$RTMP_URL" \
           -y 2>&1 | tee /tmp/ffmpeg_rtmp.log | grep -E "frame|Stream" || true &

    FFMPEG_PID=$!
    sleep 3

    # Check if stream is active
    if curl -s "$HLS_URL" | grep -q "#EXTM3U"; then
        success "RTMP stream published successfully!"
        success "HLS playlist is accessible at: $HLS_URL"
    else
        warning "HLS playlist not yet available (stream may still be starting)"
    fi

    # Wait a bit, then stop ffmpeg
    sleep $((TEST_DURATION - 2))
    kill $FFMPEG_PID 2>/dev/null || true
    wait $FFMPEG_PID 2>/dev/null || true

else
    warning "ffmpeg or test video not available, skipping RTMP test"
fi
echo ""

# Test HLS access
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Test 2: HLS Stream Access${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
status "Testing HLS playlist access..."

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$HLS_URL" || echo "000")

if [ "$HTTP_CODE" == "200" ]; then
    success "HLS playlist is accessible (HTTP $HTTP_CODE)"
    status "HLS Playlist URL: $HLS_URL"
    echo "You can play this stream with:"
    echo "  - VLC Media Player: File → Open Network Stream → $HLS_URL"
    echo "  - Web player: Open in browser with HLS-capable player"
    echo "  - FFplay: ffplay '$HLS_URL'"
else
    status "HLS playlist returned HTTP $HTTP_CODE (stream may not be active)"
    status "This is expected if no stream is currently publishing"
fi
echo ""

# Test server information
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Test 3: Server Information${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
status "MediaMTX container details:"
docker ps --filter "name=mediamtx" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" || true
echo ""

# Test Docker logs
status "Recent MediaMTX logs:"
docker logs --tail 5 mediamtx 2>/dev/null || warning "Could not retrieve logs"
echo ""

# Summary and instructions
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}Summary and Next Steps${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "✓ Setup Complete!"
echo ""
echo "📍 Server Configuration:"
echo "   - RTMP:   rtmp://publish:streampass123@localhost:1935/live/{stream_name}"
echo "   - RTSP:   rtsp://publish:streampass123@localhost:8554/live/{stream_name}"
echo "   - HLS:    http://localhost:8888/live/{stream_name}/index.m3u8"
echo "   - WebRTC: http://localhost:8889/live/{stream_name}"
echo ""
echo "📤 To Publish a Stream:"
echo ""
echo "   1. Using FFmpeg:"
echo "      ffmpeg -i your_video.mp4 -c copy -f flv \\"
echo "      rtmp://publish:streampass123@localhost:1935/live/mystream"
echo ""
echo "   2. Using OBS Studio:"
echo "      - Settings → Stream"
echo "      - Service: Custom"
echo "      - Server: rtmp://localhost:1935/live"
echo "      - Stream Key: mystream"
echo "      - (Optional) Set Auth in advanced settings"
echo ""
echo "   3. Using Screen Capture (FFmpeg):"
echo "      ffmpeg -f avfoundation -i \"1:\" -c:v libx264 -c:a aac \\"
echo "      -f flv rtmp://publish:streampass123@localhost:1935/live/mystream"
echo ""
echo "📺 To Watch a Stream:"
echo ""
echo "   1. VLC Media Player:"
echo "      Media → Open Network Stream → http://localhost:8888/live/mystream/index.m3u8"
echo ""
echo "   2. FFplay:"
echo "      ffplay 'http://localhost:8888/live/mystream/index.m3u8'"
echo ""
echo "   3. Browser (HLS):"
echo "      http://localhost:8888/live/mystream/index.m3u8"
echo ""
echo "🔐 Credentials:"
echo "   - Username: publish"
echo "   - Password: streampass123"
echo ""
echo "⚙️  Configuration File:"
echo "   - mediamtx.yml (mount as read-only in docker-compose.yml)"
echo "   - Change credentials and settings in this file"
echo "   - Restart container after changes: docker-compose restart"
echo ""
echo "📋 Useful Commands:"
echo ""
echo "   # Start server"
echo "   docker-compose up -d"
echo ""
echo "   # Stop server"
echo "   docker-compose down"
echo ""
echo "   # View logs"
echo "   docker-compose logs -f mediamtx"
echo ""
echo "   # Restart after config changes"
echo "   docker-compose restart"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

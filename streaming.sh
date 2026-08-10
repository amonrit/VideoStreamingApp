#!/bin/bash

# MediaMTX Streaming Server Control Script
# Usage: ./streaming.sh [start|stop|restart|status|logs|test]

set -e

STREAMING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/streaming"
cd "$STREAMING_DIR"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[i]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

# Show usage
usage() {
    echo "MediaMTX Streaming Server Control"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  start       Start the streaming server"
    echo "  stop        Stop the streaming server"
    echo "  restart     Restart the streaming server"
    echo "  status      Show server status"
    echo "  logs        View live server logs"
    echo "  test        Run quick verification test"
    echo "  shell       Open bash in streaming directory"
    echo ""
    echo "Examples:"
    echo "  $0 start       # Start streaming server"
    echo "  $0 logs        # View live logs"
    echo "  $0 test        # Verify server is working"
    echo ""
}

# Main commands
case "${1:-}" in
    start)
        info "Starting MediaMTX streaming server..."
        docker-compose up -d
        sleep 2
        success "Server started! Ports: RTMP(1935), HLS(8888), RTSP(8554), WebRTC(8889)"
        echo ""
        info "Run: $0 status  (to check status)"
        info "Run: $0 logs    (to view live logs)"
        ;;
    stop)
        info "Stopping MediaMTX streaming server..."
        docker-compose down
        success "Server stopped"
        ;;
    restart)
        info "Restarting MediaMTX streaming server..."
        docker-compose restart
        sleep 2
        success "Server restarted"
        echo ""
        info "Run: $0 logs  (to view logs)"
        ;;
    status)
        info "Checking server status..."
        if docker ps --filter "name=mediamtx" --format "{{.Names}}" | grep -q mediamtx; then
            success "MediaMTX server is RUNNING"
            echo ""
            docker ps --filter "name=mediamtx" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        else
            error "MediaMTX server is NOT running"
            echo ""
            info "Start with: $0 start"
            exit 1
        fi
        ;;
    logs)
        info "Showing live server logs (Ctrl+C to exit)"
        echo ""
        docker-compose logs -f mediamtx
        ;;
    test)
        info "Running server verification test..."
        echo ""
        if [ -x "./quick-test.sh" ]; then
            ./quick-test.sh
        else
            error "quick-test.sh not found"
            exit 1
        fi
        ;;
    shell)
        info "Opening shell in streaming directory..."
        echo "Current directory: $STREAMING_DIR"
        bash
        ;;
    help|--help|-h)
        usage
        ;;
    "")
        usage
        ;;
    *)
        error "Unknown command: $1"
        echo ""
        usage
        exit 1
        ;;
esac

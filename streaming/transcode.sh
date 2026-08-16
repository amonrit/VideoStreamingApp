#!/bin/bash
# Host-side wrapper for FFmpeg transcoding control
# Makes it easy to start/stop transcoding from the host machine
# Usage: ./transcode.sh start <stream_name>
#        ./transcode.sh stop <stream_name>
#        ./transcode.sh status

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$1" ]; then
    echo "❌ Usage:"
    echo "  $0 start <stream_name>    - Start transcoding"
    echo "  $0 stop <stream_name>     - Stop transcoding"
    echo "  $0 status                 - Show active transcoding"
    echo ""
    echo "Examples:"
    echo "  $0 start mystream"
    echo "  $0 stop mystream"
    echo "  $0 status"
    exit 1
fi

COMMAND=$1
STREAM_NAME=$2

case "$COMMAND" in
    start)
        if [ -z "$STREAM_NAME" ]; then
            echo "❌ Error: stream_name required"
            echo "Usage: $0 start <stream_name>"
            exit 1
        fi
        echo "🎬 Starting transcoding for: $STREAM_NAME"
        docker exec ffmpeg-transcoder python3 /ffmpeg-manager.py start "$STREAM_NAME"
        ;;
    stop)
        if [ -z "$STREAM_NAME" ]; then
            echo "❌ Error: stream_name required"
            echo "Usage: $0 stop <stream_name>"
            exit 1
        fi
        echo "🛑 Stopping transcoding for: $STREAM_NAME"
        docker exec ffmpeg-transcoder python3 /ffmpeg-manager.py stop "$STREAM_NAME"
        ;;
    status)
        echo "📊 FFmpeg Transcoding Status:"
        docker exec ffmpeg-transcoder python3 /ffmpeg-manager.py status
        ;;
    *)
        echo "❌ Unknown command: $COMMAND"
        echo "Use: start, stop, or status"
        exit 1
        ;;
esac

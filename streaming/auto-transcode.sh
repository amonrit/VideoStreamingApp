#!/bin/bash
# Auto-restart FFmpeg transcoding when stream drops
# Usage: ./auto-transcode.sh mystream

STREAM_NAME=${1:-mystream}
MAX_RETRIES=999
RETRY_DELAY=5
COUNTER=0

echo "🔄 Auto-Restart Monitor for: $STREAM_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Will auto-restart if stream stops"
echo "Press Ctrl+C to stop"
echo ""

while [ $COUNTER -lt $MAX_RETRIES ]; do
    COUNTER=$((COUNTER + 1))

    echo "[$(date '+%H:%M:%S')] 🎬 Attempt #$COUNTER - Starting transcoding..."

    # Start FFmpeg transcoding
    docker exec ffmpeg-transcoder bash /ffmpeg-config/ffmpeg-transcode.sh "$STREAM_NAME" \
        > /tmp/transcode_${STREAM_NAME}.log 2>&1

    # Check why it stopped
    if [ $? -eq 0 ]; then
        echo "[$(date '+%H:%M:%S')] ✅ Transcoding completed successfully"
    else
        echo "[$(date '+%H:%M:%S')] ⚠️  Transcoding stopped or failed"
    fi

    # Check if input stream still exists
    STREAM_CHECK=$(docker logs mediamtx 2>&1 | grep -c "is publishing to path '$STREAM_NAME'")

    if [ $STREAM_CHECK -gt 0 ]; then
        echo "[$(date '+%H:%M:%S')] 📡 Input stream still active - restarting in ${RETRY_DELAY}s..."
    else
        echo "[$(date '+%H:%M:%S')] 🔴 Input stream down - will retry when available"
    fi

    sleep $RETRY_DELAY
done

echo "❌ Max retries reached"

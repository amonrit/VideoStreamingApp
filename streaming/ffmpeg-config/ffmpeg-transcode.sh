#!/bin/bash
# Real-time RTMP → HLS transcoding with 480p, 360p variants
# Phase 1.2: FFmpeg Transcoding Script
# Usage: ./ffmpeg-transcode.sh <STREAM_NAME>
# Example: ./ffmpeg-transcode.sh mystream

set -e

if [ -z "$1" ]; then
    echo "❌ Error: STREAM_NAME required"
    echo "Usage: $0 <STREAM_NAME>"
    exit 1
fi

STREAM_NAME=$1
RTMP_URL="rtmp://mediamtx:1935/live/${STREAM_NAME}"
OUTPUT_DIR="/hls_output/${STREAM_NAME}"
LOG_FILE="/logs/ffmpeg-${STREAM_NAME}.log"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "🎬 Starting transcoding for: $STREAM_NAME" | tee -a "$LOG_FILE"
echo "📡 Input:  $RTMP_URL" | tee -a "$LOG_FILE"
echo "📂 Output: $OUTPUT_DIR" | tee -a "$LOG_FILE"
echo "---" | tee -a "$LOG_FILE"

# FFmpeg transcoding with 2 bitrate variants (480p, 360p)
# Using veryfast preset for minimal latency
# Outputs back to MediaMTX via RTMP for HLS serving
ffmpeg -hide_banner -loglevel warning \
  -i "$RTMP_URL" \
  -filter_complex "[0:v]split=2[v1][v2]; \
    [v1]scale=854:480[v1out]; \
    [v2]scale=640:360[v2out]" \
  \
  -map "[v1out]" -map "0:a" \
  -c:v libx264 -preset veryfast \
  -b:v 2000k -r 30 -g 6 -keyint_min 6 \
  -c:a aac -b:a 128k -ar 44100 \
  -f flv "rtmp://mediamtx:1935/live-480p" \
  \
  -map "[v2out]" -map "0:a" \
  -c:v libx264 -preset veryfast \
  -b:v 800k -r 30 -g 6 -keyint_min 6 \
  -c:a aac -b:a 128k -ar 44100 \
  -f flv "rtmp://mediamtx:1935/live-360p" \
  2>> "$LOG_FILE"

echo "✅ Transcoding completed for: $STREAM_NAME" | tee -a "$LOG_FILE"

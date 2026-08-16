#!/bin/bash
# Real-time RTMP → HLS transcoding with selectable bitrate variants
# Usage: ./ffmpeg-transcode.sh <STREAM_NAME> [RESOLUTIONS...]
# Examples:
#   ./ffmpeg-transcode.sh mystream               # Default: 480p 360p
#   ./ffmpeg-transcode.sh mystream 1080p 720p    # Sharp: 1080p + 720p
#   ./ffmpeg-transcode.sh mystream 480p 360p     # Blurry: 480p + 360p
#   ./ffmpeg-transcode.sh mystream 1080p 480p    # Mix: 1080p + 480p

set -e

if [ -z "$1" ]; then
    echo "❌ Error: STREAM_NAME required"
    echo "Usage: $0 <STREAM_NAME> [1080p|720p|480p|360p] ..."
    echo "Example: $0 mystream 1080p 720p 480p 360p"
    exit 1
fi

STREAM_NAME=$1
shift || true
RESOLUTIONS=("$@")

# Default resolutions if none specified
if [ ${#RESOLUTIONS[@]} -eq 0 ]; then
    RESOLUTIONS=("480p" "360p")
fi

# Resolution config: width:height:bitrate
declare -A RES_CONFIG
RES_CONFIG[1080p]="1920:1080:5000"
RES_CONFIG[720p]="1280:720:2500"
RES_CONFIG[480p]="854:480:1200"
RES_CONFIG[360p]="640:360:600"

RTMP_URL="rtmp://mediamtx:1935/live/${STREAM_NAME}"
OUTPUT_DIR="/hls_output/${STREAM_NAME}"
LOG_FILE="/logs/ffmpeg-${STREAM_NAME}.log"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "🎬 Starting transcoding for: $STREAM_NAME" | tee -a "$LOG_FILE"
echo "📡 Input:  $RTMP_URL" | tee -a "$LOG_FILE"
echo "📂 Resolutions: ${RESOLUTIONS[*]}" | tee -a "$LOG_FILE"
echo "---" | tee -a "$LOG_FILE"

# Build filter_complex and ffmpeg command
FILTER_COMPLEX="[0:v]fps=30,split=${#RESOLUTIONS[@]}"

# Add split outputs to filter
for ((i=0; i<${#RESOLUTIONS[@]}; i++)); do
    FILTER_COMPLEX="${FILTER_COMPLEX}[v$i]"
done
FILTER_COMPLEX="${FILTER_COMPLEX};"

# Build scale filters and collect output args
FFMPEG_ARGS=()
for ((i=0; i<${#RESOLUTIONS[@]}; i++)); do
    res="${RESOLUTIONS[$i]}"
    config="${RES_CONFIG[$res]}"

    if [ -z "$config" ]; then
        echo "❌ Unknown resolution: $res"
        exit 1
    fi

    IFS=':' read -r width height bitrate <<< "$config"
    FILTER_COMPLEX="${FILTER_COMPLEX}[v$i]scale=${width}:${height}[v${i}out];"

    # Add output mapping for this resolution
    FFMPEG_ARGS+=("-map" "[v${i}out]" "-map" "0:a")
    FFMPEG_ARGS+=("-c:v" "libx264" "-preset" "veryfast" "-tune" "zerolatency")
    FFMPEG_ARGS+=("-b:v" "${bitrate}k" "-r" "30")
    FFMPEG_ARGS+=("-g" "6" "-keyint_min" "6" "-sc_threshold" "0")
    FFMPEG_ARGS+=("-c:a" "aac" "-b:a" "128k" "-ar" "44100" "-async" "1")
    FFMPEG_ARGS+=("-f" "flv" "rtmp://mediamtx:1935/live-${res}")
done

# Remove trailing semicolon if present
FILTER_COMPLEX="${FILTER_COMPLEX%;}"

# Execute FFmpeg with dynamic arguments
ffmpeg -hide_banner -loglevel warning \
  -i "$RTMP_URL" \
  -filter_complex "$FILTER_COMPLEX" \
  "${FFMPEG_ARGS[@]}" \
  2>> "$LOG_FILE"

echo "✅ Transcoding completed for: $STREAM_NAME" | tee -a "$LOG_FILE"

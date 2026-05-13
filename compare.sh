#!/bin/bash

# Ensure an input file parameter is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <original_media_file>"
    exit 1
fi

ORIGINAL_FILE="$1"
GENERATED_FILE="fil.wav"

# Ensure the generated test file exists
if [ ! -f "$GENERATED_FILE" ]; then
    echo "Error: Target file '$GENERATED_FILE' not found in current directory."
    exit 1
fi

# Determine the total duration of the original track using ffprobe
DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$ORIGINAL_FILE")
# Fallback length if ffprobe metadata calculation fails
if [ -z "$DURATION" ] || [ "$DURATION" == "N/A" ]; then
    DURATION=300
fi

# Floor the duration integer value
TOTAL_SECONDS=${DURATION%.*}
CURRENT_TIME=0

echo "=== Starting A/B Alternating Comparison ==="
echo "Original source:   $ORIGINAL_FILE"
echo "Generated tracker: $GENERATED_FILE"
echo "-----------------------------------------"

# Loop sequentially through the track timeline
while [ $CURRENT_TIME -lt $TOTAL_SECONDS ]; do
    
    # 1. Play 5 seconds of the original file (Supports video/audio formats)
    echo "[Time: ${CURRENT_TIME}s] 🔊 Playing ORIGINAL File..."
    ffplay -ss "$CURRENT_TIME" -t 5 -nodisp -autoexit -loglevel error "$ORIGINAL_FILE" >/dev/null
    
    # 2. Play 5 seconds of the generated WAV matching the current timestamp position
    echo "[Time: ${CURRENT_TIME}s] 🕹️ Playing GENERATED Chiptune File..."
    ffplay -ss "$CURRENT_TIME" -t 5 -nodisp -autoexit -loglevel error "$GENERATED_FILE" >/dev/null
    
    echo
    
    # Increment tracking timestamp forward by 5 seconds
    CURRENT_TIME=$((CURRENT_TIME + 5))
done

echo "=== Comparison Finished ==="

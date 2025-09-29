#!/usr/bin/env bash
# Simple SatDump wrapper for Meteor LRPT recordings
# Usage: ./meteor_decode.sh path/to/recording.raw16

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <path_to_raw16_file>"
    exit 1
fi

INPUT_FILE="$1"

# Make sure the file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File '$INPUT_FILE' not found"
    exit 1
fi

# Create a timestamped output directory
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_DIR="$(dirname "$INPUT_FILE")/meteor_output_$TIMESTAMP"
mkdir -p "$OUTPUT_DIR"

# Sample rate and format (adjust if you recorded differently)
SAMPLERATE=72000
BASEBAND_FORMAT="s16"

# Run SatDump CLI via your flake
nix run ~/flakes/satdump#satdump -- meteor_lrpt baseband "$INPUT_FILE" "$OUTPUT_DIR" \
    --samplerate "$SAMPLERATE" --baseband_format "$BASEBAND_FORMAT"

echo "Decoding complete! Images are in: $OUTPUT_DIR"


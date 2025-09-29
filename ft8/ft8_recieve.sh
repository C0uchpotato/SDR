#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# FT8 Receive Script — Continuous / Bulletproof
# Automatically recovers from rtl_fm crashes, underruns, or CPU hiccups

declare -A FT8_FREQUENCIES=(
  ["80m"]="3.573M"
  ["40m"]="7.074M"
  ["20m"]="14.074M"
  ["15m"]="21.074M"
  ["10m"]="28.074M"
)

DEFAULT_BAND="20m"
DEFAULT_FREQ="${FT8_FREQUENCIES[$DEFAULT_BAND]}"
RTL_GAIN=40
WSJT_SAMPLE_RATE=48000
declare -A RTL_SAMPLE_RATES=(
  ["80m"]=6000
  ["40m"]=8000
  ["20m"]=12000
  ["15m"]=12000
  ["10m"]=12000
)

# Parse args
FREQ="$DEFAULT_FREQ"
BAND=""
while (( "$#" )); do
  case "$1" in
    --band) BAND="$2"; shift 2 ;;
    *) FREQ="$1"; shift ;;
  esac
done

# Determine frequency from band
# Initialize BAND_KEY to empty
BAND_KEY=""

# Handle --band argument
if [[ -n "$BAND" ]]; then
  if [[ -n "${FT8_FREQUENCIES[$BAND]:-}" ]]; then
    FREQ="${FT8_FREQUENCIES[$BAND]}"
    BAND_KEY="$BAND"
  else
    echo "Unknown band: $BAND"
    exit 2
  fi
fi

# If BAND_KEY still empty, determine from FREQ
if [[ -z "$BAND_KEY" ]]; then
  for k in "${!FT8_FREQUENCIES[@]}"; do
    if [[ "$FREQ" == "${FT8_FREQUENCIES[$k]}" ]]; then
      BAND_KEY="$k"
      break
    fi
  done
fi

# Fallback to default if BAND_KEY is still empty
if [[ -z "$BAND_KEY" ]]; then
  BAND_KEY="$DEFAULT_BAND"
fi



# Determine RTL sample rate
BAND_KEY="$BAND"
if [[ -z "$BAND_KEY" ]]; then
  for k in "${!FT8_FREQUENCIES[@]}"; do
    if [[ "$FREQ" == "${FT8_FREQUENCIES[$k]}" ]]; then
      BAND_KEY="$k"
      break
    fi
  done
fi
RTL_SAMPLE_RATE="${RTL_SAMPLE_RATES[$BAND_KEY]:-12000}"

# Detect PipeWire
PIPEWIRE_SINK=$(pactl list short sinks 2>/dev/null | grep loopback | awk '{print $2}' || true)

if [[ -n "$PIPEWIRE_SINK" ]]; then
  AUDIO_DEVICE="pulse:$PIPEWIRE_SINK"
  WSJTX_INPUT="PulseAudio device: $AUDIO_DEVICE (select in WSJT-X)"
else
  ALSA_PLAY_DEVICE="plughw:Loopback,0,0"
  ALSA_CAPTURE_DEVICE="plughw:Loopback,1,0"
  AUDIO_DEVICE="$ALSA_PLAY_DEVICE"
  WSJTX_INPUT="ALSA device: $ALSA_CAPTURE_DEVICE (Mono, 48kHz)"
  sudo modprobe snd_aloop || echo "snd_aloop already loaded"
  sleep 0.5
fi

echo
echo "=== FT8 Receive Setup ==="
echo "FT8 Frequency: $FREQ"
echo "RTL Gain: $RTL_GAIN"
echo "RTL Sample Rate: $RTL_SAMPLE_RATE"
echo "WSJT-X Sample Rate: $WSJT_SAMPLE_RATE"
echo "Audio Output Device: $AUDIO_DEVICE"
echo "WSJT-X Input: $WSJTX_INPUT"
echo "========================"
echo

PIPELINE_LOG="ft8_rtl_pipeline.log"

# Main loop — automatically restarts rtl_fm if it exits
while true; do
  echo "Starting rtl_fm -> sox -> audio pipeline (Ctrl-C to stop)"
  if [[ -n "$PIPEWIRE_SINK" ]]; then
    rtl_fm -f "$FREQ" -M usb -g "$RTL_GAIN" -s "$RTL_SAMPLE_RATE" -p 0 \
      | sox -q -t raw -r "$RTL_SAMPLE_RATE" -e signed -b 16 -c 1 - \
            -r "$WSJT_SAMPLE_RATE" -c 1 -t wav - \
      | paplay --device="$AUDIO_DEVICE" --rate=$WSJT_SAMPLE_RATE 2>&1 | tee "$PIPELINE_LOG"
  else
    rtl_fm -f "$FREQ" -M usb -g "$RTL_GAIN" -s "$RTL_SAMPLE_RATE" -p 0 \
      | sox -q -t raw -r "$RTL_SAMPLE_RATE" -e signed -b 16 -c 1 - \
            -r "$WSJT_SAMPLE_RATE" -c 1 -t wav - \
      | aplay -D "$ALSA_CAPTURE_DEVICE" -f cd -B 1000000 -F 200000 2>&1 | tee "$PIPELINE_LOG"
  fi
  echo "Pipeline exited unexpectedly. Restarting in 2s…"
  sleep 2
done


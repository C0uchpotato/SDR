#!/usr/bin/env bash
# capture_sat.sh
# Usage:
#   ./capture_sat.sh apt 137.100M 600 outbase [gain]
#   ./capture_sat.sh meteor 137900000 600 outbase [gain]
#
# Modes:
#   - apt    : record an APT pass (analog NOAA historical style). Produces outbase.wav and tries to run noaa-apt to make PNG.
#   - meteor : record raw IQ/baseband for LRPT (Meteor). Produces outbase.u8 (unsigned 8-bit IQ). Decode with SatDump (examples printed).
#
# Notes:
#  - This script just *records* the pass for a fixed duration (seconds). Use a pass predictor (Heavens-Above / N2YO / SatDump scheduler) to start at AOS.
#  - Adjust sample rate and gain for your hardware/antenna. Typical Meteor sample rates: 900k-1.024Msps; APT: audio centered ~60k.
#  - Requires rtl_fm / rtl_sdr / sox to be in PATH. SatDump is optional (used to decode LRPT files).

set -euo pipefail
shopt -s nocasematch

if [ "$#" -lt 4 ]; then
  echo "Usage: $0 {apt|meteor} FREQ DURATION_OUT_SECONDS OUTBASE [GAIN]"
  echo "Examples:"
  echo "  $0 apt 137.100M 600 noaa_pass 40"
  echo "  $0 meteor 137900000 600 meteor_pass 40"
  exit 2
fi

MODE="$1"
FREQ_RAW="$2"
DURATION="$3"
OUTBASE="$4"
GAIN="${5:-40}"

# convert freq to Hz if user used 'M' suffix (e.g. 137.100M)
if [[ "$FREQ_RAW" == *M ]]; then
  # strip trailing M and multiply by 1e6 (supports decimals)
  fnum="${FREQ_RAW%M}"
  # awk will print integer Hz (no exponential)
  FREQ_HZ=$(awk "BEGIN{printf(\"%.0f\", $fnum * 1000000)}")
else
  FREQ_HZ="$FREQ_RAW"
fi

echo "--> mode: $MODE"
echo "--> freq (Hz): $FREQ_HZ"
echo "--> duration (s): $DURATION"
echo "--> outbase: $OUTBASE"
echo "--> gain: $GAIN"

# helper: check for command presence
need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "ERROR: required command '$1' not found. Install it."; exit 3; }
}

# Mode-specific record + decode
case "$MODE" in
  apt)
    # APT flow (analog): rtl_fm demodulates to signed16 audio; use sox to create proper WAV (11025Hz) for noaa-apt
    need_cmd rtl_fm
    need_cmd sox

    WAV="${OUTBASE}.wav"
    echo "Recording APT (FM audio demod) to $WAV ..."
    # rtl_fm -> sox, runs for DURATION seconds
    # -s 60k chosen for NOAA/APT; -M fm demod. Adjust -g gain as needed.
    # sox reads raw signed 16-bit little endian mono at 60000Hz, converts & resamples to 11025Hz WAV (what many APT decoders like).
    timeout "${DURATION}"s bash -c \
      "rtl_fm -f ${FREQ_HZ} -M fm -s 60k -g ${GAIN} - | sox -t raw -r 60000 -es -b 16 -c 1 - ${WAV} rate 11025" || true

    if [ ! -s "${WAV}" ]; then
      echo "WARNING: recorded WAV is empty or missing. Check rtl device, antenna, permissions."
      exit 4
    fi

    echo "Recorded $WAV"
    if command -v noaa-apt >/dev/null 2>&1; then
      echo "Running noaa-apt decoder..."
      PNG="${OUTBASE}.png"
      # noaa-apt python CLI: -i input.wav -o output.png (some installs: noaa-apt input.wav -o out.png)
      # We'll try the common syntax and fallback.
      if noaa-apt -h >/dev/null 2>&1; then
        noaa-apt -i "${WAV}" -o "${PNG}" || echo "noaa-apt failed (it may expect different args). Try: 'noaa-apt ${WAV}'"
      else
        noaa-apt "${WAV}" -o "${PNG}" || noaa-apt "${WAV}" || echo "noaa-apt invocation failed; check its CLI on your system."
      fi
      echo "If decode succeeded you should have: ${PNG}"
    else
      echo "noaa-apt not installed -> WAV is ready: ${WAV}. Install 'noaa-apt' (pip) or use an image decoder (WXtoImg, noaa-apt) to convert."
    fi
    ;;

  meteor)
    # Meteor LRPT flow: record raw IQ (unsigned 8-bit interleaved 'u8'), user decodes with SatDump (recommended)
    need_cmd rtl_sdr
    need_cmd timeout

    # default sample rate for Meteor LRPT recordings with RTL-SDR — 1.024Msps is safe/generic. If you have problems try 900k.
    SR="${6:-1024000}"
    IQFILE="${OUTBASE}.u8"

    echo "Recording baseband IQ (u8) to ${IQFILE} at samplerate ${SR} ... (duration: ${DURATION}s)"
    # rtl_sdr prints raw u8 IQ to stdout; timeout used to limit capture duration
    # Note: you may need to run as root or allow access to the device (udev rules).
    timeout "${DURATION}"s bash -c "rtl_sdr -f ${FREQ_HZ} -s ${SR} -g ${GAIN} - | dd of=${IQFILE} bs=1M conv=fsync" || true

    if [ ! -s "${IQFILE}" ]; then
      echo "WARNING: IQ file empty or missing. Check rtl device, antenna and permissions."
      exit 5
    fi

    echo "Recorded IQ file: ${IQFILE}"
    echo ""
    echo "Next: decode with SatDump (recommended). Example offline command (adjust samplerate/baseband_format if needed):"
    echo ""
    echo "  satdump meteor_m2-x_lrpt_80k baseband ${IQFILE} ${OUTBASE}_satdump_out --samplerate ${SR} --baseband_format u8"
    echo ""
    echo "If you don't have satdump installed, get it at: https://www.satdump.org/ (Linux builds & docs). SatDump can also autotrack passes and decode live."
    ;;
  *)
    echo "Unknown mode: $MODE"
    exit 2
    ;;
esac

echo "Done."


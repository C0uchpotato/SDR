#!/usr/bin/env bash
set -euo pipefail

TLE_FILE="$HOME/SDR/sats/meteor.tle"

# List of NORAD IDs you want
NORAD_IDS=(
  25338  # NOAA 15
  28654  # NOAA 18
  33591  # NOAA 19
  27820  # Meteor-M1
  40069  # Meteor-M2
  27844  # CO-55
  22825  # AO-27
  7530  # OSCAR 7
)

# Clear the file (or recreate)
: > "$TLE_FILE"

for id in "${NORAD_IDS[@]}"; do
  # Fetch single TLE (gp.php supports only one CATNR per request) :contentReference[oaicite:1]{index=1}
  url="https://celestrak.org/NORAD/elements/gp.php?CATNR=${id}&FORMAT=TLE"
  echo "Fetching NORAD ID ${id} ..."
  # If the fetch fails, continue (so one bad doesn't break all)
  if curl -s "${url}" >> "$TLE_FILE"; then
    echo "  → success"
  else
    echo "  → failed (id ${id})" >&2
  fi
  # optional: separate entries by a blank line
  echo "" >> "$TLE_FILE"
done

echo "Done. TLEs written to ${TLE_FILE}"


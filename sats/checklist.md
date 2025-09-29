📑 NOAA & Meteor Satellite Recording Checklist (SDR++)
🔧 General SDR++ Setup

Device Sample Rate: 2.048 MSPS (Device tab)

Gain: 30–40 dB (manual, not auto)

Audio Sample Rate: 48 kHz, mono (Audio tab)

NFM -> NOAA
RAW -> METEOR

Recorder Type:

Audio WAV (16-bit) → NOAA APT

Baseband → Meteor LRPT

Start Recording: ~1 min before AOS

Stop Recording: ~1 min after LOS

| Satellite | Frequency (MHz) | Mode | Bandwidth | Recorder                | Decoder            |
| --------- | --------------- | ---- | --------- | ----------------------- | ------------------ |
| NOAA-15   | 137.6200        | NFM  | ~40 kHz   | Audio (48k WAV, 16-bit) | noaa-apt / WXtoImg |
| NOAA-18   | 137.9125        | NFM  | ~40 kHz   | Audio (48k WAV, 16-bit) | noaa-apt / WXtoImg |
| NOAA-19   | 137.1000        | NFM  | ~40 kHz   | Audio (48k WAV, 16-bit) | noaa-apt / WXtoImg |


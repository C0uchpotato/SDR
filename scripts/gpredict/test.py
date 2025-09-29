#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import time
import math
from datetime import datetime, timedelta, timezone
from skyfield.api import load, EarthSatellite, wgs84
from pytz import timezone as pytz_timezone

# -----------------------------
# USER CONFIGURATION
# -----------------------------
tle_source = "/home/astro-helmer/SDR/sats/meteor.tle"
min_elevation_deg = 50
observer_lat = 35.2271
observer_lon = -80.8431
observer_alt_m = 0
lookahead_days = 7
max_passes_to_show = 12
refresh_interval = 15  # seconds
# -----------------------------

ts = load.timescale()
observer = wgs84.latlon(observer_lat, observer_lon, observer_alt_m)
ny_tz = pytz_timezone('America/New_York')

# -----------------------------
# Satellite frequencies (Hz)
# -----------------------------
sat_frequencies = {
    "NOAA 15": 137.6200e6,
    "NOAA 18": 137.9125e6,
    "NOAA 19": 137.1000e6,
    "OSCAR 7": 145.970e6,
    "METEOR-M": 137.900e6,
    "METEOR-M2": 137.900e6,
    "EYESAT 1": 436.795e6,
    "CUTE-1": 437.470e6
}

# -----------------------------
# ANSI COLORS
# -----------------------------
class Colors:
    RED = "\033[91m"
    YELLOW = "\033[93m"
    GREEN = "\033[92m"
    CYAN = "\033[96m"
    BOLD = "\033[1m"
    RESET = "\033[0m"

def color_countdown(delta):
    if isinstance(delta, str) and delta == "In Progress":
        return f"{Colors.CYAN}{delta}{Colors.RESET}"
    seconds = delta.total_seconds()
    if seconds < 3600:
        return f"{Colors.RED}{str(delta).split('.')[0]}{Colors.RESET}"
    elif seconds < 21600:
        return f"{Colors.YELLOW}{str(delta).split('.')[0]}{Colors.RESET}"
    else:
        return f"{Colors.GREEN}{str(delta).split('.')[0]}{Colors.RESET}"

# -----------------------------
# FSPL calculation (dB)
# -----------------------------
def fspl_db(distance_km, frequency_hz):
    f_mhz = frequency_hz / 1e6
    return 20 * math.log10(distance_km) + 20 * math.log10(f_mhz) + 32.44

# -----------------------------
# Load TLEs
# -----------------------------
def load_tles(path):
    sats = []
    if not os.path.exists(path):
        print(f"TLE file not found: {path}")
        return sats
    with open(path) as f:
        lines = [l.strip() for l in f if l.strip()]
    i = 0
    while i < len(lines) - 2:
        name = lines[i]
        line1 = lines[i+1]
        line2 = lines[i+2]
        try:
            sat = EarthSatellite(line1, line2, name, ts)
            sat.name = name
            sats.append(sat)
        except Exception as e:
            print(f"Error loading {name}: {e}")
        i += 3
    return sats

# -----------------------------
# Find passes above min elevation
# -----------------------------
def find_passes(sat, observer, min_elev, lookahead_days):
    now = datetime.now(timezone.utc)
    t0 = ts.from_datetime(now)
    t1 = ts.from_datetime(now + timedelta(days=lookahead_days))
    times, events = sat.find_events(observer, t0, t1, altitude_degrees=0.0)
    passes = []
    aos, los = None, None

    for t, event in zip(times, events):
        if event == 0:
            aos = t
        elif event == 2 and aos is not None:
            los = t
            sample_times = ts.linspace(aos, los, 50)
            difference = sat.at(sample_times) - observer.at(sample_times)
            altitudes = difference.altaz()[0].degrees
            max_el = max(altitudes)
            if max_el >= min_elev:
                passes.append((aos, los, max_el, sat.name, sat, sample_times))
            aos, los = None, None
    return passes

# -----------------------------
# Format window in NY time
# -----------------------------
def format_window(aos, los):
    aos_est = aos.utc_datetime().astimezone(ny_tz)
    los_est = los.utc_datetime().astimezone(ny_tz)
    date_str = aos_est.strftime('%Y-%m-%d')
    time_str = f"{aos_est.strftime('%H:%M')}-{los_est.strftime('%H:%M')}"
    return date_str, time_str

# -----------------------------
# MAIN LOOP
# -----------------------------
try:
    while True:
        satellites = load_tles(tle_source)
        tle_mtime = datetime.utcfromtimestamp(os.path.getmtime(tle_source)).replace(tzinfo=timezone.utc) if os.path.exists(tle_source) else None

        all_passes = []
        for sat in satellites:
            all_passes.extend(find_passes(sat, observer, min_elevation_deg, lookahead_days))

        now = datetime.now(timezone.utc)
        all_passes.sort(key=lambda p: p[0].utc_datetime())
        all_passes = all_passes[:max_passes_to_show]

        os.system("clear")
        tle_info = f"TLE last updated: {tle_mtime.strftime('%Y-%m-%d %H:%M:%S UTC')}" if tle_mtime else "TLE file not found"
        print(f"Observer: {observer_lat},{observer_lon} | Min Elevation: {min_elevation_deg}° | Lookahead: {lookahead_days} days")
        print(f"Refresh: {now.strftime('%Y-%m-%d %H:%M:%S UTC')} | {tle_info}\n")

        print(f"{'Satellite':<25}{'Date Window(EST)':<21}{'MaxEl':>6}{'   '}{'Countdown':>12}")
        print("-" * 75)

        if not all_passes:
            print("No passes above minimum elevation in the lookahead window.")
        else:
            active_passes = []
            upcoming_passes = []
            for aos, los, max_el, name, sat_obj, sample_times in all_passes:
                aos_dt = aos.utc_datetime().replace(tzinfo=timezone.utc)
                los_dt = los.utc_datetime().replace(tzinfo=timezone.utc)
                if aos_dt <= now <= los_dt:
                    active_passes.append((aos, los, max_el, name, sat_obj, sample_times))
                elif aos_dt > now:
                    upcoming_passes.append((aos, los, max_el, name, sat_obj, sample_times))

            # Active passes
            if active_passes:
                print(f"{Colors.BOLD}ACTIVE PASSES{Colors.RESET}")
                for aos, los, max_el, name, sat_obj, sample_times in active_passes:
                    date_str, window_str = format_window(aos, los)
                    countdown_str = color_countdown("In Progress")
                    print(f"{Colors.BOLD}{name:<25}{Colors.RESET}{date_str} {window_str:<16}{max_el:>6.1f}{'   '}{countdown_str:>12}")
                print("-" * 75)

            # Upcoming passes
            if upcoming_passes:
                print(f"{Colors.BOLD}UPCOMING PASSES{Colors.RESET}")
                for aos, los, max_el, name, sat_obj, sample_times in upcoming_passes:
                    date_str, window_str = format_window(aos, los)
                    countdown = aos.utc_datetime().replace(tzinfo=timezone.utc) - now
                    print(f"{name:<25}{date_str} {window_str:<16}{max_el:>6.1f}{'   '}{color_countdown(countdown):>12}")

            # Detailed info for currently active pass (bottom of screen)
            if active_passes:
                print("\n" + Colors.BOLD + "ACTIVE PASS DETAILS" + Colors.RESET)
                for aos, los, max_el, name, sat_obj, sample_times in active_passes:
                    idx = min(range(len(sample_times)), key=lambda i: abs((sample_times[i]-ts.from_datetime(now)).utc_seconds()))
                    pos = sat_obj.at(sample_times[idx])
                    difference = pos - observer
                    alt, az, distance = difference.altaz()
                    velocity = pos.velocity.km_per_s
                    frequency = sat_frequencies.get(sat_obj.name, 137.0e6)
                    signal_loss_db = fspl_db(distance.km, frequency)
                    print(f"{Colors.BOLD}{name}{Colors.RESET}: Alt {alt.degrees:.1f}°, Az {az.degrees:.1f}°, "
                          f"Dist {distance.km:.1f} km, Vel {velocity:.2f} km/s, "
                          f"Freq {frequency/1e6:.3f} MHz, Loss {signal_loss_db:.1f} dB")

        time.sleep(refresh_interval)

except KeyboardInterrupt:
    print("\nExiting on user request.")


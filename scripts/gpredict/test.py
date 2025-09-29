#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import time
import os
from datetime import datetime, timedelta, timezone
from skyfield.api import load, EarthSatellite, wgs84

# -----------------------------
# USER CONFIGURATION
# -----------------------------
tle_source = "/home/waffa/SDR/sats/meteor.tle"
min_elevation_deg = 50
observer_lat = 35.2271
observer_lon = -80.8431
observer_alt_m = 0
lookahead_days = 7
max_passes_to_show = 12
refresh_interval = 15
# -----------------------------

ts = load.timescale()
observer = wgs84.latlon(observer_lat, observer_lon, observer_alt_m)

# -----------------------------
# ANSI COLORS AND BOLD
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
            epoch = sat.epoch.utc_datetime().strftime("%Y-%m-%d")
            sat.name = f"{name} ({epoch})"
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
        if event == 0:  # Rise
            aos = t
        elif event == 2 and aos is not None:  # Set
            los = t
            sample_times = ts.linspace(aos, los, 50)
            difference = sat.at(sample_times) - observer.at(sample_times)
            altitudes = difference.altaz()[0].degrees
            max_el = max(altitudes)
            if max_el >= min_elev:
                passes.append((aos, los, max_el, sat.name))
            aos, los = None, None
    return passes

# -----------------------------
# Main loop
# -----------------------------
try:
    while True:
        satellites = load_tles(tle_source)
        tle_mtime = None
        if os.path.exists(tle_source):
            tle_mtime = datetime.utcfromtimestamp(os.path.getmtime(tle_source)).replace(tzinfo=timezone.utc)

        all_passes = []
        for sat in satellites:
            all_passes.extend(find_passes(sat, observer, min_elevation_deg, lookahead_days))

        # sort by AOS
        all_passes.sort(key=lambda p: p[0].utc_datetime())
        all_passes = all_passes[:max_passes_to_show]

        now = datetime.now(timezone.utc)
        os.system("clear")

        tle_info = f"TLE last updated: {tle_mtime.strftime('%Y-%m-%d %H:%M:%S UTC')}" if tle_mtime else "TLE file not found"
        print(f"Observer: {observer_lat},{observer_lon} | Min Elevation: {min_elevation_deg}° | Lookahead: {lookahead_days} days")
        print(f"Script refresh: {now.strftime('%Y-%m-%d %H:%M:%S UTC')} | {tle_info}\n")

        print(f"{'Satellite':<30} {'Pass Window (UTC)':<24} {'Max El(°)':<10} {'Countdown':<12}")
        print("-" * 85)

        if not all_passes:
            print("No passes above minimum elevation in the lookahead window.\n")
        else:
            active_passes = []
            upcoming_passes = []
            for aos, los, max_el, name in all_passes:
                aos_dt = aos.utc_datetime().replace(tzinfo=timezone.utc)
                los_dt = los.utc_datetime().replace(tzinfo=timezone.utc)
                countdown = aos_dt - now
                if countdown.total_seconds() <= 0 <= (los_dt - now).total_seconds():
                    active_passes.append((aos, los, max_el, name))
                elif countdown.total_seconds() > 0:
                    upcoming_passes.append((aos, los, max_el, name))

            # ACTIVE PASSES
            if active_passes:
                print(f"{Colors.BOLD}ACTIVE PASSES{Colors.RESET}")
                for aos, los, max_el, name in active_passes:
                    aos_dt = aos.utc_datetime().replace(tzinfo=timezone.utc)
                    los_dt = los.utc_datetime().replace(tzinfo=timezone.utc)
                    countdown_str = color_countdown("In Progress")
                    window_str = f"{aos_dt.strftime('%Y-%m-%d %H:%M')}–{los_dt.strftime('%H:%M')}"
                    print(f"{Colors.BOLD}{name:<30}{Colors.RESET} {window_str:<24} {max_el:>8.1f} {countdown_str:<12}\n")
                print("-" * 85)

            # UPCOMING PASSES
            if upcoming_passes:
                print(f"{Colors.BOLD}UPCOMING PASSES{Colors.RESET}")
                for aos, los, max_el, name in upcoming_passes:
                    aos_dt = aos.utc_datetime().replace(tzinfo=timezone.utc)
                    los_dt = los.utc_datetime().replace(tzinfo=timezone.utc)
                    countdown = aos_dt - now
                    countdown_str = color_countdown(countdown)
                    window_str = f"{aos_dt.strftime('%Y-%m-%d %H:%M')}–{los_dt.strftime('%H:%M')}"
                    print(f"{name:<30} {window_str:<24} {max_el:>8.1f} {countdown_str:<12}\n")

        time.sleep(refresh_interval)

except KeyboardInterrupt:
    print("\nExiting on user request.")


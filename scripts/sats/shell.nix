{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    rtl-sdr       # rtl_fm, rtl_test, rtl_power
    sox           # audio handling
    pulseaudio    # audio routing
    wsjtx         # FT8/FT4/WSPR decoder
  ];

  shellHook = ''
    echo "=== NOAA/FT8 environment ==="
    echo "Commands available: rtl_fm, sox, wsjtx"
    echo "Tip: first create a PulseAudio loopback sink:"
    echo "   pactl load-module module-null-sink sink_name=loopback"
    echo "Then run rtl_fm -> sox -> play into loopback."
  '';
}


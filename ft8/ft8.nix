{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    rtl-sdr        # rtl_fm/rtl_tcp/rtl_sdr
    sox            # audio conversion / piping
    alsa-utils      # aplay/arecord/amixer
    pavucontrol    # optional (for PipeWire/Pulse management)
    wget
    # WSJT-X may or may not be packaged in your channel; if available uncomment:
    # wsjtx
    inspectrum     # handy for visual analysis (optional)
    multimon-ng    # optional, other decoders
  ];

  # Helpful animation-less prompt
  shellHook = ''
    echo "Entering FT8 receive shell. Available tools: rtl_fm, sox, aplay, arecord, amixer"
    echo "Run ./ft8_receive.sh --help for usage."
  '';
}


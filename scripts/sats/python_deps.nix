{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [
    (pkgs.python311.withPackages (ps: with ps; [
      skyfield
      requests
      pytz
    ]))
  ];

  shellHook = ''
    echo "Python 3.11 environment ready with Skyfield, requests, and pytz."
  '';
}


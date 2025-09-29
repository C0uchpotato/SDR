rtl_fm -f 137.100M -M fm -s 48k -g 40 - | \
  sox -t raw -r 48k -e signed -b 16 -c 1 - noaa.wav

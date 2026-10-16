#!/bin/bash
# Moniteur d'etat affichage — attrape l'ecran noir
# Echantillonne 1x/s: backlight, statut eDP, charge GPU, temp amdgpu
BL=/sys/class/backlight/gmux_backlight/brightness
EDP=/sys/class/drm/card1-eDP-1/status
BUSY=/sys/class/drm/card1/device/gpu_busy_percent
TEMP=""
for t in /sys/class/drm/card1/device/hwmon/hwmon*/temp1_input; do TEMP=$t; break; done
OUT=/home/benoit/t1-diag/blacklog.csv
echo "time,backlight,edp_status,gpu_busy,amdgpu_temp" > "$OUT"
echo "moniteur lance a $(date '+%F %T') -> $OUT"
while true; do
  ts=$(date +%H:%M:%S)
  bl=$(cat "$BL" 2>/dev/null)
  edp=$(cat "$EDP" 2>/dev/null)
  busy=$(cat "$BUSY" 2>/dev/null)
  tmp=$(cat "$TEMP" 2>/dev/null)
  echo "$ts,$bl,$edp,$busy,$tmp" >> "$OUT"
  sleep 1
done

#!/bin/bash
# Watchdog v2 camera virtuelle T1:
# - stub (noir) tourne par defaut (camera T1 eteinte, device pret)
# - si une app consomme /dev/video2 -> stub stop, pipeline reel demarre (camera T1 allumee)
# - si plus aucun consommateur pendant 5s -> pipeline reel stop, stub relance
DEV=/dev/video2
REAL=t1-virtualcam.service
STUB=t1-cam-stub.service
IDLE_LIMIT=5
last_busy=0
real_up() { systemctl --user is-active --quiet $REAL; }
stub_up() { systemctl --user is-active --quiet $STUB; }
while true; do
  now=$(date +%s)
  holders=$(fuser $DEV 2>/dev/null | xargs -n1 2>/dev/null)
  busy=0
  for pid in $holders; do
    [ -r "/proc/$pid/cmdline" ] || continue
    cmd=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null)
    case "$cmd" in
      *gst-launch*) continue ;;
      *fuser*) continue ;;
    esac
    busy=1
    break
  done
  if [ "$busy" = "1" ]; then
    last_busy=$now
    if ! real_up; then
      stub_up && systemctl --user stop $STUB
      sleep 0.3
      systemctl --user start $REAL
    fi
  fi
  if [ $((now - last_busy)) -ge $IDLE_LIMIT ]; then
    if real_up; then
      systemctl --user stop $REAL
      sleep 0.3
      systemctl --user start $STUB
    fi
    last_busy=0
  fi
  sleep 0.5
done

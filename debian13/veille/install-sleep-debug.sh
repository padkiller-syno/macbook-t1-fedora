#!/usr/bin/env bash
# Monitoring de la veille (suspend) : messages PM du noyau + photos d'état avant / après / +30 s.
# Photos : /var/log/t1-sleep/   Annuler : sudo bash install-sleep-debug.sh annuler
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Lance-moi avec sudo"; exit 1; }
if [ "${1:-}" = annuler ]; then
  rm -f /usr/lib/systemd/system-sleep/t1-sleep-debug /usr/local/sbin/t1-snapshot /etc/tmpfiles.d/pm-debug.conf
  echo 0 > /sys/power/pm_debug_messages; echo 0 > /sys/power/pm_print_times
  echo "== retiré (les photos restent dans /var/log/t1-sleep)"; exit 0
fi

# 1) messages de debug PM du noyau (persistants au boot)
printf 'w /sys/power/pm_debug_messages - - - - 1\nw /sys/power/pm_print_times - - - - 1\n' > /etc/tmpfiles.d/pm-debug.conf
echo 1 > /sys/power/pm_debug_messages; echo 1 > /sys/power/pm_print_times

# 2) photo d'état
cat > /usr/local/sbin/t1-snapshot <<'EOS'
#!/bin/bash
# t1-snapshot <étiquette> : état T1 / GPU / réseau dans /var/log/t1-sleep/
L=${1:-manuel}; D=/var/log/t1-sleep; mkdir -p $D; chmod 755 $D
O=$D/$(date +%Y%m%d-%H%M%S)-$L.txt
{
echo "### $L  $(date '+%F %T.%N')  uptime=$(cut -d' ' -f1 /proc/uptime)s"
echo "## T1 USB"; lsusb | grep -i 05ac
T=$(dirname "$(grep -l '^8600$' /sys/bus/usb/devices/*/idProduct 2>/dev/null | head -1)" 2>/dev/null)
if [ -d "$T" ]; then
  echo "config=$(cat $T/bConfigurationValue) runtime=$(cat $T/power/runtime_status) control=$(cat $T/power/control)"
  for i in "$T"/*:*; do [ -e "$i/bInterfaceClass" ] && echo "  $(basename $i) cls=$(cat $i/bInterfaceClass) drv=$(basename "$(readlink $i/driver)" 2>/dev/null)"; done
fi
echo "## DRM"; for c in /sys/class/drm/card*-*; do echo "  $(basename $c) $(cat $c/status) $(cat $c/enabled) dpms=$(cat $c/dpms 2>/dev/null)"; done
ls -l /dev/dri/touchbar 2>&1 | sed 's/^/  /'
echo "## amdgpu"; for d in /sys/class/drm/card[0-9]/device; do [ "$(basename "$(readlink -f $d/driver)")" = amdgpu ] || continue
  echo "  level=$(cat $d/power_dpm_force_performance_level) state=$(cat $d/power_state 2>/dev/null) busy=$(cat $d/gpu_busy_percent 2>/dev/null)% temp=$(( $(cat $d/hwmon/hwmon*/temp1_input)/1000 ))C"
  echo "  mclk: $(tr '\n' ' ' < $d/pp_dpm_mclk)"; done
echo "  backlight=$(cat /sys/class/backlight/*/brightness 2>/dev/null | tr '\n' ' ')"
echo "## Video"; for v in /dev/video*; do echo "  $v $(cat /sys/class/video4linux/$(basename $v)/name)"; done
echo "## Réseau"; ip -br link; iw dev 2>/dev/null | grep -E 'Interface|ssid'
echo "## Services T1"; for u in t1-touchbar-hw.service t1-touchid-auth.service t1bridge-keybag.service 't1-xart-storage@*' 't1-ncm-ready@*' fprintd.service; do printf '  %-28s %s\n' "$u" "$(systemctl is-active "$u" 2>&1 | head -1)"; done
echo "## t1bridge status"; timeout 5 t1bridge status 2>&1 | sed 's/^/  /'
echo "## noyau (25 dernières lignes)"; journalctl -k -b --no-pager -n 25 -o short-monotonic 2>&1
} > "$O" 2>&1
chmod 644 "$O"
EOS
chmod 755 /usr/local/sbin/t1-snapshot

# 3) crochet de veille : avant / après / +30 s
install -d /usr/lib/systemd/system-sleep
cat > /usr/lib/systemd/system-sleep/t1-sleep-debug <<'EOS'
#!/bin/sh
case "$1/$2" in
  pre/*)  /usr/local/sbin/t1-snapshot "1-avant-$2" ;;
  post/*) /usr/local/sbin/t1-snapshot "2-reveil-$2"
          systemd-run --quiet --on-active=30 --unit=t1-snapshot-post30-$$ /usr/local/sbin/t1-snapshot "3-reveil+30s-$2" ;;
esac
EOS
chmod 755 /usr/lib/systemd/system-sleep/t1-sleep-debug

/usr/local/sbin/t1-snapshot 0-reference
echo "== OK. pm_debug_messages=$(cat /sys/power/pm_debug_messages) pm_print_times=$(cat /sys/power/pm_print_times)"
ls -l /var/log/t1-sleep/

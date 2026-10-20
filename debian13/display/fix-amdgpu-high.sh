#!/usr/bin/env bash
# Radeon Polaris : fréquences fixes (pas de bascule mémoire 300<->1270 MHz, cause connue de blocages)
# Annuler : sudo rm /etc/udev/rules.d/80-amdgpu-high.rules && echo auto | sudo tee /sys/class/drm/card*/device/power_dpm_force_performance_level
set -e
[ "$(id -u)" = 0 ] || { echo "Lance-moi avec sudo"; exit 1; }
cat > /etc/udev/rules.d/80-amdgpu-high.rules <<'EOR'
ACTION=="add|change", SUBSYSTEM=="drm", KERNEL=="card[0-9]", DRIVERS=="amdgpu", ATTR{device/power_dpm_force_performance_level}="high"
EOR
udevadm control --reload
for f in /sys/class/drm/card[0-9]/device/power_dpm_force_performance_level; do
  [ "$(basename "$(readlink -f "$(dirname "$f")/driver")")" = amdgpu ] && echo high > "$f" && echo "$f -> $(cat "$f")"
done
cat /sys/class/drm/card*/device/pp_dpm_mclk 2>/dev/null

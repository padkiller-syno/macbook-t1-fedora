#!/usr/bin/env bash
# Test veille n°1 : amdgpu en « auto » pendant la veille, « high » rétabli 5 s après le réveil
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Lance-moi avec sudo"; exit 1; }
cat > /usr/local/sbin/amdgpu-level <<'EOS'
#!/bin/sh
# amdgpu-level auto|high : niveau DPM de la Radeon (cartes pilotées par amdgpu)
for f in /sys/class/drm/card[0-9]/device/power_dpm_force_performance_level; do
  d=$(dirname "$f"); [ "$(basename "$(readlink -f "$d/driver")")" = amdgpu ] || continue
  timeout 3 sh -c "echo $1 > $f" && logger -t amdgpu-level "$f -> $1" || logger -t amdgpu-level "ÉCHEC $f -> $1"
done
EOS
chmod 755 /usr/local/sbin/amdgpu-level
cat > /usr/lib/systemd/system-sleep/t1-sleep-debug <<'EOS'
#!/bin/sh
case "$1/$2" in
  pre/*)  timeout 15 /usr/local/sbin/t1-snapshot "1-avant-$2"
          /usr/local/sbin/amdgpu-level auto ;;
  post/*) systemd-run --quiet --on-active=5  --unit=amdgpu-high-$$ /usr/local/sbin/amdgpu-level high
          systemd-run --quiet --on-active=2  --unit=t1-snap-post-$$   timeout 20 /usr/local/sbin/t1-snapshot "2-reveil-$2"
          systemd-run --quiet --on-active=30 --unit=t1-snap-post30-$$ timeout 20 /usr/local/sbin/t1-snapshot "3-reveil+30s-$2" ;;
esac
EOS
chmod 755 /usr/lib/systemd/system-sleep/t1-sleep-debug
cat /usr/lib/systemd/system-sleep/t1-sleep-debug
/usr/local/sbin/amdgpu-level high; cat /sys/class/drm/card*/device/power_dpm_force_performance_level 2>/dev/null
echo "== Prêt pour le test : enregistre ton travail puis  systemctl suspend -i"

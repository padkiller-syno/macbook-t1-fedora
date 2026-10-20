#!/usr/bin/env bash
# Radeon Polaris : niveau DPM suivant le profil d'énergie GNOME (power-profiles-daemon)
#   économie d'énergie + pas d'écran externe -> low  (MCLK fixe 300 MHz)
#   sinon                                    -> high (MCLK fixe 1270 MHz, anti-gel)
# Jamais « auto » : la bascule MCLK 300<->1270 en cours d'affichage gèle la carte.
# Annuler : sudo bash install-amdgpu-profils.sh annuler
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Lance-moi avec sudo"; exit 1; }

if [ "${1:-}" = annuler ]; then
  systemctl disable --now amdgpu-power-sync.service 2>/dev/null || true
  rm -f /etc/systemd/system/amdgpu-power-sync.service /usr/local/sbin/amdgpu-power-sync /etc/udev/rules.d/80-amdgpu-power-sync.rules
  cat > /etc/udev/rules.d/80-amdgpu-high.rules <<'EOR'
ACTION=="add|change", SUBSYSTEM=="drm", KERNEL=="card[0-9]", DRIVERS=="amdgpu", ATTR{device/power_dpm_force_performance_level}="high"
EOR
  systemctl daemon-reload; udevadm control --reload
  for f in /sys/class/drm/card[0-9]/device/power_dpm_force_performance_level; do
    [ "$(basename "$(readlink -f "$(dirname "$f")/driver")")" = amdgpu ] && echo high > "$f"; done
  echo "== retour à « high » permanent"; exit 0
fi

cat > /usr/local/sbin/amdgpu-power-sync <<'EOS'
#!/bin/sh
# Radeon : low/high selon le profil power-profiles-daemon et les écrans externes.
# Sondage toutes les 2 s : « high » immédiat, « low » seulement après 3 sondages d'affilée (6 s),
# pour ignorer les déconnexions brèves d'un écran externe.
lows=0
while :; do
  P=$(busctl get-property org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles \
        org.freedesktop.UPower.PowerProfiles ActiveProfile 2>/dev/null | awk -F'"' '{print $2}')
  for d in /sys/class/drm/card[0-9]; do
    [ "$(basename "$(readlink -f $d/device/driver)")" = amdgpu ] || continue
    ext=0
    for c in $d-*; do
      case "$c" in *eDP*) continue ;; esac
      [ "$(cat $c/status 2>/dev/null)" = connected ] && ext=1
    done
    f=$d/device/power_dpm_force_performance_level; cur=$(cat $f)
    if [ "$P" != power-saver ] || [ $ext = 1 ]; then
      lows=0
      [ "$cur" = high ] || { echo high > $f && logger -t amdgpu-power-sync "$(basename $d): high (profil=${P:-?} externe=$ext)"; }
    else
      lows=$((lows + 1))
      [ $lows -ge 3 ] && [ "$cur" != low ] && echo low > $f && logger -t amdgpu-power-sync "$(basename $d): low (profil=$P externe=0, stable 6 s)"
    fi
  done
  [ "${1:-}" = once ] && exit 0
  sleep 2
done
EOS
chmod 755 /usr/local/sbin/amdgpu-power-sync

cat > /etc/systemd/system/amdgpu-power-sync.service <<'EOS'
[Unit]
Description=Radeon : niveau DPM selon le profil d'énergie (low en économie, sinon high)
After=power-profiles-daemon.service
Wants=power-profiles-daemon.service
Before=display-manager.service

[Service]
Type=simple
ExecStart=/usr/local/sbin/amdgpu-power-sync
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOS

# l'ancienne règle « high » fixe et la règle RUN (déclenchée avant que le port passe « connected ») sont retirées
rm -f /etc/udev/rules.d/80-amdgpu-high.rules /etc/udev/rules.d/80-amdgpu-power-sync.rules
# au boot (apparition de la carte) : « high » tout de suite, jamais « auto » ; le service affine ensuite
cat > /etc/udev/rules.d/80-amdgpu-high.rules <<'EOR'
ACTION=="add", SUBSYSTEM=="drm", KERNEL=="card[0-9]", DRIVERS=="amdgpu", ATTR{device/power_dpm_force_performance_level}="high"
EOR
udevadm control --reload
systemctl daemon-reload
systemctl enable amdgpu-power-sync.service
systemctl restart amdgpu-power-sync.service
sleep 2
systemctl is-active amdgpu-power-sync.service
cat /sys/class/drm/card*/device/power_dpm_force_performance_level 2>/dev/null
cat /sys/class/drm/card0/device/pp_dpm_mclk
echo "== OK"

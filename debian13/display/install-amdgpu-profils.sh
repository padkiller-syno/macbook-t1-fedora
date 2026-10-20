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
  F=/sys/devices/system/cpu/cpu0/cpufreq
  echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo
  for m in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_max_freq; do cat $F/cpuinfo_max_freq > $m; done
  echo "== retour à « high » permanent ; CPU sans limite, turbo désactivé (disable-turbo.service)"; exit 0
fi

cat > /usr/local/sbin/amdgpu-power-sync <<'EOS'
#!/bin/sh
# Radeon : low/high selon le profil power-profiles-daemon et les écrans externes.
# CPU : économie -> 800 MHz max sans turbo ; équilibré -> sans limite, sans turbo ; performance -> turbo.
# Secteur : au BRANCHEMENT du chargeur, « économie d'énergie » passe en « équilibré » (une fois).
# Sondage toutes les 2 s : « high » immédiat, « low » seulement après 3 sondages d'affilée (6 s),
# pour ignorer les déconnexions brèves d'un écran externe.
PP="org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles org.freedesktop.UPower.PowerProfiles"
AC=$(ls -d /sys/class/power_supply/*/ 2>/dev/null | while read -r s; do [ "$(cat ${s}type)" = Mains ] && echo ${s}online && break; done)
ac_prev=$(cat "$AC" 2>/dev/null || echo 0)
lows=0
while :; do
  P=$(busctl get-property $PP ActiveProfile 2>/dev/null | awk -F'"' '{print $2}')
  ac=$(cat "$AC" 2>/dev/null || echo 0)
  if [ "$ac_prev" = 0 ] && [ "$ac" = 1 ] && [ "$P" = power-saver ]; then
    busctl set-property $PP ActiveProfile s balanced && P=balanced && \
      logger -t amdgpu-power-sync "secteur branché : économie d'énergie -> équilibré"
  fi
  ac_prev=$ac
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
  # --- CPU (intel_pstate) : appliqué immédiatement ---
  T=/sys/devices/system/cpu/intel_pstate/no_turbo; F=/sys/devices/system/cpu/cpu0/cpufreq
  if [ "$P" = performance ]; then nt=0; else nt=1; fi
  [ "$(cat $T)" = $nt ] || { echo $nt > $T && logger -t amdgpu-power-sync "cpu: turbo $([ $nt = 0 ] && echo activé || echo désactivé) (profil=${P:-?})"; }
  if [ "$P" = power-saver ]; then mx=$(cat $F/cpuinfo_min_freq); else mx=$(cat $F/cpuinfo_max_freq); fi
  if [ "$(cat $F/scaling_max_freq)" != "$mx" ]; then
    for m in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_max_freq; do echo $mx > $m; done
    logger -t amdgpu-power-sync "cpu: max $((mx / 1000)) MHz (profil=${P:-?})"
  fi
  [ "${1:-}" = once ] && exit 0
  sleep 2
done
EOS
chmod 755 /usr/local/sbin/amdgpu-power-sync

cat > /etc/systemd/system/amdgpu-power-sync.service <<'EOS'
[Unit]
Description=Profil d'énergie -> Radeon (low/high), CPU (800 MHz / sans turbo / turbo), secteur -> équilibré
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
echo "cpu: no_turbo=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo) max=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq)"
echo "== OK"

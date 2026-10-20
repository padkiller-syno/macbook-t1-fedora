#!/usr/bin/env bash
# Veille et hibernation interdites (la reprise de la Radeon Polaris plante) ; batterie critique -> extinction
# Annuler : sudo rm /etc/systemd/sleep.conf.d/pas-de-veille.conf ; sudo cp /etc/UPower/UPower.conf.avant /etc/UPower/UPower.conf ; sudo systemctl restart upower
set -e
[ "$(id -u)" = 0 ] || { echo "Lance-moi avec sudo"; exit 1; }
rm -f /etc/systemd/sleep.conf.d/hibernate-shutdown.conf
cat > /etc/systemd/sleep.conf.d/pas-de-veille.conf <<'EOC'
# MacBookPro13,3 : la Radeon Polaris (amdgpu) ne survit ni à la veille ni à l'hibernation
[Sleep]
AllowSuspend=no
AllowHibernation=no
AllowHybridSleep=no
AllowSuspendThenHibernate=no
EOC
cp -n /etc/UPower/UPower.conf /etc/UPower/UPower.conf.avant
sed -i 's/^CriticalPowerAction=.*/CriticalPowerAction=PowerOff/' /etc/UPower/UPower.conf
systemctl restart upower
grep '^CriticalPowerAction' /etc/UPower/UPower.conf
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager 2>/dev/null | true
for m in CanSuspend CanHibernate CanHybridSleep; do echo "$m: $(busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager $m)"; done
echo "== OK"

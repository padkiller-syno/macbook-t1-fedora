#!/usr/bin/env bash
# Contrôleurs USB 3 des ports Thunderbolt 3 (Alpine Ridge JHL6540, 8086:15d4) : jamais de mise en veille.
# En veille, ils ne se réveillent pas au branchement -> écrans/docks USB-C perdent leur USB 3 (Ethernet…).
# Annuler : sudo rm /etc/udev/rules.d/81-thunderbolt-usb3-on.rules
set -e
[ "$(id -u)" = 0 ] || { echo "Lance-moi avec sudo"; exit 1; }
cat > /etc/udev/rules.d/81-thunderbolt-usb3-on.rules <<'EOR'
# Thunderbolt 3 USB Controller (Alpine Ridge 4C 2016) : runtime PM désactivé
ACTION=="add|bind", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0x15d4", ATTR{power/control}="on"
EOR
udevadm control --reload
for d in /sys/bus/pci/devices/*; do
  [ "$(cat $d/vendor)" = 0x8086 ] && [ "$(cat $d/device)" = 0x15d4 ] && echo on > $d/power/control && echo "$(basename $d) -> $(cat $d/power/runtime_status)"
done
echo "== OK"

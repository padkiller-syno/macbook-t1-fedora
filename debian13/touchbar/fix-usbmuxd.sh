#!/usr/bin/env bash
# Empêche la règle udev de usbmuxd de déconfigurer la T1 (05ac:8600), puis réactive la config 2.
# Annuler : sudo rm /etc/udev/rules.d/39-usbmuxd.rules && sudo udevadm control --reload
set -e
[ "$(id -u)" = 0 ] || { echo "Lance-moi avec sudo"; exit 1; }
sed 's#|5ac/8600/\*##' /usr/lib/udev/rules.d/39-usbmuxd.rules > /etc/udev/rules.d/39-usbmuxd.rules
grep -c 8600 /etc/udev/rules.d/39-usbmuxd.rules || true
udevadm control --reload
D=$(dirname "$(grep -l '^8600$' /sys/bus/usb/devices/*/idProduct | head -1)")
echo 2 > "$D/bConfigurationValue"
sleep 4
echo "config=$(cat $D/bConfigurationValue)"
ls /dev/dri/ /dev/video* 2>&1
systemctl restart t1-touchbar-hw.socket t1-touchbar-hw.service 2>&1 || true
systemctl is-active t1-touchbar-hw.service

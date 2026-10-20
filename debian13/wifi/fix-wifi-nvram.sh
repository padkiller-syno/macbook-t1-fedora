#!/usr/bin/env bash
# Installe le fichier NVRAM BCM43602 (kernel bug 193121 + fix swctrlmap_2g) et recharge le wifi
# Annuler : sudo rm /lib/firmware/brcm/brcmfmac43602-pcie*.txt puis reboot
set -e
[ "$(id -u)" = 0 ] || { echo "Lance-moi avec sudo"; exit 1; }
SRC=/home/benoit/brcmfmac43602-pcie.txt
D=/lib/firmware/brcm
MODEL=$(cat /sys/class/dmi/id/product_name)
install -m644 "$SRC" "$D/brcmfmac43602-pcie.Apple Inc.-$MODEL.txt"
install -m644 "$SRC" "$D/brcmfmac43602-pcie.txt"
# Journal noyau pour diagnostiquer le son (lisible ensuite sans root)
dmesg > /home/benoit/dmesg-avant-wifi.txt; chown benoit: /home/benoit/dmesg-avant-wifi.txt
echo "== rechargement du pilote wifi"
modprobe -r brcmfmac_wcc 2>/dev/null || true
modprobe -r brcmfmac; sleep 1; modprobe brcmfmac; sleep 8
dmesg | grep -i brcmfmac | tail -8
nmcli dev wifi rescan ifname wlp3s0 2>/dev/null || true; sleep 5
nmcli -f SSID,CHAN,FREQ,SIGNAL dev wifi list ifname wlp3s0 | head -15

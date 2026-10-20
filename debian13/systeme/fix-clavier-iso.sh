#!/usr/bin/env bash
# Clavier ISO Apple (SPI) : @ et < inversés -> applespi iso_layout=1
# Annuler : sudo rm /etc/modprobe.d/applespi-iso.conf && sudo update-initramfs -u && echo N | sudo tee /sys/module/applespi/parameters/iso_layout
set -e
[ "$(id -u)" = 0 ] || { echo "Lance-moi avec sudo"; exit 1; }
echo Y > /sys/module/applespi/parameters/iso_layout      # effet immédiat
echo "options applespi iso_layout=1" > /etc/modprobe.d/applespi-iso.conf
update-initramfs -u                                       # aussi pour le mot de passe LUKS
echo "== OK : iso_layout=$(cat /sys/module/applespi/parameters/iso_layout). Teste @ et < tout de suite."

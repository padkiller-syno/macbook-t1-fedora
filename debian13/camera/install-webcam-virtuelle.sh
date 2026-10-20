#!/usr/bin/env bash
# Caméra virtuelle /dev/video10 « FaceTime HD » chargée à chaque démarrage (inactive tant que webcam-on n'est pas lancé)
# Annuler : sudo rm /etc/modprobe.d/v4l2loopback-facetime.conf /etc/modules-load.d/v4l2loopback-facetime.conf && sudo modprobe -r v4l2loopback
set -e
[ "$(id -u)" = 0 ] || { echo "Lance-moi avec sudo"; exit 1; }
echo 'options v4l2loopback video_nr=10 card_label="FaceTime HD" exclusive_caps=1' > /etc/modprobe.d/v4l2loopback-facetime.conf
echo v4l2loopback > /etc/modules-load.d/v4l2loopback-facetime.conf
modprobe -r v4l2loopback 2>/dev/null || true
modprobe v4l2loopback
ls -l /dev/video10 && cat /sys/class/video4linux/video10/name

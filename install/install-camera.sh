#!/bin/sh
# install-camera.sh — réinstallation complète de la caméra virtuelle T1
# (caméra iBridge H.264 -> v4l2loopback YUY2, on/off piloté par watchdog)
#
# Usage : sudo ./install-camera.sh
set -e

REPO="$(cd "$(dirname "$0")/.." && pwd)"
USER_HOME=$(getent passwd "$(id -u)" | cut -d: -f6)
[ -z "$USER_HOME" ] && USER_HOME="/root"

echo "==> 1/4 Paquets (v4l2loopback via RPM Fusion + GStreamer)"
dnf install -y v4l2loopback \
    gstreamer1 gstreamer1-plugins-base gstreamer1-plugins-bad-free \
    gstreamer1-plugins-ugly-free v4l-utils
# openh264dec : fourni par gstreamer1-plugins-bad-free (OpenH264)

echo "==> 2/4 Module noyau v4l2loopback"
install -d /etc/modprobe.d /etc/modules-load.d
install -m 0644 "$REPO/camera/kernel/v4l2loopback.modprobe.conf" \
    /etc/modprobe.d/v4l2loopback.conf
echo "v4l2loopback" > /etc/modules-load.d/v4l2loopback.conf
depmod -a
modprobe v4l2loopback
ls /dev/video*

echo "==> 3/4 Services user de $USER_HOME"
SVC_DIR="$USER_HOME/.config/systemd/user"
mkdir -p "$SVC_DIR"
install -m 0644 "$REPO/camera/systemd/t1-cam-stub.service" \
                "$REPO/camera/systemd/t1-virtualcam.service" \
                "$REPO/camera/systemd/t1-virtualcam-watchdog.service" \
    "$SVC_DIR/"
mkdir -p "$USER_HOME/t1-diag"
install -m 0755 "$REPO/camera/scripts/virtualcam-watchdog.sh" \
    "$USER_HOME/t1-diag/virtualcam-watchdog.sh"

echo "==> 4/4 Activation (pour la session user courante)"
# A relancer DANS la session user (systemd --user), ou au prochain login :
echo ""
echo "Fin. Dans la session user, lancer :"
echo "  systemctl --user daemon-reload"
echo "  systemctl --user enable --now t1-cam-stub.service t1-virtualcam-watchdog.service"
echo ""
echo "Vérification :"
echo "  wpctl status | grep -A6 '^Video'"
echo "  systemctl --user status t1-cam-stub t1-virtualcam-watchdog"
echo "  fuser /dev/video0   # vide = caméra T1 éteinte (au repos)"

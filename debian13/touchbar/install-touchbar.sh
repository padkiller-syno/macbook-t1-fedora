#!/usr/bin/env bash
# Installe la Touch Bar (t1bridge) + webcam H.264 sur Debian 13 / noyau 6.12 — MacBookPro13,3
# Usage : sudo bash ~/t1/install-touchbar.sh          (installer)
#         sudo bash ~/t1/install-touchbar.sh annuler  (tout retirer, webcam d'origine rétablie)
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Lance-moi avec sudo"; exit 1; }
U=benoit
H=/home/$U/t1
KV=$(uname -r)
MODDIR=/lib/modules/$KV/updates/t1bridge

if [ "${1:-}" = annuler ]; then
  systemctl --global disable t1-touchbar.service 2>/dev/null || true
  systemctl disable --now t1-touchbar-hw.service t1-touchbar-hw.socket 2>/dev/null || true
  dkms remove t1bridge-debian/0.1.12 --all 2>/dev/null || true; rm -rf /usr/src/t1bridge-debian-0.1.12
  rm -rf "$MODDIR" /usr/lib/t1bridge
  rm -f /etc/systemd/system/t1-touchbar-hw.{service,socket} /etc/systemd/user/t1-touchbar.service \
        /etc/udev/rules.d/99-zz-t1bridge-touchbar.rules /etc/modprobe.d/t1bridge.conf \
        /etc/modules-load.d/t1bridge.conf /etc/sysusers.d/t1bridge.conf /etc/tmpfiles.d/t1bridge.conf \
        /etc/udev/rules.d/39-usbmuxd.rules /etc/modprobe.d/v4l2loopback-facetime.conf /etc/modules-load.d/v4l2loopback-facetime.conf
  sed -i '/^t1_cfgsel$/d' /etc/initramfs-tools/modules
  depmod -a; update-initramfs -u; systemctl daemon-reload
  echo "== Retiré. Éteins complètement (poweroff) puis rallume."; exit 0
fi

echo "== 1/6 dépendance de compilation"
apt-get install -y libsystemd-dev

echo "== 2/6 compilation du service matériel (en tant que $U)"
sudo -u $U bash -c "cd $H/t1bridge && PATH=/home/$U/.cargo/bin:\$PATH cargo build --locked --release -p t1-touchbar-hw --bin t1-touchbar-hw --features service && PATH=/home/$U/.cargo/bin:\$PATH cargo build --locked --release -p t1-touchbar --bin t1-touchbar"

echo "== 3/6 modules noyau (t1_cfgsel, appletbdrm, uvcvideo H.264)"
install -d "$MODDIR"
install -m644 $H/t1bridge/kernel/t1-cfgsel/t1_cfgsel.ko $H/t1bridge/kernel/appletbdrm-t1/appletbdrm.ko \
              $H/uvc612/src/drivers/media/usb/uvc/uvcvideo.ko "$MODDIR/"
depmod -a
B=$H/t1bridge/packaging/arch/t1bridge-dkms
install -m644 $B/t1bridge.modprobe.conf /etc/modprobe.d/t1bridge.conf
install -m644 $B/t1bridge.modules-load.conf /etc/modules-load.d/t1bridge.conf
# t1_cfgsel doit être chargé avant que la T1 s'énumère -> initramfs
grep -qx t1_cfgsel /etc/initramfs-tools/modules || echo t1_cfgsel >> /etc/initramfs-tools/modules
update-initramfs -u

echo "== 4/6 binaires"
install -Dm755 $H/t1bridge/target/release/t1-touchbar-hw /usr/lib/t1bridge/t1-touchbar-hw
install -Dm755 $H/t1bridge/target/release/t1-touchbar    /usr/lib/t1bridge/t1-touchbar

echo "== 5/6 groupe, systemd, udev"
S=$H/t1bridge/systemd
install -Dm644 $S/t1bridge.sysusers /etc/sysusers.d/t1bridge.conf
install -Dm644 $S/t1bridge.conf     /etc/tmpfiles.d/t1bridge.conf
systemd-sysusers /etc/sysusers.d/t1bridge.conf
systemd-tmpfiles --create /etc/tmpfiles.d/t1bridge.conf
usermod -aG t1bridge $U
install -m644 $S/t1-touchbar-hw.service $S/t1-touchbar-hw.socket /etc/systemd/system/
install -Dm644 $S/user/t1-touchbar.service /etc/systemd/user/t1-touchbar.service
install -Dm644 $S/99-zz-t1bridge-touchbar.rules /etc/udev/rules.d/99-zz-t1bridge-touchbar.rules
systemctl daemon-reload
systemctl enable t1-touchbar-hw.service
systemctl --global enable t1-touchbar.service
udevadm control --reload

echo "== 6/6 terminé"
echo "Éteins COMPLÈTEMENT (sudo poweroff), attends 10 s, rallume."
echo "Pour annuler : sudo bash $H/install-touchbar.sh annuler"

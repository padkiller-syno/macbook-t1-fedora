#!/usr/bin/env bash
# Passe les 4 modules T1 (t1_cfgsel, appletbdrm, apple_t1_ncm, uvcvideo H.264) sous DKMS :
# reconstruits automatiquement à chaque nouveau noyau Debian.
# Annuler : sudo bash install-dkms-t1.sh annuler
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Lance-moi avec sudo"; exit 1; }
N=t1bridge-debian; V=0.1.12; KV=$(uname -r)
if [ "${1:-}" = annuler ]; then
  dkms remove $N/$V --all || true; rm -rf /usr/src/$N-$V; depmod -a; update-initramfs -u
  echo "== DKMS retiré"; exit 0
fi
rm -rf /usr/src/$N-$V
cp -r /home/benoit/t1/dkms/$N-$V /usr/src/
chown -R root:root /usr/src/$N-$V
dkms remove $N/$V --all >/dev/null 2>&1 || true
dkms add $N/$V
dkms build $N/$V -k "$KV"
dkms install $N/$V -k "$KV" --force
# les copies manuelles font doublon avec updates/dkms : on les retire
rm -rf /lib/modules/$KV/updates/t1bridge
depmod -a "$KV"
for m in t1_cfgsel appletbdrm apple_t1_ncm uvcvideo; do echo "$m -> $(modinfo -n $m)"; done
update-initramfs -u -k "$KV"
lsinitramfs /boot/initrd.img-$KV | grep t1_cfgsel
dkms status | grep -E "$N|snd_hda|v4l2loopback"
echo "== OK : modules sous DKMS. Pas besoin de redémarrer maintenant."

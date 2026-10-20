#!/usr/bin/env bash
# Touch ID (t1bridge) — PHASE 1 : services + libfprint/fprintd patchés. NE TOUCHE PAS À PAM.
# Usage : sudo bash ~/t1/install-touchid.sh          (installer)
#         sudo bash ~/t1/install-touchid.sh annuler  (tout retirer ; /var/lib/t1bridge est conservé)
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Lance-moi avec sudo"; exit 1; }
H=/home/benoit/t1
B=$H/t1bridge/target/release
S=$H/t1bridge/systemd
MODDIR=/lib/modules/$(uname -r)/updates/t1bridge
UNITS="t1-ncm-ready@.service t1-xart-storage@.service t1bridge-keybag.service t1-touchid-auth.service t1-touchid-auth.socket t1bridge-fingerprint.socket t1bridge-import.service"
MANIFEST=$H/fprint/installed-files.txt

if [ "${1:-}" = annuler ]; then
  systemctl disable --now t1-touchid-auth.socket t1bridge-fingerprint.socket 2>/dev/null || true
  systemctl stop t1-touchid-auth.service t1bridge-keybag.service 't1-xart-storage@*' 'fprintd.service' 2>/dev/null || true
  for u in $UNITS; do rm -f /etc/systemd/system/$u; done
  rm -f /etc/systemd/network/50-t1bridge-ncm.link /etc/udev/rules.d/90-t1bridge-xart.rules "$MODDIR/apple_t1_ncm.ko"
  rm -f /usr/lib/t1bridge/{t1-xart-storage,t1-ncm-ready,t1-keybag-relay,t1-touchid-auth,t1-legacy-recovery} /usr/bin/t1-touchid /usr/bin/t1bridge
  [ -f "$MANIFEST" ] && xargs -r -d '\n' rm -f < "$MANIFEST"
  rm -f /etc/apt/preferences.d/no-debian-fprintd
  depmod -a; ldconfig; systemctl daemon-reload; udevadm control --reload
  echo "== Retiré (empreintes conservées dans /var/lib/t1bridge). Redémarre."; exit 0
fi

echo "== 1/5 module réseau privé T1 (apple_t1_ncm)"
install -Dm644 $H/t1bridge/kernel/apple-t1-ncm/apple_t1_ncm.ko "$MODDIR/apple_t1_ncm.ko"
depmod -a

echo "== 2/5 binaires t1bridge"
for b in t1-xart-storage t1-ncm-ready t1-keybag-relay t1-touchid-auth; do install -Dm755 $B/$b /usr/lib/t1bridge/$b; done
install -Dm750 $B/t1-legacy-recovery /usr/lib/t1bridge/t1-legacy-recovery
install -Dm755 $B/t1-touchid /usr/bin/t1-touchid
install -Dm755 $B/t1bridge   /usr/bin/t1bridge

echo "== 3/5 systemd, udev, lien réseau"
for u in $UNITS; do install -m644 $S/$u /etc/systemd/system/$u; done
install -Dm644 $S/50-t1bridge-ncm.link /etc/systemd/network/50-t1bridge-ncm.link
install -Dm644 $S/90-t1bridge-xart.rules /etc/udev/rules.d/90-t1bridge-xart.rules
systemd-tmpfiles --create /etc/tmpfiles.d/t1bridge.conf
systemctl daemon-reload
systemctl enable t1-touchid-auth.socket t1bridge-fingerprint.socket
udevadm control --reload

echo "== 4/5 libfprint + fprintd (driver T1Bridge) dans /usr"
meson install -C $H/fprint/build-libfprint --no-rebuild >/dev/null
meson install -C $H/fprint/build-fprintd   --no-rebuild >/dev/null
cat $H/fprint/build-libfprint/meson-logs/install-log.txt $H/fprint/build-fprintd/meson-logs/install-log.txt | grep -v '^#' > "$MANIFEST"
chown benoit: "$MANIFEST"
ldconfig
systemctl daemon-reload
systemctl reload dbus 2>/dev/null || true
udevadm control --reload

echo "== 5/5 terminé"
echo "Éteins COMPLÈTEMENT (sudo poweroff), rallume, puis dis « c'est redémarré » : on fera l'import et le premier enregistrement."
echo "PAM n'est PAS modifié : la connexion fonctionne exactement comme avant."

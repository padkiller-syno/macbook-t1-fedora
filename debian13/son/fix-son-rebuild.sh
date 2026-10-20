#!/usr/bin/env bash
# Recompile le pilote son CS8409 contre les sources 6.12.113 (et non 6.12.0)
set -e
[ "$(id -u)" = 0 ] || { echo "Lance-moi avec sudo"; exit 1; }
cd /usr/local/src/snd_hda_macbookpro
# "6.12.113+deb13-amd64" -> "6.12.113" (sinon le script retombe sur linux-6.12.tar.xz)
for f in install.cirrus.driver.pre617.sh install.cirrus.driver.sh; do
  sed -i "s/^kernel_version=\$(echo \$UNAME | cut -d '-' -f1)\( *#.*\)\?$/kernel_version=\$(echo \$UNAME | cut -d '-' -f1 | cut -d '+' -f1)\1/" "$f"
done
grep -n '^kernel_version=' install.cirrus.driver*.sh
rm -rf build
dkms remove snd_hda_macbookpro/0.1 --all 2>/dev/null || true
./install.cirrus.driver.sh -i
echo; echo "== Pilote recompilé. Redémarre maintenant : sudo reboot"

#!/bin/bash
# Installe le thème Plymouth « pomme » et active l'écran de démarrage graphique (GRUB : splash).
# Annuler : sudo plymouth-set-default-theme -R debian-theme ; retirer « splash » de /etc/default/grub ; sudo update-grub
set -e
[ "$(id -u)" = 0 ] || { echo "Lance-moi avec sudo"; exit 1; }
install -d /usr/share/plymouth/themes/pomme
install -m 644 "$(dirname "$0")"/{pomme.plymouth,pomme.script,*.png} /usr/share/plymouth/themes/pomme/
[ -e /root/grub.bak-20261030 ] || cp -p /etc/default/grub /root/grub.bak-20261030
grep -q 'GRUB_CMDLINE_LINUX_DEFAULT=.*splash' /etc/default/grub || sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="quiet/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash/' /etc/default/grub
grep ^GRUB_CMDLINE_LINUX_DEFAULT /etc/default/grub
update-grub 2>&1 | tail -2
plymouth-set-default-theme pomme && update-initramfs -u
lsinitramfs /boot/initrd.img-$(uname -r) | grep -E "themes/pomme/|amdgpu.ko|plymouth/renderers/drm" | head
echo "== OK : redémarre pour voir la pomme."

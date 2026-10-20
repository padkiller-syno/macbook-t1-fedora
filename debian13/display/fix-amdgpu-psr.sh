#!/usr/bin/env bash
# Désactive le Panel Self Refresh d'amdgpu (blocage GPU après débranchement d'un écran externe)
# Annuler : retirer amdgpu.dcdebugmask=0x10 de GRUB_CMDLINE_LINUX_DEFAULT dans /etc/default/grub, puis sudo update-grub
set -e
[ "$(id -u)" = 0 ] || { echo "Lance-moi avec sudo"; exit 1; }
cp /etc/default/grub /etc/default/grub.avant-psr
grep -q 'amdgpu.dcdebugmask' /etc/default/grub || \
  sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 amdgpu.dcdebugmask=0x10"/' /etc/default/grub
grep '^GRUB_CMDLINE_LINUX_DEFAULT' /etc/default/grub
update-grub
echo "== OK. Redémarre, puis teste : branche le Dell, débranche-le, attends 30 s."

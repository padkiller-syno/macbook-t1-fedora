#!/usr/bin/env bash
# Touch ID — PHASE 2 : empreinte proposée avant le mot de passe (sudo, polkit, su…)
# Le mot de passe reste toujours possible (default=ignore).
# Annuler : sudo pam-auth-update --disable t1bridge-fprintd && sudo rm /usr/share/pam-configs/t1bridge-fprintd
set -e
[ "$(id -u)" = 0 ] || { echo "Lance-moi avec sudo"; exit 1; }
cp -a /etc/pam.d/common-auth /etc/pam.d/common-auth.avant-touchid
cat > /usr/share/pam-configs/t1bridge-fprintd <<'EOP'
Name: Empreinte digitale Touch ID (fprintd / T1Bridge)
Default: yes
Priority: 260
Auth-Type: Primary
Auth:
	[success=end default=ignore]	pam_fprintd.so max-tries=1 timeout=10
Auth-Initial:
	[success=end default=ignore]	pam_fprintd.so max-tries=1 timeout=10
EOP
pam-auth-update --enable t1bridge-fprintd
echo "== /etc/pam.d/common-auth :"; grep -vE '^\s*#|^$' /etc/pam.d/common-auth
echo "== Teste dans un AUTRE terminal :  sudo -k ; sudo true"

#!/usr/bin/env bash
# 1) Capot fermé : verrouiller au lieu de mettre en veille (veille cassée avec t1bridge + amdgpu)
# 2) Firmware de l'adaptateur Ethernet USB Realtek RTL8156B
# Annuler 1) : sudo rm /etc/systemd/logind.conf.d/10-capot-verrouille.conf && sudo systemctl reload systemd-logind
set -e
[ "$(id -u)" = 0 ] || { echo "Lance-moi avec sudo"; exit 1; }
mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/10-capot-verrouille.conf <<'EOC'
[Login]
HandleLidSwitch=lock
HandleLidSwitchExternalPower=lock
HandleLidSwitchDocked=ignore
EOC
systemctl reload systemd-logind
apt-get install -y firmware-realtek
echo "== OK. Le firmware Realtek sera chargé au prochain branchement de l'adaptateur."

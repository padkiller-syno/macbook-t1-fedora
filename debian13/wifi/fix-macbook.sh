#!/usr/bin/env bash
# Correctifs MacBookPro13,3 (2016 15") sous Debian 13 — à lancer avec sudo
# Usage : sudo bash fix-macbook.sh [wifi|son|tout]
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Lance-moi avec sudo"; exit 1; }
what=${1:-tout}

wifi() {
  echo "== Wi-Fi (BCM43602 / brcmfmac)"
  # Pays FR : sans ça le pilote reste en "country 99" et peut masquer le 5 GHz
  sed -i 's/^REGDOMAIN=.*/REGDOMAIN=FR/' /etc/default/crda 2>/dev/null || true
  echo 'options cfg80211 ieee80211_regdom=FR' > /etc/modprobe.d/cfg80211-fr.conf
  # Désactive SAE/WPA3 offload + PNO : évite plantages/déconnexions du firmware 43602
  echo 'options brcmfmac feature_disable=0x82000 roamoff=1' > /etc/modprobe.d/brcmfmac-mbp.conf
  # Économie d'énergie wifi désactivée (cause de latence et pertes)
  mkdir -p /etc/NetworkManager/conf.d
  printf '[connection]\nwifi.powersave = 2\n' > /etc/NetworkManager/conf.d/wifi-powersave-off.conf
  echo "   -> redémarre (ou: modprobe -r brcmfmac_wcc brcmfmac && modprobe brcmfmac && systemctl restart NetworkManager)"
}

son() {
  echo "== Son (Cirrus CS8409 — pilote patché davidjo/snd_hda_macbookpro)"
  apt-get install -y git build-essential "linux-headers-$(uname -r)" dkms wget patch
  dir=/usr/local/src/snd_hda_macbookpro
  [ -d "$dir" ] || git clone https://github.com/davidjo/snd_hda_macbookpro.git "$dir"
  cd "$dir" && git pull --ff-only || true
  ./install.cirrus.driver.sh -i   # -i = installation DKMS (survit aux mises à jour noyau)
  echo "   -> redémarre puis vérifie : aplay -l (la carte PCH doit lister des sorties analogiques)"
}

case $what in
  wifi) wifi ;; son) son ;; tout) wifi; son ;;
  *) echo "argument: wifi | son | tout"; exit 1 ;;
esac

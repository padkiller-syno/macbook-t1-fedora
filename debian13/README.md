# MacBook Pro 13,3 (2016, Touch Bar) sous Debian 13

Même machine que la version Fedora, cette fois sous **Debian 13 (trixie)**,
kernel **`6.12.113+deb13-amd64`**, GNOME 48 / **Wayland**, LUKS + LVM.
Session de remise en état du 20/10/2026.

Différence majeure avec Fedora : le kernel Debian est un **6.12**, alors que
t1bridge cible les kernels **7.x**. Deux modules ont dû être portés.

## Statut

| Chantier | Statut | Dossier |
|---|---|---|
| **Wi-Fi** BCM43602 (5 GHz, signal) | ✅ -55 dBm en 5 GHz (contre -89 dBm en 2,4 GHz avant) | [`wifi/`](wifi/) |
| **Son** CS8409 (haut-parleurs + micro) | ✅ | [`son/`](son/) |
| **T1 en recovery** (`05ac:1281`) | ✅ régénérée avec t1-revive | [`t1-revive/`](#t1-revive-t1-bloquée-en-recovery) |
| **Touch Bar** | ✅ (t1bridge, modules portés en 6.12) | [`touchbar/`](touchbar/) |
| **Caméra** FaceTime HD | ✅ caméra virtuelle à la demande (Meet, Firefox, GNOME Caméra) | [`camera/`](camera/) |
| **Écran noir / gel** (amdgpu Polaris) | ✅ `power_dpm_force_performance_level=high` | [`display/`](display/) |
| Touch ID | ⏸️ non fait (volontairement) | — |
| Veille (suspend) | ❌ ne marche pas avec la pile t1bridge → veille désactivée (auto + capot) | [`systeme/`](#réglages-système-revue-du-syslog) |

---

## Wi-Fi — BCM43602 (`brcmfmac`)

**Symptôme** : carte interne à 17–24 % de signal, **aucun réseau 5 GHz**,
`country 99` (non défini). Une clé USB au même endroit captait à 100 %.

**Cause** : `linux-firmware` ne fournit **aucun fichier NVRAM** (étalonnage
radio) pour cette carte → le front-end radio est mal piloté
(`Direct firmware load for brcm/brcmfmac43602-pcie.txt failed`).

**Fix** :
1. Fichier NVRAM de
   [ysonggit/macbookpro13-3-bcm43602-wifi-fix](https://github.com/ysonggit/macbookpro13-3-bcm43602-wifi-fix)
   (issu du [bug kernel 193121](https://bugzilla.kernel.org/show_bug.cgi?id=193121),
   avec le correctif `swctrlmap_2g`), installé sous
   `/lib/firmware/brcm/brcmfmac43602-pcie.txt` **et**
   `brcmfmac43602-pcie.Apple Inc.-MacBookPro13,3.txt` → `wifi/fix-wifi-nvram.sh`.
2. `options brcmfmac feature_disable=0x82000 roamoff=1`, régulation FR,
   `wifi.powersave = 2` dans NetworkManager → `wifi/fix-macbook.sh wifi`.

**Résultat** : 5 GHz (canal 64), -55 dBm, 405 Mbit/s en réception.
Le NVRAM est le vrai correctif ; les options seules ne changeaient rien.

## Son — Cirrus CS8409 / CS42L83

**Symptôme** : seules les sorties HDMI dans `aplay -l`, PipeWire sur
« Dummy Output ».

**Fix** : pilote [davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro)
en DKMS (`wifi/fix-macbook.sh son`).

⚠️ **Piège Debian** : le script du pilote lit la version kernel avec
`cut -d '-' -f1` → `6.12.113+deb13` → le téléchargement de
`linux-6.12.113+deb13.tar.xz` échoue et il **retombe sur `linux-6.12.tar.xz`
(6.12.0)**. Le module compile, mais `struct hda_gen_spec` diffère entre 6.12.0
et 6.12.113 → **Oops noyau** dès que WirePlumber touche « Auto-Mute Mode »
(`automute_mode_put` → `call_update_outputs` → saut dans une page NX),
WirePlumber bloqué en état D.

→ `son/fix-son-rebuild.sh` corrige la détection (`| cut -d '+' -f1`) et
recompile contre les vraies sources **6.12.113**.

Micro : fonctionnel (source « Audio interne Stéréo analogique »).

## t1-revive — T1 bloquée en recovery

**Symptôme** : `lsusb` → `05ac:1281 Apple Mobile Device [Recovery Mode]`,
pas de Touch Bar, pas de caméra. Les fichiers
`EFI/APPLE/EMBEDDEDOS/{combined.memboot,FDRData,version.plist}` étaient
présents sur l'ESP, mais **recopiés** (tous datés de la même minute, logs
`EFI/APPLE/LOG` jamais mis à jour aux reboots suivants) → la T1 les refusait,
même après un arrêt complet.

**Fix** : [niconistal/t1-revive](https://github.com/niconistal/t1-revive) v0.1.5,
prévu pour Arch, utilisé tel quel sous Debian :

```sh
sudo apt install autoconf automake libtool pkgconf libzip-dev libusb-1.0-0-dev \
  libssl-dev libcurl4-openssl-dev zlib1g-dev libreadline-dev acpi-call-dkms
git clone https://github.com/niconistal/t1-revive && cd t1-revive
bash build.sh                                  # sans root, dans ./prefix
sudo bin/t1-revive preflight                   # 24/25 ok : seul « package checks Arch only » est NO
sudo bin/t1-revive backup --to ~/t1/backup-efi
sudo bin/t1-revive regenerate                  # secteur branché, ~4 min
```

`preflight` sort en code 3 à cause du contrôle de paquets Arch, mais
`regenerate` ne dépend pas de ce contrôle. Résultat : **T1 en `05ac:8600`**
en 3 min 57 s, caméra visible immédiatement.

> Garder `~/t1/backup-efi/` **hors de la machine** : c'est la seule clé de
> Touch ID pour ce Mac.

## Touch Bar — t1bridge porté sur kernel 6.12

t1bridge v0.1.12 (`standardagents/t1bridge`, commit `81cbdf8`) n'a que des
paquets Arch. Compilé à la main :

- **Rust ≥ 1.88** requis, Debian n'a que 1.85 → `rustup` (utilisateur).
- `libsystemd-dev` pour `t1-touchbar-hw`.
- Modules : `t1_cfgsel` ✅ tel quel, `apple_t1_ncm` ✅ tel quel,
  **`appletbdrm`** ❌ → patch [`appletbdrm-6.12-drm_dev_set_dma_dev.patch`](touchbar/patches/appletbdrm-6.12-drm_dev_set_dma_dev.patch)
  (`drm_dev_set_dma_dev` n'existe qu'à partir de 6.16 ; ne sert qu'au
  partage de buffers, inutile ici), **`uvcvideo-t1`** ❌ (basé sur 7.1) →
  voir caméra.

Installation : [`touchbar/install-touchbar.sh`](touchbar/install-touchbar.sh)
(modules dans `/lib/modules/$(uname -r)/updates/t1bridge/`, `t1_cfgsel` dans
l'initramfs, services systemd + udev, groupe `t1bridge`).
`sudo bash install-touchbar.sh annuler` retire tout.

### ⚠️ Piège : usbmuxd déconfigure la T1

Après installation, Touch Bar noire **et** plus de caméra :
`bConfigurationValue` vide alors que `t1_cfgsel` avait bien choisi la config 2
au boot (interfaces `1-3:2.x` dans dmesg). Coupable :
`/usr/lib/udev/rules.d/39-usbmuxd.rules` cible `5ac/8600/*` et fait
`ATTR{bConfigurationValue}="0"` à chaque `add`.

→ [`touchbar/fix-usbmuxd.sh`](touchbar/fix-usbmuxd.sh) : copie de la règle
dans `/etc/udev/rules.d/` **sans** `|5ac/8600/*` (iPhone/iPad toujours gérés),
puis `echo 2 > bConfigurationValue`. Touch Bar allumée immédiatement.

À vérifier côté Fedora : même règle usbmuxd possible.

## Caméra — H.264 seulement en config 2

En config 2 (celle de la Touch Bar), la caméra T1 n'expose **que du H.264**
(1280×720 / 640×480). Le `uvcvideo` de 6.12 ne parse pas les descripteurs
H.264 → [`uvcvideo-6.12.113-h264-t1.patch`](touchbar/patches/uvcvideo-6.12.113-h264-t1.patch) :
les 2 patches upstream de t1bridge (`0001-parse-h264-descriptors`,
`0002-disable-autosuspend`) adaptés à 6.12.113 (2 hunks réécrits à la main :
la boucle de parsing des frames n'est pas encore factorisée en
`uvc_parse_frame()` dans 6.12).

Puis même architecture que sous Fedora (caméra virtuelle v4l2loopback), en
une seule boucle bash au lieu de 3 services :

- [`camera/install-webcam-virtuelle.sh`](camera/install-webcam-virtuelle.sh) :
  `v4l2loopback video_nr=10 card_label="FaceTime HD" exclusive_caps=1`.
- [`camera/facetime-auto`](camera/facetime-auto) + [`.service`](camera/facetime-auto.service)
  (service **utilisateur**) : au repos ffmpeg pousse du **noir 5 fps** (voyant
  éteint, ~0 % CPU) ; dès qu'un process lit `/dev/video10` (`fuser`, poll 1 s)
  → bascule sur `ffmpeg H.264 → yuyv422 720p30` ; 5 s sans lecteur → retour au
  noir.
- [`camera/51-masquer-ibridge.conf`](camera/51-masquer-ibridge.conf)
  (WirePlumber) : désactive les nodes « iBridge » (H.264 inutilisables) pour
  que PipeWire ne propose que « FaceTime HD ».

Pièges rencontrés :
- Sans producteur, `v4l2loopback` 0.15 refuse `VIDIOC_G_INPUT` → il faut un
  producteur permanent (le noir), pas seulement `keep_format`.
- `keep_format=1` garde l'ancien format au redémarrage du service → remis à 0
  au lancement, puis 1 une fois la source noire en place.
- WirePlumber énumère `/dev/video10` au boot **avant** la source noire → il le
  voit en sortie, pas en capture → `ExecStartPost` relance WirePlumber.
- Sortie en **YUY2** (format validé sous Fedora) plutôt qu'en I420.

### Firefox : `media.webrtc.camera.allow-pipewire`

GNOME Caméra marchait, **Firefox ESR 153 ne voyait ni caméra ni micro**.
Firefox ouvrait `/dev/video0` (la T1 brute, H.264) en **V4L2 direct**, échouait,
et `getUserMedia({audio, video})` échouait en bloc → micro absent aussi.

Fix, **dans chaque profil** (`~/.config/mozilla/firefox/*/user.js`) :

```js
user_pref("media.webrtc.camera.allow-pipewire", true);
```

Firefox passe alors par le portail / PipeWire et ne voit que « FaceTime HD ».
Penser aux profils créés plus tard (ou `about:config`).

## Écran noir / gel — amdgpu Polaris

**Symptôme** : débrancher l'écran Dell externe → écran noir quelques secondes
après, machine figée (reboot forcé). Aussi un gel **au login GDM** sans écran
externe. Déjà présent avant la Touch Bar. Températures normales
(CPU 55–58 °C, GPU 49 °C, ventilateurs ~2000 tr/min).

**Journal** :

```
amdgpu: [drm] *ERROR* [CRTC:57:crtc-0] flip_done timed out
amdgpu: ring gfx timeout, signaled seq=94, emitted seq=95
amdgpu: Process information: process gnome-shell ...
amdgpu: GPU reset begin!            (et ne revient jamais)
INFO: task Xwayland blocked for more than 120 seconds (amdgpu_vm_fini / dma_fence_wait)
```

**Le fix qui marche** — [`display/fix-amdgpu-high.sh`](display/fix-amdgpu-high.sh) :

```
# /etc/udev/rules.d/80-amdgpu-high.rules
ACTION=="add|change", SUBSYSTEM=="drm", KERNEL=="card[0-9]", DRIVERS=="amdgpu", ATTR{device/power_dpm_force_performance_level}="high"
```

En `auto`, la VRAM bascule sans arrêt **300 ↔ 1270 MHz** (`pp_dpm_mclk`) ;
sur Polaris, une bascule MCLK pendant le scan-out est une cause connue de
`flip_done timed out`. Typiquement : 2 écrans → MCLK bloquée haute ;
débranchement → 1 seul écran → la carte redescend → gel. En `high`, MCLK reste
à 1270 MHz. Coût : un peu plus de chaleur et de conso. **Applicable à chaud,
réversible sans reboot** :

```sh
echo auto | sudo tee /sys/class/drm/card*/device/power_dpm_force_performance_level
```

**Ce qui n'a pas marché / à éviter** :

| Essai | Résultat |
|---|---|
| `amdgpu.dcdebugmask=0x10` (désactive PSR) | gel toujours présent (laissé en place, inoffensif) |
| `apple_gmux.force_igd=1` | **paramètre inexistant** en 6.12 (`unknown parameter 'force_igd' ignored`) |
| `echo IGD > /sys/kernel/debug/vgaswitcheroo/switch` avant GDM (service systemd) | ❌ **écran noir complet** : i915 a déjà abandonné l'eDP au probe (`failed to retrieve link info, disabling eDP`), basculer le mux après coup ne le réveille pas. Récupéré via SSH. |
| `outb 0x728/0x710/0x740` dans GRUB | non tenté : le gmux est **indexed** (v4.0.29), ces ports sont ceux des anciens gmux |
| `amdgpu.dc=0` | non retenté (cassait l'affichage sous Fedora) |
| `amdgpu.sg_display=0` (piste Fedora) | non tenté : ce paramètre concerne les APU, a priori sans effet sur une Polaris dédiée |

## Réglages système (revue du syslog)

Revue de `journalctl -b -p warning` + kernel : aucune unité en échec,
microcode à jour (`0xf0`, dernier pour ce Skylake). Deux corrections :

**Veille désactivée** — la veille casse la pile t1bridge et la reprise amdgpu
(risque d'écran noir / gel au réveil). Par défaut, GNOME mettait en veille
après 15 min sur batterie, et logind à la fermeture du capot.

```sh
# veille auto sur batterie -> rien (l'écran s'éteint et se verrouille quand même)
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
```

```ini
# /etc/systemd/logind.conf.d/10-capot-verrouille.conf
[Login]
HandleLidSwitch=lock
HandleLidSwitchExternalPower=lock
HandleLidSwitchDocked=ignore
```

⚠️ Capot fermé = machine allumée : l'éteindre avant de la ranger dans un sac.

**Firmware Realtek** — l'adaptateur Ethernet USB 2,5 Gbit (RTL8156B, `r8152`)
tournait sans son firmware (`failed to load rtl_nic/rtl8156b-2.fw`) →
`apt install firmware-realtek`.

Les deux : [`systeme/fix-veille-realtek.sh`](systeme/fix-veille-realtek.sh).

**Ignorés volontairement** (bruit sans effet) : erreurs ACPI `_PDC`/`GCAP`/
`OSCP` (tables Apple pour macOS), `brcm/BCM.hcd` absent (firmware Bluetooth
Apple non distribuable, le Bluetooth marche), `clm_blob`/`txcap_blob`
brcmfmac (n'existent pas pour la 43602), avertissements MDS/MMIO « SMT on »,
`hid_field_extract() n (64) > 32` sur l'iBridge, warnings GNOME/ALSA/keyring.

## Après une mise à jour du kernel

- **Son** : reconstruit tout seul (DKMS).
- **Touch Bar + caméra** : modules installés à la main dans
  `updates/t1bridge/` → **pas** reconstruits. Recompiler `t1_cfgsel`,
  `appletbdrm` (patché) et `uvcvideo` (patché) contre le nouveau kernel, puis
  relancer `install-touchbar.sh`.
- `v4l2loopback` : DKMS (paquet Debian), automatique.

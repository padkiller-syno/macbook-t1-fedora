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
| **Clavier** `@` / `<` inversés | ✅ `applespi iso_layout=1` | [`../keyboard/`](../keyboard/README.md) |
| **Touch ID** (sudo, polkit, verrouillage, GDM) | ✅ 2 doigts, Touch Bar en français | [`touchid/`](#touch-id) |
| **Touch Bar : volume / média** | ✅ fournisseur bureau GNOME + PipeWire | [`touchbar/desktop-provider/`](#touch-bar--volume-sourdine-média) |
| **Capteur de lumière ambiante** | ✅ déjà fonctionnel (luminosité auto GNOME) | [ici](#capteur-de-lumière-ambiante) |
| **Modules T1 sous DKMS** | ✅ reconstruits à chaque nouveau kernel | [`dkms/`](#après-une-mise-à-jour-du-kernel--dkms) |
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

## Touch ID

Fait **après** la Touch Bar (même t1bridge v0.1.12, commit `81cbdf8`).
La T1 avait été régénérée par t1-revive : son `FDRData` est accepté par
l'import (`t1bridge machine-data import`).

### Phase 1 — services + libfprint/fprintd patchés (sans toucher à PAM)

1. [`touchid/touchid-deps.sh`](touchid/touchid-deps.sh) : dépendances de
   compilation (`libudev-dev`, `libarchive-dev`, `meson`, `libgusb-dev`,
   `libgudev-1.0-dev`, `libpam0g-dev`, `libpolkit-gobject-1-dev`…) **+ pin APT**
   `/etc/apt/preferences.d/no-debian-fprintd` (priorité -1 sur `fprintd`,
   `libfprint-2-2`, `libpam-fprintd`) pour que Debian n'écrase jamais les
   versions patchées. Il faut aussi `gettext` (msgfmt) pour fprintd.
2. Binaires Rust (`--locked --release`, Rust ≥ 1.88 via rustup) :
   `t1-xart-storage`, `t1-ncm-ready`, `t1-keybag-relay`
   (`--features keybag-relay-service`), `t1-touchid-auth`
   (`--features auth-broker-service`), `t1-touchid`, `t1-legacy-recovery`
   (`--features legacy-recovery`), `t1bridge` (importer, `-p t1-import`).
3. libfprint commit `3f1e281` + patches t1bridge `0001`/`0002`, fprintd
   commit `b54a007` + patches `0001`/`0002` (sha256 identiques aux PKGBUILD) :

   ```sh
   meson setup build-libfprint --prefix=/usr -Ddrivers=all -Dinstalled-tests=false \
     -Ddoc=false -Dintrospection=false \
     -Dudev_rules_dir=/usr/lib/udev/rules.d -Dudev_hwdb_dir=/usr/lib/udev/hwdb.d
   PKG_CONFIG_PATH=$PWD/build-libfprint/meson-uninstalled \
   meson setup build-fprintd --prefix=/usr --sysconfdir=/etc -Dgtk_doc=false -Dman=false \
     -Dpam=true -Dpam_modules_dir=/usr/lib/x86_64-linux-gnu/security \
     -Dsystemd_system_unit_dir=/usr/lib/systemd/system
   ```

   (`-Dudev_*_dir` explicites : sans `systemd-dev`, `udev.pc` est absent.)
4. [`touchid/install-touchid.sh`](touchid/install-touchid.sh) : module
   `apple_t1_ncm` (compile tel quel en 6.12), binaires, unités systemd, lien
   `50-t1bridge-ncm.link`, règle `90-t1bridge-xart.rules`, `meson install`
   des deux projets (manifeste gardé pour `annuler`). Puis **poweroff**.

Après reboot : `apple_t1_ncm` chargé, interface privée `eth0` (link-local
IPv6, non gérée par NetworkManager), `t1-xart-storage@eth0` actif, port
`[::]%eth0:61500` en écoute. **Aucun pare-feu actif** sur cette machine
(nftables/firewalld/ufw inactifs) → rien à ouvrir.

```sh
sudo systemctl start t1bridge-import.service   # import FDRData depuis l'ESP
sudo t1bridge status                           # tout « ready », keybag: not-enrolled
fprintd-enroll -f right-index-finger
fprintd-verify                                 # verify-match
```

⚠️ **Premier `fprintd-enroll` : `enroll-unknown-error`**
(`t1bridge keybag: prepare device keybag failed`). Réseau T1 sain. Avec
`/etc/t1bridge/diagnostics.conf` → `T1BRIDGE_DIAGNOSTICS=1` et
`systemctl restart t1-touchid-auth.service`, la **2ᵉ tentative a réussi**
(keybag créé, relais démarré, `phase=enroll result=ok`). Probablement un
broker démarré trop tôt après le boot. Ne pas boucler ni effacer
`/var/lib/t1bridge` : une seule nouvelle tentative, diagnostics activés.
Penser à retirer `diagnostics.conf` ensuite.

### Phase 2 — PAM

- **GDM et l'écran de verrouillage** : `/etc/pam.d/gdm-fingerprint` (fourni
  par gdm3) et `org.gnome.login-screen enable-fingerprint-authentication`
  étaient déjà là ; il manquait juste `pam_fprintd.so`. Rien à modifier.
- **sudo, polkit, su** : profil `pam-auth-update` (copie de celui de
  `libpam-fprintd`) → [`touchid/touchid-pam.sh`](touchid/touchid-pam.sh) :

  ```
  auth  [success=2 default=ignore]  pam_fprintd.so max-tries=1 timeout=10
  auth  [success=1 default=ignore]  pam_unix.so nullok try_first_pass
  ```

  Empreinte d'abord (10 s), mot de passe ensuite. Garder un shell root ouvert
  pendant le test (`sudo -k; sudo true`). Annuler :
  `sudo pam-auth-update --disable t1bridge-fprintd`.

Restent au mot de passe : LUKS au boot, et la 1ʳᵉ connexion après boot
(trousseau GNOME).

### Touch Bar en français

Les messages Touch ID de la Touch Bar ne sont pas des chaînes traduisibles :
ce sont **5 masques alpha précalculés** (`overlay_labels.rs`, Inter Medium
4.1). Régénérés en français avec la même police (`fonts-inter` Debian = 4.1)
à **26 px** (taille étalonnée sur les originaux) :

| Libellé | Original | Français |
|---|---|---|
| `ENROLLMENT` | Lift and rest your finger on Touch ID repeatedly | Posez et levez le doigt sur Touch ID plusieurs fois |
| `AUTHENTICATE` | Unlock with Touch ID | Déverrouiller avec Touch ID |
| `APPROVE` | Approve with Touch ID | Autoriser avec Touch ID |
| `RETRY` | Try Again | Réessayez |
| `SUCCESS` | Unlocked | Déverrouillé |

[`touchid/gen-labels-fr.py`](touchid/gen-labels-fr.py) (ou le patch
[`touchbar-labels-fr.patch`](touchid/patches/touchbar-labels-fr.patch)), puis
`cargo build -p t1-touchbar`, `install` dans `/usr/lib/t1bridge/` et
`systemctl --user restart t1-touchbar.service`. Les 96 tests du crate passent
(la largeur des libellés est libre, mise à l'échelle par le renderer).

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

## Touch Bar : volume, sourdine, média

t1bridge ne fournit aucun contrôle de volume/média : il définit un contrat
« **Desktop provider v1** » (`docs/interfaces.md`) — un exécutable utilisateur
appelé par le renderer avec `v1 status | set-volume N | toggle-mute |
media-previous | media-play-pause | media-next` (délai max 500 ms, sortie
`T1BRIDGE-DESKTOP 1 <caps> <volume> <muet> [<écran>]`).

[`touchbar/desktop-provider/t1-desktop-provider`](touchbar/desktop-provider/t1-desktop-provider)
(bash, ~45 ms) :

- **volume / sourdine** : `wpctl` sur `@DEFAULT_AUDIO_SINK@` ;
- **média** : premier lecteur MPRIS du bus de session (Firefox, Spotify, VLC…),
  boutons affichés seulement si un lecteur existe ;
- **extinction avec l'écran** (capacité 16) : `PowerSaveMode` de
  `org.gnome.Mutter.DisplayConfig` ≠ 0 → Touch Bar sombre.

Branchement (sans root) :
[`desktop-provider.conf`](touchbar/desktop-provider/desktop-provider.conf) →
`~/.config/systemd/user/t1-touchbar.service.d/`, script → `~/.local/bin/`, puis
`systemctl --user daemon-reload && systemctl --user restart t1-touchbar.service`.

Pièges :
- `LC_ALL=C` obligatoire : en locale `fr_FR`, `awk` lit `0.38` comme `0`
  (virgule décimale) → volume affiché à 0.
- `busctl --user list` coûte ~230 ms (introspection de chaque nom) : utiliser
  un seul `ListNames` pour trouver `org.mpris.MediaPlayer2.*`.

## Capteur de lumière ambiante

Rien à faire : le capteur de la T1 apparaît en `iio:device0` (`als`, via
`hid-sensor-hub` sur l'iBridge), `iio-sensor-proxy` le voit
(`HasAmbientLight = true`, valeur en lux) et GNOME a déjà
`org.gnome.settings-daemon.plugins.power ambient-enabled = true`
(Paramètres → Énergie → Luminosité automatique).

## Après une mise à jour du kernel — DKMS

Les 4 modules T1 sont sous **DKMS** (`t1bridge-debian/0.1.12`) et sont
reconstruits automatiquement à chaque nouveau kernel Debian, comme le son
(`snd_hda_macbookpro`) et `v4l2loopback` :

| Module | Source |
|---|---|
| `t1_cfgsel` | t1bridge tel quel |
| `appletbdrm` | t1bridge + [garde `drm_dev_set_dma_dev`](touchbar/patches/appletbdrm-6.12-drm_dev_set_dma_dev.patch) |
| `apple_t1_ncm` | t1bridge tel quel |
| `uvcvideo` | uvcvideo **6.12.113** + [parsing H.264 T1](touchbar/patches/uvcvideo-6.12.113-h264-t1.patch) |

```sh
bash dkms/build-dkms-tree.sh          # ~/t1/dkms/t1bridge-debian-0.1.12 (t1bridge 81cbdf8 + patches)
sudo bash dkms/install-dkms-t1.sh     # dkms add/build/install, retire les copies manuelles, initramfs
dkms status                           # t1bridge-debian/0.1.12 ... installed
```

[`dkms.conf`](dkms/dkms.conf) installe les 4 modules dans `updates/dkms`
(prioritaires sur le `uvcvideo` du kernel) ; `t1_cfgsel` reste dans
l'initramfs via `/etc/initramfs-tools/modules` (hook `dkms` exécuté avant
`update-initramfs` au postinst du kernel).

⚠️ Limite : `uvcvideo` est figé sur les sources **6.12.113**. Si une future
6.12.x modifie ce driver, sa compilation DKMS peut échouer → seule la caméra
tombe ; régénérer le patch sur les nouvelles sources.

Annuler : `sudo bash dkms/install-dkms-t1.sh annuler`
(`touchbar/install-touchbar.sh annuler` le fait aussi).

# Touch Bar — pile t1bridge

La Touch Bar (et le Touch ID, le rétroéclairage clavier SPI) vivent sur le
coprocesseur T1. Sous Linux, la pile qui fait tout est **t1bridge**
(https://github.com/standardagents/t1bridge), version **0.1.12** = HEAD
upstream au 15/10/2026.

**Statut : Touch Bar fonctionnelle et stable** (depuis le 15/10/2026,
0 denial SELinux, session maintenue sans revocation).

## Architecture

- **Modules noyau (DKMS 0.1.12, 4 modules signés)** :
  - `t1_cfgsel` — driver « configuration selector » : force le T1 en USB
    **configuration 2** (mode iBridge complet : Touch Bar + NCM + XART).
  - `appletbdrm` — DRM/KMS pour la Touch Bar (retro-éclairage + frames).
  - `apple_t1_ncm` — réseau CDC-NCM du T1 (canal de contrôle).
  - `uvcvideo` (recompilé) — caméra iBridge.
- **Userspace** :
  - `/usr/bin/t1bridge` (démon : import du T1, contrôle USB, firmware).
  - `t1-touchbar-hw.service` (system system) — écrit les frames Touch Bar
    (memfd `t1-frame` passé par SCM_RIGHTS au renderer).
  - `t1-touchbar` (service **user**) — le renderer GNOME/Qt.
  - `/usr/bin/t1-touchid` — Touch ID.

## Installation (récapitulatif)

Aucun paquet officiel Fedora → compilation depuis le dépôt source
(layout Arch PKGBUILD) :

```sh
# dépendances
sudo dnf install cargo libcurl-devel libarchive-devel openssl-devel \
    xz-devel pkgconf iio-sensor-proxy akmod kernel-devel

# build + install (9 binaires)
cd ~/t1bridge
cargo build --locked --release
# scripts du repo : install userspace dans /usr/lib/t1bridge/ + /usr/bin/t1bridge
# + unités systemd ; DKMS 0.1.12 pour les 4 modules
```

## Le fix boot indispensable : USB configuration 2

**Problème** : après la transition initramfs → root system (« soft reboot »
systemd-udevd), le T1 revient en **configuration 1** (USB par défaut)
au lieu de la **config 2** (iBridge complet). Résultat : Touch Bar morte
jusqu'au prochain cycle USB.

**Fix** (fichiers dans `boot/`) :
- `50-t1-cfgsel.rules` — règle udev : dès que le `05ac:8600` apparaît en
  config 1 (events `add`/`change`), exécute le script.
- `t1-cfg-fix.sh` — trouve le device `05ac:8600`, et si `bConfigurationValue
  != 2`, fait un unbind/bind sur le driver `t1bridge-cfgselector` qui
  re-sélectionne la config 2.
- `t1-cfgsel-fix.service` — filet de sécurité au boot (oneshot, reste actif).

Installation :
```sh
sudo cp boot/50-t1-cfgsel.rules /etc/udev/rules.d/
sudo cp boot/t1-cfg-fix.sh /usr/local/lib/t1bridge/
sudo cp boot/t1-cfgsel-fix.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable t1-cfgsel-fix.service
```

Autres configs boot conservées : `/etc/modules-load.d/`, `/etc/modprobe.d/`,
`/etc/dracut.conf.d/t1bridge` (modules chargés dès l'initramfs).

## SELinux : le module t1hwframe

**Problème** : avec SELinux enforcing, le démon `t1-touchbar-hw` (domaine
`init_t`) devait **écrire** dans le memfd `t1-frame` créé par le renderer
user (label `user_tmp_t`) et reçu par SCM_RIGHTS. Sans règle : chaque cycle
de connexion mourait sur `AVC denied { write }` → session-revocation →
Touch Bar noire.

**Fix** : module SELinux `t1hwframe` (source : `selinux/t1hwframe.te`) :
```
allow init_t user_tmp_t:file { read write map getattr lock open };
```

Build + install (pitfalls Fedora 44 notés au passage) :
```sh
# paquets requis
sudo dnf install selinux-policy-devel setools-console
cd ~/t1-diag/selinux-src
checkmodule -M -m -o t1hwframe.mod t1hwframe.te     # -M (pas -m seul)
make -f /usr/share/selinux/tools/Makefile.modbuild t1hwframe.mod
sudo semodule -i t1hwframe.pp
sudo semodule -R    # -i seul ne rechargait pas le kernel
```
Pitfalls : `checkmodule -m` avec la syntaxe `module nom 1.0.0;` ; et
`semodule -i` peut ne pas recharger le policy en mémoire → `semodule -R`.

Après install : **0 denial**, Touch Bar stable.

## Ce qui ne marche PAS (connu, pas encore fait)

- **Touches physique luminosité / rétroéclairage clavier** : pas de handler
  noyau pour les keycodes 224/225/233/234 du clavier SPI ; `BRIGHTUP (224)`
  est même absent des capabilities de `event4`. t1bridge ne gère que le
  slider de la Touch Bar. Il faudrait un petit daemon userspace qui écoute
  `event4` et écrit dans :
  - `/sys/class/backlight/gmux_backlight/brightness` (0–1023, eDP),
  - `/sys/class/leds/spi::kbd_backlight/brightness` (0–255, **deux** deux-points).
  Les deux sont écriturables et validés (tests injection C).
- **Rétroéclairage clavier via SMC** : pas de clé KBLT dans les 911 clés SMC
  lues — le rétroéclairage est bien piloté par le T1 (LED SPI).

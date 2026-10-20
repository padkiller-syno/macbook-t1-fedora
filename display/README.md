# Écran noir aléatoire — bug amdgpu Polaris

**Statut : fix v2 posé (2026-10-16), à tester au prochain reboot.**
Le fix v1 (`amdgpu.dc=0`) est **banni** — il cassait l'affichage au boot.

> **Mise à jour 2026-10-20 (Debian 13, même machine)** : le gel est résolu en
> fixant les fréquences de la Polaris — `power_dpm_force_performance_level=high`
> via une règle udev (MCLK bloquée à 1270 MHz au lieu de basculer
> 300 ↔ 1270 MHz). Applicable à chaud, réversible sans reboot. Devrait
> s'appliquer tel quel sous Fedora. Détails et liste des essais ratés :
> [`../debian13/README.md`](../debian13/README.md#écran-noir--gel--amdgpu-polaris).

## Symptôme

Au hasard : l'écran devient **noir**, le système reste **100 % vivant**
(clavier allumé, Maj s'allume, audio en fond), **aucun moyen de le faire
revenir sauf reboot**. Déjà présent **avant** l'installation de t1bridge.

## Diagnostic

- Dual GPU : i915 (Skylake) + amdgpu **Baffin/Polaris** (RX 550, `1002:67EF`).
- L'eDP est piloté par **amdgpu (card1) via GMUX v4.0.29** ; l'eDP i915
  échoue au boot (`failed to retrieve link info, disabling eDP`).
- Backlight unique `gmux_backlight` (max 1023) ; `appletbdrm` ne crée pas
  de 2e backlight.
- `Display Core v3.2.384 initialized on DCE 11.2` au boot (DC actif).
- Moniteur 1 Hz (`blacklog.sh` → CSV) : backlight, status eDP-1,
  `gpu_busy_percent`, température — à relancer après chaque reboot pour
  attraper l'événement en flagrant délit.

## Les params testés (kernel 7.2.10-200.fc44)

| Param | Résultat |
|---|---|
| `amdgpu.dc=0 gpu_recovery=1 gfx_off=0` (v1, 16/10) | ❌ **cassait l'affichage au boot** : glitch (ligne en bas d'écran), affichage inutilisable — l'utilisateur a dû éditer le menu GRUB (touche `e`) pour virer les lignes et démarrer. `dc=0` bascule sur l'ancien chemin d'affichage, inadapté à cette Polaris. **Banni.** |
| `amdgpu.gfx_off=0` | inexistant sur ce ASIC (param Vega+), inutile ici |
| **`amdgpu.sg_display=0` + `amdgpu.gpu_recovery=1`** (v2) | ⏳ posé, à tester. `sg_display=0` désactive le power-gating du moteur d'affichage (cause classique des hangs aléatoires Polaris : l'engine s'endort et ne se réveille plus → écran noir, système vivant). `gpu_recovery=1` fait réessayer au driver de récupérer le GPU au lieu de le laisser mort. |

### État actuel du boot (grubby)

- kernel **7.2.10** (par défaut) : `amdgpu.sg_display=0 amdgpu.gpu_recovery=1`
- kernel **6.19.10** : **propre, aucun param** → fallback sûr dans le menu GRUB
  si le 7.2.10 posait un problème.
- Le boot est en **BLS** : les args viennent des entrées
  `/boot/loader/entries/` (répertoire root-only, c'est pourquoi `grubby`
  est l'outil de confiance — `/etc/default/grub` n'est pas reflété dans
  `/proc/cmdline`).

### Re-tester

```sh
sudo grubby --info=ALL | grep args          # vérifier les params par kernel
# rebooter ; après boot :
cat /proc/cmdline                            # les params DOIVENT y figurer
journalctl -b | grep -iE "amdgpu|drm" | head -30
```

Si l'écran noir persiste avec `sg_display=0` : relancer le moniteur
`blacklog.sh` en flagrant délit, puis plan B : `amdgpu.sg_ip_block=0`
(power-gating complet) ou basculer l'affichage GMUX vers l'iGPU (i915).

## Moniteur

`blacklog.sh` (à relancer après chaque reboot, il ne survit pas) :

```sh
nohup ~/git/macbook-t1-fedora/display/blacklog.sh >> ~/t1-diag/blacklog.log 2>&1 &
```

Colonnes : `time,backlight,edp_status,gpu_busy,amdgpu_temp`.

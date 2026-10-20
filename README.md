# MacBook Pro 13,3 (2016, Touch Bar) sous Fedora 44

Référentiel complet de ce qu'il a fallu pour faire tourner la **Touch Bar**
et la **caméra/micro** du MacBook Pro 2016 Touch Bar (coprocesseur Apple T1)
sous **Fedora 44**, kernel `7.2.10-200.fc44.x86_64`.

> **Debian 13 (kernel 6.12)** : même machine, tout refait et fonctionnel
> (Wi-Fi, son, T1 régénérée, Touch Bar, caméra, Touch ID, écran noir amdgpu) →
> [`debian13/`](debian13/README.md).

T1 = le coprocesseur Apple qui pilote la Touch Bar, la caméra FaceTime HD,
le rétroéclairage clavier et le Touch ID. Sous Linux, il apparaît comme un
iBridge USB (`05ac:8600`) qu'il faut « réveiller ».

## Machine

| | |
|---|---|
| Modèle | MacBookPro13,3 (2016, Touch Bar) |
| CPU | i7-6820HQ (Skylake) |
| GPU | Intel HD 530 (i915) + AMD Baffin/Polaris (RX 550, amdgpu) — affichage eDP piloté par **amdgpu via GMUX** |
| OS | Fedora 44, SELinux enforcing, session **Wayland** (GNOME) |
| Chiffrement | LUKS sur le volume racine |

## Les 4 chantiers et leur statut

| Chantier | Statut | Dossier |
|---|---|---|
| **Touch Bar** (t1bridge + SELinux + boot) | ✅ Fonctionnelle et stable | [`touchbar/`](touchbar/README.md) |
| **Caméra + micro** (cam virtuelle v4l2loopback) | ✅ Fonctionnels, caméra éteinte au repos | [`camera/`](camera/README.md) |
| **Clavier SPI : swap @ / \<** | ✅ `applespi iso_layout=1` | [`keyboard/`](keyboard/README.md) |
| **Écran noir aléatoire** (bug amdgpu Polaris) | ⏳ Fix posé, à tester au reboot — résolu sous Debian par `power_dpm_force_performance_level=high`, voir [`debian13/`](debian13/README.md#écran-noir--gel--amdgpu-polaris) | [`display/`](display/README.md) |

## Arborescence

```
├── README.md                ← ce fichier
├── touchbar/
│   ├── README.md            ← pile t1bridge : installation, fix boot, SELinux
│   ├── selinux/t1hwframe.te ← module SELinux source (frame Touch Bar)
│   └── boot/                ← fix USB config 2 (udev + service + script)
├── camera/
│   ├── README.md            ← cause racine + architecture de la cam virtuelle
│   ├── systemd/             ← 3 services user (stub, pipeline, watchdog)
│   ├── scripts/             ← watchdog on/off
│   ├── kernel/              ← config module v4l2loopback (modprobe + modules-load)
│   └── install/             ← (voir install/install-camera.sh à la racine)
├── keyboard/
│   ├── README.md            ← diagnostic swap @/< (keycodes 86/41)
│   └── keycap90.log         ← capture brute des keycodes (preuve)
├── display/
│   ├── README.md            ← écran noir aléatoire : diagnostic + fix amdgpu
│   └── blacklog.sh          ← moniteur 1 Hz (backlight, eDP, GPU)
└── install/
    └── install-camera.sh    ← réinstallation complète de la cam virtuelle
```

## Reprendre plus tard

- **Caméra** : `install/install-camera.sh` fait tout (module + 3 services + enable).
- **Touch Bar** : voir `touchbar/README.md` (source : dépôt `standardagents/t1bridge`,
  branche/v0.1.12 = HEAD upstream au 15/10/2026).
- **Clavier** : résolu par `options applespi iso_layout=1` (+ régénérer
  l'initramfs), voir `keyboard/README.md`.
- **Écran noir** : `display/README.md` — le fix `amdgpu.sg_display=0 gpu_recovery=1`
  est posé sur le kernel 7.2.10 via `grubby` ; `6.19.10` reste en fallback propre.

# Caméra + micro — caméra virtuelle v4l2loopback

**Statut : caméra et micro fonctionnels** dans Firefox, Chrome et l'app
Caméra de GNOME (visio Google Meet OK). La caméra T1 est **éteinte au
repos** et ne s'allume que pendant l'appel.

## Cause racine

La caméra FaceTime HD du T1 (`iBridge`, `/dev/video0`) n'expose **qu'un seul
format : H.264 1280×720 @ 10–30 fps** (le T1 encode la vidéo sur puce).
`/dev/video1` n'est que du métadonnées.

Or, **WirePlumber 0.5.18** (le session-manager de PipeWire sur Fedora 44)
rejette ce format à chaque boot :

```
WARN  V4L2 v4l2_pixelformat.cpp:346 Unsupported V4L2 pixel format H264
ERROR UVC uvcvideo.cpp:563 Camera iBridge: FaceTime HD Camera
      doesn't expose any supported format
```

Conséquences :
- Le node caméra PipeWire existe dans `wpctl` mais **ne fournit aucun
  format utilisable** → le portail `xdg-desktop-portal` ne peut rien donner.
- Toutes les apps passant par le portail (Firefox, Chrome, GNOME Camera)
  voient **zéro caméra**. C'est aussi pour ça que le « prompt de
  permission » ne menait à rien : l'autorisation était accordée, mais il
  n'y avait aucun flux derrière.
- `libcamera` a la même limite (`Unsupported V4L2 pixel format H264`).
- En revanche, le V4L2 **direct** marche (ffmpeg, GStreamer) : c'est le
  chemin que la solution exploite.

Le **micro** (codec CS8409/CS42L83 via ALSA/PipeWire) n'a jamais été en
cause — il est exposé normalement (`wpctl` / `pactl`).

## La solution : une caméra virtuelle « FaceTime HD (virtual) »

Un pont qui lit le H.264 de `/dev/video0`, le décode, et l'expose en
**YUY2 720p30** sur un device V4L2 loopback (`/dev/video2`) — une caméra
« normale » aux yeux de WirePlumber, du portail et de tous les navigateurs.

```
T1 (H.264)                    v4l2loopback
/dev/video0  ──► v4l2src ─► h264parse ─► openh264dec ─► videoconvert
                        (décode H.264)              (YUY2 1280x720@30)
                                                            │
                                                            ▼ v4l2sink
                                                    /dev/video2  ◄── apps
                                                    (YUYV 720p30)   (Firefox, Chrome,
                                                                    GNOME Camera, …)
```

### Composants

| Fichier | Rôle |
|---|---|
| `kernel/v4l2loopback.modules-load` | charge le module au boot (`/etc/modules-load.d/`) |
| `kernel/v4l2loopback.modprobe.conf` | `exclusive_caps=1` + `card_label="FaceTime HD (virtual)"` (`/etc/modprobe.d/`) |
| `systemd/t1-cam-stub.service` | **stub** : images noires 720p30 → garde `/dev/video2` prêt, caméra T1 **éteinte** |
| `systemd/t1-virtualcam.service` | **pipeline réel** : H.264 → YUY2 (caméra T1 allumée) |
| `systemd/t1-virtualcam-watchdog.service` | watchdog : fait la navette stub ↔ réel |
| `scripts/virtualcam-watchdog.sh` | le script du watchdog |

Module noyau : `v4l2loopback` 0.15.4 via **akmod** (RPM Fusion) —
reconstruit automatiquement à chaque nouveau kernel.

### Comportement on/off (le watchdog)

1. **Au repos** : le stub (noir) est connecté. La caméra T1 n'est pas
   alimentée (`/dev/video0` fermé).
2. **Une app ouvre la caméra** (via le portail) → un process tient
   `/dev/video2` → le watchdog (poll 0,5 s) **stoppe le stub et démarre le
   pipeline réel** en ~1 s. Premier plan d'app : ~1–2 s noires, puis l'image.
3. **Fin d'appel** : plus de consommateur pendant 5 s → pipeline réel
   stoppé, stub relancé → **la caméra T1 s'éteint**.

Pourquoi le stub ? Sans producteur connecté, `v4l2loopback` ne propose
**aucun format** côté consommateur (`VIDIOC_ENUM_FMT` vide) : aucune app ne
pourrait même ouvrir le device → le stub maintient la caméra virtuelle
« prête » sans jamais allumer la vraie.

### Installation

Tout est dans [`install/install-camera.sh`](../install/install-camera.sh) :

```sh
sudo ~/git/macbook-t1-fedora/install/install-camera.sh
```

Puis se déconnecter/reconnecter (ou reboot) pour que WirePlumber scanne.
Vérification :

```sh
wpctl status                 # Video → Sources : FaceTime HD (virtual)
systemctl --user status t1-cam-stub t1-virtualcam t1-virtualcam-watchdog
fuser /dev/video0            # vide = caméra T1 éteinte (au repos)
```

### Notes & limites

- Résolution limitée à **720p** (c'est tout ce que le T1 sort).
- Le node iBridge « cassé » reste visible dans `wpctl` (device) mais
  n'offre aucun flux ; les apps ne listent que la cam virtuelle utile.
- Si tu fais tes propres tests V4L2 directs sur `/dev/video0`
  (ffmpeg, etc.), stoppe le pipeline d'abord :
  `systemctl --user stop t1-virtualcam t1-cam-stub`.

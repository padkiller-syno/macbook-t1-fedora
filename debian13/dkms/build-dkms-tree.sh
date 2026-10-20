#!/usr/bin/env bash
# Reconstruit ~/t1/dkms/t1bridge-debian-0.1.12 à partir de t1bridge (81cbdf8) + patches du dépôt.
# Prérequis : ~/t1/t1bridge cloné (standardagents/t1bridge, commit 81cbdf8).
set -euo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)            # .../debian13
T1=$HOME/t1/t1bridge; K=$T1/kernel
S=$HOME/t1/dkms/t1bridge-debian-0.1.12
rm -rf "$S"; mkdir -p "$S"/{t1-cfgsel,appletbdrm,apple-t1-ncm,uvcvideo}
cp $K/t1-cfgsel/{Makefile,t1_cfgsel.c,t1_recovery_reset.h} "$S/t1-cfgsel/"
cp $K/appletbdrm-t1/{Makefile,appletbdrm.c,appletbdrm_resume.h,appletbdrm_protocol.h} "$S/appletbdrm/"
patch -d "$S/appletbdrm" -p3 < "$REPO/touchbar/patches/appletbdrm-6.12-drm_dev_set_dma_dev.patch"
cp $K/apple-t1-ncm/{Makefile,apple_t1_ncm.c} "$S/apple-t1-ncm/"
# uvcvideo : sources 6.12.113 + patch H.264 T1
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
curl -sSfL https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.113.tar.xz \
  | tar -xJ -C "$W" --strip-components=1 linux-6.12.113/drivers/media/usb/uvc
patch -d "$W" -p1 < "$REPO/touchbar/patches/uvcvideo-6.12.113-h264-t1.patch"
cp "$W"/drivers/media/usb/uvc/{*.c,*.h,Makefile} "$S/uvcvideo/"
cp "$REPO/dkms/"{dkms.conf,Makefile} "$S/"
echo "== $S prêt ; puis : sudo bash $REPO/dkms/install-dkms-t1.sh"

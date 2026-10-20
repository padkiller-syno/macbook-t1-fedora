#!/usr/bin/env bash
# Dépendances de compilation Touch ID (t1bridge import + libfprint/fprintd patchés)
set -e
[ "$(id -u)" = 0 ] || { echo "Lance-moi avec sudo"; exit 1; }
apt-get install -y libudev-dev libarchive-dev liblzma-dev meson ninja-build \
  libglib2.0-dev libgusb-dev libgudev-1.0-dev libpixman-1-dev libcairo2-dev \
  libgirepository1.0-dev gobject-introspection libpam0g-dev libpolkit-gobject-1-dev \
  libdbus-1-dev python3-gi python3-cairo xsltproc
# Les versions Debian de fprintd/libfprint écraseraient les versions patchées T1
cat > /etc/apt/preferences.d/no-debian-fprintd <<'EOP'
# libfprint/fprintd compilés à la main avec le driver T1Bridge (/usr) : ne pas installer ceux de Debian
Package: fprintd libfprint-2-2 libfprint-2-dev libpam-fprintd gir1.2-fprint-2.0
Pin: release *
Pin-Priority: -1
EOP
echo DEPS_OK

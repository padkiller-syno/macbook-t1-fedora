# Modules T1 (t1bridge v0.1.12) portés sur noyau Debian 6.12 — construit par DKMS
KDIR ?= /lib/modules/$(shell uname -r)/build
SUBDIRS := t1-cfgsel appletbdrm apple-t1-ncm uvcvideo

all:
	for d in $(SUBDIRS); do $(MAKE) -C $(KDIR) M=$(CURDIR)/$$d CONFIG_USB_VIDEO_CLASS=m modules || exit 1; done

clean:
	for d in $(SUBDIRS); do $(MAKE) -C $(KDIR) M=$(CURDIR)/$$d clean; done

.PHONY: all clean

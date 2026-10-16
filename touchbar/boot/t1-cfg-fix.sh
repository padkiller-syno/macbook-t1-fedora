#!/bin/sh
# Force the T1 iBridge back to USB configuration 2 (Touch Bar mode)
# when it comes up in the default configuration 1.
DEV=""
for d in /sys/bus/usb/devices/*; do
    v=$(cat "$d/idVendor" 2>/dev/null)
    p=$(cat "$d/idProduct" 2>/dev/null)
    [ "$v" = "05ac" ] && [ "$p" = "8600" ] && DEV=$(basename "$d") && break
done
[ -z "$DEV" ] && exit 0
cfg=$(cat "/sys/bus/usb/devices/$DEV/bConfigurationValue" 2>/dev/null)
[ "$cfg" = "2" ] && exit 0
drv="/sys/bus/usb/drivers/t1bridge-cfgselector"
[ -d "$drv" ] || exit 0
echo "$DEV" > "$drv/unbind" 2>/dev/null
sleep 0.3
echo "$DEV" > "$drv/bind" 2>/dev/null
exit 0

#!/system/bin/sh
#
# LineageOS A/B OTA Postinstall Script
#

# Backup and restore using backuptool_ab
mount -o remount,rw /postinstall
/postinstall/bin/backuptool_ab.sh backup
/postinstall/bin/backuptool_ab.sh restore
mount -o remount,ro /postinstall

# Run otapreopt_script, the default AOSP postinstall script
/system/bin/otapreopt_script "$@"

exit 0

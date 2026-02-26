#!/bin/bash
#
# diy-part2.sh - OpenWrt 23.05 HiWiFi R33 customization
# Run AFTER feeds install
#

# Modify default LAN IP
sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate

echo "Default LAN IP changed to 192.168.10.1"

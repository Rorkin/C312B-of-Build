#!/bin/bash
# 修改默认 IP 为 192.168.10.1
sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate

# 修改固件版本标识 (可选)
sed -i "s/OpenWrt /C312B-Build-$(date +%Y%m%d) /g" package/base-files/files/etc/banner

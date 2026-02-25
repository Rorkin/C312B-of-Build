#!/bin/bash

# 1. 修改默认管理 IP
sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate

# 2. 注入硬件适配 DTS
if [ -d "$GITHUB_WORKSPACE/custom_files" ]; then
    cp -f $GITHUB_WORKSPACE/custom_files/mt7620a_hiwifi_hc5861b.dts target/linux/ramips/dts/mt7620a_hiwifi_hc5861b.dts
fi

# 3. 强制修正 Makefile：添加驱动并确保生成 factory.bin 和 sysupgrade.bin
DEVICE_MAKEFILE="target/linux/ramips/image/mt7620.mk"
if [ -f "$DEVICE_MAKEFILE" ]; then
    # 注入驱动包
    sed -i '/DEVICE_TITLE := HiWiFi HC5861B/,/IMAGE_SIZE/ s/DEVICE_PACKAGES := .*/DEVICE_PACKAGES := kmod-mt76x2 kmod-usb2 kmod-usb-ohci kmod-ledtrig-usbport kmod-switch-rtl8367b/' $DEVICE_MAKEFILE
    
    # 确保生成的镜像类型包含 factory 和 sysupgrade
    # 针对 23.05 的语法调整，确保两者都生成
    sed -i '/define Device\/hiwifi_hc5861b/,/endef/ s/IMAGES := .*/IMAGES := squashfs-factory.bin squashfs-sysupgrade.bin/' $DEVICE_MAKEFILE
fi

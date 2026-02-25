#!/bin/bash

# 1. 修改默认管理 IP
sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate

# 2. 注入硬件 DTS 补丁 (确保路径和名称与 SOC 前缀匹配)
if [ -d "$GITHUB_WORKSPACE/custom_files" ]; then
    cp -f $GITHUB_WORKSPACE/custom_files/mt7620a_hiwifi_hc5861b.dts target/linux/ramips/dts/mt7620a_hiwifi_hc5861b.dts
fi

# 3. 重写 Makefile 核心定义
MT7620_MAKEFILE="target/linux/ramips/image/mt7620.mk"
# 删除源码中可能存在的旧定义
sed -i '/define Device\/hiwifi_hc5861b/,/endef/d' $MT7620_MAKEFILE

# 注入符合 23.05 标准的设备定义
cat <<EOF >> $MT7620_MAKEFILE

define Device/hiwifi_hc5861b
  \$(Device/gdma-nand)
  SOC := mt7620a
  IMAGE_SIZE := 124160k
  DEVICE_VENDOR := HiWiFi
  DEVICE_MODEL := HC5861B (R33)
  SUPPORTED_DEVICES := hiwifi,hc5861b hiwifi,r33 hiwifi_hc5861b
  DEVICE_PACKAGES := kmod-mt76x2 kmod-usb2 kmod-usb-ohci kmod-ledtrig-usbport kmod-switch-rtl8367b
  IMAGES := squashfs-factory.bin squashfs-sysupgrade.bin
  IMAGE/squashfs-factory.bin := append-kernel | pad-to \$\$(BLOCKSIZE) | append-ubi
  IMAGE/squashfs-sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += hiwifi_hc5861b
EOF

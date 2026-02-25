#!/bin/bash

# 1. 修改默认管理 IP
sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate

# 2. 注入硬件 DTS 补丁
if [ -d "$GITHUB_WORKSPACE/custom_files" ]; then
    cp -f $GITHUB_WORKSPACE/custom_files/mt7620a_hiwifi_hc5861b.dts target/linux/ramips/dts/mt7620a_hiwifi_hc5861b.dts
fi

# 3. 重写 Makefile，增加兼容 ID (SUPPORTED_DEVICES)
MT7620_MAKEFILE="target/linux/ramips/image/mt7620.mk"
sed -i '/define Device\/hiwifi_hc5861b/,/endef/d' $MT7620_MAKEFILE

cat <<EOF >> $MT7620_MAKEFILE

define Device/hiwifi_hc5861b
  \$(Device/gdma-nand)
  DEVICE_VENDOR := HiWiFi
  DEVICE_MODEL := HC5861B (R33)
  # 关键点：添加这一行，让 22.03 的系统能识别并允许升级
  SUPPORTED_DEVICES := hiwifi,hc5861b hiwifi,r33 hiwifi_hc5861b
  DEVICE_PACKAGES := kmod-mt76x2 kmod-usb2 kmod-usb-ohci kmod-ledtrig-usbport kmod-switch-rtl8367b
  IMAGES := squashfs-factory.bin squashfs-sysupgrade.bin
  IMAGE/squashfs-factory.bin := append-kernel | pad-to \$\$(BLOCKSIZE) | append-ubi
  IMAGE/squashfs-sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += hiwifi_hc5861b
EOF

#!/bin/bash

# 1. 修改默认管理 IP
sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate

# 2. 注入硬件 DTS 补丁
if [ -d "$GITHUB_WORKSPACE/custom_files" ]; then
    cp -f $GITHUB_WORKSPACE/custom_files/mt7620a_hiwifi_hc5861b.dts target/linux/ramips/dts/mt7620a_hiwifi_hc5861b.dts
fi

# 3. 强制修正 Makefile 逻辑
MT7620_MAKEFILE="target/linux/ramips/image/mt7620.mk"

# 删除原有定义
sed -i '/define Device\/hiwifi_hc5861b/,/endef/d' $MT7620_MAKEFILE

# 注入新定义，直接在 pad-to 中使用 128k
cat <<'EOF' >> $MT7620_MAKEFILE

define Device/hiwifi_hc5861b
  $(Device/gdma-nand)
  SOC := mt7620a
  IMAGE_SIZE := 124160k
  # 显式申明 NAND 物理参数
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  DEVICE_VENDOR := HiWiFi
  DEVICE_MODEL := HC5861B (R33)
  SUPPORTED_DEVICES := hiwifi,hc5861b hiwifi,r33 hiwifi_hc5861b
  DEVICE_PACKAGES := kmod-mt76x2 kmod-usb2 kmod-usb-ohci kmod-ledtrig-usbport kmod-switch-rtl8367b
  IMAGES := squashfs-factory.bin squashfs-sysupgrade.bin
  # 关键修复：直接使用 128k 避免 dd 参数为空
  IMAGE/squashfs-factory.bin := append-kernel | pad-to 128k | append-ubi
  IMAGE/squashfs-sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += hiwifi_hc5861b
EOF

echo "Makefile 强制填充补丁已应用！"

#!/bin/bash

# 1. 修改默认管理 IP 为 192.168.10.1
sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate

# 2. 注入硬件 DTS 补丁
# 确保 custom_files 目录存在并包含正确的 mt7620a_hiwifi_hc5861b.dts 文件
if [ -d "$GITHUB_WORKSPACE/custom_files" ]; then
    cp -f $GITHUB_WORKSPACE/custom_files/mt7620a_hiwifi_hc5861b.dts target/linux/ramips/dts/mt7620a_hiwifi_hc5861b.dts
    echo "DTS 补丁注入成功"
fi

# 3. 强制重写 Makefile 设备定义 (针对极路由 3 Pro NAND 128MB 深度优化)
MT7620_MAKEFILE="target/linux/ramips/image/mt7620.mk"

# 先删除源码中原有的 hiwifi_hc5861b 定义块
sed -i '/define Device\/hiwifi_hc5861b/,/endef/d' $MT7620_MAKEFILE

# 注入全新的定义，通过硬编码 128k 解决 dd 参数为空的问题，并添加兼容 ID
# 使用 'EOF' (带单引号) 确保 Makefile 中的 $(...) 变量不会被 Shell 提前解析
cat <<'EOF' >> $MT7620_MAKEFILE

define Device/hiwifi_hc5861b
  $(Device/gdma-nand)
  SOC := mt7620a
  IMAGE_SIZE := 124160k
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  DEVICE_VENDOR := HiWiFi
  DEVICE_MODEL := HC5861B (R33)
  # 允许从 22.03 (hiwifi,r33) 无缝升级到 23.05
  SUPPORTED_DEVICES := hiwifi,hc5861b hiwifi,r33 hiwifi_hc5861b
  # 强化驱动：加入 5G WiFi、USB 和千兆交换机驱动，ubi-utils 用于处理 NAND 分区
  DEVICE_PACKAGES := kmod-mt76x2 kmod-usb2 kmod-usb-ohci kmod-switch-rtl8367b kmod-usb-ledtrig-usbport ubi-utils
  IMAGES := squashfs-factory.bin squashfs-sysupgrade.bin
  # 关键修复：pad-to 直接指定 128k，彻底解决编译时 dd 报错
  IMAGE/squashfs-factory.bin := append-kernel | pad-to 128k | append-ubi
  IMAGE/squashfs-sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += hiwifi_hc5861b
EOF

echo "Makefile 修正补丁已应用"

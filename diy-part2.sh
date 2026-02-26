#!/bin/bash

# 1. 修改默认管理 IP
sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate

# 2. 注入硬件 DTS 补丁
if [ -d "$GITHUB_WORKSPACE/custom_files" ]; then
    cp -f $GITHUB_WORKSPACE/custom_files/mt7620a_hiwifi_hc5861b.dts target/linux/ramips/dts/mt7620a_hiwifi_hc5861b.dts
fi

# 3. 强制修正 Makefile (直接修改原位定义，不删除，不追加)
MT7620_MAKEFILE="target/linux/ramips/image/mt7620.mk"

# 确保核心驱动和镜像生成规则被写入 (使用 sed 精确替换原有 Device/hiwifi_hc5861b 块的内容)
# 我们通过匹配 Device/hiwifi_hc5861b 到 TARGET_DEVICES 的范围来重写
sed -i '/define Device\/hiwifi_hc5861b/,/endef/c\
define Device\/hiwifi_hc5861b\
  $(Device\/gdma-nand)\
  SOC := mt7620a\
  IMAGE_SIZE := 124160k\
  DEVICE_VENDOR := HiWiFi\
  DEVICE_MODEL := HC5861B (R33)\
  SUPPORTED_DEVICES := hiwifi,hc5861b hiwifi,r33 hiwifi_hc5861b\
  DEVICE_PACKAGES := kmod-mt76x2 kmod-usb2 kmod-usb-ohci kmod-switch-rtl8367b\
  IMAGES := squashfs-factory.bin squashfs-sysupgrade.bin\
  IMAGE/squashfs-factory.bin := append-kernel | pad-to $$(BLOCKSIZE) | append-ubi\
  IMAGE/squashfs-sysupgrade.bin := sysupgrade-tar | append-metadata\
endef' $MT7620_MAKEFILE

echo "Makefile 修正完成！"

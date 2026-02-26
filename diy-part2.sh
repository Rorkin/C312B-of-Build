#!/bin/bash

# 1. 修改 IP
sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate

# 2. 注入 DTS
if [ -d "$GITHUB_WORKSPACE/custom_files" ]; then
    cp -f $GITHUB_WORKSPACE/custom_files/mt7620a_hiwifi_hc5861b.dts target/linux/ramips/dts/mt7620a_hiwifi_hc5861b.dts
fi

# 3. 强制开启内核驱动支持 (解决不停重启的关键)
# 下载针对 5.15 内核的 Ralink NAND 驱动补丁
PATCH_FOLDER="target/linux/ramips/patches-5.15"
mkdir -p $PATCH_FOLDER
curl -sfL "https://raw.githubusercontent.com/mengzonefire/22.03-of/openwrt-22.03/target/linux/ramips/patches-5.10/0038-mtd-ralink-add-support-for-MT7620-NAND-flash.patch" -o "$PATCH_FOLDER/0038-mtd-ralink-add-support-for-MT7620-NAND-flash.patch"

# 强制在内核配置中启用该驱动
echo "CONFIG_MTD_NAND_RALINK=y" >> target/linux/ramips/mt7620/config-5.15

# 4. 重写 Makefile 规则 (解决 dd 报错和 ubinize 错误)
MT7620_MAKEFILE="target/linux/ramips/image/mt7620.mk"
sed -i '/define Device\/hiwifi_hc5861b/,/endef/d' $MT7620_MAKEFILE

cat <<'EOF' >> $MT7620_MAKEFILE
define Device/hiwifi_hc5861b
  $(Device/gdma-nand)
  SOC := mt7620a
  IMAGE_SIZE := 124160k
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  DEVICE_VENDOR := HiWiFi
  DEVICE_MODEL := HC5861B (R33)
  SUPPORTED_DEVICES := hiwifi,hc5861b hiwifi,r33 hiwifi_hc5861b
  DEVICE_PACKAGES := kmod-mt76x2 kmod-usb2 kmod-usb-ohci kmod-switch-rtl8367b ubi-utils
  IMAGES := squashfs-factory.bin squashfs-sysupgrade.bin
  IMAGE/squashfs-factory.bin := append-kernel | pad-to 128k | append-ubi
  IMAGE/squashfs-sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += hiwifi_hc5861b
EOF

#!/bin/bash
#
# diy-part1.sh - OpenWrt 23.05 HiWiFi R33 (HC5861B) hardware patches
# Run BEFORE feeds update
# Applies all necessary patches to official OpenWrt 23.05 source
#

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
DEVICE_DIR="$SCRIPT_DIR/device-files"

echo "============================================"
echo " Applying HiWiFi R33 (C312B) patches"
echo " Target: OpenWrt 23.05 / Kernel 5.15"
echo "============================================"

# ============================================================
# 1. RTL8367B switch driver - add chip_ver 0x0020 support
# ============================================================
echo "[1/10] Patching RTL8367B switch driver..."

RTL8367B_FILE="target/linux/generic/files/drivers/net/phy/rtl8367b.c"

if [ -f "$RTL8367B_FILE" ]; then
    # Add global variable rtl_device_id
    sed -i '/#define RTL8367B_MIB_TXB_ID/a\\nu32 rtl_device_id;' "$RTL8367B_FILE"

    # Skip initvals for chip_ver 0x0020
    sed -i '/static int rtl8367b_write_initvals/,/int i;/{
        /int i;/a\\n\tif (rtl_device_id == 0x0020) \n\t{\n\t\treturn 0;\n\t}
    }' "$RTL8367B_FILE"

    # Add braces around REG_WR loop
    sed -i 's/^\(\t\)REG_WR(smi, initvals\[i\]\.reg, initvals\[i\]\.val);/\1{\n\t\tREG_WR(smi, initvals[i].reg, initvals[i].val);\n\t}/' "$RTL8367B_FILE"

    # Save chip_ver and add case 0x0020
    sed -i '/switch (chip_ver) {/{
        i\\trtl_device_id = chip_ver;\n
    }' "$RTL8367B_FILE"

    sed -i '/switch (chip_ver) {/a\\tcase 0x0020:' "$RTL8367B_FILE"

    echo "    RTL8367B driver patched successfully"
else
    echo "    WARNING: RTL8367B driver file not found!"
fi

# ============================================================
# 2. Device Tree Source (DTS)
# ============================================================
echo "[2/10] Installing DTS file..."

cp "$DEVICE_DIR/mt7620a_hiwifi_r33.dts" \
   "target/linux/ramips/dts/mt7620a_hiwifi_r33.dts"

echo "    DTS installed"

# ============================================================
# 3. Image build rules (mt7620.mk)
# ============================================================
echo "[3/10] Adding image build rules..."

cat >> target/linux/ramips/image/mt7620.mk << 'HIWIFI_R33_EOF'

define Device/hiwifi_r33
  SOC := mt7620a
  DEVICE_VENDOR := HiWiFi
  DEVICE_MODEL := R33
  DEVICE_PACKAGES := kmod-usb2 kmod-usb-ohci kmod-usb-ledtrig-usbport \
	kmod-switch-rtl8366-smi kmod-switch-rtl8367b kmod-mt76x2
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  KERNEL_SIZE := 4096k
  UBINIZE_OPTS := -E 5
  IMAGE_SIZE := 32768k
  IMAGES += kernel.bin rootfs.bin factory.bin
  IMAGE/kernel.bin := append-kernel | check-size $$$$(KERNEL_SIZE)
  IMAGE/rootfs.bin := append-ubi | check-size $$$$(IMAGE_SIZE)
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
  IMAGE/factory.bin := append-kernel | pad-to $$(KERNEL_SIZE) | append-ubi | \
	check-size
  SUPPORTED_DEVICES += r33
endef
TARGET_DEVICES += hiwifi_r33
HIWIFI_R33_EOF

echo "    Image build rules added"

# ============================================================
# 4. LED configuration (01_leds)
# ============================================================
echo "[4/10] Adding LED configuration..."

LEDS_FILE="target/linux/ramips/mt7620/base-files/etc/board.d/01_leds"

sed -i '/hiwifi,hc5861)/,/;;/{
    /;;/a\hiwifi,r33)\n\tucidef_set_led_switch "internet" "internet" "blue:internet" "switch1" "0x01"\n\t;;
}' "$LEDS_FILE"

echo "    LED configuration added"

# ============================================================
# 5. Network configuration (02_network)
# ============================================================
echo "[5/10] Adding network configuration..."

NETWORK_FILE="target/linux/ramips/mt7620/base-files/etc/board.d/02_network"

# Add switch configuration in ramips_setup_interfaces()
sed -i '/hiwifi,hc5861)/,/;;/{
    /;;/a\\thiwifi,r33)\n\t\tucidef_add_switch "switch0" \\\n\t\t\t"1:lan" "2:lan" "3:lan" "4:lan" "0:wan" "6@eth0"\n\t\tucidef_add_switch_attr "switch0" "enable" "false"\n\t\tucidef_add_switch "switch1" \\\n\t\t\t"1:lan" "2:lan" "0:wan" "6@eth0"\n\t\t;;
}' "$NETWORK_FILE"

# Add MAC address configuration in ramips_setup_macs()
sed -i '/hiwifi,hc5861)/,/wan_mac=.*lan_mac.*1)/{
    /wan_mac=.*lan_mac.*1)/a\\t;;\n\thiwifi,r33)\n\t\tlan_mac=$(mtd_get_mac_ascii bdinfo "Vfac_mac ")\n\t\tlabel_mac=$lan_mac\n\t\t[ -n "$lan_mac" ] || lan_mac=$(cat /sys/class/net/eth0/address)\n\t\twan_mac=$(macaddr_add "$lan_mac" 1)
}' "$NETWORK_FILE"

echo "    Network configuration added"

# ============================================================
# 6. WiFi MAC fix hotplug script
# ============================================================
echo "[6/10] Installing WiFi MAC fix script..."

HOTPLUG_DIR="target/linux/ramips/mt7620/base-files/etc/hotplug.d/ieee80211"
mkdir -p "$HOTPLUG_DIR"
cp "$DEVICE_DIR/10_fix_wifi_mac" "$HOTPLUG_DIR/10_fix_wifi_mac"

echo "    WiFi MAC fix script installed"

# ============================================================
# 7. Upgrade platform support
# ============================================================
echo "[7/10] Adding upgrade platform support..."

PLATFORM_FILE="target/linux/ramips/mt7620/base-files/lib/upgrade/platform.sh"

sed -i '/\*)/i\\thiwifi,r33)\n\t\tnand_do_upgrade "$1"\n\t\t;;' "$PLATFORM_FILE"

echo "    Upgrade platform support added"

# ============================================================
# 8. Kernel config for NAND/UBI/UBIFS (config-5.15)
# ============================================================
echo "[8/10] Adding kernel configuration..."

KCONFIG_FILE="target/linux/ramips/mt7620/config-5.15"

if [ -f "$KCONFIG_FILE" ]; then
    if ! grep -q "CONFIG_MTD_NAND_MT7620" "$KCONFIG_FILE"; then
        cat >> "$KCONFIG_FILE" << 'KCONFIG_EOF'
CONFIG_CRC16=y
CONFIG_CRYPTO_DEFLATE=y
CONFIG_CRYPTO_GF128MUL=y
CONFIG_CRYPTO_HASH_INFO=y
CONFIG_CRYPTO_LZO=y
CONFIG_LZO_COMPRESS=y
CONFIG_LZO_DECOMPRESS=y
CONFIG_MDIO_DEVRES=y
CONFIG_MTD_NAND_MT7620=y
CONFIG_MTD_UBI=y
CONFIG_MTD_UBI_BEB_LIMIT=20
CONFIG_MTD_UBI_BLOCK=y
CONFIG_MTD_UBI_WL_THRESHOLD=4096
CONFIG_MTD_VIRT_CONCAT=y
CONFIG_NVMEM=y
CONFIG_SGL_ALLOC=y
CONFIG_UBIFS_FS=y
CONFIG_UBIFS_FS_ADVANCED_COMPR=y
# CONFIG_UBIFS_FS_ZSTD is not set
CONFIG_ZLIB_DEFLATE=y
CONFIG_ZLIB_INFLATE=y
KCONFIG_EOF
        echo "    Kernel config updated"
    else
        echo "    Kernel config already present"
    fi
else
    echo "    WARNING: config-5.15 not found!"
fi

# ============================================================
# 9. Target features - add nand
# ============================================================
echo "[9/10] Adding NAND feature to target.mk..."

TARGET_MK="target/linux/ramips/mt7620/target.mk"

sed -i 's/FEATURES+=usb ramdisk/FEATURES+=usb nand ramdisk/' "$TARGET_MK"

echo "    NAND feature added"

# ============================================================
# 10. NAND driver - source files + kernel build config patch
# ============================================================
echo "[10/10] Installing NAND driver..."

# 10a. 复制NAND驱动源码到 files/
mkdir -p target/linux/ramips/files/drivers/mtd/maps/
cp "$DEVICE_DIR/kernel/ralink_nand.c" target/linux/ramips/files/drivers/mtd/maps/
cp "$DEVICE_DIR/kernel/ralink_nand.h" target/linux/ramips/files/drivers/mtd/maps/

# 10b. 安装 Kconfig/Makefile patch
mkdir -p target/linux/ramips/patches-5.15
cp "$DEVICE_DIR/patches/0038-mtd-ralink-add-mt7620-nand-kconfig.patch" \
   target/linux/ramips/patches-5.15/

# 10c. 清理可能存在的旧垃圾文件
rm -f target/linux/ramips/patches-5.15/9999-mtd-nand-mt7620-fallback.patch
rm -f target/linux/ramips/hack-5.15/999-fix-nand-kconfig.patch

echo "    NAND driver installed"
echo "      - files/drivers/mtd/maps/ralink_nand.c"
echo "      - files/drivers/mtd/maps/ralink_nand.h"  
echo "      - patches-5.15/0038-mtd-ralink-add-mt7620-nand-kconfig.patch"

# ============================================================
# 10. NAND driver - source files + kernel build config
# ============================================================
echo "[10/10] Installing NAND driver..."

# 10a. Copy NAND driver source files via OpenWrt files/ mechanism
#      These get copied into the kernel tree AFTER patches are applied
mkdir -p target/linux/ramips/files/drivers/mtd/maps/
cp "$DEVICE_DIR/kernel/ralink_nand.c" target/linux/ramips/files/drivers/mtd/maps/
cp "$DEVICE_DIR/kernel/ralink_nand.h" target/linux/ramips/files/drivers/mtd/maps/

# 10b. Install the small Kconfig/Makefile patch
#      This only adds the build system hooks (4+1 lines), NOT the source code
mkdir -p target/linux/ramips/patches-5.15
cp "$DEVICE_DIR/patches/0038-mtd-ralink-add-mt7620-nand-kconfig.patch" \
   target/linux/ramips/patches-5.15/

echo "    NAND driver installed (source via files/, config via patch)"

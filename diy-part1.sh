# ============================================================
# 8. Kernel config for NAND/UBI/UBIFS (config-5.15)
# ============================================================
echo "[8/10] Adding kernel configuration..."

KCONFIG_FILE="target/linux/ramips/mt7620/config-5.15"

if [ -f "$KCONFIG_FILE" ]; then
    grep -q "CONFIG_MTD_NAND_MT7620" "$KCONFIG_FILE" || cat >> "$KCONFIG_FILE" << 'KCONFIG_EOF'
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
CONFIG_SGL_ALLOC=y
CONFIG_UBIFS_FS=y
CONFIG_UBIFS_FS_ADVANCED_COMPR=y
# CONFIG_UBIFS_FS_ZSTD is not set
CONFIG_ZLIB_DEFLATE=y
CONFIG_ZLIB_INFLATE=y
KCONFIG_EOF
    echo "    Kernel config updated"
else
    echo "    WARNING: config-5.15 not found!"
fi

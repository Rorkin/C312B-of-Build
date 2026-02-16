#!/bin/bash
#
# diy-part2.sh - After Update feeds
#

# === 1. 修改默认 IP ===
sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate

# === 2. 去掉 geoview 依赖 ===
PW2_MK=$(find package feeds -name "Makefile" -path "*/luci-app-passwall2/*" 2>/dev/null | head -1)
if [ -n "$PW2_MK" ]; then
    sed -i 's/+geoview//g' "$PW2_MK"
    echo "=== Removed geoview dependency from: $PW2_MK ==="
    grep -i 'DEPENDS' "$PW2_MK" | head -5
fi

# === 3. 配置预编译包仓库作为后备 ===
mkdir -p files/etc/opkg
cat > files/etc/opkg/passwall-fallback.conf << 'OPKGEOF'
# PassWall2 预编译包后备仓库 (mipsel_24kc)
# 需要时取消注释，然后: opkg update && opkg install xray-core --force-reinstall
# src/gz passwall_packages https://sourceforge.net/projects/openwrt-passwall-build/files/releases/packages-23.05/mipsel_24kc/passwall_packages
OPKGEOF

echo "=== Fallback opkg feed configured ==="

# === 4. 验证关键包版本 ===
echo "=== Xray-core source version ==="
XRAY_MK=$(find feeds -name "Makefile" -path "*/xray-core/*" 2>/dev/null | head -1)
if [ -n "$XRAY_MK" ]; then
    grep 'PKG_VERSION' "$XRAY_MK" | head -1
else
    echo "WARNING: xray-core Makefile not found!"
fi

echo "=== Hysteria source version ==="
HY_MK=$(find feeds -name "Makefile" -path "*/hysteria/*" 2>/dev/null | head -1)
if [ -n "$HY_MK" ]; then
    grep 'PKG_VERSION' "$HY_MK" | head -1
else
    echo "WARNING: hysteria Makefile not found!"
fi

echo "=== diy-part2.sh completed ==="

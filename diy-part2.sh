#!/bin/bash
#
# diy-part2.sh - After Update feeds
#

# === 1. 修改默认 IP ===
sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate

# === 2. 去掉 geoview 依赖（需要较新Go，可能编译失败）===
PW2_MK=$(find package feeds -name "Makefile" -path "*/luci-app-passwall2/*" 2>/dev/null | head -1)
if [ -n "$PW2_MK" ]; then
    sed -i 's/+geoview//g' "$PW2_MK"
    echo "=== Removed geoview dependency from: $PW2_MK ==="
    grep -i 'DEPENDS' "$PW2_MK" | head -5
fi

# === 3. 不再手动修改 xray-core 版本！===
# 原因：
#   - 升级 Go 工具链后，feed 自带版本就能编译
#   - 手动改版本号容易与依赖不匹配
#   - Xray-core 不支持 Hysteria2，升级也没用

echo "=== diy-part2.sh completed ==="

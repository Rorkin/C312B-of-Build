#!/bin/bash
# 1. 修改默认 IP
sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate

# 2. 移除 geoview 依赖 (减少编译失败概率)
PW2_MK=$(find feeds/passwall2 -name "Makefile" | grep "luci-app-passwall2")
if [ -n "$PW2_MK" ]; then
    sed -i 's/+geoview//g' "$PW2_MK"
fi

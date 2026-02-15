#!/bin/bash
# 1. 修改默认 IP 为 192.168.10.1
sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate

# 2. 移除 geoview 依赖（防止编译失败）
PW2_MK=$(find feeds/passwall2 -name "Makefile" | grep "luci-app-passwall2")
if [ -n "$PW2_MK" ]; then
    sed -i 's/+geoview//g' "$PW2_MK"
fi

# 3. 核心修复：彻底删除基础版 dnsmasq 源码，强制系统只使用 dnsmasq-full
rm -rf package/network/services/dnsmasq

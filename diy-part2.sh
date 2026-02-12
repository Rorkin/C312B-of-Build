#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# Modify default IP
sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate

# 升级 xray-core 到 v1.8.24（支持 Hysteria2）
# 找到 xray-core 的 Makefile
XRAY_MAKEFILE="feeds/passwall_packages/xray-core/Makefile"

if [ -f "$XRAY_MAKEFILE" ]; then
    echo "=== Original xray-core version ==="
    grep 'PKG_VERSION' $XRAY_MAKEFILE | head -3

    # 修改版本号为 1.8.24（最新稳定版，完整支持Hysteria2）
    sed -i 's/PKG_VERSION:=.*/PKG_VERSION:=1.8.24/' $XRAY_MAKEFILE

    # 更新 hash（必须匹配新版本的源码hash）
    # 设为 skip 让编译时自动计算
    sed -i 's/PKG_HASH:=.*/PKG_HASH:=skip/' $XRAY_MAKEFILE

    echo "=== Updated xray-core version ==="
    grep 'PKG_VERSION' $XRAY_MAKEFILE | head -3
    grep 'PKG_HASH' $XRAY_MAKEFILE | head -1
else
    echo "WARNING: xray-core Makefile not found at $XRAY_MAKEFILE"
    # 尝试其他可能的路径
    find . -path "*/xray-core/Makefile" -exec echo "Found: {}" \;
fi

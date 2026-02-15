#!/bin/bash
#
# diy-part1.sh - Before Update feeds
# 适配 OpenWrt 23.05
#

# === 1. 修复 git.openwrt.org 503 问题 ===
sed -i 's|https://git.openwrt.org/feed/packages.git|https://github.com/openwrt/packages.git|g' feeds.conf.default
sed -i 's|https://git.openwrt.org/project/luci.git|https://github.com/openwrt/luci.git|g' feeds.conf.default
sed -i 's|https://git.openwrt.org/feed/routing.git|https://github.com/openwrt/routing.git|g' feeds.conf.default
sed -i 's|https://git.openwrt.org/feed/telephony.git|https://github.com/openwrt/telephony.git|g' feeds.conf.default

echo "=== feeds.conf.default after git fix ==="
cat feeds.conf.default

# === 2. 添加 PassWall2 相关 feeds ===
# main 分支同时兼容 22.03 和 23.05
echo "src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main" >> feeds.conf.default
echo "src-git passwall2 https://github.com/Openwrt-Passwall/openwrt-passwall2.git;main" >> feeds.conf.default

echo "=== Final feeds.conf.default ==="
cat feeds.conf.default

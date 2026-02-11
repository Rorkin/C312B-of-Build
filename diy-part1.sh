#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#

# 修复 git.openwrt.org 503 问题：替换为 GitHub 镜像
sed -i 's|https://git.openwrt.org/feed/packages.git|https://github.com/openwrt/packages.git|g' feeds.conf.default
sed -i 's|https://git.openwrt.org/project/luci.git|https://github.com/openwrt/luci.git|g' feeds.conf.default
sed -i 's|https://git.openwrt.org/feed/routing.git|https://github.com/openwrt/routing.git|g' feeds.conf.default
sed -i 's|https://git.openwrt.org/feed/telephony.git|https://github.com/openwrt/telephony.git|g' feeds.conf.default

echo "=== feeds.conf.default after fix ==="
cat feeds.conf.default

# 添加 passwall_packages feed
echo "src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main" >> feeds.conf.default

# passwall2 不走feed，直接克隆到package目录
git clone --depth 1 https://github.com/Openwrt-Passwall/openwrt-passwall2.git /tmp/passwall2
if [ -d "/tmp/passwall2/luci-app-passwall2" ]; then
    cp -r /tmp/passwall2/luci-app-passwall2 package/luci-app-passwall2
else
    cp -r /tmp/passwall2 package/luci-app-passwall2
fi
rm -rf /tmp/passwall2

# 关键修复：去掉 passwall2 Makefile 中对 geoview 的依赖
# geoview 需要新版Go，在22.03上无法编译
if [ -f "package/luci-app-passwall2/Makefile" ]; then
    sed -i 's/+geoview//g' package/luci-app-passwall2/Makefile
    sed -i 's/geoview//g' package/luci-app-passwall2/Makefile
    echo "=== Removed geoview dependency from passwall2 Makefile ==="
    grep -i 'DEPENDS' package/luci-app-passwall2/Makefile | head -5
fi

echo "=== luci-app-passwall2 installed ==="
ls package/luci-app-passwall2/

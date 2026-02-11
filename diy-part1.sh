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

# 只添加 passwall_packages feed（仓库结构正常，可走feed）
echo "src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main" >> feeds.conf.default

# passwall2 不走feed，直接克隆到package目录
# 因为仓库是子目录结构，feed系统无法解析
git clone --depth 1 https://github.com/Openwrt-Passwall/openwrt-passwall2.git /tmp/passwall2
if [ -d "/tmp/passwall2/luci-app-passwall2" ]; then
    cp -r /tmp/passwall2/luci-app-passwall2 package/luci-app-passwall2
else
    cp -r /tmp/passwall2 package/luci-app-passwall2
fi
rm -rf /tmp/passwall2
echo "=== luci-app-passwall2 installed ==="
ls package/luci-app-passwall2/

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

# Add passwall packages feed (这个仓库结构正常，可以用feed方式)
echo 'src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main' >>feeds.conf.default

# passwall2 不通过feed添加，通过手动克隆方式处理（因为仓库结构是子目录）
# 直接克隆到package目录下
git clone --depth 1 https://github.com/xiaorouji/openwrt-passwall2.git /tmp/passwall2
cp -r /tmp/passwall2/luci-app-passwall2 package/luci-app-passwall2
rm -rf /tmp/passwall2

echo "luci-app-passwall2 installed to package/luci-app-passwall2"
ls -la package/luci-app-passwall2/

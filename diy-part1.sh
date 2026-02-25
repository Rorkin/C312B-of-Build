#!/bin/bash

# 1. 替换所有核心 feed 源为 GitHub 镜像地址（解决官方 503 报错）
sed -i 's|https://git.openwrt.org/feed/packages.git|https://github.com/openwrt/packages.git|g' feeds.conf.default
sed -i 's|https://git.openwrt.org/project/luci.git|https://github.com/openwrt/luci.git|g' feeds.conf.default
sed -i 's|https://git.openwrt.org/feed/routing.git|https://github.com/openwrt/routing.git|g' feeds.conf.default
sed -i 's|https://git.openwrt.org/feed/telephony.git|https://github.com/openwrt/telephony.git|g' feeds.conf.default

# 2. 如果之前执行失败留下了残余文件夹，清理它们以防干扰（可选）
# rm -rf feeds/packages feeds/luci feeds/routing feeds/telephony

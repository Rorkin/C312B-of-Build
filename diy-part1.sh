#!/bin/bash
# 修复官方 feeds 镜像 (可选，若官方源慢可启用)
# sed -i 's|https://git.openwrt.org/feed/packages.git|https://github.com/openwrt/packages.git|g' feeds.conf.default

# 添加 PassWall2 依赖包仓库 (包含最新 xray, hysteria 等)
echo "src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main" >> feeds.conf.default

# 添加 PassWall2 LuCI 仓库
echo "src-git passwall2 https://github.com/Openwrt-Passwall/openwrt-passwall2.git;main" >> feeds.conf.default

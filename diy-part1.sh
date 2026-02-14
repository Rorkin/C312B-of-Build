#!/bin/bash
# 添加 PassWall2 核心组件仓库
echo "src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main" >> feeds.conf.default
# 添加 PassWall2 LuCI 界面仓库
echo "src-git passwall2 https://github.com/Openwrt-Passwall/openwrt-passwall2.git;main" >> feeds.conf.default

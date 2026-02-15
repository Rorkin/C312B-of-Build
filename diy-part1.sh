#!/bin/bash
# 添加 PassWall2 及其核心依赖包仓库 [cite: 841, 843]
echo "src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main" >> feeds.conf.default
echo "src-git passwall2 https://github.com/Openwrt-Passwall/openwrt-passwall2.git;main" >> feeds.conf.default

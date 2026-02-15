#!/bin/bash

# 1. 强制重写 feeds.conf.default 确保分支匹配
cat > feeds.conf.default <<EOF
src-git packages https://github.com/openwrt/packages.git;openwrt-23.05
src-git luci https://github.com/openwrt/luci.git;openwrt-23.05
src-git routing https://github.com/openwrt/routing.git;openwrt-23.05
src-git telephony https://github.com/openwrt/telephony.git;openwrt-23.05
EOF

# 2. 添加 PassWall2 及其核心依赖包仓库 [cite: 841, 843]
echo "src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main" >> feeds.conf.default
echo "src-git passwall2 https://github.com/Openwrt-Passwall/openwrt-passwall2.git;main" >> feeds.conf.default

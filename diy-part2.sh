#!/bin/bash

# 1. 修改默认 IP 为 192.168.10.1
sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate

# 2. 【关键步骤】将你仓库里的自定义 DTS 注入到源码中
# $GITHUB_WORKSPACE 是你的仓库路径，openwrt/ 是源码下载后的路径
cp -f $GITHUB_WORKSPACE/custom_files/mt7620a_hiwifi_hc5861b.dts target/linux/ramips/dts/mt7620a_hiwifi_hc5861b.dts

# 3. 确保 23.05 的 Makefile 能够识别该设备（如果名称有出入，这里可以修正）
# 极路由 3 Pro 在 23.05 官方源码中对应的 ID 就是 hiwifi_hc5861b，所以直接覆盖即可。

echo "硬件适配补丁已成功注入！"
sed -i '/DEVICE_PACKAGES :=/ s/$/ kmod-switch-rtl8367b/' target/linux/ramips/image/mt7620.mk

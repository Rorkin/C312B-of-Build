#!/bin/bash

# 1. 修改默认管理 IP 为 192.168.10.1
sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate

# 2. 注入硬件适配 DTS 文件
# 将 custom_files 目录下的 DTS 复制到源码对应位置，替换官方通用文件
if [ -d "$GITHUB_WORKSPACE/custom_files" ]; then
    cp -f $GITHUB_WORKSPACE/custom_files/mt7620a_hiwifi_hc5861b.dts target/linux/ramips/dts/mt7620a_hiwifi_hc5861b.dts
    echo "DTS 硬件补丁注入成功！"
fi

# 3. 修正设备 Makefile，确保包含 RTL8367RB 交换机驱动和必要的内核模块
# 23.05 编译时需要明确定义该设备的包依赖，否则 LAN 口可能无法识别
DEVICE_MAKEFILE="target/linux/ramips/image/mt7620.mk"
if [ -f "$DEVICE_MAKEFILE" ]; then
    # 确保 hiwifi_hc5861b 设备条目中包含 kmod-switch-rtl8367b
    sed -i '/DEVICE_TITLE := HiWiFi HC5861B/,/IMAGE_SIZE/ s/DEVICE_PACKAGES := .*/DEVICE_PACKAGES := kmod-mt76x2 kmod-usb2 kmod-usb-ohci kmod-ledtrig-usbport kmod-switch-rtl8367b/' $DEVICE_MAKEFILE
    echo "Makefile 驱动依赖修正完成！"
fi

# 4. 修改 banner 显示自定义信息（可选）
sed -i "s/OpenWrt /C312B-Pure-Build /g" package/base-files/files/etc/banner

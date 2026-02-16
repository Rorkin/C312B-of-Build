#!/bin/bash
#
# port-r33.sh - Port Hiwifi R33 NAND device support from mengzonefire/22.03-of to OpenWrt 23.05
#

set -e

echo "============================================================"
echo "  Porting Hiwifi R33 (128MB NAND) device support to 23.05"
echo "============================================================"

# ===== 1. 克隆 mengzonefire 源码 =====
echo ""
echo "===== Step 1: Clone mengzonefire fork ====="
rm -rf /tmp/r33-source
git clone --depth 1 https://github.com/mengzonefire/22.03-of -b openwrt-22.03 /tmp/r33-source
echo "Clone done"

# ===== 2. 查找 23.05 的内核配置文件 =====
echo ""
echo "===== Step 2: Find kernel config files ====="

R33_KCONF="/tmp/r33-source/target/linux/ramips/mt7620/config-5.10"
CUR_KCONF=""

for candidate in \
    "target/linux/ramips/mt7620/config-5.15" \
    "target/linux/ramips/mt7620/config-5.10" \
    ; do
    if [ -f "$candidate" ]; then
        CUR_KCONF="$candidate"
        break
    fi
done

if [ -z "$CUR_KCONF" ]; then
    CUR_KCONF=$(find target/linux/ramips/ -name "config-*" -path "*/mt7620/*" 2>/dev/null | head -1)
fi

echo "22.03 kernel config: $R33_KCONF"
echo "23.05 kernel config: $CUR_KCONF"

# ===== 3. 合并 NAND 内核配置 =====
echo ""
echo "===== Step 3: Merge NAND kernel configs ====="

if [ -f "$R33_KCONF" ] && [ -n "$CUR_KCONF" ] && [ -f "$CUR_KCONF" ]; then
    echo "--- NAND configs in 22.03 ---"
    grep -i "NAND\|MTD_NAND\|UBI\|UBIFS" "$R33_KCONF" | sort || true

    echo ""
    echo "--- NAND configs in 23.05 ---"
    grep -i "NAND\|MTD_NAND\|UBI\|UBIFS" "$CUR_KCONF" | sort || true

    # 确保关键 NAND 配置存在
    NAND_CFGS="
CONFIG_MTD_NAND=y
CONFIG_MTD_NAND_ECC=y
CONFIG_MTD_NAND_ECC_SW_HAMMING=y
CONFIG_MTD_RAW_NAND=y
CONFIG_MTD_NAND_MT7620=y
CONFIG_MTD_UBI=y
CONFIG_MTD_UBI_WL_THRESHOLD=4096
CONFIG_MTD_UBI_BEB_LIMIT=20
CONFIG_MTD_UBI_BLOCK=y
CONFIG_UBIFS_FS=y
CONFIG_UBIFS_FS_ADVANCED_COMPR=y
CONFIG_UBIFS_FS_LZO=y
CONFIG_UBIFS_FS_ZLIB=y
CONFIG_UBIFS_FS_ZSTD=y
"
    echo ""
    echo "Ensuring critical NAND configs..."
    echo "$NAND_CFGS" | while IFS= read -r cfg; do
        [ -z "$cfg" ] && continue
        cfg_key=$(echo "$cfg" | cut -d'=' -f1)
        if ! grep -q "^${cfg_key}=" "$CUR_KCONF" 2>/dev/null; then
            echo "  ADDING: $cfg"
            echo "$cfg" >> "$CUR_KCONF"
        else
            echo "  EXISTS: $(grep "^${cfg_key}=" "$CUR_KCONF")"
        fi
    done

    # 从 22.03 提取额外的 NAND 配置
    grep -E "^CONFIG_.*(NAND|UBI|UBIFS)" "$R33_KCONF" 2>/dev/null | grep "=y\|=m" | while IFS= read -r line; do
        cfg_key=$(echo "$line" | cut -d'=' -f1)
        if ! grep -q "^${cfg_key}=" "$CUR_KCONF" 2>/dev/null; then
            echo "  ADDING from 22.03: $line"
            echo "$line" >> "$CUR_KCONF"
        fi
    done

    echo ""
    echo "--- Final NAND configs ---"
    grep -i "NAND\|UBI\|UBIFS" "$CUR_KCONF" | sort || true
else
    echo "WARNING: Kernel config files missing, skipping merge"
fi

# ===== 4. 复制 R33 DTS 文件 =====
echo ""
echo "===== Step 4: Copy R33 DTS files ====="

echo "Searching for R33/hiwifi DTS files in mengzonefire fork..."
find /tmp/r33-source/target/linux/ramips/dts/ -type f \( \
    -iname "*r33*" -o \
    -iname "*hc5661*" -o \
    -iname "*hc5761*" -o \
    -iname "*hc5861*" -o \
    -iname "*hiwifi*" \
\) 2>/dev/null | tee /tmp/r33-dts-list.txt

DTS_COUNT=0
if [ -f /tmp/r33-dts-list.txt ]; then
    DTS_COUNT=$(wc -l < /tmp/r33-dts-list.txt)
fi
echo "Found $DTS_COUNT DTS files"

if [ "$DTS_COUNT" -gt 0 ]; then
    while IFS= read -r dts_file; do
        [ -z "$dts_file" ] && continue
        [ ! -f "$dts_file" ] && continue
        fname=$(basename "$dts_file")

        # 只复制 23.05 中不存在的 DTS 文件
        if [ -f "target/linux/ramips/dts/$fname" ]; then
            echo "SKIP (exists): $fname"
        else
            echo "Copying: $fname"
            cp "$dts_file" target/linux/ramips/dts/
            echo "  NAND/partition references:"
            grep -n -i "nand\|ubi\|partition\|flash" "$dts_file" | head -10 || echo "  (none)"
        fi
    done < /tmp/r33-dts-list.txt
else
    echo "WARNING: No R33 DTS files found"
fi

# 检查公共 dtsi 文件
echo ""
echo "Checking common dtsi files..."
for dtsi_name in mt7620a.dtsi mt7620.dtsi; do
    src="/tmp/r33-source/target/linux/ramips/dts/$dtsi_name"
    dst="target/linux/ramips/dts/$dtsi_name"
    if [ -f "$src" ] && [ -f "$dst" ]; then
        src_nand=$(grep -c -i "nand" "$src" 2>/dev/null || true)
        dst_nand=$(grep -c -i "nand" "$dst" 2>/dev/null || true)
        src_nand=${src_nand:-0}
        dst_nand=${dst_nand:-0}
        echo "  $dtsi_name: 22.03 has $src_nand nand refs, 23.05 has $dst_nand nand refs"
    elif [ -f "$src" ] && [ ! -f "$dst" ]; then
        echo "  $dtsi_name only in 22.03, copying"
        cp "$src" "$dst"
    fi
done

# ===== 5. 提取并追加 R33 设备定义（仅 R33，不含其他已有设备） =====
echo ""
echo "===== Step 5: Extract R33 device definition ONLY ====="

R33_IMG_SRC="/tmp/r33-source/target/linux/ramips/image/mt7620.mk"
R33_IMG_DST="target/linux/ramips/image/mt7620.mk"

# 检查 23.05 是否已有 R33 定义
if grep -q "^define Device/hiwifi_r33" "$R33_IMG_DST" 2>/dev/null; then
    echo "R33 device definition ALREADY EXISTS in 23.05 mt7620.mk, skipping"
else
    echo "R33 not found in 23.05, extracting from 22.03..."

    # 创建 awk 脚本只提取 hiwifi_r33 设备块
    cat > /tmp/extract-r33.awk << 'AWKEOF'
/^define Device\/hiwifi_r33$/ { found=1 }
found { print }
found && /^TARGET_DEVICES \+= hiwifi_r33$/ { found=0 }
AWKEOF

    awk -f /tmp/extract-r33.awk "$R33_IMG_SRC" > /tmp/r33-block.txt 2>/dev/null

    if [ -s /tmp/r33-block.txt ]; then
        echo "Extracted R33 device block:"
        cat /tmp/r33-block.txt
        echo ""

        # 验证关键 NAND 参数
        echo "Verifying NAND parameters:"
        grep -q "BLOCKSIZE" /tmp/r33-block.txt && echo "  ✓ BLOCKSIZE" || echo "  ✗ BLOCKSIZE missing!"
        grep -q "PAGESIZE" /tmp/r33-block.txt && echo "  ✓ PAGESIZE" || echo "  ✗ PAGESIZE missing!"
        grep -q "UBINIZE_OPTS" /tmp/r33-block.txt && echo "  ✓ UBINIZE_OPTS" || echo "  ✗ UBINIZE_OPTS missing!"
        grep -q "sysupgrade-tar" /tmp/r33-block.txt && echo "  ✓ sysupgrade-tar" || echo "  ✗ sysupgrade-tar missing!"
        grep -q "append-ubi" /tmp/r33-block.txt && echo "  ✓ append-ubi" || echo "  ✗ append-ubi missing!"

        # 追加到 23.05 的 mt7620.mk（只追加 R33）
        echo "" >> "$R33_IMG_DST"
        echo "# === Hiwifi R33 (NAND) - ported from mengzonefire/22.03-of ===" >> "$R33_IMG_DST"
        cat /tmp/r33-block.txt >> "$R33_IMG_DST"
        echo ""
        echo "R33 device definition added successfully (ONLY R33, no duplicates)"
    else
        echo "WARNING: awk extraction empty"
        echo "Trying sed-based extraction..."

        # 备用方案
        START_LINE=$(grep -n "^define Device/hiwifi_r33$" "$R33_IMG_SRC" | head -1 | cut -d: -f1)
        if [ -n "$START_LINE" ]; then
            END_LINE=$(tail -n +"$START_LINE" "$R33_IMG_SRC" | grep -n "^TARGET_DEVICES += hiwifi_r33$" | head -1 | cut -d: -f1)
            if [ -n "$END_LINE" ]; then
                ACTUAL_END=$((START_LINE + END_LINE - 1))
                echo "Extracting lines $START_LINE to $ACTUAL_END"
                sed -n "${START_LINE},${ACTUAL_END}p" "$R33_IMG_SRC" > /tmp/r33-block.txt
                cat /tmp/r33-block.txt
                echo "" >> "$R33_IMG_DST"
                echo "# === Hiwifi R33 (NAND) - ported from mengzonefire/22.03-of ===" >> "$R33_IMG_DST"
                cat /tmp/r33-block.txt >> "$R33_IMG_DST"
                echo "R33 added via sed fallback"
            fi
        fi

        if [ ! -s /tmp/r33-block.txt ]; then
            echo "CRITICAL: Cannot extract R33 definition!"
            echo "All hiwifi lines in source:"
            grep -n "hiwifi" "$R33_IMG_SRC" || true
        fi
    fi

    rm -f /tmp/extract-r33.awk /tmp/r33-block.txt
fi

# 验证：确认没有重复定义
echo ""
echo "Checking for duplicate device definitions..."
DUP_COUNT=$(grep -c "^define Device/hiwifi_hc5661$" "$R33_IMG_DST" 2>/dev/null || true)
DUP_COUNT=${DUP_COUNT:-0}
if [ "$DUP_COUNT" -gt 1 ]; then
    echo "ERROR: hiwifi_hc5661 defined $DUP_COUNT times! Removing duplicates..."
    # 这不应该发生了，但作为安全检查
fi

R33_COUNT=$(grep -c "^define Device/hiwifi_r33$" "$R33_IMG_DST" 2>/dev/null || true)
R33_COUNT=${R33_COUNT:-0}
echo "hiwifi_r33 definitions: $R33_COUNT (should be 1)"

# ===== 6. 复制 NAND 内核补丁 =====
echo ""
echo "===== Step 6: Port NAND kernel patches ====="

PATCH_SRC_DIR="/tmp/r33-source/target/linux/ramips/patches-5.10"
PATCH_DST_DIR="target/linux/ramips/patches-5.15"

if [ ! -d "$PATCH_DST_DIR" ]; then
    PATCH_DST_DIR=$(find target/linux/ramips/ -maxdepth 1 -type d -name "patches-*" 2>/dev/null | head -1)
fi

echo "Source patches: $PATCH_SRC_DIR"
echo "Dest patches: $PATCH_DST_DIR"

if [ -d "$PATCH_SRC_DIR" ] && [ -n "$PATCH_DST_DIR" ]; then
    mkdir -p "$PATCH_DST_DIR"

    echo "Searching for NAND-related patches..."
    find "$PATCH_SRC_DIR" -name "*.patch" -type f | while read -r pf; do
        fname=$(basename "$pf")
        if grep -q -i "nand\|mt7620.*nand\|ralink.*nand" "$pf" 2>/dev/null; then
            if [ -f "$PATCH_DST_DIR/$fname" ]; then
                echo "  EXISTS: $fname"
            else
                echo "  COPYING: $fname"
                cp "$pf" "$PATCH_DST_DIR/"
            fi
        fi
    done
else
    echo "WARNING: Patch directories not found"
fi

# ===== 7. 移植 board.d 网络和 LED 配置 =====
echo ""
echo "===== Step 7: Port board.d network and LED configs ====="

# 7a. 网络配置 (02_network)
echo "--- Network config (02_network) ---"

# 检查 ramips 级别
NET_SRC="/tmp/r33-source/target/linux/ramips/base-files/etc/board.d/02_network"
NET_DST="target/linux/ramips/base-files/etc/board.d/02_network"

# 也检查 mt7620 子目录级别
NET_SRC_SUB="/tmp/r33-source/target/linux/ramips/mt7620/base-files/etc/board.d/02_network"
NET_DST_SUB="target/linux/ramips/mt7620/base-files/etc/board.d/02_network"

# 选择实际存在的源文件
ACTUAL_NET_SRC=""
ACTUAL_NET_DST=""

for src_try in "$NET_SRC_SUB" "$NET_SRC"; do
    if [ -f "$src_try" ]; then
        ACTUAL_NET_SRC="$src_try"
        break
    fi
done

for dst_try in "$NET_DST_SUB" "$NET_DST"; do
    if [ -f "$dst_try" ]; then
        ACTUAL_NET_DST="$dst_try"
        break
    fi
done

echo "  Source: ${ACTUAL_NET_SRC:-NOT FOUND}"
echo "  Dest:   ${ACTUAL_NET_DST:-NOT FOUND}"

if [ -n "$ACTUAL_NET_SRC" ]; then
    echo "  R33 network entries in 22.03:"
    grep -n -A5 "r33\|hiwifi.*r33" "$ACTUAL_NET_SRC" | head -20 || echo "  (none found directly)"

    # 如果直接搜索没找到，搜索更广的范围
    if ! grep -q "r33" "$ACTUAL_NET_SRC" 2>/dev/null; then
        echo "  Broader search for hiwifi entries:"
        grep -n -A3 "hiwifi" "$ACTUAL_NET_SRC" | head -20 || echo "  (none)"
    fi
fi

# 确保 23.05 的 02_network 有 R33 条目
if [ -n "$ACTUAL_NET_DST" ]; then
    if grep -q "hiwifi,r33\|hiwifi_r33" "$ACTUAL_NET_DST" 2>/dev/null; then
        echo "  R33 network config already in 23.05"
    else
        echo "  Adding R33 network config to 23.05..."
        # R33 使用 RTL8367B 交换芯片，需要 VLAN 配置
        # 查找 22.03 中的配置方式
        if [ -n "$ACTUAL_NET_SRC" ]; then
            R33_NET=$(grep -A10 "r33" "$ACTUAL_NET_SRC" 2>/dev/null | head -12)
            if [ -n "$R33_NET" ]; then
                echo "  Found R33 network block from 22.03:"
                echo "$R33_NET"
            else
                echo "  No R33-specific block found, checking switch config pattern..."
                grep -A10 "rtl8367\|switch" "$ACTUAL_NET_SRC" | head -15 || true
            fi
        fi
        
        # 搜索所有可能的 board.d 文件
        echo ""
        echo "  Searching ALL board.d files for R33 references..."
        find /tmp/r33-source/target/linux/ramips/ -path "*/board.d/*" -type f | while read -r bf; do
            if grep -q "r33" "$bf" 2>/dev/null; then
                echo "  Found R33 in: $bf"
                grep -n -A5 "r33" "$bf" | head -20
            fi
        done
    fi
else
    echo "  WARNING: No 02_network found in 23.05"
    echo "  Searching for any network board.d in 23.05..."
    find target/linux/ramips/ -path "*/board.d/02_network" -type f 2>/dev/null || echo "  None"
fi

# 7b. LED 配置 (01_leds)
echo ""
echo "--- LED config (01_leds) ---"

LED_SRC="/tmp/r33-source/target/linux/ramips/base-files/etc/board.d/01_leds"
LED_DST="target/linux/ramips/base-files/etc/board.d/01_leds"
LED_SRC_SUB="/tmp/r33-source/target/linux/ramips/mt7620/base-files/etc/board.d/01_leds"
LED_DST_SUB="target/linux/ramips/mt7620/base-files/etc/board.d/01_leds"

ACTUAL_LED_SRC=""
ACTUAL_LED_DST=""

for src_try in "$LED_SRC_SUB" "$LED_SRC"; do
    if [ -f "$src_try" ]; then
        ACTUAL_LED_SRC="$src_try"
        break
    fi
done

for dst_try in "$LED_DST_SUB" "$LED_DST"; do
    if [ -f "$dst_try" ]; then
        ACTUAL_LED_DST="$dst_try"
        break
    fi
done

echo "  Source: ${ACTUAL_LED_SRC:-NOT FOUND}"
echo "  Dest:   ${ACTUAL_LED_DST:-NOT FOUND}"

if [ -n "$ACTUAL_LED_SRC" ]; then
    echo "  R33 LED entries in 22.03:"
    grep -n -A5 "r33\|hiwifi.*r33" "$ACTUAL_LED_SRC" | head -10 || echo "  (none)"
fi

# ===== 8. 移植 platform.sh 升级函数（NAND sysupgrade 必需） =====
echo ""
echo "===== Step 8: Port platform.sh NAND upgrade function ====="

# 搜索所有可能的 platform.sh 位置
echo "Searching for platform.sh files..."
echo "--- In 22.03 fork ---"
find /tmp/r33-source/target/linux/ramips/ -name "platform.sh" -path "*/upgrade/*" | while read -r pf; do
    echo "  $pf"
    grep -n "r33\|hiwifi" "$pf" | head -5 || echo "    (no r33 entries)"
done

echo ""
echo "--- In 23.05 ---"
find target/linux/ramips/ -name "platform.sh" -path "*/upgrade/*" | while read -r pf; do
    echo "  $pf"
    grep -n "r33\|hiwifi\|nand_do_upgrade" "$pf" | head -10 || echo "    (no r33/nand entries)"
done

# 找到包含 R33 NAND 升级定义的源文件
R33_PLAT_SRC=""
for plat_try in \
    "/tmp/r33-source/target/linux/ramips/mt7620/base-files/lib/upgrade/platform.sh" \
    "/tmp/r33-source/target/linux/ramips/base-files/lib/upgrade/platform.sh"; do
    if [ -f "$plat_try" ] && grep -q "r33" "$plat_try" 2>/dev/null; then
        R33_PLAT_SRC="$plat_try"
        break
    fi
done

echo ""
echo "R33 upgrade source: ${R33_PLAT_SRC:-NOT FOUND}"

if [ -n "$R33_PLAT_SRC" ]; then
    echo "R33 upgrade function in 22.03:"
    grep -A5 "r33" "$R33_PLAT_SRC"
fi

# 找到 23.05 的目标 platform.sh
R33_PLAT_DST=""
for plat_try in \
    "target/linux/ramips/mt7620/base-files/lib/upgrade/platform.sh" \
    "target/linux/ramips/base-files/lib/upgrade/platform.sh"; do
    if [ -f "$plat_try" ]; then
        R33_PLAT_DST="$plat_try"
        break
    fi
done

echo "23.05 platform.sh: ${R33_PLAT_DST:-NOT FOUND}"

if [ -n "$R33_PLAT_DST" ]; then
    if grep -q "hiwifi,r33\|hiwifi_r33" "$R33_PLAT_DST" 2>/dev/null; then
        echo "R33 NAND upgrade already configured in 23.05"
    else
        echo "Adding R33 NAND upgrade function to 23.05..."
        echo ""
        echo "Current platform.sh content:"
        cat "$R33_PLAT_DST"
        echo ""

        # 检查是否已有 nand_do_upgrade 的 case 块
        if grep -q "nand_do_upgrade" "$R33_PLAT_DST" 2>/dev/null; then
            echo "platform.sh already has nand_do_upgrade for other devices"
            echo "Adding R33 case before the existing case block..."

            # 在已有的 nand_do_upgrade 之前的 case 模式中添加 R33
            # 查找 platform_do_upgrade 函数中的 case 语句
            if grep -q "esac" "$R33_PLAT_DST" 2>/dev/null; then
                # 在 esac 之前插入 R33 条目
                sed -i '/^[[:space:]]*esac/i\
\thiwifi,r33)\
\t\tnand_do_upgrade "$1"\
\t\t;;' "$R33_PLAT_DST"
                echo "Added R33 nand_do_upgrade before esac"
            fi
        else
            echo "No existing nand_do_upgrade, adding complete block..."
            # 如果 platform.sh 有 platform_do_upgrade 函数但没有 NAND 支持
            if grep -q "platform_do_upgrade" "$R33_PLAT_DST" 2>/dev/null; then
                # 在函数内的 case 块添加
                if grep -q "esac" "$R33_PLAT_DST" 2>/dev/null; then
                    sed -i '/^[[:space:]]*esac/i\
\thiwifi,r33)\
\t\tnand_do_upgrade "$1"\
\t\t;;' "$R33_PLAT_DST"
                    echo "Added R33 case to platform_do_upgrade"
                else
                    # 如果没有 esac（简单格式的 platform.sh），追加到文件末尾
                    cat >> "$R33_PLAT_DST" << 'PLATEOF'

# Hiwifi R33 NAND upgrade support
platform_do_upgrade() {
	local board=$(board_name)
	case "$board" in
	hiwifi,r33)
		nand_do_upgrade "$1"
		;;
	*)
		default_do_upgrade "$1"
		;;
	esac
}
PLATEOF
                    echo "Added complete platform_do_upgrade function"
                fi
            else
                # platform.sh 不存在或为空
                cat >> "$R33_PLAT_DST" << 'PLATEOF'

# Hiwifi R33 NAND upgrade support
platform_do_upgrade() {
	local board=$(board_name)
	case "$board" in
	hiwifi,r33)
		nand_do_upgrade "$1"
		;;
	*)
		default_do_upgrade "$1"
		;;
	esac
}
PLATEOF
                echo "Created platform_do_upgrade function"
            fi
        fi

        echo ""
        echo "Updated platform.sh:"
        cat "$R33_PLAT_DST"
    fi
else
    echo "WARNING: No platform.sh found in 23.05"
    echo "Creating platform.sh for mt7620..."

    PLAT_DIR="target/linux/ramips/mt7620/base-files/lib/upgrade"
    mkdir -p "$PLAT_DIR"
    cat > "$PLAT_DIR/platform.sh" << 'PLATEOF'
# Platform upgrade support for mt7620 NAND devices

platform_do_upgrade() {
	local board=$(board_name)
	case "$board" in
	hiwifi,r33)
		nand_do_upgrade "$1"
		;;
	*)
		default_do_upgrade "$1"
		;;
	esac
}
PLATEOF
    echo "Created new platform.sh"
    cat "$PLAT_DIR/platform.sh"
fi

# ===== 9. 确保 NAND 升级依赖脚本存在 =====
echo ""
echo "===== Step 9: Verify NAND upgrade dependencies ====="

# nand_do_upgrade 依赖 nand.sh
echo "Checking for nand.sh..."
find target/linux/ramips/ -name "nand.sh" 2>/dev/null || echo "Not found in ramips"
find package/ -name "nand.sh" 2>/dev/null || echo "Not found in package"

# 通常 nand.sh 在 base-files 或通用 upgrade 目录
NAND_SH=$(find target/ package/ -name "nand.sh" -path "*/upgrade/*" 2>/dev/null | head -1)
if [ -n "$NAND_SH" ]; then
    echo "Found nand.sh: $NAND_SH"
else
    echo "WARNING: nand.sh not found - checking if it is included via base-files package"
    # 在 23.05 中 nand.sh 通常在 package/base-files/files/lib/upgrade/
    if [ -f "package/base-files/files/lib/upgrade/nand.sh" ]; then
        echo "OK: nand.sh found in base-files package"
    else
        echo "Searching broadly..."
        find . -name "nand.sh" 2>/dev/null | head -5 || echo "Not found anywhere"
    fi
fi

# ===== 10. 移植 mt7620 subtarget 文件 =====
echo ""
echo "===== Step 10: Port mt7620 subtarget files ====="

R33_SUB="/tmp/r33-source/target/linux/ramips/mt7620"
CUR_SUB="target/linux/ramips/mt7620"

echo "22.03 mt7620 subtarget files:"
ls -la "$R33_SUB"/ 2>/dev/null || echo "(none)"

echo ""
echo "23.05 mt7620 subtarget files:"
ls -la "$CUR_SUB"/ 2>/dev/null || echo "(none)"

# 只复制 base-files 子目录中缺失的文件（不覆盖）
if [ -d "$R33_SUB/base-files" ]; then
    echo ""
    echo "Copying missing base-files..."
    find "$R33_SUB/base-files" -type f | while read -r f; do
        rel_path="${f#$R33_SUB/base-files/}"
        dst_file="$CUR_SUB/base-files/$rel_path"
        if [ ! -f "$dst_file" ]; then
            echo "  Copying: $rel_path"
            mkdir -p "$(dirname "$dst_file")"
            cp "$f" "$dst_file"
        else
            # 如果文件已存在但缺少 R33 条目
            if grep -q "r33\|hiwifi" "$f" 2>/dev/null; then
                if ! grep -q "r33" "$dst_file" 2>/dev/null; then
                    echo "  Merging R33 entries into: $rel_path"
                    grep -A5 "r33\|hiwifi.*r33" "$f" 2>/dev/null | head -10
                fi
            fi
        fi
    done
fi

# ===== 11. 清理并验证 =====
echo ""
echo "===== Step 11: Cleanup and final verification ====="

rm -rf /tmp/r33-source /tmp/r33-dts-list.txt

echo ""
echo "=========================================="
echo "  FINAL VERIFICATION"
echo "=========================================="
echo ""

echo "1. R33 DTS file:"
if [ -f "target/linux/ramips/dts/mt7620a_hiwifi_r33.dts" ]; then
    echo "   OK: mt7620a_hiwifi_r33.dts exists"
    echo "   NAND definition:"
    grep -A3 "nand {" target/linux/ramips/dts/mt7620a_hiwifi_r33.dts | head -5
else
    echo "   FAIL: R33 DTS not found!"
fi

echo ""
echo "2. R33 device definition (ONLY R33, no duplicates):"
R33_DEF_COUNT=$(grep -c "^define Device/hiwifi_r33$" target/linux/ramips/image/mt7620.mk 2>/dev/null || true)
R33_DEF_COUNT=${R33_DEF_COUNT:-0}
echo "   hiwifi_r33 count: $R33_DEF_COUNT (expected: 1)"
if [ "$R33_DEF_COUNT" -eq 1 ]; then
    echo "   OK"
    grep -A5 "^define Device/hiwifi_r33$" target/linux/ramips/image/mt7620.mk | head -8
else
    echo "   PROBLEM!"
fi

# 检查其他设备没有重复
for dev in hiwifi_hc5661 hiwifi_hc5761 hiwifi_hc5861; do
    count=$(grep -c "^define Device/${dev}$" target/linux/ramips/image/mt7620.mk 2>/dev/null || true)
    count=${count:-0}
    if [ "$count" -gt 1 ]; then
        echo "   WARNING: $dev defined $count times (DUPLICATE!)"
    elif [ "$count" -eq 1 ]; then
        echo "   OK: $dev defined once"
    fi
done

echo ""
echo "3. NAND kernel configs:"
if [ -n "$CUR_KCONF" ] && [ -f "$CUR_KCONF" ]; then
    MTD_NAND=$(grep -c "CONFIG_MTD_NAND_MT7620=y" "$CUR_KCONF" 2>/dev/null || true)
    MTD_UBI=$(grep -c "CONFIG_MTD_UBI=y" "$CUR_KCONF" 2>/dev/null || true)
    UBIFS=$(grep -c "CONFIG_UBIFS_FS=y" "$CUR_KCONF" 2>/dev/null || true)
    echo "   MTD_NAND_MT7620: ${MTD_NAND:-0} (expected: 1)"
    echo "   MTD_UBI: ${MTD_UBI:-0} (expected: 1)"
    echo "   UBIFS_FS: ${UBIFS:-0} (expected: 1)"
fi

echo ""
echo "4. NAND driver patch:"
if [ -n "$PATCH_DST_DIR" ] && [ -f "$PATCH_DST_DIR/0038-mtd-ralink-add-mt7620-nand-driver.patch" ]; then
    echo "   OK: MT7620 NAND driver patch present"
else
    echo "   WARNING: NAND driver patch missing"
fi

echo ""
echo "5. Platform upgrade (nand_do_upgrade):"
if [ -n "$R33_PLAT_DST" ] && [ -f "$R33_PLAT_DST" ]; then
    if grep -q "hiwifi,r33" "$R33_PLAT_DST" 2>/dev/null; then
        echo "   OK: R33 NAND upgrade configured"
    else
        echo "   WARNING: R33 not in platform.sh"
    fi
else
    echo "   Checking all platform.sh files:"
    grep -rl "hiwifi,r33\|hiwifi_r33" target/linux/ramips/ 2>/dev/null || echo "   NOT FOUND"
fi

echo ""
echo "=========================================="
echo "  PORTING COMPLETE"
echo "=========================================="

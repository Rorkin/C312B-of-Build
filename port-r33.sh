#!/bin/bash
#
# port-r33.sh - Port Hiwifi R33 NAND device support from mengzonefire/22.03-of to OpenWrt 23.05
# 在 build-openwrt.yml 中被调用，运行目录为 openwrt 源码根目录
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

# 23.05 可能用不同路径
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
    echo "Available configs:"
    find target/linux/ramips/ -name "config-*" 2>/dev/null || true
    find /tmp/r33-source/target/linux/ramips/ -name "config-*" 2>/dev/null || true
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

DTS_COUNT=$(wc -l < /tmp/r33-dts-list.txt 2>/dev/null || echo "0")
echo "Found $DTS_COUNT DTS files"

if [ "$DTS_COUNT" -gt 0 ]; then
    while IFS= read -r dts_file; do
        [ -z "$dts_file" ] && continue
        [ ! -f "$dts_file" ] && continue
        fname=$(basename "$dts_file")
        echo "Copying: $fname"
        cp "$dts_file" target/linux/ramips/dts/
        echo "  NAND/partition references:"
        grep -n -i "nand\|ubi\|partition\|flash" "$dts_file" | head -10 || echo "  (none)"
    done < /tmp/r33-dts-list.txt
else
    echo "WARNING: No R33 DTS files found"
    echo "All mt7620 DTS files:"
    ls /tmp/r33-source/target/linux/ramips/dts/mt7620*.dts 2>/dev/null | head -20 || true
fi

# 检查公共 dtsi 中的 NAND 定义差异
echo ""
echo "Checking common dtsi files for NAND definitions..."
for dtsi_name in mt7620a.dtsi mt7620.dtsi; do
    src="/tmp/r33-source/target/linux/ramips/dts/$dtsi_name"
    dst="target/linux/ramips/dts/$dtsi_name"
    if [ -f "$src" ] && [ -f "$dst" ]; then
        echo "  $dtsi_name - comparing NAND sections:"
        src_nand=$(grep -c -i "nand" "$src" 2>/dev/null || echo "0")
        dst_nand=$(grep -c -i "nand" "$dst" 2>/dev/null || echo "0")
        echo "    22.03: $src_nand nand references"
        echo "    23.05: $dst_nand nand references"
        if [ "$src_nand" -gt "$dst_nand" ]; then
            echo "    WARNING: 22.03 has more NAND references, may need manual merge"
        fi
    elif [ -f "$src" ] && [ ! -f "$dst" ]; then
        echo "  $dtsi_name only in 22.03, copying"
        cp "$src" "$dst"
    fi
done

# ===== 5. 提取 R33 设备定义 =====
echo ""
echo "===== Step 5: Extract R33 device definition ====="

R33_IMG_SRC="/tmp/r33-source/target/linux/ramips/image/mt7620.mk"
R33_IMG_DST="target/linux/ramips/image/mt7620.mk"

echo "Searching for hiwifi device definitions..."
echo "All hiwifi/r33 lines in mengzonefire mt7620.mk:"
grep -n -i "hiwifi\|r33\|hc5661\|hc5761\|hc5861" "$R33_IMG_SRC" 2>/dev/null || echo "(none found)"

# 提取所有 hiwifi 设备块
echo ""
echo "Extracting all hiwifi device blocks..."

# 创建临时提取脚本（避免 awk 在 YAML 中的转义问题）
cat > /tmp/extract-devices.awk << 'AWKEOF'
/^define Device\/hiwifi/ { found=1 }
found { print }
found && /^TARGET_DEVICES \+= / { found=0; print "" }
AWKEOF

awk -f /tmp/extract-devices.awk "$R33_IMG_SRC" > /tmp/hiwifi-blocks.txt 2>/dev/null

if [ -s /tmp/hiwifi-blocks.txt ]; then
    echo "Found hiwifi device blocks:"
    cat /tmp/hiwifi-blocks.txt
    echo ""
    echo "Appending to 23.05 mt7620.mk..."
    echo "" >> "$R33_IMG_DST"
    echo "# === Hiwifi devices ported from mengzonefire/22.03-of ===" >> "$R33_IMG_DST"
    echo "# R33 uses 128MB NAND Flash, requires UBI support" >> "$R33_IMG_DST"
    cat /tmp/hiwifi-blocks.txt >> "$R33_IMG_DST"
    echo "Device definitions added successfully"
else
    echo "WARNING: No hiwifi device blocks extracted by awk"
    echo ""
    echo "Trying grep-based extraction..."
    # 备用方案：找到 define Device/hiwifi 行号，提取到下一个空行
    grep -n "^define Device/hiwifi" "$R33_IMG_SRC" 2>/dev/null | while IFS=: read -r linenum rest; do
        echo "Found at line $linenum: $rest"
        # 提取从该行到 TARGET_DEVICES 的内容
        sed -n "${linenum},/^TARGET_DEVICES/p" "$R33_IMG_SRC" >> /tmp/hiwifi-blocks-alt.txt
        echo "" >> /tmp/hiwifi-blocks-alt.txt
    done

    if [ -s /tmp/hiwifi-blocks-alt.txt ]; then
        echo "Extracted via sed:"
        cat /tmp/hiwifi-blocks-alt.txt
        echo "" >> "$R33_IMG_DST"
        echo "# === Hiwifi devices ported from mengzonefire/22.03-of ===" >> "$R33_IMG_DST"
        cat /tmp/hiwifi-blocks-alt.txt >> "$R33_IMG_DST"
    else
        echo "CRITICAL: Cannot extract device definitions!"
        echo ""
        echo "=== Full content of mengzonefire mt7620.mk (last 150 lines) ==="
        tail -150 "$R33_IMG_SRC"
    fi
fi

# ===== 6. 复制 NAND 内核补丁 =====
echo ""
echo "===== Step 6: Port NAND kernel patches ====="

# 确定补丁目录
PATCH_SRC_DIR="/tmp/r33-source/target/linux/ramips/patches-5.10"
PATCH_DST_DIR="target/linux/ramips/patches-5.15"

# 如果 23.05 用的不是 5.15，自动检测
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
            echo "  NAND patch: $fname"
            if [ -f "$PATCH_DST_DIR/$fname" ]; then
                echo "    -> Already exists in 23.05"
            else
                echo "    -> Copying"
                cp "$pf" "$PATCH_DST_DIR/"
            fi
        fi
    done

    echo ""
    echo "Searching for hiwifi/r33 specific patches..."
    find "$PATCH_SRC_DIR" -name "*.patch" -type f | while read -r pf; do
        fname=$(basename "$pf")
        if grep -q -i "hiwifi\|r33\|hc5661" "$pf" 2>/dev/null; then
            echo "  R33 patch: $fname"
            if [ ! -f "$PATCH_DST_DIR/$fname" ]; then
                echo "    -> Copying"
                cp "$pf" "$PATCH_DST_DIR/"
            fi
        fi
    done
else
    echo "WARNING: Patch directories not found"
fi

# ===== 7. 移植 board.d 配置（网络/LED） =====
echo ""
echo "===== Step 7: Port board.d configs ====="

for board_file in \
    "target/linux/ramips/base-files/etc/board.d/01_leds" \
    "target/linux/ramips/base-files/etc/board.d/02_network"; do

    src="/tmp/r33-source/$board_file"
    dst="$board_file"

    if [ -f "$src" ]; then
        echo ""
        echo "File: $(basename $board_file)"
        echo "  22.03 hiwifi entries:"
        grep -i "hiwifi\|r33" "$src" | head -10 || echo "  (none)"

        if [ -f "$dst" ]; then
            echo "  23.05 hiwifi entries:"
            grep -i "hiwifi\|r33" "$dst" | head -10 || echo "  (none)"

            # 如果 23.05 缺少 R33 条目，从 22.03 提取并追加
            if ! grep -q -i "hiwifi.*r33\|hiwifi,r33\|hiwifi_r33" "$dst" 2>/dev/null; then
                echo "  -> R33 entries missing in 23.05, extracting from 22.03..."
                grep -i "hiwifi.*r33\|hiwifi,r33\|hiwifi_r33" "$src" 2>/dev/null | while IFS= read -r entry; do
                    echo "  -> Adding: $entry"
                    echo "$entry" >> "$dst"
                done
            fi
        else
            echo "  23.05 file missing, copying from 22.03"
            mkdir -p "$(dirname "$dst")"
            cp "$src" "$dst"
        fi
    fi
done

# ===== 8. 移植 platform.sh 升级函数 =====
echo ""
echo "===== Step 8: Port platform.sh upgrade functions ====="

PLAT_SRC="/tmp/r33-source/target/linux/ramips/base-files/lib/upgrade/platform.sh"
PLAT_DST="target/linux/ramips/base-files/lib/upgrade/platform.sh"

# 也检查 mt7620 子目录
PLAT_SRC_SUB="/tmp/r33-source/target/linux/ramips/mt7620/base-files/lib/upgrade/platform.sh"
PLAT_DST_SUB="target/linux/ramips/mt7620/base-files/lib/upgrade/platform.sh"

for src_f in "$PLAT_SRC" "$PLAT_SRC_SUB"; do
    [ ! -f "$src_f" ] && continue
    echo "Checking: $src_f"
    echo "  NAND/hiwifi upgrade entries:"
    grep -n -i "nand\|ubi\|hiwifi\|r33" "$src_f" | head -10 || echo "  (none)"
done

# ===== 9. 移植 mt7620 subtarget 文件 =====
echo ""
echo "===== Step 9: Port mt7620 subtarget files ====="

R33_SUB="/tmp/r33-source/target/linux/ramips/mt7620"
CUR_SUB="target/linux/ramips/mt7620"

echo "22.03 mt7620 subtarget files:"
ls -la "$R33_SUB"/ 2>/dev/null || echo "(none)"

echo ""
echo "23.05 mt7620 subtarget files:"
ls -la "$CUR_SUB"/ 2>/dev/null || echo "(none)"

# 复制缺失的文件（不覆盖已有的）
if [ -d "$R33_SUB" ]; then
    for f in "$R33_SUB"/*; do
        [ ! -f "$f" ] && continue
        fname=$(basename "$f")
        if [ ! -f "$CUR_SUB/$fname" ]; then
            echo "Copying missing: $fname"
            cp "$f" "$CUR_SUB/"
        fi
    done
fi

# ===== 10. 清理并验证 =====
echo ""
echo "===== Step 10: Cleanup and verification ====="

rm -rf /tmp/r33-source /tmp/r33-dts-list.txt /tmp/hiwifi-blocks.txt /tmp/hiwifi-blocks-alt.txt /tmp/extract-devices.awk

echo ""
echo "=========================================="
echo "  FINAL VERIFICATION"
echo "=========================================="
echo ""
echo "--- R33 DTS files in 23.05 ---"
find target/linux/ramips/dts/ -type f \( -iname "*r33*" -o -iname "*hc5661*" -o -iname "*hiwifi*" \) 2>/dev/null || echo "NONE FOUND"

echo ""
echo "--- R33 in image mt7620.mk ---"
R33_COUNT=$(grep -c -i "hiwifi_r33\|hiwifi-r33\|hiwifi,r33" target/linux/ramips/image/mt7620.mk 2>/dev/null || echo "0")
echo "R33 references: $R33_COUNT"

echo ""
echo "--- All hiwifi device blocks ---"
grep -A 20 "Device/hiwifi" target/linux/ramips/image/mt7620.mk 2>/dev/null || echo "No hiwifi device blocks"

echo ""
echo "--- NAND kernel configs ---"
if [ -n "$CUR_KCONF" ] && [ -f "$CUR_KCONF" ]; then
    grep -i "NAND\|UBI\|UBIFS" "$CUR_KCONF" | sort || echo "None"
fi

echo ""
echo "--- NAND patches ---"
if [ -n "$PATCH_DST_DIR" ]; then
    grep -rl -i "nand.*mt7620\|mt7620.*nand" "$PATCH_DST_DIR"/ 2>/dev/null || echo "None"
fi

echo ""
echo "=========================================="
echo "  PORTING COMPLETE"
echo "=========================================="

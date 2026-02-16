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

# ===== 5. 提取并追加 R33 设备定义（仅 R33） =====
echo ""
echo "===== Step 5: Extract R33 device definition ONLY ====="

R33_IMG_SRC="/tmp/r33-source/target/linux/ramips/image/mt7620.mk"
R33_IMG_DST="target/linux/ramips/image/mt7620.mk"

if grep -q "^define Device/hiwifi_r33" "$R33_IMG_DST" 2>/dev/null; then
    echo "R33 device definition ALREADY EXISTS in 23.05, skipping"
else
    echo "R33 not found in 23.05, extracting from 22.03..."

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

        echo "Verifying NAND parameters:"
        grep -q "BLOCKSIZE" /tmp/r33-block.txt && echo "  OK: BLOCKSIZE" || echo "  MISSING: BLOCKSIZE"
        grep -q "PAGESIZE" /tmp/r33-block.txt && echo "  OK: PAGESIZE" || echo "  MISSING: PAGESIZE"
        grep -q "UBINIZE_OPTS" /tmp/r33-block.txt && echo "  OK: UBINIZE_OPTS" || echo "  MISSING: UBINIZE_OPTS"
        grep -q "sysupgrade-tar" /tmp/r33-block.txt && echo "  OK: sysupgrade-tar" || echo "  MISSING: sysupgrade-tar"
        grep -q "append-ubi" /tmp/r33-block.txt && echo "  OK: append-ubi" || echo "  MISSING: append-ubi"

        echo "" >> "$R33_IMG_DST"
        echo "# === Hiwifi R33 (NAND) - ported from mengzonefire/22.03-of ===" >> "$R33_IMG_DST"
        cat /tmp/r33-block.txt >> "$R33_IMG_DST"
        echo ""
        echo "R33 device definition added successfully"
    else
        echo "WARNING: awk extraction empty, trying sed..."
        START_LINE=$(grep -n "^define Device/hiwifi_r33$" "$R33_IMG_SRC" | head -1 | cut -d: -f1)
        if [ -n "$START_LINE" ]; then
            END_LINE=$(tail -n +"$START_LINE" "$R33_IMG_SRC" | grep -n "^TARGET_DEVICES += hiwifi_r33$" | head -1 | cut -d: -f1)
            if [ -n "$END_LINE" ]; then
                ACTUAL_END=$((START_LINE + END_LINE - 1))
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
            grep -n "hiwifi" "$R33_IMG_SRC" || true
        fi
    fi

    rm -f /tmp/extract-r33.awk /tmp/r33-block.txt
fi

echo ""
echo "Duplicate check:"
R33_COUNT=$(grep -c "^define Device/hiwifi_r33$" "$R33_IMG_DST" 2>/dev/null || true)
R33_COUNT=${R33_COUNT:-0}
echo "  hiwifi_r33 definitions: $R33_COUNT (should be 1)"

# ===== 6. 复制 NAND 内核补丁并修复 5.15 兼容性 =====
echo ""
echo "===== Step 6: Port NAND kernel patches (with 5.15 fix) ====="

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

    # ===============================================================
    # 【关键修复】修补 ralink_nand.c 中的 5.15 编译兼容性问题
    #
    # 问题: kernel 5.15 中 MTD OOB 接口重构，ralink_nand.c 中的
    #   ramtd_nand_readoob() 和 ramtd_nand_writeoob() 不再被引用
    #   GCC 12.3 + -Werror 将 unused-function 视为致命错误
    #
    # 解决: 给这两个函数添加 __maybe_unused 属性
    # ===============================================================
    echo ""
    echo "--- Fixing NAND driver for kernel 5.15 compatibility ---"

    NAND_PATCH="$PATCH_DST_DIR/0038-mtd-ralink-add-mt7620-nand-driver.patch"

    if [ -f "$NAND_PATCH" ]; then
        echo "Found NAND driver patch: $NAND_PATCH"

        # 检查是否包含需要修复的函数
        if grep -q "ramtd_nand_readoob" "$NAND_PATCH" 2>/dev/null; then
            echo "Patching ramtd_nand_readoob to add __maybe_unused..."

            # 修复 ramtd_nand_readoob: 在函数定义行前添加 __maybe_unused
            sed -i 's/^+ramtd_nand_readoob(struct mtd_info \*mtd/+__maybe_unused ramtd_nand_readoob(struct mtd_info *mtd/' "$NAND_PATCH"
            # 如果函数签名跨行(static int 在前一行)
            sed -i '/^+static int$/{
                N
                s/^+static int\n+ramtd_nand_readoob/+static int __maybe_unused\n+ramtd_nand_readoob/
            }' "$NAND_PATCH"

            echo "  Done"
        else
            echo "  ramtd_nand_readoob not found in patch (may already be fixed)"
        fi

        if grep -q "ramtd_nand_writeoob" "$NAND_PATCH" 2>/dev/null; then
            echo "Patching ramtd_nand_writeoob to add __maybe_unused..."

            sed -i 's/^+ramtd_nand_writeoob(struct mtd_info \*mtd/+__maybe_unused ramtd_nand_writeoob(struct mtd_info *mtd/' "$NAND_PATCH"
            sed -i '/^+static int$/{
                N
                s/^+static int\n+ramtd_nand_writeoob/+static int __maybe_unused\n+ramtd_nand_writeoob/
            }' "$NAND_PATCH"

            echo "  Done"
        else
            echo "  ramtd_nand_writeoob not found in patch (may already be fixed)"
        fi

        # 验证修复
        echo ""
        echo "Verifying fix applied:"
        echo "  readoob:"
        grep -n "ramtd_nand_readoob" "$NAND_PATCH" | head -3
        echo "  writeoob:"
        grep -n "ramtd_nand_writeoob" "$NAND_PATCH" | head -3

        # 显示修复后的上下文
        echo ""
        echo "Context around readoob:"
        grep -B2 -A1 "ramtd_nand_readoob" "$NAND_PATCH" | head -10
        echo ""
        echo "Context around writeoob:"
        grep -B2 -A1 "ramtd_nand_writeoob" "$NAND_PATCH" | head -10

    else
        echo "WARNING: NAND driver patch not found at $NAND_PATCH"
        echo "Searching for any ralink nand patch..."
        find "$PATCH_DST_DIR" -name "*nand*" -o -name "*ralink*" 2>/dev/null || echo "None found"
    fi
else
    echo "WARNING: Patch directories not found"
fi

# ===== 7. 移植 board.d 网络和 LED 配置 =====
echo ""
echo "===== Step 7: Port board.d network and LED configs ====="

echo "--- Network config (02_network) ---"

NET_SRC=""
NET_DST=""

for src_try in \
    "/tmp/r33-source/target/linux/ramips/mt7620/base-files/etc/board.d/02_network" \
    "/tmp/r33-source/target/linux/ramips/base-files/etc/board.d/02_network"; do
    if [ -f "$src_try" ]; then
        NET_SRC="$src_try"
        break
    fi
done

for dst_try in \
    "target/linux/ramips/mt7620/base-files/etc/board.d/02_network" \
    "target/linux/ramips/base-files/etc/board.d/02_network"; do
    if [ -f "$dst_try" ]; then
        NET_DST="$dst_try"
        break
    fi
done

echo "  Source: ${NET_SRC:-NOT FOUND}"
echo "  Dest:   ${NET_DST:-NOT FOUND}"

if [ -n "$NET_SRC" ]; then
    echo "  R33 network entries in 22.03:"
    grep -n -A5 "r33\|hiwifi.*r33" "$NET_SRC" | head -20 || echo "  (none)"

    if ! grep -q "r33" "$NET_SRC" 2>/dev/null; then
        echo "  Broader hiwifi search:"
        grep -n -A3 "hiwifi" "$NET_SRC" | head -20 || echo "  (none)"
    fi
fi

if [ -n "$NET_DST" ]; then
    if grep -q "hiwifi,r33\|hiwifi_r33" "$NET_DST" 2>/dev/null; then
        echo "  R33 network config already in 23.05"
    else
        echo "  Searching all board.d for R33 network..."
        find /tmp/r33-source/target/linux/ramips/ -path "*/board.d/*" -type f 2>/dev/null | while read -r bf; do
            if grep -q "r33" "$bf" 2>/dev/null; then
                echo "  Found R33 in: $bf"
                grep -n -A5 "r33" "$bf" | head -20
            fi
        done
    fi
fi

echo ""
echo "--- LED config (01_leds) ---"

LED_SRC=""
LED_DST=""

for src_try in \
    "/tmp/r33-source/target/linux/ramips/mt7620/base-files/etc/board.d/01_leds" \
    "/tmp/r33-source/target/linux/ramips/base-files/etc/board.d/01_leds"; do
    if [ -f "$src_try" ]; then
        LED_SRC="$src_try"
        break
    fi
done

for dst_try in \
    "target/linux/ramips/mt7620/base-files/etc/board.d/01_leds" \
    "target/linux/ramips/base-files/etc/board.d/01_leds"; do
    if [ -f "$dst_try" ]; then
        LED_DST="$dst_try"
        break
    fi
done

echo "  Source: ${LED_SRC:-NOT FOUND}"
echo "  Dest:   ${LED_DST:-NOT FOUND}"

if [ -n "$LED_SRC" ]; then
    echo "  R33 LED entries in 22.03:"
    grep -n -A5 "r33\|hiwifi.*r33" "$LED_SRC" | head -10 || echo "  (none)"
fi

# ===== 8. 移植 platform.sh 升级函数 =====
echo ""
echo "===== Step 8: Port platform.sh NAND upgrade function ====="

echo "Searching platform.sh files..."
echo "--- In 22.03 ---"
find /tmp/r33-source/target/linux/ramips/ -name "platform.sh" -path "*/upgrade/*" 2>/dev/null | while read -r pf; do
    echo "  $pf"
    grep -n "r33\|hiwifi" "$pf" | head -5 || echo "    (no r33)"
done

echo ""
echo "--- In 23.05 ---"
find target/linux/ramips/ -name "platform.sh" -path "*/upgrade/*" 2>/dev/null | while read -r pf; do
    echo "  $pf"
    grep -n "r33\|hiwifi\|nand_do_upgrade" "$pf" | head -10 || echo "    (no r33/nand)"
done

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
        echo "R33 NAND upgrade already configured"
    else
        echo "Adding R33 NAND upgrade function..."

        if grep -q "nand_do_upgrade" "$R33_PLAT_DST" 2>/dev/null; then
            echo "Existing nand_do_upgrade found, adding R33 case..."
            if grep -q "esac" "$R33_PLAT_DST" 2>/dev/null; then
                sed -i '/^[[:space:]]*esac/i\
\thiwifi,r33)\
\t\tnand_do_upgrade "$1"\
\t\t;;' "$R33_PLAT_DST"
                echo "Added R33 case before esac"
            fi
        else
            if grep -q "platform_do_upgrade" "$R33_PLAT_DST" 2>/dev/null; then
                if grep -q "esac" "$R33_PLAT_DST" 2>/dev/null; then
                    sed -i '/^[[:space:]]*esac/i\
\thiwifi,r33)\
\t\tnand_do_upgrade "$1"\
\t\t;;' "$R33_PLAT_DST"
                    echo "Added R33 case to platform_do_upgrade"
                fi
            else
                cat >> "$R33_PLAT_DST" << 'PLATEOF'

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
    echo "Creating new platform.sh..."
    PLAT_DIR="target/linux/ramips/mt7620/base-files/lib/upgrade"
    mkdir -p "$PLAT_DIR"
    cat > "$PLAT_DIR/platform.sh" << 'PLATEOF'
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
    R33_PLAT_DST="$PLAT_DIR/platform.sh"
    echo "Created new platform.sh"
    cat "$R33_PLAT_DST"
fi

# ===== 9. 确保 NAND 升级依赖存在 =====
echo ""
echo "===== Step 9: Verify NAND upgrade dependencies ====="

echo "Checking for nand.sh..."
NAND_SH=$(find target/ package/ -name "nand.sh" -path "*/upgrade/*" 2>/dev/null | head -1)
if [ -n "$NAND_SH" ]; then
    echo "Found nand.sh: $NAND_SH"
elif [ -f "package/base-files/files/lib/upgrade/nand.sh" ]; then
    echo "OK: nand.sh in base-files package"
else
    echo "Searching broadly..."
    find . -name "nand.sh" 2>/dev/null | head -5 || echo "Not found"
fi

# ===== 10. 移植 mt7620 subtarget 文件 =====
echo ""
echo "===== Step 10: Port mt7620 subtarget files ====="

R33_SUB="/tmp/r33-source/target/linux/ramips/mt7620"
CUR_SUB="target/linux/ramips/mt7620"

echo "22.03 mt7620 files:"
ls -la "$R33_SUB"/ 2>/dev/null || echo "(none)"

echo ""
echo "23.05 mt7620 files:"
ls -la "$CUR_SUB"/ 2>/dev/null || echo "(none)"

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
    echo "   OK: exists"
    grep -A3 "nand {" target/linux/ramips/dts/mt7620a_hiwifi_r33.dts | head -5
else
    echo "   FAIL: not found"
fi

echo ""
echo "2. R33 device definition:"
R33_DEF_COUNT=$(grep -c "^define Device/hiwifi_r33$" target/linux/ramips/image/mt7620.mk 2>/dev/null || true)
R33_DEF_COUNT=${R33_DEF_COUNT:-0}
echo "   count: $R33_DEF_COUNT (expected: 1)"

for dev in hiwifi_hc5661 hiwifi_hc5761 hiwifi_hc5861; do
    count=$(grep -c "^define Device/${dev}$" target/linux/ramips/image/mt7620.mk 2>/dev/null || true)
    count=${count:-0}
    if [ "$count" -gt 1 ]; then
        echo "   WARNING: $dev duplicated ($count times)"
    fi
done

echo ""
echo "3. NAND kernel configs:"
if [ -n "$CUR_KCONF" ] && [ -f "$CUR_KCONF" ]; then
    MTD_NAND=$(grep -c "CONFIG_MTD_NAND_MT7620=y" "$CUR_KCONF" 2>/dev/null || true)
    MTD_UBI=$(grep -c "CONFIG_MTD_UBI=y" "$CUR_KCONF" 2>/dev/null || true)
    UBIFS=$(grep -c "CONFIG_UBIFS_FS=y" "$CUR_KCONF" 2>/dev/null || true)
    echo "   MTD_NAND_MT7620: ${MTD_NAND:-0}"
    echo "   MTD_UBI: ${MTD_UBI:-0}"
    echo "   UBIFS_FS: ${UBIFS:-0}"
fi

echo ""
echo "4. NAND driver patch (5.15 compatible):"
NAND_PATCH_CHECK="$PATCH_DST_DIR/0038-mtd-ralink-add-mt7620-nand-driver.patch"
if [ -f "$NAND_PATCH_CHECK" ]; then
    echo "   OK: patch present"
    if grep -q "__maybe_unused" "$NAND_PATCH_CHECK" 2>/dev/null; then
        echo "   OK: __maybe_unused fix applied"
        UNUSED_COUNT=$(grep -c "__maybe_unused" "$NAND_PATCH_CHECK" 2>/dev/null || true)
        echo "   __maybe_unused occurrences: ${UNUSED_COUNT:-0} (expected: 2)"
    else
        echo "   WARNING: __maybe_unused fix NOT found"
    fi
else
    echo "   WARNING: patch missing"
fi

echo ""
echo "5. Platform upgrade:"
if [ -n "$R33_PLAT_DST" ] && [ -f "$R33_PLAT_DST" ]; then
    if grep -q "hiwifi,r33" "$R33_PLAT_DST" 2>/dev/null; then
        echo "   OK: R33 NAND upgrade configured"
    else
        echo "   WARNING: R33 not in platform.sh"
    fi
else
    grep -rl "hiwifi,r33\|hiwifi_r33" target/linux/ramips/ 2>/dev/null || echo "   NOT FOUND"
fi

echo ""
echo "=========================================="
echo "  PORTING COMPLETE"
echo "=========================================="

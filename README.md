# OpenWrt 23.05 Build for HiWiFi R33 (HC5861B / C312B B52)

Build OpenWrt 23.05.5 firmware for HiWiFi R33 (极路由3 Pro) using GitHub Actions.

## Hardware Specifications

| Component | Detail |
|-----------|--------|
| CPU | MT7620A @ 580MHz (MIPS 24KEc) |
| RAM | 128MB DDR2 |
| Flash | 128MB NAND |
| Switch | RTL8367RB (Gigabit) |
| WiFi 2.4G | MT7620A built-in (rt2800-soc) |
| WiFi 5G | MT7612EN (PCIe, kmod-mt76x2) |
| USB | USB 2.0 |
| Target | ramips/mt7620 |
| Arch | mipsel_24kc |

## Key Features

- **Pure/Clean build** — Based on official OpenWrt 23.05.5 source
- **NAND support** — Custom MT7620 NAND driver with ECC
- **Dual-band WiFi** — 2.4GHz + 5GHz fully supported
- **Gigabit Ethernet** — RTL8367RB switch with patched driver
- **LuCI Web UI** — Included for easy management
- **USB Storage** — FAT/EXT4 filesystem support

## Patches Applied

1. **RTL8367RB switch driver** — Added chip_ver `0x0020` identification
2. **MT7620 NAND driver** — Custom kernel driver for 128MB NAND flash
3. **Device Tree** — Full hardware description (DTS) with nvmem-layout
4. **Board scripts** — LED, network, WiFi MAC, upgrade support

## 22.03 → 23.05 Adaptations

| Item | Change |
|------|--------|
| Kernel | 5.10 → 5.15 |
| DTS eeprom | `ralink,mtd-eeprom` → `nvmem-layout` + `nvmem-cells` |
| NAND patch | Removed `erase_info.fail_addr` (gone since kernel 5.0) |
| Kconfig | Adjusted for `patches-5.15` / `config-5.15` |
| Build env | Ubuntu 20.04 → Ubuntu 22.04 |
| Source | Fork → Official OpenWrt + dynamic patching |

## Usage

1. Fork this repository
2. Go to **Actions** tab → **Build OpenWrt 23.05 for HiWiFi R33**
3. Click **Run workflow**
4. Wait for build to complete (~1-2 hours)
5. Download firmware from **Releases**

## Output Files

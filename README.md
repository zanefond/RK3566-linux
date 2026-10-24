# R66 (RK3566 DDR4) Armbian Linux 移植项目

本项目为 **R66 (Rockchip RK3566 DDR4)** 安卓开发板提供基于 **Armbian 官方构建框架 (`armbian/build`) + Rockchip Vendor 6.1 BSP 内核** 的完整 Linux 固件云端编译方案（通过 GitHub Actions 编译，本地无需安装任何交叉编译工具或虚拟机）。

---

## 1. 硬件规格与驱动适配清单 (基于原厂安卓 `rk3566.dts` 逆向提取)

| 模块 | 硬件型号 / 接口 | 关键引脚 / 总线 | Linux 6.1 驱动状态 |
| :--- | :--- | :--- | :--- |
| **SoC / 内存** | Rockchip RK3566 (4x Cortex-A55) + DDR4 1056MHz | `rk3566_ddr_1056MHz_v1.21.bin` | 已内置打包进 U-Boot |
| **电源管理** | RK809 PMIC (`0x20`) + TCS4525 CPU DCDC (`0x1c`) | `i2c0`, PMIC IRQ `GPIO0_A3` | 已完整映射所有电压域 (`pmu_io_domains`) |
| **视频输出** | **HDMI 2.0** (默认主显示) + 预留 eDP 接口 | `VP0 -> HDMI`, `hdmi-sound` (`i2s0`) | **默认开启 HDMI + 音频**（eDP 默认关闭防抢占主屏） |
| **视频硬解/硬编** | Rockchip VPU / RKVDEC2 / RKVENC / RGA2 / IEP / JPEG | `&mpp_srv`, `&rkvdec`, `&vdpu`, `&rk_rga` | **已开启 Rockchip MPP 全套硬件编解码支持** |
| **有线网卡** | Realtek RTL8111 千兆网口 (PCIe 2.0 x1) | `&pcie2x1`, 复位脚 `GPIO3_C1` | `r8169` 驱动自动加载 |
| **无线 / 蓝牙** | Realtek RTL8821CS (SDIO WiFi + UART1 BT) | `&sdmmc1`, 电源 `GPIO1_A0`, 复位 `GPIO2_B1` | `rtw88_8821cs` + `hci_uart` (`btrtl`) |
| **存储** | 板载 8-bit eMMC (`&sdhci`) + MicroSD/TF 卡 (`&sdmmc0`) | TF 供电 `vcc3v3_sd` / `vccio_sd` | U-Boot 已配置为 **TF 卡 (`mmc1`) 优先启动** |
| **USB 接口** | USB 3.0 Host + USB 2.0 Host x2 + USB 2.0 OTG | Host 供电 `GPIO0_A6`, OTG 供电 `GPIO0_A5` | 全端口已启用 |
| **外置硬件看门狗** | 板载协处理器 (`spirit_mcu@15` on `i2c5`) | 喂狗引脚 `GPIO4_B1` (低有效翻转) | **内核内置 `linux,wdt-gpio` (`always-running`) 自动后台喂狗** |
| **实时时钟 (RTC)** | HYM8563 (`0x51`) | `i2c5`, 中断脚 `GPIO0_C0` | `rtc-hym8563` 内置驱动 |
| **音频 Codec** | RK809 Codec (`i2s1_8ch`) | 功放控制 `GPIO3_A2`, 耳机检测 `GPIO3_A1` | `snd-soc-rk817` |

---

## 2. 目录结构

```text
.
├── .github/workflows/build.yml                          # GitHub Actions 云端自动编译并发布固件工作流
├── rk3566.dts                                           # 从板载安卓固件提取的原始反编译设备树备份
└── userpatches/
    ├── config/boards/r66-rk3566.csc                     # Armbian 板级配置文件 (含 U-Boot 打包与内核看门狗配置)
    └── kernel/rk35xx-vendor-6.1/dt/rk3566-r66.dts       # 移植后的 Linux 6.1 设备树源码
```

---

## 3. 使用 GitHub Actions 云端编译固件

1. 打开本仓库的 **Actions** 页面，选择左侧 **Build Armbian for R66 (RK3566)**。
2. 点击右侧 **Run workflow**：
   - `release`: 推荐选择 `bookworm` (Debian 12) 或 `noble` (Ubuntu 24.04)。
   - `build_minimal`: 推荐 `no`（标准服务器 CLI 版，包含完整工具链与固件包）。
   - `build_desktop`: 服务器用途选 `no`。
   - `create_release`: 勾选 `true`（编译完成后自动发布到仓库的 **Releases** 页面）。
3. 编译耗时约 **45 ~ 70 分钟**。完成后可直接在仓库的 **Releases**（或 Action Run 底部的 **Artifacts**）下载 `.img.xz` 镜像文件。

---

## 4. SD 卡刷入与启动说明（必读）

### 4.1 刷写 SD 卡
生成的 `.img.xz` 镜像**已将 U-Boot (`u-boot-rockchip.bin`，含 DDR4 初始化固件与 TF 卡优先启动顺序) 直接打包在镜像偏移 `32KB (sector 64)` 处**：
- 直接使用 **BalenaEtcher**、**Raspberry Pi Imager** 或 `xzcat Armbian_*.img.xz | sudo dd of=/dev/sdX bs=4M status=progress` 刷入 MicroSD/TF 卡即可。

### 4.2 关于 RK3566 启动顺序 (eMMC vs SD 卡)
瑞芯微 RK3566 芯片内部固化的硬件 BootROM 寻找引导程序 (`idbloader`) 的固定顺序为：
> **SPI Flash -> 板载 eMMC (`sdhci`) -> SD/TF 卡 (`sdmmc0`)**

这意味着：
- **情况 A（推荐）**：如果板载 eMMC 里的安卓原厂 U-Boot 支持扫描并引导 SD 卡上的 `extlinux`/`boot.scr`，或者板载 eMMC 引导区已被擦除，插入刷好本镜像的 SD 卡上电即可直接进入 Armbian。
- **情况 B（若上电后仍然直接进了板载 eMMC 的安卓系统）**：说明板载 eMMC 中的原厂引导程序拦截了启动且未扫描 SD 卡。此时有两种解决方式：
  1. **保留安卓系统共存**：将镜像中编译出的 U-Boot（或使用 `rkdeveloptool`）刷入 eMMC 的 `uboot` 分区，由于本项目的 U-Boot 已配置 `BOOT_TARGETS="mmc1 usb mmc0"`，插有 SD 卡时会自动从 SD 卡启动 Armbian，拔出 SD 卡则启动 eMMC。
  2. **纯 SD 卡/eMMC 运行 Linux**：按住主板上的 **`RECOVER2`** 按键上电（或进入安卓 `adb reboot loader`），清空 eMMC 头部的 `idbloader`（前 4MB），此后硬件 BootROM 会永远跳过 eMMC 直接从 SD 卡上的 U-Boot 启动；进入 SD 卡的 Armbian 后也可随时运行 `armbian-install` 将系统一键写入板载高速 eMMC。

---

## 5. 视频硬解 (Rockchip MPP) 使用方法

进入 Armbian (`vendor` 6.1 内核) 后，可检查硬件解码器节点是否就绪：
```bash
ls -l /dev/mpp_service /dev/rga /dev/dri/
```
在 Debian 12 (`bookworm`) / Ubuntu 24.04 (`noble`) 下安装并使用集成了 Rockchip MPP + RGA 硬件加速的 FFmpeg / Jellyfin：
- **Jellyfin 官方硬件加速包**：直接安装 `jellyfin-ffmpeg6` / `jellyfin-ffmpeg7`，在 Jellyfin 后台开启 **Rockchip MPP (RKMPP)** 即可硬解 H.264 / HEVC (H.265) / VP9 4K 视频。
- **命令行测试**：可通过 `liujianfeng1994/rockchip-multimedia` PPA 或源码编译 `ffmpeg-rockchip` 使用 `-c:v h264_rkmpp` / `-c:v hevc_rkmpp`。

# Rockchip RK3566 DDR4 R66 Board (PCIe RTL8111 GbE, RTL8821CS WiFi/BT, eMMC, SD, USB3, HDMI, eDP)
BOARD_NAME="R66 RK3566"
BOARD_VENDOR="rockchip"
BOARDFAMILY="rk35xx"
BOOT_SOC="rk3566"
BOARD_MAINTAINER="chenzhanfeng"
INTRODUCED="2024"
BOOTCONFIG="quartz64-a-rk3566_defconfig"
KERNEL_TARGET="vendor"
KERNEL_TEST_TARGET="vendor"
FULL_DESKTOP="yes"
BOOT_LOGO="desktop"
BOOT_FDT_FILE="rockchip/rk3566-r66.dtb"
BOOT_SCENARIO="spl-blobs"
IMAGE_PARTITION_TABLE="gpt"

# Package mainline U-Boot + Rockchip DDR4/BL31 blobs directly into the SD card image (sector 64 / 32KB offset)
function post_family_config__r66_use_mainline_uboot() {
	display_alert "$BOARD" "Using mainline U-Boot for $BOARD / $BRANCH" "info"

	declare -g BOOTSOURCE="https://github.com/u-boot/u-boot.git"
	declare -g BOOTBRANCH="tag:v2025.04"
	declare -g BOOTPATCHDIR="v2025.04"
	declare -g BOOTDELAY=1

	# Binman packs DDR_BLOB (rk3566_ddr_1056MHz_v1.21.bin) + U-Boot SPL + BL31_BLOB + U-Boot FIT into u-boot-rockchip.bin
	declare -g UBOOT_TARGET_MAP="BL31=${RKBIN_DIR}/${BL31_BLOB} ROCKCHIP_TPL=${RKBIN_DIR}/${DDR_BLOB};;u-boot-rockchip.bin"

	unset uboot_custom_postprocess write_uboot_platform write_uboot_platform_mtd

	function write_uboot_platform() {
		dd "if=$1/u-boot-rockchip.bin" "of=$2" bs=32k seek=1 conv=notrunc status=none
	}
}

# Ensure U-Boot checks SD card (mmc1) before onboard eMMC (mmc0)
function pre_config_uboot_target__r66_patch_boot_order() {
	declare -a rockchip_uboot_targets=("mmc1" "usb" "mmc0" "pxe" "dhcp")
	display_alert "u-boot for ${BOARD}/${BRANCH}" "u-boot: adjust boot order to '${rockchip_uboot_targets[*]}'" "info"
	if [[ -f include/configs/rockchip-common.h ]]; then
		sed -i -e "s/#define BOOT_TARGETS.*/#define BOOT_TARGETS \"${rockchip_uboot_targets[*]}\"/" include/configs/rockchip-common.h
	fi
}

# Enable GPIO watchdog driver in kernel to automatically pet the onboard spirit_mcu watchdog pin (GPIO4_B1)
function custom_kernel_config__r66_mcu_watchdog() {
	opts_y+=("GPIO_WATCHDOG" "WATCHDOG_HANDLE_BOOT_ENABLED")
}

# Friendly audio card names for HDMI and RK809 analog audio
function post_family_tweaks__r66_naming_audios() {
	display_alert "$BOARD" "Configuring R66 audio device names" "info"

	mkdir -p "$SDCARD/etc/udev/rules.d/"
	cat <<- 'EOF' > "$SDCARD/etc/udev/rules.d/90-naming-audios.rules"
		SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmi-sound", ENV{SOUND_DESCRIPTION}="HDMI Audio"
		SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-rk809-sound", ENV{SOUND_DESCRIPTION}="RK809 Audio"
	EOF
	return 0
}

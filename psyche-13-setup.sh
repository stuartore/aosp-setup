#!/bin/bash
# This file is generated for Xiaomi 12X (psyche)
# Please copy this script to android source root directory before running

# make new mkdir
mkdir -p device/xiaomi vendor/xiaomi kernel/xiaomi

psyche_use_common_deps(){
	# NOT AVAIABLE 

	# pull source for device/ vendor/ kernel
	# device specific dir
	mkdir -p vendor/xiaomi-firmware
	
	# pull source for device/ vendor/ kernel
	git clone https://github.com//LineageOS/android_hardware_xiaomi -b lineage-20 hardware/xiaomi
	git clone https://github.com/stuartore/device_xiaomi_psyche -b $1 device/xiaomi/psyche
	git clone https://github.com/stuartore/device_xiaomi_sm8250-common -b thirteen device/xiaomi/sm8250-common
	git clone https://gitlab.com/stuartore/android_vendor_xiaomi_psyche -b thirteen vendor/xiaomi/psyche
	git clone https://gitlab.com/stuartore/vendor_xiaomi_sm8250-common.git -b thirteen vendor/xiaomi/sm8250-common
	git clone https://gitlab.com/stuartore/vendor_xiaomi_psyche-firmware -b thirteen vendor/xiaomi-firmware/psyche
	git clone --depth=1 https://github.com/stuartore/kernel_xiaomi_sm8250 -b thirteen kernel/xiaomi/sm8250
	
	# other
	echo 'include $(call all-subdir-makefiles)' > vendor/xiaomi-firmware/Android.mk
}

psyche_deps(){
	# pull source for device/ vendor/ kernel

	git clone https://github.com//LineageOS/android_hardware_xiaomi -b lineage-20 hardware/xiaomi
	git clone https://github.com/stuartore/android_device_xiaomi_psyche -b $1 device/xiaomi/psyche
	git clone https://gitlab.com/stuartore/android_vendor_xiaomi_psyche -b thirteen vendor/xiaomi/psyche
	#git clone https://gitlab.com/stuartore/vendor_xiaomi_psyche-firmware -b thirteen vendor/xiaomi-firmware/psyche
	#git clone --depth=1 https://github.com/stuartore/kernel_xiaomi_sm8250 -b thirteen kernel/xiaomi/sm8250
	git clone https://github.com/VoidUI-Devices/kernel_xiaomi_sm8250.git --depth=1 -b aosp-13-redline-archived_till_base_finished kernel/xiaomi/void-sm8250
}

select rom_to_build in "PixelExperience 13" "Superior 13" "RiceDroid 13"
do
	case $rom_to_build in
		"PixelExperience 13")
			dt_branch="thirteen"
			;;
		"Superior 13")
			dt_branch="superior-13"
			;;
		"RiceDroid 13")
			dt_branch="rice-13"
			;;
		*)
			echo -e "\n\033[32m=>\033[0m not selected"
			exit 1
			;;
	esac
	break
done 

psyche_deps ${dt_branch}

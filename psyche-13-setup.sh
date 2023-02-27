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
	git clone --depth=1 https://github.com/VoidUI-Devices/kernel_xiaomi_sm8250.git --depth=1 -b aosp-13 kernel/xiaomi/void-aosp-sm8250
	
	# other
	echo 'include $(call all-subdir-makefiles)' > vendor/xiaomi-firmware/Android.mk
}

psyche_deps(){
	# pull source for device/ vendor/ kernel
	# device specific dir
	mkdir -p vendor/xiaomi-firmware

	git clone https://github.com//LineageOS/android_hardware_xiaomi -b lineage-20 hardware/xiaomi
	git clone https://github.com/stuartore/android_device_xiaomi_psyche -b $1 device/xiaomi/psyche
	git clone https://gitlab.com/stuartore/android_vendor_xiaomi_psyche -b thirteen vendor/xiaomi/psyche
	git clone https://gitlab.com/stuartore/vendor_xiaomi_psyche-firmware -b thirteen vendor/xiaomi-firmware/psyche
	# void: success log commit: 4303d3f7aa90687f315726a183e416cc364d276b
	git clone --depth=1 https://github.com/VoidUI-Devices/kernel_xiaomi_sm8250.git --depth=1 -b aosp-13 kernel/xiaomi/void-aosp-sm8250

	# other
	echo 'include $(call all-subdir-makefiles)' > vendor/xiaomi-firmware/Android.mk
}

dt_bingup_superior(){
	# handle aosp_psyche
	sed -i 's/aosp_psyche/superior_psyche/g' *.mk
	sed -i 's/vendor\/aosp\/config/vendor\/superior\/config/g' aosp_psyche.mk
	sed -i 's/vendor\/aosp\/config/vendor\/superior\/config/g' BoardConfig.mk
	mv aosp_psyche.mk superior_psyche.mk
	
	# handle overlay
	overlay_custom_dir=$(find . -iname "overlay-*" | sed 's/.\///g')
	mv $overlay_custom_dir overlay-superior
	sed -i 's/overlay-aosp/overlay-superior/g' *.mk
	
	# handle parts
}

select rom_to_build in "PixelExperience 13" "Superior 13" "Crdroid 13" "RiceDroid 13"
do
	case $rom_to_build in
		"PixelExperience 13")
			dt_branch="thirteen"
			;;
		"Superior 13")
			dt_branch="superior-13"
			;;
		"Crdroid 13")
			dt_branch="crd-13"
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

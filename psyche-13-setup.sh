#!/bin/bash
# This file is generated for Xiaomi 12X (psyche)
# Please copy this script to android source root directory before running

if [[ -d build ]];then
	script_mode='ANDROID_SETUP'
elif [[ -f BoardConfig.mk ]];then
	script_mode='DT_BRINGUP'
fi

case $script_mode in
	"DT_BRINGUP")
		dt_bringup_superior
		exit 0
		;;
	"ANDROID_SETUP")
		echo
		;;
	*)
		echo "Please copy this scrpit in Android Source root directory"
		exit 1
		;;
esac

# make new mkdir
mkdir -p device/xiaomi vendor/xiaomi kernel/xiaomi

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

	# you can also use xiaomi_sm8250_devs kernel
	#git clone --depth=1 https://github.com/xiaomi-sm8250-devs/android_kernel_xiaomi_sm8250.git -b lineage-20 kernel/xiaomi/devs-sm8250

	# clang
	mkdir -p prebuilts/clang/host/linux-x86/
	git clone https://github.com/EmanuelCN/zyc_clang-14.git prebuilts/clang/host/linux-x86/ZyC-clang

	# other
	echo 'include $(call all-subdir-makefiles)' > vendor/xiaomi-firmware/Android.mk
}

dt_bringup_superior(){
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

kernel_patch(){
	# need remove 2 techpack Android.mk
	psyche_kernel_path=$(grep TARGET_KERNEL_SOURCE device/xiaomi/psyche/BoardConfig.mk | grep -v '#' | sed 's/TARGET_KERNEL_SOURCE//g' | sed 's/:=//g' | sed 's/[[:space:]]//g')

	cd $psyche_kernel_path
	rm -f techpack/data/drivers/rmnet/perf/Android.mk
	rm -f techpack/data/drivers/rmnet/shs/Android.mk	
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

kernel_patch
#psyche_deps ${dt_branch}

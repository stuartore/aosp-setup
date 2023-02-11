#!/bin/bash
# This file is generated for Xiaomi 12X (psyche)

# make new mkdir
mkdir -p device/xiaomi vendor/xiaomi kernel/xiaomi

psyche_use_common_deps(){
	# NOT AVAIABLE 

	# pull source for device/ vendor/ kernel
	# device specific dir
	mkdir -p vendor/xiaomi-firmware
	
	# pull source for device/ vendor/ kernel
	git clone https://github.com//LineageOS/android_hardware_xiaomi -b lineage-20 hardware/xiaomi
	git clone https://github.com/stuartore/device_xiaomi_psyche -b thirteen device/xiaomi/psyche
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
	git clone https://github.com/stuartore/android_device_xiaomi_psyche -b thirteen device/xiaomi/psyche
	git clone https://gitlab.com/stuartore/android_vendor_xiaomi_psyche -b thirteen vendor/xiaomi/psyche
	#git clone https://gitlab.com/stuartore/vendor_xiaomi_psyche-firmware -b thirteen vendor/xiaomi-firmware/psyche
	git clone --depth=1 https://github.com/stuartore/kernel_xiaomi_sm8250 -b thirteen kernel/xiaomi/sm8250
}

psyche_deps

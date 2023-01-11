#!/bin/bash
# This file is generated for Xiaomi 12X (psyche)

cd $HOME/aosp-setup/android/pe

# make new mkdir
mkdir -p device/xiaomi vendor/xiaomi kernel/xiaomi
# device specific dir
mkdir -p vendor/xiaomi-firmware

# pull source for device/ vendor/ kernel
git clone https://github.com/pixelexperience/hardware_xiaomi -b thirteen hardware/xiaomi
git clone https://github.com/stuartore/device_xiaomi_psyche -b thirteen device/xiaomi/psyche
git clone https://github.com/stuartore/device_xiaomi_sm8250-common -b thirteen-rebase device/xiaomi/sm8250-common
git clone https://gitlab.com/stuartore/android_vendor_xiaomi_psyche -b arrow-13.0 vendor/xiaomi/psyche
git clone https://gitlab.com/stuartore/vendor_xiaomi_sm8250-common.git -b thirteen vendor/xiaomi/sm8250-common
git clone https://gitlab.com/stuartore/vendor_xiaomi_psyche-firmware -b thirteen vendor/xiaomi-firmware/psyche
git clone https://github.com/UtsavBalar1231/kernel_xiaomi_sm8250 -b android13-stable kernel/xiaomi/sm8250

# other
echo 'include $(call all-subdir-makefiles)' > vendor/xiaomi-firmware/Android.mk

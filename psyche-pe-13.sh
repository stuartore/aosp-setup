#!/bin/bash
# This file is generated for Xiaomi 12X (psyche)
# 2023年 01月 02日 星期一 20:56:04 CST

cd /home/stuart/volume/android/pe

# make new mkdir
mkdir -p device/xiaomi vendor/xiaomi kernel/xiaomi
# device specific dir
mkdir -p vendor/xiaomi-firmware

# pull source for device/ vendor/ kernel
git clone https://github.com/pixelexperience/hardware_xiaomi -b thirteen hardware/xiaomi
git clone https://github.com/stuartore/device_xiaomi_psyche -b thirteen device/xiaomi/psyche
git clone https://github.com/stuartore/device_xiaomi_sm8250-common -b thirteen device/xiaomi/sm8250-common
git clone https://gitlab.com/stuartore/android_vendor_xiaomi_psyche -b arrow-13.0 vendor/xiaomi/psyche
git clone https://gitlab.pixelexperience.org/android/vendor-blobs/vendor_xiaomi_sm8250-common -b thirteen vendor/xiaomi/sm8250-common
git clone https://gitlab.com/stuartore/vendor_xiaomi_psyche-firmware -b thirteen vendor/xiaomi-firmware/psyche
git clone https://github.com/stuartore/kernel_xiaomi_sm8250 -b thirteen kernel/xiaomi/sm8250

# other
echo 'include $(call all-subdir-makefiles)' > vendor/${my_device_brand}/Android.mk

# ssh
sudo sed -i 's/#ClientAliveInterval 3/ClientAliveInterval 30/g' /etc/ssh/sshd_config
sudo sed -i 's/#ClientAliveCountMax 0/ClientAliveCountMax 86400/g' /etc/ssh/sshd_config
sudo systemctl restart sshd

# fix ccache error on android 12+
mkdir -p $HOME/.aosp_ccache
sudo mount --bind $HOME/.ccache $HOME/.aosp_ccache

touch $HOME/.bashrc
ccache_check=$(grep 'aosp_ccache' -l $HOME/.bashrc)
if [[ $ccache_check == "" ]];then
cat >>$HOME/.bashrc <<- CCACHELINES
export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
export CCACHE_DIR=$HOME/.aosp_ccache
ccache -M 50G -F 0
CCACHELINES
fi

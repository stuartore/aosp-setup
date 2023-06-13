#!/bin/bash

source $(dirname $0)/lang.sh

#1 which rom
#2 branch
AOSP_SETUP_ROOT=$(pwd)

declare -i env_run_last_return
declare -i env_run_time

# generated to avoid install deps repeatedly. EDIT env_run_time=3 or higher to skip install deps
env_run_last_return=0
env_run_time=0
aosp_source_dir_working=
aosp_setup_dir_check_ok=0

str_to_arr(){
	# arg 1: string
	# arg 2: split symbol
	OLD_IFS="$IFS"
	IFS="$2"
	str_to_arr_result=($1)
	IFS="$OLD_IFS"
}

######################### PATCH & FIX UNIT #########################
patch_when_low_ram(){
	# a patch that fix build on low ram PC less than 25Gb
	# at least 25GB recommended

	 get_pc_ram_raw=($(free -m | grep ${pc_mem_str}))
	 get_pc_ram=${get_pc_ram_raw[1]}
	 declare -i pc_ram
	 pc_ram=$get_pc_ram

	 get_pc_swap_ram_raw=($(free -m | sed -n '2p'))
	 get_pc_swap_ram=${get_pc_swap_ram_raw[1]}
	 declare -i pc_sawp_ram=0
	 pc_sawp_ram=$get_pc_swap_ram

	# need to patch when ram less than 25Gb
	declare -i pc_ram_patch
	pc_ram_patch=0
	if [[ $pc_ram -lt 25600 ]] && [[ $pc_sawp_ram -lt 30000 ]];then
	 	echo -e "\n\033[1;32m=>\033[0m ${auto_add_ram_str_1} ${pc_ram}${auto_add_ram_str_2} $pc_sawp_ram"
	 	pc_ram_patch=1
	else
		echo -e "\n\033[1;32m=>\033[0m RAM: ${pc_sawp_ram}Mb"
	fi

	if [[ $pc_ram_patch == 1 ]];then
		# zram swap patch
		if [[ ! -f /usr/local/sbin/zram-swap.sh ]];then
			git clone https://github.com/foundObjects/zram-swap.git ~/zram-swap
			cd ~/zram-swap && sudo ./install.sh
		fi
		cd $AOSP_SETUP_ROOT
		sudo /usr/local/sbin/zram-swap.sh stop
		sudo sed -i 's/#_zram_fixedsize="2G"/_zram_fixedsize="64G"/g' /etc/default/zram-swap
		sudo /usr/local/sbin/zram-swap.sh start
		# remove directory because do not need patch another time
		sudo rm -rf ~/zram-swap
	fi

	# more patch for cmd.BuiltTool("metalava"). locate line and add java mem when running.
	metalava_patch_file=${aosp_source_dir_working}/build/soong/java/droidstubs.go
	echo -e "\033[1;32m=>\033[0m ${patch_out_of_mem_str} $metalava_patch_file"
	if [[ -f $metalava_patch_file ]];then
		declare -i locate_metalava_0
		declare -i locate_metalava_1
		locate_metalava_0=$(grep 'cmd.BuiltTool("metalava")' -ns $metalava_patch_file | awk  -F ':' '{print $1}')
		locate_metalava_1=$(grep 'Flag(config.JavacVmFlags).' -ns $metalava_patch_file | awk  -F ':' '{print $1}')
		declare -i locate_metalava_3=$locate_metalava_1-$locate_metalava_0
		# make sure codes in the same method
		if [[ $locate_metalava_3 -le 6 ]];then
			# the second line declare the mem
			if [[ ! $(grep 'Flag("-J-Xmx' -l $metalava_patch_file) ]];then
				sed -i '/Flag(config.JavacVmFlags)./a Flag("-J-XmxMEMm")\.' $metalava_patch_file
			fi
			sed -i 's/Flag("-J-Xmx.*/Flag("-J-Xmx8192m")\./' $metalava_patch_file
		fi
		echo -e "\n\033[1;32m=>\033[0m ${patch_out_of_mem_info_str}\n"
	else
		echo -e "\n\033[1;33m=>\033[0m ${try_fix_out_of_mem_str}\n"
	fi
}

sepolicy_patch(){
	# This is a patch for diffrences between
	# 1. system/sepolicy/public |  system/sepolicy/prebuilts/api/33.0/public
	# 2. system/sepolicy/priviate  |  system/sepolicy/prebuilts/api/33.0/priviate

	cd $AOSP_SETUP_ROOT
	if [[ ! -d $aosp_source_dir_working ]];then
		return
	else
		cd ${aosp_source_dir_working}
		echo -e "\033[1;32m=>\033[0m ${fix_sepolicy_str=} : \033[1;3;36m${aosp_source_dir_working}\033[0m\n"

		if [[ -d system/sepolicy/public ]];then
			eval "$(diff system/sepolicy/public system/sepolicy/prebuilts/api/33.0/public | grep diff | sed 's/diff/cp -f/g')"
			eval "$(diff system/sepolicy/private system/sepolicy/prebuilts/api/33.0/private | grep diff | sed 's/diff/cp -f/g')"
		fi
	fi
	cd $AOSP_SETUP_ROOT
}

ssh_enlong_patch(){
        if [[ $HOSTNAME =~ 'VM' ]];then
		sudo sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 30/g' /etc/ssh/sshd_config
		sudo sed -i 's/#ClientAliveCountMax 3/ClientAliveCountMax 86400/g' /etc/ssh/sshd_config
		sudo systemctl restart sshd
	fi
}

git_fix_openssl(){
	# now ubuntu
	sudo apt-get update
	sudo apt-get install build-essential fakeroot dpkg-dev libcurl4-openssl-dev
	sudo apt-get build-dep git

	mkdir ~/git-openssl
	cd ~/git-openssl
	apt-get source git
	cd git-*
	sed -i 's/libcurl4-gnutls-dev/libcurl4-openssl-dev/g' debian/control
	sed -i '/TEST =test/ d' debian/rules
	sudo dpkg-buildpackage -rfakeroot -b
}

ccache_fix(){
	# Custom Ccache
	custom_ccache_dir=

	if [[ ! $(grep 'Generated ccache config' $HOME/.bashrc) ]];then
		default_ccache_dir=/home/$USER/.aosp_ccache
		if [[ $custom_ccache_dir == "" ]];then
			custom_ccache_dir=$default_ccache_dir
		fi
		mkdir -p /home/$USER/.ccache
		mkdir -p $custom_ccache_dir
		sudo mount --bind /home/$USER/.ccache $custom_ccache_dir
		sudo chmod -R 777 $custom_ccache_dir

		sed -i '$a \
# Generated ccache config \
export USE_CCACHE=0 \
export CCACHE_EXEC=\/usr\/bin\/ccache \
export CCACHE_DIR='"$custom_ccache_dir"' \
ccache -M 50G -F 0' $HOME/.bashrc
	fi
}

lineage_sdk_patch(){
	cd $aosp_source_dir_working
	rom_spec_str="$(basename "$(find vendor -maxdepth 3 -type f -iname "common.mk" | sed 's/config.*//g')")"

	git clone https://github.com/LineageOS/android_packages_resources_devicesettings.git -b lineage-20.0 packages/resources/devicesettings
	git clone https://github.com/LineageOS/android_hardware_lineage_interfaces -b lineage-20.0 hardware/lineage/interfaces

	# add trust usb & trust usb defaults
	rom_build_soong_bp=vendor/${rom_spec_str}/build/soong/Android.bp

	if [[ ! $(grep 'name: "trust_usb_control_defaults"' $rom_build_soong_bp) ]];then
		sed -i '1a \
trust_usb_control { \
    name: "trust_usb_control_defaults", \
    soong_config_variables: { \
        target_trust_usb_control_path: { \
            cppflags: ["-DUSB_CONTROL_PATH=\\"%s\\""], \
        }, \
        target_trust_usb_control_enable: { \
            cppflags: ["-DUSB_CONTROL_ENABLE=\\"%s\\""], \
        }, \
        target_trust_usb_control_disable: { \
            cppflags: ["-DUSB_CONTROL_DISABLE=\\"%s\\""], \
        }, \
    }, \
}' $rom_build_soong_bp
	fi

	if [[ ! $(grep 'name: "trust_usb_control"' $rom_build_soong_bp) ]];then
		sed -i '1a \
\/\/ aosp-setup: lineage sdk patch \
soong_config_module_type { \
    name: "trust_usb_control", \
    module_type: "cc_defaults", \
    config_namespace: "lineageGlobalVars", \
    value_variables: [ \
        "target_trust_usb_control_path", \
        "target_trust_usb_control_enable", \
        "target_trust_usb_control_disable", \
    ], \
    properties: ["cppflags"], \
}' $rom_build_soong_bp
	fi

	cd $AOSP_SETUP_ROOT
}

dt_str_patch(){
	# patch device tree string
	# 1 - device tree directory
	cd $aosp_source_dir_working

	rom_spec_str="$(basename "$(find vendor -maxdepth 3 -type f -iname "common.mk" | sed 's/config.*//g')")"
	dt_dir=device/$(dirname ${1})/$(basename ${1})
	if [[ ! -d $dt_dir ]];then echo -e "=> ${dt_patch_exit_str}";exit 1;fi
	cd $dt_dir
	dt_device_name="$(grep 'PRODUCT_DEVICE :=' *.mk --max-count=1 | sed 's/[[:space:]]//g' | sed 's/.*:=//g')"
	dt_main_mk=$(grep 'PRODUCT_DEVICE :=' *.mk  --max-count=1 | sed 's/[[:space:]]//g' | sed 's/:PRODUCT_DEVICE.*//g')
	dt_old_str=$(echo $dt_main_mk | sed 's/_'"${dt_device_name}"'.*//g')

	sed -i 's/'"${dt_old_str}"'/'"${rom_spec_str}"'/g' AndroidProducts.mk
	sed -i 's/'"${dt_old_str}"'/'"${rom_spec_str}"'/g' $dt_main_mk
	sed -i 's/vendor\/'"${dt_old_str}"'/vendor\/'"${rom_spec_str}"'/g' BoardConfig*.mk

	dt_new_main_mk="${rom_spec_str}_${dt_device_name}.mk"

	if [[ ! -f $dt_new_main_mk ]];then
		mv $dt_main_mk $dt_new_main_mk
	fi

}

allow_list_patch(){
	# file: build/soong/scripts/check_boot_jars/package_allowed_list.txt
	# com.oplus.os
	# oplus.content.res
	echo
}

source_webview_check(){
	#  out/host/linux-x86/bin/aapt external/chromium-webview/prebuilt/arm64/webview.apk
	echo
}	

sepolicy_error_fix(){
	# Files system/sepolicy/private/property.te and system/sepolicy/prebuilts/api/33.0/private/property.te differ
	# Failed to resolve expandtypeattribute statement at /home/ubuntu/aosp-setup/android/Project-Elixir/out/soong/.intermediates/system/sepolicy/compat/system_ext_30.0.cil/android_common/gen/system_ext_30.0.cil:1
	# 
	echo
}

other_fix(){
        # fix Disallowed PATH Tool error
        disallowed_tg_file=${aosp_source_dir}/build/sonng/ui/path/config.go

	# build continue after build error
	m api-stubs-docs-non-updatable-update-current-api && m framework-bluetooth.stubs.source-update-current-api && m system-api-stubs-docs-non-updatable-update-current-api && m test-api-stubs-docs-non-updatable-update-current-api

}

so_deps(){
	so_deps_list=($(readelf -a $1 | grep NEEDED | sed 's/.*Shared\ library://g' | sed 's/\[//g' | sed 's/\]//g' | sed 's/[[:space:]]//g' | sort))
	echo -e "\033[1;32m=>\033[0m Dep \033[4m$(basename $1)\033[0m\n"
	for so_dep in "${so_deps_list[@]}"
	do
		if [[ $(find "$(dirname $1)/.." -iname $so_dep) ]];then
			echo -e "\033[1;32m$so_dep\033[0m"

		else
			echo -e "$so_dep"
		fi
	done
	echo
}

psyche_7z_pack(){
	# pack ROM using 7z
	if [[ $aosp_source_dir_working == "" ]];then echo -e "\033[1;33m=>\033[0m ${pack_no_rom_str}";return;fi
	cd $AOSP_SETUP_ROOT
	mkdir -p ROM/tmp

	if [[ $1 == "" ]];then
		rom_out_path=${aosp_source_dir_working}/out/target/product/psyche
	else
		if [[ ! -d $1 ]];then exit 1;fi
		rom_out_path=$1/out/target/product/psyche
	fi

	if [[ -f $(dirname ${rom_out_path})/$(basename ${rom_out_path})/vbmeta_system.img ]];then
		if [[ ! -d ROM/psyche_rom_bin ]];then
			git clone https://github.com/stuartore/psyche_rom_bin.git --depth=1 ROM/psyche_rom_bin
			if [[ $? != 0 ]];then echo -e "\n\033[1;33m=>\033[0m ${no_perm_git}";exit;fi
		fi
		cp -f ${rom_out_path}/*.img ROM/tmp
		cp -rf ROM/psyche_rom_bin/* ROM/tmp
		cd ROM/tmp
		rm -f *test* *debug*
		rom_pack_name=$(basename ${aosp_source_dir_working})_psyche_Xiaomi_12X_$(date "+%Y%m%d%H%M_%q%w%S").7z
		7zr a ../${rom_pack_name} ./*
		cd ../.. && rm -rf ROM/tmp
	else
		echo -e "\033[1;33m=>\033[0m ${pack_build_not_complete_str} \033[1;33m$(basename ${aosp_source_dir_working})\033[0m"
		return
	fi

}

######################### MIRROR UNIT (OK) #########################

git_mirror_reset(){
	git_name=$(git config --global user.name)
	git_email=$(git config --global user.email)
	rm -f $HOME/.gitconfig
	git config --global user.name "${git_name}"
	git config --global user.email "${git_email}"

        # try: fix git early eof
        git config --global http.postBuffer 1048576000
        git config --global core.compression -1
        git config --global http.lowSpeedLimit 0
        git config --global http.lowSpeedTime 999999
	git config --global http.sslVerify false
}

select_mirror(){
	if [[ $(which git) == "" ]];then echo -e '\nPlease install git';exit 1;fi
	sel_github_list=('https://ghproxy.com/https://github.com' 'https://kgithub.com' 'https://hub.fgit.ml' 'https://hub.njuu.cf' 'https://hub.yzuu.cf' 'https://hub.nuaa.cf' 'https://gh.con.sh/https://github.com' 'https://ghps.cc/https://github.com' 'https://github.moeyy.xyz/https://github.com')
	sel_aosp_list=('tuna tsinghua' 'ustc' 'beijing bfsu' 'nanfang sci (not)' 'google')

	# reset before use mirror
	git_mirror_reset

	if [[ "$(command -v repo)" == "" ]];then echo;fi

	tasks=('github' 'aosp')
	for task in "${tasks[@]}"
	do
		case $task in
			github)
				## handle github.com
				echo -e "\n${choose_git_mirror_str}"
				select gm in "${sel_github_list[@]}"
				do
					if [[ $gm != "" ]];then
						echo -e "\033[1;32m=>\033[0m ${sel_is_str} $gm"
						git config --global url."${gm}".insteadof https://github.com
						case $gm in
							'https://kgithub.com')
								git config --global url.https://raw.kgithub.com.insteadof https://raw.githubusercontent.com
								;;
							'https://hub.fgit.ml')
								git config --global url.https://raw.fgit.ml.insteadof https://raw.githubusercontent.com
								;;
							'https://hub.njuu.cf')
								git config --global url.https://raw.njuu.cf.insteadof https://raw.githubusercontent.com
								;;
							'https://hub.yzuu.cf')
								git config --global url.https://raw.yzuu.cf.insteadof https://raw.githubusercontent.com
								;;
							'https://hub.nuaa.cf')
								git config --global url.https://raw.nuaa.cf.insteadof https://raw.githubusercontent.com
								;;
							*)
								git config --global url."https://gh.con.sh/https://raw.githubusercontent.com".insteadof https://raw.githubusercontent.com
								;;
						esac
					else
						echo -e "\033[1;32m=>\033[0m don't use github mirror"
					fi
					break
				done
				;;
			aosp)
				## handle AOSP
				echo -e "\n${choose_aosp_mirror_str}\n"
				select aos in "${sel_aosp_list[@]}"
				do
					case $aos in
						'tuna tsinghua')
							aom='https://mirrors.tuna.tsinghua.edu.cn/git/AOSP/'
							;;
						'ustc')
							select ustc_pro in "git" "https" "http"
							do
								aom="${ustc_pro}://mirrors.ustc.edu.cn/aosp/"
								break
							done
							;;
						'beijing bfsu')
							aom='https://mirrors.bfsu.edu.cn/git/AOSP/'
							;;
						'nanfang sci (not)')
							aom='https://mirrors.sustech.edu.cn/AOSP/'
							;;
						*)
							aom='https://android.googlesource.com'
							;;
					esac
					echo -e "\033[1;32m=>\033[0m ${sel_is_str} $aom"
					git config --global url."${aom}".insteadof https://android.googlesource.com
					break
				done
				;;
		esac
	done
}

git_and_repo_mirror_reset(){
	git_name=$(git config --global user.name)
	git_email=$(git config --global user.email)
	rm -f $HOME/.gitconfig
	git config --global user.name "${git_name}"
	git config --global user.email "${git_email}"

	# REPO URL
	export REPO_URL='https://gerrit.googlesource.com/git-repo'
}

mirror_unit_main(){
	# for aosp | git mirrors
	if [[ $keep_mirror_arg -eq 0 ]];then
		echo -e "${use_mirror_str}"
		select use_mirror_sel in "Yes" "No"
		do
			case $use_mirror_sel in
				"Yes")
					declare -i USE_GIT_AOSP_MIRROR=1
					select_mirror
					export REPO_URL='https://mirrors.tuna.tsinghua.edu.cn/git/git-repo'
					;;
				"No" | *)
					declare -i USE_GIT_AOSP_MIRROR=0
					git_and_repo_mirror_reset
					echo -e "\033[1;36m=>\033[0m ${skip_mirror_str}"
					;;
			esac
			break
		done
	else
		echo -e "\033[1;32m=>\033[0m ${keep_mirror_str}"
	fi
}

######################### DEPS UNIT #########################
ubuntu_deps(){
	sudo apt update -y
	sudo apt install software-properties-common lsb-core -y

	lsb_release="$(lsb_release -d | cut -d ':' -f 2 | sed -e 's/^[[:space:]]*//')"

	case $lsb_release in
		"Mint 18"* | "Ubuntu 16"*)
			other_pkgs="libesd0-dev"
			;;
		"Ubuntu 2"* | "Pop!_OS 2"*)
			other_pkgs="libncurses5 curl python-is-python3"
			;;
		"Debian GNU/Linux 10"* | "Debian GNU/Linux 11"*)
			other_pkgs="libncurses5"
			;;
		*)
			other_pkgs="libncurses5"
			;;
	esac

	LATEST_MAKE_VERSION="4.3"

	sudo apt install -y adb autoconf automake axel bc bison build-essential \
	    ccache clang cmake curl expat fastboot flex g++ \
	    g++-multilib gawk gcc gcc-multilib git git-lfs gnupg gperf \
 	    htop imagemagick lib32ncurses5-dev lib32z1-dev libtinfo5 libc6-dev libcap-dev \
	    libexpat1-dev libgmp-dev '^liblz4-.*' '^liblzma.*' libmpc-dev libmpfr-dev libncurses5-dev \
	    libsdl1.2-dev libssl-dev libtool libxml2 libxml2-utils '^lzma.*' lzop \
	    maven ncftp ncurses-dev patch patchelf pkg-config pngcrush \
	    pngquant python2.7 python3 android-platform-tools-base python-all-dev re2c schedtool squashfs-tools subversion \
	    texinfo unzip w3m xsltproc zip zlib1g-dev lzip p7zip p7zip-full \
	    libxml-simple-perl libswitch-perl apt-utils ${other_pkgs}

	sudo systemctl restart udev
}

arch_deps(){
	sudo sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

	if [[ ! $(grep '# aosp-setup add ustc archlinuxcn' /etc/pacman.conf) ]];then
		 sudo sed -i '$a \
\
# aosp-setup add ustc archlinuxcn \
[archlinuxcn] \
SigLevel = Optional TrustAll \
Server = https://mirrors.ustc.edu.cn/archlinuxcn/$arch \
' /etc/pacman.conf
        fi

	if [[ $env_run_time -le 2 ]];then
		sudo pacman -Sy --noconfirm archlinuxcn-keyring
	fi
	sudo pacman -Syy --noconfirm --needed git git-lfs multilib-devel fontconfig ttf-droid yay ccache make yay patch pkg-config maven gradle 
	packages=(ncurses5-compat-libs lib32-ncurses5-compat-libs aosp-devel xml2 lineageos-devel python-pip python-setuptools p7zip)
	yay -Sy --noconfirm --norebuild --noredownload ${packages[@]}
	sudo pacman -S --noconfirm --needed android-tools # android-udev
}

fedora_deps(){
	sudo dnf install -y \
		android-tools autoconf213 bison bzip2 ccache clang curl flex gawk gcc-c++ git git-lfs p7zip glibc-devel glibc-static libstdc++-static libX11-devel make mesa-libGL-devel ncurses-devel openssl patch zlib-devel ncurses-devel.i686 readline-devel.i686 zlib-devel.i686 libX11-devel.i686 mesa-libGL-devel.i686 glibc-devel.i686 libstdc++.i686 libXrandr.i686 zip perl-Digest-SHA python2 wget lzop openssl-devel java-1.8.0-openjdk-devel ImageMagick schedtool lzip vboot-utils vim

	# The package libncurses5 is not available, so we need to hack our way by symlinking the required library.
	sudo ln -s /usr/lib/libncurses.so.6 /usr/lib/libncurses.so.5
	sudo ln -s /usr/lib/libncurses.so.6 /usr/lib/libtinfo.so.5
	sudo ln -s /usr/lib64/libncurses.so.6 /usr/lib64/libncurses.so.5
	sudo ln -s /usr/lib64/libncurses.so.6 /usr/lib64/libtinfo.so.5

	sudo udevadm control --reload-rules
}

solus_deps(){
	sudo eopkg it -c system.devel
	sudo eopkg it openjdk-8-devel curl-devel git gnupg gperf libgcc-32bit libxslt-devel lzop ncurses-32bit-devel ncurses-devel readline-32bit-devel rsync schedtool sdl1-devel squashfs-tools unzip wxwidgets-devel zip zlib-32bit-devel lzip ccache

	sudo usysconf run -f
}

######################### BUILD DEVICE(POST ENV) ENV UNIT #####################
repo_check(){
	### handle git-repo
	## Decline handle git-repo because scripts do it

	if [[ "$(command -v repo)" == "" ]];then
		repo_tg_path=/usr/bin/repo
		sudo curl https://storage.googleapis.com/git-repo-downloads/repo -o $repo_tg_path --silent
		sudo chmod a+x $repo_tg_path || chmod a+x $repo_tg_path
		echo -e "\033[1;32m=>\033[0m ${repo_added_str}"
	fi

	touch $HOME/.bashrc
	if [[ ! $(grep '# android sync-helper' $HOME/.bashrc) ]];then
		cat <<BASHEOF >> $HOME/.bashrc
# android sync-helper
export REPO_URL='https://mirrors.tuna.tsinghua.edu.cn/git/git-repo'
readonly REPO_URL
BASHEOF
	fi

	### handle repo bin path
	touch $HOME/.profile
	if [[ ! $(grep '# android sync-helper' $HOME/.profile) ]];then
		cat <<PROFILEEOF >> $HOME/.profile
# android sync-helper
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi
PROFILEEOF
	fi

	### handle disconnect ssh issue
	# sudo sed -i 's/^export TMOUT=.*/export TMOUT=0/' /etc/profile && sudo sed -i "/#ClientAliveInterval/a\ClientAliveInterval 60" /etc/ssh/sshd_config && sudo sed -i "/#ClientAliveInterval/d" /etc/ssh/sshd_config && sudo sed -i '/ClientAliveCountMax/ s/^#//' /etc/ssh/sshd_config &&sudo /bin/systemctl restart sshd.service
}

adb_rules_setup(){
	if [[ ! -f /etc/udev/rules.d/51-android.rules ]];then
		sudo curl --create-dirs -L -o /etc/udev/rules.d/51-android.rules -O -L https://raw.githubusercontent.com/M0Rf30/android-udev-rules/main/51-android.rules
	fi
	sudo chmod 644 /etc/udev/rules.d/51-android.rules
	sudo chown root /etc/udev/rules.d/51-android.rules
}

deps_install_check(){
	# config install android build dependencies
	if [[ $env_run_time -lt 3 ]] || [[ $env_run_last_return -gt 0 ]];then
		env_run_time+=1
		sed -i '14s/env_run_time=./env_run_time='"${env_run_time}"'/g' $(dirname $0)/${BASH_SOURCE}
		echo "Need"
	else
		echo "NoNeed"
	fi
}

setup_build_deps(){
	#return 5
	#adb path
	if [[ $(grep 'add Android SDK platform' -ns $HOME/.bashrc) == "" ]];then
		sed -i '$a \
# add Android SDK platform tools to path \
if [ -d "$HOME/platform-tools" ] ; then \
 PATH="$HOME/platform-tools:$PATH" \
fi' $HOME/.bashrc
	fi

	# lineageos:  bc bison build-essential ccache curl flex g++-multilib gcc-multilib git gnupg gperf imagemagick lib32ncurses5-dev lib32readline-dev lib32z1-dev libelf-dev liblz4-tool libncurses5 libncurses5-dev libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev
	# Ubuntu versions older than 20.04 (focal), libwxgtk3.0-dev
	# Ubuntu versions older than 16.04 (xenial), libwxgtk2.8-dev

	if [[ "$(command -v apt)" != "" ]]; then
		ubuntu_deps
	elif [[ "$(command -v pacman)" != "" ]]; then
     		arch_deps
 	elif [[ "$(command -v yum)" != "" ]]; then
     		fedora_deps
	elif [[ "$(command -v eopkg)" != "" ]]; then
            	solus_deps
	fi

	# android adb udev rules
	if [[ ! $HOSTNAME =~ 'VM' ]];then
		adb_rules_setup
	fi
	cd $AOSP_SETUP_ROOT
}

android_env_setup(){
	# setup(install) build deps
	if [[ $1 == "Need" ]];then setup_build_deps && env_run_return=$? && sed -i '13s/env_run_last_return=./env_run_last_return='"${env_run_return}"'/g' $(dirname $0)/${BASH_SOURCE};fi

	# check repo
	repo_check

	# ssh
	ssh_enlong_patch

	#ccache fix
	ccache_fix

	# low RAM patch less than 25Gb
	patch_when_low_ram

	# fix sepolicy error
	sepolicy_patch

	# try: fix git early eof
	git config --global http.postBuffer 1048576000
	git config --global core.compression -1
	git config --global http.lowSpeedLimit 0
	git config --global http.lowSpeedTime 999999
}

######################### PRE SYNC & SYNC UNIT #########################
rom_manifest_config(){
	if [[ $1 != "" ]];then
		if [[ $1 =~ "manifest" ]] || [[ $1 =~ "android" ]] && [[ ! $1 =~ "device" ]] && [[ ! $1 =~ "vendor" ]] && [[ ! $1 =~ "kernel" ]];then
			ROM_MANIFEST=${rom_url}
		fi
	else

		#echo -e "\n${sel_rom_source_str}"
		rom_sources=("LineageOS" "ArrowOS" "Pixel Experience" "Crdroid" "AlphaDroid" "Evolution-X" "Project-Elixir" "Paranoid Android (AOSPA)" "PixysOS" "SuperiorOS" "PixelPlusUI")
		select aosp_source in "${rom_sources[@]}"
		do
			case $aosp_source in
				"LineageOS")
					ROM_MANIFEST='https://github.com/LineageOS/android.git'
					;;
				"ArrowOS")
					ROM_MANIFEST='https://github.com/ArrowOS/android_manifest.git'
					;;
				"Pixel Experience")
					ROM_MANIFEST='https://github.com/PixelExperience/manifest.git'
					;;
				"Crdroid")
					ROM_MANIFEST='https://github.com/crdroidandroid/android.git'
					;;
				"AlphaDroid")
					ROM_MANIFEST='https://github.com/AlphaDroid-Project/manifest.git'
					;;
				"Evolution-X")
					ROM_MANIFEST='https://github.com/Evolution-X/manifest.git'
					;;
				"Project-Elixir")
					ROM_MANIFEST='https://github.com/Project-Elixir/manifest.git'
					;;
				"Paranoid Android (AOSPA)")
					ROM_MANIFEST='https://github.com/AOSPA/manifest.git'
					;;
				"PixysOS")
					ROM_MANIFEST='https://github.com/PixysOS/manifest.git'
					;;
				"SuperiorOS")
					ROM_MANIFEST='https://github.com/SuperiorOS/manifest.git'
					;;
				"PixelPlusUI")
					ROM_MANIFEST='https://github.com/PixelPlusUI/manifest.git'
					;;
			esac
			break
		done
	fi
	echo ${ROM_MANIFEST}
}

handle_sync(){
	str_to_arr $1 '/'
        declare -i url_all_num
        url_all_num=${#str_to_arr_result[@]}
        os_str_num=url_all_num-2
        manifest_str_num=url_all_num-1
        rom_str=${str_to_arr_result[${os_str_num}]}
        manifest_str="$(echo ${str_to_arr_result[${manifest_str_num}]} | sed 's/.git$//g')"

	echo -e "\n\033[1;4;32m---------- ${rom_info_str} ------------\033[0m"
	echo -e "\033[1;33mROM\033[0m: $rom_str"
	echo -e "\033[1;33mmanifest\033[0m: $manifest_str"
	echo -e "\033[1;4;32m-----------------------------\033[0m"

	aosp_source_dir=android/${rom_str}
	mkdir -p $aosp_source_dir
	sed -i '15s|aosp_source_dir_working=.*|aosp_source_dir_working='"${aosp_source_dir}"'|g' $(dirname $0)/${BASH_SOURCE}

	custom_json="$(dirname $0)/${rom_str}.json"
	if [[ ! -f $custom_json ]];then
		curl https://api.github.com/repos/${rom_str}/${manifest_str}/branches -o $custom_json
	fi
	custom_branches=($(cat $custom_json | grep name | sed 's/"name"://g' | sed 's/"//g' | tr "," " "))
	echo -e "\n${rom_branch_str}"
	select custom_branch in "${custom_branches[@]}"
	do
	        # source bashrc everytime sync source
        	source $HOME/.bashrc

		cd $aosp_source_dir
		echo -e "\n\033[1;32m=>\033[0m ${enter_to_sync_str}\033[1;3;34m$(pwd)\033[0m"

		if [[ -d .repo/project-objects ]];then
			repo_init_need=0
		else
			if [[ -d .repo ]];then
				declare -i repo_init_dir_size
				repo_init_dir_raw=$(du -sm .repo | sed 's/[[:space:]]*.repo//g')
				repo_init_dir_size=$repo_init_dir_raw
				if [[ $repo_init_dir_size -lt 4 ]];then
					rm -rf .repo
					export REPO_INIT_NEED=1
				else
					export REPO_INIT_NEED=0
				fi
			else
				export REPO_INIT_NEED=1
			fi
		fi
		break
	done
	if [[ $REPO_INIT_NEED -eq 1 ]];then repo init --depth=1 -u https://github.com/${rom_str}/${manifest_str} -b $custom_branch;fi
	repo sync -c --no-clone-bundle --force-remove-dirty --optimized-fetch --prune --force-sync -j$(nproc --all)
	cd $AOSP_SETUP_ROOT
}

################# INSTRUCTION UNIT #################
instructions_help(){
	if [[ $LANG == "zh_CN.utf8" ]];then
		cat<<INSTCN
bash aosp.sh [arg]

arg:
    {ROM_manifest_url}	自定义ROM manifest同步源码
    			例: bash aosp.sh https://github.com/{ROM_USER_NAME}/manifest.git
    -k | --keep-mirror	保持镜像配置
    --recheck		再次检测英文目录环境
    
independent arg:
    --mirror 		配置git & aosp镜像
    --dt_bringup	快速为当前ROM Bringup设备树
    			例: device/xiaomi/thyme
    			    bash aosp.sh --dt_bringup xiaomi/thyme
    --lineage-sdk	如果你的设备树有Lineage libs并且当前ROM没有Lineage Sdk,可以
    			使用它. 另外应根据log对vendor/{ROM_vendor}/build/soong/Android.bp
    			增加module. 或相应的处理
    --psyche		快速同步Xiaomi 12X编译依赖
    -h | --help		说明
INSTCN
	else
		cat<<INSTEN
bash aosp.sh [arg]

arg:
    {ROM_manifest_url}	custom ROM manifest to sync
    			eg: bash aosp.sh https://github.com/{ROM_USER_NAME}/manifest.git
    -k | --keep-mirror	keep mirror configuration
    --recheck		recheck English directory for build
    
independent arg:
    --mirror 		use mirror for git & aosp
    --dt_bringup	fast bringup device tree for current rom
    			eg: bash aosp.sh --dt_bringup xiaomi/thyme
    --lineage-sdk	if your device tree have lineage libs, try to use
    			this patch. What's more, you may need to add one or
    			more module for vendor/{ROM_vendor}/build/soong/Android.bp
    --psyche		Build ROM for Xiaomi 12X.
    			Fast sync dependencies
    -h | --help		Show this instruction (help)

INSTEN
	fi
}

################# parse args #####################

all_args=$@
arg_arr=(${all_args})
rom_url=
keep_mirror_arg=0

# for global fuction
for i in "${arg_arr[@]}"
do
	case $i in
		-k | -km | --keep-mirror)
			keep_mirror_arg=1
			;;
		--recheck)
			aosp_setup_dir_check_ok=0
			;;
		https://*)
			rom_url=${i}
			;;
	esac
done

# for independent function
for i in "${arg_arr[@]}"
do
	case $i in
		-*-mirror)
			mirror_unit_main
			exit 0
			;;
		--lineage-sdk)
			lineage_sdk_patch
			exit 0
			;;
		--so-deps)
			if [[ $2 =~ ".so" ]];then
				so_deps $2
			fi
			exit 0
			;;
		--dt_bringup)
			dt_str_patch $2
			exit 0
			;;
		--psyche)
			if [[ ${aosp_source_dir_working} != "" ]];then
				dt_branch='thirteen-staging'

				cd ${aosp_source_dir_working}
				mkdir -p device/xiaomi
				git clone git@github.com:stuartore/device_xiaomi_psyche.git -b ${dt_branch} device/xiaomi/psyche --depth=1
				source build/envsetup.sh
				cd $AOSP_SETUP_ROOT
			fi
			exit 0
			;;
		--psyche-pack)
			psyche_7z_pack $2
			exit 0
			;;
		-h | --help)
			instructions_help
			exit 0
			;;
	esac
done

######################### CONFIG UNIT #########################
aosp_setup_check(){
	if [[ $1 -eq 1 ]];then return;fi

	# check directory do not have non-English words
	aosp_setup_dir_str="$(echo $AOSP_SETUP_ROOT | sed 's/[a-zA-Z]//g')"
	spec_symbol_list=('~' '`' '!' '@' '#' '$' '%' '^' '&' '-' '+' '=' '[' ']' '\' '|' '/' ':' '<' '>' '?')

	for spec_symbol in "${spec_symbol_list[@]}"
	do
		aosp_setup_dir_str="$(echo ${aosp_setup_dir_str} | sed 's|\'"$spec_symbol"'||g')"
	done
	if [[ "${aosp_setup_dir_str}" != "" ]];then
		sed -i '16s/aosp_setup_dir_check_ok=.*/aosp_setup_dir_check_ok=0/g' $(dirname $0)/${BASH_SOURCE}
		echo -e "\033[1;33m=>\033[0m Found non-English direcotory string [\033[36m${aosp_setup_dir_str}\033[0m]\n\033[1;33m=>\033[0m Suggestions: rename it in Eng."
		exit
	else
		sed -i '16s/aosp_setup_dir_check_ok=.*/aosp_setup_dir_check_ok=1/g' $(dirname $0)/${BASH_SOURCE}
	fi

	# Install deps for setup configuration
	if [[ "$(command -v curl)" == "" ]] || [[ "$(command -v git)" == "" ]];then
		if [[ "$(command -v apt)" != "" ]]; then
			if [[ "$(command -v curl)" == "" ]] || [[ "$(command -v git)" == "" ]];then
				sudo apt-get update -yq
				sudo apt-get install curl git -yq
			fi
		elif [[ "$(command -v pacman)" != "" ]]; then
			sudo pacman -Syy
			sudo pacman -Sy curl git
		elif [[ "$(command -v eopkg)" != "" ]]; then
			sudo eopkg it curl git
		fi
	fi
}

git_config_user_info(){
	# git config
	if [[ $(git config user.name) == "" ]] || [[ $(git config user.email) == "" ]];then
		echo -e "\n==> Config git "
	fi
	if [[ $(git config user.name) == "" ]];then
		read -p 'Your name: ' git_name
		git config --global user.name "${git_name}"
	fi

	if [[ $(git config user.email) == "" ]];then
		read -p 'Your email: ' git_email
		git config --global user.email "${git_email}"
	fi
}

aosp_setup_check $aosp_setup_dir_check_ok
clear

mirror_unit_main
git_config_user_info

main(){
	# android environment setup
	android_env_setup $(echo $(deps_install_check))

	# handle aosp source
	handle_sync $(echo $(rom_manifest_config ${rom_url}))

        # sync end info
        if [[ $? == "0" ]];then
                android_envsetup_file=build/envsetup.sh
                if [[ -f $aosp_source_dir/$android_envsetup_file ]];then
                	echo -e "\033[1;32m=>\033[0m ${sync_sucess_str}"
                else
                	echo -e "\033[1;32m=>\033[0m ${repo_error_str}"
                fi
        fi
}

main

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

	# Files system/sepolicy/private/property.te and system/sepolicy/prebuilts/api/33.0/private/property.te differ
	# Failed to resolve expandtypeattribute statement at /home/ubuntu/aosp-setup/android/Project-Elixir/out/soong/.intermediates/system/sepolicy/compat/system_ext_30.0.cil/android_common/gen/system_ext_30.0.cil:1
	# 

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
	# Only ccache fix when build failed
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
export USE_CCACHE=1 \
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
	git clone https://github.com/LineageOS/android_hardware_lineage_livedisplay.git -b lineage-20.0 hardware/lineage/livedisplay
	
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
	if [[ ! $1 =~ '/' ]];then echo -e "\033[1;33m=>\033[0m ${dt_bringup_name_error_str}";return;fi

	cd $aosp_source_dir_working

	rom_spec_str="$(basename "$(find vendor -maxdepth 3 -type f -iname "common.mk" | sed 's/config.*//g')")"
	dt_dir=device/$(dirname ${1})/$(basename ${1})
	cd $dt_dir
	dt_device_name="$(grep 'PRODUCT_DEVICE' *.mk --max-count=1 | sed 's/[[:space:]]//g' | sed 's/.*:=//g')"
	dt_main_mk=$(grep 'PRODUCT_DEVICE :=' *.mk  --max-count=1 | sed 's/[[:space:]]//g' | sed 's/:PRODUCT_DEVICE.*//g')
	dt_old_str=$(echo $dt_main_mk | sed 's/_.*//g')

	sed -i 's/'"${dt_old_str}"'/'"${rom_spec_str}"'/g' AndroidProducts.mk
	sed -i 's/'"${dt_old_str}"'/'"${rom_spec_str}"'/g' $dt_main_mk
	sed -i 's/vendor\/'"${dt_old_str}"'/vendor\/'"${rom_spec_str}"'/g' BoardConfig*.mk

	dt_new_main_mk="${rom_spec_str}_${dt_device_name}.mk"
	if [[ ! -f $dt_new_main_mk ]];then
		mv $dt_main_mk $dt_new_main_mk
	fi
	if [[ ! -f ${rom_spec_str}.dependencies ]];then
		mv ${dt_old_str}.dependencies ${rom_spec_str}.dependencies
	fi

	# handle parts. if there are multiple name for device settings, user need to check mannually
	if [[ -f ../../../packages/resources/devicesettings/Android.bp ]] && [[ -f parts/Android.bp ]];then
		if [[ $(grep settings.resource ../../../packages/resources/devicesettings/Android.bp | grep -c 'name:') -eq 1 ]];then
			old_parts_settings_str="$(grep settings.resources parts/Android.bp | sed 's/[[:space:]]//g')"
			new_parts_settings_str="$(grep name: ../../../packages/resources/devicesettings/Android.bp | sed 's/[[:space:]]//g' | sed 's/name://g')"
			sed -i 's/'"${old_parts_settings_str}"'/'"${new_parts_settings_str}"'/g' parts/Android.bp
		fi
	fi

	cd $AOSP_SETUP_ROOT
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

setup_patches(){
	# check repo
	repo_check

	# ssh
	ssh_enlong_patch

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

########################## ERROR HANDLING UNIT ############################
# All error fix function under AOSP Source Dir (aosp_source_dir_working)

lineage_sdk_dump_error(){
	# fix error for aleady defined Android.bp
	#sh -c "$(cat out/error.log  | grep 'already defined' | sed 's/Android.bp.*/Android.bp/g' | sed 's/.*hardware/hardware/g' | sed 's/^/rm &/g')"
	echo
}

sepolicy_differ_error_handle(){
	log_file=out/error.log
	tmp_log_file=out/aosp_setup_error.log
	sh -c "$(grep differ out/error.log | sed 's/Files/cp/g' | sed 's/and//g' | sed 's/differ//g')"
	sh -c "$(grep Command out/error.log | sed 's/Command://g')"
}

sysprop_dump_error_handle(){
	# It's maybe not perfect
	sysprop_dump_in_log=($(grep = out/error.log | grep -v 'Command:' | grep '\.'))
	sysprop_real_dump_list=($(grep = out/error.log | grep -v 'Command:' | grep '\.' | sed 's/=.*//g' | uniq))
	
}

stubs_api_error_handle(){
	source build/envsetup.sh
	m api-stubs-docs-non-updatable-update-current-api && m framework-bluetooth.stubs.source-update-current-api && m system-api-stubs-docs-non-updatable-update-current-api && m test-api-stubs-docs-non-updatable-update-current-api
}

allow_list_error_handle(){
	# file: build/soong/scripts/check_boot_jars/package_allowed_list.txt

	# base hals
	if [[ ! $(grep 'aosp-setup adds' build/soong/scripts/check_boot_jars/package_allowed_list.txt) ]];then
                sh -c "$(echo '''
# aosp-setup adds
com\.oplus\.os
com\.oplus\.os\..*
oplus\.content\.res
oplus\.content\.res\..*
vendor\.lineage\.livedisplay
vendor\.lineage\.livedisplay\..*
vendor\.lineage\.touch  
vendor\.lineage\.touch\..*
ink\.kaleidoscope
ink\.kaleidoscope\..*
''' >> build/soong/scripts/check_boot_jars/package_allowed_list.txt)"
        fi

	# some individual hal
        allow_hal="$(cat out/error.log | sed 's/build\/soong\/scripts\/check_boot_jars\/package_allowed_list.txt.*//g' | sed 's/.*whose\ package\ name//g' | sed 's/is\ empty.*//g' | sed 's/"//g' | sed 's/[[:space:]]//g')"

        allow_hal_1="$(echo $allow_hal | sed 's/\./\\./g')"
	allow_hal_2="$(echo ${allow_hal_1}\\..*)"
	echo $allow_hal_1 >> build/soong/scripts/check_boot_jars/package_allowed_list.txt
	echo $allow_hal_2 >> build/soong/scripts/check_boot_jars/package_allowed_list.txt
}

handle_build_errror(){
	# FAILED: out/soong/.intermediates/system/sepolicy/plat_policy_for_vendor.cil/android_common/plat_policy_for_vendor.cil
#out/host/linux-x86/bin/checkpolicy -C -M -c 30 -o out/soong/.intermediates/system/sepolicy/plat_policy_for_vendor.cil/android_common/plat_policy_for_vendor.cil out/soong/.intermediates/system/sepolicy/plat_policy_for_vendor.conf/android_common/plat_policy_for_vendor.conf && cat system/sepolicy/private/technical_debt.cil >>  out/soong/.intermediates/system/sepolicy/plat_policy_for_vendor.cil/android_common/plat_policy_for_vendor.cil && out/host/linux-x86/bin/secilc -m -M true -G -c 30 out/soong/.intermediates/system/sepolicy/plat_policy_for_vendor.cil/android_common/plat_policy_for_vendor.cil -o /dev/null -f /dev/null # hash of input list: 6e559a895c8d47ee372fecf016f5b2639b5d5d288a4777b8a065fc673afaa911
	#device/xiaomi/psyche/sepolicy/public/attributes:9:ERROR 'Duplicate declaration of type' at token ';' on line 6983:
	
	#ubuntu@VM-0-12-ubuntu:~/aosp-setup/android/AlphaDroid-Project$ sh -c "$(grep Command out/error.log | sed 's/Command://g')"
	#device/xiaomi/psyche/sepolicy/public/attributes:10:ERROR 'Duplicate declaration of type' at token ';' on line 7006:
#attribute hal_touchfeature_server;
#line 10

	#error: found duplicate sysprop assignments:
#persist.sys.sf.native_mode=258
#persist.sys.sf.native_mode=2

	# out/soong/.intermediates/frameworks/base/framework-minus-apex/android_common/aligned/framework-minus-apex.jar contains class file ink.kaleidoscope.ParallelSpaceManager$$ExternalSyntheticLambda0, whose package name "ink.kaleidoscope" is empty or not in the allow list build/soong/scripts/check_boot_jars/package_allowed_list.txt of packages allowed on the bootclasspath

	if [[ -f aosh.sh ]] && [[ -f lang.sh ]];then
		cd ${aosp_source_dir_working}
	fi
	local default_error_log=out/error.log

	local failed_cmd=$(grep Command out/error.log | sed 's/Command://g')
	if [[ $(grep 'Files' $default_error_log) ]] && [[ $(grep 'differ' $default_error_log) ]] && [[ $(grep 'sepolicy' $default_error_log) ]];then
		local error_type="sepolicy_differ_error"
	elif [[ $(grep 'Read-only file system' $default_error_log) ]] && [[ $(grep 'ccache:' $default_error_log) ]];then
		local error_type="ccache_readonly_error"
	elif [[ $(grep 'Duplicate declaration of type' $default_error_log) ]] && [[ $(grep 'sepolicy' $default_error_log) ]];then
		local error_type="sepolicy_dump_type_error"
	elif [[ $(grep 'duplicate sysprop' $default_error_log) ]];then
		local error_type="sysprop_dump_error"
	elif [[ $(grep 'update-current-api' $default_error_log) ]];then
		local error_type="stubs_update_api_error"
	elif [[ $(grep 'package_allowed_list.txt' $default_error_log) ]];then
		local error_type="allow_list_error"
	fi
	
	case $error_type in
		"sepolicy_differ_error")
			sepolicy_differ_error_handle
			;;
		"ccache_readonly_error")
			# It seems user still need to run command mannually
			ccache_fix
			sudo mount --bind /home/$USER/.ccache $custom_ccache_dir
			;;
		"sepolicy_dump_type_error")
			echo
			;;
		# typeattribute/ expandtypeattribute
		"sysprop_dump_error")
			sysprop_dump_error_handle
			;;
		"stubs_update_api_error")
			stubs_api_error_handle
			;;
		"allow_list_error")
			allow_list_error_handle
			;;
	esac
}

######################### MIRROR UNIT (OK) #########################
select_mirror(){
	if [[ $(which git) == "" ]];then echo -e '\nPlease install git';exit 1;fi
	sel_github_list=('https://ghproxy.com/https://github.com' 'https://kgithub.com' 'https://hub.fgit.ml' 'https://hub.njuu.cf' 'https://hub.yzuu.cf' 'https://hub.nuaa.cf' 'https://gh.con.sh/https://github.com' 'https://ghps.cc/https://github.com' 'https://github.moeyy.xyz/https://github.com')
	sel_aosp_list=('tuna tsinghua' 'ustc' 'beijing bfsu' 'nanfang sci (not)' 'google')

        while (( "$#" ))
        do
                case "$1" in
			"github")
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
			"aosp")
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
		shift
	done
}

git_aosp_repo_mirror_reset(){

	while (( "$#" )); do
		case $1 in
			"github")
				local insteadof_git_list=($(git config --global --list | grep insteadof | grep github | sed 's/insteadof=.*/insteadof/g' | sort))
				for insteadof_git in "${insteadof_git_list[@]}"
				do
					git config --global --unset ${insteadof_git}
				done
				;;
			"aosp")
				local insteadof_aosp_list=($(git config --global --list | grep insteadof | grep android | sed 's/insteadof=.*/insteadof/g' | sort))
				for insteadof_aosp in "${insteadof_aosp_list[@]}"
				do
					git config --global --unset ${insteadof_aosp}
				done
				;;
		esac
		shift
	done

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
					sel_mirror_list=$(echo $sel_mirror_list_str | sort)
					select_mirror "${sel_mirror_list[@]}"
					export REPO_URL='https://mirrors.tuna.tsinghua.edu.cn/git/git-repo'
					;;
				"No" | *)
					git_aosp_repo_mirror_reset "github" "aosp"
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

adb_rules_setup(){
	if [[ ! -f /etc/udev/rules.d/51-android.rules ]];then
		sudo curl --create-dirs -L -o /etc/udev/rules.d/51-android.rules -O -L https://raw.githubusercontent.com/M0Rf30/android-udev-rules/main/51-android.rules
	fi
	sudo chmod 644 /etc/udev/rules.d/51-android.rules
	sudo chown root /etc/udev/rules.d/51-android.rules
}

env_install_mode(){
	# config install android build dependencies
	if [[ $only_env_mode -eq 1 ]];then
		echo "OnlyEnv"
	elif [[ $env_run_time -lt 3 ]] || [[ $env_run_last_return -gt 0 ]];then
		env_run_time+=1
		sed -i '14s/env_run_time=./env_run_time='"${env_run_time}"'/g' $(dirname $0)/${BASH_SOURCE}
		echo "Need"
	else
		echo "NoNeed"
	fi
}

android_env_setup(){
	# setup(install) build deps
	mirror_unit_main
	git_config_user_info
	case $1 in
		"Need" | "OnlyEnv")
			setup_build_deps && env_run_return=$? && sed -i '13s/env_run_last_return=./env_run_last_return='"${env_run_return}"'/g' $(dirname $0)/${BASH_SOURCE}	
	esac
	setup_patches
	if [[ $1 == "OnlyEnv" ]];then exit 0;fi
}

######################### PRE SYNC & SYNC UNIT #########################
rom_manifest_config(){
	if [[ $1 != "" ]];then
		if [[ $1 =~ "manifest" ]] || [[ $1 =~ "android" ]] && [[ ! $1 =~ "device" ]] && [[ ! $1 =~ "vendor" ]] && [[ ! $1 =~ "kernel" ]];then
			ROM_MANIFEST=${aosp_manifest_url}
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

repo_sync_fail_handle(){
	# 1 - failed repo directory list

	if [[ ! -f build/envsetup.sh ]];then
		if [[ $aosp_source_dir != "" ]];then
			aosp_source_dir_working=$aosp_source_dir
		fi
		if [[ ${aosp_source_dir_working} != "" ]];then
			cd $aosp_source_dir_working
		else
			return 1
		fi
	fi

	if [[ ${1} == "" ]];then
		echo -e "\033[1;32m=>\033[0m ${repo_failed_usr_str}"
		echo "   ${repo_failed_usr_eg_str}"
		read -p '=>' repo_fail_str
	else
		repo_fail_str=""
		while [[ ${1} =~ '/' ]]
		do
			# do not pass a dangerous direcotory
			if [[ ${1:0:1} == '/' ]];then continue;fi
			repo_fail_str="${repo_fail_str} ${1}"
			shift
		done
	fi

	declare -i repo_fail_num=0
	while [[ repo_fail_num -lt 4 ]]
	do
		let repo_fail_num++

		echo -e "\033[1;32m=>\033[0m ${repo_failed_usr_str}"
		echo "   ${repo_failed_usr_eg_str}"
		read -p '=>' repo_fail_str

		repo_fail_list=($(echo ${repo_fail_str} | sort))

		# handle by log
		#declare -i repo_line_a=$(grep -n repos: t.log | awk -F ':' '{print $1}') && let repo_line_a++
		#declare -i repo_line_b=$(grep -n 'Try re-running' t.log | awk -F ':' '{print $1}') && let repo_line_b--
		#repo_fail_list=($(sed -n ''"${repo_line_a}"','"${repo_line_b}"'p' t.log | sort))

		# recheck in aosp source directory - because remove is a dangerous command
		if [[ ! -d build ]] || [[ ! -d bootable ]];then return 0;fi

		for repo_fail in "${repo_fail_list[@]}"
		do
			eval "$(grep "${repo_fail}" .repo/manifest* -r | sed 's/ /\n/g' | grep name | grep -v '/')"
			if [[ -d .repo/project-objects/${name}.git ]];then
				rm -rf .repo/project-objects/${name}.git
			else
				repo_fail_in_po_list=($(find .repo/project-objects/ -maxdepth 2 -iname "*$(echo ${repo_fail} | sed 's/\//_/g')*"))
				if [[ ! ${#repo_fail_in_po_list[@]} -eq 0 ]];then
					echo "rm -rf ${repo_fail_in_po_list[@]}"
				fi
			fi
			rm -rf .repo/projects/${repo_fail}.git
			rm -rf ${repo_fail}
		done

		return

		# synchronize again
		repo sync -c --no-clone-bundle --force-remove-dirty --optimized-fetch --prune --force-sync -j$(nproc --all) && break
		repo_fail_str=""
	done
}

handle_sync(){
	# aosp source
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
	if [[ $REPO_INIT_NEED -eq 1 ]];then yes | repo init --depth=1 -u https://github.com/${rom_str}/${manifest_str} -b $custom_branch;fi
	repo sync -c --no-clone-bundle --force-remove-dirty --optimized-fetch --prune --force-sync -j$(nproc --all) || repo_sync_fail_handle
	
	if [[ $? -eq 0 ]] && [[ -f build/envsetup.sh ]];then
		cd $AOSP_SETUP_ROOT
		return 0
	else
		cd $AOSP_SETUP_ROOT
		return 1
	fi
}

################# POST TASK UNIT #################
auto_build(){
	# 1 - brand/codename . eg: xiaomi/psyche
	
	# set defailt device xiaomi/psyche
	local brand_device=xiaomi/psyche
	if [[ -n $1 ]] && [[ $1 =~ '/' ]];then brand_device=$1;fi
	if [[ $brand_device == "xiaomi/psyche" ]];then psyche_deps;fi

	if [[ $aosp_source_dir != "" ]];then
		aosp_source_dir_working=$aosp_source_dir
	fi

	if [[ ${aosp_source_dir_working} != "" ]];then
		dt_str_patch ${brand_device}

		cd ${aosp_source_dir_working}
		AOSP_BUILD_ROOT=$(pwd)

		local rom_spec_str="$(basename "$(find vendor -maxdepth 3 -type f -iname "common.mk" | sed 's/config.*//g')")"
		local build_device=$dt_device_name
	
		repo sync -j$(nproc --all) || exit 1
		source build/envsetup.sh
		lunch "${rom_spec_str}_${build_device}-user"

		declare -i build_time=0
		while [[ $build_time -le 5 ]]
		do
			let build_time++
			m bacon -j$(nproc --all) && exit 0
			if [[ $? != 0 ]];then
				declare -i cmd_run_time=0
				build_failed_cmd=$(grep Command out/error.log | sed 's/Command://g')
				while [[ $cmd_run_time -le 6 ]]
				do
					let cmd_run_time++
					if [[ $cmd_run_time -lt 5 ]];then
						sh -c "$build_failed_cmd" && break || handle_build_errror
			      		elif [[ $cmd_run_time -eq 5 ]];then
			      			m bacon -j$(nproc --all) && exit 0 || handle_build_errror
			      		elif [[ $cmd_run_time -eq 6 ]];then
			                        echo "=> ${error_handle_mannually_str}"
			                        break
			                fi
				done
			fi
		done
	fi
}

psyche_deps(){
	if [[ $aosp_source_dir != "" ]];then
		aosp_source_dir_working=$aosp_source_dir
	fi

	if [[ ${aosp_source_dir_working} != "" ]];then
		dt_branch='thirteen-staging'

		cd ${aosp_source_dir_working}
		mkdir -p device/xiaomi
		git clone https://github.com/stuartore/device_xiaomi_psyche.git -b ${dt_branch} device/xiaomi/psyche --depth=1
		source build/envsetup.sh
		cd $AOSP_SETUP_ROOT
	fi
}

post_tasks(){
	if [[ $post_task_str == "" ]];then return;fi

	post_task_list=($(echo $post_task_str | sort))
	for post_task in "${post_task_list[@]}"
	do
		if [[ $post_task =~ "auto_build" ]];then
			post_end_task=$post_task
			continue
		fi
		eval "$(echo $post_task | sed 's/POSTSPACE/ /g')"
	done
	eval "$(echo $post_end_task | sed 's/POSTSPACE/ /g')"
}

################# INSTRUCTION UNIT #################
instructions_help(){
	if [[ $LANG =~ "zh_CN" ]];then
		cat<<INSTCN
bash aosp.sh [arg]

arg:
    {ROM_manifest_url}	自定义ROM manifest同步源码
    			例: bash aosp.sh https://github.com/{ROM_USER_NAME}/manifest.git
    -k | --keep-mirror	保持镜像配置
    --recheck		再次检测英文目录环境
    --psyche		快速同步Xiaomi 12X编译依赖
    --auto_build	尝试自动编译
			eg. bash aosp.sh --auto_build
			    bash aosp.sh --auto_build xiaomi/raphael

			 其他设备手动配置好依赖，目前xiaomi/psyche为默认

independent arg:
    --mirror 		配置git & aosp镜像
    --dt_bringup	快速为当前ROM Bringup设备树
    			例: device/xiaomi/thyme
    			    bash aosp.sh --dt_bringup xiaomi/thyme
    --lineage-sdk	如果你的设备树有Lineage libs并且当前ROM没有Lineage Sdk,可以
    			使用它. 另外应根据log对vendor/{ROM_vendor}/build/soong/Android.bp
    			增加module. 或相应的处理

    -h | --help		说明
INSTCN
	else
		cat<<INSTEN
bash aosp.sh [arg]

arg:
    {ROM_manifest_url}	custom ROM manifest to sync
    			eg: bash aosp.sh https://github.com/{ROM_USER_NAME}/manifest.git

    --recheck		recheck English directory for build
    --only-env		Only Setup Android Build Environment
    
    -k | --keep-mirror	keep mirror configuration
    --github-mirror	mannually set github mirror
    --aosp-mirror	mannually set Android Source mirror
    --reset-mirror	unset all mirrors
    
    --psyche		Build ROM for Xiaomi 12X.
    			Fast sync dependencies
    --auto_build	Try to build automaticlly
			eg. bash aosp.sh --auto_build
			    bash aosp.sh --auto_build xiaomi/raphael

			Other device need to config dependencies mannually. default: xiaomi/psyche
    
independent arg:
    --mirror 		use mirror for git & aosp
    --dt_bringup	fast bringup device tree for current rom
    			eg: bash aosp.sh --dt_bringup xiaomi/thyme
    --lineage-sdk	if your device tree have lineage libs, try to use
    			this patch. What's more, you may need to add one or
    			more module for vendor/{ROM_vendor}/build/soong/Android.bp
    -h | --help		Show this instruction (help)

INSTEN
	fi
}

################# parse args #####################

aosp_manifest_url=
declare -i keep_mirror_arg=0
declare -i only_env_mode=0
sel_mirror_list_str="github aosp"
post_task_str=""

# for global fuction
while (( "$#" )); do
	case "$1" in
		https://*)
			aosp_manifest_url=${1}
			;;
		-k | -km | --keep-mirror)
			keep_mirror_arg=1
			;;
		--recheck)
			aosp_setup_dir_check_ok=0
			;;
		--only-env)
			only_env_mode=1
			;;
		--lineage-sdk)
			# wait for sync complete and add lineage sdk
			post_task_str="${post_task_str} lineage_sdk_patch"
			;;
		--auto_build)
			shift
			post_task_str="${post_task_str} auto_buildPOSTSPACE${1}"
			;;
		--failed-repo)
			shift
			failed_repo_list_str=""
			while [[ ${1} =~ '/' ]]
			do
				failed_repo_list_str="${failed_repo_list_str} ${1}"
				if [[ ${1} =~ '--' ]];then break;fi
				shift
			done
			failed_repo_list_str_arg="$(echo $failed_repo_list_str | sed 's/ /POSTSPACE/g')"
			post_task_str="${post_task_str} repo_sync_fail_handlePOSTSPACE${failed_repo_list_str_arg}"
			;;
		--psyche)
			# wait for sync complete and clone psyche dependencies
			post_task_str="${post_task_str} psyche_deps"
			;;
		--github-mirror)
			shift
			if [[ -n "$1" ]];then
				git_aosp_repo_mirror_reset "github" "aosp"
				sel_mirror_list_str="aosp"
				custom_git_mirror="$1"
				git config --global url."${custom_git_mirror}".insteadof https://github.com
			fi
			;;
		--aosp-mirror)
			shift
			if [[ -n "$1" ]];then
				git_aosp_repo_mirror_reset "github" "aosp"
				sel_mirror_list_str="github"
				custom_aosp_mirror="$1"
				git config --global url."${custom_aosp_mirror}".insteadof https://android.googlesource.com
			fi
			;;
		--reset-mirror)
			git_aosp_repo_mirror_reset "github" "aosp"
			exit 0
			;;
		--dt_bringup)
			# wait for sync complete and bringup dt. eg. xiaomi/raphael. function with arg need to use arr[]
			shift
			post_task_str="${post_task_str} dt_str_patchPOSTSPACE${1}"
			;;
		-*-mirror)
			mirror_unit_main
			exit 0
			;;
		--so-deps)
			# get so deps - experiment
			if [[ $2 =~ ".so" ]];then
				so_deps $2
			fi
			exit 0
			;;
		-h | --help)
			instructions_help
			exit 0
			;;
	esac
	shift
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

aosp_setup_check $aosp_setup_dir_check_ok
clear

main(){
	# android environment setup
	android_env_setup $(echo $(env_install_mode))

	# handle aosp source
	handle_sync $(echo $(rom_manifest_config ${aosp_manifest_url})) && echo -e "\033[1;32m=>\033[0m ${sync_sucess_str}" || echo -e "\033[1;32m=>\033[0m  ${repo_error_str}"

        # post tasks
        post_tasks
}

main

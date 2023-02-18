#!/bin/bash

#1 which rom
#2 branch
c_dir=$(pwd)

declare -i env_run_last_return
declare -i env_run_time

# generated & record to avoid run android envsetup repeatly
env_run_last_return=0
env_run_time=0
aosp_source_dir_working=

str_to_arr(){
	# arg 1: string
	# arg 2: split symbol 
	OLD_IFS="$IFS"
	IFS="$2"
	str_to_arr_result=($1)
	IFS="$OLD_IFS"
}

android_env_setup(){
	# pre tool
	if [[ "$(command -v apt)" != "" ]]; then
		sudo apt update -y && sudo apt-get update -y
		sudo apt install android-platform-tools-base python3 -y
	elif [[ "$(command -v pacman)" != "" ]]; then
		sudo pacman -Syy
		sudo pacman -Sy make yay patch pkg-config maven gradle
	elif [[ "$(command -v eopkg)" != "" ]]; then
        	sudo eopkg it ccache
	fi
	
	#git config
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

	#repo & adb path
	if [[ $(grep 'add Android SDK platform' -ns $HOME/.bashrc) == "" ]];then
		sed -i '$a \
# add Android SDK platform tools to path \
if [ -d "$HOME/platform-tools" ] ; then \
 PATH="$HOME/platform-tools:$PATH" \
fi' $HOME/.bashrc
	fi

	if [[ $(grep 'set PATH so it includes user' -ns $HOME/.bashrc) == "" ]];then
		sed -i '$a \
# set PATH so it includes user private bin if it exists \
if [ -d "$HOME/bin" ] ; then \
    PATH="$HOME/bin:$PATH" \
fi' $HOME/.bashrc
        fi

	#repo setup
	mkdir -p $HOME/bin
	if [[ ! -f $HOME/bin/repo ]];then
		curl https://mirrors.tuna.tsinghua.edu.cn/git/git-repo -o $HOME/bin/repo
	fi
	sudo chmod a+x ~/bin/repo
	chmod a+x ~/bin/repo

	# android env from pixelexperience wiki

	# lineageos:  bc bison build-essential ccache curl flex g++-multilib gcc-multilib git gnupg gperf imagemagick lib32ncurses5-dev lib32readline-dev lib32z1-dev libelf-dev liblz4-tool libncurses5 libncurses5-dev libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev
	# Ubuntu versions older than 20.04 (focal), libwxgtk3.0-dev
	# Ubuntu versions older than 16.04 (xenial), libwxgtk2.8-dev

	cd ~/
	if [[ ! -f scripts/setup/android_build_env.sh ]];then
		git clone https://github.com/akhilnarang/scripts
	fi
	cd scripts
	if [[ "$(command -v apt)" != "" ]]; then
     		./setup/android_build_env.sh
	elif [[ "$(command -v pacman)" != "" ]]; then
     		./setup/arch-manjaro.sh
 	elif [[ "$(command -v yum)" != "" ]]; then
     		./setup/fedora.sh
	elif [[ "$(command -v eopkg)" != "" ]]; then
            ./setup/solus.sh
	fi

	# ssh
	ssh_enlong_patch

	#ccache fix
	ccache_fix
	
	# low RAM patch less than 25Gb
	patch_when_raw_ram
	
	# try: fix git early eof
	git config --global http.postBuffer 1048576000
	git config --global core.compression -1
	git config --global http.lowSpeedLimit 0
	git config --global http.lowSpeedTime 999999

        cd $c_dir
}

patch_when_raw_ram(){
	# a patch that fix build on low ram PC less than 25Gb
	# at least 25GB recommended

	 get_pc_ram_raw=($(free -m | grep 'Mem:'))
	 get_pc_ram=${get_pc_ram_raw[1]}
	 declare -i pc_ram
	 pc_ram=$get_pc_ram
	 
	 get_pc_swap_ram_raw=($(free -m | grep 'Swap:'))
	 get_pc_swap_ram=${get_pc_swap_ram_raw[1]}
	 declare -i pc_sawp_ram=0
	 pc_sawp_ram=$get_pc_swap_ram

	# need to patch when ram less than 25Gb
	declare -i pc_ram_patch
	pc_ram_patch=0
	if [[ $pc_ram -lt 25600 ]] && [[ $pc_sawp_ram -lt 30000 ]];then
	 	echo -e "\n\033[1;32m=>\033[0m Automaticly add RAM (now ${pc_ram}Mb) patch. SWAP RAM: $pc_sawp_ram"
	 	pc_ram_patch=1
	else
		echo -e "\n\033[1;32m=>\033[0m RAM: ${pc_sawp_ram}Mb"
	fi

	if [[ $pc_ram_patch == 1 ]];then
		# zram swap patch
		cd ~/
		if [[ ! -d zram-swap ]];then
			git clone https://github.com/foundObjects/zram-swap.git
		fi
		cd zram-swap && sudo ./install.sh
		cd $c_dir
		sudo /usr/local/sbin/zram-swap.sh stop
		sudo sed -i 's/#_zram_fixedsize="2G"/_zram_fixedsize="64G"/g' /etc/default/zram-swap
		sudo /usr/local/sbin/zram-swap.sh start
		# remove directory because do not need patch another time
		#sudo rm -rf ~/zram-swap
	fi
	
	# more patch for cmd.BuiltTool("metalava"). locate line and add java mem when running.
	metalava_patch_file=${aosp_source_dir_working}/build/soong/java/droidstubs.go
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
			sed -i 's/Flag("-J-Xmx.*/Flag("-J-Xmx6144m")\./' $metalava_patch_file
		fi
		echo -e "\033[1;32m=>\033[0m Fixed Ran out of memory error on low ram pc\n"
	else
		echo -e "\033[1;33m=>\033[0m Try fix memory error next run because not sync completely\n"
	fi
}

custom_sync(){
	str_to_arr $1 '/'
        declare -i url_all_num
        url_all_num=${#str_to_arr_result[@]}
        os_str_num=url_all_num-2
        manifest_str_num=url_all_num-1
        rom_str=${str_to_arr_result[${os_str_num}]}
        manifest_str="$(echo ${str_to_arr_result[${manifest_str_num}]} | sed 's/.git$//g')"

	echo -e "\n\033[1;4;32m---------- INFO ------------\033[0m"
	echo -e "\033[1;33mROM\033[0m: $rom_str"
	echo -e "\033[1;33mmanifest\033[0m: $manifest_str"
	echo -e "\033[1;4;32m-----------------------------\033[0m\n"
	
	aosp_source_dir=android/${rom_str}
	mkdir -p $aosp_source_dir
	sed -i '13s|aosp_source_dir_working=.*|aosp_source_dir_working='"${aosp_source_dir}"'|g' $(dirname $0)/${BASH_SOURCE}
	
	custom_json="$(dirname $0)/${rom_str}.json"
	if [[ ! -f $custom_json ]];then
		curl https://api.github.com/repos/${rom_str}/${manifest_str}/branches -o $custom_json
	fi
	custom_branches=($(cat $custom_json | grep name | sed 's/"name"://g' | sed 's/"//g' | tr "," " "))
	echo "Which branch you wanna sync ?"
	select custom_branch in "${custom_branches[@]}"
	do
	        # source bashrc everytime sync source
        	source $HOME/.bashrc

		cd $aosp_source_dir
		echo -e "\n\033[1;32m=>\033[0m Enter \033[1;3;34m$(pwd)\033[0m"

		if [[ -d .repo/project-objects ]];then
			repo_init_need=0
		else
			if [[ -d .repo ]];then
				declare -i repo_init_dir_size
				repo_init_dir_raw=$(du -sm .repo | sed 's/[[:space:]]*.repo//g')
				repo_init_dir_size=$repo_init_dir_raw
				if [[ $repo_init_dir_size -lt 4 ]];then
					rm -rf .repo
					repo_init_need=1
				else
					repo_init_need=0
				fi
			else
				repo_init_need=1
			fi
		fi
		if [[ $repo_init_need -eq 1 ]];then repo init -u https://github.com/${rom_str}/${manifest_str} -b $custom_branch;fi
		
		repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
		break
	done
	cd $c_dir
}

use_git_aosp_mirror(){
	if [[ -f aosp-setup/helper.sh ]];then
		helper_tg=aosp-setup/helper.sh
	elif [[ -f helper.sh ]];then
		helper_tg=helper.sh
	else
		helper_tg=''
	fi
	source $helper_tg
}

ssh_enlong_patch(){
	sudo sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 30/g' /etc/ssh/sshd_config
	sudo sed -i 's/#ClientAliveCountMax 3/ClientAliveCountMax 86400/g' /etc/ssh/sshd_config
	sudo systemctl restart sshd
}

ccache_fix(){
	# Custom Ccache
	custom_ccache_dir=

	if [[ ! $(grep 'Generated ccache config' $HOME/.bashrc) ]];then
		default_ccache_dir=/home/$USER/.aosp_ccache
		if [[ $custom_ccache_dir == "" ]];then
			custom_ccache_dir=$default_ccache_dir
		fi
		mkdir -p $custom_ccache_dir
		sudo mount --bind /home/$USER/.ccache $custom_ccache_dir
		sudo chmod -R 777 $custom_ccache_dir

		echo '''
# Generated ccache config
export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
export CCACHE_DIR='"$custom_ccache_dir"'
ccache -M 50G -F 0''' | tee -a $HOME/.bashrc
	fi
}

other_fix(){
        # fix Disallowed PATH Tool error

        disallowed_tg_file=${aosp_source_dir}/build/sonng/ui/path/config.go
}

git_mirror_reset(){
	git_name=$(git config --global user.name)
	git_email=$(git config --global user.email)
	rm -f $HOME/.gitconfig
	git config --global user.name "${git_name}"
	git config --global user.email "${git_email}"
}

handle_main(){

	# pre tool
	if [[ ! $(which git) ]] || [[ ! $(which curl) ]];then
		if [[ "$(command -v apt)" != "" ]]; then
			sudo apt install curl git -y
		elif [[ "$(command -v pacman)" != "" ]]; then
			sudo pacman -Sy curl git
		elif [[ "$(command -v yum)" != "" ]]; then
			sudo yum install -y curl git
		elif [[ "$(command -v eopkg)" != "" ]]; then
		    sudo eopkg it curl git
        	fi
	fi

	#for aosp | git mirrors
	echo "Do you wanna use git & AOSP mirror ?"
	select use_mirror_sel in "Yes" "No"
	do
		case $use_mirror_sel in
			"Yes")
				use_git_aosp_mirror
				;;
			"No")
				git_mirror_reset
				;;
			*)
				echo -e "==> Skip use mirror\n"
				;;
		esac
		break
	done
	
	#android environment setup
	if [[ env_run_last_return != 0 ]] && [[ env_run_time -lt 3 ]];then
		android_env_setup
		env_run_return=$?
		env_run_time+=1
		sed -i '11s/env_run_last_return=./env_run_last_return='"${env_run_return}"'/g' $(dirname $0)/${BASH_SOURCE}
		sed -i '12s/env_run_time=./env_run_time='"${env_run_time}"'/g' $(dirname $0)/${BASH_SOURCE}
	fi

	# Custom ROM
	if [[ $1 != "" ]];then
		if [[ $1 =~ "manifest" ]] || [[ $1 =~ "android" ]] && [[ ! $1 =~ "device" ]] && [[ ! $1 =~ "vendor" ]] && [[ ! $1 =~ "kernel" ]];then
			custom_sync $1
			return 0
		else
			cat<<EOF
Custom choice usage:

		bash aosp.sh {ROM_manifest_url}
EOF
		fi
	fi
	
	#handle aosp source
	echo "Which ROM source do you wanna sync ?"
	rom_sources=("LineageOS" "ArrowOS" "Pixel Experience" "Evolution-X" "Paranoid Android (AOSPA)" "PixysOS" "SuperiorOS" "PixelPlusUI")
	select aosp_source in "${rom_sources[@]}"
	do
		
		case $aosp_source in
			"LineageOS")
				custom_sync https://github.com/LineageOS/android.git
				;;
			"ArrowOS")
				custom_sync https://github.com/ArrowOS/android_manifest.git
				;;
			"Pixel Experience")
				custom_sync https://github.com/PixelExperience/manifest.git
				;;
			"Evolution-X")
				custom_sync https://github.com/Evolution-X/manifest.git
				;;
			"Paranoid Android (AOSPA)")
				custom_sync https://github.com/AOSPA/manifest.git
				;;
			"PixysOS")
				custom_sync https://github.com/PixysOS/manifest.git
				;;
			"SuperiorOS")
				custom_sync https://github.com/SuperiorOS/manifest.git
				;;
			"PixelPlusUI")
				custom_sync https://github.com/PixelPlusUI/manifest.git
				;;
			*)
				echo 'ROM source not added crrently. Plese use: bash aosp.sh ${ROM_manifest_url}'
				exit 1
				;;
		esac
		break
	done
	
        # sync end info
        if [[ $? == "0" ]];then
                android_envsetup_file=build/envsetup.sh
                if [[ -f $aosp_source_dir/$android_envsetup_file ]];then
                	echo -e "\033[1;32m=>\033[0m sync source \033[32msuccess\033[0m."
                else
                	echo -e "\033[1;32m=>\033[0m If you receive \033[33mrepo error\033[0m related to itself . Run it next time"
                fi       
        fi
}

handle_main $1

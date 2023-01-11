#!/bin/bash

#1 which rom
#2 branch
c_dir=$(pwd)

declare -i env_run_last_return
declare -i env_run_time

# generated & record to avoid run android envsetup repeatly
env_run_last_return=027
env_run_time=3

android_env_setup(){
	# pre tool
	
	# Fedora
	if [[ $(env | grep HOSTNAME) =~ "fedora" ]];then sudo yum install -y redhat-lsb-core;fi
	
	lsb_os=$(lsb_release -d | cut -d ':' -f 2 | sed -e 's/^[[:space:]]*//')
	if [[ ${lsb_os} =~ "Ubuntu" ]];then
		sudo apt install curl git android-platform-tools-base python3 -y
	elif [[ ${lsb_os} =~ "Manjaro" ]];then
		sudo pacman -Sy curl git
	elif [[ ${lsb_os} =~ "Fedora" ]];then
		sudo yum install -y curl git
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
	if [[ ${lsb_os} =~ "Ubuntu" ]];then
     		./setup/android_build_env.sh
  	elif [[ ${lsb_os} =~ "Manjaro" ]];then
     		./setup/arch-manjaro.sh
     	elif [[ ${lsb_os} =~ "Fedora" ]];then
     		./setup/fedora.sh
	fi

	# ssh
	ssh_enlong_patch

	#ccache fix
	ccache_fix

	cd $c_dir
	source $HOME/.bashrc
}

lineageos_sync(){
	mkdir -p android/lineage

	lineage_json="$(dirname $0)/lineage.json"
	if [[ ! -f $lineage_json ]];then
		curl https://api.github.com/repos/LineageOS/android/branches -o $lineage_json
	fi
	lineage_branches=($(cat $lineage_json | grep name | sed 's/"name"://g' | sed 's/"//g' | tr "," " "))
	echo "Which branch you wanna sync ?"
	select lineage_branch in "${lineage_branches[@]}"
	do
		cd android/lineage
		if [[ ! -d .repo ]];then
			repo init -u https://github.com/LineageOS/android.git -b $lineage_branch
		fi
		repo sync -c -j$(nproc --all) --force-sync
		break
	done
	cd $c_dir
}

arrowos_sync(){
	mkdir -p android/arrow

	arrow_json="$(dirname $0)/arrow.json"
	if [[ ! -f $arrow_json ]];then
		curl https://api.github.com/repos/ArrowOS/android_manifest/branches -o $arrow_json
	fi
	arrow_branches=($(cat $arrow_json | grep name | sed 's/"name"://g' | sed 's/"//g' | tr "," " "))
	echo "Which branch you wanna sync ?"
	select arrow_branch in "${arrow_branches[@]}"
	do
		cd android/arrow
		if [[ ! -d .repo ]];then
			repo init -u https://github.com/ArrowOS/android_manifest.git -b $arrow_branch
		fi
		repo sync -c -j$(nproc --all) --force-sync
		break
	done
	cd $c_dir
}

pixelexperience_sync(){
	mkdir -p android/pe

	pixelexperience_json="$(dirname $0)/pixelexperience.json"
	if [[ ! -f $pixelexperience_json ]];then
		curl https://api.github.com/repos/PixelExperience/manifest/branches -o $pixelexperience_json
	fi
	pe_branches=($(cat $pixelexperience_json | grep name | sed 's/"name"://g' | sed 's/"//g' | tr "," " "))
	echo "Which branch you wanna sync ?"
	select pe_branch in "${pe_branches[@]}"
	do
		cd android/pe
		if [[ ! -d .repo ]];then
			repo init -u https://github.com/PixelExperience/manifest -b $pe_branch
		fi
		repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
		break
	done
	cd $c_dir
}

evolutionx_sync(){
	mkdir -p android/evolutionx

	evolutionx_json="$(dirname $0)/evolution-x.json"
	if [[ ! -f $evolutionx_json ]];then
		curl https://api.github.com/repos/Evolution-X/manifest/branches -o $evolutionx_json
	fi
	evolutionx_branches=($(cat $evolutionx_json | grep name | sed 's/"name"://g' | sed 's/"//g' | tr "," " "))
	echo "Which branch you wanna sync ?"
	select evolutionx_branch in "${evolutionx_branches[@]}"
	do
		cd android/evolutionx
		if [[ ! -d .repo ]];then
			repo init -u https://github.com/Evolution-X/manifest.git -b $evolutionx_branch
		fi
		repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
		break
	done
	cd $c_dir
}
aospa_sync(){
	mkdir -p android/aospa

	aospa_json="$(dirname $0)/aospa.json"
	if [[ ! -f $pixelexperience_json ]];then
		curl https://api.github.com/repos/AOSPA/manifest/branches -o $aospa_json
	fi
	aospa_branches=($(cat $aospa_json | grep name | sed 's/"name"://g' | sed 's/"//g' | tr "," " "))
	echo "Which branch you wanna sync ?"
	select aospa_branch in "${aospa_branches[@]}"
	do
		cd android/aospa
		if [[ ! -d .repo ]];then
			repo init -u https://github.com/AOSPA/manifest -b $aospa_branch
		fi
		repo sync --no-clone-bundle --current-branch --no-tags -j$(nproc --all)
		break
	done
	cd $c_dir
}

pixelplusui_sync(){
	mkdir -p WORKSPACE

	ppui_json="$(dirname $0)/ppui.json"
	if [[ ! -f $ppui_json ]];then
		curl https://api.github.com/repos/PixelPlusui/manifest/branches -o $ppui_json
	fi
	ppui_branches=($(cat $ppui_json | grep name | sed 's/"name"://g' | sed 's/"//g' | tr "," " "))
	select ppui_branch in "${ppui_branches[@]}"
	do
		cd WORKSPACE
		if [[ ! -d .repo ]];then
			repo init -u https://github.com/PixelPlusUI/manifest -b tiramisu
		fi
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

git_mirror_reset(){
	git_name=$(git config --global user.name)
	git_email=$(git config --global user.email)
	rm -f $HOME/.gitconfig
	git config --global user.name "${git_name}"
	git config --global user.email "${git_email}"
}

handle_main(){
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

	#handle aosp source
	echo "Which ROM source do you wann sync ?"
	rom_sources=("LineageOS" "ArrowOS" "Pixel Experience" "Evolution-X" "Paranoid Android (AOSPA)" "PixelPlusUI")
	select aosp_source in "${rom_sources[@]}"
	do
		case $aosp_source in
			"LineageOS")
				lineageos_sync
				;;
			"ArrowOS")
				arrowos_sync
				;;
			"Pixel Experience")
				pixelexperience_sync
				;;
			"Evolution-X")
				evolutionx_sync
				;;
			"Paranoid Android (AOSPA)")
				aospa_sync
				;;
			"PixelPlusUI")
				pixelplusui_sync
				;;
			*)
				echo 'ROM source not added crrently'
				exit 1
				;;
		esac
		break
	done
}

handle_main

#!/bin/bash

# EN: If your cloud server supports and requires automatic script execution, please paste this script into the Automatic Script
#     Assistant (Manager). You may need to adjust the variables in the next section according to your needs.   
# 中文： 如果你的云服务器支持并且需要自动运行脚本，请把这个脚本粘贴到自动脚本助手（管理器）中。你可能需要根据你的需要调整下一部分的变量。

# setup git
# only used to pull android pull source
your_git_username="example"
your_git_email="example@example.com"
git_android_manifest="https://github.com/RisingTechOSS/android"
git_android_branch="thirteen"
# only if you want to use wxpusher
wxpusher_uid=""


cloud_script(){
  if [[ "$(command -v apt)" != "" ]]; then
		  sudo apt update -y && sudo apt install -y git
	elif [[ "$(command -v pacman)" != "" ]]; then
     	sudo pacman -Syu --noconfirm git
 	elif [[ "$(command -v yum)" != "" ]]; then
     	sudo yum update -y && sudo yum install -y git
	elif [[ "$(command -v eopkg)" != "" ]]; then
        sudo eopkg update -y && sudo eopkg install -y git
	fi
  git config --global user.name name
  git config --global user.email example@example.com

  # check aosp-setup
  if [[ ! -d /home/${USER}/aosp-setup ]];then git clone https://github.com/stuartore/aosp-setup.git /home/${USER}/aosp-setup;fi
  sudo chown -R ${USER}:${USER} /home/${USER}/aosp-setup
  sudo chmod -R 777 /home/${USER}/aosp-setup

  # now sync source & build
  cd /home/${USER}/aosp-setup
  ./aosp.sh -k ${git_android_manifest} ${git_android_branch} --auto_build --wxpusher_uid ${wxpusher_uid}
}

cloud_script

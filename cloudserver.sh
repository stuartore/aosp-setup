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

# optional
user_work_dir=""

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
  
  script_work_dir(){
    if [[ $HOSTNAME =~ 'VM' ]];then
      declare -i run_on_vm=1
    else
      declare -i run_on_vm=0
    fi
    
    if [[ $HOSTNAME =~ 'VM' ]] && [[ $HOSTNAME =~ 'ubuntu' ]];then
      declare -i run_on_vm=1
      work_dir=/home/ubuntu
    elif [[ $HOSTNAME =~ 'VM' ]] && [[ $HOSTNAME =~ 'ubuntu' ]];then
      declare -i run_on_vm=1
      work_dir=/root
    elif [[ $HOSTNAME =~ 'VM' ]];then
      declare -i run_on_vm=1
      work_dir=/root
    else
      work_dir=""
    fi
  
    if [[ ${work_dir} == "" ]];then
      work_dir=${user_work_dir}
      if [[ ${work_dir} == "" ]];then
        work_dir=$HOME
      fi
    fi
    echo $work_dir
  }

  # check aosp-setup
  case $LANG in
 	  "zh_CN"*)
		  git_url="https://gitee.com/stuartore/aosp-setup.git"
		  ;;
	  *)
		  git_url="https://github.com/stuartore/aosp-setup.git"
		  ;;
  esac
  work_dir=$(echo $(script_work_dir))
  if [[ ! -d ${work_dir}/aosp-setup ]];then git clone ${git_url} ${work_dir}/aosp-setup;fi
  sudo chmod -R 777 ${work_dir}/aosp-setup

  # now sync source & build
  cd ${work_dir}/aosp-setup
  ./aosp.sh -k ${git_android_manifest} ${git_android_branch} --auto_build --with_push ${wxpusher_uid}
}

cloud_script

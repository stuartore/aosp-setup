#!/bin/bash

# setup git
# only used to pull android pull source
your_git_username="example"
your_git_email="example@example.com"
git_android_manifest="https://github.com/RisingTechOSS/android"
git_android_branch="thirteen"


cloud_script(){
  sudo apt update -y
  sudo apt install -y git
  git config --global user.name name
  git config --global user.email example@example.com

  # check aosp-setup
  if [[ ! -d /home/${USER}/aosp-setup ]];then git clone https://github.com/stuartore/aosp-setup.git /home/${USER}/aosp-setup;fi
  sudo chown -R ${USER}:${USER} /home/${USER}/aosp-setup
  sudo chmod -R 777 /home/${USER}/aosp-setup

  # now sync source & build
  cd /home/${USER}/aosp-setup
  ./aosp.sh -k ${git_android_manifest} ${git_android_branch} --auto_build
}

cloud_script

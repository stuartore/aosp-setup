#!/bin/bash

# setup git
sudo apt update -y
sudo apt install -y git
git config --global user.name name
git config --global user.email email@example.com

# check aosp-setup
if [[ ! -d /home/ubuntu/aosp-setup ]];then
  git clone https://github.com/stuartore/aosp-setup.git /home/ubuntu/aosp-setup
fi
sudo chown -R ubuntu:ubuntu /home/ubuntu/aosp-setup
sudo chmod -R 777 /home/ubuntu/aosp-setup

# check ssh-key
if [[ ! -f /home/ubuntu/.ssh/id_ed25519.pub ]];then
  echo 'n' | ssh-keygen -t ed25519 -f /home/ubuntu/.ssh/id_ed25519 -N '' -q -C "ubunut@VM-ubuntu"
fi
sudo chown -R ubuntu:ubuntu /home/ubuntu/.ssh
sudo chmod -R 700 /home/ubuntu/.ssh

# add login info for profile
touch /home/ubuntu/.profile
cat>>/home/ubuntu/.profile<<BASHINFO
echo ">>> Your-key"
cat /home/ubuntu/.ssh/id_ed25519.pub
BASHINFO

# now sync source & build
cd /home/ubuntu/aosp-setup
./aosp.sh -k https://github.com/PixelExperience/manifest thirteen-plus --auto_build --auto_build --upload git@gitlab.com:example/psyche_release_aosp.git


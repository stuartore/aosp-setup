#!/bin/bash

# EN: If your cloud server supports and requires automatic script execution, please paste this script into the Automatic Script
#     Assistant (Manager). You may need to adjust the variables in the next section according to your needs.   
# 中文： 如果你的云服务器支持并且需要自动运行脚本，请把这个脚本粘贴到自动脚本助手（管理器）中。你可能需要根据你的需要调整下一部分的变量。

# setup git
# only used to pull android pull source
your_git_username="example"
your_git_email="example@example.com"
git_android_manifest="https://github.com/SuperiorOS/manifest"
git_android_branch="fifteen"
# only if you want to use wxpusher
wxpusher_uid=""

#cd $(dirname ${BASH_SOURCE[0]});bash aosp.sh -k --github-config ${your_git_username} ${your_git_email} ${git_android_manifest} ${git_android_branch} --auto_build --with_push ${wxpusher_uid}

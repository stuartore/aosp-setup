#!/bin/bash

# EN: If your cloud server supports and requires automatic script execution, please paste this script into the Automatic Script
#     Assistant (Manager). You may need to adjust the variables in the next section according to your needs and remove symbol '#' in the last line.   
# 中文： 如果你的云服务器支持并且需要自动运行脚本，请把这个脚本粘贴到自动脚本助手（管理器）中。你可能需要根据你的需要调整下一部分的变量并且取消最后一行注释'#'。

# env | only used to pull android pull source (default git configuration doesn't matter)
# 配置 ｜ 仅用于AOSP源码拉取（默认GIT配置不影响运行）
your_git_username="example"
your_git_email="example@example.com"
git_android_manifest="https://github.com/SuperiorOS/manifest"
git_android_branch="fifteen"
# only if get status on wechat (wxpusher) | 使用微信推送请配置UID_xxx (公众号wxpusher获取)
wxpusher_uid=""

# Automatically run example | 自动运行示例
#cd $(dirname ${BASH_SOURCE[0]});bash aosp.sh -k --github-config ${your_git_username} ${your_git_email} ${git_android_manifest} ${git_android_branch} --auto_build --with_push ${wxpusher_uid}

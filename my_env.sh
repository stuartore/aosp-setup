#!/bin/bash

# env | only used to pull android pull source (default git configuration doesn't matter)
# 配置 ｜ 仅用于AOSP源码拉取（默认GIT配置不影响运行）
your_git_username="example"
your_git_email="example@example.com"
git_android_manifest="https://github.com/Project-Mist-OS/manifest"
git_android_branch="15"
# only if get status on wechat (wxpusher) | 使用微信推送请配置UID_xxx (公众号wxpusher获取)
wxpusher_uid=""
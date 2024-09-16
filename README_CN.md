# AOSP setup
快速开始AOSP编译
```
git clone https://github.com/stuartore/aosp-setup.git && aosp-setup
./aosp.sh
```
> 配置环境并拉取源码

### 自定义
```
./aosp.sh ${ROM_manifest_url}

# 例子
./aosp.sh https://github.com/xxxxxxx/manifest.git

# Xiaomi 12X已适配自动编译，VPS服务器编译示例
./aosp.sh -k https://github.com/xxxxxxx/manifest.git --auto_build
```

### 镜像
```
# 设置github 和（或）aosp同步镜像
./aosp.sh --mirror

# 保留原有镜像配置
./aosp.sh --keep-mirror
```

### 自动编译
```
./aosp.sh --auto_build 品牌/设备代号

# 例子
./aosp.sh --auto_build xiaomi/psyche
```
> 实验性：仍然需要用户处理和修复出错

+ LineageOS
+ ArrowOS
+ Pixel Experience
+ Crdroid
+ AlphaDroid
+ Evolution-X
+ Project-Elixir
+ Paranoid Android (AOSPA)
+ PixysOS
+ SuperiorOS
+ PixelPlusUI

#### 运行状态推送
无人值守，[`点我`](https://wxpusher.zjiecode.com/wxuser/?type=1&id=83609#/follow)
```
# 例子， 可能需要在公众号右下方获取UID_xxxx
./aosp.sh --auto_build --with_push UID_xxxxx
```
+ 感谢@zjiecode和`wxpusher`

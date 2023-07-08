# AOSP setup
快速开始AOSP编译
```
git clone https://github.com/stuartore/aosp-setup.git
cd aosp-setup && bash aosp.sh
```
> 配置环境并拉取源码

### 自定义
```
bash aosp.sh ${ROM_manifest_url}

# 例子
bash aosp.sh https://github.com/xxxxxxx/manifest.git

# Xiaomi 12X已适配自动编译，VPS服务器编译示例
bash aosp.sh -k https://github.com/xxxxxxx/manifest.git --auto_build
```

### 镜像
```
# 设置github 和（或）aosp同步镜像
bash aosp.sh --mirror

# 保留原有镜像配置
bash aosp.sh --keep-mirror
```

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
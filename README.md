# AOSP setup
[中文](./README_CN.md)  
Quick start my aosp sync up
```
git clone https://github.com/stuartore/aosp-setup.git && cd aosp-setup
./aosp.sh
```

### Custom
```
./aosp.sh ${ROM_manifest_url}

# example
./aosp.sh https://github.com/xxxxxxx/manifest.git
```
### mirror
```
# set github & aosp mirror for synchonization
./aosp.sh --mirror

# keep mirror when sync source
./aosp.sh -k
./aosp.sh --keep-mirror
```

+ LineageOS
+ ArrowOS
+ Pixel Experience
+ RisingOS
+ Crdroid
+ AlphaDroid
+ Evolution-X
+ Project-Elixir
+ Paranoid Android (AOSPA)
+ PixysOS
+ SuperiorOS
+ PixelPlusUI

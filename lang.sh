#!/bin/bash

lang_en(){
	pc_mem_str='Mem'
	pc_swap_mem_str='Swap'

	# repo added
	repo_added_str='git-repo url added'
	repo_error_str='If you receive \033[33mrepo error\033[0m related to itself . Run it next time'
	
	# mirror str
	use_mirror_str='Do you wanna use git & AOSP mirror ?'
	choose_git_mirror_str='Choose \033[1;33mgithub\033[0m mirror ?'
	choose_aosp_mirror_str='Choose \033[1;33mAndroid source\033[0m mirror ?'
	sel_is_str='select mirror is '
	keep_mirror_str='keep mirror configuration'
	skip_mirror_str='Skip use mirror'
	
	# source synchonize str
	sel_rom_source_str='Which \033[1;33mROM source\033[0m do you wanna sync ?'
	rom_info_str='INFO'
	rom_branch_str='Which branch you wanna sync ?'
	enter_to_sync_str='Enter '
	auto_add_ram_str_1='Automaticly add RAM (now '
	auto_add_ram_str_2='Mb) patch. SWAP RAM:'
	patch_out_of_mem_str='patching'
	patch_out_of_mem_info_str='Fixed Ran out of memory error on low ram pc'
	try_fix_out_of_mem_str='Try fix memory error next run because not sync completely'
	sync_sucess_str='sync source \033[32msuccess\033[0m.'
	
	# fix sepolicy str
	fix_sepolicy_str='fixed last used prebuilt sepolicy error'

	# pack for psyche str
	no_perm_git='No permission of this repository because of \033[1;32mself-use\033[0m purpose.'
	pack_build_not_complete_str='Build not complete |'
}

lang_zh(){
	pc_mem_str='内存'
	pc_swap_mem_str='交换'

	# repo added
	repo_added_str='已添加git-repo\n'
	repo_error_str='如果你遇到\033[33mrepo\033[0m相关错误，请在下一次运行本程序'
	
	# mirror str
	use_mirror_str='你想使用Git或AOSP镜像吗 ？'
	choose_git_mirror_str='请选择\033[1;33mGithub\033[0m镜像 ？'
	choose_aosp_mirror_str='请选择\033[1;33m安卓源码\033[0m镜像？'
	sel_is_str='选择了'
	keep_mirror_str='保留原有镜像配置'
	skip_mirror_str='选择了跳过使用镜像'
	
	# source synchonize str
	sel_rom_source_str='请问你想同步哪一个\033[1;33mROM\033[0m源码？'
	rom_info_str='信息'
	rom_branch_str='请选择你想同步的分支？'
	enter_to_sync_str='进入'
	auto_add_ram_str_1='自动增加RAM （现在'
	auto_add_ram_str_2='Mb) 补丁。交换空间'
	patch_out_of_mem_str='修补了'
	patch_out_of_mem_info_str='修补了在低内存设备上编译时内存不足的错误'
	try_fix_out_of_mem_str='下次运行修复内存不足错误，因为源码没有同步完全'
	sync_sucess_str='源码已同步\033[32m成功\033[0m.'

	# fix sepolicy str
	fix_sepolicy_str='修复了最近使用的预编译sepolicy错误'

	# pack for psyche str
	no_perm_git='No permission of this repository because of \033[1;32mself-use\033[0m purpose.'
	pack_build_not_complete_str='Build not complete |'
}

case $LANG in
	"zh_CN"*)
		lang_zh
		;;
	*)
		lang_en
		;;
esac

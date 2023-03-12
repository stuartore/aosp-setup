#!/bin/bash -e

source lang.sh

git_mirror_reset(){
	git_name=$(git config --global user.name)
	git_email=$(git config --global user.email)
	rm -f $HOME/.gitconfig
	git config --global user.name "${git_name}"
	git config --global user.email "${git_email}"

        # try: fix git early eof
        git config --global http.postBuffer 1048576000
        git config --global core.compression -1
        git config --global http.lowSpeedLimit 0
        git config --global http.lowSpeedTime 999999
	git config --global http.sslVerify false
}

select_mirror(){
	if [[ $(which git) == "" ]];then echo -e '\nPlease install git';exit 1;fi
	sel_github_list=('https://ghproxy.com/https://github.com' 'https://kgithub.com' 'https://hub.njuu.cf' 'https://hub.yzuu.cf' 'https://hub.nuaa.cf' 'https://gh.con.sh/https://github.com' 'https://ghps.cc/https://github.com' 'https://github.moeyy.xyz/https://github.com')
	sel_aosp_list=('tuna tsinghua' 'ustc' 'beijing bfsu' 'nanfang sci (not)' 'google')

	# reset before use mirror
	git_mirror_reset

	tasks=('github' 'aosp')
	for task in "${tasks[@]}"
	do
		case $task in
			github)
				## handle github.com
				echo -e "\n${choose_git_mirror_str}\n"
				select gm in "${sel_github_list[@]}"
				do
					if [[ $gm != "" ]];then
						echo -e "\033[1;32m=>\033[0m ${sel_is_str} $gm"
						git config --global url."${gm}".insteadof https://github.com
					else
						echo -e "\033[1;32m=>\033[0m don't use github mirror"
					fi
					break
				done
				;;
			aosp)
				## handle AOSP
				echo -e "\n${choose_aosp_mirror_str}\n"
				select aos in "${sel_aosp_list[@]}"
				do
					case $aos in
						'tuna tsinghua')
							aom='https://mirrors.tuna.tsinghua.edu.cn/git/AOSP/'
							;;
						'ustc')
							select ustc_pro in "git" "https" "http"
							do
								aom="${ustc_pro}://mirrors.ustc.edu.cn/aosp/"
								break
							done
							;;
						'beijing bfsu')
							aom='https://mirrors.bfsu.edu.cn/git/AOSP/'
							;;
						'nanfang sci (not)')
							aom='https://mirrors.sustech.edu.cn/AOSP/'
							;;
						*)
							aom='https://android.googlesource.com'
							;;
					esac
					echo -e "\033[1;32m=>\033[0m ${sel_is_str} $aom"
					git config --global url."${aom}".insteadof https://android.googlesource.com
					break
				done
				;;
		esac
	done
}

more_end_info(){
	source $HOME/.bashrc
	source $HOME/.profile
	if [[ $(git config --get user.name) == "" ]];then
	cat<<EOF

You may run to start using git:

    git config --global user.email "you@example.com"
    git config --global user.name "Your Name"

EOF
	fi
}
select_mirror
more_end_info

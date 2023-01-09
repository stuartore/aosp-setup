#!/bin/bash -e

git_mirror_reset(){
	git_name=$(git config --global user.name)
	git_email=$(git config --global user.email)
	rm -f $HOME/.gitconfig
	git config --global user.name "${git_name}"
	git config --global user.email "${git_email}"
}

non_freedom(){
### handle git-repo
mkdir -p ~/bin
if [[ ! -f $HOME/bin/repo ]];then
	curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
	sudo chmod a+x ~/bin/repo || chmod a+x ~/bin/repo
fi

touch $HOME/.bashrc
if [[ ! $(grep '# android sync-helper' $HOME/.bashrc) ]];then
	cat <<BASHEOF >> $HOME/.bashrc
# android sync-helper
export REPO_URL='https://mirrors.tuna.tsinghua.edu.cn/git/git-repo'
readonly REPO_URL
BASHEOF
fi
echo "==> git-repo url added"

### handle repo bin path
touch $HOME/.profile
if [[ ! $(grep '# android sync-helper' $HOME/.profile) ]];then
	cat <<PROFILEEOF >> $HOME/.profile
# android sync-helper
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi
PROFILEEOF
echo "==> bin path added"
fi

### handle disconnect ssh issue
# sudo sed -i 's/^export TMOUT=.*/export TMOUT=0/' /etc/profile && sudo sed -i "/#ClientAliveInterval/a\ClientAliveInterval 60" /etc/ssh/sshd_config && sudo sed -i "/#ClientAliveInterval/d" /etc/ssh/sshd_config && sudo sed -i '/ClientAliveCountMax/ s/^#//' /etc/ssh/sshd_config &&sudo /bin/systemctl restart sshd.service
}

select_mirror(){
	if [[ $(which git) == "" ]];then echo -e '\nPlease install git';exit 1;fi
	sel_github_list=('https://ghproxy.com/https://github.com' 'https://kgithub.com' 'https://hub.njuu.cf' 'https://hub.yzuu.cf' 'https://hub.nuaa.cf' 'https://github.moeyy.xyz/https://github.com')
	sel_aosp_list=('tuna tsinghua' 'ustc' 'beijing bfsu' 'nanfang sci' 'google')

	# reset before use mirror
	git_mirror_reset

	tasks=('github' 'aosp')
	for task in "${tasks[@]}"
	do
		case $task in
			github)
				## handle github.com
				echo -e "\nChoose \033[1;33mgithub\033[0m mirror ?\n"
				select gm in "${sel_github_list[@]}"
				do
					if [[ $gm != "" ]];then
						echo -e "\033[1;32m=>\033[0m sel is $gm"
						git config --global url."${gm}".insteadof https://github.com
					else
						echo -e "\033[1;32m=>\033[0m don't use github mirror"
					fi
					break
				done
				;;
			aosp)
				## handle AOSP
				echo -e "\nChoose \033[1;33mAndroid source\033[0m mirror ?\n"
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
						'nanfang sci')
							aom='https://mirrors.sustech.edu.cn/AOSP'
							;;
						*)
							aom='https://android.googlesource.com'
							;;
					esac
					echo -e "\033[1;32m=>\033[0m select mirror is $aom"
					git config --global url."${aom}".insteadof https://android.googlesource.com
					break
				done
				;;
		esac
	done
}

other_mirror(){
	# repo use REPO_URL in $HOME/.bashrc if use mirror. defualt: tuna
	repo_modi_tg=${HOME}/scripts/setup/android_build_env.sh
	if [[ $aom != 'https://android.googlesource.com' ]];then
		sed -i 's/https:\/\/storage.googleapis.com\/git-repo-downloads\/repo/$REPO_URL/g' $repo_modi_tg
		sed -i 's/raw.githubusercontent.com/raw.kgithub.com/g' $repo_modi_tg
	fi
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
non_freedom
select_mirror
other_mirror
more_end_info

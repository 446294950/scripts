#!/usr/bin/env bash
#author:spark
#需要docker环境,下载本文件到容器内任意位置,以下示例是放到了/jd/scripts
#举个栗子,我们要拉取大佬i-chenzhe的qx脚本仓库,则在计划任务内添加以下任务(半小时拉取一次,时间自定):
###-> */30 * * * *  /bin/bash /jd/scripts/git_diy.sh  i-chenzhe  qx     <-###
#只拉取仓库下指定的文件夹,多个用逗号隔开,dira,dirb
###-> */30 * * * *  /bin/bash /jd/scripts/git_diy.sh  i-chenzhe  qx "dira,dirb"     <-###
#或者添加到到diy.sh最后一行即可,跟随pull的频率,不过pull的频率远远跟不上柘大佬的节奏!
#脚本每次运行会检测脚本内的定时任务是否更新,如果有自定义脚本执行时间,不想随脚本更新,请在脚本计划任务后>添加注释 #nochange
#如果仓库内有不想执行的脚本,注释即可!
#群文件sendinfo.js sendinfo.sh两个文件请放到scripts映射目录下,如没有,则没有通知消息

#操作之前请备份,信息丢失,概不负责.
#操作之前请备份,信息丢失,概不负责.
#操作之前请备份,信息丢失,概不负责.

declare -A BlackListDict
author=$1
repo=$2
dirs=$3

#私仓更新,秘钥放在/jd/diyscripts/sshkey/目录下,并已作者名字命名
#[ -f /jd/diyscripts/sshkey/$author ] && chmod 600 /jd/diyscripts/sshkey/$author &&  export GIT_SSH_COMMAND="ssh -i /jd/diyscripts/sshkey/$author"
[ -f /jd/diyscripts/sshkey/$author ] && chmod 600 /jd/diyscripts/sshkey/$author && eval `ssh-agent -s` && ssh-add /jd/diyscripts/sshkey/$author
[ `grep -c github.com ~/.ssh/known_hosts` -eq 0 ] && ssh-keyscan github.com >> ~/.ssh/known_hosts



#指定仓库屏蔽关键词,不添加计划任务,多个按照格式二
BlackListDict['monk-coder']="_get|backup"
BlackListDict['sparkssssssss']="smzdm|tg|xxxxxxxx"
BlackListDict['3028']="jd_daojia_bean"
BlackListDict['yangtingxiao']="jdCookie|example"

blackword=${BlackListDict["${author}"]}
blackword=${blackword:-"wojiushigejimo"}

if [ $# -lt 2 ] && [ $# -gt 3 ] ; then
  echo "USAGE: $0 author repo         #for all repo"
  echo "USAGE: $0 author repo  dir    #for special dir of the repo"
  exit 0;
fi

diyscriptsdir=/jd/diyscripts
mkdir -p ${diyscriptsdir}

if [ ! -d "$diyscriptsdir/${author}_${repo}" ]; then
  echo -e "${author}本地仓库不存在,从gayhub拉取ing..."
  if [ ! -f /jd/diyscripts/sshkey/$author ];then
    cd ${diyscriptsdir} &&  git clone https://github.com/${author}/${repo}.git ${author}_${repo}
  else
    cd ${diyscriptsdir} &&  git clone git@github.com:${author}/${repo}.git ${author}_${repo}
  fi
  gitpullstatus=$?
  [ $gitpullstatus -eq 0 ] && echo -e "${author}本地仓库拉取完毕"
  [ $gitpullstatus -ne 0 ] && echo -e "${author}本地仓库拉取失败,请检查!" && exit 0
else
  cd ${diyscriptsdir}/${author}_${repo}
  branch=`git symbolic-ref --short -q HEAD`
  git fetch --all
  git reset --hard origin/$branch
  git pull
  gitpullstatus=$?
fi

rand(){
    min=$1
    max=$(($2-$min+1))
    num=$(cat /proc/sys/kernel/random/uuid | cksum | awk -F ' ' '{print $1}')
    echo $(($num%$max+$min))
}

function addnewcron {
  local addname=""
  if [ ! -z $dir ];then
    dirname=$(echo $dir|sed 's#/##g')	   
    cd ${diyscriptsdir}/${author}_${repo}/$dir
    local author=${author}_${dirname}
  else
    cd ${diyscriptsdir}/${author}_${repo}
  fi
  [ $(grep -c "#${author}" /jd/config/crontab.list) -eq 0 ] && sed -i "/#diy/i#${author}"  /jd/config/crontab.list
  
  for jspath in `ls *.js|egrep -v $blackword`; 
  #for jspath in `find ./ -name  "*.js"|egrep -v $blackword`; 
  #for js in `ls *.js|egrep -v $blackword`;
    do 
      newflag=0
      js=`echo $jspath|awk -F'/' '{print $NF}'` 
      croname=`echo "${author}_$js"|awk -F\. '{print $1}'`
      script_date=`cat  $js|grep ^[0-9]|awk '{print $1,$2,$3,$4,$5}'|egrep -v "[a-zA-Z]|:|\."|sort |uniq|head -n 1`
      #[ -z "${script_date}" ] && script_date=`cat  $jspath|grep -Eo "([0-9]+|\*|[0-9]+[,-].*) ([0-9]+|\*|[0-9]+[,-].*) ([0-9]+|\*|[0-9]+[,-].*) ([0-9]+|\*|[0-9]+[,-].*) ([0-9]+|\*|[0-9][,-].*)"|sort |uniq|head -n 1`
      [ -z "${script_date}" ] && cron_min=$(rand 1 59) && cron_hour=$(rand 7 9) && script_date="${cron_min} ${cron_hour} * * *"
      [ $(grep -c -w "$croname" /jd/config/crontab.list) -eq 0 ] && sed -i "/#${author}/a${script_date} bash jd $croname"  /jd/config/crontab.list && addname="${addname}\n${croname}" && echo -e "添加了新的脚本${croname}." && newflag=1 
      [ $newflag -eq 1 ] && bash jd ${croname} now >/dev/null &


      if [ $(egrep -v "^#|nochange" /jd/config/crontab.list|grep -c -w "$croname" ) -eq 1 ];then
          old_script_date=$(grep -w "$croname" /jd/config/crontab.list|awk '{print $1,$2,$3,$4,$5}')
	  [ "${old_script_date}" != "${script_date}" ] && sed -i "/\<bash jd $croname\>/d" /jd/config/crontab.list && sed -i "/#${author}/a${script_date} bash jd $croname"  /jd/config/crontab.list
      fi

      if [ ! -f "/jd/scripts/${author}_$js" ];then
        \cp $jspath /jd/scripts/${author}_$js
      else
        change=$(diff $jspath /jd/scripts/${author}_$js)
        [ ! -z "${change}" ] && \cp $jspath /jd/scripts/${author}_$js && echo -e "${author}_$js 脚本更新了."

      fi
  done
  [ "$addname" != "" ] && [ -f "/jd/scripts/sendinfo.sh" ] && /bin/bash  /jd/scripts/sendinfo.sh "${author}新增自定义脚本" "${addname}"

}

function delcron {
  local delname=""
  if [ ! -z $dir ];then
    dirname=$(echo $dir|sed 's#/##g')
    local jspath=${diyscriptsdir}/${author}_${repo}/$dir
    local author=${author}_${dirname}
  else
    jspath=${diyscriptsdir}/${author}_${repo}
  fi
  cronfiles=$(grep "$author" /jd/config/crontab.list|grep -v "^#"|awk '{print $8}'|awk -F"${author}_" '{print $2}')
  for filename in $cronfiles;
    do
	    if [ ! -f "$jspath/${filename}.js" ] || [ ! -z $(echo $filename|egrep  $blackword) ] ; then 
        sed -i "/\<bash jd ${author}_${filename}\>/d" /jd/config/crontab.list && echo -e "删除失效脚本${filename}."
	delname="${delname}\n${author}_${filename}"
      fi
  done
  [ "$delname" != "" ] && [ -f "/jd/scripts/sendinfo.sh" ] && /bin/bash  /jd/scripts/sendinfo.sh  "${author}删除失效脚本" "${delname}" 
}

if [[ ${gitpullstatus} -eq 0 ]]
then
  if [ ! -z "$dirs" ] ;then
    for dir in `echo "$dirs" | sed 's/,/\n/g'`
    do
      addnewcron
      delcron
    done
  else
    addnewcron
    delcron
  fi
else
  echo -e "$author 仓库更新失败了."
  [ -f "/jd/scripts/sendinfo.sh" ] && /bin/bash  /jd/scripts/sendinfo.sh "自定义仓库更新失败" "$author"
fi

exit 0

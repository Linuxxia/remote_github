#/bin/bash 
#
#server status check
export LANG=en_US.UTF-8
db_user='fml_yw'
db_password='J5+%pDaVnj>2'
num=2
check_num=2
ip=`curl ip.cip.cc`
function check_info
{
	#获取服务GSID
	check_port=$(ls -F /data/server/ |grep '/$' |grep '^fml' |awk -F '/' '{print $1}'|awk -F '_' '{print $4}' | xargs |sed s/" "/","/g)
	#获取服务信息
	mysql_info=$(/usr/local/mysql/bin/mysql -h 54.223.130.112 -u$db_user -p$db_password -P3306 -N -e "SELECT gsid,port,backendPort,rechargeHttpPort,externalip,name from fml_serverlist.configdb where gsId in ($check_port) and ismerged=0 and monitor=1")
	if [ $? != 0 ] && [ $num -gt 0 ];then
		sleep 10
		let num=$num-1
		echo $num
		check_info
	fi
	if [ $num -gt 0 ];then
		return 0
	else
		echo "`date +%Y-%m-%d_%H:%M:%S` yunweiDB connection failed！！！" >> /data/log/connection_failed.log
		return 1
	fi	
}

function check_process
{
	moitor_dir=/data/log
	[ ! -d $moitor_dir ] && mkdir $moitor_dir
	echo "$mysql_info" |while read line
	do
		gsid=`echo "$line" |awk '{print $1}'`
		port=`echo "$line" |awk '{print $2}'`
		backendPort=`echo "$line" |awk '{print $3}'`
		rechargeHttpPort=`echo "$line" |awk '{print $4}'`
		externalip=`echo "$line" |awk '{print $5}'`
		name=`echo "$line" |awk '{print $6}'`
		num=0
		num_port=0
		num_backendPort=0
		num_rechargeHttpPort=0
		if [ ! "$ip" == "$externalip" ];then
			exit
		fi
		netstat -ntlp |grep "$port" > /dev/null
		[ ! "$?" == 0  ] && let num+=1 && num_port=1
		netstat -ntlp |grep "$backendPort" > /dev/null
		[ ! "$?" == 0  ] && let num+=1 && num_backendPort=1
	        netstat -ntlp |grep "$rechargeHttpPort" > /dev/null
        	[ ! "$?" == 0  ] && let num+=1 && num_rechargeHttpPort=1
		if [ "$num" -gt 0 ] && [ "$check_num" -gt 0 ];then
			sleep 5
			let check_num=$check_num-1
			echo "$check_num"
			check_info
			if [ $? == 0 ];then
        			echo 'start check process'
        			check_process
			else
				exit
			fi
		fi
		if [ "$num" == 3 ];then
			curl message.haowan123.com/sms/?group='fml'\&content="$name gsid_$gsid down IP:$externalip"
		elif [ "$num" == 0 ];then
			echo "`date +%Y-%m-%d_%H:%M:%S` $gsid status is success" >> /data/log/check_status.log
		else
			if [ "$num_port" == 1 ];then
				curl message.haowan123.com/sms/?group='fml'\&content="$name gsid_$gsid GamePort $port down please check !!! IP:$externalip"
			fi
			if [ "$num_backendPort" == 1 ];then
				curl message.haowan123.com/sms/?group='fml'\&content="$name gsid_$gsid GMPort $backendPort down please check !!!! IP: $externalip"
                	fi
			if [ "$num_rechargeHttpPort" == 1 ];then
				curl message.haowan123.com/sms/?group='fml'\&content="$name gsid_$gsid RechargeHttpPort $rechargeHttpPort down please check !!!! IP:$externalip"
                	fi

		fi
		
	done
	exit 0
}
check_info
if [ $? == 0 ];then
	echo 'start check process'
	check_process
fi


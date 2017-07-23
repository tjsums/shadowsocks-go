#! /bin/bash
#===============================================================================================
#   System Required:  debian or ubuntu (32bit/64bit)
#   Description:  Install Shadowsocks(go) for Debian or Ubuntu
#   Author: tennfy <admin@tennfy.com>
#   Intro:  http://www.tennfy.com
#===============================================================================================
export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
clear
echo '-----------------------------------------------------------------'
echo '   Install Shadowsocks(go) for debian or ubuntu (32bit/64bit) '
echo '   Intro:  http://www.tennfy.com                                 '
echo '   Author: tennfy <admin@tennfy.com>                             '
echo '-----------------------------------------------------------------'

#Variables
ShadowsocksType='shadowsocks-go'
ShadowsocksDir='/opt/shadowsocks'
GoDir='/opt/goenv'

#Version
ShadowsocksVersion=''
GolangVersion='1.3'

#ciphers
Ciphers=(
chacha20
rc4-md5
aes-256-cfb   
)

#color
CEND="\033[0m"
CMSG="\033[1;36m"
CFAILURE="\033[1;31m"
CSUCCESS="\033[32m"
CWARNING="\033[1;33m"

function Die()
{
	echo -e "${CFAILURE}[Error] $1 ${CEND}"
	exit 1
}
function CheckSanity()
{
	# Do some sanity checking.
	if [ $(/usr/bin/id -u) != "0" ]
	then
		Die 'Must be run by root user'
	fi

	if [ ! -f /etc/debian_version ]
	then
		Die "Distribution is not supported"
	fi
}
function GetDebianVersion()
{
	if [ -f /etc/debian_version ]
	then
		local main_version=$1
		local debian_version=`cat /etc/debian_version|awk -F '.' '{print $1}'`
		if [ "${main_version}" == "${debian_version}" ]
		then
		    return 0
		else 
			return 1
		fi
	else
		Die "Distribution is not supported"
	fi    	
}
function GetSystemBit()
{
	ldconfig
	if [ $(getconf WORD_BIT) = '32' ] && [ $(getconf LONG_BIT) = '64' ] 
	then
		if [ '64' = $1 ]; then
		    return 0
		else
		    return 1
		fi			
	else
		if [ '32' = $1 ]; then
		    return 0
		else
		    return 1
		fi		
	fi
}
function CheckServerPort()
{
    if [ $1 -ge 1 ] && [ $1 -le 65535 ]
	then 
	    return 0
	else
	    return 1
	fi
}
function GetLatestShadowsocksVersion()
{
	local shadowsocksurl=`curl -s https://api.github.com/repos/shadowsocks/${ShadowsocksType}/releases/latest | grep tag_name | cut -d '"' -f 4`
	
	if [ $? -ne 0 ]
	then
	    Die "Get latest shadowsocks version failed!"
	else
	    ShadowsocksVersion=`echo $shadowsocksurl`
	fi
}
function InstallGoEnvironment() 
{
    #create go directory
	if [ -d ${GoDir} ]
	then 
	    rm -rf ${GoDir}
	fi
	mkdir ${GoDir}
	
    #install go environment
    if GetSystemBit 64; then
	    wget --no-check-certificate http://golang.org/dl/go${GolangVersion}.linux-amd64.tar.gz 
	    tar xf go${GolangVersion}.linux-amd64.tar.gz -C ${GoDir}
	    rm go${GolangVersion}.linux-amd64.tar.gz
    else
	    wget --no-check-certificate http://golang.org/dl/go${GolangVersion}.tar.gz 
	    tar xf go${GolangVersion}.linux-386.tar.gz -C ${GoDir}
	    rm go${GolangVersion}.linux-386.tar.gz
    fi

    #set go environment variables
	echo "export GOROOT=${GoDir}/go" >> ~/.profile
	echo "PATH=\$PATH:\$GOROOT/bin" >> ~/.profile
	source ~/.profile
	
	echo "export GOPATH=${ShadowsocksDir}/packages/${ShadowsocksType}" >> ~/.profile
	echo "PATH=\$PATH:\$GOPATH/bin" >> ~/.profile
	source ~/.profile
}

function InstallShadowsocksCore() 
{
    #install
    apt-get update
    apt-get install -y --force-yes git mercurial curl
	
    #get latest shadowsocks-libev release version
	GetLatestShadowsocksVersion
		
    #download shadowsocks-go
    wget --no-check-certificate https://github.com/shadowsocks/shadowsocks-go/releases/download/${ShadowsocksVersion}/shadowsocks-server.tar.gz
    tar zxvf shadowsocks-server.tar.gz -C ${ShadowsocksDir}/packages
	rm -f shadowsocks-server.tar.gz
	
	mkdir ${ShadowsocksDir}/packages/shadowsocks-go
	mv ${ShadowsocksDir}/packages/shadowsocks-server ${ShadowsocksDir}/packages/shadowsocks-go/shadowsocks-server 
    chmod +x ${ShadowsocksDir}/packages/shadowsocks-go/shadowsocks-server 

    #create configuration directory
	mkdir -p /etc/${ShadowsocksType}
	
cat > /etc/init.d/${ShadowsocksType}<<-"EOF"
#!/bin/bash
# Start/stop shadowsocks.
#
### BEGIN INIT INFO
# Provides:          shadowsocks
# Required-Start:
# Required-Stop:
# Should-Start:
# Should-Stop:
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: shadowsocks is a lightweight tunneling proxy
# Description:       Modified from Linode's nginx fastcgi startup script
### END INIT INFO
# Note: this script requires sudo in order to run shadowsocks as the specified
# user.
PATH=/sbin:/usr/sbin:/bin:/usr/bin            
LOG_FILE=/var/log/$NAME.log             
PID_DIR=/var/run
PID_FILE=$PID_DIR/$NAME.pid
USER=root
GROUP=root  
RET_VAL=0
[ -x $BIN ] || exit 0
check_running() {
  if [[ -r $PID_FILE ]]; then
    read PID <$PID_FILE
    if [[ -d "/proc/$PID" ]]; then
      return 0
    else
      rm -f $PID_FILE
      return 1
    fi
  else
    return 2
  fi
}
do_status() {
  check_running
  case $? in
    0)
      echo "$NAME running with PID $PID"
      ;;
    1)
      echo "$NAME not running, remove PID file $PID_FILE"
      ;;
    2)
      echo "Could not find PID file $PID_FILE, $NAME does not appear to be running"
      ;;
  esac
  return 0
}
do_start() {
  if [[ ! -d $PID_DIR ]]; then
    echo "creating PID dir"
    mkdir $PID_DIR || echo "failed creating PID directory $PID_DIR"; exit 1
    chown $USER:$GROUP $PID_DIR || echo "failed creating PID directory $PID_DIR"; exit 1
    chmod 0770 $PID_DIR
  fi
  if check_running; then
    echo "shadowsocks already running with PID $PID"
    return 0
  fi
  if [[ ! -r $CONFIG_FILE ]]; then
    echo "config file $CONFIG_FILE not found"
    return 1
  fi
  echo "starting $NAME"
  # sudo will set the group to the primary group of $USER
  $BIN -c $CONFIG_FILE -u>>$LOG_FILE &
  PID=$!
  echo $PID > $PID_FILE
  sleep 0.3
  if ! check_running; then
    echo "start failed"
    return 1
  fi
  echo "$NAME running with PID $PID"
  return 0
}
do_stop() {
  if check_running; then
    echo "stopping $NAME with PID $PID"
    kill $PID
    rm -f $PID_FILE
  else
    echo "Could not find PID file $PID_FILE"
  fi
}
do_restart() {
  do_stop
  do_start
}
case "$1" in
  start|stop|restart|status)
    do_$1
    ;;
  *)
    echo "Usage: $NAME {start|stop|restart|status}"
    RET_VAL=1
    ;;
esac
exit $RET_VAL
EOF
    sed -i "/PATH=/a\NAME=${ShadowsocksType}" /etc/init.d/${ShadowsocksType}
    sed -i "/PATH=/a\CONFIG_FILE=\/etc\/${ShadowsocksType}\/config.json" /etc/init.d/${ShadowsocksType}
    sed -i "/PATH=/a\BIN=${ShadowsocksDir}\/packages/shadowsocks-go\/shadowsocks-server" /etc/init.d/${ShadowsocksType}
    chmod +x /etc/init.d/${ShadowsocksType}
}
function UninstallShadowsocksCore()
{
    #stop shadowsocks-go process
	ps -ef | grep -v grep | grep -v ps | grep -i "shadowsocks-server" > /dev/null 2>&1
	if [ $? -eq 0 ]; then 
	   /etc/init.d/${ShadowsocksType} stop
	fi

	#uninstall shadowsocks-libev
	update-rc.d -f ${ShadowsocksType} remove 

	#uninstall shadowsocks-go
	rm -rf ${ShadowsocksDir}

	#delete config file
	rm -rf /etc/${ShadowsocksType}

	#delete shadowsocks-go init file
	rm -f /etc/init.d/${ShadowsocksType}
}
function Init()
{	
	cd /root
	
    #create packages and conf directory
	if [ -d ${ShadowsocksDir} ]
	then 
	    rm -rf ${ShadowsocksDir}	
	fi
	mkdir ${ShadowsocksDir}
	mkdir ${ShadowsocksDir}/packages
	mkdir ${ShadowsocksDir}/conf

	#init system
	CheckSanity
}
############################### install function##################################
function InstallShadowsocks()
{
	#initialize
    Init
	
    #install shadowsocks core program
	InstallShadowsocksCore
	
    # Get IP address(Default No.1)	
    ip=`curl -s checkip.dyndns.com | cut -d' ' -f 6  | cut -d'<' -f 1`
    if [ -z $ip ]; then
        ip=`curl -s ifconfig.me/ip`
    fi

    #config setting
	clear
    echo '-----------------------------------------------------------------'
    echo '          Please setup your shadowsocks server                   '
    echo '-----------------------------------------------------------------'
    echo ''
	#input server port
	while :
	do
        read -p "input server port(443 is default): " server_port
		[ -z "$server_port" ] && server_port=443
        if CheckServerPort $(($server_port))
		then
		    break
		else
		    echo -e "${CFAILURE}[Error] The server port should be between 1 to 65535! ${CEND}"
		fi
	done
	
	echo ''
	echo '-----------------------------------------------------------------'
	echo ''
	
	#select encrypt method
	while :
	do
		echo 'Please select encrypt method:'
        i=1
		for var in "${Ciphers[@]}"
		do
            echo -e "\t${CMSG}${i}${CEND}. ${var}"
			let i++
        done
		read -p "Please input a number:(Default 1 press Enter) " encrypt_method_num
		[ -z "$encrypt_method_num" ] && encrypt_method_num=1
		if [[ ! $encrypt_method_num =~ ^[1-${#Ciphers[@]}]$ ]]
		then
			echo -e "${CWARNING} input error! Please only input number 1~${#Ciphers[@]} ${CEND}"
		else
			encrypt_method=${Ciphers[$(let $encrypt_method_num -1)]}			
			break
		fi
	done
	
	echo ''
	echo '-----------------------------------------------------------------'
	echo ''
	while :
	do
        read -p "input password: " shadowsocks_pwd
	    if [ -z ${shadowsocks_pwd} ]; then
		    echo -e "${CFAILURE}[Error] The password is null! ${CEND}"
		else
            break
		fi
	done	
         

	echo ''
	echo '-----------------------------------------------------------------'
	echo ''

    #config shadowsocks
cat > /etc/${ShadowsocksType}/config.json<<-EOF
{
    "server":"${ip}",
    "server_port":${server_port},
    "local_port":1080,
    "password":"${shadowsocks_pwd}",
    "timeout":60,
    "method":"${encrypt_method}"
}
EOF

    #add system startup
    update-rc.d ${ShadowsocksType} defaults

    #start service
    /etc/init.d/${ShadowsocksType} start

    #if failed, start again --debian8 specified
    if [ $? -ne 0 ]
	then
    #failure indication
	    echo ''
        echo '-----------------------------------------------------------------'
		echo ''
        echo -e "${CFAILURE}Sorry, shadowsocks-libev install failed!${CEND}"
        echo -e "${CFAILURE}Please contact with admin@tennfy.com${CEND}"
		echo ''
		echo '-----------------------------------------------------------------'
    else	
        #success indication
		echo ''
        echo '-----------------------------------------------------------------'
		echo ''
        echo -e "${CSUCCESS}Congratulations, ${ShadowsocksType} install completed!${CEND}"
        echo -e "Your Server IP: ${ip}"
        echo -e "Your Server Port: ${server_port}"
        echo -e "Your Password: ${shadowsocks_pwd}"
        echo -e "Your Local Port: 1080"
        echo -e "Your Encryption Method:${encrypt_method}"
		echo ''
		echo '-----------------------------------------------------------------'
    fi
}
############################### uninstall function##################################
function UninstallShadowsocks()
{
    UninstallShadowsocksCore
    echo -e "${CSUCCESS}${ShadowsocksType} uninstall success!${CEND}"
}
############################### update function##################################
function UpdateShadowsocks()
{
    UninstallShadowsocks
    InstallShadowsocks
    echo -e "${CSUCCESS}${ShadowsocksType} update success!${CEND}"
}
############################### Initialization##################################
action=$1
[ -z $1 ] && action=install
case "$action" in
install)
    InstallShadowsocks
    ;;
uninstall)
    UninstallShadowsocks
    ;;
update)
    UpdateShadowsocks
    ;;	
*)
    echo "Arguments error! [${action} ]"
    echo "Usage: `basename $0` {install|uninstall|update}"
    ;;
esac

#! /bin/bash
#===============================================================================================
#   System Required:  Debian or Ubuntu (32bit/64bit)
#   Description:  Install Shadowsocks(go) for Debian or Ubuntu
#   Author: tennfy <admin@tennfy.com>
#   Intro:  http://www.tennfy.com
#===============================================================================================

clear
echo "#############################################################"
echo "# Install Shadowsocks(go) for Debian or Ubuntu (32bit/64bit)"
echo "# Intro: http://www.tennfy.com"
echo "#"
echo "# Author: tennfy <admin@tennfy.com>"
echo "#"
echo "#############################################################"
echo ""
function check_sanity {
	# Do some sanity checking.
	if [ $(/usr/bin/id -u) != "0" ]
	then
		die 'Must be run by root user'
	fi

	if [ ! -f /etc/debian_version ]
	then
		die "Distribution is not supported"
	fi
}

function die {
	echo "ERROR: $1" > /dev/null 1>&2
	exit 1
}

function install_go_environment() {

#install go environment
ldconfig
if [ $(getconf WORD_BIT) = '32' ] && [ $(getconf LONG_BIT) = '64' ] ; then
	wget --no-check-certificate http://golang.org/dl/go1.3.linux-amd64.tar.gz 
	tar xf go1.3.linux-amd64.tar.gz
	rm go1.3.linux-amd64.tar.gz
else
	wget --no-check-certificate http://golang.org/dl/go1.3.linux-386.tar.gz 
	tar xf go1.3.linux-386.tar.gz
	rm go1.3.linux-386.tar.gz
fi

echo "export GOROOT=\$HOME/go" >> ~/.profile
echo "PATH=$PATH:\$GOROOT/bin" >> ~/.profile
source ~/.profile
mkdir ~/gocode
echo "export GOPATH=\$HOME/gocode" >> ~/.profile
echo "PATH=\$PATH:\$GOPATH/bin" >> ~/.profile
source ~/.profile

}

function install_shadowsocks_go() {
#download shadowsocks-go

go get github.com/shadowsocks/shadowsocks-go/cmd/shadowsocks-server

chmod +x /root/gocode/bin/shadowsocks-server

# Get IP address(Default No.1)
IP=`curl -s checkip.dyndns.com | cut -d' ' -f 6  | cut -d'<' -f 1`
if [ -z $IP ]; then
   IP=`curl -s ifconfig.me/ip`
fi

#config setting
echo "#############################################################"
echo "#"
echo "# Please input your shadowsocks server_port and password"
echo "#"
echo "#############################################################"
echo ""
echo "input server_port(443 is suggested):"
read serverport
echo "input password:"
read shadowsockspwd

# Config shadowsocks
cat > /root/gocode/bin/config.json<<-EOF
{
    "server":"${IP}",
    "server_port":${serverport},
    "local_port":1080,
    "password":"${shadowsockspwd}",
    "timeout":60,
    "method":"rc4-md5"
}
EOF

cat > /etc/init.d/shadowsocks<<-"EOF"
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

BIN=/root/gocode/bin/shadowsocks-server
CONFIG_FILE=/root/gocode/bin/config.json
LOG_FILE=/var/log/shadowsocks
USER=root
GROUP=root
PID_DIR=/var/run
PID_FILE=$PID_DIR/shadowsocks.pid
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
      echo "shadowsocks running with PID $PID"
      ;;
    1)
      echo "shadowsocks not running, remove PID file $PID_FILE"
      ;;
    2)
      echo "Could not find PID file $PID_FILE, shadowsocks does not appear to be running"
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
  echo "starting shadowsocks"
  # sudo will set the group to the primary group of $USER
  sudo -u $USER $BIN -c $CONFIG_FILE >>$LOG_FILE &
  PID=$!
  echo $PID > $PID_FILE
  sleep 0.3
  if ! check_running; then
    echo "start failed"
    return 1
  fi
  echo "shadowsocks running with PID $PID"
  return 0
}

do_stop() {
  if check_running; then
    echo "stopping shadowsocks with PID $PID"
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
    echo "Usage: shadowsocks {start|stop|restart|status}"
    RET_VAL=1
    ;;
esac

exit $RET_VAL
EOF

chmod +x /etc/init.d/shadowsocks

#start
/etc/init.d/shadowsocks start

#start with boot
update-rc.d shadowsocks defaults

#install successfully
    echo ""
    echo "Congratulations, shadowsocks-go install completed!"
    echo -e "Your Server IP: ${IP}"
    echo -e "Your Server Port: ${serverport}"
    echo -e "Your Password: ${shadowsockspwd}"
    echo -e "Your Local Port: 1080"
    echo -e "Your Encryption Method:rc4-md5"

}
############################### install function##################################
function install_shadowsocksgo_tennfy(){

# Make sure only root can run our script
check_sanity

# install
apt-get update
apt-get install -y --force-yes git mercurial curl

cd $HOME

#install go environment
install_go_environment

install_shadowsocks_go
}
############################### uninstall function##################################
function uninstall_shadowsocksgo_tennfy(){

#stop shadowsocks-go process
ps -ef | grep -v grep | grep -v ps | grep -i "shadowsocks-server" > /dev/null 2>&1
if [ $? -eq 0 ]; then 
   /etc/init.d/shadowsocks stop
fi

#uninstall shadowsocks-go
rm -f /root/gocode/bin/shadowsocks-server

# delete config file
rm -rf /root/gocode/bin/config.json

# delete shadowsocks-go init file
rm -f /etc/init.d/shadowsocks

#delete start with boot
update-rc.d -f shadowsocks remove

echo "Shadowsocks-go uninstall success!"

}
############################### update function##################################
function update_shadowsocksgo_tennfy(){
     uninstall_shadowsocksgo_tennfy
     
	 cd $HOME
	 
	 install_shadowsocks_go
	 
	 echo "Shadowsocks-go update success!"
}
# Initialization
action=$1
[  -z $1 ] && action=install
case "$action" in
install)
    install_shadowsocksgo_tennfy
    ;;
uninstall)
    uninstall_shadowsocksgo_tennfy
    ;;
update)
    update_shadowsocksgo_tennfy
    ;;	
*)
    echo "Arguments error! [${action} ]"
    echo "Usage: `basename $0` {install|uninstall|update}"
    ;;
esac

#!/bin/bash
export LANG=en_US.UTF-8
sred='\033[5;31m'
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;36m'
bblue='\033[0;34m'
plain='\033[0m'
red(){ echo -e "\033[31m\033[01m$1\033[0m";}
green(){ echo -e "\033[32m\033[01m$1\033[0m";}
yellow(){ echo -e "\033[33m\033[01m$1\033[0m";}
blue(){ echo -e "\033[36m\033[01m$1\033[0m";}
white(){ echo -e "\033[37m\033[01m$1\033[0m";}
readp(){ read -p "$(yellow "$1")" $2;}
[[ $EUID -ne 0 ]] && yellow "请以root模式运行脚本" && exit
stty erase $'\b' 2>/dev/null || stty erase '^H' 2>/dev/null
#[[ -e /etc/hosts ]] && grep -qE '^ *172.65.251.78 gitlab.com' /etc/hosts || echo -e '\n172.65.251.78 gitlab.com' >> /etc/hosts
if [[ -f /etc/redhat-release ]]; then
release="Centos"
elif cat /etc/issue | grep -q -E -i "alpine"; then
release="alpine"
elif cat /etc/issue | grep -q -E -i "debian"; then
release="Debian"
elif cat /etc/issue | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
elif cat /proc/version | grep -q -E -i "debian"; then
release="Debian"
elif cat /proc/version | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
else 
red "不支持当前的系统，请选择使用Ubuntu,Debian,Centos系统。" && exit
fi
vsid=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)
op=$(cat /etc/redhat-release 2>/dev/null || cat /etc/os-release 2>/dev/null | grep -i pretty_name | cut -d \" -f2)
#if [[ $(echo "$op" | grep -i -E "arch|alpine") ]]; then
if [[ $(echo "$op" | grep -i -E "arch") ]]; then
red "脚本不支持当前的 $op 系统，请选择使用Ubuntu,Debian,Centos系统。" && exit
fi
version=$(uname -r | cut -d "-" -f1)
[[ -z $(systemd-detect-virt 2>/dev/null) ]] && vi=$(virt-what 2>/dev/null) || vi=$(systemd-detect-virt 2>/dev/null)
case $(uname -m) in
aarch64) cpu=arm64;;
x86_64) cpu=amd64;;
*) red "目前脚本不支持$(uname -m)架构" && exit;;
esac

if [[ -n $(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk -F ' ' '{print $3}') ]]; then
bbr=`sysctl net.ipv4.tcp_congestion_control | awk -F ' ' '{print $3}'`
elif [[ -n $(ping 10.0.0.2 -c 2 | grep ttl) ]]; then
bbr="Openvz版bbr-plus"
else
bbr="Openvz/Lxc"
fi

if [ ! -f xuiyg_update ]; then
green "首次安装x-ui-yg脚本必要的依赖……"
if [[ x"${release}" == x"alpine" ]]; then
apk update
apk add wget curl tar jq iptables tzdata openssl busybox-extras expect git socat iproute2 coreutils util-linux 
apk add virt-what
else
if [[ $release = Centos && ${vsid} =~ 8 ]]; then
cd /etc/yum.repos.d/ && mkdir backup && mv *repo backup/ 
curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-8.repo
sed -i -e "s|mirrors.cloud.aliyuncs.com|mirrors.aliyun.com|g " /etc/yum.repos.d/CentOS-*
sed -i -e "s|releasever|releasever-stream|g" /etc/yum.repos.d/CentOS-*
yum clean all && yum makecache
cd
fi

if [ -x "$(command -v apt-get)" ]; then
apt update -y
apt install jq tzdata socat cron busybox iptables-persistent coreutils util-linux -y
elif [ -x "$(command -v yum)" ]; then
yum update -y && yum install epel-release -y
yum install jq tzdata busybox socat coreutils util-linux -y
elif [ -x "$(command -v dnf)" ]; then
dnf update -y
dnf install jq tzdata busybox socat coreutils util-linux -y
fi
if [ -x "$(command -v yum)" ] || [ -x "$(command -v dnf)" ]; then
if ! command -v "cronie" &> /dev/null; then
if [ -x "$(command -v yum)" ]; then
yum install -y cronie
elif [ -x "$(command -v dnf)" ]; then
dnf install -y cronie
fi
fi
fi

packages=("curl" "openssl" "tar" "expect" "xxd" "python3" "wget" "git")
inspackages=("curl" "openssl" "tar" "expect" "xxd" "python3" "wget" "git")
for i in "${!packages[@]}"; do
package="${packages[$i]}"
inspackage="${inspackages[$i]}"
if ! command -v "$package" &> /dev/null; then
if [ -x "$(command -v apt-get)" ]; then
apt-get install -y "$inspackage"
elif [ -x "$(command -v yum)" ]; then
yum install -y "$inspackage"
elif [ -x "$(command -v dnf)" ]; then
dnf install -y "$inspackage"
fi
fi
done
fi
touch xuiyg_update
fi

if [[ $vi = openvz ]]; then
TUN=$(cat /dev/net/tun 2>&1)
if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ '处于错误状态' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]]; then 
red "检测到未开启TUN，现尝试添加TUN支持" && sleep 4
cd /dev && mkdir net && mknod net/tun c 10 200 && chmod 0666 net/tun
TUN=$(cat /dev/net/tun 2>&1)
if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ '处于错误状态' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]]; then 
green "添加TUN支持失败，建议与VPS厂商沟通或后台设置开启" && exit
else
echo '#!/bin/bash' > /root/tun.sh && echo 'cd /dev && mkdir net && mknod net/tun c 10 200 && chmod 0666 net/tun' >> /root/tun.sh && chmod +x /root/tun.sh
grep -qE "^ *@reboot root bash /root/tun.sh >/dev/null 2>&1" /etc/crontab || echo "@reboot root bash /root/tun.sh >/dev/null 2>&1" >> /etc/crontab
green "TUN守护功能已启动"
fi
fi
fi
argopid(){
ym=$(cat /usr/local/x-ui/xuiargoympid.log 2>/dev/null)
ls=$(cat /usr/local/x-ui/xuiargopid.log 2>/dev/null)
}
v4v6(){
v4=$(curl -s4m5 icanhazip.com -k)
v6=$(curl -s6m5 icanhazip.com -k)
v4dq=$(curl -s4m5 -k https://myip.ipip.net | awk -F'来自于：' '{print $2}' 2>/dev/null)
#v4dq=$(curl -s4m5 -k https://ip.fm | sed -n 's/.*Location: //p' 2>/dev/null)
v6dq=$(curl -s6m5 -k https://ip.fm | sed -n 's/.*Location: //p' 2>/dev/null)
}
warpcheck(){
wgcfv6=$(curl -s6m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
wgcfv4=$(curl -s4m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
}

v6(){
warpcheck
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
v4=$(curl -s4m5 icanhazip.com -k)
if [ -z $v4 ]; then
yellow "检测到 纯IPV6 VPS，添加nat64"
echo -e "nameserver 2a00:1098:2b::1\nnameserver 2a00:1098:2c::1" > /etc/resolv.conf
fi
fi
}

serinstall(){
green "下载并安装x-ui相关组件……"
cd /usr/local/
#curl -L -o /usr/local/x-ui-linux-${cpu}.tar.gz --insecure https://gitlab.com/rwkgyg/x-ui-yg/raw/main/x-ui-linux-${cpu}.tar.gz
curl -L -o /usr/local/x-ui-linux-${cpu}.tar.gz -# --retry 2 --insecure https://github.com/yonggekkk/x-ui-yg/releases/download/xui_ygb/x-ui-linux-${cpu}.tar.gz
tar zxvf x-ui-linux-${cpu}.tar.gz > /dev/null 2>&1
rm x-ui-linux-${cpu}.tar.gz -f
cd x-ui
chmod +x x-ui bin/xray-linux-${cpu}
cp -f x-ui.service /etc/systemd/system/ >/dev/null 2>&1
systemctl daemon-reload >/dev/null 2>&1
systemctl enable x-ui >/dev/null 2>&1
systemctl start x-ui >/dev/null 2>&1
cd
rm /usr/bin/x-ui -f
#curl -L -o /usr/bin/x-ui --insecure https://gitlab.com/rwkgyg/x-ui-yg/raw/main/1install.sh >/dev/null 2>&1
curl -L -o /usr/bin/x-ui -# --retry 2 --insecure https://raw.githubusercontent.com/yonggekkk/x-ui-yg/beta/install.sh
chmod +x /usr/bin/x-ui
if [[ x"${release}" == x"alpine" ]]; then
echo '#!/sbin/openrc-run
name="x-ui"
command="/usr/local/x-ui/x-ui"
directory="/usr/local/${name}"
pidfile="/var/run/${name}.pid"
command_background="yes"
depend() {
need networking 
}' > /etc/init.d/x-ui
chmod +x /etc/init.d/x-ui
rc-update add x-ui default
rc-service x-ui start
fi
if [[ -f /usr/bin/x-ui && -f /usr/local/x-ui/bin/xray-linux-${cpu} ]]; then
green "下载成功"
else
red "下载失败，请检测VPS网络是否正常，脚本退出"
if [[ x"${release}" == x"alpine" ]]; then
rc-service x-ui stop
rc-update del x-ui default
rm /etc/init.d/x-ui -f
else
systemctl stop x-ui
systemctl disable x-ui
rm /etc/systemd/system/x-ui.service -f
systemctl daemon-reload
systemctl reset-failed
fi
rm /usr/bin/x-ui -f
rm /etc/x-ui-yg/ -rf
rm /usr/local/x-ui/ -rf
rm -rf xuiyg_update
exit
fi
}

userinstall(){
readp "设置 x-ui 登录用户名（回车跳过为随机6位字符）：" username
sleep 1
if [[ -z ${username} ]]; then
username=`date +%s%N |md5sum | cut -c 1-6`
fi
while true; do
if [[ ${username} == *admin* ]]; then
red "不支持包含有 admin 字样的用户名，请重新设置" && readp "设置 x-ui 登录用户名（回车跳过为随机6位字符）：" username
else
break
fi
done
sleep 1
green "x-ui登录用户名：${username}"
echo
readp "设置 x-ui 登录密码（回车跳过为随机6位字符）：" password
sleep 1
if [[ -z ${password} ]]; then
password=`date +%s%N |md5sum | cut -c 1-6`
fi
while true; do
if [[ ${password} == *admin* ]]; then
red "不支持包含有 admin 字样的密码，请重新设置" && readp "设置 x-ui 登录密码（回车跳过为随机6位字符）：" password
else
break
fi
done
sleep 1
green "x-ui登录密码：${password}"
/usr/local/x-ui/x-ui setting -username ${username} -password ${password} >/dev/null 2>&1
}

portinstall(){
echo
readp "设置 x-ui 登录端口[1-65535]（回车跳过为10000-65535之间的随机端口）：" port
sleep 1
if [[ -z $port ]]; then
port=$(shuf -i 10000-65535 -n 1)
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") && -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] 
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") || -n $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义端口:" port
done
else
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") && -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") || -n $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义端口:" port
done
fi
sleep 1
/usr/local/x-ui/x-ui setting -port $port >/dev/null 2>&1
green "x-ui登录端口：${port}"
}

pathinstall(){
echo
readp "设置 x-ui 登录根路径（回车跳过为随机3位字符）：" path
sleep 1
if [[ -z $path ]]; then
path=`date +%s%N |md5sum | cut -c 1-3`
fi
/usr/local/x-ui/x-ui setting -webBasePath ${path} >/dev/null 2>&1
green "x-ui登录根路径：${path}"
}

showxuiip(){
xuilogin(){
v4v6
if [[ -z $v4 ]]; then
echo "[$v6]" > /usr/local/x-ui/xip
elif [[ -n $v4 && -n $v6 ]]; then
echo "$v4" > /usr/local/x-ui/xip
echo "[$v6]" >> /usr/local/x-ui/xip
else
echo "$v4" > /usr/local/x-ui/xip
fi
}
warpcheck
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
xuilogin
else
systemctl stop wg-quick@wgcf >/dev/null 2>&1
kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
xuilogin
systemctl start wg-quick@wgcf >/dev/null 2>&1
systemctl restart warp-go >/dev/null 2>&1
systemctl enable warp-go >/dev/null 2>&1
systemctl start warp-go >/dev/null 2>&1
fi
}

resinstall(){
echo "----------------------------------------------------------------------"
restart
#curl -sL https://gitlab.com/rwkgyg/x-ui-yg/-/raw/main/version/version | awk -F "更新内容" '{print $1}' | head -n 1 > /usr/local/x-ui/v
curl -sL https://raw.githubusercontent.com/yonggekkk/x-ui-yg/main/version | awk -F "更新内容" '{print $1}' | head -n 1 > /usr/local/x-ui/v
showxuiip
sleep 2
xuigo
cronxui
echo "----------------------------------------------------------------------"
blue "x-ui-yg $(cat /usr/local/x-ui/v 2>/dev/null) 安装成功，自动进入 x-ui 显示管理菜单" && sleep 4
echo
show_menu
}

xuiinstall(){
v6
echo "----------------------------------------------------------------------"
openyn
echo "----------------------------------------------------------------------"
serinstall
echo "----------------------------------------------------------------------"
userinstall
portinstall
pathinstall
mkdir -p /root/ygkkkcaz
curl -Ls -o /root/ygkkkcaz/private.key https://github.com/yonggekkk/argosbx/releases/download/argosbx/private.key
curl -Ls -o /root/ygkkkcaz/cert.crt https://github.com/yonggekkk/argosbx/releases/download/argosbx/cert.crt
resinstall
#[[ -e /etc/gai.conf ]] && grep -qE '^ *precedence ::ffff:0:0/96  100' /etc/gai.conf || echo 'precedence ::ffff:0:0/96  100' >> /etc/gai.conf 2>/dev/null
}

update() {
yellow "升级也有可能出意外哦，建议如下："
yellow "一、点击x-ui面版中的备份与恢复，下载备份文件x-ui-yg.db"
yellow "二、在 /etc/x-ui-yg 路径导出备份文件x-ui-yg.db"
readp "确定升级，请按回车(退出请按ctrl+c):" ins
if [[ -z $ins ]]; then
if [[ x"${release}" == x"alpine" ]]; then
rc-service x-ui stop
else
systemctl stop x-ui
fi
serinstall && sleep 2
restart
#curl -sL https://gitlab.com/rwkgyg/x-ui-yg/-/raw/main/version/version | awk -F "更新内容" '{print $1}' | head -n 1 > /usr/local/x-ui/v
curl -sL https://raw.githubusercontent.com/yonggekkk/x-ui-yg/main/version | awk -F "更新内容" '{print $1}' | head -n 1 > /usr/local/x-ui/v
green "x-ui更新完成" && sleep 2 && x-ui
else
red "输入有误" && update
fi
}

uninstall() {
yellow "本次卸载将清除所有数据，建议如下："
yellow "一、点击x-ui面版中的备份与恢复，下载备份文件x-ui-yg.db"
yellow "二、在 /etc/x-ui-yg 路径导出备份文件x-ui-yg.db"
readp "确定卸载，请按回车(退出请按ctrl+c):" ins
if [[ -z $ins ]]; then
if [[ x"${release}" == x"alpine" ]]; then
rc-service x-ui stop
rc-update del x-ui default
rm /etc/init.d/x-ui -f
else
systemctl stop x-ui
systemctl disable x-ui
rm /etc/systemd/system/x-ui.service -f
systemctl daemon-reload
systemctl reset-failed
fi
kill -15 $(cat /usr/local/x-ui/xuiargopid.log 2>/dev/null) >/dev/null 2>&1
kill -15 $(cat /usr/local/x-ui/xuiargoympid.log 2>/dev/null) >/dev/null 2>&1
kill -15 $(cat /usr/local/x-ui/xuiwpphid.log 2>/dev/null) >/dev/null 2>&1
kill -15 $(pgrep -f 'webxui' 2>/dev/null) >/dev/null 2>&1
rm -rf /root/webxui /etc/local.d/alpinesub.start /usr/local/x-ui/ /etc/x-ui-yg/ /usr/bin/x-ui xuiyg_update ygkkkcaz
uncronxui
iptables -t nat -F PREROUTING >/dev/null 2>&1
netfilter-persistent save >/dev/null 2>&1
service iptables save >/dev/null 2>&1
#sed -i '/^precedence ::ffff:0:0\/96  100/d' /etc/gai.conf 2>/dev/null
echo
green "x-ui已卸载完成"
echo
blue "欢迎继续使用x-ui-yg脚本：bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/x-ui-yg/main/install.sh)"
echo
else
red "输入有误" && uninstall
fi
}

reset_config() {
/usr/local/x-ui/x-ui setting -reset
sleep 1 
portinstall
pathinstall
}

stop() {
if [[ x"${release}" == x"alpine" ]]; then
rc-service x-ui stop
else
systemctl stop x-ui
fi
check_status
if [[ $? == 1 ]]; then
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/goxui.sh/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
green "x-ui停止成功"
else
red "x-ui停止失败，请运行 x-ui log 查看日志并反馈" && exit
fi
}

restart() {
yellow "请稍等……"
if [[ x"${release}" == x"alpine" ]]; then
rc-service x-ui restart
else
systemctl restart x-ui
fi
sleep 2
check_status
if [[ $? == 0 ]]; then
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/goxui.sh/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
crontab -l 2>/dev/null > /tmp/crontab.tmp
echo "* * * * * /usr/local/x-ui/goxui.sh" >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
green "x-ui重启成功"
else
red "x-ui重启失败，请运行 x-ui log 查看日志并反馈" && exit
fi
}

show_log() {
if [[ x"${release}" == x"alpine" ]]; then
yellow "暂不支持alpine查看日志"
else
journalctl -u x-ui.service -e --no-pager -f
fi
}

get_char(){
SAVEDSTTY=`stty -g`
stty -echo
stty cbreak
dd if=/dev/tty bs=1 count=1 2> /dev/null
stty -raw
stty echo
stty $SAVEDSTTY
}

back(){
white "------------------------------------------------------------------------------------"
white " 回x-ui主菜单，请按任意键"
white " 退出脚本，请按Ctrl+C"
get_char && show_menu
}

acme() {
#bash <(curl -Ls https://gitlab.com/rwkgyg/acme-script/raw/main/acme.sh)
bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/acme-yg/main/acme.sh)
back
}

bbr() {
bash <(curl -Ls https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
back
}

cfwarp() {
#bash <(curl -Ls https://gitlab.com/rwkgyg/CFwarp/raw/main/CFwarp.sh)
bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/warp-yg/main/CFwarp.sh)
back
}

xuirestop(){
echo
readp "1. 停止 x-ui \n2. 重启 x-ui \n0. 返回主菜单\n请选择：" action
if [[ $action == "1" ]]; then
stop
elif [[ $action == "2" ]]; then
restart
else
show_menu
fi
}

xuichange(){
echo
readp "1. 更改 x-ui 用户名与密码 \n2. 更改 x-ui 面板登录端口\n3. 更改 x-ui 面板根路径\n4. 重置 x-ui 面板设置（面板设置选项中所有设置都恢复出厂设置，登录端口与面板根路径将重新自定义，账号密码不变）\n0. 返回主菜单\n请选择：" action
if [[ $action == "1" ]]; then
userinstall && restart
elif [[ $action == "2" ]]; then
portinstall && restart
elif [[ $action == "3" ]]; then
pathinstall && restart
elif [[ $action == "4" ]]; then
reset_config && restart
else
show_menu
fi
}

check_status() {
if [[ x"${release}" == x"alpine" ]]; then
if [[ ! -f /etc/init.d/x-ui ]]; then
return 2
fi
temp=$(rc-service x-ui status | awk '{print $3}')
if [[ x"${temp}" == x"started" ]]; then
return 0
else
return 1
fi
else
if [[ ! -f /etc/systemd/system/x-ui.service ]]; then
return 2
fi
temp=$(systemctl is-active x-ui 2>/dev/null | grep -w active)
if [[ x"${temp}" == x"active" ]]; then
return 0
else
return 1
fi
fi
}

check_enabled() {
if [[ x"${release}" == x"alpine" ]]; then
temp=$(rc-status default | grep x-ui | awk '{print $1}')
if [[ x"${temp}" == x"x-ui" ]]; then
return 0
else
return 1
fi
else
temp=$(systemctl is-enabled x-ui)
if [[ x"${temp}" == x"enabled" ]]; then
return 0
else
return 1
fi
fi
}

check_uninstall() {
check_status
if [[ $? != 2 ]]; then
yellow "x-ui已安装，可先选择2卸载，再安装" && sleep 3
if [[ $# == 0 ]]; then
show_menu
fi
return 1
else
return 0
fi
}

check_install() {
check_status
if [[ $? == 2 ]]; then
yellow "未安装x-ui，请先安装x-ui" && sleep 3
if [[ $# == 0 ]]; then
show_menu
fi
return 1
else
return 0
fi
}

show_status() {
check_status
case $? in
0)
echo -e "x-ui状态: $blue已运行$plain"
show_enable_status
;;
1)
echo -e "x-ui状态: $yellow未运行$plain"
show_enable_status
;;
2)
echo -e "x-ui状态: $red未安装$plain"
esac
show_xray_status
}

show_enable_status() {
check_enabled
if [[ $? == 0 ]]; then
echo -e "x-ui自启: $blue是$plain"
else
echo -e "x-ui自启: $red否$plain"
fi
}

check_xray_status() {
count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
if [[ count -ne 0 ]]; then
return 0
else
return 1
fi
}

show_xray_status() {
check_xray_status
if [[ $? == 0 ]]; then
echo -e "xray状态: $blue已启动$plain"
else
echo -e "xray状态: $red未启动$plain"
fi
}

xuigo(){
cat>/usr/local/x-ui/goxui.sh<<-\EOF
#!/bin/bash
xui=`ps -aux |grep "x-ui" |grep -v "grep" |wc -l`
xray=`ps -aux |grep "xray" |grep -v "grep" |wc -l`
if [ $xui = 0 ];then
systemctl restart x-ui
fi
if [ $xray = 0 ];then
systemctl restart x-ui
fi
EOF
chmod +x /usr/local/x-ui/goxui.sh
}

cronxui(){
uncronxui
crontab -l 2>/dev/null > /tmp/crontab.tmp
echo "* * * * * /usr/local/x-ui/goxui.sh" >> /tmp/crontab.tmp
echo "0 2 * * * systemctl restart x-ui" >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
}

uncronxui(){
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/goxui.sh/d' /tmp/crontab.tmp
sed -i '/systemctl restart x-ui/d' /tmp/crontab.tmp
sed -i '/xuiargoport.log/d' /tmp/crontab.tmp
sed -i '/xuiargopid.log/d' /tmp/crontab.tmp
sed -i '/xuiargoympid/d' /tmp/crontab.tmp
sed -i '/xuiwpphid.log/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
}

close(){
systemctl stop firewalld.service >/dev/null 2>&1
systemctl disable firewalld.service >/dev/null 2>&1
setenforce 0 >/dev/null 2>&1
ufw disable >/dev/null 2>&1
iptables -P INPUT ACCEPT >/dev/null 2>&1
iptables -P FORWARD ACCEPT >/dev/null 2>&1
iptables -P OUTPUT ACCEPT >/dev/null 2>&1
iptables -t mangle -F >/dev/null 2>&1
iptables -F >/dev/null 2>&1
iptables -X >/dev/null 2>&1
netfilter-persistent save >/dev/null 2>&1
if [[ -n $(apachectl -v 2>/dev/null) ]]; then
systemctl stop httpd.service >/dev/null 2>&1
systemctl disable httpd.service >/dev/null 2>&1
service apache2 stop >/dev/null 2>&1
systemctl disable apache2 >/dev/null 2>&1
fi
sleep 1
green "执行开放端口，关闭防火墙完毕"
}

openyn(){
echo
readp "是否开放端口，关闭防火墙？\n1、是，执行(回车默认)\n2、否，跳过！自行处理\n请选择：" action
if [[ -z $action ]] || [[ $action == "1" ]]; then
close
elif [[ $action == "2" ]]; then
echo
else
red "输入错误,请重新选择" && openyn
fi
}

changeserv(){
echo
readp "1：设置Argo临时、固定隧道\n2：设置vmess与vless节点在订阅链接中的优选IP地址\n3：设置Gitlab订阅分享链接\n4：获取warp-wireguard普通账号配置\n0：返回上层\n请选择【0-4】：" menu
if [ "$menu" = "1" ];then
xuiargo
elif [ "$menu" = "2" ];then
xuicfadd
elif [ "$menu" = "3" ];then
gitlabsub
elif [ "$menu" = "4" ];then
warpwg
elif [ "$menu" = "5" ];then
hyjpport
elif [ "$menu" = "6" ];then
ipsub
else 
show_menu
fi
}

hyjpport(){
echo "设置Hysteria2协议的跳跃端口：$hyjpt"
iptables -t nat -F PREROUTING >/dev/null 2>&1
ip6tables -t nat -F PREROUTING >/dev/null 2>&1
hyport=$(cat "$HOME/agsbx/port_hy2")
for p in ${hyjpt//,/ }; do
iptables -t nat -A PREROUTING -p udp --dport "${p/-/:}" -j DNAT --to-destination :$hyport
ip6tables -t nat -A PREROUTING -p udp --dport "${p/-/:}" -j DNAT --to-destination :$hyport
done
netfilter-persistent save >/dev/null 2>&1
if command -v rc-service >/dev/null 2>&1 && command -v rc-update >/dev/null 2>&1; then
rc-update show default 2>/dev/null | grep -q 'iptables' || rc-update add iptables >/dev/null 2>&1
rc-update show default 2>/dev/null | grep -q 'ip6tables' || rc-update add ip6tables >/dev/null 2>&1
rc-service iptables save >/dev/null 2>&1
rc-service ip6tables save >/dev/null 2>&1
fi
}

ipsub(){
subtokenipsub(){
echo
readp "输入订阅链接路径密码（回车表示xui面版登录根路径）：" menu
if [ -z "$menu" ]; then
subtoken="$(/usr/local/x-ui/x-ui setting -show 2>/dev/null | awk -F': ' 'NR==4{print $2}' | tr -d '/')"
else
subtoken="$menu"
fi
rm -rf /root/webxui/"$(cat /usr/local/x-ui/bin/subtoken.log 2>/dev/null)"
echo $subtoken > /usr/local/x-ui/bin/subtoken.log
green "订阅链接路径密码：$(cat /usr/local/x-ui/bin/subtoken.log 2>/dev/null)"
}
subportipsub(){
echo
readp "输入未被占用且可用的订阅链接端口（回车表示随机端口）：" menu
if [ -z "$menu" ]; then
subport=$(shuf -i 10000-65535 -n 1)
else
subport="$menu"
fi
echo $subport > /usr/local/x-ui/bin/subport.log
green "订阅链接端口：$(cat /usr/local/x-ui/bin/subport.log 2>/dev/null)"
}
echo
yellow "1：重置安装本地IP订阅链接"
yellow "2：更换订阅链接路径密码"
yellow "3：更换订阅链接端口"
yellow "4：卸载本地IP订阅链接"
yellow "0：返回上层"
readp "请选择【0-4】：" menu
if [ "$menu" = "1" ]; then
subtokenipsub && subportipsub
elif [ "$menu" = "2" ];then
subtokenipsub
elif [ "$menu" = "3" ];then
subportipsub
elif [ "$menu" = "4" ];then
kill -15 $(pgrep -f 'webxui' 2>/dev/null) >/dev/null 2>&1
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/webxui/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
rm -rf /root/webxui
rm -rf /etc/local.d/alpinesub.start
green "本地IP订阅链接已卸载完成" && sleep 3 && exit
else
changeserv
fi
echo
green "请稍后…………"
kill -15 $(pgrep -f 'webxui' 2>/dev/null) >/dev/null 2>&1
mkdir -p /root/webxui/"$(cat /usr/local/x-ui/bin/subtoken.log 2>/dev/null)"
ln -sf /usr/local/x-ui/bin/clmi.yaml /root/webxui/"$(cat /usr/local/x-ui/bin/subtoken.log 2>/dev/null)"/clmi.yaml
ln -sf /usr/local/x-ui/bin/sbox.json /root/webxui/"$(cat /usr/local/x-ui/bin/subtoken.log 2>/dev/null)"/sbox.json
ln -sf /usr/local/x-ui/bin/jhsub.txt /root/webxui/"$(cat /usr/local/x-ui/bin/subtoken.log 2>/dev/null)"/jhsub.txt
if command -v apk >/dev/null 2>&1; then
busybox-extras httpd -f -p "$(cat /usr/local/x-ui/bin/subport.log 2>/dev/null)" -h /root/webxui > /dev/null 2>&1 &
else
busybox httpd -f -p "$(cat /usr/local/x-ui/bin/subport.log 2>/dev/null)" -h /root/webxui > /dev/null 2>&1 &
fi
sleep 5
if command -v apk >/dev/null 2>&1; then
cat > /etc/local.d/alpinesub.start <<'EOF'
#!/bin/bash
sleep 10
busybox-extras httpd -f -p $(cat /usr/local/x-ui/bin/subport.log 2>/dev/null) -h /root/webxui > /dev/null 2>&1 &
EOF
chmod +x /etc/local.d/alpinesub.start
rc-update add local default >/dev/null 2>&1
else
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/webxui/d' /tmp/crontab.tmp
echo '@reboot sleep 10 && /bin/bash -c "busybox httpd -f -p $(cat /usr/local/x-ui/bin/subport.log 2>/dev/null) -h /root/webxui > /dev/null 2>&1 &"' >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
fi
sleep 1 && green "本地IP订阅链接已更新完成" && sleep 3 && x-ui
}

warpwg(){
warpcode(){
reg(){
keypair=$(openssl genpkey -algorithm X25519|openssl pkey -text -noout)
private_key=$(echo "$keypair" | awk '/priv:/{flag=1; next} /pub:/{flag=0} flag' | tr -d '[:space:]' | xxd -r -p | base64)
public_key=$(echo "$keypair" | awk '/pub:/{flag=1} flag' | tr -d '[:space:]' | xxd -r -p | base64)
curl -X POST 'https://api.cloudflareclient.com/v0a2158/reg' -sL --tlsv1.3 \
-H 'CF-Client-Version: a-7.21-0721' -H 'Content-Type: application/json' \
-d \
'{
"key":"'${public_key}'",
"tos":"'$(date +"%Y-%m-%dT%H:%M:%S.000Z")'"
}' \
| python3 -m json.tool | sed "/\"account_type\"/i\         \"private_key\": \"$private_key\","
}
reserved(){
reserved_str=$(echo "$warp_info" | grep 'client_id' | cut -d\" -f4)
reserved_hex=$(echo "$reserved_str" | base64 -d | xxd -p)
reserved_dec=$(echo "$reserved_hex" | fold -w2 | while read HEX; do printf '%d ' "0x${HEX}"; done | awk '{print "["$1", "$2", "$3"]"}')
echo -e "{\n    \"reserved_dec\": $reserved_dec,"
echo -e "    \"reserved_hex\": \"0x$reserved_hex\","
echo -e "    \"reserved_str\": \"$reserved_str\"\n}"
}
result() {
echo "$warp_reserved" | grep -P "reserved" | sed "s/ //g" | sed 's/:"/: "/g' | sed 's/:\[/: \[/g' | sed 's/\([0-9]\+\),\([0-9]\+\),\([0-9]\+\)/\1, \2, \3/' | sed 's/^"/    "/g' | sed 's/"$/",/g'
echo "$warp_info" | grep -P "(private_key|public_key|\"v4\": \"172.16.0.2\"|\"v6\": \"2)" | sed "s/ //g" | sed 's/:"/: "/g' | sed 's/^"/    "/g'
echo "}"
}
warp_info=$(reg) 
warp_reserved=$(reserved) 
result
}
output=$(warpcode)
if ! echo "$output" 2>/dev/null | grep -w "private_key" > /dev/null; then
v6=2606:4700:110:8f20:f22e:2c8d:d8ee:fe7
pvk=SGU6hx3CJAWGMr6XYoChvnrKV61hxAw2S4VlgBAxzFs=
res=[15,242,244]
else
pvk=$(echo "$output" | sed -n 4p | awk '{print $2}' | tr -d ' "' | sed 's/.$//')
v6=$(echo "$output" | sed -n 7p | awk '{print $2}' | tr -d ' "')
res=$(echo "$output" | sed -n 1p | awk -F":" '{print $NF}' | tr -d ' ' | sed 's/.$//')
fi
green "成功生成warp-wireguard普通账号配置，进入x-ui面板-面板设置-Xray配置出站设置，进行三要素替换"
blue "Private_key私钥：$pvk"
blue "IPV6地址：$v6"
blue "reserved值：$res"
}

cloudflaredargo(){
if [ ! -e /usr/local/x-ui/cloudflared ]; then
case $(uname -m) in
aarch64) cpu=arm64;;
x86_64) cpu=amd64;;
#aarch64) cpu=car;;
#x86_64) cpu=cam;;
esac
curl -L -o /usr/local/x-ui/cloudflared -# --retry 2 https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$cpu
#curl -L -o /usr/local/x-ui/cloudflared -# --retry 2 https://gitlab.com/rwkgyg/sing-box-yg/-/raw/main/$cpu
chmod +x /usr/local/x-ui/cloudflared
fi
}

xuiargo(){
echo
yellow "开启Argo隧道节点的三个前提要求："
green "一、节点的传输协议是WS"
green "二、节点的TLS必须关闭"
green "三、节点的请求头留空不设"
green "节点类别可选：vmess-ws、vless-ws、trojan-ws、shadowsocks-ws。推荐vmess-ws"
echo
yellow "1：设置Argo临时隧道"
yellow "2：设置Argo固定隧道"
yellow "0：返回上层"
readp "请选择【0-2】：" menu
if [ "$menu" = "1" ]; then
cfargo
elif [ "$menu" = "2" ]; then
cfargoym
else
changeserv
fi
}

cfargo(){
echo
yellow "1：重置Argo临时隧道域名"
yellow "2：停止Argo临时隧道"
yellow "0：返回上层"
readp "请选择【0-2】：" menu
if [ "$menu" = "1" ]; then
readp "请输入Argo监听的WS节点端口：" port
echo "$port" > /usr/local/x-ui/xuiargoport.log
cloudflaredargo
i=0
while [ $i -le 4 ]; do let i++
yellow "第$i次刷新验证Cloudflared Argo隧道域名有效性，请稍等……"
if [[ -n $(ps -e | grep cloudflared) ]]; then
kill -15 $(cat /usr/local/x-ui/xuiargopid.log 2>/dev/null) >/dev/null 2>&1
fi
/usr/local/x-ui/cloudflared tunnel --url http://localhost:$port --edge-ip-version auto --no-autoupdate --protocol http2 > /usr/local/x-ui/argo.log 2>&1 &
echo "$!" > /usr/local/x-ui/xuiargopid.log
sleep 20
if [[ -n $(curl -sL https://$(cat /usr/local/x-ui/argo.log 2>/dev/null | grep -a trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')/ -I | awk 'NR==1 && /404|400|503/') ]]; then
argo=$(cat /usr/local/x-ui/argo.log 2>/dev/null | grep -a trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
blue "Argo隧道申请成功，域名验证有效：$argo" && sleep 2
break
fi
if [ $i -eq 5 ]; then
red "请注意"
yellow "1：请确保你输入的端口是x-ui已创建WS协议端口"
yellow "2：Argo域名验证暂不可用，稍后可能会自动恢复，或者再次重置" && sleep 2
fi
done
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/xuiargoport.log/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
crontab -l 2>/dev/null > /tmp/crontab.tmp
echo '@reboot sleep 10 && /bin/bash -c "/usr/local/x-ui/cloudflared tunnel --url http://localhost:$(cat /usr/local/x-ui/xuiargoport.log) --edge-ip-version auto --no-autoupdate --protocol http2 > /usr/local/x-ui/argo.log 2>&1 & pid=\$! && echo \$pid > /usr/local/x-ui/xuiargopid.log"' >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
elif [ "$menu" = "2" ]; then
kill -15 $(cat /usr/local/x-ui/xuiargopid.log 2>/dev/null) >/dev/null 2>&1
rm -rf /usr/local/x-ui/argo.log /usr/local/x-ui/xuiargopid.log /usr/local/x-ui/xuiargoport.log
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/xuiargopid.log/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
green "已卸载Argo临时隧道"
else
xuiargo
fi
}

cfargoym(){
echo
if [[ -f /usr/local/x-ui/xuiargotoken.log && -f /usr/local/x-ui/xuiargoym.log ]]; then
green "当前Argo固定隧道域名：$(cat /usr/local/x-ui/xuiargoym.log 2>/dev/null)"
green "当前Argo固定隧道Token：$(cat /usr/local/x-ui/xuiargotoken.log 2>/dev/null)"
fi
echo
green "请确保Cloudflare官网 --- Zero Trust --- Networks --- Tunnels已设置完成"
yellow "1：重置/设置Argo固定隧道域名"
yellow "2：停止Argo固定隧道"
yellow "0：返回上层"
readp "请选择【0-2】：" menu
if [ "$menu" = "1" ]; then
readp "请输入Argo监听的WS节点端口：" port
echo "$port" > /usr/local/x-ui/xuiargoymport.log
cloudflaredargo
readp "输入Argo固定隧道Token: " argotoken
readp "输入Argo固定隧道域名: " argoym
if [[ -n $(ps -e | grep cloudflared) ]]; then
kill -15 $(cat /usr/local/x-ui/xuiargoympid.log 2>/dev/null) >/dev/null 2>&1
fi
echo
if [[ -n "${argotoken}" && -n "${argoym}" ]]; then
nohup setsid /usr/local/x-ui/cloudflared tunnel --no-autoupdate --edge-ip-version auto --protocol http2 run --token ${argotoken} >/dev/null 2>&1 & echo "$!" > /usr/local/x-ui/xuiargoympid.log
sleep 20
fi
echo ${argoym} > /usr/local/x-ui/xuiargoym.log
echo ${argotoken} > /usr/local/x-ui/xuiargotoken.log
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/xuiargoympid/d' /tmp/crontab.tmp
echo '@reboot sleep 10 && /bin/bash -c "nohup setsid /usr/local/x-ui/cloudflared tunnel --no-autoupdate --edge-ip-version auto --protocol http2 run --token $(cat /usr/local/x-ui/xuiargotoken.log 2>/dev/null) >/dev/null 2>&1 & pid=\$! && echo \$pid > /usr/local/x-ui/xuiargoympid.log"' >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
argo=$(cat /usr/local/x-ui/xuiargoym.log 2>/dev/null)
blue "Argo固定隧道设置完成，固定域名：$argo"
elif [ "$menu" = "2" ]; then
kill -15 $(cat /usr/local/x-ui/xuiargoympid.log 2>/dev/null) >/dev/null 2>&1
rm -rf /usr/local/x-ui/xuiargoym.log /usr/local/x-ui/xuiargoymport.log /usr/local/x-ui/xuiargoympid.log /usr/local/x-ui/xuiargotoken.log
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/xuiargoympid/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
green "已卸载Argo固定隧道"
else
xuiargo
fi
}

xuicfadd(){
[[ -s /usr/local/x-ui/bin/xuicdnip_ws.txt ]] && cdnwsname=$(cat /usr/local/x-ui/bin/xuicdnip_ws.txt 2>/dev/null)  || cdnwsname='域名或IP直连'
[[ -s /usr/local/x-ui/bin/xuicdnip_argo.txt ]] && cdnargoname=$(cat /usr/local/x-ui/bin/xuicdnip_argo.txt 2>/dev/null)  || cdnargoname=www.visa.com.sg
echo
green "推荐使用稳定的世界大厂或组织的CDN网站作为客户端优选IP地址："
blue "www.visa.com.sg"
blue "www.wto.org"
blue "www.web.com"
echo
yellow "1：设置所有主节点vmess/vless订阅节点客户端优选IP地址 【当前正使用：$cdnwsname】"
yellow "2：设置Argo节点vmess/vless订阅节点客户端优选IP地址 【当前正使用：$cdnargoname】"
yellow "0：返回上层"
readp "请选择【0-2】：" menu
if [ "$menu" = "1" ]; then
red "请确保本地IP已解析到CF托管的域名上，节点端口已设置为13个CF标准端口："
red "关tls端口：2052、2082、2086、2095、80、8880、8080"
red "开tls端口：2053、2083、2087、2096、8443、443"
red "如果VPS不支持以上13个CF标准端口（NAT类VPS），请在CF规则页面---Origin Rules页面下设置好回源规则" && sleep 2
echo
readp "输入自定义的优选IP/域名 (回车跳过表示恢复本地IP直连)：" menu
[[ -z "$menu" ]] && > /usr/local/x-ui/bin/xuicdnip_ws.txt || echo "$menu" > /usr/local/x-ui/bin/xuicdnip_ws.txt
green "设置成功，可选择7刷新" && sleep 2 && show_menu
elif [ "$menu" = "2" ]; then
red "请确保Argo临时隧道或者固定隧道的节点功能已启用" && sleep 2
readp "输入自定义的优选IP/域名 (回车跳过表示用默认优选域名：www.visa.com.sg)：" menu
[[ -z "$menu" ]] && > /usr/local/x-ui/bin/xuicdnip_argo.txt || echo "$menu" > /usr/local/x-ui/bin/xuicdnip_argo.txt
green "设置成功，可选择7刷新" && sleep 2 && show_menu
else
changeserv
fi
}

gitlabsub(){
echo
green "请确保Gitlab官网上已建立项目，已开启推送功能，已获取访问令牌"
yellow "1：重置/设置Gitlab订阅链接"
yellow "0：返回上层"
readp "请选择【0-1】：" menu
if [ "$menu" = "1" ]; then
chown -R root:root /usr/local/x-ui/bin /usr/local/x-ui
cd /usr/local/x-ui/bin
readp "输入登录邮箱: " email
readp "输入访问令牌: " token
readp "输入用户名: " userid
readp "输入项目名: " project
echo
green "多台VPS可共用一个令牌及项目名，可创建多个分支订阅链接"
green "回车跳过表示不新建，仅使用主分支main订阅链接(首台VPS建议回车跳过)"
readp "新建分支名称(可随意填写): " gitlabml
echo
sharesub_sbcl >/dev/null 2>&1
if [[ -z "$gitlabml" ]]; then
gitlab_ml=''
git_sk=main
rm -rf /usr/local/x-ui/bin/gitlab_ml_ml
else
gitlab_ml=":${gitlabml}"
git_sk="${gitlabml}"
echo "${gitlab_ml}" > /usr/local/x-ui/bin/gitlab_ml_ml
fi
echo "$token" > /usr/local/x-ui/bin/gitlabtoken.txt
rm -rf /usr/local/x-ui/bin/.git
git init >/dev/null 2>&1
git add sbox.json clmi.yaml jhsub.txt>/dev/null 2>&1
git config --global user.email "${email}" >/dev/null 2>&1
git config --global user.name "${userid}" >/dev/null 2>&1
git commit -m "commit_add_$(date +"%F %T")" >/dev/null 2>&1
branches=$(git branch)
if [[ $branches == *master* ]]; then
git branch -m master main >/dev/null 2>&1
fi
git remote add origin https://${token}@gitlab.com/${userid}/${project}.git >/dev/null 2>&1
if [[ $(ls -a | grep '^\.git$') ]]; then
cat > /usr/local/x-ui/bin/gitpush.sh <<EOF
#!/usr/bin/expect
spawn bash -c "git push -f origin main${gitlab_ml}"
expect "Password for 'https://$(cat /usr/local/x-ui/bin/gitlabtoken.txt 2>/dev/null)@gitlab.com':"
send "$(cat /usr/local/x-ui/bin/gitlabtoken.txt 2>/dev/null)\r"
interact
EOF
chmod +x gitpush.sh
./gitpush.sh "git push -f origin main${gitlab_ml}" cat /usr/local/x-ui/bin/gitlabtoken.txt >/dev/null 2>&1
echo "https://gitlab.com/api/v4/projects/${userid}%2F${project}/repository/files/sbox.json/raw?ref=${git_sk}&private_token=${token}" > /usr/local/x-ui/bin/sing_box_gitlab.txt
echo "https://gitlab.com/api/v4/projects/${userid}%2F${project}/repository/files/clmi.yaml/raw?ref=${git_sk}&private_token=${token}" > /usr/local/x-ui/bin/clash_meta_gitlab.txt
echo "https://gitlab.com/api/v4/projects/${userid}%2F${project}/repository/files/jhsub.txt/raw?ref=${git_sk}&private_token=${token}" > /usr/local/x-ui/bin/xui_ty_gitlab.txt
sharesubshow
else
yellow "设置Gitlab订阅链接失败，请反馈"
fi
cd
else
changeserv
fi
}

sharesubshow(){
green "当前X-ui-Sing-box节点已更新并推送"
green "Sing-box订阅链接如下："
blue "$(cat /usr/local/x-ui/bin/sing_box_gitlab.txt 2>/dev/null)"
echo
green "Sing-box订阅链接二维码如下："
qrencode -o - -t ANSIUTF8 "$(cat /usr/local/x-ui/bin/sing_box_gitlab.txt 2>/dev/null)"
sleep 3
echo
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
green "当前X-ui-Clash-meta节点配置已更新并推送"
green "Clash-meta订阅链接如下："
blue "$(cat /usr/local/x-ui/bin/clash_meta_gitlab.txt 2>/dev/null)"
echo
green "Clash-meta订阅链接二维码如下："
qrencode -o - -t ANSIUTF8 "$(cat /usr/local/x-ui/bin/clash_meta_gitlab.txt 2>/dev/null)"
sleep 3
echo
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
green "当前X-ui聚合通用节点配置已更新并推送"
green "聚合通用节点订阅链接如下："
blue "$(cat /usr/local/x-ui/bin/xui_ty_gitlab.txt 2>/dev/null)"
sleep 3
echo
yellow "可以在网页上输入以上三个订阅链接查看配置内容，如果无配置内容，请自检Gitlab相关设置并重置"
echo
}

sharesub(){
sharesub_sbcl
echo
red "Gitlab订阅链接如下："
echo
cd /usr/local/x-ui/bin
if [[ $(ls -a | grep '^\.git$') ]]; then
if [ -f /usr/local/x-ui/bin/gitlab_ml_ml ]; then
gitlab_ml=$(cat /usr/local/x-ui/bin/gitlab_ml_ml)
fi
git rm --cached sbox.json clmi.yaml jhsub.txt >/dev/null 2>&1
git commit -m "commit_rm_$(date +"%F %T")" >/dev/null 2>&1
git add sbox.json clmi.yaml jhsub.txt >/dev/null 2>&1
git commit -m "commit_add_$(date +"%F %T")" >/dev/null 2>&1
chmod +x gitpush.sh
./gitpush.sh "git push -f origin main${gitlab_ml}" cat /usr/local/x-ui/bin/gitlabtoken.txt >/dev/null 2>&1
sharesubshow
else
yellow "未设置Gitlab订阅链接"
fi
cd
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀X-UI聚合通用节点分享链接显示如下："
red "文件目录 /usr/local/x-ui/bin/jhsub.txt ，可直接在客户端剪切板导入添加" && sleep 2
echo
cat /usr/local/x-ui/bin/jhsub.txt
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀X-UI-Clash-Meta配置文件操作如下："
red "文件目录 /usr/local/x-ui/bin/clmi.yaml ，复制自建以yaml文件格式为准" 
echo
red "输入：cat /usr/local/x-ui/bin/clmi.yaml 即可显示配置内容" && sleep 2
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀XUI-Sing-box-SFA/SFI/SFW配置文件操作如下："
red "文件目录 /usr/local/x-ui/bin/sbox.json ，复制自建以json文件格式为准"
echo
red "输入：cat /usr/local/x-ui/bin/sbox.json 即可显示配置内容" && sleep 2
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

sharesub_sbcl(){
if [[ -s /usr/local/x-ui/bin/xuicdnip_argo.txt ]]; then
cdnargo=$(cat /usr/local/x-ui/bin/xuicdnip_argo.txt 2>/dev/null)
else
cdnargo=www.visa.com.sg
fi
green "请稍等……"
cat > /usr/local/x-ui/bin/sbox.json <<EOF
{
    "log": {
        "disabled": false,
        "level": "info",
        "timestamp": true
    },
    "experimental": {
        "cache_file": {
            "enabled": true,
            "path": "./cache.db",
            "store_fakeip": true
        },
        "clash_api": {
            "external_controller": "127.0.0.1:9090",
            "external_ui": "ui",
            "default_mode": "Rule"
        }
    },
    "dns": {
        "servers": [
            {
                "tag": "aliDns",
                "type": "https",
                "server": "dns.alidns.com",
                "path": "/dns-query",
                "domain_resolver": "local"
            },
            {
                "tag": "local",
                "type": "udp",
                "server": "223.5.5.5"
            },
            {
                "tag": "proxyDns",
                "type": "https",
                "server": "dns.google",
                "path": "/dns-query",
	            "domain_resolver": "aliDns",
                "detour": "proxy"
            },
           {
        "type": "fakeip",
        "tag": "fakeip",
        "inet4_range": "198.18.0.0/15",
        "inet6_range": "fc00::/18"
      }
        ],
        "rules": [
            {
                "rule_set": "geosite-cn",
                "clash_mode": "Rule",
                "server": "aliDns"
            },
            {
                "clash_mode": "Direct",
                "server": "local"
            },
            {
                "clash_mode": "Global",
                "server": "proxyDns"
            },
            {
        "query_type": [
          "A",
          "AAAA"
        ],
        "server": "fakeip"
      }
        ],
        "final": "proxyDns",
        "strategy": "prefer_ipv4"
    },
    "inbounds": [
        {
            "type": "tun",
            "tag": "tun-in",
            "address": [
                "172.19.0.1/30",
                "fd00::1/126"
            ],
            "auto_route": true,
            "strict_route": true
        }
    ],
    "route": {
        "rules": [
            {
	           "inbound": "tun-in",
                "action": "sniff"
            },
            {
                "type": "logical",
                "mode": "or",
                "rules": [
                    {
                        "port": 53
                    },
                    {
                        "protocol": "dns"
                    }
                ],
                "action": "hijack-dns"
            },
         {
          "clash_mode": "Global",
          "outbound": "proxy"
         },
        {
        "rule_set": "geosite-cn",
        "clash_mode": "Rule",
        "outbound": "direct"
       },
     {
    "rule_set": "geoip-cn",
    "clash_mode": "Rule",
    "outbound": "direct"
      },
     {
    "ip_is_private": true,
    "clash_mode": "Rule",
    "outbound": "direct"
    },
     {
      "clash_mode": "Direct",
      "outbound": "direct"
     }		
        ],
        "rule_set": [
            {
                "tag": "geosite-cn",
                "type": "remote",
                "format": "binary",
                "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/geolocation-cn.srs",
                "download_detour": "direct"
            },
            {
                "tag": "geoip-cn",
                "type": "remote",
                "format": "binary",
                "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/cn.srs",
                "download_detour": "direct"
            }
        ],
        "final": "proxy",
        "auto_detect_interface": true,
        "default_domain_resolver": {
            "server": "aliDns"
        }
    },
  "outbounds": [

//_0

    {
      "tag": "proxy",
      "type": "selector",
      "default": "auto",
      "outbounds": [
        "auto",

//_1

      ]
    },
    {
      "tag": "auto",
      "type": "urltest",
      "outbounds": [

//_2

       ],
       "url": "http://www.gstatic.com/generate_204",
       "interval": "10m",
        "tolerance": 50
        },
    {
      "tag": "direct",
      "type": "direct"
    }
    ]
}
EOF

cat > /usr/local/x-ui/bin/clmi.yaml <<EOF
port: 7890
allow-lan: true
mode: rule
log-level: info
unified-delay: true
dns:
  enable: true 
  listen: "0.0.0.0:1053"
  ipv6: true
  prefer-h3: false
  respect-rules: true
  use-system-hosts: false
  cache-algorithm: "arc"
  enhanced-mode: "fake-ip"
  fake-ip-range: "198.18.0.1/16"
  fake-ip-filter:
    - "+.lan"
    - "+.local"
    - "+.msftconnecttest.com"
    - "+.msftncsi.com"
    - "localhost.ptlogin2.qq.com"
    - "localhost.sec.qq.com"
    - "+.in-addr.arpa"
    - "+.ip6.arpa"
    - "time.*.com"
    - "time.*.gov"
    - "pool.ntp.org"
    - "localhost.work.weixin.qq.com"
  default-nameserver: ["223.5.5.5", "119.29.29.29"]
  nameserver:
    - "https://1.1.1.1/dns-query"
    - "https://8.8.8.8/dns-query"
  proxy-server-nameserver:
    - "https://223.5.5.5/dns-query"
    - "https://doh.pub/dns-query"
nameserver-policy:
  "geosite:cn":
     - "https://223.5.5.5/dns-query"
     - "https://doh.pub/dns-query"

proxies:

#_0

proxy-groups:
- name: 负载均衡
  type: load-balance
  url: https://www.gstatic.com/generate_204
  interval: 300
  strategy: round-robin
  proxies: 

#_1


- name: 自动选择
  type: url-test
  url: https://www.gstatic.com/generate_204
  interval: 300
  tolerance: 50
  proxies:  

#_2                         
    
- name: 🌍选择代理节点
  type: select
  proxies:
    - 负载均衡                                         
    - 自动选择
    - DIRECT

#_3

rules:
  - GEOIP,LAN,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,🌍选择代理节点
EOF

xui_sb_cl(){
sed -i "/#_0/r /usr/local/x-ui/bin/cl${i}.log" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_1/ i\\    - $tag" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_2/ i\\    - $tag" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_3/ i\\    - $tag" /usr/local/x-ui/bin/clmi.yaml
sed -i "/\/\/_0/r /usr/local/x-ui/bin/sb${i}.log" /usr/local/x-ui/bin/sbox.json
sed -i "/\/\/_1/ i\\ \"$tag\"," /usr/local/x-ui/bin/sbox.json
sed -i "/\/\/_2/ i\\ \"$tag\"," /usr/local/x-ui/bin/sbox.json
}

tag_count=$(jq '.inbounds | map(select(.protocol == "vless" or .protocol == "vmess" or .protocol == "trojan" or .protocol == "shadowsocks")) | length' /usr/local/x-ui/bin/config.json)
for ((i=0; i<tag_count; i++))
do
jq -c ".inbounds | map(select(.protocol == \"vless\" or .protocol == \"vmess\" or .protocol == \"trojan\" or .protocol == \"shadowsocks\"))[$i]" /usr/local/x-ui/bin/config.json > "/usr/local/x-ui/bin/$((i+1)).log"
done
rm -rf /usr/local/x-ui/bin/jhsub.txt
xip1=$(cat /usr/local/x-ui/xip 2>/dev/null | sed -n 1p)
ymip=$(cat /root/ygkkkca/ca.log 2>/dev/null)
directory="/usr/local/x-ui/bin/"
for i in $(seq 1 $tag_count); do
file="${directory}${i}.log"
if [ -f "$file" ]; then
#vless-reality-vision
if grep -q "vless" "$file" && grep -q "reality" "$file" && grep -q "vision" "$file"; then
finger=$(jq -r '.streamSettings.realitySettings.fingerprint' /usr/local/x-ui/bin/${i}.log)
vl_name=$(jq -r '.streamSettings.realitySettings.serverNames[0]' /usr/local/x-ui/bin/${i}.log)
public_key=$(jq -r '.streamSettings.realitySettings.publicKey' /usr/local/x-ui/bin/${i}.log)
short_id=$(jq -r '.streamSettings.realitySettings.shortIds[0]' /usr/local/x-ui/bin/${i}.log)
uuid=$(jq -r '.settings.clients[0].id' /usr/local/x-ui/bin/${i}.log)
vl_port=$(jq -r '.port' /usr/local/x-ui/bin/${i}.log)
tag=$vl_port-vless-reality-vision
cat > /usr/local/x-ui/bin/sb${i}.log <<EOF

 {
      "type": "vless",
      "tag": "$tag",
      "server": "$xip1",
      "server_port": $vl_port,
      "uuid": "$uuid",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "$vl_name",
        "utls": {
          "enabled": true,
          "fingerprint": "$finger"
        },
      "reality": {
          "enabled": true,
          "public_key": "$public_key",
          "short_id": "$short_id"
        }
      }
    },
EOF

cat > /usr/local/x-ui/bin/cl${i}.log <<EOF

- name: $tag               
  type: vless
  server: $xip1                           
  port: $vl_port                                
  uuid: $uuid   
  network: tcp
  udp: true
  tls: true
  flow: xtls-rprx-vision
  servername: $vl_name                 
  reality-opts: 
    public-key: $public_key    
    short-id: $short_id                      
  client-fingerprint: $finger   

EOF
echo "vless://$uuid@$xip1:$vl_port?type=tcp&security=reality&sni=$vl_name&pbk=$public_key&flow=xtls-rprx-vision&sid=$short_id&fp=$finger#$tag" >>/usr/local/x-ui/bin/jhsub.txt
xui_sb_cl

#vless-tcp-vision
elif grep -q "vless" "$file" && grep -q "vision" "$file" && grep -q "keyFile" "$file"; then
[[ -n $ymip ]] && servip=$ymip || servip=$xip1
uuid=$(jq -r '.settings.clients[0].id' /usr/local/x-ui/bin/${i}.log)
vl_port=$(jq -r '.port' /usr/local/x-ui/bin/${i}.log)
tag=$vl_port-vless-tcp-vision
cat > /usr/local/x-ui/bin/sb${i}.log <<EOF

{
            "server": "$servip",
            "server_port": $vl_port,
            "tag": "$tag",
            "tls": {
                "enabled": true,
                "insecure": false
            },
            "type": "vless",
            "flow": "xtls-rprx-vision",
            "uuid": "$uuid"
        },
EOF

cat > /usr/local/x-ui/bin/cl${i}.log <<EOF

- name: $tag           
  type: vless
  server: $servip                     
  port: $vl_port                                  
  uuid: $uuid  
  network: tcp
  tls: true
  udp: true
  flow: xtls-rprx-vision


EOF
echo "vless://$uuid@$servip:$vl_port?type=tcp&security=tls&flow=xtls-rprx-vision#$tag" >>/usr/local/x-ui/bin/jhsub.txt
xui_sb_cl

#vless-ws
elif grep -q "vless" "$file" && grep -q "ws" "$file" && ! grep -qw "{}}}" "$file"; then
ws_path=$(jq -r '.streamSettings.wsSettings.path' /usr/local/x-ui/bin/${i}.log)
tls=$(jq -r '.streamSettings.security' /usr/local/x-ui/bin/${i}.log)
vl_port=$(jq -r '.port' /usr/local/x-ui/bin/${i}.log)
if [[ $tls == 'tls' ]]; then
tls=true 
tlsw=tls
else
tls=false 
tlsw=''
fi
if ! [[ "$vl_port" =~ ^(2052|2082|2086|2095|80|8880|8080|2053|2083|2087|2096|8443|443)$ ]] && [[ -s /usr/local/x-ui/bin/xuicdnip_ws.txt ]]; then
servip=$(cat /usr/local/x-ui/bin/xuicdnip_ws.txt 2>/dev/null)
if [[ $(jq -r '.streamSettings.security' /usr/local/x-ui/bin/${i}.log) == 'tls' ]]; then
vl_port=8443
tag=$(jq -r '.port' /usr/local/x-ui/bin/${i}.log)-回源-vless-ws-tls
else
vl_port=8880
tag=$(jq -r '.port' /usr/local/x-ui/bin/${i}.log)-回源-vless-ws
fi
elif [[ "$vl_port" =~ ^(2052|2082|2086|2095|80|8880|8080|2053|2083|2087|2096|8443|443)$ ]] && [[ -s /usr/local/x-ui/bin/xuicdnip_ws.txt ]]; then
servip=$(cat /usr/local/x-ui/bin/xuicdnip_ws.txt 2>/dev/null)
[[ $(jq -r '.streamSettings.security' /usr/local/x-ui/bin/${i}.log) == 'tls' ]] && tag=$(jq -r '.port' /usr/local/x-ui/bin/${i}.log)-vless-ws-tls || tag=$(jq -r '.port' /usr/local/x-ui/bin/${i}.log)-vless-ws
else
[[ -n $ymip ]] && servip=$ymip || servip=$xip1
[[ $(jq -r '.streamSettings.security' /usr/local/x-ui/bin/${i}.log) == 'tls' ]] && tag=$(jq -r '.port' /usr/local/x-ui/bin/${i}.log)-vless-ws-tls || tag=$(jq -r '.port' /usr/local/x-ui/bin/${i}.log)-vless-ws
fi
vl_name=$(jq -r '.streamSettings.wsSettings.headers.Host' /usr/local/x-ui/bin/${i}.log)
uuid=$(jq -r '.settings.clients[0].id' /usr/local/x-ui/bin/${i}.log)



cat > /usr/local/x-ui/bin/sb${i}.log <<EOF

{
            "server": "$servip",
            "server_port": $vl_port,
            "tag": "$tag",
            "tls": {
                "enabled": $tls,
                "server_name": "$vl_name",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$vl_name"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vless",
            "uuid": "$uuid"
        },
EOF

cat > /usr/local/x-ui/bin/cl${i}.log <<EOF

- name: $tag                         
  type: vless
  server: $servip                       
  port: $vl_port                                     
  uuid: $uuid     
  udp: true
  tls: $tls
  network: ws
  servername: $vl_name                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $vl_name 

EOF
echo "vless://$uuid@$servip:$vl_port?type=ws&security=$tlsw&sni=$vl_name&path=$ws_path&host=$vl_name#$tag" >>/usr/local/x-ui/bin/jhsub.txt
xui_sb_cl

#vmess-ws
elif grep -q "vmess" "$file" && grep -q "ws" "$file" && ! grep -qw "{}}}" "$file"; then
ws_path=$(jq -r '.streamSettings.wsSettings.path' /usr/local/x-ui/bin/${i}.log)
vm_port=$(jq -r '.port' /usr/local/x-ui/bin/${i}.log)
tls=$(jq -r '.streamSettings.security' /usr/local/x-ui/bin/${i}.log)
if [[ $tls == 'tls' ]]; then
tls=true 
tlsw=tls
else
tls=false 
tlsw=''
fi
if ! [[ "$vm_port" =~ ^(2052|2082|2086|2095|80|8880|8080|2053|2083|2087|2096|8443|443)$ ]] && [[ -s /usr/local/x-ui/bin/xuicdnip_ws.txt ]]; then
servip=$(cat /usr/local/x-ui/bin/xuicdnip_ws.txt 2>/dev/null)
if [[ $(jq -r '.streamSettings.security' /usr/local/x-ui/bin/${i}.log) == 'tls' ]]; then
vm_port=8443
tag=$(jq -r '.port' /usr/local/x-ui/bin/${i}.log)-回源-vmess-ws-tls
else
vm_port=8880
tag=$(jq -r '.port' /usr/local/x-ui/bin/${i}.log)-回源-vmess-ws
fi
elif [[ "$vm_port" =~ ^(2052|2082|2086|2095|80|8880|8080|2053|2083|2087|2096|8443|443)$ ]] && [[ -s /usr/local/x-ui/bin/xuicdnip_ws.txt ]]; then
servip=$(cat /usr/local/x-ui/bin/xuicdnip_ws.txt 2>/dev/null)
[[ $(jq -r '.streamSettings.security' /usr/local/x-ui/bin/${i}.log) == 'tls' ]] && tag=$(jq -r '.port' /usr/local/x-ui/bin/${i}.log)-vmess-ws-tls || tag=$(jq -r '.port' /usr/local/x-ui/bin/${i}.log)-vmess-ws
else
[[ -n $ymip ]] && servip=$ymip || servip=$xip1
[[ $(jq -r '.streamSettings.security' /usr/local/x-ui/bin/${i}.log) == 'tls' ]] && tag=$(jq -r '.port' /usr/local/x-ui/bin/${i}.log)-vmess-ws-tls || tag=$(jq -r '.port' /usr/local/x-ui/bin/${i}.log)-vmess-ws
fi
vm_name=$(jq -r '.streamSettings.wsSettings.headers.Host' /usr/local/x-ui/bin/${i}.log)
uuid=$(jq -r '.settings.clients[0].id' /usr/local/x-ui/bin/${i}.log)
cat > /usr/local/x-ui/bin/sb${i}.log <<EOF

{
            "server": "$servip",
            "server_port": $vm_port,
            "tag": "$tag",
            "tls": {
                "enabled": $tls,
                "server_name": "$vm_name",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$vm_name"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
EOF

cat > /usr/local/x-ui/bin/cl${i}.log <<EOF

- name: $tag                         
  type: vmess
  server: $servip                        
  port: $vm_port                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: $tls
  network: ws
  servername: $vm_name                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $vm_name

EOF
echo -e "vmess://$(echo '{"add":"'$servip'","aid":"0","host":"'$vm_name'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"'$vm_port'","ps":"'$tag'","tls":"'$tlsw'","sni":"'$vm_name'","type":"none","v":"2"}' | base64 -w 0)" >>/usr/local/x-ui/bin/jhsub.txt
xui_sb_cl

#vmess-tcp
elif grep -q "vmess" "$file" && grep -q "tcp" "$file"; then
[[ -n $ymip ]] && servip=$ymip || servip=$xip1
tls=$(jq -r '.streamSettings.security' /usr/local/x-ui/bin/${i}.log)
if [[ $tls == 'tls' ]]; then
tls=true 
tlst=tls
else
tls=false 
tlst=''
fi
uuid=$(jq -r '.settings.clients[0].id' /usr/local/x-ui/bin/${i}.log)
vm_port=$(jq -r '.port' /usr/local/x-ui/bin/${i}.log)
tag=$vm_port-vmess-tcp
cat > /usr/local/x-ui/bin/sb${i}.log <<EOF

{
            "server": "$servip",
            "server_port": $vm_port,
            "tag": "$tag",
            "tls": {
                "enabled": $tls,
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
EOF

cat > /usr/local/x-ui/bin/cl${i}.log <<EOF

- name: $tag                         
  type: vmess
  server: $servip                        
  port: $vm_port                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: $tls

EOF
echo -e "vmess://$(echo '{"add":"'$servip'","aid":"0","id":"'$uuid'","net":"tcp","port":"'$vm_port'","ps":"'$tag'","tls":"'$tlst'","type":"none","v":"2"}' | base64 -w 0)" >>/usr/local/x-ui/bin/jhsub.txt
xui_sb_cl

#vless-tcp
elif grep -q "vless" "$file" && grep -q "tcp" "$file"; then
[[ -n $ymip ]] && servip=$ymip || servip=$xip1
tls=$(jq -r '.streamSettings.security' /usr/local/x-ui/bin/${i}.log)
if [[ $tls == 'tls' ]]; then
tls=true 
tlst=tls
else
tls=false 
tlst=''
fi
uuid=$(jq -r '.settings.clients[0].id' /usr/local/x-ui/bin/${i}.log)
vl_port=$(jq -r '.port' /usr/local/x-ui/bin/${i}.log)
tag=$vl_port-vless-tcp
cat > /usr/local/x-ui/bin/sb${i}.log <<EOF

{
            "server": "$servip",
            "server_port": $vl_port,
            "tag": "$tag",
            "tls": {
                "enabled": $tls,
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "type": "vless",
            "uuid": "$uuid"
        },
EOF

cat > /usr/local/x-ui/bin/cl${i}.log <<EOF

- name: $tag                         
  type: vless
  server: $servip                       
  port: $vl_port                                     
  uuid: $uuid     
  udp: true
  tls: $tls

EOF
echo "vless://$uuid@$servip:$vl_port?type=tcp&security=$tlst#$tag" >>/usr/local/x-ui/bin/jhsub.txt
xui_sb_cl

#trojan-tcp-tls
elif grep -q "trojan" "$file" && grep -q "tcp" "$file" && grep -q "keyFile" "$file"; then
[[ -n $ymip ]] && servip=$ymip || servip=$xip1
password=$(jq -r '.settings.clients[0].password' /usr/local/x-ui/bin/${i}.log)
vl_port=$(jq -r '.port' /usr/local/x-ui/bin/${i}.log)
tag=$vl_port-trojan-tcp-tls
cat > /usr/local/x-ui/bin/sb${i}.log <<EOF

{
            "server": "$servip",
            "server_port": $vl_port,
            "tag": "$tag",
            "tls": {
                "enabled": true,
                "insecure": false
            },
            "type": "trojan",
            "password": "$password"
        },
EOF

cat > /usr/local/x-ui/bin/cl${i}.log <<EOF

- name: $tag                         
  type: trojan
  server: $servip                       
  port: $vl_port                                     
  password: $password    
  udp: true
  sni: $servip
  skip-cert-verify: false

EOF
echo "trojan://$password@$servip:$vl_port?security=tls&type=tcp#$tag" >>/usr/local/x-ui/bin/jhsub.txt
xui_sb_cl

#trojan-ws-tls
elif grep -q "trojan" "$file" && grep -q "ws" "$file" && grep -q "keyFile" "$file"; then
ws_path=$(jq -r '.streamSettings.wsSettings.path' /usr/local/x-ui/bin/${i}.log)
vm_name=$(jq -r '.streamSettings.wsSettings.headers.Host' /usr/local/x-ui/bin/${i}.log)
[[ -n $ymip ]] && servip=$ymip || servip=$xip1
tls=$(jq -r '.streamSettings.security' /usr/local/x-ui/bin/${i}.log)
[[ $tls == 'tls' ]] && tls=true || tls=false
password=$(jq -r '.settings.clients[0].password' /usr/local/x-ui/bin/${i}.log)
vl_port=$(jq -r '.port' /usr/local/x-ui/bin/${i}.log)
tag=$vl_port-trojan-ws-tls
cat > /usr/local/x-ui/bin/sb${i}.log <<EOF

{
            "server": "$servip",
            "server_port": $vl_port,
            "tag": "$tag",
            "tls": {
                "enabled": $tls,
                "insecure": false
            },
            "transport": {
                "headers": {
                    "Host": [
                        "$vm_name"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "trojan",
            "password": "$password"
        },
EOF

cat > /usr/local/x-ui/bin/cl${i}.log <<EOF

- name: $tag                         
  type: trojan
  server: $servip                       
  port: $vl_port                                     
  password: $password    
  udp: true
  sni: $servip
  skip-cert-verify: false
  network: ws                 
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $vm_name

EOF
echo "trojan://$password@$servip:$vl_port?security=tls&type=ws&path=$ws_path&host=$vm_name#$tag" >>/usr/local/x-ui/bin/jhsub.txt
xui_sb_cl

#shadowsocks-tcp
elif grep -q "shadowsocks" "$file" && grep -q "tcp" "$file"; then
[[ -n $ymip ]] && servip=$ymip || servip=$xip1
password=$(jq -r '.settings.password' /usr/local/x-ui/bin/${i}.log)
vm_port=$(jq -r '.port' /usr/local/x-ui/bin/${i}.log)
ssmethod=$(jq -r '.settings.method' /usr/local/x-ui/bin/${i}.log)
tag=$vm_port-ss-tcp
cat > /usr/local/x-ui/bin/sb${i}.log <<EOF

{
      "type": "shadowsocks",
      "tag": "$tag",
      "server": "$servip",
      "server_port": $vm_port,
      "method": "$ssmethod",
      "password": "$password"
},
EOF

cat > /usr/local/x-ui/bin/cl${i}.log <<EOF

- name: $tag                         
  type: ss
  server: $servip                        
  port: $vm_port                                     
  password: $password
  cipher: $ssmethod
  udp: true

EOF
echo -e "ss://$ssmethod:$password@$servip:$vm_port#$tag" >>/usr/local/x-ui/bin/jhsub.txt
xui_sb_cl
fi
else
red "当前x-ui未设置有效的节点配置" && exit
fi
done

argopid
argoprotocol=$(jq -r --arg port "$(cat /usr/local/x-ui/xuiargoport.log 2>/dev/null)" '.inbounds[] | select(.port == ($port | tonumber)) | .protocol' /usr/local/x-ui/bin/config.json 2>/dev/null)
uuid=$(jq -r --arg port "$(cat /usr/local/x-ui/xuiargoport.log 2>/dev/null)" '.inbounds[] | select(.port == ($port | tonumber)) | .settings.clients[0].id' /usr/local/x-ui/bin/config.json 2>/dev/null)
ws_path=$(jq -r --arg port "$(cat /usr/local/x-ui/xuiargoport.log 2>/dev/null)" '.inbounds[] | select(.port == ($port | tonumber)) | .streamSettings.wsSettings.path' /usr/local/x-ui/bin/config.json 2>/dev/null)
argotls=$(jq -r --arg port "$(cat /usr/local/x-ui/xuiargoport.log 2>/dev/null)" '.inbounds[] | select(.port == ($port | tonumber)) | .streamSettings.security' /usr/local/x-ui/bin/config.json 2>/dev/null)
argolsym=$(cat /usr/local/x-ui/argo.log 2>/dev/null | grep -a trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
if [[ -n $(ps -e | grep -w $ls 2>/dev/null) ]] && [[ -f /usr/local/x-ui/xuiargoport.log ]] && [[ $argoprotocol =~ vless|vmess ]] && [[ ! "$argotls" = "tls" ]]; then
if [[ $argoprotocol = vless ]]; then
#vless-ws-tls-argo临时
cat > /usr/local/x-ui/bin/sbvltargo.log <<EOF

{
            "server": "$cdnargo",
            "server_port": 8443,
            "tag": "vl-tls-argo临时-8443",
            "tls": {
                "enabled": true,
                "server_name": "$argolsym",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argolsym"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vless",
            "uuid": "$uuid"
        },
EOF

cat > /usr/local/x-ui/bin/clvltargo.log <<EOF

- name: vl-tls-argo临时-8443                         
  type: vless
  server: $cdnargo                       
  port: 8443                                     
  uuid: $uuid     
  udp: true
  tls: true
  network: ws
  servername: $argolsym                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argolsym 

EOF

#vless-ws-argo临时
cat > /usr/local/x-ui/bin/sbvlargo.log <<EOF

{
            "server": "$cdnargo",
            "server_port": 8880,
            "tag": "vl-argo临时-8880",
            "tls": {
                "enabled": false,
                "server_name": "$argolsym",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argolsym"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vless",
            "uuid": "$uuid"
        },
EOF

cat > /usr/local/x-ui/bin/clvlargo.log <<EOF

- name: vl-argo临时-8880                         
  type: vless
  server: $cdnargo                       
  port: 8880                                     
  uuid: $uuid     
  udp: true
  tls: false
  network: ws
  servername: $argolsym                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argolsym 

EOF
sed -i "/#_0/r /usr/local/x-ui/bin/clvltargo.log" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_1/ i\\    - vl-tls-argo临时-8443" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_2/ i\\    - vl-tls-argo临时-8443" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_3/ i\\    - vl-tls-argo临时-8443" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_0/r /usr/local/x-ui/bin/clvlargo.log" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_1/ i\\    - vl-argo临时-8880" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_2/ i\\    - vl-argo临时-8880" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_3/ i\\    - vl-argo临时-8880" /usr/local/x-ui/bin/clmi.yaml
sed -i "/\/\/_0/r /usr/local/x-ui/bin/sbvltargo.log" /usr/local/x-ui/bin/sbox.json
sed -i "/\/\/_1/ i\\ \"vl-tls-argo临时-8443\"," /usr/local/x-ui/bin/sbox.json
sed -i "/\/\/_2/ i\\ \"vl-tls-argo临时-8443\"," /usr/local/x-ui/bin/sbox.json
sed -i "/\/\/_0/r /usr/local/x-ui/bin/sbvlargo.log" /usr/local/x-ui/bin/sbox.json
sed -i "/\/\/_1/ i\\ \"vl-argo临时-8880\"," /usr/local/x-ui/bin/sbox.json
sed -i "/\/\/_2/ i\\ \"vl-argo临时-8880\"," /usr/local/x-ui/bin/sbox.json
echo "vless://$uuid@$cdnargo:8880?type=ws&security=none&path=$ws_path&host=$argolsym#vl-argo临时-8880" >>/usr/local/x-ui/bin/jhsub.txt
echo "vless://$uuid@$cdnargo:8443?type=ws&security=tls&path=$ws_path&host=$argolsym#vl-tls-argo临时-8443" >>/usr/local/x-ui/bin/jhsub.txt

elif [[ $argoprotocol = vmess ]]; then
#vmess-ws-tls-argo临时
cat > /usr/local/x-ui/bin/sbvmtargo.log <<EOF

{
            "server": "$cdnargo",
            "server_port": 8443,
            "tag": "vm-tls-argo临时-8443",
            "tls": {
                "enabled": true,
                "server_name": "$argolsym",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argolsym"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
EOF

cat > /usr/local/x-ui/bin/clvmtargo.log <<EOF

- name: vm-tls-argo临时-8443                        
  type: vmess
  server: $cdnargo                        
  port: 8443                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: true
  network: ws
  servername: $argolsym                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argolsym

EOF

#vmess-ws-argo临时
cat > /usr/local/x-ui/bin/sbvmargo.log <<EOF

{
            "server": "$cdnargo",
            "server_port": 8880,
            "tag": "vm-argo临时-8880",
            "tls": {
                "enabled": false,
                "server_name": "$argolsym",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argolsym"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
EOF

cat > /usr/local/x-ui/bin/clvmargo.log <<EOF

- name: vm-argo临时-8880                         
  type: vmess
  server: $cdnargo                       
  port: 8880                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: false
  network: ws
  servername: $argolsym                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argolsym

EOF
sed -i "/#_0/r /usr/local/x-ui/bin/clvmtargo.log" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_1/ i\\    - vm-tls-argo临时-8443" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_2/ i\\    - vm-tls-argo临时-8443" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_3/ i\\    - vm-tls-argo临时-8443" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_0/r /usr/local/x-ui/bin/clvmargo.log" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_1/ i\\    - vm-argo临时-8880" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_2/ i\\    - vm-argo临时-8880" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_3/ i\\    - vm-argo临时-8880" /usr/local/x-ui/bin/clmi.yaml
sed -i "/\/\/_0/r /usr/local/x-ui/bin/sbvmtargo.log" /usr/local/x-ui/bin/sbox.json
sed -i "/\/\/_1/ i\\ \"vm-tls-argo临时-8443\"," /usr/local/x-ui/bin/sbox.json
sed -i "/\/\/_2/ i\\ \"vm-tls-argo临时-8443\"," /usr/local/x-ui/bin/sbox.json
sed -i "/\/\/_0/r /usr/local/x-ui/bin/sbvmargo.log" /usr/local/x-ui/bin/sbox.json
sed -i "/\/\/_1/ i\\ \"vm-argo临时-8880\"," /usr/local/x-ui/bin/sbox.json
sed -i "/\/\/_2/ i\\ \"vm-argo临时-8880\"," /usr/local/x-ui/bin/sbox.json
echo -e "vmess://$(echo '{"add":"'$cdnargo'","aid":"0","host":"'$argolsym'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"8880","ps":"vm-argo临时-8880","v":"2"}' | base64 -w 0)" >>/usr/local/x-ui/bin/jhsub.txt
echo -e "vmess://$(echo '{"add":"'$cdnargo'","aid":"0","host":"'$argolsym'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"8443","ps":"vm-tls-argo临时-8443","tls":"tls","sni":"'$argolsym'","type":"none","v":"2"}' | base64 -w 0)" >>/usr/local/x-ui/bin/jhsub.txt
fi
fi

argoprotocol=$(jq -r --arg port "$(cat /usr/local/x-ui/xuiargoymport.log 2>/dev/null)" '.inbounds[] | select(.port == ($port | tonumber)) | .protocol' /usr/local/x-ui/bin/config.json 2>/dev/null)
uuid=$(jq -r --arg port "$(cat /usr/local/x-ui/xuiargoymport.log 2>/dev/null)" '.inbounds[] | select(.port == ($port | tonumber)) | .settings.clients[0].id' /usr/local/x-ui/bin/config.json 2>/dev/null)
ws_path=$(jq -r --arg port "$(cat /usr/local/x-ui/xuiargoymport.log 2>/dev/null)" '.inbounds[] | select(.port == ($port | tonumber)) | .streamSettings.wsSettings.path' /usr/local/x-ui/bin/config.json 2>/dev/null)
argotls=$(jq -r --arg port "$(cat /usr/local/x-ui/xuiargoymport.log 2>/dev/null)" '.inbounds[] | select(.port == ($port | tonumber)) | .streamSettings.security' /usr/local/x-ui/bin/config.json 2>/dev/null)
argoym=$(cat /usr/local/x-ui/xuiargoym.log 2>/dev/null)
if [[ -n $(ps -e | grep -w $ym 2>/dev/null) ]] && [[ -f /usr/local/x-ui/xuiargoymport.log ]] && [[ $argoprotocol =~ vless|vmess ]] && [[ ! "$argotls" = "tls" ]]; then
if [[ $argoprotocol = vless ]]; then
#vless-ws-tls-argo固定
cat > /usr/local/x-ui/bin/sbvltargoym.log <<EOF

{
            "server": "$cdnargo",
            "server_port": 8443,
            "tag": "vl-tls-argo固定-8443",
            "tls": {
                "enabled": true,
                "server_name": "$argoym",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argoym"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vless",
            "uuid": "$uuid"
        },
EOF

cat > /usr/local/x-ui/bin/clvltargoym.log <<EOF

- name: vl-tls-argo固定-8443                         
  type: vless
  server: $cdnargo                       
  port: 8443                                     
  uuid: $uuid     
  udp: true
  tls: true
  network: ws
  servername: $argoym                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argoym 

EOF

#vless-ws-argo固定
cat > /usr/local/x-ui/bin/sbvlargoym.log <<EOF

{
            "server": "$cdnargo",
            "server_port": 8880,
            "tag": "vl-argo固定-8880",
            "tls": {
                "enabled": false,
                "server_name": "$argoym",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argoym"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vless",
            "uuid": "$uuid"
        },
EOF

cat > /usr/local/x-ui/bin/clvlargoym.log <<EOF

- name: vl-argo固定-8880                         
  type: vless
  server: $cdnargo                       
  port: 8880                                     
  uuid: $uuid     
  udp: true
  tls: false
  network: ws
  servername: $argoym                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argoym 

EOF
sed -i "/#_0/r /usr/local/x-ui/bin/clvltargoym.log" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_1/ i\\    - vl-tls-argo固定-8443" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_2/ i\\    - vl-tls-argo固定-8443" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_3/ i\\    - vl-tls-argo固定-8443" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_0/r /usr/local/x-ui/bin/clvlargoym.log" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_1/ i\\    - vl-argo固定-8880" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_2/ i\\    - vl-argo固定-8880" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_3/ i\\    - vl-argo固定-8880" /usr/local/x-ui/bin/clmi.yaml
sed -i "/\/\/_0/r /usr/local/x-ui/bin/sbvltargoym.log" /usr/local/x-ui/bin/sbox.json
sed -i "/\/\/_1/ i\\ \"vl-tls-argo固定-8443\"," /usr/local/x-ui/bin/sbox.json
sed -i "/\/\/_2/ i\\ \"vl-tls-argo固定-8443\"," /usr/local/x-ui/bin/sbox.json
sed -i "/\/\/_0/r /usr/local/x-ui/bin/sbvlargoym.log" /usr/local/x-ui/bin/sbox.json
sed -i "/\/\/_1/ i\\ \"vl-argo固定-8880\"," /usr/local/x-ui/bin/sbox.json
sed -i "/\/\/_2/ i\\ \"vl-argo固定-8880\"," /usr/local/x-ui/bin/sbox.json
echo "vless://$uuid@$cdnargo:8880?type=ws&security=none&path=$ws_path&host=$argoym#vl-argo临时-8880" >>/usr/local/x-ui/bin/jhsub.txt
echo "vless://$uuid@$cdnargo:8443?type=ws&security=tls&path=$ws_path&host=$argoym#vl-tls-argo临时-8443" >>/usr/local/x-ui/bin/jhsub.txt

elif [[ $argoprotocol = vmess ]]; then
#vmess-ws-tls-argo固定
cat > /usr/local/x-ui/bin/sbvmtargoym.log <<EOF

{
            "server": "$cdnargo",
            "server_port": 8443,
            "tag": "vm-tls-argo固定-8443",
            "tls": {
                "enabled": true,
                "server_name": "$argoym",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argoym"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
EOF

cat > /usr/local/x-ui/bin/clvmtargoym.log <<EOF

- name: vm-tls-argo固定-8443                        
  type: vmess
  server: $cdnargo                        
  port: 8443                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: true
  network: ws
  servername: $argoym                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argoym

EOF

#vmess-ws-argo固定
cat > /usr/local/x-ui/bin/sbvmargoym.log <<EOF

{
            "server": "$cdnargo",
            "server_port": 8880,
            "tag": "vm-argo固定-8880",
            "tls": {
                "enabled": false,
                "server_name": "$argoym",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argoym"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
EOF

cat > /usr/local/x-ui/bin/clvmargoym.log <<EOF

- name: vm-argo固定-8880                         
  type: vmess
  server: $cdnargo                       
  port: 8880                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: false
  network: ws
  servername: $argoym                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argoym

EOF
sed -i "/#_0/r /usr/local/x-ui/bin/clvmtargoym.log" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_1/ i\\    - vm-tls-argo固定-8443" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_2/ i\\    - vm-tls-argo固定-8443" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_3/ i\\    - vm-tls-argo固定-8443" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_0/r /usr/local/x-ui/bin/clvmargoym.log" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_1/ i\\    - vm-argo固定-8880" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_2/ i\\    - vm-argo固定-8880" /usr/local/x-ui/bin/clmi.yaml
sed -i "/#_3/ i\\    - vm-argo固定-8880" /usr/local/x-ui/bin/clmi.yaml
sed -i "/\/\/_0/r /usr/local/x-ui/bin/sbvmtargoym.log" /usr/local/x-ui/bin/sbox.json
sed -i "/\/\/_1/ i\\ \"vm-tls-argo固定-8443\"," /usr/local/x-ui/bin/sbox.json
sed -i "/\/\/_2/ i\\ \"vm-tls-argo固定-8443\"," /usr/local/x-ui/bin/sbox.json
sed -i "/\/\/_0/r /usr/local/x-ui/bin/sbvmargoym.log" /usr/local/x-ui/bin/sbox.json
sed -i "/\/\/_1/ i\\ \"vm-argo固定-8880\"," /usr/local/x-ui/bin/sbox.json
sed -i "/\/\/_2/ i\\ \"vm-argo固定-8880\"," /usr/local/x-ui/bin/sbox.json
echo -e "vmess://$(echo '{"add":"'$cdnargo'","aid":"0","host":"'$argoym'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"8880","ps":"vm-argo固定-8880","v":"2"}' | base64 -w 0)" >>/usr/local/x-ui/bin/jhsub.txt
echo -e "vmess://$(echo '{"add":"'$cdnargo'","aid":"0","host":"'$argoym'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"8443","ps":"vm-tls-argo固定-8443","tls":"tls","sni":"'$argoym'","type":"none","v":"2"}' | base64 -w 0)" >>/usr/local/x-ui/bin/jhsub.txt
fi
fi
line=$(grep -B1 "//_1" /usr/local/x-ui/bin/sbox.json | grep -v "//_1")
new_line=$(echo "$line" | sed 's/,//g')
sed -i "/^$line$/s/.*/$new_line/g" /usr/local/x-ui/bin/sbox.json
sed -i '/\/\/_0\|\/\/_1\|\/\/_2/d' /usr/local/x-ui/bin/sbox.json
sed -i '/#_0\|#_1\|#_2\|#_3/d' /usr/local/x-ui/bin/clmi.yaml
find /usr/local/x-ui/bin -type f -name "*.log" -delete
baseurl=$(base64 -w 0 < /usr/local/x-ui/bin/jhsub.txt 2>/dev/null)
v2sub=$(cat /usr/local/x-ui/bin/jhsub.txt 2>/dev/null)
echo "$v2sub" > /usr/local/x-ui/bin/jhsub.txt
}

insxuiwpph(){
ins(){
if [ ! -e /usr/local/x-ui/xuiwpph ]; then
case $(uname -m) in
aarch64) cpu=arm64;;
x86_64) cpu=amd64;;
esac
curl -L -o /usr/local/x-ui/xuiwpph -# --retry 2 --insecure https://raw.githubusercontent.com/yonggekkk/x-ui-yg/main/xuiwpph_$cpu
chmod +x /usr/local/x-ui/xuiwpph
fi
if [[ -n $(ps -e | grep xuiwpph) ]]; then
kill -15 $(cat /usr/local/x-ui/xuiwpphid.log 2>/dev/null) >/dev/null 2>&1
fi
v4v6
if [[ -n $v4 ]]; then
sw46=4
else
red "IPV4不存在，确保安装过WARP-IPV4模式"
sw46=6
fi
echo
readp "设置WARP-plus-Socks5端口（回车跳过端口默认40000）：" port
if [[ -z $port ]]; then
port=40000
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") && -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] 
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") || -n $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义端口:" port
done
else
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") && -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") || -n $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\n端口被占用，请重新输入端口" && readp "自定义端口:" port
done
fi
}
unins(){
kill -15 $(cat /usr/local/x-ui/xuiwpphid.log 2>/dev/null) >/dev/null 2>&1
rm -rf /usr/local/x-ui/xuiwpph.log /usr/local/x-ui/xuiwpphid.log
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/xuiwpphid.log/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
}
echo
yellow "1：重置启用WARP-plus-Socks5本地Warp代理模式"
yellow "2：重置启用WARP-plus-Socks5多地区Psiphon代理模式"
yellow "3：停止WARP-plus-Socks5代理模式"
yellow "0：返回上层"
readp "请选择【0-3】：" menu
if [ "$menu" = "1" ]; then
ins
nohup setsid /usr/local/x-ui/xuiwpph -b 127.0.0.1:$port -$sw46 --endpoint 162.159.192.1:2408 >/dev/null 2>&1 & echo "$!" > /usr/local/x-ui/xuiwpphid.log
green "申请IP中……请稍等……" && sleep 20
resv1=$(curl -s --socks5 localhost:$port icanhazip.com)
resv2=$(curl -sx socks5h://localhost:$port icanhazip.com)
if [[ -z $resv1 && -z $resv2 ]]; then
red "WARP-plus-Socks5的IP获取失败" && unins && exit
else
echo "/usr/local/x-ui/xuiwpph -b 127.0.0.1:$port -$sw46 --endpoint 162.159.192.1:2408 >/dev/null 2>&1" > /usr/local/x-ui/xuiwpph.log
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/xuiwpphid.log/d' /tmp/crontab.tmp
echo '@reboot sleep 10 && /bin/bash -c "nohup setsid $(cat /usr/local/x-ui/xuiwpph.log 2>/dev/null) & pid=\$! && echo \$pid > /usr/local/x-ui/xuiwpphid.log"' >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
green "WARP-plus-Socks5的IP获取成功，可进行Socks5代理分流"
fi
elif [ "$menu" = "2" ]; then
ins
echo '
奥地利（AT）
澳大利亚（AU）
比利时（BE）
保加利亚（BG）
加拿大（CA）
瑞士（CH）
捷克 (CZ)
德国（DE）
丹麦（DK）
爱沙尼亚（EE）
西班牙（ES）
芬兰（FI）
法国（FR）
英国（GB）
克罗地亚（HR）
匈牙利 (HU)
爱尔兰（IE）
印度（IN）
意大利 (IT)
日本（JP）
立陶宛（LT）
拉脱维亚（LV）
荷兰（NL）
挪威 (NO)
波兰（PL）
葡萄牙（PT）
罗马尼亚 (RO)
塞尔维亚（RS）
瑞典（SE）
新加坡 (SG)
斯洛伐克（SK）
美国（US）
'
readp "可选择国家地区（输入末尾两个大写字母，如美国，则输入US）：" guojia
nohup setsid /usr/local/x-ui/xuiwpph -b 127.0.0.1:$port --cfon --country $guojia -$sw46 --endpoint 162.159.192.1:2408 >/dev/null 2>&1 & echo "$!" > /usr/local/x-ui/xuiwpphid.log
green "申请IP中……请稍等……" && sleep 20
resv1=$(curl -s --socks5 localhost:$port icanhazip.com)
resv2=$(curl -sx socks5h://localhost:$port icanhazip.com)
if [[ -z $resv1 && -z $resv2 ]]; then
red "WARP-plus-Socks5的IP获取失败，尝试换个国家地区吧" && unins && exit
else
echo "/usr/local/x-ui/xuiwpph -b 127.0.0.1:$port --cfon --country $guojia -$sw46 --endpoint 162.159.192.1:2408 >/dev/null 2>&1" > /usr/local/x-ui/xuiwpph.log
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/xuiwpphid.log/d' /tmp/crontab.tmp
echo '@reboot sleep 10 && /bin/bash -c "nohup setsid $(cat /usr/local/x-ui/xuiwpph.log 2>/dev/null) & pid=\$! && echo \$pid > /usr/local/x-ui/xuiwpphid.log"' >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
green "WARP-plus-Socks5的IP获取成功，可进行Socks5代理分流"
fi
elif [ "$menu" = "3" ]; then
unins && green "已停止WARP-plus-Socks5代理功能"
else
show_menu
fi
}

sbsm(){
echo
green "关注甬哥YouTube频道：https://youtube.com/@ygkkk?sub_confirmation=1 了解最新代理协议与翻墙动态"
echo
blue "x-ui-yg脚本视频教程：https://www.youtube.com/playlist?list=PLMgly2AulGG_Affv6skQXWnVqw7XWiPwJ"
echo
blue "x-ui-yg脚本博客说明：https://ygkkk.blogspot.com/2023/05/reality-xui-chatgpt.html"
echo
blue "x-ui-yg脚本项目地址：https://github.com/yonggekkk/x-ui-yg"
echo
}

show_menu(){
clear
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"           
echo -e "${bblue} ░██     ░██      ░██ ██ ██         ░█${plain}█   ░██     ░██   ░██     ░█${red}█   ░██${plain}  "
echo -e "${bblue}  ░██   ░██      ░██    ░░██${plain}        ░██  ░██      ░██  ░██${red}      ░██  ░██${plain}   "
echo -e "${bblue}   ░██ ░██      ░██ ${plain}                ░██ ██        ░██ █${red}█        ░██ ██  ${plain}   "
echo -e "${bblue}     ░██        ░${plain}██    ░██ ██       ░██ ██        ░█${red}█ ██        ░██ ██  ${plain}  "
echo -e "${bblue}     ░██ ${plain}        ░██    ░░██        ░██ ░██       ░${red}██ ░██       ░██ ░██ ${plain}  "
echo -e "${bblue}     ░█${plain}█          ░██ ██ ██         ░██  ░░${red}██     ░██  ░░██     ░██  ░░██ ${plain}  "
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
white "甬哥Github项目  ：github.com/yonggekkk"
white "甬哥Blogger博客 ：ygkkk.blogspot.com"
white "甬哥YouTube频道 ：www.youtube.com/@ygkkk"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
white "x-ui-yg脚本快捷方式：x-ui"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
green " 1. 一键安装 x-ui"
green " 2. 删除卸载 x-ui"
echo "----------------------------------------------------------------------------------"
green " 3. 其他设置 【Argo双隧道、订阅优选IP、Gitlab订阅链接、获取warp-wireguard账号配置】"
green " 4. 变更 x-ui 面板设置 【用户名密码、登录端口、根路径、还原面板】"
green " 5. 关闭、重启 x-ui"
green " 6. 更新 x-ui 脚本"
echo "----------------------------------------------------------------------------------"
green " 7. 更新并查看聚合通用节点、clash-meta与sing-box客户端配置及订阅链接"
green " 8. 查看 x-ui 运行日志"
green " 9. 一键原版BBR+FQ加速"
green "10. 管理 Acme 申请域名证书"
green "11. 管理 Warp 查看本地Netflix、ChatGPT解锁情况"
green "12. 添加WARP-plus-Socks5代理模式 【本地Warp/多地区Psiphon-VPN】"
green "13. 刷新IP配置及参数显示"
echo "----------------------------------------------------------------------------------"
green "14. x-ui-yg脚本使用说明书"
echo "----------------------------------------------------------------------------------"
green " 0. 退出脚本"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
insV=$(cat /usr/local/x-ui/v 2>/dev/null)
#latestV=$(curl -s https://gitlab.com/rwkgyg/x-ui-yg/-/raw/main/version/version | awk -F "更新内容" '{print $1}' | head -n 1)
latestV=$(curl -sL https://raw.githubusercontent.com/yonggekkk/x-ui-yg/main/version | awk -F "更新内容" '{print $1}' | head -n 1)
if [[ -f /usr/local/x-ui/v ]]; then
if [ "$insV" = "$latestV" ]; then
echo -e "当前 x-ui-yg 脚本最新版：${bblue}${insV}${plain} (已安装)"
else
echo -e "当前 x-ui-yg 脚本版本号：${bblue}${insV}${plain}"
echo -e "检测到最新 x-ui-yg 脚本版本号：${yellow}${latestV}${plain} (可选择6进行更新)"
echo -e "${yellow}$(curl -sL https://raw.githubusercontent.com/yonggekkk/x-ui-yg/main/version)${plain}"
#echo -e "${yellow}$(curl -sL https://gitlab.com/rwkgyg/x-ui-yg/-/raw/main/version/version)${plain}"
fi
else
echo -e "当前 x-ui-yg 脚本版本号：${bblue}${latestV}${plain}"
echo -e "请先选择 1 ，安装 x-ui-yg 脚本"
fi
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
echo -e "VPS状态如下："
echo -e "系统:$blue$op$plain  \c";echo -e "内核:$blue$version$plain  \c";echo -e "处理器:$blue$cpu$plain  \c";echo -e "虚拟化:$blue$vi$plain  \c";echo -e "BBR算法:$blue$bbr$plain"
v4v6
if [[ "$v6" == "2a09"* ]]; then
w6="【WARP】"
fi
if [[ "$v4" == "104.28"* ]]; then
w4="【WARP】"
fi
if [[ -z $v4 ]]; then
vps_ipv4='无IPV4'      
vps_ipv6="$v6"
location="$v6dq"
elif [[ -n $v4 && -n $v6 ]]; then
vps_ipv4="$v4"    
vps_ipv6="$v6"
location="$v4dq"
else
vps_ipv4="$v4"    
vps_ipv6='无IPV6'
location="$v4dq"
fi
echo -e "本地IPV4地址：$blue$vps_ipv4$w4$plain   本地IPV6地址：$blue$vps_ipv6$w6$plain"
echo -e "服务器地区：$blue$location$plain"
echo "------------------------------------------------------------------------------------"
if [[ -n $(ps -e | grep xuiwpph) ]]; then
s5port=$(cat /usr/local/x-ui/xuiwpph.log 2>/dev/null | awk '{print $3}'| awk -F":" '{print $NF}')
s5gj=$(cat /usr/local/x-ui/xuiwpph.log 2>/dev/null | awk '{print $6}')
case "$s5gj" in
AT) showgj="奥地利" ;;
AU) showgj="澳大利亚" ;;
BE) showgj="比利时" ;;
BG) showgj="保加利亚" ;;
CA) showgj="加拿大" ;;
CH) showgj="瑞士" ;;
CZ) showgj="捷克" ;;
DE) showgj="德国" ;;
DK) showgj="丹麦" ;;
EE) showgj="爱沙尼亚" ;;
ES) showgj="西班牙" ;;
FI) showgj="芬兰" ;;
FR) showgj="法国" ;;
GB) showgj="英国" ;;
HR) showgj="克罗地亚" ;;
HU) showgj="匈牙利" ;;
IE) showgj="爱尔兰" ;;
IN) showgj="印度" ;;
IT) showgj="意大利" ;;
JP) showgj="日本" ;;
LT) showgj="立陶宛" ;;
LV) showgj="拉脱维亚" ;;
NL) showgj="荷兰" ;;
NO) showgj="挪威" ;;
PL) showgj="波兰" ;;
PT) showgj="葡萄牙" ;;
RO) showgj="罗马尼亚" ;;
RS) showgj="塞尔维亚" ;;
SE) showgj="瑞典" ;;
SG) showgj="新加坡" ;;
SK) showgj="斯洛伐克" ;;
US) showgj="美国" ;;
esac
grep -q "country" /usr/local/x-ui/xuiwpph.log 2>/dev/null && s5ms="多地区Psiphon代理模式 (端口:$s5port  国家:$showgj)" || s5ms="本地Warp代理模式 (端口:$s5port)"
echo -e "WARP-plus-Socks5状态：$blue已启动 $s5ms$plain"
else
echo -e "WARP-plus-Socks5状态：$blue未启动$plain"
fi
echo "------------------------------------------------------------------------------------"
argopid
if [[ -n $(ps -e | grep -w $ym 2>/dev/null) || -n $(ps -e | grep -w $ls 2>/dev/null) ]]; then
if [[ -f /usr/local/x-ui/xuiargoport.log ]]; then
argoprotocol=$(jq -r --arg port "$(cat /usr/local/x-ui/xuiargoport.log 2>/dev/null)" '.inbounds[] | select(.port == ($port | tonumber)) | .protocol' /usr/local/x-ui/bin/config.json)
echo -e "Argo临时隧道状态：$blue已启动 【监听$yellow${argoprotocol}-ws$plain$blue节点的端口:$plain$yellow$(cat /usr/local/x-ui/xuiargoport.log 2>/dev/null)$plain$blue】$plain$plain"
argotro=$(jq -r --arg port "$(cat /usr/local/x-ui/xuiargoport.log 2>/dev/null)" '.inbounds[] | select(.port == ($port | tonumber)) | .settings.clients[0].password' /usr/local/x-ui/bin/config.json)
argoss=$(jq -r --arg port "$(cat /usr/local/x-ui/xuiargoport.log 2>/dev/null)" '.inbounds[] | select(.port == ($port | tonumber)) | .settings.password' /usr/local/x-ui/bin/config.json)
argouuid=$(jq -r --arg port "$(cat /usr/local/x-ui/xuiargoport.log 2>/dev/null)" '.inbounds[] | select(.port == ($port | tonumber)) | .settings.clients[0].id' /usr/local/x-ui/bin/config.json)
argopath=$(jq -r --arg port "$(cat /usr/local/x-ui/xuiargoport.log 2>/dev/null)" '.inbounds[] | select(.port == ($port | tonumber)) | .streamSettings.wsSettings.path' /usr/local/x-ui/bin/config.json)
if [[ ! $argouuid = "null" ]]; then
argoma=$argouuid
elif [[ ! $argoss = "null" ]]; then
argoma=$argoss
else
argoma=$argotro
fi
argotls=$(jq -r --arg port "$(cat /usr/local/x-ui/xuiargoport.log 2>/dev/null)" '.inbounds[] | select(.port == ($port | tonumber)) | .streamSettings.security' /usr/local/x-ui/bin/config.json)
if [[ -n $argouuid ]]; then
if [[ "$argotls" = "tls" ]]; then
echo -e "错误反馈：$red面板创建的ws节点开启了tls，不支持Argo，请在面板对应的节点中关闭tls$plain"
else
echo -e "Argo密码/UUID：$blue$argoma$plain"
echo -e "Argo路径path：$blue$argopath$plain"
argolsym=$(cat /usr/local/x-ui/argo.log 2>/dev/null | grep -a trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
[[ $(echo "$argolsym" | grep -w "api.trycloudflare.com/tunnel") ]] && argolsyms='生成失败，请重置' || argolsyms=$argolsym
echo -e "Argo临时域名：$blue$argolsyms$plain"
fi
else
echo -e "错误反馈：$red面板尚未创建一个端口为$yellow$(cat /usr/local/x-ui/xuiargoport.log 2>/dev/null)$plain$red的ws节点，推荐vmess-ws$plain$plain"
fi
fi
if [[ -f /usr/local/x-ui/xuiargoymport.log && -f /usr/local/x-ui/xuiargoport.log ]]; then
echo "--------------------------"
fi
if [[ -f /usr/local/x-ui/xuiargoymport.log ]]; then
argoprotocol=$(jq -r --arg port "$(cat /usr/local/x-ui/xuiargoymport.log 2>/dev/null)" '.inbounds[] | select(.port == ($port | tonumber)) | .protocol' /usr/local/x-ui/bin/config.json)
echo -e "Argo固定隧道状态：$blue已启动 【监听$yellow${argoprotocol}-ws$plain$blue节点的端口:$plain$yellow$(cat /usr/local/x-ui/xuiargoymport.log 2>/dev/null)$plain$blue】$plain$plain"
argotro=$(jq -r --arg port "$(cat /usr/local/x-ui/xuiargoymport.log 2>/dev/null)" '.inbounds[] | select(.port == ($port | tonumber)) | .settings.clients[0].password' /usr/local/x-ui/bin/config.json)
argoss=$(jq -r --arg port "$(cat /usr/local/x-ui/xuiargoymport.log 2>/dev/null)" '.inbounds[] | select(.port == ($port | tonumber)) | .settings.password' /usr/local/x-ui/bin/config.json)
argouuid=$(jq -r --arg port "$(cat /usr/local/x-ui/xuiargoymport.log 2>/dev/null)" '.inbounds[] | select(.port == ($port | tonumber)) | .settings.clients[0].id' /usr/local/x-ui/bin/config.json)
argopath=$(jq -r --arg port "$(cat /usr/local/x-ui/xuiargoymport.log 2>/dev/null)" '.inbounds[] | select(.port == ($port | tonumber)) | .streamSettings.wsSettings.path' /usr/local/x-ui/bin/config.json)
if [[ ! $argouuid = "null" ]]; then
argoma=$argouuid
elif [[ ! $argoss = "null" ]]; then
argoma=$argoss
else
argoma=$argotro
fi
argotls=$(jq -r --arg port "$(cat /usr/local/x-ui/xuiargoymport.log 2>/dev/null)" '.inbounds[] | select(.port == ($port | tonumber)) | .streamSettings.security' /usr/local/x-ui/bin/config.json)
if [[ -n $argouuid ]]; then
if [[ "$argotls" = "tls" ]]; then
echo -e "错误反馈：$red面板创建的ws节点开启了tls，不支持Argo，请在面板对应的节点中关闭tls$plain"
else
echo -e "Argo密码/UUID：$blue$argoma$plain"
echo -e "Argo路径path：$blue$argopath$plain"
echo -e "Argo固定域名：$blue$(cat /usr/local/x-ui/xuiargoym.log 2>/dev/null)$plain"
fi
else
echo -e "错误反馈：$red面板尚未创建一个端口为$yellow$(cat /usr/local/x-ui/xuiargoymport.log 2>/dev/null)$plain$red的ws节点，推荐vmess-ws$plain$plain"
fi
fi
else
echo -e "Argo状态：$blue未启动$plain"
fi
echo "------------------------------------------------------------------------------------"
show_status
echo "------------------------------------------------------------------------------------"
acp=$(/usr/local/x-ui/x-ui setting -show 2>/dev/null)
if [[ -n $acp ]]; then
if [[ $acp == *admin*  ]]; then
red "x-ui出错，请选择4重置用户名密码或者卸载重装x-ui"
else
xpath=$(echo $acp | awk '{print $8}')
xport=$(echo $acp | awk '{print $6}')
xip1=$(cat /usr/local/x-ui/xip 2>/dev/null | sed -n 1p)
xip2=$(cat /usr/local/x-ui/xip 2>/dev/null | sed -n 2p)
temp=$(systemctl is-active x-ui 2>/dev/null | grep -w active)
if [[ x"${temp}" == x"active" ]]; then
if [ -s /usr/local/x-ui/bin/subport.log ]; then
showsubport=$(cat /usr/local/x-ui/bin/subport.log)
if ps -ef 2>/dev/null | grep "$showsubport" | grep -v grep >/dev/null; then
showsubtoken=$(cat /usr/local/x-ui/bin/subtoken.log 2>/dev/null)
suburl="$xip1:$showsubport/$showsubtoken"
echo "Clash/Mihomo本地IP订阅地址：http://$suburl/clmi.yaml"
echo "Sing-box本地IP订阅地址：http://$suburl/sbox.json"
echo "聚合协议本地IP订阅地址：http://$suburl/jhsub.txt"
fi
fi
fi
if [ "$xpath" == "/" ]; then
pathk="$sred【严重安全提示: 请进入面板设置，添加url根路径】$plain"
fi
echo -e "x-ui登录信息如下："
echo -e "$blue$acp$pathk$plain" 
if [[ -n $xip2 ]]; then
xuimb="http://${xip1}:${xport}${xpath} 或者 http://${xip2}:${xport}${xpath}"
else
xuimb="http://${xip1}:${xport}${xpath}"
fi
echo -e "$blue登录地址(裸IP泄露模式-非安全)：$xuimb$plain"
if [[ -f /root/ygkkkca/cert.crt && -f /root/ygkkkca/private.key && -s /root/ygkkkca/cert.crt && -s /root/ygkkkca/private.key ]]; then
ym=`bash ~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}'`
echo $ym > /root/ygkkkca/ca.log
fi
if [[ -f /root/ygkkkca/ca.log ]]; then
echo -e "$blue登录地址(域名加密模式-安全)：https://$(cat /root/ygkkkca/ca.log 2>/dev/null):${xport}${xpath}$plain"
else
echo -e "$sred强烈建议申请域名证书并开启域名(https)登录方式，以确保面板数据安全$plain"
fi
fi
else
echo -e "x-ui登录信息如下："
echo -e "$red未安装x-ui，无显示$plain"
fi
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
echo
readp "请输入数字【0-14】:" Input
case "$Input" in     
 1 ) check_uninstall && xuiinstall;;
 2 ) check_install && uninstall;;
 3 ) check_install && changeserv;;
 4 ) check_install && xuichange;;
 5 ) check_install && xuirestop;;
 6 ) check_install && update;;
 7 ) check_install && sharesub;;
 8 ) check_install && show_log;;
 9 ) bbr;;
 10  ) acme;;
 11 ) cfwarp;;
 12 ) check_install && insxuiwpph;;
 13 ) check_install && showxuiip && show_menu;;
 14 ) sbsm;;
 * ) exit 
esac
}
show_menu

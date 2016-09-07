#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#===============================================================================================
#   System Required:  CentOS Debian or Ubuntu (32bit/64bit)
#   Description:  A tool to auto-compile & install kcptun-server on Linux
#   Author: Clang
#   Intro:  http://koolshare.cn/forum-72-1.html
#===============================================================================================
version="2.1"
str_program_dir="/usr/local/kcp-server"
kcptun_latest="https://github.com/xtaci/kcptun/releases/latest"
program_name="kcp-server"
kcp_init="/etc/init.d/${program_name}"
program_config_file="server-kcptun.json"
program_download_url="https://github.com/xtaci/kcptun/releases/download"
program_socks5_download="https://raw.githubusercontent.com/clangcn/kcp-server/master/socks5_latest"
program_socks5_filename="socks5"
socks_md5sum_file=md5sum.md
program_init_download_url=https://raw.githubusercontent.com/clangcn/kcp-server/master/kcptun-server.init
str_install_shell=https://raw.githubusercontent.com/clangcn/kcp-server/master/install-kcp-server.sh

function fun_clang.cn(){
    echo ""
    echo "+---------------------------------------------------------+"
    echo "|        kcptun for Linux Server, Written by Clang        |"
    echo "+---------------------------------------------------------+"
    echo "| A tool to auto-compile & install kcptun-server on Linux |"
    echo "+---------------------------------------------------------+"
    echo "|        Intro: http://koolshare.cn/forum-72-1.html       |"
    echo "+---------------------------------------------------------+"
    echo ""
}

function fun_set_text_color(){
    COLOR_RED='\E[1;31m'
    COLOR_GREEN='\E[1;32m'
    COLOR_YELOW='\E[1;33m'
    COLOR_BLUE='\E[1;34m'
    COLOR_PINK='\E[1;35m'
    COLOR_PINKBACK_WHITEFONT='\033[45;37m'
    COLOR_GREEN_LIGHTNING='\033[32m \033[05m'
    COLOR_END='\E[0m'
}
# Check if user is root
function rootness(){
    if [[ $EUID -ne 0 ]]; then
        fun_clang.cn
        echo "Error:This script must be run as root!" 1>&2
        exit 1
    fi
}

function get_char(){
    SAVEDSTTY=`stty -g`
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}

# Check OS
function checkos(){
    if grep -Eqi "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        OS=CentOS
    elif grep -Eqi "Debian" /etc/issue || grep -Eq "Debian" /etc/*-release; then
        OS=Debian
    elif grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
        OS=Ubuntu
    else
        echo "Not support OS, Please reinstall OS and retry!"
        exit 1
    fi
}

# Get version
function getversion(){
    if [[ -s /etc/redhat-release ]];then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
}

# CentOS version
function centosversion(){
    local code=$1
    local version="`getversion`"
    local main_ver=${version%%.*}
    if [ $main_ver == $code ];then
        return 0
    else
        return 1
    fi
}

# Check OS bit
function check_os_bit(){
    ARCHS=""
    if [[ `getconf WORD_BIT` = '32' && `getconf LONG_BIT` = '64' ]] ; then
        Is_64bit='y'
        ARCHS="amd64"
    else
        Is_64bit='n'
        ARCHS="386"
    fi
}

function check_centosversion(){
if centosversion 5; then
    echo "Not support CentOS 5.x, please change to CentOS 6,7 or Debian or Ubuntu and try again."
    exit 1
fi
}

# Disable selinux
function disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

# Check port
function fun_check_port(){
    port_flag=""
    strCheckPort=""
    input_port=""
    port_flag="$1"
    strCheckPort="$2"
    if [ ${strCheckPort} -ge 1 ] && [ ${strCheckPort} -le 65535 ]; then
        checkServerPort=`netstat -ntulp | grep "\b:${strCheckPort}\b"`
        if [ -n "${checkServerPort}" ]; then
            echo ""
            echo -e "${COLOR_RED}Error:${COLOR_END} Port ${COLOR_GREEN}${strCheckPort}${COLOR_END} is ${COLOR_PINK}used${COLOR_END},view relevant port:"
            netstat -ntulp | grep "\b:${strCheckPort}\b"
            fun_input_${port_flag}_port
        else
            input_port="${strCheckPort}"
        fi
    else
        echo "Input error! Please input correct numbers."
        fun_input_${port_flag}_port
    fi
}

# input port
function fun_input_kcptun_port(){
    def_server_port="45678"
    echo ""
    echo -n -e "Please input ${COLOR_GREEN}Kcptun${COLOR_END} Port [1-65535]"
    read -p "(Default Server Port: ${def_server_port}):" serverport
    [ -z "${serverport}" ] && serverport="${def_server_port}"
    fun_check_port "kcptun" "${serverport}"
}
# input port
function fun_input_socks5_port(){
    def_socks5_port="12948"
    #echo ""
    #echo -e "Please input Server Socks5 Port [1-65535](Don't the same SSH Port ${COLOR_RED}${sshport}${COLOR_END})"
    #read -p "(Default Server Port: ${def_socks5_port}):" socks5_port
    #[ -z "${socks5_port}" ] && socks5_port="${def_socks5_port}"
    #fun_check_port "socks5" "${socks5_port}"
}
# Check mtu
function fun_check_mtu(){
    strInputMTU="$1"
    if [ ${strInputMTU} -ge 900 ] && [ ${strInputMTU} -le 1400 ]; then
        strInputMTU="${strInputMTU}"
        echo "mtu ${strInputMTU}"
    else
        echo "Input error! Please input correct numbers."
        fun_input_mtu
    fi
}

# input port
function fun_input_mtu(){
    def_mtu="1350"
    echo ""
    read -p "Please input mtu [900-1400],(Default mtu: ${def_mtu}):" strMTU
    [ -z "${strMTU}" ] && strMTU="${def_mtu}"
    fun_check_mtu "${strMTU}"
}
# ====== check packs ======
function check_net-tools(){
    netstat -V >/dev/null
    if [[ $? -gt 6 ]] ;then
        echo " Run net-tools failed"
        if [ "${OS}" == 'CentOS' ]; then
            echo " Install centos net-tools ..."
            yum -y install net-tools
        else
            echo " Install debian/ubuntu net-tools ..."
            apt-get update -y
            apt-get install -y net-tools
        fi
    fi
    echo $result
}
function check_iptables(){
    iptables -V >/dev/null
    if [[ $? -gt 1 ]] ;then
        echo " Run iptables failed"
        if [ "${OS}" == 'CentOS' ]; then
            echo " Install centos iptables ..."
            yum -y install iptables policycoreutils libpcap libpcap-devel
        else
            echo " Install debian/ubuntu iptables ..."
            apt-get update -y
            apt-get install -y iptables libpcap-dev
        fi
    fi
    echo $result
}
function check_curl(){
    curl -V >/dev/null
    if [[ $? -gt 1 ]] ;then
        echo " Run curl failed"
        if [ "${OS}" == 'CentOS' ]; then
            echo " Install centos curl ..."
            yum -y install curl curl-devel
        else
            echo " Install debian/ubuntu curl ..."
            apt-get update -y
            apt-get install -y curl
        fi
    fi
    echo $result
}
function check_md5sum(){
    md5sum --version >/dev/null
    if [[ $? -gt 6 ]] ;then
        echo " Run md5sum failed"
    fi
    echo $result
}
# Random password
function fun_randstr(){
  index=0
  strRandomPass=""
  for i in {a..z}; do arr[index]=$i; index=`expr ${index} + 1`; done
  for i in {A..Z}; do arr[index]=$i; index=`expr ${index} + 1`; done
  for i in {0..9}; do arr[index]=$i; index=`expr ${index} + 1`; done
  for i in {1..16}; do strRandomPass="$strRandomPass${arr[$RANDOM%$index]}"; done
  echo $strRandomPass
}
function fun_getVer(){
    kcptun_version=""
    kcptun_latest_release=""
    kcptun_latest_download=""
    kcptun_latest_filename=""
    echo -e "Loading network version for kcptun, please wait..."
    check_curl
    kcptun_latest_release=`curl -s ${kcptun_latest} | cut -d\" -f2`
    kcptun_latest_download=`curl -s ${kcptun_latest} | cut -d\" -f2 | sed 's/tag/download/'`
    kcptun_latest_filename=`curl -s ${kcptun_latest_release} | sed -n '/<strong>kcptun-linux-'${ARCHS}'/p' | cut -d">" -f2 | cut -d "<" -f1`
    if [ -z "${kcptun_latest_filename}" ]; then
        echo -e "${COLOR_RED}Load network version failed!!!${COLOR_END}"
        echo "You can get version number from https://github.com/xtaci/kcptun/releases"
        read -p "(Please input kcptun Version you want[e.g.: 20160820]):" kcptun_version
        if [ "${kcptun_version}" = "" ]; then
            echo "Error: You must input kcptun_version version!!"
            exit 1
        fi
        echo "=================================================="
        echo -e "You want download version to ${COLOR_GREEN}${kcptun_version}${COLOR_END}"
        echo "=================================================="
        echo -e "${COLOR_YELOW}Press any key to start...or Press Ctrl+c to cancel${COLOR_END}"
        char=`get_char`
    else
        echo -e "Kcptun Latest release file ${COLOR_GREEN}${kcptun_latest_filename}${COLOR_END}"
    fi
    
}
function fun_download_file(){
    # download kcptun
    if [ ! -s ${str_program_dir}/${program_name} ]; then
        if [ -z "${kcptun_latest_filename}" ]; then
            if ! wget --no-check-certificate ${program_download_url}/v${kcptun_version}/kcptun-linux-${ARCHS}-${kcptun_version}.tar.gz; then
                echo "Failed to download kcptun-linux-${ARCHS}-${kcptun_version}.tar.gz file!"
                exit 1
            fi
            tar xzvf kcptun-linux-${ARCHS}-${kcptun_version}.tar.gz
            mv server_linux_${ARCHS} ${str_program_dir}/${program_name}
            rm -f kcptun-linux-${ARCHS}-${kcptun_version}.tar.gz client_linux_${ARCHS}
        else
            rm -f ${kcptun_latest_filename} server_linux_${ARCHS} client_linux_${ARCHS}
            if ! wget --no-check-certificate ${kcptun_latest_download}/${kcptun_latest_filename}; then
                echo "Failed to download ${kcptun_latest_filename} file!"
                exit 1
            fi
            check_md5sum
            kcptun_md5_web=`curl -s ${kcptun_latest_release} | sed -n '/MD5 (kcptun-linux-'${ARCHS}'/p' | cut -d"=" -f2 | sed s/[[:space:]]//g`
            down_local_md5=`md5sum ${kcptun_latest_filename} | awk '{print $1}'`
            if [ "${down_local_md5}" != "${kcptun_md5_web}" ]; then
                echo "md5sum not match,Failed to download ${kcptun_latest_filename} file!"
                exit 1
            fi
            tar xzvf ${kcptun_latest_filename}
            mv server_linux_${ARCHS} ${str_program_dir}/${program_name}
            rm -f ${kcptun_latest_filename} client_linux_${ARCHS}
        fi
    fi
    # download socks5 proxy
    if [ ! -s ${str_program_dir}/${program_socks5_filename} ]; then
        if ! wget --no-check-certificate ${program_socks5_download}/socks5_linux_${ARCHS} -O ${str_program_dir}/${program_socks5_filename}; then
            echo "Failed to download socks5_linux_${ARCHS} file!"
            exit 1
        fi
        socks5_md5_web=`curl -s ${program_socks5_download}/${socks_md5sum_file} | sed  -n "/socks5_linux_${ARCHS}/p" | awk '{print $1}'`
        socks5_local_md5=`md5sum ${str_program_dir}/${program_socks5_filename} | awk '{print $1}'`
        if [ "${socks5_local_md5}" != "${socks5_md5_web}" ]; then
            echo "md5sum not match,Failed to download ${program_socks5_filename} file!"
            exit 1
        fi
    fi
    chown root:root ${str_program_dir}/*
    [ ! -x ${str_program_dir}/${program_name} ] && chmod 755 ${str_program_dir}/${program_name}
    [ ! -x ${str_program_dir}/${program_socks5_filename} ] && chmod 755 ${str_program_dir}/${program_socks5_filename}
}
# ====== install kcptun server ======
function install_program_server_clang(){
    fun_getVer
    #config setting
    sshport=`sed -n '/^Port/p' /etc/ssh/sshd_config | awk 'NR==1 { print $2}'`
    if [ "${sshport}" = "" ]; then
        sshport=`netstat -anp |grep ssh | grep '0.0.0.0:'|cut -d: -f2| awk 'NR==1 { print $1}'`
    fi
    #defIP=`ifconfig  | grep 'inet addr:'| grep -v '127.0.0.' | cut -d: -f2 | awk 'NR==1 { print $1}'`
    #if [ "${defIP}" = "" ]; then
        check_curl
        defIP=$(curl -s -4 ip.clang.cn | sed -r 's/\r//')
    #fi
    echo -e "You VPS IP:${COLOR_GREEN}${defIP}${COLOR_END}"
    echo -e  "${COLOR_YELOW}Please input your server setting:${COLOR_END}"
    echo ""
    fun_input_kcptun_port
    [ -n "${input_port}" ] && set_kcptun_port="${input_port}"
    echo "kcptun port: ${set_kcptun_port}"
    echo ""
    default_kcptun_pwd=`fun_randstr`
    read -p "Please input Password (Default Password: ${default_kcptun_pwd}):" set_kcptun_pwd
    [ -z "${set_kcptun_pwd}" ] && set_kcptun_pwd="${default_kcptun_pwd}"
    echo "kcptun password: ${set_kcptun_pwd}"
    echo ""
    echo "##### Please select crypt mode #####"
    echo " 1: aes"
    echo " 2: aes-128"
    echo " 3: aes-192"
    echo " 4: salsa20"
    echo " 5: blowfish"
    echo " 6: twofish"
    echo " 7: cast5"
    echo " 8: 3des"
    echo " 9: tea"
    echo "10: xtea"
    echo "11: xor"
    echo " n: none"
    echo "#####################################################"
    read -p "Enter your choice (1, 2, 3, ... or exit. default [1]): " strcrypt
    case "${strcrypt}" in
        1|[aA][eE][sS])
            strcrypt="aes"
            ;;
        2|[aA][eE][sS]-128)
            strcrypt="aes-128"
            ;;
        3|[aA][eE][sS]-192)
            strcrypt="aes-192"
            ;;
        4|[sS][aA][lL][sS][aA]20)
            strcrypt="salsa20"
            ;;
        5|[bB][lL][oO][wW][fF][iI][sS][hH])
            strcrypt="blowfish"
            ;;
        6|[tT][wW][oO][fF][iI][sS][hH])
            strcrypt="twofish"
            ;;
        7|[cC][aA][sS][tT]5)
            strcrypt="cast5"
            ;;
        8|3[dD][eE][sS])
            strcrypt="3des"
            ;;
        9|[tT][eE][aA])
            strcrypt="tea"
            ;;
        10|[xX][tT][eE][aA])
            strcrypt="xtea"
            ;;
        11|[xX][oO][rR])
            strcrypt="xor"
            ;;
        12|[nN]|[nN][oO][nN][eE])
            strcrypt="none"
            ;;
        [eE][xX][iI][tT])
            exit 1
            ;;
        *)
            strcrypt="aes"
            ;;
    esac
    echo "crypt mode: ${strcrypt}"
    echo ""
    echo "##### Please select fast mode #####"
    echo "1: fast"
    echo "2: fast2"
    echo "3: fast3"
    echo "4: normal"
    echo "#####################################################"
    read -p "Enter your choice (1, 2, 3, 4 or exit. default [2]): " strmode
    case "${strmode}" in
        1|[fF][aA][sS][tT])
            strmode="fast"
            ;;
        2|[fF][aA][sS][tT]2)
            strmode="fast2"
            ;;
        3|[fF][aA][sS][tT]3)
            strmode="fast3"
            ;;
        4|[nN][oO][rR][mM][aA][lL])
            strmode="normal"
            ;;
        [eE][xX][iI][tT])
            exit 1
            ;;
        *)
            strmode="fast2"
            ;;
    esac
    echo "fast mode: ${strmode}"
    fun_input_mtu
    read -p "Please enable compression input Y, Disable compression input n,Default [yes]):" strcompression
    case "${strcompression}" in
    1|[yY]|[yY][eE][sS]|[tT][rR][uU][eE]|[eE][nN][aA][bB][lL][eE])
        strcompression="enable"
        set_kcptun_comp="false"
    ;;
    0|[nN]|[nN][oO]|[fF][aA][lL][sS][eE]|[dD][iI][sS][aA][bB][lL][eE])
        strcompression="disable"
        set_kcptun_comp="true"
    ;;
    *)
        strcompression="enable"
        set_kcptun_comp="false"
    esac
    echo "compression: ${strcompression}"
    echo ""
    fun_input_socks5_port
    set_socks5_port="${def_socks5_port}"
    echo "socks5 port: ${set_socks5_port}"
    echo ""
    set_iptables="n"
        echo  -e "\033[33mDo you want to set iptables?\033[0m"
        read -p "(if you want please input: y,Default [no]):" set_iptables

        case "${set_iptables}" in
        [yY]|[yY][eE][sS])
        echo "You will set iptables!"
        set_iptables="y"
        ;;
        [nN]|[nN][oO])
        echo "You will NOT set iptables!"
        set_iptables="n"
        ;;
        *)
        echo "The iptables is not set!"
        set_iptables="n"
        esac

    echo ""
    echo "============== Check your input =============="
    echo -e "Socks5 Port: ${COLOR_GREEN}${set_socks5_port}${COLOR_END}"
    echo -e "Kcptun Port: ${COLOR_GREEN}${set_kcptun_port}${COLOR_END}"
    echo -e "Kcptun key : ${COLOR_GREEN}${set_kcptun_pwd}${COLOR_END}"
    echo -e "crypt mode : ${COLOR_GREEN}${strcrypt}${COLOR_END}"
    echo -e "fast mode  : ${COLOR_GREEN}${strmode}${COLOR_END}"
    echo -e "compression: ${COLOR_GREEN}${strcompression}${COLOR_END}"
    echo -e "MTU        : ${COLOR_GREEN}${strInputMTU}${COLOR_END}"
    echo "=============================================="
    echo ""
    echo "Press any key to start...or Press Ctrl+c to cancel"

    char=`get_char`

    [ ! -d ${str_program_dir} ] && mkdir -p ${str_program_dir}
    cd ${str_program_dir}
    echo $PWD

# Config file
cat > ${str_program_dir}/${program_config_file}<<-EOF
{
    "listen": ":${set_kcptun_port}",
    "target": "127.0.0.1:${set_socks5_port}",
    "key": "${set_kcptun_pwd}",
    "crypt": "${strcrypt}",
    "mode": "${strmode}",
    "mtu": ${strInputMTU},
    "sndwnd": 1024,
    "rcvwnd": 1024,
    "datashard": 70,
    "parityshard": 30,
    "dscp": 46,
    "nocomp": ${set_kcptun_comp},
    "acknodelay": false,
    "nodelay": 0,
    "interval": 40,
    "resend": 0,
    "nc": 0,
    "sockbuf": 4194304,
    "keepalive": 10
}
EOF
cat > ${str_program_dir}/client.json<<-EOF
{
    "localaddr": ":1082",
    "remoteaddr": "${defIP}:${set_kcptun_port}",
    "key": "${set_kcptun_pwd}",
    "crypt": "${strcrypt}",
    "mode": "${strmode}",
    "conn": 1,
    "autoexpire": 60,
    "mtu": ${strInputMTU},
    "sndwnd": 128,
    "rcvwnd": 1024,
    "datashard": 70,
    "parityshard": 30,
    "dscp": 46,
    "nocomp": ${set_kcptun_comp},
    "acknodelay": false,
    "nodelay": 0,
    "interval": 40,
    "resend": 0,
    "nc": 0,
    "sockbuf": 4194304,
    "keepalive": 10
}
EOF
    rm -f ${str_program_dir}/${program_name} ${str_program_dir}/${program_socks5_filename}
    fun_download_file
    if [ ! -s ${kcp_init} ]; then
        if ! wget --no-check-certificate ${program_init_download_url} -O ${kcp_init}; then
            echo "Failed to download kcptun.init file!"
            exit 1
        fi
    fi
    [ ! -x ${kcp_init} ] && chmod +x ${kcp_init}
    if [ "${OS}" == 'CentOS' ]; then
        chmod +x ${kcp_init}
        chkconfig --add ${program_name}
    else
        chmod +x ${kcp_init}
        update-rc.d -f ${program_name} defaults
    fi

    if [ "$set_iptables" == 'y' ]; then
        check_iptables
        # iptables config
        iptables -I INPUT -p udp --dport ${set_kcptun_port} -j ACCEPT
        iptables -I INPUT -p tcp --dport ${set_socks5_port} -j ACCEPT
        iptables -I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
        if [ "${OS}" == 'CentOS' ]; then
            service iptables save
        else
            echo '#!/bin/bash' > /etc/network/if-post-down.d/iptables
            echo 'iptables-save > /etc/iptables.rules' >> /etc/network/if-post-down.d/iptables
            echo 'exit 0;' >> /etc/network/if-post-down.d/iptables
            chmod +x /etc/network/if-post-down.d/iptables

            echo '#!/bin/bash' > /etc/network/if-pre-up.d/iptables
            echo 'iptables-restore < /etc/iptables.rules' >> /etc/network/if-pre-up.d/iptables
            echo 'exit 0;' >> /etc/network/if-pre-up.d/iptables
            chmod +x /etc/network/if-pre-up.d/iptables
        fi
    fi
    [ -s ${kcp_init} ] && ln -s ${kcp_init} /usr/bin/${program_name}
    ${kcp_init} start
    str_sndwnd=`sed -n '/sndwnd/p' ${str_program_dir}/server-kcptun.json | sed 's/[[:space:]]*//g;s/,//g' | cut -d: -f2`
    str_rcvwnd=`sed -n '/rcvwnd/p' ${str_program_dir}/server-kcptun.json | sed 's/[[:space:]]*//g;s/,//g' | cut -d: -f2`
    ${str_program_dir}/${program_name} --version
    fun_clang.cn
    #install successfully
    echo ""
    echo "Congratulations, kcp-server install completed!"
    echo "=============================================="
    echo -e "Your Server IP: ${COLOR_GREEN}${defIP}${COLOR_END}"
    echo -e "   Server Port: ${COLOR_GREEN}${set_kcptun_port}${COLOR_END}"
    echo -e "    Server Key: ${COLOR_GREEN}${set_kcptun_pwd}${COLOR_END}"
    echo -e "    crypt mode: ${COLOR_GREEN}${strcrypt}${COLOR_END}"
    echo -e "     fast mode: ${COLOR_GREEN}${strmode}${COLOR_END}"
    echo -e "   compression: ${COLOR_GREEN}${strcompression}${COLOR_END}"
    echo -e "           MTU: ${COLOR_GREEN}${strInputMTU}${COLOR_END}"
    echo -e "        sndwnd: ${COLOR_GREEN}${str_sndwnd}${COLOR_END}"
    echo -e "        rcvwnd: ${COLOR_GREEN}${str_rcvwnd}${COLOR_END}"
    echo "=============================================="
    echo ""
    echo -e "kcptun status manage: ${COLOR_PINKBACK_WHITEFONT}${kcp_init}${COLOR_END} {${COLOR_GREEN}start${COLOR_END}|${COLOR_PINK}stop${COLOR_END}|${COLOR_YELOW}restart${COLOR_END}}"
}
############################### install function ##################################
function pre_install_clang(){
    fun_clang.cn
    checkos
    check_centosversion
    check_os_bit
    disable_selinux
    clear
    fun_clang.cn
    check_net-tools
    if [ -s ${str_program_dir}/${program_name} ] && [ -s ${kcp_init} ]; then
        echo "kcptun is installed!"
    else
        install_program_server_clang
    fi
}
############################### configure function ##################################
function configure_program_server_clang(){
    if [ -s ${str_program_dir}/${program_config_file} ]; then
        vi ${str_program_dir}/${program_config_file}
    else
        echo "kcptun configuration file not found!"
    fi
}
############################### uninstall function ##################################
function uninstall_program_server_clang(){
    fun_clang.cn
    if [ -s ${kcp_init} ] || [ -s ${str_program_dir}/${program_name} ] ; then
        echo "============== Uninstall ${program_name} =============="
        save_config="n"
        echo  -e "${COLOR_YELOW}Do you want to keep the configuration file?${COLOR_END}"
        read -p "(if you want please input: y,Default [no]):" save_config

        case "${save_config}" in
        [yY]|[yY][eE][sS])
        echo ""
        echo "You will keep the configuration file!"
        save_config="y"
        ;;
        [nN]|[nN][oO])
        echo ""
        echo "You will NOT to keep the configuration file!"
        save_config="n"
        ;;
        *)
        echo ""
        echo "will NOT to keep the configuration file!"
        save_config="n"
        esac
        checkos
        ${kcp_init} stop
        if [ "${OS}" == 'CentOS' ]; then
            chkconfig --del ${program_name}
        else
            update-rc.d -f ${program_name} remove
        fi
        rm -f /usr/bin/${program_name} ${kcp_init} /var/run/${program_name}.pid /root/${program_name}-install.log /root/${program_name}-update.log
        if [ "${save_config}" == 'n' ]; then
            rm -fr ${str_program_dir}
        else
            rm -f ${str_program_dir}/${program_name} ${str_program_dir}/${program_name}.log
        fi
        echo "${program_name} uninstall success!"
    else
        echo "${program_name} Not install!"
    fi
    echo ""
}
############################### update function ##################################
function update_program_server_clang(){
    fun_clang.cn
    check_curl
    if [ -s ${kcp_init} ] || [ -s ${str_program_dir}/${program_name} ] ; then
        echo "============== Update ${program_name} =============="
        checkos
        check_centosversion
        check_os_bit
        remote_shell_version=`curl -s ${str_install_shell} | sed -n '/'^version'/p' | cut -d\" -f2`
        remote_init_version=`curl -s ${program_init_download_url} | sed -n '/'^version'/p' | cut -d\" -f2`
        local_init_version=`sed -n '/'^version'/p' ${kcp_init} | cut -d\" -f2`
        install_shell=${strPath}
        update_flag="false"
        if [ ! -z ${remote_shell_version} ] || [ ! -z ${remote_init_version} ];then
            if [[ "${local_init_version}" < "${remote_init_version}" ]];then
                echo "========== Update ${program_name} ${kcp_init} =========="
                if ! wget --no-check-certificate ${program_init_download_url} -O ${kcp_init}; then
                    echo "Failed to download ${program_name}.init file!"
                    exit 1
                else
                    echo -e "${COLOR_GREEN}${kcp_init} Update successfully !!!${COLOR_END}"
                    update_flag="true"
                fi
            fi
            if [[ "${version}" < "${remote_shell_version}" ]];then
                echo "========== Update ${program_name} install-${program_name}.sh =========="
                if ! wget --no-check-certificate ${str_install_shell} -O ${install_shell}/$0; then
                    echo "Failed to download install-${program_name}.sh file!"
                    exit 1
                else
                    echo -e "${COLOR_GREEN}install-${program_name}.sh Update successfully !!!${COLOR_END}"
                    update_flag="true"
                fi
            fi
            if [ "${update_flag}" == 'true' ]; then
                echo -e "${COLOR_GREEN}Update shell successfully !!!${COLOR_END}"
                echo ""
                echo -e "${COLOR_GREEN}Please Re-run${COLOR_END} ${COLOR_PINKBACK_WHITEFONT}$0 update${COLOR_END}"
                echo ""
                exit 1
            fi
        fi
        if [ "${update_flag}" == 'false' ]; then
            [ ! -d ${str_program_dir} ] && mkdir -p ${str_program_dir}
            fun_getVer
            ${kcp_init} stop
            sleep 1
            rm -f /usr/bin/${program_name} ${str_program_dir}/${program_name} ${str_program_dir}/${program_socks5_filename}
            fun_download_file
            if [ "${OS}" == 'CentOS' ]; then
                chmod +x ${kcp_init}
                chkconfig --add ${program_name}
            else
                chmod +x ${kcp_init}
                update-rc.d -f ${program_name} defaults
            fi
            [ -s ${kcp_init} ] && ln -s ${kcp_init} /usr/bin/${program_name}
            [ ! -x ${kcp_init} ] && chmod 755 ${kcp_init}
            ${kcp_init} start
            ${str_program_dir}/${program_name} -version
            echo "${program_name} update success!"
        fi
    else
        echo "${program_name} Not install!"
    fi
    echo ""
}
clear
strPath=`pwd`
rootness
fun_set_text_color
# Initialization
action=$1
[  -z $1 ]
case "$action" in
install)
    pre_install_clang 2>&1 | tee /root/${program_name}-install.log
    ;;
config)
    configure_program_server_clang
    ;;
uninstall)
    uninstall_program_server_clang 2>&1 | tee /root/${program_name}-uninstall.log
    ;;
update)
    update_program_server_clang 2>&1 | tee /root/${program_name}-update.log
    ;;
*)
    fun_clang.cn
    echo "Arguments error! [${action} ]"
    echo "Usage: `basename $0` {install|uninstall|update|config}"
    ;;
esac

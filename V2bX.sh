#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error: ${plain} You must run this script as root!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "alpine"; then
    release="alpine"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat|rocky|alma|oracle linux"; then
    release="centos"
elif cat /proc/version | grep -Eqi "arch"; then
    release="arch"
else
    echo -e "${red}System version not detected, please contact script author.${plain}\n" && exit 1
fi

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Please use CentOS 7 or newer!${plain}\n" && exit 1
    fi
    if [[ ${os_version} -eq 7 ]]; then
        echo -e "${red}Note: CentOS 7 cannot use hysteria1/2 protocols!${plain}\n"
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or newer!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use Debian 8 or newer!${plain}\n" && exit 1
    fi
fi

# Check the system YesNo have IPv6 address
check_ipv6_support() {
    if ip -6 addr | grep -q "inet6"; then
        echo "1"  # IPv6 supported
    else
        echo "0"  # No IPv6 supported
    fi
}

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -rp "$1 [default $2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -rp "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Do you want to restart V2bX?" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Press Enter to return to main menu: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/rahavard01/V2bX-script/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    if [[ $# == 0 ]]; then
        echo && echo -n -e "Enter specified version (default: latest): " && read version
    else
        version=$2
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/rahavard01/V2bX-script/master/install.sh) $version
    if [[ $? == 0 ]]; then
        echo -e "${green}Update complete. V2bX restarted. Use 'V2bX log' to check logs.${plain}"
        exit
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

config() {
    echo "V2bX will try to restart automatically after configuration changes"
    vi /etc/V2bX/config.json
    sleep 2
    restart
    check_status
    case $? in
        0)
            echo -e "V2bX status: ${green}Running${plain}"
            ;;
        1)
            echo -e "V2bX is not running or restart failed. View logs?[Y/n]" && echo
            read -e -rp "(default: y):" yn
            [[ -z ${yn} ]] && yn="y"
            if [[ ${yn} == [Yy] ]]; then
               show_log
            fi
            ;;
        2)
            echo -e "V2bX status: ${red}Not Installed${plain}"
    esac
}

uninstall() {
    confirm "Are you sure you want to uninstall V2bX?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    if [[ x"${release}" == x"alpine" ]]; then
        service V2bX stop
        rc-update del V2bX
        rm /etc/init.d/V2bX -f
    else
        systemctl stop V2bX
        systemctl disable V2bX
        rm /etc/systemd/system/V2bX.service -f
        systemctl daemon-reload
        systemctl reset-failed
    fi
    rm /etc/V2bX/ -rf
    rm /usr/local/V2bX/ -rf

    echo ""
    echo -e "Uninstall successful. If you want to delete this script, run after exiting: ${green}rm /usr/bin/V2bX -f${plain} "
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}V2bXRunning，No need to restart，If you need to restart, please select Restart ${plain}"
    else
        if [[ x"${release}" == x"alpine" ]]; then
            service V2bX start
        else
            systemctl start V2bX
        fi
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green}V2bX started successfully. Use 'V2bX log' to check logs.${plain}"
        else
            echo -e "${red}V2bX may have failed to start. Please check logs later using 'V2bX log'.${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    if [[ x"${release}" == x"alpine" ]]; then
        service V2bX stop
    else
        systemctl stop V2bX
    fi
    sleep 2
    check_status
    if [[ $? == 1 ]]; then
        echo -e "${green}V2bX stopped successfully.${plain}"
    else
        echo -e "${red}Failed to stop V2bX. May have timed out. Check logs later.${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    if [[ x"${release}" == x"alpine" ]]; then
        service V2bX restart
    else
        systemctl restart V2bX
    fi
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}V2bX restarted successfully. Use 'V2bX log' to check logs.${plain}"
    else
        echo -e "${red}V2bX may have failed to start. Please check logs later using 'V2bX log'.${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    if [[ x"${release}" == x"alpine" ]]; then
        service V2bX status
    else
        systemctl status V2bX --no-pager -l
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    if [[ x"${release}" == x"alpine" ]]; then
        rc-update add V2bX
    else
        systemctl enable V2bX
    fi
    if [[ $? == 0 ]]; then
        echo -e "${green}V2bX enabled to start on boot successfully.${plain}"
    else
        echo -e "${red}Failed to enable V2bX at boot.${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    if [[ x"${release}" == x"alpine" ]]; then
        rc-update del V2bX
    else
        systemctl disable V2bX
    fi
    if [[ $? == 0 ]]; then
        echo -e "${green}V2bX disabled from starting at boot successfully.${plain}"
    else
        echo -e "${red}Failed to disable V2bX at boot.${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    if [[ x"${release}" == x"alpine" ]]; then
        echo -e "${red}Log viewing is not supported on Alpine systems.${plain}\n" && exit 1
    else
        journalctl -u V2bX.service -e --no-pager -f
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

install_bbr() {
    bash <(curl -L -s https://github.com/ylx2016/Linux-NetSpeed/raw/master/tcpx.sh)
}

update_shell() {
    wget -O /usr/bin/V2bX -N --no-check-certificate https://raw.githubusercontent.com/rahavard01/V2bX-script/master/V2bX.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}Script download failed. Please check if this system can access Github.${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/V2bX
        echo -e "${green}Script upgraded successfully. Please re-run the script.${plain}" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /usr/local/V2bX/V2bX ]]; then
        return 2
    fi
    if [[ x"${release}" == x"alpine" ]]; then
        temp=$(service V2bX status | awk '{print $3}')
        if [[ x"${temp}" == x"started" ]]; then
            return 0
        else
            return 1
        fi
    else
        temp=$(systemctl status V2bX | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
        if [[ x"${temp}" == x"running" ]]; then
            return 0
        else
            return 1
        fi
    fi
}

check_enabled() {
    if [[ x"${release}" == x"alpine" ]]; then
        temp=$(rc-update show | grep V2bX)
        if [[ x"${temp}" == x"" ]]; then
            return 1
        else
            return 0
        fi
    else
        temp=$(systemctl is-enabled V2bX)
        if [[ x"${temp}" == x"enabled" ]]; then
            return 0
        else
            return 1;
        fi
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}V2bX is already installed. Please do not install again.${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}Please install V2bX first.${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
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
            echo -e "V2bX status: ${green}Running${plain}"
            show_enable_status
            ;;
        1)
            echo -e "V2bX status: ${yellow}Not Running${plain}"
            show_enable_status
            ;;
        2)
            echo -e "V2bX status: ${red}Not Installed${plain}"
    esac
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Auto-start on boot: ${green}Yes${plain}"
    else
        echo -e "Auto-start on boot: ${red}No${plain}"
    fi
}

generate_x25519_key() {
    echo -n "Generating x25519 key:"
    /usr/local/V2bX/V2bX x25519
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

# اضافه شد 
append_config_file() {
    echo -e "\033[0;33mAppending new node(s) to existing configuration...\033[0m"

    config_path="/etc/V2bX/config.json"
    if [[ ! -f "$config_path" ]]; then
        echo -e "\033[0;31mConfig file not found. Please generate by using Option 15.\033[0m"
        return
    fi

    current_config=$(cat "$config_path")
    current_cores=$(echo "$current_config" | jq '.Cores')
    current_nodes=$(echo "$current_config" | jq '.Nodes')

    # Get ApiHost and ApiKey from existing config
    ApiHost=$(echo "$current_nodes" | jq -r '.[0].ApiHost')
    ApiKey=$(echo "$current_nodes" | jq -r '.[0].ApiKey')

    echo -e "\033[0;32mApiHost: $ApiHost\033[0m"
    echo -e "\033[0;32mApiKey : $ApiKey\033[0m"

    # Prepare to collect nodes
    nodes_config=()
    core_xray=false
    core_sing=false
    core_hysteria2=false

    while true; do
        read -rp "Add a new node? (Press Enter to continue, 'n' or 'no' to finish): " continue_add
        if [[ "$continue_add" =~ ^[Nn][Oo]?$ ]]; then
            if [ "${#nodes_config[@]}" -eq 0 ]; then
                echo -e "\033[0;33mNo nodes entered. Exiting without changes.\033[0m"
                return
            else
                break  # Done adding nodes, continue to merge and save
            fi
        fi
        add_node_config_append  # This function must define node and append to nodes_config
    done

    # Merge new nodes
    new_nodes_json=$(printf "%s\n" "${nodes_config[@]}" | jq -s '.')
    updated_nodes=$(echo "$current_nodes" "$new_nodes_json" | jq -s '.[0] + .[1]')

    # Merge cores
    updated_cores=$(echo "$current_cores" | jq '.')

    if [ "$core_xray" = true ] && ! echo "$current_cores" | grep -q '"Type": "xray"'; then
        xray_core='{"Type":"xray","Log":{"Level":"error","ErrorPath":"/etc/V2bX/error.log"},"OutboundConfigPath":"/etc/V2bX/custom_outbound.json","RouteConfigPath":"/etc/V2bX/route.json"}'
        updated_cores=$(echo "$updated_cores" | jq ". + [\$core]" --argjson core "$xray_core")
    fi

    if [ "$core_sing" = true ] && ! echo "$current_cores" | grep -q '"Type": "sing"'; then
        sing_core='{"Type":"sing","Log":{"Level":"error","Timestamp":true},"NTP":{"Enable":false,"Server":"time.apple.com","ServerPort":0},"OriginalPath":"/etc/V2bX/sing_origin.json"}'
        updated_cores=$(echo "$updated_cores" | jq ". + [\$core]" --argjson core "$sing_core")
    fi

    if [ "$core_hysteria2" = true ] && ! echo "$current_cores" | grep -q '"Type": "hysteria2"'; then
        hysteria2_core='{"Type":"hysteria2","Log":{"Level":"error"}}'
        updated_cores=$(echo "$updated_cores" | jq ". + [\$core]" --argjson core "$hysteria2_core")
    fi

    # Backup current config
    mv "$config_path" "$config_path.bak"

    # Write final config
    jq -n \
        --argjson cores "$updated_cores" \
        --argjson nodes "$updated_nodes" \
        '{
            "Log": {
                "Level": "error",
                "Output": ""
            },
            "Cores": $cores,
            "Nodes": $nodes
        }' > "$config_path"

    echo -e "\033[0;32m✔ Node(s) successfully added and config.json updated.\033[0m"
    echo -e "\033[0;32mv2bx restart ...\033[0m"

    # ری‌استارت سرویس
    v2bx restart 

    # برگشت به منو
    sleep 1
    before_show_menu
}


show_V2bX_version() {
    echo -n "V2bX version:"
    /usr/local/V2bX/V2bX version
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}
# اضافه شد

add_node_config_append() {
    echo -e "${green}Please select node core type:${plain}"
    echo -e "${green}1. xray${plain}"
    echo -e "${green}2. singbox${plain}"
    echo -e "${green}3. hysteria2${plain}"
    read -rp "Enter:" core_type

    if [ "$core_type" == "1" ]; then
        core="xray"; core_xray=true
    elif [ "$core_type" == "2" ]; then
        core="sing"; core_sing=true
    elif [ "$core_type" == "3" ]; then
        core="hysteria2"; core_hysteria2=true
    else
        echo "Invalid choice. Please select 1 2 3."
        return
    fi

    while true; do
        read -rp "Enter Node ID: " NodeID
        [[ "$NodeID" =~ ^[0-9]+$ ]] && break || echo "Error: Please enter a valid number as Node ID."
    done

    if [ "$core_hysteria2" = true ] && [ "$core_xray" = false ] && [ "$core_sing" = false ]; then
        NodeType="hysteria2"
    else
        echo -e "${yellow}Select node transport protocol:${plain}"
        echo -e "${green}1. Shadowsocks${plain}"
        echo -e "${green}2. Vless${plain}"
        echo -e "${green}3. Vmess${plain}"
        [ "$core_sing" == true ] && echo -e "${green}4. Hysteria\n5. Hysteria2\n7. Tuic\n8. AnyTLS${plain}"
        [ "$core_hysteria2" == true ] && [ "$core_sing" = false ] && echo -e "${green}5. Hysteria2${plain}"
        echo -e "${green}6. Trojan${plain}"

        read -rp "Enter:" NodeType
        case "$NodeType" in
            1 ) NodeType="shadowsocks" ;;
            2 ) NodeType="vless" ;;
            3 ) NodeType="vmess" ;;
            4 ) NodeType="hysteria" ;;
            5 ) NodeType="hysteria2" ;;
            6 ) NodeType="trojan" ;;
            7 ) NodeType="tuic" ;;
            8 ) NodeType="anytls" ;;
            * ) NodeType="shadowsocks" ;;
        esac
    fi

    fastopen=true
    [[ "$NodeType" == "vless" ]] && read -rp "Is this a reality node? (y/n): " isreality
    [[ "$NodeType" =~ hysteria|hysteria2|tuic|anytls ]] && fastopen=false && istls="y"
    [[ "$isreality" != "y" && "$istls" != "y" ]] && read -rp "Enable TLS configuration? (y/n): " istls

    certmode="none"; certdomain="example.com"
    if [[ "$isreality" != "y" && "$istls" == "y" ]]; then
        echo -e "${yellow}Select certificate request mode:${plain}"
        echo -e "${green}1. HTTP mode - auto (domain resolved)${plain}"
        echo -e "${green}2. DNS mode - auto (requires DNS provider API)${plain}"
        echo -e "${green}3. Self mode - self-signed or custom certificate${plain}"
        read -rp "Enter:" certmode
        case "$certmode" in
            1 ) certmode="http" ;;
            2 ) certmode="dns" ;;
            3 ) certmode="self" ;;
        esac
        read -rp "Enter cert domain (e.g. example.com): " certdomain
        [ "$certmode" != "http" ] && echo -e "${red}Please manually edit config file and restart!${plain}"
    fi

    ipv6_support=$(check_ipv6_support)
    listen_ip="0.0.0.0"
    [ "$ipv6_support" -eq 1 ] && listen_ip="::"

    if [ "$core_type" == "1" ]; then
        node_config=$(cat <<EOF
{
    "Core": "$core",
    "ApiHost": "$ApiHost",
    "ApiKey": "$ApiKey",
    "NodeID": $NodeID,
    "NodeType": "$NodeType",
    "Timeout": 30,
    "ListenIP": "0.0.0.0",
    "SendIP": "0.0.0.0",
    "DeviceOnlineMinTraffic": 200,
    "EnableProxyProtocol": false,
    "EnableUot": true,
    "EnableTFO": true,
    "DNSType": "UseIPv4",
    "CertConfig": {
        "CertMode": "$certmode",
        "RejectUnknownSni": false,
        "CertDomain": "$certdomain",
        "CertFile": "/etc/V2bX/fullchain.cer",
        "KeyFile": "/etc/V2bX/cert.key",
        "Email": "v2bx@github.com",
        "Provider": "cloudflare",
        "DNSEnv": {
            "EnvName": "env1"
        }
    }
}
EOF
)
    elif [ "$core_type" == "2" ]; then
        node_config=$(cat <<EOF
{
    "Core": "$core",
    "ApiHost": "$ApiHost",
    "ApiKey": "$ApiKey",
    "NodeID": $NodeID,
    "NodeType": "$NodeType",
    "Timeout": 30,
    "ListenIP": "$listen_ip",
    "SendIP": "0.0.0.0",
    "DeviceOnlineMinTraffic": 200,
    "TCPFastOpen": $fastopen,
    "SniffEnabled": true,
    "CertConfig": {
        "CertMode": "$certmode",
        "RejectUnknownSni": false,
        "CertDomain": "$certdomain",
        "CertFile": "/etc/V2bX/fullchain.cer",
        "KeyFile": "/etc/V2bX/cert.key",
        "Email": "v2bx@github.com",
        "Provider": "cloudflare",
        "DNSEnv": {
            "EnvName": "env1"
        }
    }
}
EOF
)
    elif [ "$core_type" == "3" ]; then
        node_config=$(cat <<EOF
{
    "Core": "$core",
    "ApiHost": "$ApiHost",
    "ApiKey": "$ApiKey",
    "NodeID": $NodeID,
    "NodeType": "$NodeType",
    "Hysteria2ConfigPath": "/etc/V2bX/hy2config.yaml",
    "Timeout": 30,
    "ListenIP": "",
    "SendIP": "0.0.0.0",
    "DeviceOnlineMinTraffic": 200,
    "CertConfig": {
        "CertMode": "$certmode",
        "RejectUnknownSni": false,
        "CertDomain": "$certdomain",
        "CertFile": "/etc/V2bX/fullchain.cer",
        "KeyFile": "/etc/V2bX/cert.key",
        "Email": "v2bx@github.com",
        "Provider": "cloudflare",
        "DNSEnv": {
            "EnvName": "env1"
        }
    }
}
EOF
)
    fi

    nodes_config+=("$node_config")
}
# تا اینجا

add_node_config() {
    echo -e "${green}Please select node core type:${plain}"
    echo -e "${green}1. xray${plain}"
    echo -e "${green}2. singbox${plain}"
    echo -e "${green}3. hysteria2${plain}"
    read -rp "Enter:" core_type
    if [ "$core_type" == "1" ]; then
        core="xray"
        core_xray=true
    elif [ "$core_type" == "2" ]; then
        core="sing"
        core_sing=true
    elif [ "$core_type" == "3" ]; then
        core="hysteria2"
        core_hysteria2=true
    else
        echo "Invalid choice. Please select 1 2 3."
        continue
    fi
    while true; do
        read -rp "Enter Node ID:" NodeID
        # judgment NodeIDYesNo For positive integers
        if [[ "$NodeID" =~ ^[0-9]+$ ]]; then
            break  # Enter correctly, exit loop
        else
            echo "Error: Please enter a valid number as Node ID."
        fi
    done

    if [ "$core_hysteria2" = true ] && [ "$core_xray" = false ] && [ "$core_sing" = false ]; then
        NodeType="hysteria2"
    else
        echo -e "${yellow}Select node transport protocol:${plain}"
        echo -e "${green}1. Shadowsocks${plain}"
        echo -e "${green}2. Vless${plain}"
        echo -e "${green}3. Vmess${plain}"
        if [ "$core_sing" == true ]; then
            echo -e "${green}4. Hysteria${plain}"
            echo -e "${green}5. Hysteria2${plain}"
        fi
        if [ "$core_hysteria2" == true ] && [ "$core_sing" = false ]; then
            echo -e "${green}5. Hysteria2${plain}"
        fi
        echo -e "${green}6. Trojan${plain}"  
        if [ "$core_sing" == true ]; then
            echo -e "${green}7. Tuic${plain}"
            echo -e "${green}8. AnyTLS${plain}"
        fi
        read -rp "Enter:" NodeType
        case "$NodeType" in
            1 ) NodeType="shadowsocks" ;;
            2 ) NodeType="vless" ;;
            3 ) NodeType="vmess" ;;
            4 ) NodeType="hysteria" ;;
            5 ) NodeType="hysteria2" ;;
            6 ) NodeType="trojan" ;;
            7 ) NodeType="tuic" ;;
            8 ) NodeType="anytls" ;;
            * ) NodeType="shadowsocks" ;;
        esac
    fi
    fastopen=true
    if [ "$NodeType" == "vless" ]; then
        read -rp "Is this a reality node? (y/n)" isreality
    elif [ "$NodeType" == "hysteria" ] || [ "$NodeType" == "hysteria2" ] || [ "$NodeType" == "tuic" ] || [ "$NodeType" == "anytls" ]; then
        fastopen=false
        istls="y"
    fi

    if [[ "$isreality" != "y" && "$isreality" != "Y" &&  "$istls" != "y" ]]; then
        read -rp "Enable TLS configuration? (y/n)" istls
    fi

    certmode="none"
    certdomain="example.com"
    if [[ "$isreality" != "y" && "$isreality" != "Y" && ( "$istls" == "y" || "$istls" == "Y" ) ]]; then
        echo -e "${yellow}Select certificate request mode:${plain}"
        echo -e "${green}1. HTTP mode - auto (domain resolved)${plain}"
        echo -e "${green}2. DNS mode - auto (requires DNS provider API)${plain}"
        echo -e "${green}3. Self mode - self-signed or custom certificate${plain}"
        read -rp "Enter:" certmode
        case "$certmode" in
            1 ) certmode="http" ;;
            2 ) certmode="dns" ;;
            3 ) certmode="self" ;;
        esac
        read -rp "Enter node certificate domain (example.com):" certdomain
        if [ "$certmode" != "http" ]; then
            echo -e "${red}Please manually edit config file and restart V2bX!${plain}"
        fi
    fi
    ipv6_support=$(check_ipv6_support)
    listen_ip="0.0.0.0"
    if [ "$ipv6_support" -eq 1 ]; then
        listen_ip="::"
    fi
    node_config=""
    if [ "$core_type" == "1" ]; then 
    node_config=$(cat <<EOF
{
            "Core": "$core",
            "ApiHost": "$ApiHost",
            "ApiKey": "$ApiKey",
            "NodeID": $NodeID,
            "NodeType": "$NodeType",
            "Timeout": 30,
            "ListenIP": "0.0.0.0",
            "SendIP": "0.0.0.0",
            "DeviceOnlineMinTraffic": 200,
            "EnableProxyProtocol": false,
            "EnableUot": true,
            "EnableTFO": true,
            "DNSType": "UseIPv4",
            "CertConfig": {
                "CertMode": "$certmode",
                "RejectUnknownSni": false,
                "CertDomain": "$certdomain",
                "CertFile": "/etc/V2bX/fullchain.cer",
                "KeyFile": "/etc/V2bX/cert.key",
                "Email": "v2bx@github.com",
                "Provider": "cloudflare",
                "DNSEnv": {
                    "EnvName": "env1"
                }
            }
        },
EOF
)
    elif [ "$core_type" == "2" ]; then
    node_config=$(cat <<EOF
{
            "Core": "$core",
            "ApiHost": "$ApiHost",
            "ApiKey": "$ApiKey",
            "NodeID": $NodeID,
            "NodeType": "$NodeType",
            "Timeout": 30,
            "ListenIP": "$listen_ip",
            "SendIP": "0.0.0.0",
            "DeviceOnlineMinTraffic": 200,
            "TCPFastOpen": $fastopen,
            "SniffEnabled": true,
            "CertConfig": {
                "CertMode": "$certmode",
                "RejectUnknownSni": false,
                "CertDomain": "$certdomain",
                "CertFile": "/etc/V2bX/fullchain.cer",
                "KeyFile": "/etc/V2bX/cert.key",
                "Email": "v2bx@github.com",
                "Provider": "cloudflare",
                "DNSEnv": {
                    "EnvName": "env1"
                }
            }
        },
EOF
)
    elif [ "$core_type" == "3" ]; then
    node_config=$(cat <<EOF
{
            "Core": "$core",
            "ApiHost": "$ApiHost",
            "ApiKey": "$ApiKey",
            "NodeID": $NodeID,
            "NodeType": "$NodeType",
            "Hysteria2ConfigPath": "/etc/V2bX/hy2config.yaml",
            "Timeout": 30,
            "ListenIP": "",
            "SendIP": "0.0.0.0",
            "DeviceOnlineMinTraffic": 200,
            "CertConfig": {
                "CertMode": "$certmode",
                "RejectUnknownSni": false,
                "CertDomain": "$certdomain",
                "CertFile": "/etc/V2bX/fullchain.cer",
                "KeyFile": "/etc/V2bX/cert.key",
                "Email": "v2bx@github.com",
                "Provider": "cloudflare",
                "DNSEnv": {
                    "EnvName": "env1"
                }
            }
        },
EOF
)
    fi
    nodes_config+=("$node_config")
}

generate_config_file() {
    echo -e "${yellow}V2bX Configuration Wizard${plain}"
    echo -e "${red}Please read the following notes:${plain}"
    echo -e "${red}1. This feature is in testing stage.${plain}"
    echo -e "${red}2. Config file will be saved to /etc/V2bX/config.json${plain}"
    echo -e "${red}3. Old config will be backed up to /etc/V2bX/config.json.bak${plain}"
    echo -e "${red}4. Only partial TLS support available.${plain}"
    echo -e "${red}5. Generated config includes audit. Continue?(y/n)${plain}"
    read -rp "Enter:" continue_prompt
    if [[ "$continue_prompt" =~ ^[Nn][Oo]? ]]; then
        exit 0
    fi
    
    nodes_config=()
    first_node=true
    core_xray=false
    core_sing=false
    fixed_api_info=false
    check_api=false
    
    while true; do
        if [ "$first_node" = true ]; then
            read -rp "Enter panel URL (e.g., https://example.com):" ApiHost
            read -rp "Enter panel API Key:" ApiKey
            read -rp "Set fixed API URL and API Key? (y/n)" fixed_api
            if [ "$fixed_api" = "y" ] || [ "$fixed_api" = "Y" ]; then
                fixed_api_info=true
                echo -e "${red}Fixed address successfully.${plain}"
            fi
            first_node=false
            add_node_config
        else
            read -rp "Continue adding node configuration? (Enter to continue, n or no to quit)" continue_adding_node
            if [[ "$continue_adding_node" =~ ^[Nn][Oo]? ]]; then
                break
            elif [ "$fixed_api_info" = false ]; then
                read -rp "Please enter Airport website：" ApiHost
                read -rp "Enter panel API Key:" ApiKey
            fi
            add_node_config
        fi
    done

    # Initialize the array configuration core
    cores_config="["

    # Check and add xray configuration core
    if [ "$core_xray" = true ]; then
        cores_config+="
    {
        \"Type\": \"xray\",
        \"Log\": {
            \"Level\": \"error\",
            \"ErrorPath\": \"/etc/V2bX/error.log\"
        },
        \"OutboundConfigPath\": \"/etc/V2bX/custom_outbound.json\",
        \"RouteConfigPath\": \"/etc/V2bX/route.json\"
    },"
    fi

    # Check and add sing configuration core
    if [ "$core_sing" = true ]; then
        cores_config+="
    {
        \"Type\": \"sing\",
        \"Log\": {
            \"Level\": \"error\",
            \"Timestamp\": true
        },
        \"NTP\": {
            \"Enable\": false,
            \"Server\": \"time.apple.com\",
            \"ServerPort\": 0
        },
        \"OriginalPath\": \"/etc/V2bX/sing_origin.json\"
    },"
    fi

    # Check and add hysteria2 configuration core
    if [ "$core_hysteria2" = true ]; then
        cores_config+="
    {
        \"Type\": \"hysteria2\",
        \"Log\": {
            \"Level\": \"error\"
        }
    },"
    fi

    # Remove the last one and close the array
    cores_config+="]"
    cores_config=$(echo "$cores_config" | sed 's/},]$/}]/')

    # Switch to configuration file directory
    cd /etc/V2bX
    
    # Backup old configuration file
    mv config.json config.json.bak
    nodes_config_str="${nodes_config[*]}"
    formatted_nodes_config="${nodes_config_str%,}"

    # creation config.json document
    cat <<EOF > /etc/V2bX/config.json
{
    "Log": {
        "Level": "error",
        "Output": ""
    },
    "Cores": $cores_config,
    "Nodes": [$formatted_nodes_config]
}
EOF
    
    # creation custom_outbound.json document
    cat <<EOF > /etc/V2bX/custom_outbound.json
    [
        {
            "tag": "IPv4_out",
            "protocol": "freedom",
            "settings": {
                "domainStrategy": "UseIPv4v6"
            }
        },
        {
            "tag": "IPv6_out",
            "protocol": "freedom",
            "settings": {
                "domainStrategy": "UseIPv6"
            }
        },
        {
            "protocol": "blackhole",
            "tag": "block"
        }
    ]
EOF
    
    # creation route.json document
    cat <<EOF > /etc/V2bX/route.json
    {
        "domainStrategy": "AsIs",
        "rules": [
            {
                "type": "field",
                "outboundTag": "block",
                "ip": [
                    "geoip:private"
                ]
            },
            {
                "type": "field",
                "outboundTag": "block",
                "domain": [
                    "regexp:(api|ps|sv|offnavi|newvector|ulog.imap|newloc)(.map|).(baidu|n.shifen).com",
                    "regexp:(.+.|^)(360|so).(cn|com)",
                    "regexp:(Subject|HELO|SMTP)",
                    "regexp:(torrent|.torrent|peer_id=|info_hash|get_peers|find_node|BitTorrent|announce_peer|announce.php?passkey=)",
                    "regexp:(^.@)(guerrillamail|guerrillamailblock|sharklasers|grr|pokemail|spam4|bccto|chacuo|027168).(info|biz|com|de|net|org|me|la)",
                    "regexp:(.?)(xunlei|sandai|Thunder|XLLiveUD)(.)",
                    "regexp:(..||)(dafahao|mingjinglive|botanwang|minghui|dongtaiwang|falunaz|epochtimes|ntdtv|falundafa|falungong|wujieliulan|zhengjian).(org|com|net)",
                    "regexp:(ed2k|.torrent|peer_id=|announce|info_hash|get_peers|find_node|BitTorrent|announce_peer|announce.php?passkey=|magnet:|xunlei|sandai|Thunder|XLLiveUD|bt_key)",
                    "regexp:(.+.|^)(360).(cn|com|net)",
                    "regexp:(.*.||)(guanjia.qq.com|qqpcmgr|QQPCMGR)",
                    "regexp:(.*.||)(rising|kingsoft|duba|xindubawukong|jinshanduba).(com|net|org)",
                    "regexp:(.*.||)(netvigator|torproject).(com|cn|net|org)",
                    "regexp:(..||)(visa|mycard|gash|beanfun|bank).",
                    "regexp:(.*.||)(gov|12377|12315|talk.news.pts.org|creaders|zhuichaguoji|efcc.org|cyberpolice|aboluowang|tuidang|epochtimes|zhengjian|110.qq|mingjingnews|inmediahk|xinsheng|breakgfw|chengmingmag|jinpianwang|qi-gong|mhradio|edoors|renminbao|soundofhope|xizang-zhiye|bannedbook|ntdtv|12321|secretchina|dajiyuan|boxun|chinadigitaltimes|dwnews|huaglad|oneplusnews|epochweekly|cn.rfi).(cn|com|org|net|club|net|fr|tw|hk|eu|info|me)",
                    "regexp:(.*.||)(miaozhen|cnzz|talkingdata|umeng).(cn|com)",
                    "regexp:(.*.||)(mycard).(com|tw)",
                    "regexp:(.*.||)(gash).(com|tw)",
                    "regexp:(.bank.)",
                    "regexp:(.*.||)(pincong).(rocks)",
                    "regexp:(.*.||)(taobao).(com)",
                    "regexp:(.*.||)(laomoe|jiyou|ssss|lolicp|vv1234|0z|4321q|868123|ksweb|mm126).(com|cloud|fun|cn|gs|xyz|cc)",
                    "regexp:(flows|miaoko).(pages).(dev)"
                ]
            },
            {
                "type": "field",
                "outboundTag": "block",
                "ip": [
                    "127.0.0.1/32",
                    "10.0.0.0/8",
                    "fc00::/7",
                    "fe80::/10",
                    "172.16.0.0/12"
                ]
            },
            {
                "type": "field",
                "outboundTag": "block",
                "protocol": [
                    "bittorrent"
                ]
            }
        ]
    }
EOF

    ipv6_support=$(check_ipv6_support)
    dnsstrategy="ipv4_only"
    if [ "$ipv6_support" -eq 1 ]; then
        dnsstrategy="prefer_ipv4"
    fi
    # creation sing_origin.json document
    cat <<EOF > /etc/V2bX/sing_origin.json
{
  "dns": {
    "servers": [
      {
        "tag": "cf",
        "address": "1.1.1.1"
      }
    ],
    "strategy": "$dnsstrategy"
  },
  "outbounds": [
    {
      "tag": "direct",
      "type": "direct",
      "domain_resolver": {
        "server": "cf",
        "strategy": "$dnsstrategy"
      }
    },
    {
      "type": "block",
      "tag": "block"
    }
  ],
  "route": {
    "rules": [
      {
        "ip_is_private": true,
        "outbound": "block"
      },
      {
        "domain_regex": [
            "(api|ps|sv|offnavi|newvector|ulog.imap|newloc)(.map|).(baidu|n.shifen).com",
            "(.+.|^)(360|so).(cn|com)",
            "(Subject|HELO|SMTP)",
            "(torrent|.torrent|peer_id=|info_hash|get_peers|find_node|BitTorrent|announce_peer|announce.php?passkey=)",
            "(^.@)(guerrillamail|guerrillamailblock|sharklasers|grr|pokemail|spam4|bccto|chacuo|027168).(info|biz|com|de|net|org|me|la)",
            "(.?)(xunlei|sandai|Thunder|XLLiveUD)(.)",
            "(..||)(dafahao|mingjinglive|botanwang|minghui|dongtaiwang|falunaz|epochtimes|ntdtv|falundafa|falungong|wujieliulan|zhengjian).(org|com|net)",
            "(ed2k|.torrent|peer_id=|announce|info_hash|get_peers|find_node|BitTorrent|announce_peer|announce.php?passkey=|magnet:|xunlei|sandai|Thunder|XLLiveUD|bt_key)",
            "(.+.|^)(360).(cn|com|net)",
            "(.*.||)(guanjia.qq.com|qqpcmgr|QQPCMGR)",
            "(.*.||)(rising|kingsoft|duba|xindubawukong|jinshanduba).(com|net|org)",
            "(.*.||)(netvigator|torproject).(com|cn|net|org)",
            "(..||)(visa|mycard|gash|beanfun|bank).",
            "(.*.||)(gov|12377|12315|talk.news.pts.org|creaders|zhuichaguoji|efcc.org|cyberpolice|aboluowang|tuidang|epochtimes|zhengjian|110.qq|mingjingnews|inmediahk|xinsheng|breakgfw|chengmingmag|jinpianwang|qi-gong|mhradio|edoors|renminbao|soundofhope|xizang-zhiye|bannedbook|ntdtv|12321|secretchina|dajiyuan|boxun|chinadigitaltimes|dwnews|huaglad|oneplusnews|epochweekly|cn.rfi).(cn|com|org|net|club|net|fr|tw|hk|eu|info|me)",
            "(.*.||)(miaozhen|cnzz|talkingdata|umeng).(cn|com)",
            "(.*.||)(mycard).(com|tw)",
            "(.*.||)(gash).(com|tw)",
            "(.bank.)",
            "(.*.||)(pincong).(rocks)",
            "(.*.||)(taobao).(com)",
            "(.*.||)(laomoe|jiyou|ssss|lolicp|vv1234|0z|4321q|868123|ksweb|mm126).(com|cloud|fun|cn|gs|xyz|cc)",
            "(flows|miaoko).(pages).(dev)"
        ],
        "outbound": "block"
      },
      {
        "outbound": "direct",
        "network": [
          "udp","tcp"
        ]
      }
    ]
  },
  "experimental": {
    "cache_file": {
      "enabled": true
    }
  }
}
EOF

    # creation hy2config.yaml document           
    cat <<EOF > /etc/V2bX/hy2config.yaml
quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520
  maxIdleTimeout: 30s
  maxIncomingStreams: 1024
  disablePathMTUDiscovery: false
ignoreClientBandwidth: false
disableUDP: false
udpIdleTimeout: 60s
resolver:
  type: system
acl:
  inline:
    - direct(geosite:google)
    - reject(geosite:cn)
    - reject(geoip:cn)
masquerade:
  type: 404
EOF
    echo -e "${green}V2bX configuration file generation complete, restarting V2bX service${plain}"
    restart 0
    before_show_menu
}

# Open the port firewall
open_ports() {
    systemctl stop firewalld.service 2>/dev/null
    systemctl disable firewalld.service 2>/dev/null
    setenforce 0 2>/dev/null
    ufw disable 2>/dev/null
    iptables -P INPUT ACCEPT 2>/dev/null
    iptables -P FORWARD ACCEPT 2>/dev/null
    iptables -P OUTPUT ACCEPT 2>/dev/null
    iptables -t nat -F 2>/dev/null
    iptables -t mangle -F 2>/dev/null
    iptables -F 2>/dev/null
    iptables -X 2>/dev/null
    netfilter-persistent save 2>/dev/null
    echo -e "${green}Firewall ports opened successfully!${plain}"
}

show_usage() {
    echo "V2bX Script Usage: "
    echo "------------------------------------------"
    echo "V2bX              - Show management menu (more features)"
    echo "V2bX start        - Start V2bX"
    echo "V2bX stop         - Stop V2bX"
    echo "V2bX restart      - Restart V2bX"
    echo "V2bX status       - View V2bX status"
    echo "V2bX enable       - Enable V2bX on boot"
    echo "V2bX disable      - Disable V2bX on boot"
    echo "V2bX log          - View V2bX logs"
    echo "V2bX x25519       - Generate x25519 key"
    echo "V2bX generate     - Generate V2bX config file"
    echo "V2bX update       - Update V2bX"
    echo "V2bX update x.x.x - Install specific V2bX version"
    echo "V2bX install      - Install V2bX"
    echo "V2bX uninstall    - Uninstall V2bX"
    echo "V2bX version      - View V2bX version"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}V2bX backend management script,${plain}${red}not for Docker use${plain}
--- https://github.com/wyx2685/V2bX ---
  ${green}0.${plain} Modify configuration
————————————————
  ${green}1.${plain} Install V2bX
  ${green}2.${plain} Update V2bX
  ${green}3.${plain} Uninstall V2bX
————————————————
  ${green}4.${plain} Start V2bX
  ${green}5.${plain} Stop V2bX
  ${green}6.${plain} Restart V2bX
  ${green}7.${plain} View V2bX status
  ${green}8.${plain} View V2bX logs
————————————————
  ${green}9.${plain} Enable V2bX on boot
  ${green}10.${plain} Disable V2bX on boot
————————————————
  ${green}11.${plain} One-click install BBR (latest kernel)
  ${green}12.${plain} View V2bX version
  ${green}13.${plain} Generate X25519 Key
  ${green}14.${plain} Update V2bX maintenance script
  ${green}15.${plain} Generate V2bX config file
  ${green}16.${plain} Add new node
  ${green}17.${plain} Open all VPS firewall ports
  ${green}18.${plain} Exit script
 "
 #The next update can be added to the upper part of the string
    show_status
    echo && read -rp "Enter your choice [0-18]: " num

    case "${num}" in
        0) config ;;
        1) check_uninstall && install ;;
        2) check_install && update ;;
        3) check_install && uninstall ;;
        4) check_install && start ;;
        5) check_install && stop ;;
        6) check_install && restart ;;
        7) check_install && status ;;
        8) check_install && show_log ;;
        9) check_install && enable ;;
        10) check_install && disable ;;
        11) install_bbr ;;
        12) check_install && show_V2bX_version ;;
        13) check_install && generate_x25519_key ;;
        14) update_shell ;;
        15) generate_config_file ;;
        16) check_install && append_config_file ;;
        17) open_ports ;;
        18) exit ;;
        *) echo -e "${red}Please enter a valid number [0-16]${plain}" ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0 ;;
        "stop") check_install 0 && stop 0 ;;
        "restart") check_install 0 && restart 0 ;;
        "status") check_install 0 && status 0 ;;
        "enable") check_install 0 && enable 0 ;;
        "disable") check_install 0 && disable 0 ;;
        "log") check_install 0 && show_log 0 ;;
        "update") check_install 0 && update 0 $2 ;;
        "config") config $* ;;
        "generate") generate_config_file ;;
        "install") check_uninstall 0 && install 0 ;;
        "uninstall") check_install 0 && uninstall 0 ;;
        "x25519") check_install 0 && generate_x25519_key 0 ;;
        "version") check_install 0 && show_V2bX_version 0 ;;
        "update_shell") update_shell ;;
        *) show_usage
    esac
else
    show_menu
fi

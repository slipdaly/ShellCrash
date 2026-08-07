#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_FW_FILTER_LOADED" ] && return
__IS_MODULE_FW_FILTER_LOADED=1
load_lang fw_filter

# 流量过滤
set_fw_filter() {
    while true; do
        [ -z "$common_ports" ] && common_ports=ON
        [ -z "$quic_rj" ] && quic_rj=OFF
        [ -z "$cn_ip_route" ] && cn_ip_route=OFF
        touch "$CRASHDIR"/configs/mac "$CRASHDIR"/configs/ip_filter
        [ -z "$(cat "$CRASHDIR"/configs/mac "$CRASHDIR"/configs/ip_filter 2>/dev/null)" ] && mac_filter_info=OFF || mac_filter_info=ON
        comp_box "${FWF_ITEM_1_PREFIX}\033[36m$common_ports\033[0m\t${FWF_ITEM_1_SUFFIX}" \
            "${FWF_ITEM_2_PREFIX}\033[36m$mac_filter_info\033[0m\t${FWF_ITEM_2_SUFFIX}" \
            "${FWF_ITEM_3_PREFIX}\033[36m$quic_rj\033[0m\t${FWF_ITEM_3_SUFFIX}" \
            "${FWF_ITEM_4_PREFIX}\033[36m$cn_ip_route\033[0m\t${FWF_ITEM_4_SUFFIX}" \
            "$FWF_ITEM_5" \
            "$FWF_ITEM_6" \
            "" \
            "$FWF_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            if [ -n "$(pidof CrashCore)" ] && [ "$firewall_mod" = 'iptables' ]; then
                comp_box "$FWF_SWITCH_STOP"
                btm_box "$FWF_YES" \
                    "$FWF_NO_BACK"
                read -r -p "$COMMON_INPUT> " res
                [ "$res" = 1 ] && "$CRASHDIR"/start.sh stop && set_common_ports
            else
                set_common_ports
            fi
            ;;
        2)
            checkcfg_mac=$(cat "$CRASHDIR"/configs/mac)
            fw_filter_lan
            if [ -n "$PID" ]; then
                checkcfg_mac_new=$(cat "$CRASHDIR"/configs/mac)
                [ "$checkcfg_mac" != "$checkcfg_mac_new" ] && checkrestart
            fi
            ;;
        3)
            if [ "$quic_rj" = "OFF" ]; then
                quic_rj=ON
                msg_alert "\033[33m$FWF_QUIC_OFF\033[0m"
            else
                quic_rj=OFF
                msg_alert "\033[33m$FWF_QUIC_ON\033[0m"
            fi
            setconfig quic_rj $quic_rj
            ;;
        4)
            if [ -n "$(ipset -v 2>/dev/null)" ] || [ "$firewall_mod" = 'nftables' ]; then
                if [ "$cn_ip_route" = "OFF" ]; then
                    cn_ip_route=ON
                    msg_alert -t 2 "\033[32m$FWF_CNIP_ON\033[0m" \
                        "\033[31m$FWF_CNIP_WARN\033[0m"
                else
                    cn_ip_route=OFF
                    msg_alert "\033[33m$FWF_CNIP_OFF\033[0m"
                fi
                setconfig cn_ip_route $cn_ip_route
            else
                msg_alert "\033[31m$FWF_NO_IPSET\033[0m"
            fi
            ;;
        5)
            set_cust_host_ipv4
            ;;
        6)
            set_reserve_ipv4
            ;;
        *)
            errornum
            ;;
        esac
    done
}

set_common_ports() {
    while true; do
        [ -z "$multiport" ] && multiport='22,80,443,8080,8443'
        line_break
        separator_line "="
        content_line "\033[31m$FWF_COMMON_NOTE\033[0m$FWF_MIX_NOTE"
        if [ -n "$common_ports" ]; then
            content_line ""
            content_line "$FWF_ALLOWED_PORTS\033[36m$multiport\033[0m"
        fi
        separator_line "="
        btm_box "${FWF_PORT_MENU_1_PREFIX}\033[36m$common_ports\033[0m${FWF_PORT_MENU_1_SUFFIX}" \
            "$FWF_PORT_MENU_2" \
            "$FWF_PORT_MENU_3" \
            "$FWF_PORT_MENU_4" \
            "$FWF_PORT_MENU_5" \
            "" \
            "$FWF_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            if [ "$common_ports" = ON ]; then
                common_ports=OFF
            else
                common_ports=ON
            fi

            if setconfig common_ports "$common_ports"; then
                msg_alert "\033[32m$COMMON_SUCCESS\033[0m"
            else
                msg_alert "\033[31m$COMMON_FAILED\033[0m"
            fi
            ;;
        2)
            while true; do
                port_count=$(echo "$multiport" | awk -F',' '{print NF}')
                if [ "$port_count" -ge 15 ]; then
                    comp_box "\033[31m$FWF_MAX_PORT\033[0m"
                else
                    comp_box "$FWF_ALLOWED_PORTS\033[36m$multiport\033[0m"
                    btm_box "\033[36m$FWF_INPUT_ADD_HINT\033[0m\n$FWF_INPUT_ADD_HINT2" \
                        "$FWF_OR_BACK"
                    read -r -p "$FWF_INPUT_PORT" port
                    if [ "$port" = 0 ]; then
                        break
                    elif echo ",$multiport," | grep -q ",$port,"; then
                        msg_alert "\033[31m$FWF_ERR_DUP\033[0m"
                    elif [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
                        msg_alert "\033[31m$FWF_ERR_RANGE\033[0m"
                    else
                        multiport=$(echo "$multiport,$port" | sed "s/^,//")

                        if setconfig multiport "$multiport"; then
                            msg_alert "\033[32m$COMMON_SUCCESS\033[0m"
                        else
                            msg_alert "\033[31m$COMMON_FAILED\033[0m"
                        fi
                    fi
                fi
            done
            ;;
        3)
            while true; do
                comp_box "$FWF_ALLOWED_PORTS\033[36m$multiport\033[0m"
                btm_box "\033[36m$FWF_INPUT_REMOVE_HINT\033[0m\n$FWF_INPUT_ADD_HINT2" \
                    "$FWF_OR_BACK"
                read -r -p "$FWF_INPUT_PORT" port
                if [ "$port" = 0 ]; then
                    break
                elif echo ",$multiport," | grep -q ",$port,"; then
                    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
                        msg_alert "\033[31m$FWF_ERR_RANGE\033[0m"
                    else
                        multiport=$(echo ",$multiport," | sed "s/,$port//; s/^,//; s/,$//")
                        if setconfig multiport "$multiport"; then
                            msg_alert "\033[32m$COMMON_SUCCESS\033[0m"
                        else
                            msg_alert "\033[31m$COMMON_FAILED\033[0m"
                        fi
                    fi
                else
                    msg_alert "\033[31m$FWF_ERR_DUP\033[0m"
                fi
            done
            ;;
        4)
            multiport=''
            if setconfig multiport; then
                msg_alert "\033[32m$COMMON_SUCCESS\033[0m"
            else
                msg_alert "\033[31m$COMMON_FAILED\033[0m"
            fi
            ;;
        5)
            multiport='22,80,143,194,443,465,587,853,993,995,5222,8080,8443'
            if setconfig multiport "$multiport"; then
                msg_alert "\033[32m$COMMON_SUCCESS\033[0m"
            else
                msg_alert "\033[31m$COMMON_FAILED\033[0m"
            fi
            ;;
        *)
            errornum
            ;;
        esac
    done
}

# 自定义ipv4透明路由、保留地址网段
set_cust_host_ipv4() {
    while true; do
        [ -z "$replace_default_host_ipv4" ] && replace_default_host_ipv4="OFF"
        . "$CRASHDIR"/starts/fw_getlanip.sh && getlanip
        comp_box "$FWF_CUST_HOST_TITLE\033[32m$host_ipv4\033[0m" \
            "$FWF_CUST_HOST_TITLE2\033[36m$cust_host_ipv4\033[0m"
        btm_box "$FWF_CUST_HOST_MENU_1" \
            "$FWF_CUST_HOST_MENU_2	\033[36m$replace_default_host_ipv4\033[0m" \
            "" \
            "$FWF_BACK"
        read -r -p "$FWF_CUST_HOST_HINT" text
        case "$text" in
        "" | 0)
            break
            ;;
        1)
            unset cust_host_ipv4
            if setconfig cust_host_ipv4; then
                msg_alert "\033[32m$COMMON_SUCCESS\033[0m"
            else
                msg_alert "\033[31m$COMMON_FAILED\033[0m"
            fi
            ;;
        2)
            if [ "$replace_default_host_ipv4" = "OFF" ]; then
                replace_default_host_ipv4="ON"
            else
                replace_default_host_ipv4="OFF"
            fi

            if setconfig replace_default_host_ipv4 "$replace_default_host_ipv4"; then
                msg_alert "\033[32m$COMMON_SUCCESS\033[0m"
            else
                msg_alert "\033[31m$COMMON_FAILED\033[0m"
            fi
            ;;
        *)
            if echo "$text" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}' && [ -z "$(echo $cust_host_ipv4 | grep "$text")" ]; then
                cust_host_ipv4="$cust_host_ipv4 $text"
                if setconfig cust_host_ipv4 "'$cust_host_ipv4'"; then
                    msg_alert "\033[32m$COMMON_SUCCESS\033[0m"
                else
                    msg_alert "\033[31m$COMMON_FAILED\033[0m"
                fi
            else
                msg_alert "\033[31m$FWF_NET_ERR\033[0m"
            fi
            ;;
        esac
    done
}

set_reserve_ipv4() {
    while true; do
        [ -z "$reserve_ipv4" ] && reserve_ipv4="0.0.0.0/8 10.0.0.0/8 127.0.0.0/8 100.64.0.0/10 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 240.0.0.0/4"
        comp_box "\033[33m$FWF_RESERVE_NOTE\033[0m" \
            "" \
            "$FWF_RESERVE_NOW" \
            "\033[36m$reserve_ipv4\033[0m"
        btm_box "\033[36m$FWF_RESERVE_INPUT_HINT\033[0m" \
            "$FWF_RESERVE_INPUT_HINT2" \
            "$FWF_RESERVE_INPUT_HINT3"
        read -r -p "$FWF_RESERVE_PROMPT" text
        case "$text" in
        "" | 0)
            break
            ;;
        1)
            unset reserve_ipv4
            if setconfig reserve_ipv4; then
                msg_alert "\033[32m$COMMON_SUCCESS\033[0m"
            else
                msg_alert "\033[31m$COMMON_FAILED\033[0m"
            fi
            ;;
        *)
            if echo "$text" | grep -Eq "(((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])/(3[0-2]|[1-2]?[0-9]))( +|$)+"; then
                reserve_ipv4="$text"
                if setconfig reserve_ipv4 "'$reserve_ipv4'"; then
                    msg_alert "\033[32m$FWF_RESERVE_SET$reserve_ipv4\033[0m"
                else
                    msg_alert "\033[31m$COMMON_FAILED\033[0m"
                fi
            else
                msg_alert "\033[31m$FWF_RESERVE_ERR\033[0m"
            fi
            ;;
        esac
    done
}

# 局域网设备过滤
fw_filter_lan() {
    get_devinfo() {
        dev_ip=$(cat "$dhcpdir" | grep " $dev " | awk '{print $3}') && [ -z "$dev_ip" ] && dev_ip=$dev
        dev_mac=$(cat "$dhcpdir" | grep " $dev " | awk '{print $2}') && [ -z "$dev_mac" ] && dev_mac=$dev
        dev_name=$(cat "$dhcpdir" | grep " $dev " | awk '{print $4}') && [ -z "$dev_name" ] && dev_name="$FWF_LAN_NO_DEVICE"
    }
    add_mac() {
        while true; do
            comp_box "$FWF_MAC_HINT"
            content_line "$FWF_MAC_EXISTED"
            content_line ""
            if [ -s "$CRASHDIR/configs/mac" ]; then
                while IFS= read -r line; do
                    content_line "$line"
                done <"$CRASHDIR/configs/mac"
            else
                content_line "$FWF_NONE_MAC"
            fi
            separator_line "="
            content_line "$FWF_MAC_HEADER"
            if [ -s "$dhcpdir" ]; then
                awk '{print NR") "$3,$2,$4}' "$dhcpdir" |
                    while IFS= read -r line; do
                        content_line "$line"
                    done
            else
                content_line "$FWF_MAC_NONE"
            fi
            btm_box "" \
                "$FWF_BACK"
            read -r -p "$FWF_MAC_INPUT_HINT" num
            if [ -z "$num" ] || [ "$num" = 0 ]; then
                i=
                break
            elif echo "$num" | grep -aEq '^([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})$'; then
                if [ -z "$(cat "$CRASHDIR"/configs/mac | grep -E "$num")" ]; then
                    echo "$num" | grep -oE '^([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})$' >>"$CRASHDIR"/configs/mac
                else
                    msg_alert "\033[31m$FWF_MAC_DUP\033[0m"
                fi
            elif [ "$num" -le $(cat $dhcpdir 2>/dev/null | awk 'END{print NR}') ]; then
                macadd=$(cat "$dhcpdir" | awk '{print $2}' | sed -n "$num"p)
                if [ -z "$(cat "$CRASHDIR"/configs/mac | grep -E "$macadd")" ]; then
                    echo "$macadd" >>"$CRASHDIR"/configs/mac
                else
                    msg_alert "\033[31m$FWF_MAC_DUP\033[0m"
                fi
            else
                msg_alert "\033[31m$FWF_RESERVE_ERR\033[0m"
            fi
        done
    }

    add_ip() {
        while true; do
            comp_box "$FWF_IP_HINT" \
                "$FWF_IP_HINT2"
            content_line "$FWF_IP_EXISTED"
            content_line ""
            if [ -s "$CRASHDIR/configs/ip_filter" ]; then
                while IFS= read -r line; do
                    content_line "$line"
                done <"$CRASHDIR/configs/ip_filter"
            else
                content_line "$FWF_NONE_IP"
            fi

            separator_line "="
            content_line "$FWF_IP_HEADER"
            if [ -s "$dhcpdir" ]; then
                awk '{print NR") "$3, $4}' "$dhcpdir" |
                    while IFS= read -r line; do
                        content_line "$line"
                    done
            else
                content_line "$FWF_MAC_NONE"
            fi
            btm_box "" \
                "$FWF_BACK"
            read -r -p "$FWF_IP_INPUT_HINT" num
            if [ -z "$num" ] || [ "$num" = 0 ]; then
                i=
                break
            elif echo "$num" | grep -aEq '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(/(3[0-2]|[12]?[0-9]))?$'; then
                if [ -z "$(cat "$CRASHDIR"/configs/ip_filter | grep -E "$num")" ]; then
                    echo "$num" | grep -oE '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(/(3[0-2]|[12]?[0-9]))?$' >>"$CRASHDIR"/configs/ip_filter
                else
                    msg_alert "\033[31m$FWF_IP_DUP\033[0m"
                fi
            elif [ "$num" -le "$(cat "$dhcpdir" 2>/dev/null | awk 'END{print NR}')" ]; then
                ipadd=$(cat "$dhcpdir" | awk '{print $3}' | sed -n "$num"p)
                if [ -z "$(cat "$CRASHDIR"/configs/mac | grep -E "$ipadd")" ]; then
                    echo "$ipadd" >>"$CRASHDIR"/configs/ip_filter
                else
                    msg_alert "\033[31m$FWF_IP_DUP\033[0m"
                fi
            else
                msg_alert "\033[31m$FWF_RESERVE_ERR\033[0m"
            fi
        done
    }

    del_all() {
        while true; do
            if [ -z "$(cat "$CRASHDIR"/configs/mac "$CRASHDIR"/configs/ip_filter 2>/dev/null)" ]; then
                msg_alert "\033[31m$FWF_REMOVE_NONE\033[0m"
                break
            else
                comp_box "$FWF_REMOVE_TITLE"
                content_line "$FWF_REMOVE_HEADER"
                i=1
                for dev in $(cat "$CRASHDIR"/configs/mac "$CRASHDIR"/configs/ip_filter 2>/dev/null); do
                    get_devinfo
                    content_line "$(printf "%s) \033[32m%-18s \033[36m%-18s \033[35m%s\033[0m" \
                        "$i" "$dev_ip" "$dev_mac" "$dev_name")"
                    i=$((i + 1))
                done
                btm_box "" \
                    "$FWF_BACK"
                read -r -p "$COMMON_INPUT> " num
                mac_filter_rows=$(cat "$CRASHDIR"/configs/mac 2>/dev/null | wc -l)
                ip_filter_rows=$(cat "$CRASHDIR"/configs/ip_filter 2>/dev/null | wc -l)
                if [ -z "$num" ] || [ "$num" -le 0 ]; then
                    n=
                    break
                elif [ "$num" -le "$mac_filter_rows" ]; then
                    sed -i "${num}d" "$CRASHDIR"/configs/mac
                    msg_alert "\033[32m$FWF_REMOVE_OK\033[0m"
                elif [ "$num" -le $((mac_filter_rows + ip_filter_rows)) ]; then
                    num=$((num - mac_filter_rows))
                    sed -i "${num}d" "$CRASHDIR"/configs/ip_filter
                    msg_alert "\033[32m$FWF_REMOVE_OK\033[0m"
                else
                    msg_alert "\033[31m$FWF_RESERVE_ERR\033[0m"
                fi
            fi
        done
    }

    while true; do
        [ -z "$dhcpdir" ] && [ -f /var/lib/dhcp/dhcpd.leases ] && dhcpdir='/var/lib/dhcp/dhcpd.leases'
        [ -z "$dhcpdir" ] && [ -f /var/lib/dhcpd/dhcpd.leases ] && dhcpdir='/var/lib/dhcpd/dhcpd.leases'
        [ -z "$dhcpdir" ] && [ -f /tmp/dhcp.leases ] && dhcpdir='/tmp/dhcp.leases'
        [ -z "$dhcpdir" ] && [ -f /tmp/dnsmasq.leases ] && dhcpdir='/tmp/dnsmasq.leases'
        [ -z "$dhcpdir" ] && dhcpdir='/dev/null'
        [ -z "$macfilter_type" ] && macfilter_type='黑名单'
        if [ "$macfilter_type" = '黑名单' ]; then
            macfilter_type_show="$FWF_BLACK_LIST"
            fw_filter_lan_over="$FWF_WHITE_LIST"
            fw_filter_lan_desc="$FWF_FILTER_BLACK_DESC"
        else
            macfilter_type_show="$FWF_WHITE_LIST"
            fw_filter_lan_over="$FWF_BLACK_LIST"
            fw_filter_lan_desc="$FWF_FILTER_WHITE_DESC"
        fi

        comp_box "\033[30;47m$FWF_FILTER_MENU_TITLE\033[0m" \
            "" \
            "$FWF_FILTER_MODE\033[33m$macfilter_type_show$FWF_FILTER_MODE_SUFFIX\033[0m" \
            "\033[36m$fw_filter_lan_desc\033[0m"
        if [ -n "$(cat "$CRASHDIR"/configs/mac)" ]; then
            content_line "$FWF_FILTER_EXISTED"
            content_line ""
            content_line "$FWF_FILTER_HEADER"
            for dev in $(cat "$CRASHDIR"/configs/mac 2>/dev/null); do
                get_devinfo
                content_line "$(printf "\033[36m%-20s \033[35m%s\033[0m" \
                    "$dev_mac" "$dev_name")"
            done
            for dev in $(cat "$CRASHDIR"/configs/ip_filter 2>/dev/null); do
                get_devinfo
                content_line "$(printf "\033[36m%-20s \033[35m%s\033[0m" \
                    "$dev_ip" "$dev_name")"
            done
            separator_line "="
        fi
        btm_box "${FWF_FILTER_SWITCH_PREFIX}\033[33m$fw_filter_lan_over\033[0m${FWF_FILTER_SWITCH_SUFFIX}" \
            "$FWF_FILTER_ADD_MAC" \
            "$FWF_FILTER_ADD_IP" \
            "$FWF_FILTER_REMOVE" \
            "$FWF_FILTER_CLEAR" \
            "" \
            "$FWF_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            if [ "$macfilter_type" = '黑名单' ]; then
                macfilter_type='白名单'
            else
                macfilter_type='黑名单'
            fi
            if setconfig macfilter_type "$macfilter_type"; then
                msg_alert "\033[32m$FWF_SWITCH_OK\033[0m"
            else
                msg_alert "\033[31m$COMMON_FAILED\033[0m"
            fi
            ;;
        2)
            add_mac
            ;;
        3)
            add_ip
            ;;
        4)
            del_all
            ;;
        9)
            : >"$CRASHDIR"/configs/mac
            : >"$CRASHDIR"/configs/ip_filter
            msg_alert "\033[31m$FWF_LIST_CLEARED\033[0m"
            ;;
        *)
            errornum
            ;;
        esac
    done
}

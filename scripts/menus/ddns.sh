#! /bin/bash
# Copyright (C) Juewuy

load_lang ddns

ddns_menu() {
    top_box "\033[30;46m$DDNS_WELCOME\033[0m"
    load_ddns
}

add_ddns() {
    cat >>"$ddns_dir" <<EOF

config service '$service'
    option enabled '1'
    option force_unit 'hours'
    option lookup_host '$domain'
    option service_name '$service_name'
    option domain '$domain'
    option username '$username'
    option use_https '0'
    option use_ipv6 '$use_ipv6'
    option password '$password'
    option ip_source 'web'
    option check_unit 'minutes'
    option check_interval '$check_interval'
    option force_interval '$force_interval'
    option interface 'wan'
    option bind_network 'wan'
EOF
    /usr/lib/ddns/dynamic_dns_updater.sh -S "$service" start >/dev/null 2>&1 &
    sleep 3
    msg_alert "$DDNS_ADD_DONE"
}

set_ddns() {
    while true; do
        line_break
        read -r -p "$DDNS_INPUT_DOMAIN> " str
        [ -z "$str" ] && domain="$domain" || domain="$str"
        echo ""
        read -r -p "$DDNS_INPUT_USER> " str
        [ -z "$str" ] && username="$username" || username="$str"
        echo ""
        read -r -p "$DDNS_INPUT_PASS> " str
        [ -z "$str" ] && password="$password" || password="$str"
        echo ""
        read -r -p "$DDNS_INPUT_CHECK_INTERVAL> " check_interval
        [ -z "$check_interval" ] || [ "$check_interval" -lt 1 -o "$check_interval" -gt 1440 ] && check_interval=10
        echo ""
        read -r -p "$DDNS_INPUT_FORCE_INTERVAL> " force_interval
        [ -z "$force_interval" ] || [ "$force_interval" -lt 1 -o "$force_interval" -gt 240 ] && force_interval=24

        comp_box "$DDNS_CONFIRM_INFO" \
            "" \
            "$DDNS_FIELD_SERVICE		\033[32m$service\033[0m" \
            "$DDNS_FIELD_DOMAIN		\033[32m$domain\033[0m" \
            "$DDNS_FIELD_USER		\033[32m$username\033[0m" \
            "$DDNS_FIELD_INTERVAL	\033[32m$check_interval\033[0m"
        btm_box "$DDNS_CONFIRM_ADD"
        btm_box "1) $DDNS_YES" \
            "0) $DDNS_REINPUT"
        read -r -p "$COMMON_INPUT> " res
        if [ "$res" = 1 ]; then
            add_ddns
            break
        fi
    done
}

set_ddns_service() {
    while true; do
        services_dir=/etc/ddns/"$serv"
        [ -s "$services_dir" ] || services_dir=/etc/ddns/services
        [ -s "$services_dir" ] || services_dir=/usr/share/ddns/list
        [ -s "$services_dir" ] || {
            msg_alert "\033[33m$DDNS_LIST_NOT_FOUND\033[0m"
            ddns service update >/dev/null || msg_alert "\033[31m$DDNS_DOWNLOAD_FAILED\033[0m"
        }
        comp_box "\033[32m$DDNS_SELECT_PROVIDER\033[0m"

        list=$(awk '/^#/ || !NF {next} {print $1}' "$services_dir")
        list_box "$list"

        nr=$(echo "$list" | wc -l)
        common_back
        read -r -p "$COMMON_INPUT> " num
        if [ -z "$num" ] || [ "$num" = 0 ]; then
            i=
            break
        elif [ "$num" -gt 0 ] && [ "$num" -lt "$nr" ]; then
            service_name=$(echo "$list" | sed -n "$num"p | sed 's/"//g')
            service=$(echo "$service_name" | sed 's/\./_/g')
            set_ddns
            break
        else
            msg_alert "\033[33m$DDNS_INPUT_ERROR\033[0m"
        fi
    done
}

set_ddns_type() {
    while true; do
        comp_box "\033[32m$DDNS_SELECT_NETMODE\033[0m"
        btm_box "1) \033[36m$DDNS_IPV4\033[0m" \
            "2) \033[36m$DDNS_IPV6\033[0m" \
            "" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            use_ipv6=0
            serv=services
            set_ddns_service
            break
            ;;
        2)
            use_ipv6=1
            serv=services_ipv6
            set_ddns_service
            break
            ;;
        *)
            msg_alert "\033[33m$DDNS_INPUT_ERROR\033[0m"
            ;;
        esac
    done
}

rev_ddns_service() {
    while true; do
        enabled=$(uci get ddns."$service".enabled)
        [ "$enabled" = 1 ] && enabled_b="$DDNS_DISABLE" || enabled_b="$DDNS_ENABLE"
        comp_box "1) \033[32m$DDNS_UPDATE_NOW\033[0m" \
            "2) $DDNS_EDIT_CURRENT" \
            "3) $enabled_b$DDNS_CURRENT_SERVICE" \
            "4) $DDNS_REMOVE_CURRENT" \
            "5) $DDNS_VIEW_LOG" \
            "" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            /usr/lib/ddns/dynamic_dns_updater.sh -S "$service" start >/dev/null 2>&1 &
            sleep 3
            break
            ;;
        2)
            domain=$(uci get ddns."$service".domain 2>/dev/null)
            username=$(uci get ddns."$service".username 2>/dev/null)
            password=$(uci get ddns."$service".password 2>/dev/null)
            service_name=$(uci get ddns."$service".service_name 2>/dev/null)
            uci delete ddns."$service"
            set_ddns
            break
            ;;
        3)
            [ "$enabled" = 1 ] && uci set ddns."$service".enabled='0' || uci set ddns."$service".enabled='1' && sleep 3
            uci commit ddns."$service"
            break
            ;;
        4)
            uci delete ddns."$service"
            uci commit ddns."$service"
            break
            ;;
        5)
            line_break
            echo "==========================================================="
            cat /var/log/ddns/"$service".log 2>/dev/null
            echo "==========================================================="
            break
            ;;
        *)
            msg_alert "\033[33m$DDNS_INPUT_ERROR\033[0m"
            ;;
        esac
    done
}

load_ddns() {
    while true; do
        ddns_dir=/etc/config/ddns
        tmp_dir="$TMPDIR"/ddns
        [ ! -f "$ddns_dir" ] && {
            btm_box "\033[31m$DDNS_NOT_SUPPORTED\033[0m"
            sleep 1
            return 1
        }
        nr=0
        cat "$ddns_dir" | grep 'config service' | awk '{print $3}' | sed "s/'//g" | sed 's/"//g' >"$tmp_dir"
        separator_line "="
        content_line "$DDNS_LIST_HEADER"
        content_line ""
        [ -s "$tmp_dir" ] && for service in $(cat "$tmp_dir"); do
            # echo $service >>$tmp_dir
            nr=$((nr + 1))
            enabled=$(uci get ddns."$service".enabled 2>/dev/null)
            domain=$(uci get ddns."$service".domain 2>/dev/null)
            local_ip=$(sed '1!G;h;$!d' /var/log/ddns/"$service".log 2>/dev/null | grep -E 'Registered IP' | tail -1 | awk -F "'" '{print $2}' | tr -d "'\"")
            content_line "$nr)   $domain  $enabled   $local_ip"
        done
        content_line "$((nr + 1))) $DDNS_ADD_SERVICE"
        content_line "0) $DDNS_EXIT"
        separator_line "="
        read -r -p "$DDNS_INPUT_INDEX> " num
        if [ -z "$num" ] || [ "$num" = 0 ]; then
            i=
            rm -rf "$tmp_dir"
            break
        elif [ "$num" -gt $nr ]; then
            set_ddns_type
        elif [ "$num" -gt 0 ] && [ "$num" -le $nr ]; then
            service=$(cat "$tmp_dir" | sed -n "$num"p)
            rev_ddns_service
        else
            msg_alert "\033[33m$DDNS_INPUT_NUM_ERROR\033[0m"
        fi
    done
}

#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_7_GATEWAY_LOADED" ] && return
__IS_MODULE_7_GATEWAY_LOADED=1

. "$GT_CFG_PATH"
. "$CRASHDIR"/menus/check_port.sh
. "$CRASHDIR"/libs/gen_base64.sh
load_lang 7_gateway

# 访问与控制主菜单
gateway() {
    while true; do
        comp_box "\033[30;47m$GW_TITLE\033[0m"
        content_line "1) $GW_MENU_FW_WAN			\033[32m$fw_wan\033[0m"
        content_line "2) $GW_MENU_TG_BOT		\033[32m$bot_tg_service\033[0m"
        content_line "3) $GW_MENU_DDNS"
        [ "$disoverride" != "1" ] && {
            content_line "4) $GW_MENU_VMESS		\033[32m$vms_service\033[0m"
            content_line "5) $GW_MENU_SHADOWSOCKS	\033[32m$sss_service\033[0m"
            content_line "6) $GW_MENU_TS	\033[32m$ts_service\033[0m"
            content_line "7) $GW_MENU_WG	\033[32m$wg_service\033[0m"
        }
        btm_box "" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            if [ -n "$(pidof CrashCore)" ] && [ "$firewall_mod" = 'iptables' ]; then
                comp_box "\033[33m$GW_FW_STOP_WARN\033[0m" \
                    "$GW_CONFIRM_CONTINUE"
                btm_box "1) $GW_YES" \
                    "0) $GW_NO_BACK"
                read -r -p "$COMMON_INPUT> " res
                if [ "$res" = 1 ]; then
                    "$CRASHDIR"/start.sh stop && set_fw_wan
                else
                    continue
                fi
            else
                set_fw_wan
            fi
            ;;
        2)
            set_bot_tg
            ;;
        3)
            . "$CRASHDIR"/menus/ddns.sh && ddns_menu
            ;;
        4)
            set_vmess
            ;;
        5)
            set_shadowsocks
            ;;
        6)
            if echo "$crashcore" | grep -q 'sing'; then
                set_tailscale
            else
                msg_alert "\033[33m$crashcore$GW_CORE_UNSUPPORTED\033[0m"
            fi
            ;;
        7)
            if echo "$crashcore" | grep -q 'sing'; then
                set_wireguard
            else
                msg_alert "\033[33m$crashcore$GW_CORE_UNSUPPORTED\033[0m"
            fi
            ;;
        *)
            errornum
            ;;
        esac
    done
}

# 公网防火墙
set_fw_wan() {
    while true; do
        [ -z "$fw_wan" ] && fw_wan=ON
        line_break
        separator_line "="
        content_line "\033[31m$GW_WARN\033[0m$GW_FW_VPS_HINT"
        [ -n "$fw_wan_ports" ] &&
            content_line "$GW_FW_MANUAL_PORTS\033[36m$fw_wan_ports\033[0m"
        [ -n "$vms_port$sss_port" ] &&
            content_line "$GW_FW_AUTO_PORTS\033[36m$vms_port $sss_port\033[0m"
        content_line "$GW_FW_DEFAULT_BLOCK\033[33m$mix_port,$db_port\033[0m"
        separator_line "="
        btm_box "1) $GW_FW_TOGGLE\033[36m$fw_wan\033[0m" \
            "2) $GW_FW_ADD_PORT" \
            "3) $GW_FW_REMOVE_PORT" \
            "4) $GW_FW_CLEAR_PORTS" \
            "" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case $num in
        "" | 0)
            break
            ;;
        1)
            if [ "$fw_wan" = ON ]; then
                comp_box "$GW_FW_DISABLE_CONFIRM" \
                    "$GW_FW_DISABLE_RISK"
                btm_box "1) $GW_YES" \
                    "0) $GW_NO_BACK"
                read -r -p "$COMMON_INPUT> " res
                if [ "$res" = 1 ]; then
                    fw_wan=OFF
                else
                    fw_wan=ON
                fi
            else
                fw_wan=ON
            fi
            setconfig fw_wan "$fw_wan"
            ;;
        2)
            port_count=$(echo "$fw_wan_ports" | awk -F',' '{print NF}')
            if [ "$port_count" -ge 10 ]; then
                msg_alert "\033[31m$GW_FW_PORT_LIMIT\033[0m"
            else
                line_break
                read -r -p "$GW_INPUT_ALLOW_PORT> " port
                if echo ",$fw_wan_ports," | grep -q ",$port,"; then
                    msg_alert "\033[31m$GW_ERR_DUP_PORT\033[0m"
                elif [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
                    msg_alert "\033[31m$GW_ERR_PORT_RANGE\033[0m"
                else
                    fw_wan_ports=$(echo "$fw_wan_ports,$port" | sed "s/^,//")
                    if setconfig fw_wan_ports "$fw_wan_ports"; then
                        common_success
                    else
                        common_faileds
                    fi
                fi
            fi
            ;;
        3)
            while true; do
                comp_box "\033[36m$GW_INPUT_REMOVE_PORT\033[0m" \
                    "$GW_INPUT_0_BACK"
                read -r -p "$GW_INPUT_PLAIN> " port
                if [ "$port" = 0 ]; then
                    break
                elif echo ",$fw_wan_ports," | grep -q ",$port,"; then
                    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
                        msg_alert "\033[31m$GW_ERR_INPUT\033[0m" \
                            "\033[31m$GW_ERR_PORT_RANGE\033[0m"
                    else
                        fw_wan_ports=$(echo ",$fw_wan_ports," | sed "s/,$port//; s/^,//; s/,$//")
                        setconfig fw_wan_ports "$fw_wan_ports"
                        break
                    fi
                else
                    msg_alert "\033[31m$GW_ERR_INPUT\033[0m" \
                        "\033[31m$GW_ERR_PORT_NOT_FOUND\033[0m"
                fi
            done
            ;;
        4)
            fw_wan_ports=''
            setconfig fw_wan_ports
            msg_alert "\033[32m$GW_OK\033[0m"
            ;;
        *)
            errornum
            ;;
        esac
    done
}

# tg_BOT相关
set_bot_tg_config() {
    setconfig TG_TOKEN "$TOKEN" "$GT_CFG_PATH"
    setconfig TG_CHATID "$chat_ID" "$GT_CFG_PATH"
    # 设置机器人快捷命令
    JSON=$(
        cat <<EOF
{
  "commands": [
    {"command": "$my_alias", "description": "$GW_TG_CMD_MENU"},
    {"command": "help",  "description": "$GW_TG_CMD_HELP"}
  ]
}
EOF
    )
    TEXT="$GW_TG_DONE_PREFIX /$my_alias $GW_TG_DONE_SUFFIX"
    . "$CRASHDIR"/libs/web_json.sh
    bot_api="https://api.telegram.org/bot$TOKEN"
    web_json_post "$bot_api/setMyCommands" "$JSON"
    web_json_post "$bot_api/sendMessage" '{"chat_id":"'"$chat_ID"'","text":"'"$TEXT"'","parse_mode":"Markdown"}'

    comp_box "\033[32m$TEXT\033[0m"
}

set_bot_tg_init() {
    . "$CRASHDIR"/menus/bot_tg_bind.sh && private_bot && set_bot
    if [ "$?" = 0 ]; then
        set_bot_tg_config
        return 0
    else
        return 1
    fi
}

set_bot_tg_service() {
    if [ "$bot_tg_service" = ON ]; then
        bot_tg_service=OFF
        . "$CRASHDIR"/menus/bot_tg_service.sh && bot_tg_stop
    else
        bot_tg_service=ON
        [ -n "$(pidof CrashCore)" ] && . "$CRASHDIR"/menus/bot_tg_service.sh &&
            bot_tg_start && bot_tg_cron
    fi
    setconfig bot_tg_service "$bot_tg_service"
}

set_bot_tg() {
    while true; do
        [ -n "$ts_auth_key" ] && ts_auth_key_info="$GW_SET"
        [ -n "$TG_CHATID" ] && TG_CHATID_info="$GW_BOUND"
        comp_box "\033[31m$GW_WARN\033[0m$GW_TG_WARN"
        btm_box "1) $GW_TG_TOGGLE	\033[32m$bot_tg_service\033[0m" \
            "2) $GW_TG_BIND	\033[32m$TG_CHATID_info\033[0m" \
            "3) $GW_TG_MENUPUSH	\033[32m$TG_menupush\033[0m" \
            "" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            . "$GT_CFG_PATH"
            if [ -n "$TG_CHATID" ]; then
                set_bot_tg_service
            else
                msg_alert "\033[31m$GW_TG_BIND_FIRST\033[0m"
            fi
            ;;
        2)
            if [ -n "$chat_ID" ] && [ -n "$push_TG" ] && [ "$push_TG" != 'publictoken' ]; then
                comp_box "$GW_TG_BOUND_DETECTED" \
                    "$GW_TG_USE_DIRECT"
                btm_box "1) $GW_YES" \
                    "0) $GW_NO"
                read -r -p "$COMMON_INPUT> " res
                if [ "$res" = 1 ]; then
                    TOKEN="$push_TG"
                    set_bot_tg_config
                    continue
                fi
            fi
            set_bot_tg_init
            ;;
        3)
            if [ "$TG_menupush" = ON ]; then
                TG_menupush=OFF
            else
                TG_menupush=ON
            fi
            setconfig TG_menupush "$TG_menupush" "$GT_CFG_PATH"
            set_bot_tg
            ;;
        *)
            errornum
            ;;
        esac
    done
}

# 自定义入站
set_vmess() {
    while true; do
        comp_box "\033[31m$GW_WARN\033[0m" \
            "$GW_INBOUND_WARN_PORT" \
            "$GW_INBOUND_WARN_BASIC" \
            "\033[31m$GW_INBOUND_WARN_ILLEGAL\033[0m"
        content_line "1) \033[32m$GW_VMS_TOGGLE\033[0m  \033[32m$vms_service\033[0m"
        content_line "2) $GW_SET_LISTEN_PORT  \033[36m$vms_port\033[0m"
        content_line "3) $GW_SET_WSPATH  \033[33m$vms_ws_path\033[0m"
        content_line "4) $GW_SET_UUID  \033[36m$vms_uuid\033[0m"
        content_line "5) $GW_GEN_RANDOM_KEY"
        gen_base64 1 >/dev/null 2>&1 &&
            content_line "6) $GW_SET_OBFS_HOST  \033[33m$vms_host\033[0m"
        btm_box "7) $GW_GEN_SHARE_LINK" \
            "" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            if [ "$vms_service" = ON ]; then
                vms_service=OFF
                setconfig vms_service "$vms_service"
            else
                if [ -n "$vms_port" ] && [ -n "$vms_uuid" ]; then
                    vms_service=ON
                    setconfig vms_service "$vms_service"
                else
                    msg_alert "\033[31m$GW_FILL_REQUIRED\033[0m"
                fi
            fi
            ;;
        2)
            line_break
            read -r -p "$GW_INPUT_PORT_DEL0> " text
            if [ "$text" = 0 ]; then
                vms_port=''
                setconfig vms_port "" "$GT_CFG_PATH"
            elif check_port "$text"; then
                if echo "|$mix_port|$redir_port|$dns_port|$db_port|" | grep -q "|$text|"; then
                    msg_alert "\033[31m$CHECK_PORT_DUP_ERR\033[0m"
                    sleep 1
                else
                    vms_port="$text"
                    setconfig vms_port "$text" "$GT_CFG_PATH"
                fi
            else
                sleep 1
            fi
            ;;
        3)
            line_break
            read -r -p "$GW_INPUT_WSPATH> " text
            if [ "$text" = 0 ]; then
                vms_ws_path=''
                setconfig vms_ws_path "" "$GT_CFG_PATH"
            elif echo "$text" | grep -qE '^/'; then
                vms_ws_path="$text"
                setconfig vms_ws_path "$text" "$GT_CFG_PATH"
            else
                msg_alert "\033[31m$GW_ERR_WSPATH\033[0m"
            fi
            ;;
        4)
            line_break
            read -r -p "$GW_INPUT_UUID> " text
            if [ "$text" = 0 ]; then
                vms_uuid=''
                setconfig vms_uuid "" "$GT_CFG_PATH"
            elif echo "$text" | grep -qiE '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'; then
                vms_uuid="$text"
                setconfig vms_uuid "$text" "$GT_CFG_PATH"
            else
                msg_alert "\033[31m$GW_ERR_UUID\033[0m"
            fi
            ;;
        5)
            vms_uuid=$(cat /proc/sys/kernel/random/uuid)
            setconfig vms_uuid "$vms_uuid" "$GT_CFG_PATH"
            sleep 1
            ;;
        6)
            line_break
            read -r -p "$GW_INPUT_OBFS_HOST> " text
            if [ "$text" = 0 ]; then
                vms_host=''
                setconfig vms_host "" "$GT_CFG_PATH"
            else
                vms_host="$text"
                setconfig vms_host "$text" "$GT_CFG_PATH"
            fi
            ;;
        7)
            line_break
            read -r -p "$GW_INPUT_HOST> " host_wan
            if [ -n "$host_wan" ] && [ -n "$vms_port" ] && [ -n "$vms_uuid" ]; then
                [ -n "$vms_ws_path" ] && vms_net=ws
                vms_json=$(
                    cat <<EOF
{
  "v": "2",
  "ps": "ShellCrash_vms_in",
  "add": "$host_wan",
  "port": "$vms_port",
  "id": "$vms_uuid",
  "aid": "0",
  "type": "auto",
  "net": "$vms_net",
  "path": "$vms_ws_path",
  "host": "$vms_host"
}
EOF
                )
                vms_link="vmess://$(gen_base64 "$vms_json")"
                line_break
                echo -e "$GW_SHARE_LINK_HINT\n\033[32m$vms_link\033[0m"
                sleep 1
            else
                msg_alert "\033[31m$GW_FILL_REQUIRED\033[0m"
            fi
            ;;
        *)
            errornum
            ;;
        esac
    done
}

set_shadowsocks() {
    while true; do
        comp_box "\033[31m$GW_WARN\033[0m" \
            "$GW_INBOUND_WARN_PORT" \
            "$GW_INBOUND_WARN_BASIC" \
            "\033[31m$GW_INBOUND_WARN_ILLEGAL\033[0m"
        content_line "1) \033[32m$GW_SS_TOGGLE\033[0m  \033[32m$sss_service\033[0m"
        content_line "2) $GW_SET_LISTEN_PORT  \033[36m$sss_port\033[0m"
        content_line "3) $GW_SS_SELECT_CIPHER  \033[33m$sss_cipher\033[0m"
        content_line "4) $GW_SS_SET_PWD  \033[36m$sss_pwd\033[0m"
        gen_base64 1 >/dev/null 2>&1 &&
            content_line "5) $GW_GEN_SHARE_LINK"
        btm_box "" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            if [ "$sss_service" = ON ]; then
                sss_service=OFF
                setconfig sss_service "$sss_service"
            else
                if [ -n "$sss_port" ] && [ -n "$sss_cipher" ] && [ -n "$sss_pwd" ]; then
                    sss_service=ON
                    setconfig sss_service "$sss_service"
                else
                    msg_alert "\033[31m$GW_FILL_REQUIRED\033[0m"
                fi
            fi
            ;;
        2)
            line_break
            read -r -p "$GW_INPUT_PORT_DEL0> " text
            if [ "$text" = 0 ]; then
                sss_port=''
                setconfig sss_port "" "$GT_CFG_PATH"
            elif check_port "$text"; then
                if echo "|$mix_port|$redir_port|$dns_port|$db_port|" | grep -q "|$text|"; then
                    msg_alert "\033[31m$CHECK_PORT_DUP_ERR\033[0m"
                    sleep 1
                else
                    sss_port="$text"
                    setconfig sss_port "$text" "$GT_CFG_PATH"
                fi
            else
                sleep 1
            fi
            ;;
        3)
            comp_box "$GW_SS_SELECT_CIPHER"
            content_line "1) \033[32mxchacha20-ietf-poly1305\033[0m"
            content_line "2) \033[32mchacha20-ietf-poly1305\033[0m"
            content_line "3) \033[32maes-128-gcm\033[0m"
            content_line "4) \033[32maes-256-gcm\033[0m"
            gen_random 1 >/dev/null && {
                content_line ""
                content_line "$GW_SS_2022_NOTE_HEADER"
                content_line "$GW_SS_2022_REQUIRE"
                content_line "5) \033[32m2022-blake3-chacha20-poly1305\033[0m"
                content_line "6) \033[32m2022-blake3-aes-128-gcm\033[0m"
                content_line "7) \033[32m2022-blake3-aes-256-gcm\033[0m"
            }
            btm_box "" \
                "0) $COMMON_BACK"
            read -r -p "$COMMON_INPUT> " num
            case "$num" in
            0) ;;
            1)
                sss_cipher=xchacha20-ietf-poly1305
                sss_pwd=$(gen_random 16)
                ;;
            2)
                sss_cipher=chacha20-ietf-poly1305
                sss_pwd=$(gen_random 16)
                ;;
            3)
                sss_cipher=aes-128-gcm
                sss_pwd=$(gen_random 16)
                ;;
            4)
                sss_cipher=aes-256-gcm
                sss_pwd=$(gen_random 16)
                ;;
            5)
                sss_cipher=2022-blake3-chacha20-poly1305
                sss_pwd=$(gen_random 32)
                ;;
            6)
                sss_cipher=2022-blake3-aes-128-gcm
                sss_pwd=$(gen_random 16)
                ;;
            7)
                sss_cipher=2022-blake3-aes-256-gcm
                sss_pwd=$(gen_random 32)
                ;;
            *)
                errornum
                ;;
            esac
            setconfig sss_cipher "$sss_cipher" "$GT_CFG_PATH"
            setconfig sss_pwd "$sss_pwd" "$GT_CFG_PATH"
            ;;
        4)
            if echo "$sss_cipher" | grep -q '2022-blake3'; then
                msg_alert "\033[31m$GW_WARN\033[0m$GW_SS_2022_PASSWORD_ONLY"
            else
                line_break
                read -r -p "$GW_INPUT_PWD_DEL0> " text
                [ "$text" = 0 ] && sss_pwd='' || sss_pwd="$text"
                setconfig sss_pwd "$text" "$GT_CFG_PATH"
            fi
            ;;
        5)
            line_break
            read -r -p "$GW_INPUT_HOST> " text
            if [ -n "$text" ] && [ -n "$sss_port" ] && [ -n "$sss_cipher" ] && [ -n "$sss_pwd" ]; then
                ss_link="ss://$(gen_base64 "$sss_cipher":"$sss_pwd")@${text}:${sss_port}#ShellCrash_ss_in"
                line_break
                echo -e "$GW_SHARE_LINK_HINT\n\033[32m$ss_link\033[0m"
                sleep 1
            else
                msg_alert "\033[31m$GW_FILL_REQUIRED\033[0m"
            fi
            ;;
        *)
            errornum
            ;;
        esac
    done
}

# 自定义端点
set_tailscale() {
    while true; do
        [ -n "$ts_auth_key" ] && ts_auth_key_info='*********'
        comp_box "\033[31m$GW_WARN\033[0m$GW_TS_WARN" \
            "$GW_TS_KEY_URL" \
            "$GW_TS_ALLOW_URL" \
            "$GW_TS_SUBNET_EXIT_HINT"
        btm_box "1) \033[32m$GW_TS_TOGGLE\033[0m  \033[32m$ts_service\033[0m" \
            "2) $GW_TS_SET_AUTHKEY  $ts_auth_key_info" \
            "3) $GW_TS_SUBNET  \033[36m$ts_subnet\033[0m" \
            "4) $GW_TS_EXIT_NODE  \033[36m$ts_exit_node\033[0m" \
            "5) $GW_TS_HOSTNAME  $ts_hostname" \
            "" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            if [ -n "$ts_auth_key" ]; then
                [ "$ts_service" = ON ] && ts_service=OFF || ts_service=ON
                setconfig ts_service "$ts_service"
            else
                msg_alert "\033[31m$GW_TS_SET_KEY_FIRST\033[0m"
            fi
            ;;
        2)
            line_break
            read -r -p "$GW_TS_INPUT_KEY> " text
            [ "$text" = 0 ] && unset ts_auth_key ts_auth_key_info || ts_auth_key="$text"
            setconfig ts_auth_key "$ts_auth_key" "$GT_CFG_PATH"
            ;;
        3)
            [ "$ts_subnet" = true ] && ts_subnet=false || ts_subnet=true
            setconfig ts_subnet "$ts_subnet" "$GT_CFG_PATH"
            ;;
        4)
            if [ "$ts_exit_node" = true ]; then
                ts_exit_node=false
            else
                ts_exit_node=true
                msg_alert -t 3 "\033[31m$GW_WARN\033[0m$GW_TS_EXITNODE_WARN"
            fi
            setconfig ts_exit_node "$ts_exit_node" "$GT_CFG_PATH"
            ;;
        5)
            comp_box "\033[36m$GW_TS_INPUT_NAME\033[0m" \
                "$GW_INPUT_0_BACK"
            read -r -p "$GW_INPUT_PLAIN> " ts_hostname
            if [ "$ts_hostname" != 0 ]; then
                setconfig ts_hostname "$ts_hostname" "$GT_CFG_PATH"
            fi
            ;;
        *)
            errornum
            ;;
        esac
    done
}

set_wireguard() {
    while true; do

        if [ -n "$wg_public_key" ]; then
            wgp_key_info='*********'
        else
            unset wgp_key_info
        fi

        if [ -n "$wg_private_key" ]; then
            wgv_key_info='*********'
        else
            unset wgv_key_info
        fi

        if [ -n "$wg_pre_shared_key" ]; then
            wgpsk_key_info='*********'
        else
            unset wgpsk_key_info
        fi
        comp_box "\033[31m$GW_WARN\033[0m$GW_WG_WARN"
        btm_box "1) \033[32m$GW_WG_TOGGLE\033[0m  \033[32m$wg_service\033[0m" \
            "" \
            "2) $GW_WG_SET_ENDPOINT  \033[36m$wg_server\033[0m" \
            "3) $GW_WG_SET_ENDPOINT_PORT  \033[36m$wg_port\033[0m" \
            "4) $GW_WG_SET_PUBLIC  \033[36m$wgp_key_info\033[0m" \
            "5) $GW_WG_SET_PRESHARED  \033[36m$wgpsk_key_info\033[0m" \
            "" \
            "6) $GW_WG_SET_PRIVATE  \033[33m$wgv_key_info\033[0m" \
            "7) $GW_WG_SET_IPV4  \033[33m$wg_ipv4\033[0m" \
            "8) $GW_WG_SET_IPV6  \033[33m$wg_ipv6\033[0m" \
            "" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            if [ -n "$wg_server" ] && [ -n "$wg_port" ] && [ -n "$wg_public_key" ] && [ -n "$wg_pre_shared_key" ] && [ -n "$wg_private_key" ] && [ -n "$wg_ipv4" ]; then
                [ "$wg_service" = ON ] && wg_service=OFF || wg_service=ON
                setconfig wg_service "$wg_service"
            else
                msg_alert "\033[31m$GW_FILL_REQUIRED\033[0m"
            fi
            ;;
        [1-8])
            line_break
            read -r -p "$GW_INPUT_TEXT_DEL0> " text
            [ "$text" = 0 ] && text=''
            case "$num" in
            2)
                wg_server="$text"
                setconfig wg_server "$text" "$GT_CFG_PATH"
                ;;
            3)
                wg_port="$text"
                setconfig wg_port "$text" "$GT_CFG_PATH"
                ;;
            4)
                wg_public_key="$text"
                setconfig wg_public_key "$text" "$GT_CFG_PATH"
                ;;
            5)
                wg_pre_shared_key="$text"
                setconfig wg_pre_shared_key "$text" "$GT_CFG_PATH"
                ;;
            6)
                wg_private_key="$text"
                setconfig wg_private_key "$text" "$GT_CFG_PATH"
                ;;
            7)
                wg_ipv4="$text"
                setconfig wg_ipv4 "$text" "$GT_CFG_PATH"
                ;;
            8)
                wg_ipv6="$text"
                setconfig wg_ipv6 "$text" "$GT_CFG_PATH"
                ;;
            esac
            ;;
        *)
            errornum
            ;;
        esac
    done
}

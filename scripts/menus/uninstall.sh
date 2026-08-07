#!/bin/sh
# Copyright (C) Juewuy

load_lang uninstall

# 卸载
uninstall() {
    comp_box "\033[31m$UNINSTALL_WARN\033[0m" \
        "$UNINSTALL_CONFIRM"
    btm_box "1) $UNINSTALL_YES" \
        "0) $UNINSTALL_NO"
    read -r -p "$COMMON_INPUT> " res
    if [ "$res" = '1' ]; then
        # 停止服务
        "$CRASHDIR"/start.sh stop 2>/dev/null
        "$CRASHDIR"/start.sh cronset "$UNINSTALL_CRON_CLASH" 2>/dev/null
        "$CRASHDIR"/start.sh cronset "$UNINSTALL_CRON_SUB" 2>/dev/null
        "$CRASHDIR"/start.sh cronset "$UNINSTALL_CRON_INIT" 2>/dev/null
        "$CRASHDIR"/start.sh cronset "task.sh" 2>/dev/null

        # 移除安装目录
        if [ -n "$CRASHDIR" ] && [ "$CRASHDIR" != '/' ]; then
            comp_box "$UNINSTALL_KEEP_CONFIRM"
            btm_box "1) $UNINSTALL_YES" \
                "0) $UNINSTALL_NO"
            read -r -p "$COMMON_INPUT> " res
            if [ "$res" = '1' ]; then
                mv -f "$CRASHDIR"/configs /tmp/ShellCrash/configs_bak
                mv -f "$CRASHDIR"/yamls /tmp/ShellCrash/yamls_bak
                mv -f "$CRASHDIR"/jsons /tmp/ShellCrash/jsons_bak
                rm -rf "$CRASHDIR"/*
                mv -f /tmp/ShellCrash/configs_bak "$CRASHDIR"/configs
                mv -f /tmp/ShellCrash/yamls_bak "$CRASHDIR"/yamls
                mv -f /tmp/ShellCrash/jsons_bak "$CRASHDIR"/jsons
            else
                rm -rf "$CRASHDIR"
            fi
        else
            msg_alert "\033[31m$UNINSTALL_ENV_ERROR\033[0m"
        fi

        # 移除其他内容
        sed -i "/alias $my_alias=*/"d /etc/profile 2>/dev/null
        sed -i '/alias crash=*/'d /etc/profile 2>/dev/null
        sed -i '/export CRASHDIR=*/'d /etc/profile 2>/dev/null
        sed -i '/export crashdir=*/'d /etc/profile 2>/dev/null
        [ -w ~/.zshrc ] && {
            sed -i "/alias $my_alias=*/"d ~/.zshrc 2>/dev/null
            sed -i '/export CRASHDIR=*/'d ~/.zshrc 2>/dev/null
        }
        sed -i '/all_proxy/'d /etc/profile 2>/dev/null
        sed -i '/ALL_PROXY/'d /etc/profile 2>/dev/null
        sed -i "/$UNINSTALL_SSH_MARK/d" /etc/firewall.user 2>/dev/null
        sed -i "/$UNINSTALL_CRON_INIT/d" /etc/storage/started_script.sh 2>/dev/null
        sed -i "/$UNINSTALL_CRON_INIT/d" /jffs/.asusrouter 2>/dev/null
        [ "$BINDIR" != "$CRASHDIR" ] && rm -rf "$BINDIR"
        rm -rf /etc/init.d/shellcrash
        rm -rf /etc/systemd/system/shellcrash.service
        rm -rf /usr/lib/systemd/system/shellcrash.service
        rm -rf /www/clash
        rm -rf /tmp/ShellCrash
        rm -rf /usr/bin/crash
        sed -i '/0:7890/d' /etc/passwd 2>/dev/null
        userdel -r shellcrash 2>/dev/null
        nvram set script_usbmount="" 2>/dev/null
        nvram commit 2>/dev/null
        comp_box "\033[36m$UNINSTALL_DONE\033[0m" \
            "\033[33m$UNINSTALL_CLOSE_HINT\033[0m"
        line_break
        sleep 1
        exit 0
    else
        msg_alert "\033[31m$UNINSTALL_CANCELED\033[0m"
    fi
}

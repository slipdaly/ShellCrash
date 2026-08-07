#!/bin/sh
# Copyright (C) Juewuy

[ -f /tmp/SC_tmp/libs/check_dir_avail.sh ] && . /tmp/SC_tmp/libs/check_dir_avail.sh

if [ -n "$CRASHDIR" ] && [ -s "$CRASHDIR/libs/i18n.sh" ]; then
    . "$CRASHDIR/libs/i18n.sh"
    load_lang set_crashdir
elif [ -n "$language" ] && [ -s "/tmp/SC_tmp/lang/$language/set_crashdir.lang" ]; then
    . "/tmp/SC_tmp/lang/$language/set_crashdir.lang"
fi

set_usb_dir() {
    while true; do
        comp_box "$SCD_SELECT_INSTALL_DIR"
        du -hL /mnt |
            awk '{print NR") "$2 " " $1}' |
            while IFS= read -r line; do
                content_line "$line"
            done
        separator_line "="
        read -r -p "$SCD_INPUT_NUM> " num
        dir=$(du -hL /mnt | awk '{print $2}' | sed -n "$num"p)
        if [ -z "$dir" ]; then
            msg_alert "\033[31m$SCD_INPUT_ERROR\033[0m"
            continue
        fi
        break 1
    done
}

set_xiaomi_dir() {
    comp_box "\033[33m$SCD_XIAOMI_DETECTED\033[0m"
    [ -d /data ] && content_line "1) /data$SCD_DIR_FREE$(dir_avail /data -h) $SCD_SOFT_SOLID"
    [ -d /userdisk ] && content_line "2) /userdisk$SCD_DIR_FREE$(dir_avail /userdisk -h) $SCD_SOFT_SOLID"
    [ -d /data/other_vol ] && content_line "3) /data/other_vol$SCD_DIR_FREE$(dir_avail /data/other_vol -h) $SCD_SOFT_SOLID"
    content_line "4) $SCD_CUSTOM_DIR_WARN"
    content_line ""
    content_line "0) $SCD_EXIT_INSTALL"
    separator_line "="
    read -r -p "$SCD_INPUT_NUM> " num
    case "$num" in
    1)
        dir=/data
        ;;
    2)
        dir=/userdisk
        ;;
    3)
        dir=/data/other_vol
        ;;
    4)
        set_cust_dir
        ;;
    *)
        line_break
        exit 1
        ;;
    esac
}

set_asus_usb() {
    while true; do
        comp_box "$SCD_SELECT_USB_DIR"
        du -hL /tmp/mnt |
            awk -F/ 'NF<=4 {print NR") "$2 " " $1}' |
            while IFS= read -r line; do
                content_line "$line"
            done
        separator_line "="
        read -r -p "$SCD_INPUT_NUM> " num
        dir=$(du -hL /tmp/mnt | awk -F/ 'NF<=4' | awk '{print $2}' | sed -n "$num"p)
        if [ ! -f "$dir/asusware.arm/etc/init.d/S50downloadmaster" ]; then
            msg_alert "\033[31m$SCD_ASUS_DM_NOT_FOUND $dir/asusware.arm/etc/init.d/S50downloadmaster，$SCD_CHECK_SETTING\033[0m"
        else
            break
        fi
    done
}

set_asus_dir() {
    separator_line "="
    btm_box "\033[33m$SCD_ASUS_DETECTED\033[0m" \
        "1) $SCD_ASUS_INSTALL_DM" \
        "2) $SCD_ASUS_INSTALL_SCRIPT" \
        "" \
        "0) $SCD_EXIT_INSTALL"
    read -r -p "$SCD_INPUT_NUM> " num
    case "$num" in
    1)
        msg_alert -t 2 "$SCD_ASUS_DM_HINT"
        set_asus_usb
        ;;
    2)
        msg_alert -t 2 "$SCD_ASUS_REINSTALL_HINT"
        dir=/jffs
        ;;
    *)
        line_break
        exit 1
        ;;
    esac
}

set_cust_dir() {
    while true; do
        comp_box "$SCD_PATH_FORMAT_HINT" \
            "" \
            "$SCD_PATH_FREE_SPACE"
        df -h |
            awk '{print $6, $4}' |
            sed '1d' |
            while IFS= read -r line; do
                content_line "$line"
            done
        separator_line "="
        read -r -p "$SCD_INPUT_CUSTOM_DIR> " dir
        if [ "$(dir_avail "$dir")" = 0 ] || [ -n "$(echo "$dir" | grep -Eq '^/(tmp|opt|sys)(/|$)')" ]; then
            msg_alert "\033[31m$SCD_PATH_ERROR\033[0m"
            continue
        fi
        break 1
    done
}

set_crashdir() {
    while true; do
        top_box "\033[33m$SCD_INSTALL_SPACE_HINT\033[0m"
        case "$systype" in
        Padavan)
            dir=/etc/storage
            ;;
        mi_snapshot)
            set_xiaomi_dir
            ;;
        asusrouter)
            set_asus_dir
            ;;
        ng_snapshot)
            dir=/tmp/mnt
            ;;
        *)
            separator_line "="
            btm_box "1) $SCD_INSTALL_ETC" \
                "2) $SCD_INSTALL_USR" \
                "3) $SCD_INSTALL_HOME" \
                "4) $SCD_INSTALL_USB" \
                "5) $SCD_INSTALL_MANUAL" \
                "" \
                "0) $SCD_EXIT_INSTALL"
            read -r -p "$SCD_INPUT_NUM> " num
            # 设置目录
            case "$num" in
            1)
                dir=/etc
                ;;
            2)
                dir=/usr/share
                ;;
            3)
                dir=~/.local/share
                mkdir -p ~/.config/systemd/user
                ;;
            4)
                set_usb_dir
                ;;
            5)
                set_cust_dir
                ;;
            *)
                msg_alert "$SCD_INSTALL_CANCELED"
                line_break
                exit 1
                ;;
            esac
            ;;
        esac

        if [ ! -w "$dir" ]; then
            msg_alert "\033[31m$SCD_NO_WRITE_PREFIX$dir$SCD_NO_WRITE_SUFFIX\033[0m"
        else
            comp_box "$SCD_TARGET_DIR_PREFIX\033[32m$dir\033[0m$SCD_TARGET_DIR_SPACE$(dir_avail "$dir" -h)" \
                "" \
                "$SCD_CONFIRM_INSTALL"
            btm_box "1) $SCD_YES" \
                "0) $SCD_NO"
            read -r -p "$SCD_INPUT_NUM> " res
            if [ "$res" = "1" ]; then
                CRASHDIR="$dir"/ShellCrash
                break
            fi
        fi
    done
}

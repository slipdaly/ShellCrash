#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_PROVIDERS" ] && return
__IS_MODULE_PROVIDERS=1

load_lang providers

if [ "$crashcore" = singboxr ]; then
    CORE_TYPE=singbox
else
    CORE_TYPE=clash
fi

providers() {
    while true; do
        # 获取模版名称
        if [ -z "$(grep "provider_temp_${CORE_TYPE}" "$CRASHDIR"/configs/ShellCrash.cfg)" ]; then
            provider_temp_des=$(sed -n "1 p" "$CRASHDIR"/configs/"${CORE_TYPE}"_providers.list | awk '{print $1}')
        else
            provider_temp_file=$(grep "provider_temp_${CORE_TYPE}" "$CRASHDIR"/configs/ShellCrash.cfg | awk -F '=' '{print $2}')
            provider_temp_des=$(grep "$provider_temp_file" "$CRASHDIR"/configs/"${CORE_TYPE}"_providers.list | awk '{print $1}')
            [ -z "$provider_temp_des" ] && provider_temp_des=$provider_temp_file
        fi

        comp_box "1) \033[32m$PROVIDERS_MENU_GEN\033[0m" \
            "2) $PROVIDERS_MENU_TEMPLATE     \033[32m$provider_temp_des\033[0m" \
            "3) $PROVIDERS_MENU_CLEAN" \
            "" \
            "0) $COMMON_BACK"
        read -r -p "$PROVIDERS_INPUT> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            if [ -s "$CRASHDIR"/configs/providers.cfg ] || [ -s "$CRASHDIR"/configs/providers_uri.cfg ]; then
                . "$CRASHDIR/menus/providers_$CORE_TYPE.sh"
                gen_providers
            else
                msg_alert "\033[31m$PROVIDERS_EMPTY_HINT\033[0m"
            fi
            ;;
        2)
            list=$(cat "$CRASHDIR/configs/${CORE_TYPE}_providers.list" | awk '{print $1}')

            comp_box "$PROVIDERS_TEMPLATE_CURRENT\033[32m$provider_temp_des\033[0m" \
                "\033[33m$PROVIDERS_TEMPLATE_SELECT\033[0m"
            list_box "$list"
            btm_box "" \
                "a) $PROVIDERS_TEMPLATE_LOCAL" \
                "" \
                "0) $COMMON_BACK"
            read -r -p "$PROVIDERS_INPUT> " num
            case "$num" in
            "" | 0) ;;
            a)
                line_break
                read -r -p "$PROVIDERS_TEMPLATE_PATH> " dir
                if [ -s "$dir" ]; then
                    provider_temp_file=$dir
                    if setconfig provider_temp_"$CORE_TYPE" "$provider_temp_file"; then
                        common_success
                    else
                        common_failed
                    fi
                else
                    msg_alert "\033[31m$PROVIDERS_TEMPLATE_NOT_FOUND\033[0m"
                fi
                ;;
            *)
                provider_temp_file=$(sed -n "$num p" "$CRASHDIR"/configs/"${CORE_TYPE}"_providers.list 2>/dev/null | awk '{print $2}')
                if [ -z "$provider_temp_file" ]; then
                    errornum
                else
                    if setconfig provider_temp_"$CORE_TYPE" "$provider_temp_file"; then
                        common_success
                    else
                        common_failed
                    fi
                fi
                ;;
            esac
            ;;
        3)
            comp_box "\033[33m$PROVIDERS_CLEAN_WARN $CRASHDIR/providers $PROVIDERS_CLEAN_WARN_END\033[0m" \
                "" \
                "$PROVIDERS_CLEAN_CONFIRM"
            btm_box "1) $PROVIDERS_YES" \
                "0) $PROVIDERS_NO"
            read -r -p "$COMMON_INPUT> " res
            if [ "$res" = "1" ]; then
                if rm -rf "$CRASHDIR"/providers; then
                    common_success
                else
                    common_failed
                fi
            fi
            ;;
        *)
            errornum
            ;;
        esac
    done
}

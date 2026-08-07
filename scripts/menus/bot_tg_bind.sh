#!/bin/sh

. "$CRASHDIR"/libs/web_get_lite.sh

load_lang bot_tg

private_bot() {
    comp_box "$BOT_TG_PRIVATE_HINT"
    read -r -p "$BOT_TG_INPUT_TOKEN> " TOKEN
    url_tg=https://api.telegram.org/bot${TOKEN}/getUpdates

    top_box "$BOT_TG_PRIVATE_TOP"
}

public_bot() {
    comp_box "$BOT_TG_PUBLIC_HINT"
    TOKEN=publictoken
    url_tg=https://tgbot.jwsc.eu.org/publictoken/getUpdates
}

tg_push_token() {
    push_TG="$TOKEN"
    setconfig push_TG "$TOKEN"
    setconfig chat_ID "$chat_ID"
    . "$CRASHDIR"/libs/logger.sh && logger "$BOT_TG_SET_DONE" 32
}

get_chatid() {
    i=1
    chat_ID=''
    while [ $i -le 3 ] && [ -z "$chat_ID" ]; do
        sleep 1
        comp_box "\033[33m$BOT_TG_CHATID_RETRY_PREFIX $i $BOT_TG_CHATID_RETRY_SUFFIX\033[0m"
        chat=$(web_get_lite "$url_tg" 2>/dev/null)
        if [ -n "$chat" ]; then
            chat_ID=$(echo "$chat" | sed 's/"update_id":/{\n"update_id":/g' | grep "$public_key" | head -n1 | grep -oE '"id":.*,"is_bot' | sed s'/"id"://' | sed s'/,"is_bot//')
        fi
        i=$((i + 1))
    done
}

set_bot() {
    public_key=$(cat /proc/sys/kernel/random/boot_id | sed 's/.*-//')
    btm_box "$BOT_TG_SEND_KEY        \033[30;46m$public_key\033[0m"
    read -r -p "$BOT_TG_SENT_CONFIRM(1/0)> " res
    if [ "$res" = 1 ]; then
        get_chatid
        [ -z "$chat_ID" ] && [ "$TOKEN" != 'publictoken' ] && {
            comp_box "\033[31m$BOT_TG_CHATID_FAIL\033[0m" \
                "$BOT_TG_CHATID_MANUAL_HINT \033[32;4m$url_tg\033[0m \n\033[36m$BOT_TG_CHATID_MANUAL_HINT2\033[0m"
            read -r -p "$BOT_TG_INPUT_CHATID> " chat_ID
        }
        if echo "$chat_ID" | grep -qE '^[0-9]{8,}$'; then
            return 0
        else
            msg_alert "\033[31m$BOT_TG_CHATID_RECONFIG\033[0m"
            return 1
        fi
    fi
}

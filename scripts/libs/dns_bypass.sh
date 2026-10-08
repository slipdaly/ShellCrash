#!/bin/sh
# Copyright (C) Juewuy

is_ipv6_address() {
    printf '%s\n' "$1" | awk '
    function count_parts(text, parts, count, i) {
        if (text == "") return 0
        count = split(text, parts, ":")
        for (i = 1; i <= count; i++) {
            if (parts[i] == "" || length(parts[i]) > 4 || parts[i] !~ /^[0-9A-Fa-f]+$/) return -1
        }
        return count
    }
    {
        address = $0
        double_colon = index(address, "::")
        if (double_colon) {
            left = substr(address, 1, double_colon - 1)
            right = substr(address, double_colon + 2)
            if (index(right, "::")) exit 1
            left_count = count_parts(left)
            right_count = count_parts(right)
            if (left_count < 0 || right_count < 0 || left_count + right_count >= 8) exit 1
            exit 0
        }
        exit count_parts(address) == 8 ? 0 : 1
    }'
}

is_dns_bypass_entry() {
    printf '%s\n' "$1" | grep -aEq '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(/(3[0-2]|[12]?[0-9]))?$' && return 0
    dns_bypass_address=${1%/*}
    dns_bypass_prefix=${1#*/}
    [ "$dns_bypass_prefix" = "$1" ] && dns_bypass_prefix=128
    case "$dns_bypass_prefix" in
    "" | *[!0-9]*)
        return 1
        ;;
    esac
    [ "$dns_bypass_prefix" -le 128 ] 2>/dev/null && is_ipv6_address "$dns_bypass_address"
}

load_dns_bypass() {
    dns_bypass=
    [ -f "$CRASHDIR"/configs/dns_bypass ] || return
    while IFS= read -r dns_bypass_line || [ -n "$dns_bypass_line" ]; do
        dns_bypass_line=${dns_bypass_line%%#*}
        dns_bypass_entry=$(printf '%s\n' "$dns_bypass_line" | awk '{print $1}')
        [ -n "$dns_bypass_entry" ] || continue
        if ! is_dns_bypass_entry "$dns_bypass_entry"; then
            [ -n "$__IS_LIB_LOGGER" ] && logger "忽略无效的DNS劫持绕过地址：$dns_bypass_entry" 0 off
            continue
        fi
        printf '%s\n' "$dns_bypass" | grep -Fxq "$dns_bypass_entry" && continue
        if [ -n "$dns_bypass" ]; then
            dns_bypass="$dns_bypass
$dns_bypass_entry"
        else
            dns_bypass="$dns_bypass_entry"
        fi
    done <"$CRASHDIR"/configs/dns_bypass
}

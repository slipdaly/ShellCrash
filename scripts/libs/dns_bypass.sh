#!/bin/sh
# Copyright (C) Juewuy

is_ipv6_address() {
    printf '%s\n' "$1" | awk '
    function hex_value(char) {
        return index("0123456789abcdef", tolower(char)) - 1
    }
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

ipv6_mask_prefix() {
    printf '%s\n' "$1" | awk '
    function hex_value(char) {
        return index("0123456789abcdef", tolower(char)) - 1
    }
    function count_parts(text, parts, count, i) {
        if (text == "") return 0
        count = split(text, parts, ":")
        for (i = 1; i <= count; i++) {
            if (parts[i] == "" || length(parts[i]) > 4 || parts[i] !~ /^[0-9A-Fa-f]+$/) return -1
        }
        return count
    }
    function expand_ipv6(address, out, double_colon, left, right, left_count, right_count, fill, i, n) {
        double_colon = index(address, "::")
        if (double_colon) {
            left = substr(address, 1, double_colon - 1)
            right = substr(address, double_colon + 2)
            if (index(right, "::")) return 0
            left_count = count_parts(left, left_parts)
            right_count = count_parts(right, right_parts)
            if (left_count < 0 || right_count < 0 || left_count + right_count >= 8) return 0
            n = 0
            for (i = 1; i <= left_count; i++) out[++n] = left_parts[i]
            fill = 8 - left_count - right_count
            for (i = 1; i <= fill; i++) out[++n] = "0"
            for (i = 1; i <= right_count; i++) out[++n] = right_parts[i]
            return n == 8
        }
        if (count_parts(address, full_parts) != 8) return 0
        for (i = 1; i <= 8; i++) out[i] = full_parts[i]
        return 1
    }
    function hex_to_int(text, value, i) {
        value = 0
        for (i = 1; i <= length(text); i++) value = value * 16 + hex_value(substr(text, i, 1))
        return value
    }
    {
        if (!expand_ipv6($0, hextets)) exit 1
        prefix = 0
        seen_zero = 0
        for (i = 1; i <= 8; i++) {
            value = hex_to_int(hextets[i])
            for (bit = 15; bit >= 0; bit--) {
                one = int(value / (2 ^ bit)) % 2
                if (one) {
                    if (seen_zero) exit 1
                    prefix++
                } else {
                    seen_zero = 1
                }
            }
        }
        print prefix
    }'
}

ipv6_mask_suffix() {
    printf '%s\n' "$1" | awk '
    function hex_value(char) {
        return index("0123456789abcdef", tolower(char)) - 1
    }
    function count_parts(text, parts, count, i) {
        if (text == "") return 0
        count = split(text, parts, ":")
        for (i = 1; i <= count; i++) {
            if (parts[i] == "" || length(parts[i]) > 4 || parts[i] !~ /^[0-9A-Fa-f]+$/) return -1
        }
        return count
    }
    function expand_ipv6(address, out, double_colon, left, right, left_count, right_count, fill, i, n) {
        double_colon = index(address, "::")
        if (double_colon) {
            left = substr(address, 1, double_colon - 1)
            right = substr(address, double_colon + 2)
            if (index(right, "::")) return 0
            left_count = count_parts(left, left_parts)
            right_count = count_parts(right, right_parts)
            if (left_count < 0 || right_count < 0 || left_count + right_count >= 8) return 0
            n = 0
            for (i = 1; i <= left_count; i++) out[++n] = left_parts[i]
            fill = 8 - left_count - right_count
            for (i = 1; i <= fill; i++) out[++n] = "0"
            for (i = 1; i <= right_count; i++) out[++n] = right_parts[i]
            return n == 8
        }
        if (count_parts(address, full_parts) != 8) return 0
        for (i = 1; i <= 8; i++) out[i] = full_parts[i]
        return 1
    }
    function hex_to_int(text, value, i) {
        value = 0
        for (i = 1; i <= length(text); i++) value = value * 16 + hex_value(substr(text, i, 1))
        return value
    }
    {
        if (!expand_ipv6($0, hextets)) exit 1
        suffix = 0
        seen_one = 0
        for (i = 1; i <= 8; i++) {
            value = hex_to_int(hextets[i])
            for (bit = 15; bit >= 0; bit--) {
                one = int(value / (2 ^ bit)) % 2
                if (one) {
                    seen_one = 1
                    suffix++
                } else if (seen_one) {
                    exit 1
                }
            }
        }
        if (suffix == 0) exit 1
        print suffix
    }'
}

ipv6_address_fits_mask() {
    printf '%s|%s\n' "$1" "$2" | awk -F'|' '
    function hex_value(char) {
        return index("0123456789abcdef", tolower(char)) - 1
    }
    function count_parts(text, parts, count, i) {
        if (text == "") return 0
        count = split(text, parts, ":")
        for (i = 1; i <= count; i++) {
            if (parts[i] == "" || length(parts[i]) > 4 || parts[i] !~ /^[0-9A-Fa-f]+$/) return -1
        }
        return count
    }
    function expand_ipv6(address, out, double_colon, left, right, left_count, right_count, fill, i, n) {
        double_colon = index(address, "::")
        if (double_colon) {
            left = substr(address, 1, double_colon - 1)
            right = substr(address, double_colon + 2)
            if (index(right, "::")) return 0
            left_count = count_parts(left, left_parts)
            right_count = count_parts(right, right_parts)
            if (left_count < 0 || right_count < 0 || left_count + right_count >= 8) return 0
            n = 0
            for (i = 1; i <= left_count; i++) out[++n] = left_parts[i]
            fill = 8 - left_count - right_count
            for (i = 1; i <= fill; i++) out[++n] = "0"
            for (i = 1; i <= right_count; i++) out[++n] = right_parts[i]
            return n == 8
        }
        if (count_parts(address, full_parts) != 8) return 0
        for (i = 1; i <= 8; i++) out[i] = full_parts[i]
        return 1
    }
    function hex_to_int(text, value, i) {
        value = 0
        for (i = 1; i <= length(text); i++) value = value * 16 + hex_value(substr(text, i, 1))
        return value
    }
    {
        if (!expand_ipv6($1, address) || !expand_ipv6($2, mask)) exit 1
        for (i = 1; i <= 8; i++) {
            address_value = hex_to_int(address[i])
            mask_value = hex_to_int(mask[i])
            for (bit = 0; bit < 16; bit++) {
                address_bit = int(address_value / (2 ^ bit)) % 2
                mask_bit = int(mask_value / (2 ^ bit)) % 2
                if (!mask_bit && address_bit) exit 1
            }
        }
        exit 0
    }'
}

is_dns_bypass_ipv6_suffix() {
    dns_bypass_suffix_mask=${1#*/}
    [ "$dns_bypass_suffix_mask" != "$1" ] || return 1
    case "$dns_bypass_suffix_mask" in
    *[!0-9]*)
        ipv6_mask_suffix "$dns_bypass_suffix_mask" >/dev/null
        ;;
    *)
        return 1
        ;;
    esac
}

normalize_dns_bypass_entry() {
    printf '%s\n' "$1" | grep -aEq '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(/(3[0-2]|[12]?[0-9]))?$' && {
        printf '%s\n' "$1"
        return 0
    }
    dns_bypass_address=${1%/*}
    dns_bypass_prefix=${1#*/}
    [ "$dns_bypass_prefix" = "$1" ] && {
        is_ipv6_address "$dns_bypass_address" || return 1
        printf '%s\n' "$dns_bypass_address"
        return 0
    }
    case "$dns_bypass_prefix" in
    "" | *[!0-9]*)
        if ! is_ipv6_address "$dns_bypass_prefix"; then
            return 1
        fi
        if dns_bypass_prefix_num=$(ipv6_mask_prefix "$dns_bypass_prefix"); then
            dns_bypass_prefix=$dns_bypass_prefix_num
        elif ipv6_mask_suffix "$dns_bypass_prefix" >/dev/null &&
            ipv6_address_fits_mask "$dns_bypass_address" "$dns_bypass_prefix"; then
            printf '%s/%s\n' "$dns_bypass_address" "$dns_bypass_prefix"
            return 0
        else
            return 1
        fi
        ;;
    esac
    [ "$dns_bypass_prefix" -le 128 ] 2>/dev/null || return 1
    is_ipv6_address "$dns_bypass_address" || return 1
    printf '%s/%s\n' "$dns_bypass_address" "$dns_bypass_prefix"
}

is_dns_bypass_entry() {
    normalize_dns_bypass_entry "$1" >/dev/null
}

load_dns_bypass() {
    dns_bypass=
    [ -f "$CRASHDIR"/configs/dns_bypass ] || return
    while IFS= read -r dns_bypass_line || [ -n "$dns_bypass_line" ]; do
        dns_bypass_line=${dns_bypass_line%%#*}
        dns_bypass_entry=$(printf '%s\n' "$dns_bypass_line" | awk '{print $1}')
        [ -n "$dns_bypass_entry" ] || continue
        dns_bypass_raw_entry=$dns_bypass_entry
        if ! dns_bypass_entry=$(normalize_dns_bypass_entry "$dns_bypass_entry"); then
            [ -n "${__IS_LIB_LOGGER:-}" ] && logger "忽略无效的DNS劫持绕过地址：$dns_bypass_raw_entry" 0 off
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

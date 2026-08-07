
get_ecs_address() {
    for f in /tmp/resolv.conf.auto /tmp/resolv.conf /tmp/resolv.conf.d/resolv.conf.auto; do
        [ -f "$f" ] || continue
        ip=$(grep -A1 "^# Interface wan$" "$f" | grep nameserver | awk '{printf "%s ", $2}')
        [ -n "$ip" ] && return
    done
    . "$CRASHDIR"/libs/web_get_lite.sh
    #轮询公网IP，提取并校验为合法IPv4才采用，否则继续尝试下一个
    for web in http://ddns.oray.com/checkip http://members.3322.org/dyndns/getip http://ipinfo.io/ip; do
        ip=$(web_get_lite "$web" 0 | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | tail -1)
        [ -n "$ip" ] && return
    done
}
get_ecs_address
[ -n "$ip" ] && ecs_address="${ip%.*}.0/24"

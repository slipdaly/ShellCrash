
[ -z "$CRASHDIR" ] && CRASHDIR=$(cd "$(dirname "$0")"/.. && pwd)
PIDFILE="/tmp/ShellCrash/$1.pid"
LOCKDIR="/tmp/ShellCrash/start_$1.lock"

check_firewall_wan_ip() {
    [ "$1" = "shellcrash" ] || return
    [ -f "$CRASHDIR"/configs/ShellCrash.cfg ] || return
    . "$CRASHDIR"/configs/ShellCrash.cfg >/dev/null 2>&1
    [ "$firewall_mod" = "iptables" -o "$firewall_mod" = "nftables" ] || return
    [ "$firewall_area" = 2 -o "$firewall_area" = 3 ] || return
    reload_fw=
    #WAN地址或LAN IPv6前缀可能晚于保守模式启动或拨号后变化；发现本机/局域网规则缺失时仅重刷防火墙
    #外网未通时route get拿不到WAN源地址会跳过，避免watchdog每分钟误触发
    #fw_start.sh依赖start.sh加载的上下文，watchdog重刷前必须补齐libs并用source执行
    wan_ipv4=$(for target in 1.1.1.1 8.8.8.8 114.114.114.114; do ip route get "$target" 2>/dev/null | grep -Eo 'src [0-9]{1,3}(\.[0-9]{1,3}){3}' | awk '{print $2}' | head -n 1; done | head -n 1)
    [ "$ipv6_redir" = "ON" ] && {
        wan_ipv6=$(for target in 2001:4860:4860::8888 2606:4700:4700::1111 2400:3200::1; do ip -6 route get "$target" 2>/dev/null | grep -Eo 'src [0-9A-Fa-f:.]+' | awk '{print $2}' | head -n 1; done | head -n 1)
        lan_ifaces=$(ip route show scope link | grep -Ev 'ppp|wan|utun|iot|peer|docker|podman|virbr|vnet|ovs|vmbr|veth|vmnic|vboxnet|lxcbr|xenbr|vEthernet|wgs|multicast|anycast' | awk '{for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); break}}' | grep -v '^lo$' | sort -u)
        #优先取路由前缀，避免地址写法(::1/60)与防火墙规范化写法(::/60)不一致导致误判
        lan_ipv6=$(for iface in $lan_ifaces; do ip -6 route show dev "$iface" 2>/dev/null; done | grep -Ev 'default|unreachable|fe80::/' | awk '{print $1}' | sort -u)
        [ -z "$lan_ipv6" ] && lan_ipv6=$(ip -6 route show | grep -Ev 'default|unreachable|fe80::/|wan|ppp|utun|iot|peer|docker|podman|virbr|vnet|ovs|vmbr|veth|vmnic|vboxnet|lxcbr|xenbr|vEthernet|wgs|multicast|anycast' | awk '{print $1}' | sort -u)
    }
    if [ "$firewall_mod" = "iptables" ]; then
        [ -n "$wan_ipv4" ] && for chain in "mangle shellcrash_mark_out" "nat shellcrash_out" "nat shellcrash_dns_out"; do
            set -- $chain
            iptables -t "$1" -S "$2" >/dev/null 2>&1 && ! iptables -t "$1" -S "$2" 2>/dev/null | grep -q -- "-s $wan_ipv4" && reload_fw=1
        done
        [ -n "$wan_ipv6" ] && for chain in "mangle shellcrashv6_mark_out" "nat shellcrashv6_out"; do
            set -- $chain
            ip6tables -t "$1" -S "$2" >/dev/null 2>&1 && ! ip6tables -t "$1" -S "$2" 2>/dev/null | grep -q -- "-s $wan_ipv6" && reload_fw=1
        done
        [ -n "$lan_ipv6" ] && for chain in "mangle shellcrashv6_mark" "nat shellcrashv6" "nat shellcrashv6_dns"; do
            set -- $chain
            for ip in $lan_ipv6; do ip6tables -t "$1" -S "$2" >/dev/null 2>&1 && ! ip6tables -t "$1" -S "$2" 2>/dev/null | grep -q -- "-s $ip" && reload_fw=1; done
        done
    else
        [ -n "$wan_ipv4" ] && for chain in output output_dns; do
            nft list chain inet shellcrash "$chain" >/dev/null 2>&1 && ! nft list chain inet shellcrash "$chain" 2>/dev/null | grep -q -- "$wan_ipv4" && reload_fw=1
        done
        [ -n "$wan_ipv6" ] && nft list chain inet shellcrash output >/dev/null 2>&1 && ! nft list chain inet shellcrash output 2>/dev/null | grep -q -- "$wan_ipv6" && reload_fw=1
        [ -n "$lan_ipv6" ] && for chain in prerouting prerouting_dns; do
            for ip in $lan_ipv6; do nft list chain inet shellcrash "$chain" >/dev/null 2>&1 && ! nft list chain inet shellcrash "$chain" 2>/dev/null | grep -q -- "$ip" && reload_fw=1; done
        done
    fi
    [ -n "$reload_fw" ] || return
    "$CRASHDIR"/starts/fw_stop.sh >/dev/null 2>&1
    . "$CRASHDIR"/libs/get_config.sh >/dev/null 2>&1
    . "$CRASHDIR"/libs/check_cmd.sh >/dev/null 2>&1
    . "$CRASHDIR"/libs/logger.sh >/dev/null 2>&1
    . "$CRASHDIR"/starts/fw_start.sh >/dev/null 2>&1
}

[ -f "$CRASHDIR"/.start_error ] && [ ! -f /tmp/ShellCrash/crash_start_time ] && exit 1 #当启动失败后禁止开机自启动
mkdir "$LOCKDIR" 2>/dev/null || exit 1

if [ -f "$PIDFILE" ]; then
    PID="$(cat "$PIDFILE")"
    if [ -n "$PID" ] && [ "$PID" -eq "$PID" ] 2>/dev/null; then
        if kill -0 "$PID" 2>/dev/null || [ -d "/proc/$PID" ]; then
            check_firewall_wan_ip "$1"
            rm -fr "$LOCKDIR" 2>/dev/null
            exit 0
        fi
    else
        rm -f "$PIDFILE"
    fi
fi

#如果没有进程则拉起
if [ "$1" = "shellcrash" ]; then
    "$CRASHDIR"/start.sh start
else
    [ -f "$CRASHDIR/starts/start_legacy.sh" ] && . "$CRASHDIR/starts/start_legacy.sh"
    killall bot_tg.sh 2>/dev/null
    start_legacy "$CRASHDIR/menus/bot_tg.sh" "$1"
fi

rm -fr "$LOCKDIR" 2>/dev/null

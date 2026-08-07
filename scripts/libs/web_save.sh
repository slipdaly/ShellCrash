get_save() { #获取面板信息并内部处理所有异常
	local response exit_code
	if curl --version >/dev/null 2>&1; then
		response=$(curl -sf -H "Authorization: Bearer ${secret}" -H "Content-Type:application/json" "$1" 2>&1)
		exit_code=$?
		[ $exit_code -eq 0 ] && [ -n "$response" ] && [ "$response" != "{}" ] && {
			echo "$response"
			return 0
		}
		return 1
	elif [ -n "$(wget --help 2>&1 | grep '\-\-method')" ]; then
		response=$(wget -q --header="Authorization: Bearer ${secret}" --header="Content-Type:application/json" -O - "$1" 2>&1)
		exit_code=$?
		[ $exit_code -eq 0 ] && [ -n "$response" ] && [ "$response" != "{}" ] && {
			echo "$response"
			return 0
		}
		return 1
	fi
	return 1
}

web_save() { #最小化保存面板节点选择
	#使用get_save获取面板节点设置，失败自动退出
	response=$(get_save "http://127.0.0.1:${db_port}/proxies") || return 1

	echo "$response" | sed 's/{}//g' | sed 's/:{/\
/g' | grep -aE '"Selector"' >"$TMPDIR"/web_proxies

	>"$TMPDIR"/web_save
	[ -s "$TMPDIR"/web_proxies ] && while read line; do
		def=$(echo "$line" | grep -oE '"all".*",' | awk -F "[\"]" '{print $4}')
		now=$(echo "$line" | grep -oE '"now".*",' | awk -F "[\"]" '{print $4}')
		[ "$def" != "$now" ] && {
			name=$(echo "$line" | grep -oE '"name".*",' | awk -F "[\"]" '{print $4}')
			echo "${name},${now}" >>"$TMPDIR"/web_save
		}
	done <"$TMPDIR"/web_proxies
	rm -f "$TMPDIR"/web_proxies
	. "$CRASHDIR"/libs/compare.sh && compare "$TMPDIR"/web_save "$CRASHDIR"/configs/web_save
	[ "$?" = 0 ] && rm -f "$TMPDIR"/web_save || mv -f "$TMPDIR"/web_save "$CRASHDIR"/configs/web_save
}

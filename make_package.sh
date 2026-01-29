#!/bin/bash

# ShellCrash 打包脚本
# 用于创建 ShellCrash.tar.gz 压缩包

set -e  # 遇到错误时退出

# 检查必需的命令是否存在
check_commands() {
    local missing_cmds=()
    
    for cmd in tar cp mktemp rm cd pwd; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_cmds+=("$cmd")
        fi
    done
    
    # 检查是否有 dos2unix 或者 sed 可用来处理换行符
    if ! command -v dos2unix &> /dev/null && ! command -v sed &> /dev/null; then
        missing_cmds+=("dos2unix/sed")
    fi
    
    if [ ${#missing_cmds[@]} -ne 0 ]; then
        echo "错误: 以下必需的命令未找到: ${missing_cmds[*]}"
        echo "提示: 需要 tar, cp, mktemp, rm, cd, pwd 命令以及 dos2unix 或 sed 来处理换行符"
        exit 1
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项]

选项:
  -h, --help      显示此帮助信息
  -o, --output    指定输出文件路径 (默认: ShellCrash.tar.gz)
  -v, --verbose   详细模式
  -f, --force-unix 强制转换所有脚本文件为Unix格式

示例:
  $0                    # 创建 ShellCrash.tar.gz
  $0 -o my_shellcrash.tar.gz  # 创建自定义名称的压缩包
  $0 -f                 # 强制转换为Unix格式后打包
EOF
}

# 默认参数
OUTPUT_FILE=""
VERBOSE=false
FORCE_UNIX=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -f|--force-unix)
            FORCE_UNIX=true
            shift
            ;;
        *)
            echo "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 设置默认输出文件
if [ -z "$OUTPUT_FILE" ]; then
    OUTPUT_FILE="ShellCrash.tar.gz"
fi

# 为输出目录设置变量
OUTPUT_DIR="$SRC_DIR"

# 日志函数
log() {
    if [ "$VERBOSE" = true ]; then
        echo "[INFO] $1"
    fi
}

error_exit() {
    echo "[ERROR] $1" >&2
    exit 1
}

convert_to_unix() {
    local file="$1"
    if [ "$FORCE_UNIX" = true ] || [[ "$file" == *.sh ]] || [[ "$file" == *.list ]] || [[ "$file" == *.conf ]] || [[ "$file" == *.ini ]] || [[ "$file" == *.txt ]]; then
        if command -v dos2unix &> /dev/null; then
            dos2unix -q "$file" 2>/dev/null || log "dos2unix处理 $file 时可能存在问题（如果不是关键错误可忽略）"
        elif command -v sed &> /dev/null; then
            # 使用sed移除回车符，将DOS格式换行符转换为Unix格式
            sed -i 's/\r$//' "$file" 2>/dev/null || log "sed处理 $file 时可能存在问题（如果不是关键错误可忽略）"
        else
            log "警告: 未找到dos2unix或sed命令，跳过Unix格式转换"
        fi
    fi
}

echo "开始创建 $OUTPUT_FILE..."

# 检查必需的命令
check_commands

# 创建临时目录
TEMP_DIR=$(mktemp -d) || error_exit "无法创建临时目录"
echo "使用临时目录: $TEMP_DIR"

# 定义源码根目录
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log "源码根目录: $SRC_DIR"

# 复制主要脚本文件
log "复制主脚本文件..."
cp -f "$SRC_DIR/scripts/init.sh" "$TEMP_DIR/" || error_exit "无法复制 init.sh"
cp -f "$SRC_DIR/scripts/menu.sh" "$TEMP_DIR/" || error_exit "无法复制 menu.sh"
cp -f "$SRC_DIR/scripts/start.sh" "$TEMP_DIR/" || error_exit "无法复制 start.sh"
cp -f "$SRC_DIR/version" "$TEMP_DIR/" || error_exit "无法复制 version"

# 转换主脚本文件为Unix格式
convert_to_unix "$TEMP_DIR/init.sh"
convert_to_unix "$TEMP_DIR/menu.sh"
convert_to_unix "$TEMP_DIR/start.sh"
convert_to_unix "$TEMP_DIR/version"

# 复制配置文件（如果存在）
log "复制配置文件..."
# 从rules子目录复制各种list文件
cp -f "$SRC_DIR/rules/clash_providers/clash_providers.list" "$TEMP_DIR/" 2>/dev/null && convert_to_unix "$TEMP_DIR/clash_providers.list" && log "已复制 clash_providers.list" || echo "注意: rules/clash_providers/clash_providers.list 不存在"
cp -f "$SRC_DIR/rules/singbox_providers/singbox_providers.list" "$TEMP_DIR/" 2>/dev/null && convert_to_unix "$TEMP_DIR/singbox_providers.list" && log "已复制 singbox_providers.list" || echo "注意: rules/singbox_providers/singbox_providers.list 不存在"

# 从public目录复制各种list文件
cp -f "$SRC_DIR/public/fake_ip_filter.list" "$TEMP_DIR/" 2>/dev/null && convert_to_unix "$TEMP_DIR/fake_ip_filter.list" && log "已复制 fake_ip_filter.list" || echo "注意: public/fake_ip_filter.list 不存在"
cp -f "$SRC_DIR/public/fallback_filter.list" "$TEMP_DIR/" 2>/dev/null && convert_to_unix "$TEMP_DIR/fallback_filter.list" && log "已复制 fallback_filter.list" || echo "注意: public/fallback_filter.list 不存在"
cp -f "$SRC_DIR/public/servers.list" "$TEMP_DIR/" 2>/dev/null && convert_to_unix "$TEMP_DIR/servers.list" && log "已复制 servers.list" || echo "注意: public/servers.list 不存在"

# 从public和scripts目录复制任务列表文件
cp -f "$SRC_DIR/scripts/task.list" "$TEMP_DIR/" 2>/dev/null && convert_to_unix "$TEMP_DIR/task.list" && log "已复制 scripts/task.list" || log "scripts/task.list 不存在"
cp -f "$SRC_DIR/public/task.list" "$TEMP_DIR/" 2>/dev/null && convert_to_unix "$TEMP_DIR/task.list" && log "已复制 public/task.list -> task.list" || log "public/task.list 也不存在"
cp -f "$SRC_DIR/public/task_en.list" "$TEMP_DIR/task_en.list" 2>/dev/null && convert_to_unix "$TEMP_DIR/task_en.list" && log "已复制 public/task_en.list -> task_en.list" || echo "注意: public/task_en.list 不存在"

# 从bin/geodata目录复制IP列表文件（并重命名）
cp -f "$SRC_DIR/bin/geodata/china_ip_list.txt" "$TEMP_DIR/cn_ip.txt" 2>/dev/null && convert_to_unix "$TEMP_DIR/cn_ip.txt" && log "已复制 china_ip_list.txt -> cn_ip.txt" || echo "注意: bin/geodata/china_ip_list.txt 不存在"
cp -f "$SRC_DIR/bin/geodata/china_ipv6_list.txt" "$TEMP_DIR/cn_ipv6.txt" 2>/dev/null && convert_to_unix "$TEMP_DIR/cn_ipv6.txt" && log "已复制 china_ipv6_list.txt -> cn_ipv6.txt" || echo "注意: bin/geodata/china_ipv6_list.txt 不存在"

# 复制libs目录
log "复制libs目录..."
mkdir -p "$TEMP_DIR/libs"
if [ -d "$SRC_DIR/scripts/libs" ]; then
    cp -r "$SRC_DIR/scripts/libs/"* "$TEMP_DIR/libs/"
    # 转换libs目录下的文本文件为Unix格式
    if [ -n "$(find "$TEMP_DIR/libs" -type f \( -name "*.sh" -o -name "*.list" -o -name "*.txt" -o -name "*.conf" -o -name "*.ini" \) -print -quit 2>/dev/null)" ]; then
        # 使用find -exec执行转换函数，需要将函数定义导出到子shell
        export -f convert_to_unix
        find "$TEMP_DIR/libs" -type f \( -name "*.sh" -o -name "*.list" -o -name "*.txt" -o -name "*.conf" -o -name "*.ini" \) -exec bash -c 'convert_to_unix "$1"' _ {} {} \;
        log "已转换 libs 目录中的文本文件"
    else
        log "libs目录中没有找到需要转换的文本文件"
    fi
    log "已复制 libs 目录"
else
    echo "警告: scripts/libs 目录不存在"
fi

# 复制menus目录
log "复制menus目录..."
mkdir -p "$TEMP_DIR/menus"
if [ -d "$SRC_DIR/scripts/menus" ]; then
    cp -r "$SRC_DIR/scripts/menus/"* "$TEMP_DIR/menus/"
    # 转换menus目录下的文本文件为Unix格式
    if [ -n "$(find "$TEMP_DIR/menus" -type f \( -name "*.sh" -o -name "*.list" -o -name "*.txt" -o -name "*.conf" -o -name "*.ini" \) -print -quit 2>/dev/null)" ]; then
        export -f convert_to_unix
        find "$TEMP_DIR/menus" -type f \( -name "*.sh" -o -name "*.list" -o -name "*.txt" -o -name "*.conf" -o -name "*.ini" \) -exec bash -c 'convert_to_unix "$1"' _ {} {} \;
        log "已转换 menus 目录中的文本文件"
    else
        log "menus目录中没有找到需要转换的文本文件"
    fi
    log "已复制 menus 目录"
else
    echo "警告: scripts/menus 目录不存在"
fi

# 复制starts目录
log "复制starts目录..."
mkdir -p "$TEMP_DIR/starts"
if [ -d "$SRC_DIR/scripts/starts" ]; then
    cp -r "$SRC_DIR/scripts/starts/"* "$TEMP_DIR/starts/"
    # 转换starts目录下的文本文件为Unix格式
    if [ -n "$(find "$TEMP_DIR/starts" -type f \( -name "*.sh" -o -name "*.list" -o -name "*.txt" -o -name "*.conf" -o -name "*.ini" -o -name "*.service" -o -name "*.procd" -o -name "*.openrc" \) -print -quit 2>/dev/null)" ]; then
        export -f convert_to_unix
        find "$TEMP_DIR/starts" -type f \( -name "*.sh" -o -name "*.list" -o -name "*.txt" -o -name "*.conf" -o -name "*.ini" -o -name "*.service" -o -name "*.procd" -o -name "*.openrc" \) -exec bash -c 'convert_to_unix "$1"' _ {} {} \;
        log "已转换 starts 目录中的文本文件"
    else
        log "starts目录中没有找到需要转换的文本文件"
    fi
    log "已复制 starts 目录"
else
    echo "警告: scripts/starts 目录不存在"
fi

# 进入临时目录进行打包
cd "$TEMP_DIR"

log "开始创建压缩包..."
# 使用绝对路径确保目标文件位置正确
tar zcvf "$SRC_DIR/$(basename "$OUTPUT_FILE")" *

# 返回源码目录
cd "$SRC_DIR"

# 清理临时目录
rm -rf "$TEMP_DIR"

echo "$OUTPUT_FILE 创建完成!"
echo "文件位置: $SRC_DIR/$OUTPUT_FILE"

# 显示压缩包大小信息
if command -v ls &> /dev/null; then
    ls -lh "$SRC_DIR/$OUTPUT_FILE"
fi
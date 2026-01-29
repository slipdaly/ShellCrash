# ShellCrash 打包脚本使用说明

## 概述

`make_package.sh` 是一个自动化脚本，用于将 ShellCrash 项目的必要文件打包成 `ShellCrash.tar.gz` 格式。这个压缩包可以用于分发或安装 ShellCrash。脚本还包含将文件转换为Unix格式的功能，确保在不同操作系统之间的一致性。

## 功能特点

- 自动识别并复制所有必要的脚本文件
- 包含所有子目录（libs, menus, starts）
- 支持可选的配置文件
- 提供详细的日志输出
- 支持自定义输出文件名
- 错误检测和处理
- **新增**: 自动将文本文件转换为Unix格式（CRLF -> LF），确保跨平台兼容性

## 依赖要求

- bash shell
- tar 命令
- cp 命令
- mktemp 命令
- rm 命令
- **可选**: `dos2unix` 命令或 `sed` 命令（用于转换行结束符）

## 使用方法

### 基本用法

```bash
chmod +x make_package.sh
./make_package.sh
```

这将在项目根目录生成 `ShellCrash.tar.gz` 文件。

### 高级用法

```bash
# 指定输出文件名
./make_package.sh -o my_shellcrash.tar.gz

# 显示详细输出
./make_package.sh -v

# 强制将所有脚本文件转换为Unix格式
./make_package.sh -f

# 同时指定输出文件名和详细输出
./make_package.sh -v -o custom_shellcrash.tar.gz

# 显示帮助信息
./make_package.sh -h
```

## 打包内容

脚本将包含以下文件和目录：

- 主要脚本文件：
  - init.sh
  - menu.sh
  - start.sh
  - version

- 配置文件（如果存在）：
  - clash_providers.list (来自 rules/clash_providers/clash_providers.list)
  - cn_ip.txt (来自 bin/geodata/china_ip_list.txt)
  - cn_ipv6.txt (来自 bin/geodata/china_ipv6_list.txt)
  - fake_ip_filter.list (来自 public/fake_ip_filter.list)
  - fallback_filter.list (来自 public/fallback_filter.list)
  - servers.list (来自 public/servers.list)
  - singbox_providers.list (来自 rules/singbox_providers/singbox_providers.list)
  - task.list (来自 public/task.list)

- 子目录：
  - libs/* (包含所有库文件)
  - menus/* (包含所有菜单脚本)
  - starts/* (包含所有启动脚本)

## Unix格式转换

脚本会自动将以下类型的文件转换为Unix格式（LF换行符）：
- `.sh` 脚本文件
- `.list` 列表文件
- `.txt` 文本文件
- `.conf` 配置文件
- `.ini` 配置文件
- `.service`, `.procd`, `.openrc` 服务配置文件

转换工具优先级：
1. `dos2unix` 命令（如果可用）
2. `sed` 命令（如果dos2unix不可用）

## 版本差异说明

与旧版本的 ShellCrash1.tar.gz 相比，当前版本的打包脚本做了以下修正：

1. **修正了文件路径**：
   - clash_providers.list 现在从 `rules/clash_providers/clash_providers.list` 正确复制
   - singbox_providers.list 现在从 `rules/singbox_providers/singbox_providers.list` 正确复制
   - fake_ip_filter.list, fallback_filter.list, servers.list, task.list 现在从 `public/` 目录正确复制

2. **缺失文件说明**：
   - task_en.list：该文件存在于旧版本 ShellCrash1.tar.gz 中，但在当前项目中未找到对应文件。如果需要此文件，请确认其来源位置。

## 注意事项

1. 脚本会在执行过程中显示警告信息，如果某些可选文件不存在。
2. 所有操作都在临时目录中进行，完成后会自动清理。
3. 如果脚本执行失败，临时目录会被保留以便调试。
4. 在Windows系统上生成的文件可能会有DOS风格的换行符（CRLF），此脚本会将其转换为Unix风格（LF）。

## 故障排除

如果遇到错误，请检查：

- 是否有足够的磁盘空间
- 是否有权限访问所需文件
- 系统是否安装了必需的命令（tar, cp, mktemp, rm）
- 如果需要格式转换，确认系统中有 dos2unix 或 sed 命令

## 维护

此脚本根据项目结构进行了优化，如果项目结构发生变化，可能需要相应更新此脚本。Unix格式转换功能确保了ShellCrash可以在各种Linux/Unix系统上正常运行。
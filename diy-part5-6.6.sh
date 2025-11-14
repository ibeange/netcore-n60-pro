#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part5-6.6.sh
# Description: OpenWrt DIY script part 5 (After Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

color() {
    case $1 in
        cr) echo -e "\e[1;31m$2\e[0m" ;;  # 红色
        cg) echo -e "\e[1;32m$2\e[0m" ;;  # 绿色
        cy) echo -e "\e[1;33m$2\e[0m" ;;  # 黄色
        cb) echo -e "\e[1;34m$2\e[0m" ;;  # 蓝色
        cp) echo -e "\e[1;35m$2\e[0m" ;;  # 紫色
        cc) echo -e "\e[1;36m$2\e[0m" ;;  # 青色
    esac
}

status() {
    local check=$? end_time=$(date '+%H:%M:%S') total_time
    total_time="==> 用时 $[$(date +%s -d $end_time) - $(date +%s -d $begin_time)] 秒"
    [[ $total_time =~ [0-9]+ ]] || total_time=""
    if [[ $check = 0 ]]; then
        printf "%-62s %s %s %s %s %s %s %s\n" \
        $(color cy $1) [ $(color cg ✔) ] $(echo -e "\e[1m$total_time")
    else
        printf "%-62s %s %s %s %s %s %s %s\n" \
        $(color cy $1) [ $(color cr ✕) ] $(echo -e "\e[1m$total_time")
    fi
}

find_dir() {
    find $1 -maxdepth 3 -type d -name $2 -print -quit 2>/dev/null
}

print_info() {
    printf "%s %-40s %s %s %s\n" $1 $2 $3 $4 $5
}

# 添加整个源仓库(git clone)
git_clone() {
    local repo_url branch target_dir current_dir
    if [[ "$1" == */* ]]; then
        repo_url="$1"
        shift
    else
        branch="-b $1 --single-branch"
        repo_url="$2"
        shift 2
    fi
    if [[ -n "$@" ]]; then
        target_dir="$@"
    else
        target_dir="${repo_url##*/}"
    fi
    git clone -q $branch --depth=1 $repo_url $target_dir 2>/dev/null || {
        print_info $(color cr 拉取) $repo_url [ $(color cr ✕) ]
        return 0
    }
    rm -rf $target_dir/{.git*,README*.md,LICENSE}
    current_dir=$(find_dir "package/ feeds/ target/" "$target_dir")
    if ([[ -d $current_dir ]] && rm -rf $current_dir); then
        mv -f $target_dir ${current_dir%/*}
        print_info $(color cg 替换) $target_dir [ $(color cg ✔) ]
    else
        mv -f $target_dir $destination_dir
        print_info $(color cb 添加) $target_dir [ $(color cb ✔) ]
    fi
}

# 添加源仓库内的指定目录
clone_dir() {
    local repo_url branch temp_dir=$(mktemp -d)
    if [[ "$1" == */* ]]; then
        repo_url="$1"
        shift
    else
        branch="-b $1 --single-branch"
        repo_url="$2"
        shift 2
    fi
    git clone -q $branch --depth=1 $repo_url $temp_dir 2>/dev/null || {
        print_info $(color cr 拉取) $repo_url [ $(color cr ✕) ]
        return 0
    }
    local target_dir source_dir current_dir
    for target_dir in "$@"; do
        source_dir=$(find_dir "$temp_dir" "$target_dir")
        [[ -d $source_dir ]] || \
        source_dir=$(find $temp_dir -maxdepth 4 -type d -name $target_dir -print -quit) && \
        [[ -d $source_dir ]] || {
            print_info $(color cr 查找) $target_dir [ $(color cr ✕) ]
            continue
        }
        current_dir=$(find_dir "package/ feeds/ target/" "$target_dir")
        if ([[ -d $current_dir ]] && rm -rf $current_dir); then
            mv -f $source_dir ${current_dir%/*}
            print_info $(color cg 替换) $target_dir [ $(color cg ✔) ]
        else
            mv -f $source_dir $destination_dir
            print_info $(color cb 添加) $target_dir [ $(color cb ✔) ]
        fi
    done
    rm -rf $temp_dir
}

# 添加源仓库内的所有目录
clone_all() {
    local repo_url branch temp_dir=$(mktemp -d)
    if [[ "$1" == */* ]]; then
        repo_url="$1"
        shift
    else
        branch="-b $1 --single-branch"
        repo_url="$2"
        shift 2
    fi
    git clone -q $branch --depth=1 $repo_url $temp_dir 2>/dev/null || {
        print_info $(color cr 拉取) $repo_url [ $(color cr ✕) ]
        return 0
    }
    local target_dir source_dir current_dir
    for target_dir in $(ls -l $temp_dir/$@ | awk '/^d/ {print $NF}'); do
        source_dir=$(find_dir "$temp_dir" "$target_dir")
        current_dir=$(find_dir "package/ feeds/ target/" "$target_dir")
        if ([[ -d $current_dir ]] && rm -rf $current_dir); then
            mv -f $source_dir ${current_dir%/*}
            print_info $(color cg 替换) $target_dir [ $(color cg ✔) ]
        else
            mv -f $source_dir $destination_dir
            print_info $(color cb 添加) $target_dir [ $(color cb ✔) ]
        fi
    done
    rm -rf $temp_dir
}

# 更新&安装插件
begin_time=$(date '+%H:%M:%S')
./scripts/feeds update -a 1>/dev/null 2>&1
./scripts/feeds install -a 1>/dev/null 2>&1
status "更新&安装插件"

color cr "更换golang版本"
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang feeds/packages/lang/golang

color cy "添加&替换插件"

# 创建插件保存目录
destination_dir="package/A"
[ -d $destination_dir ] || mkdir -p $destination_dir

# 添加额外插件
git_clone https://github.com/sbwml/luci-app-openlist2 package/luci-app-openlist2
git_clone https://github.com/sbwml/luci-app-mosdns package/luci-app-mosdns
git_clone https://github.com/brvphoenix/luci-app-wrtbwmon package/luci-app-wrtbwmon
git_clone https://github.com/brvphoenix/wrtbwmon package/wrtbwmon
git_clone https://github.com/timsaya/luci-app-bandix package/luci-app-bandix
git_clone https://github.com/timsaya/openwrt-bandix package/openwrt-bandix

# UU游戏加速器
git_clone https://github.com/kiddin9/kwrt-packages package/luci-app-uugamebooster
git_clone https://github.com/kiddin9/kwrt-packages package/uugamebooster

# ddns-go 动态域名
git_clone https://github.com/sirpdboy/luci-app-ddns-go package/luci-app-ddns-go

# 关机
git_clone https://github.com/sirpdboy/luci-app-poweroffdevice package/luci-app-poweroffdevice

# luci-app-filemanager
git_clone https://github.com/sbwml/luci-app-filemanager package/luci-app-filemanager

# 添加 Turbo ACC 网络加速
# git_clone https://github.com/kiddin9/kwrt-packages package/luci-app-turboacc

# 科学上网插件
git_clone https://github.com/nikkinikki-org/OpenWrt-nikki package/OpenWrt-nikki
git_clone https://github.com/vernesong/OpenClash package/luci-app-openclash
git_clone https://github.com/kiddin9/kwrt-packages package/luci-app-v2ray-server

git_clone https://github.com/jerrykuku/luci-theme-argon

# 更改默认 Shell 为 zsh
sed -i 's/\/bin\/ash/\/usr\/bin\/zsh/g' package/base-files/files/etc/passwd

# TTYD 免登录
sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config

# 设置 root 用户密码为 password
sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.::0:99999:7:::/g' package/base-files/files/etc/shadow

echo
status "菜单 调整..."
sed -i 's|/services/|/control/|' feeds/luci/applications/luci-app-wol/root/usr/share/luci/menu.d/luci-app-wol.json
sed -i 's/services/nas/g' package/luci-app-openlist2/root/usr/share/luci/menu.d/luci-app-openlist2.json
sed -i '/"title": "Nikki",/a \        "order": -9,' package/luci-app-nikki/luci-app-nikki/root/usr/share/luci/menu.d/luci-app-nikki.json
sed -i 's/("OpenClash"), 50)/("OpenClash"), -10)/g' package/luci-app-openclash/luasrc/controller/openclash.lua
sed -i 's/"网络存储"/"存储"/g' `grep "网络存储" -rl ./`
sed -i 's/"软件包"/"软件管理"/g' `grep "软件包" -rl ./`

# 重命名
sed -i 's,UPnP IGD 和 PCP,UPnP,g' feeds/luci/applications/luci-app-upnp/po/zh_Hans/upnp.po
        
status "插件 重命名..."
echo "重命名系统菜单"
#status menu
sed -i 's/"概览"/"系统概览"/g' feeds/luci/modules/luci-base/po/zh_Hans/base.po
sed -i 's/"路由"/"路由映射"/g' feeds/luci/modules/luci-base/po/zh_Hans/base.po
#system menu
sed -i 's/"系统"/"系统设置"/g' feeds/luci/modules/luci-base/po/zh_Hans/base.po
sed -i 's/"管理权"/"权限管理"/g' feeds/luci/modules/luci-base/po/zh_Hans/base.po
sed -i 's/"重启"/"立即重启"/g' feeds/luci/modules/luci-base/po/zh_Hans/base.po
sed -i 's/"备份与升级"/"备份升级"/g' feeds/luci/modules/luci-base/po/zh_Hans/base.po
sed -i 's/"挂载点"/"挂载路径"/g' feeds/luci/modules/luci-base/po/zh_Hans/base.po
sed -i 's/"启动项"/"启动管理"/g' feeds/luci/modules/luci-base/po/zh_Hans/base.po
sed -i 's/"软件包"/"软件管理"/g' feeds/luci/modules/luci-base/po/zh_Hans/base.po
#network
sed -i 's/"接口"/"网络接口"/g' `grep "接口" -rl ./`
sed -i 's/DHCP\/DNS/DNS设定/g' feeds/luci/modules/luci-base/po/zh_Hans/base.po
sed -i 's/"Bandix 流量监控"/"流量监控"/g' package/luci-app-bandix/luci-app-bandix/po/zh_Hans/bandix.po

# 更改 ttyd 顺序和名称
sed -i '3a \		"order": 10,' feeds/luci/applications/luci-app-ttyd/root/usr/share/luci/menu.d/luci-app-ttyd.json
sed -i 's/"终端"/"命令终端"/g' feeds/luci/applications/luci-app-ttyd/po/zh_Hans/ttyd.po

# 调整 V2ray服务器 到 VPN 菜单 (修正路径)
if [ -d "package/luci-app-v2ray-server" ]; then
    sed -i 's/services/vpn/g' package/luci-app-v2ray-server/luasrc/controller/*.lua
    sed -i 's/services/vpn/g' package/luci-app-v2ray-server/luasrc/model/cbi/v2ray_server/*.lua
    sed -i 's/services/vpn/g' package/luci-app-v2ray-server/luasrc/view/v2ray_server/*.htm
fi

# Modify default IP
sed -i 's/192.168.6.1/192.168.50.1/g' package/base-files/files/bin/config_generate

# Modify default theme
#sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Modify hostname
#sed -i 's/OpenWrt/P3TERX-Router/g' package/base-files/files/bin/config_generate

# 添加组播防火墙规则
cat >> package/network/config/firewall/files/firewall.config <<EOF
config rule
        option name 'Allow-UDP-igmpproxy'
        option src 'wan'
        option dest 'lan'
        option dest_ip '224.0.0.0/4'
        option proto 'udp'
        option target 'ACCEPT'        
        option family 'ipv4'

config rule
        option name 'Allow-UDP-udpxy'
        option src 'wan'
        option dest_ip '224.0.0.0/4'
        option proto 'udp'
        option target 'ACCEPT'
EOF

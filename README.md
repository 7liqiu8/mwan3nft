# mwan3nft - Multi-WAN Manager for nftables

mwan3nft 是一个基于 nftables 的多 WAN 负载均衡和故障转移管理器，专为 OpenWrt 设计。

## 特性

- **负载均衡**: 支持按权重分配流量到多个 WAN 接口
- **故障转移**: 自动检测 WAN 接口状态，故障时自动切换
- **策略路由**: 基于源IP、目标IP、端口、协议的灵活路由规则
- **粘性会话**: 支持连接跟踪，保持同一会话使用同一出口
- **IPv4/IPv6**: 同时支持 IPv4 和 IPv6
- **兼容性**: 与 OpenClash、Lucky 等应用兼容，不会相互干扰

## 与 mwan3 的区别

| 特性 | mwan3 | mwan3nft |
|------|-------|----------|
| 防火墙后端 | iptables | nftables |
| OpenWrt 版本 | 所有版本 | 22.03+ (nftables) |
| 与 fw4 兼容 | 需要额外配置 | 原生兼容 |
| 与 OpenClash 兼容 | 可能冲突 | 完全兼容 |

## 系统要求

- OpenWrt 22.03 或更高版本（使用 nftables/fw4）
- 已安装 nftables
- 已安装 ip-full
- 多个 WAN 接口

## 安装

### 从源码编译

1. 将 `mwan3nft` 目录复制到 OpenWrt 源码的 `package/` 目录下
2. 将 `luci-app-mwan3nft` 目录复制到 `package/` 目录下
3. 编译：

```bash
make menuconfig
# 选择 Network -> Routing and Redirection -> mwan3nft
# 选择 LuCI -> Applications -> luci-app-mwan3nft
make package/mwan3nft/compile V=s
make package/luci-app-mwan3nft/compile V=s
```

### 手动安装

将编译好的 ipk 文件上传到路由器并安装：

```bash
opkg install mwan3nft_*.ipk
opkg install luci-app-mwan3nft_*.ipk
```

## 配置

### 通过 LuCI 界面

1. 登录 LuCI 管理界面
2. 进入 **网络 -> MultiWAN NFT**
3. 按照以下顺序配置：
   - **接口**: 添加并配置 WAN 接口
   - **成员**: 创建成员，关联接口与权重
   - **策略**: 创建策略，选择成员
   - **规则**: 创建规则，匹配流量并应用策略

### 通过命令行

编辑 `/etc/config/mwan3nft`:

```
# 全局设置
config globals 'globals'
    option enabled '1'
    option mmx_mask '0x3F00'
    option local_source 'lan'

# 接口配置
config interface 'wan'
    option enabled '1'
    option family 'ipv4'
    option track_ip '223.5.5.5 119.29.29.29'
    option track_method 'ping'
    option reliability '2'
    option interval '10'
    option down '5'
    option up '5'

config interface 'wan2'
    option enabled '1'
    option family 'ipv4'
    option track_ip '223.5.5.5 8.8.8.8'
    option track_method 'ping'
    option reliability '2'
    option interval '10'
    option down '5'
    option up '5'

# 成员配置
config member 'wan_m1_w1'
    option interface 'wan'
    option metric '1'
    option weight '1'

config member 'wan2_m1_w1'
    option interface 'wan2'
    option metric '1'
    option weight '1'

# 策略配置
config policy 'balanced'
    list use_member 'wan_m1_w1'
    list use_member 'wan2_m1_w1'
    option last_resort 'default'

# 规则配置
config rule 'default_rule'
    option dest_ip '0.0.0.0/0'
    option use_policy 'balanced'
    option family 'ipv4'
```

## 命令行工具

```bash
# 启动服务
mwan3nft start

# 停止服务
mwan3nft stop

# 重启服务
mwan3nft restart

# 重载配置
mwan3nft reload

# 查看状态
mwan3nft status

# 查看接口列表
mwan3nft interfaces

# 查看策略列表
mwan3nft policies

# 查看规则列表
mwan3nft rules
```

## 与 OpenClash 兼容

mwan3nft 设计时考虑了与 OpenClash 的兼容性：

1. **自动跳过已标记流量**: mwan3nft 会跳过已经被 OpenClash 标记的流量
2. **排除规则**: 默认配置包含 OpenClash 端口的排除规则

如果需要手动配置排除规则：

```
config rule 'openclash_exclude'
    option proto 'tcp udp'
    option dest_port '7891 7892 7893 9090'
    option use_policy 'default'
    option family 'ipv4'
```

## 与 Lucky 兼容

同样，mwan3nft 也与 Lucky 兼容：

```
config rule 'lucky_exclude'
    option proto 'tcp udp'
    option dest_port '16601'
    option use_policy 'default'
    option family 'ipv4'
```

## 故障排除

### 查看日志

```bash
logread | grep mwan3nft
```

### 查看 nftables 规则

```bash
nft list table inet mwan3nft
```

### 查看路由表

```bash
ip route show table all | grep mwan3
```

### 查看 IP 规则

```bash
ip rule show
```

### 常见问题

1. **接口状态一直显示 offline**
   - 检查 track_ip 是否可达
   - 检查接口是否正确获取到 IP 和网关
   - 尝试手动 ping 测试

2. **流量没有按预期分配**
   - 检查规则顺序，规则按顺序匹配
   - 检查策略中的成员配置
   - 使用 `nft list table inet mwan3nft` 查看实际规则

3. **与其他应用冲突**
   - 添加排除规则，将相关端口设置为 `use_policy 'default'`

## 文件结构

```
mwan3nft/
├── Makefile                          # OpenWrt 包 Makefile
├── files/
│   ├── etc/
│   │   ├── config/mwan3nft          # UCI 配置文件
│   │   ├── init.d/mwan3nft          # 启动脚本
│   │   └── hotplug.d/iface/15-mwan3nft  # 热插拔脚本
│   └── usr/
│       ├── sbin/
│       │   ├── mwan3nft             # 主控制脚本
│       │   └── mwan3nft-track       # 健康检查脚本
│       └── lib/mwan3nft/
│           ├── common.sh            # 公共函数
│           ├── nft.sh               # nftables 规则管理
│           └── policy.sh            # 策略路由管理

luci-app-mwan3nft/
├── Makefile                          # LuCI 应用 Makefile
├── htdocs/luci-static/resources/view/mwan3nft/
│   ├── overview.js                  # 概览页面
│   ├── interface.js                 # 接口配置页面
│   ├── member.js                    # 成员配置页面
│   ├── policy.js                    # 策略配置页面
│   └── rule.js                      # 规则配置页面
├── root/usr/share/
│   ├── luci/menu.d/luci-app-mwan3nft.json  # 菜单配置
│   └── rpcd/acl.d/luci-app-mwan3nft.json   # ACL 配置
└── po/zh_Hans/mwan3nft.po           # 中文翻译
```

## 许可证

GPL-2.0

## 致谢

本项目参考了 OpenWrt 官方的 mwan3 项目设计。

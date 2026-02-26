#!/bin/bash
# mwan3nft 一键部署脚本
# 用法: ./deploy.sh <路由器IP> [SSH端口]
# 示例: ./deploy.sh 192.168.1.1
#        ./deploy.sh 192.168.1.1 22

set -e

ROUTER_IP="$1"
SSH_PORT="${2:-22}"

if [ -z "$ROUTER_IP" ]; then
	read -p "请输入路由器IP地址: " ROUTER_IP
	[ -z "$ROUTER_IP" ] && { echo "错误：必须输入路由器IP"; exit 1; }
	read -p "SSH端口 [默认22]: " input_port
	SSH_PORT="${input_port:-22}"
fi
SSH_OPTS="-o StrictHostKeyChecking=no -p $SSH_PORT"
SCP_OPTS="-o StrictHostKeyChecking=no -P $SSH_PORT"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== mwan3nft 部署到 $ROUTER_IP:$SSH_PORT ==="

# 部署 mwan3nft 核心文件
echo "[1/6] 部署核心脚本..."
scp $SCP_OPTS "$SCRIPT_DIR/files/usr/sbin/mwan3nft" root@$ROUTER_IP:/usr/sbin/mwan3nft
scp $SCP_OPTS "$SCRIPT_DIR/files/usr/sbin/mwan3nft-track" root@$ROUTER_IP:/usr/sbin/mwan3nft-track

echo "[2/6] 部署库文件..."
ssh $SSH_OPTS root@$ROUTER_IP "mkdir -p /usr/lib/mwan3nft"
scp $SCP_OPTS "$SCRIPT_DIR/files/usr/lib/mwan3nft/common.sh" root@$ROUTER_IP:/usr/lib/mwan3nft/common.sh
scp $SCP_OPTS "$SCRIPT_DIR/files/usr/lib/mwan3nft/nft.sh" root@$ROUTER_IP:/usr/lib/mwan3nft/nft.sh
scp $SCP_OPTS "$SCRIPT_DIR/files/usr/lib/mwan3nft/policy.sh" root@$ROUTER_IP:/usr/lib/mwan3nft/policy.sh

echo "[3/6] 部署 init 和 hotplug..."
scp $SCP_OPTS "$SCRIPT_DIR/files/etc/init.d/mwan3nft" root@$ROUTER_IP:/etc/init.d/mwan3nft
ssh $SSH_OPTS root@$ROUTER_IP "mkdir -p /etc/hotplug.d/iface"
scp $SCP_OPTS "$SCRIPT_DIR/files/etc/hotplug.d/iface/15-mwan3nft" root@$ROUTER_IP:/etc/hotplug.d/iface/15-mwan3nft

echo "[4/6] 部署配置文件（不覆盖已有配置）..."
ssh $SSH_OPTS root@$ROUTER_IP "[ -f /etc/config/mwan3nft ] || true" && \
scp $SCP_OPTS "$SCRIPT_DIR/files/etc/config/mwan3nft" root@$ROUTER_IP:/etc/config/mwan3nft 2>/dev/null || \
echo "  配置文件已存在，跳过"

echo "[5/6] 部署 LuCI 文件..."
ssh $SSH_OPTS root@$ROUTER_IP "mkdir -p /www/luci-static/resources/view/mwan3nft /usr/share/rpcd/acl.d /usr/share/luci/menu.d"
scp $SCP_OPTS "$SCRIPT_DIR/luci-app-mwan3nft/htdocs/luci-static/resources/view/mwan3nft/overview.js" root@$ROUTER_IP:/www/luci-static/resources/view/mwan3nft/overview.js
scp $SCP_OPTS "$SCRIPT_DIR/luci-app-mwan3nft/htdocs/luci-static/resources/view/mwan3nft/interface.js" root@$ROUTER_IP:/www/luci-static/resources/view/mwan3nft/interface.js
scp $SCP_OPTS "$SCRIPT_DIR/luci-app-mwan3nft/htdocs/luci-static/resources/view/mwan3nft/member.js" root@$ROUTER_IP:/www/luci-static/resources/view/mwan3nft/member.js
scp $SCP_OPTS "$SCRIPT_DIR/luci-app-mwan3nft/htdocs/luci-static/resources/view/mwan3nft/policy.js" root@$ROUTER_IP:/www/luci-static/resources/view/mwan3nft/policy.js
scp $SCP_OPTS "$SCRIPT_DIR/luci-app-mwan3nft/htdocs/luci-static/resources/view/mwan3nft/rule.js" root@$ROUTER_IP:/www/luci-static/resources/view/mwan3nft/rule.js
scp $SCP_OPTS "$SCRIPT_DIR/luci-app-mwan3nft/root/usr/share/rpcd/acl.d/luci-app-mwan3nft.json" root@$ROUTER_IP:/usr/share/rpcd/acl.d/luci-app-mwan3nft.json
scp $SCP_OPTS "$SCRIPT_DIR/luci-app-mwan3nft/root/usr/share/luci/menu.d/luci-app-mwan3nft.json" root@$ROUTER_IP:/usr/share/luci/menu.d/luci-app-mwan3nft.json

echo "[6/6] 修复权限和换行符，重启服务..."
ssh $SSH_OPTS root@$ROUTER_IP << 'REMOTECMD'
# 修复 CRLF
sed -i 's/\r$//' /usr/sbin/mwan3nft /usr/sbin/mwan3nft-track /etc/init.d/mwan3nft \
  /etc/hotplug.d/iface/15-mwan3nft /usr/lib/mwan3nft/*.sh /etc/config/mwan3nft

# 修复权限
chmod 755 /usr/sbin/mwan3nft /usr/sbin/mwan3nft-track /etc/init.d/mwan3nft
chmod 644 /usr/lib/mwan3nft/*.sh /etc/hotplug.d/iface/15-mwan3nft
chmod 600 /etc/config/mwan3nft

# 启用服务
/etc/init.d/mwan3nft enable 2>/dev/null || true

# 重启相关服务
/etc/init.d/rpcd restart
rm -rf /tmp/luci-*
/etc/init.d/mwan3nft restart

echo "部署完成！"
REMOTECMD

echo ""
echo "=== 部署成功！==="
echo "请访问 http://$ROUTER_IP/cgi-bin/luci/admin/network/mwan3nft 查看"

@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

echo === mwan3nft 一键部署脚本 (Windows) ===
echo.

set "ROUTER_IP=%~1"
set "SSH_PORT=%~2"

if "%ROUTER_IP%"=="" (
    set /p "ROUTER_IP=请输入路由器IP地址: "
)
if "%ROUTER_IP%"=="" (
    echo 错误：必须输入路由器IP
    exit /b 1
)
if "%SSH_PORT%"=="" (
    set /p "SSH_PORT=SSH端口 [默认22]: "
)
if "%SSH_PORT%"=="" set "SSH_PORT=22"

set "SCRIPT_DIR=%~dp0"
set "SSH_OPTS=-o StrictHostKeyChecking=no -p %SSH_PORT%"
set "SCP_OPTS=-o StrictHostKeyChecking=no -P %SSH_PORT%"

echo 部署到 %ROUTER_IP%:%SSH_PORT%
echo.

echo [1/6] 部署核心脚本...
scp %SCP_OPTS% "%SCRIPT_DIR%files\usr\sbin\mwan3nft" root@%ROUTER_IP%:/usr/sbin/mwan3nft
scp %SCP_OPTS% "%SCRIPT_DIR%files\usr\sbin\mwan3nft-track" root@%ROUTER_IP%:/usr/sbin/mwan3nft-track

echo [2/6] 部署库文件...
ssh %SSH_OPTS% root@%ROUTER_IP% "mkdir -p /usr/lib/mwan3nft"
scp %SCP_OPTS% "%SCRIPT_DIR%files\usr\lib\mwan3nft\common.sh" root@%ROUTER_IP%:/usr/lib/mwan3nft/common.sh
scp %SCP_OPTS% "%SCRIPT_DIR%files\usr\lib\mwan3nft\nft.sh" root@%ROUTER_IP%:/usr/lib/mwan3nft/nft.sh
scp %SCP_OPTS% "%SCRIPT_DIR%files\usr\lib\mwan3nft\policy.sh" root@%ROUTER_IP%:/usr/lib/mwan3nft/policy.sh

echo [3/6] 部署 init 和 hotplug...
scp %SCP_OPTS% "%SCRIPT_DIR%files\etc\init.d\mwan3nft" root@%ROUTER_IP%:/etc/init.d/mwan3nft
ssh %SSH_OPTS% root@%ROUTER_IP% "mkdir -p /etc/hotplug.d/iface"
scp %SCP_OPTS% "%SCRIPT_DIR%files\etc\hotplug.d\iface\15-mwan3nft" root@%ROUTER_IP%:/etc/hotplug.d/iface/15-mwan3nft

echo [4/6] 部署配置文件...
scp %SCP_OPTS% "%SCRIPT_DIR%files\etc\config\mwan3nft" root@%ROUTER_IP%:/etc/config/mwan3nft

echo [5/6] 部署 LuCI 文件...
ssh %SSH_OPTS% root@%ROUTER_IP% "mkdir -p /www/luci-static/resources/view/mwan3nft /usr/share/rpcd/acl.d /usr/share/luci/menu.d"
scp %SCP_OPTS% "%SCRIPT_DIR%luci-app-mwan3nft\htdocs\luci-static\resources\view\mwan3nft\overview.js" root@%ROUTER_IP%:/www/luci-static/resources/view/mwan3nft/overview.js
scp %SCP_OPTS% "%SCRIPT_DIR%luci-app-mwan3nft\htdocs\luci-static\resources\view\mwan3nft\interface.js" root@%ROUTER_IP%:/www/luci-static/resources/view/mwan3nft/interface.js
scp %SCP_OPTS% "%SCRIPT_DIR%luci-app-mwan3nft\htdocs\luci-static\resources\view\mwan3nft\member.js" root@%ROUTER_IP%:/www/luci-static/resources/view/mwan3nft/member.js
scp %SCP_OPTS% "%SCRIPT_DIR%luci-app-mwan3nft\htdocs\luci-static\resources\view\mwan3nft\policy.js" root@%ROUTER_IP%:/www/luci-static/resources/view/mwan3nft/policy.js
scp %SCP_OPTS% "%SCRIPT_DIR%luci-app-mwan3nft\htdocs\luci-static\resources\view\mwan3nft\rule.js" root@%ROUTER_IP%:/www/luci-static/resources/view/mwan3nft/rule.js
scp %SCP_OPTS% "%SCRIPT_DIR%luci-app-mwan3nft\root\usr\share\rpcd\acl.d\luci-app-mwan3nft.json" root@%ROUTER_IP%:/usr/share/rpcd/acl.d/luci-app-mwan3nft.json
scp %SCP_OPTS% "%SCRIPT_DIR%luci-app-mwan3nft\root\usr\share\luci\menu.d\luci-app-mwan3nft.json" root@%ROUTER_IP%:/usr/share/luci/menu.d/luci-app-mwan3nft.json

echo [6/6] 修复权限和换行符，重启服务...
ssh %SSH_OPTS% root@%ROUTER_IP% "sed -i 's/\r$//' /usr/sbin/mwan3nft /usr/sbin/mwan3nft-track /etc/init.d/mwan3nft /etc/hotplug.d/iface/15-mwan3nft /usr/lib/mwan3nft/*.sh /etc/config/mwan3nft && chmod 755 /usr/sbin/mwan3nft /usr/sbin/mwan3nft-track /etc/init.d/mwan3nft && chmod 644 /usr/lib/mwan3nft/*.sh /etc/hotplug.d/iface/15-mwan3nft && chmod 600 /etc/config/mwan3nft && /etc/init.d/mwan3nft enable 2>/dev/null; /etc/init.d/rpcd restart && rm -rf /tmp/luci-* && /etc/init.d/mwan3nft restart && echo 部署完成"

echo.
echo === 部署成功！===
echo 请访问 http://%ROUTER_IP%/cgi-bin/luci/admin/network/mwan3nft 查看
pause

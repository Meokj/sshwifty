#!/usr/bin/env bash
set -e

INSTALL_DIR="/opt/sshwifty"
SERVICE_NAME="sshwifty"

echo "🛑 停止并禁用 systemd 服务..."
if systemctl is-active --quiet ${SERVICE_NAME}; then
    systemctl stop ${SERVICE_NAME}
fi

if systemctl is-enabled --quiet ${SERVICE_NAME}; then
    systemctl disable ${SERVICE_NAME}
fi

echo "🗑️ 删除 systemd 服务文件..."
if [ -f /etc/systemd/system/${SERVICE_NAME}.service ]; then
    rm -f /etc/systemd/system/${SERVICE_NAME}.service
    systemctl daemon-reload
fi

echo "🗑️ 删除安装目录..."
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
fi

echo "✅ sshwifty 卸载完成"

echo "⚠️ 注意："
echo "如果你为 sshwifty 配置了 Nginx 反向代理，需要手动删除对应 Nginx 配置文件"
echo "并重载 Nginx：systemctl reload nginx"

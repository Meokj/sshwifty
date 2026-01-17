#!/usr/bin/env bash
set -e

INSTALL_DIR="/opt/sshwifty"
PORT="8182"
SERVICE_NAME="sshwifty"

if [ "$(id -u)" != "0" ]; then
    echo "请使用 root 用户运行"
    exit 1
fi

if ss -tuln | grep -q ":${PORT} "; then
    echo "端口 ${PORT} 已被占用，请先释放或修改 PORT 后再运行"
    exit 1
fi
echo "端口 ${PORT} 可用"

while true; do
    read -p "请输入访问 sshwifty 的域名（例如 ssh.example.com）: " DOMAIN
    if [ -z "$DOMAIN" ]; then
        echo "域名不能为空"
        continue
    fi
    if [[ "$DOMAIN" =~ / ]]; then
        echo "域名不能包含路径"
        continue
    fi
    break
done
echo "域名设置为: $DOMAIN"

while true; do
    read -s -p "请输入 sshwifty SharedKey（至少8位）: " PASS1
    echo
    read -s -p "请再次确认 SharedKey: " PASS2
    echo
    if [ -z "$PASS1" ]; then
        echo "密码不能为空"
        continue
    fi
    if [ "$PASS1" != "$PASS2" ]; then
        echo "两次输入不一致，请重试"
        continue
    fi
    if [ "${#PASS1}" -lt 8 ]; then
        echo "密码长度至少8位"
        continue
    fi
    SHARED_KEY="$PASS1"
    break
done
echo "SharedKey 设置完成"

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH_TAG="amd64";;
    i386|i686) ARCH_TAG="386";;
    armv7*|armv6*) ARCH_TAG="arm";;
    aarch64) ARCH_TAG="arm64";;
    *) echo "未知架构: $ARCH"; exit 1;;
esac
echo "检测架构: $ARCH ($ARCH_TAG)"

URL=$(curl -s https://api.github.com/repos/nirui/sshwifty/releases/latest \
      | grep browser_download_url \
      | grep linux \
      | grep "$ARCH_TAG" \
      | head -n1 \
      | cut -d '"' -f4)

if [ -z "$URL" ]; then
    echo "未找到符合系统架构的 release 文件"
    exit 1
fi
echo "下载 URL: $URL"

FILENAME=$(basename "$URL")
curl -L "$URL" -o "$FILENAME"

tar -xzf "$FILENAME"

EXEC_FILE=$(ls | grep -i 'sshwifty.*'"$ARCH_TAG"'\|sshwifty$' | head -n1)
if [ -z "$EXEC_FILE" ]; then
    echo "解压后未找到可执行文件"
    exit 1
fi

mv "$EXEC_FILE" sshwifty
chmod +x sshwifty

cat > "$INSTALL_DIR/config.json" <<EOF
{
  "HostName": "${DOMAIN}",
  "SharedKey": "${SHARED_KEY}",
  "Servers": [
    {
      "ListenInterface": "127.0.0.1",
      "ListenPort": ${PORT}
    }
  ]
}
EOF
chmod 600 "$INSTALL_DIR/config.json"
echo "配置文件生成完成"

cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=sshwifty Web SSH
After=network.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
Environment=SSHWIFTY_CONFIG=${INSTALL_DIR}/config.json
ExecStart=${INSTALL_DIR}/sshwifty
Restart=always
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now ${SERVICE_NAME}

sleep 2

if systemctl is-active --quiet ${SERVICE_NAME}; then
    echo "-------------------------------"
    echo "🎉 sshwifty 安装完成并启动,服务正在运行"
    echo "访问地址: https://${DOMAIN}"
    echo "监听端口: 127.0.0.1:${PORT}"
    echo "请确保 Nginx 已正确反向代理"
   echo "-------------------------------"
else
    echo "sshwifty 服务未能启动，请检查日志：journalctl -u ${SERVICE_NAME} -f"
    exit 1
fi

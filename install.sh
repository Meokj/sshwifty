#!/usr/bin/env bash
set -e

INSTALL_DIR="/opt/sshwifty"
PORT="8182"

if [ "$(id -u)" != "0" ]; then
  echo "请使用 root 用户运行"
  exit 1
fi

if ss -tuln | grep -q ":${PORT} "; then
  echo "端口 ${PORT} 已被占用，请先释放后再运行"
  exit 1
fi

echo "✅ 端口 ${PORT} 可用"

while true; do
  read -p "请输入访问 sshwifty 使用的二级域名（如 ssh.example.com）: " DOMAIN

  if [ -z "$DOMAIN" ]; then
    echo "名不能为空"
    continue
  fi

  if [[ "$DOMAIN" =~ / ]]; then
    echo "域名不能包含路径"
    continue
  fi

  break
done

echo "✅ 域名设置为: $DOMAIN"

while true; do
  read -s -p "请设置 sshwifty SharedKey: " PASS1
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
    echo "密码长度至少 8 位"
    continue
  fi

  SHARED_KEY="$PASS1"
  break
done

echo "✅ SharedKey 设置完成"

mkdir -p ${INSTALL_DIR}
cd ${INSTALL_DIR}

echo "📥 下载 sshwifty..."
URL=$(curl -s https://api.github.com/repos/nirui/sshwifty/releases/latest \
  | grep browser_download_url \
  | grep linux \
  | head -n1 \
  | cut -d '"' -f4)

curl -L ${URL} -o sshwifty.tar.gz
tar -xzf sshwifty.tar.gz
rm -f sshwifty.tar.gz
chmod +x sshwifty

echo "📝 生成配置文件..."
cat > ${INSTALL_DIR}/config.json <<EOF
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

chmod 600 ${INSTALL_DIR}/config.json

echo "⚙️ 创建 systemd 服务..."
cat > /etc/systemd/system/sshwifty.service <<EOF
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
systemctl enable --now sshwifty

echo "--------------------------------------"
echo "🎉 sshwifty 安装完成"
echo "访问地址: https://${DOMAIN}"
echo "监听地址: 127.0.0.1:${PORT}"
echo "请确保 Nginx 已正确反向代理"
echo "--------------------------------------"

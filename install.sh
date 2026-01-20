#!/usr/bin/env bash
set -e

INSTALL_DIR="/opt/sshwifty"
PORT="8182"
SERVICE_NAME="sshwifty"
CONFIG_FILE="${INSTALL_DIR}/config.json"

ACTION="$1"

if [ "$(id -u)" != "0" ]; then
	echo "请使用 root 用户运行"
	exit 1
fi

stall_dependencies() {
    echo "检查并安装必要依赖: tar, curl, ss"

    MISSING=()
    for CMD in tar curl ss; do
        if ! command -v "$CMD" >/dev/null 2>&1; then
            MISSING+=("$CMD")
        fi
    done

    if [ "${#MISSING[@]}" -eq 0 ]; then
        return
    fi

    echo "缺少依赖: ${MISSING[*]}"

    if [ -f /etc/debian_version ]; then
        echo "检测到 Debian/Ubuntu 系统，使用 apt 安装"
        apt update
        apt install -y "${MISSING[@]}"
    elif [ -f /etc/redhat-release ]; then
        echo "检测到 RHEL/CentOS 系统，使用 yum 安装"
        yum install -y "${MISSING[@]}"
    else
        echo "未能自动识别系统类型，请手动安装: ${MISSING[*]}"
        exit 1
    fi
}

install_sshwifty() {
	if ss -tuln | grep -q ":${PORT} "; then
		echo "端口 ${PORT} 已被占用，请先释放或修改 PORT 后再运行"
		exit 1
	fi
	echo "端口 ${PORT} 可用"

	while true; do
		read -p "请输入访问 sshwifty 的域名，例如 ssh.example.com: " DOMAIN
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
		read -s -p "请输入 sshwifty SharedKey: " PASS1
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
	chmod 755 "$INSTALL_DIR"
	cd "$INSTALL_DIR" || {
		echo "无法进入目录 $INSTALL_DIR"
		exit 1
	}

	ARCH=$(uname -m)
	case "$ARCH" in
	x86_64) ARCH_TAG="amd64" ;;
	i386 | i686) ARCH_TAG="386" ;;
	armv7* | armv6*) ARCH_TAG="arm" ;;
	aarch64) ARCH_TAG="arm64" ;;
	*)
		echo "未知架构: $ARCH"
		exit 1
		;;
	esac
	echo "检测架构: $ARCH ($ARCH_TAG)"

	URL=$(curl -s https://api.github.com/repos/nirui/sshwifty/releases/latest |
		grep browser_download_url |
		grep linux |
		grep "$ARCH_TAG" |
		head -n1 |
		cut -d '"' -f4)

	if [ -z "$URL" ]; then
		echo "未找到符合系统架构的 release 文件"
		exit 1
	fi
	echo "下载 URL: $URL"

	FILENAME=$(basename "$URL")
	curl -L "$URL" -o "$FILENAME"

	FILETYPE=$(file "$FILENAME")
	if echo "$FILETYPE" | grep -q "tar archive"; then
		echo "解压 tar.gz 压缩包"
		tar -xzf "$FILENAME" && rm -f "$FILENAME"
		
		TARFILE=$(find . -maxdepth 1 -type f -name "*.tar" | head -n1)
    	if [ -n "$TARFILE" ]; then
        	echo "再次解压 tar 文件: $TARFILE"
        	tar -xf "$TARFILE" && rm -f "$TARFILE"
    	fi
	else
		echo "下载的文件不是 tar.gz 压缩包"
		exit 1
	fi

	EXEC_FILE=$(find . -maxdepth 1 -type f -executable | head -n1)

	if [ -z "$EXEC_FILE" ]; then
		echo "解压后未找到可执行文件"
		exit 1
	fi

	mv "$EXEC_FILE" sshwifty
	chmod +x sshwifty
	echo "可执行文件已准备好 $INSTALL_DIR/sshwifty"

	cat >"$INSTALL_DIR/config.json" <<EOF
{
  "HostName": "${DOMAIN}",
  "SharedKey": "${SHARED_KEY}",
  "Servers": [
    {
      "ListenInterface": "127.0.0.1",
      "ListenPort": ${PORT},
	  "ReadTimeout": 120,
      "WriteTimeout": 120,
      "HeartbeatTimeout": 10
    }
  ]
}
EOF
	chmod 600 "$INSTALL_DIR/config.json"
	echo "配置文件生成完成"

	cat >/etc/systemd/system/${SERVICE_NAME}.service <<EOF
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
		echo "======================================"
		echo "sshwifty 安装完成并已启动"
		echo
		echo "访问地址: https://${DOMAIN}"
		echo "监听端口: 127.0.0.1:${PORT}"
		echo
		echo "sshwifty 登录信息："
		echo "  登录密码 (SharedKey): ${SHARED_KEY}"
		echo "  配置文件路径: ${INSTALL_DIR}/config.json"
		echo
		echo "请确保 Nginx 已正确配置反向代理"
		echo "======================================"
	else
		echo "sshwifty 服务未能启动"
		echo "请检查日志：journalctl -u ${SERVICE_NAME} -f"
		exit 1
	fi
}

change_password() {
	if [ ! -f "$CONFIG_FILE" ]; then
		echo "未找到配置文件：$CONFIG_FILE"
		echo "请先执行：$0 install"
		exit 1
	fi

	while true; do
		read -s -p "请输入新的 SharedKey: " PASS1
		echo
		read -s -p "请再次确认 SharedKey: " PASS2
		echo

		if [ -z "$PASS1" ]; then
			echo "密码不能为空"
			continue
		fi
		if [ "$PASS1" != "$PASS2" ]; then
			echo "两次输入不一致"
			continue
		fi
		if [ "${#PASS1}" -lt 8 ]; then
			echo "密码长度至少8位"
			continue
		fi
		break
	done

	cp "$CONFIG_FILE" "${CONFIG_FILE}.bak.$(date +%F_%T)"
	sed -i "s/\"SharedKey\": \".*\"/\"SharedKey\": \"${PASS1}\"/" "$CONFIG_FILE"
	systemctl restart ${SERVICE_NAME}

	if systemctl is-active --quiet ${SERVICE_NAME}; then
		echo "======================================"
		echo "SharedKey 修改成功"
		echo "新的 SharedKey: ${PASS1}"
		echo "配置文件: ${CONFIG_FILE}"
		echo "======================================"
	else
		echo "服务重启失败，请检查日志："
		echo "journalctl -u ${SERVICE_NAME} -f"
		exit 1
	fi
}

case "$ACTION" in
install)
	install_sshwifty
	;;
passwd | password | changepass)
	change_password
	;;
*)
	echo "用法："
	echo "  $0 install   安装 sshwifty"
	echo "  $0 passwd    修改登录密码"
	exit 1
	;;
esac

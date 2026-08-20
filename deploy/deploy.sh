#!/bin/sh
# Nezha Alpine 一键部署脚本（自包含，适用于目标 Alpine 主机）
# 用法:
#   sh deploy.sh                 # 只安装 dashboard
#   sh deploy.sh <agent_secret>  # 安装 dashboard + agent（secret 在面板【服务器】生成）
# 下载: wget -qO deploy.sh https://github.com/linseeee/nezha-alpine/releases/download/alpine/deploy.sh
set -e

BASE_URL="https://github.com/linseeee/nezha-alpine/releases/download/alpine"
DASH_DIR="/opt/nezha/dashboard"
AGENT_DIR="/opt/nezha-agent"

if [ "$(id -u)" != "0" ]; then
    echo "错误: 需要 root 权限" >&2
    exit 1
fi

install_dashboard() {
    echo "==> 下载 dashboard (musl static)"
    mkdir -p "$DASH_DIR/data"
    wget -q -O "$DASH_DIR/dashboard" "$BASE_URL/dashboard-linux-amd64"
    chmod +x "$DASH_DIR/dashboard"

    echo "==> 写入配置 $DASH_DIR/data/config.yaml"
    cat > "$DASH_DIR/data/config.yaml" <<'YAML'
debug: false
listen_host: "0.0.0.0"
listen_port: 8008
language: zh-CN
location: Asia/Shanghai
site_name: "Nezha"
force_auth: true
YAML

    echo "==> 安装 OpenRC 服务"
    cat > /etc/init.d/nezha-dashboard <<'EOF'
#!/sbin/openrc-run
name="nezha-dashboard"
description="Nezha Monitoring Dashboard"
command="/opt/nezha/dashboard/dashboard"
command_args="-c /opt/nezha/dashboard/data/config.yaml"
command_background="yes"
pidfile="/run/${RC_SVCNAME}.pid"
directory="/opt/nezha/dashboard"
output_log="/var/log/nezha-dashboard.log"
error_log="/var/log/nezha-dashboard.err"
depend() { need net; after firewall; }
EOF
    chmod +x /etc/init.d/nezha-dashboard
    rc-update add nezha-dashboard default >/dev/null 2>&1 || true
    rc-service nezha-dashboard start 2>/dev/null || echo "（启动失败请查看 /var/log/nezha-dashboard.err）"
}

install_agent() {
    SECRET="$1"
    [ -n "$SECRET" ] || { echo "错误: 缺少 agent secret" >&2; exit 1; }

    echo "==> 下载 agent (pure static)"
    mkdir -p "$AGENT_DIR"
    wget -q -O "$AGENT_DIR/nezha-agent" "$BASE_URL/nezha-agent-linux-amd64"
    chmod +x "$AGENT_DIR/nezha-agent"

    echo "==> 写入配置 $AGENT_DIR/config.yml"
    cat > "$AGENT_DIR/config.yml" <<YAML
server: 127.0.0.1:5555
client_secret: "$SECRET"
tls: false
disable_auto_update: true
disable_command_execute: true
skip_connection_count: true
skip_procs_count: true
report_delay: 5
YAML

    echo "==> 安装 OpenRC 服务"
    cat > /etc/init.d/nezha-agent <<'EOF'
#!/sbin/openrc-run
name="nezha-agent"
description="Nezha Monitoring Agent"
command="/opt/nezha-agent/nezha-agent"
command_background="yes"
pidfile="/run/${RC_SVCNAME}.pid"
directory="/opt/nezha-agent"
output_log="/var/log/nezha-agent.log"
error_log="/var/log/nezha-agent.err"
depend() { need net; after firewall; }
EOF
    chmod +x /etc/init.d/nezha-agent
    rc-update add nezha-agent default >/dev/null 2>&1 || true
    rc-service nezha-agent start 2>/dev/null || echo "（启动失败请查看 /var/log/nezha-agent.err）"
}

if [ "$#" -ge 1 ]; then
    install_dashboard
    install_agent "$1"
    echo "==> 完成。dashboard: http://<host>:8008（首次登录 admin/admin，请立即改密）"
else
    install_dashboard
    echo "==> 完成。dashboard: http://<host>:8008（首次登录 admin/admin，请立即改密）"
    echo "    需要 agent 时再执行: sh deploy.sh <agent_secret>"
fi

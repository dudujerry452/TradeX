#!/usr/bin/env bash

dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

cd ${dir}/../

source .venv/bin/activate || true

ENVIR=$(cat deploy-config.json | jq -r '.environment')

# 从配置读取端口
HTTP_PORT=${1:-8000}
WS_PORT=${2:-8001}

echo "=========================================="
echo "  TradeX 后端服务启动"
echo "=========================================="
echo "环境: $ENVIR"
echo "HTTP API: http://0.0.0.0:$HTTP_PORT"
echo "WebSocket: ws://0.0.0.0:$WS_PORT"
echo "=========================================="

# 启动 Daphne WebSocket 服务 (后台)
echo "[1/2] 启动 WebSocket 服务 (Daphne)..."
DJANGO_ENV=$ENVIR daphne -b 0.0.0.0 -p $WS_PORT tradeX.asgi:application &
DAPHNE_PID=$!
echo "WebSocket PID: $DAPHNE_PID"

# 等待 Daphne 启动
sleep 2

# 启动 Django HTTP 服务 (前台)
echo "[2/2] 启动 HTTP API 服务 (Django)..."
echo ""
echo "按 Ctrl+C 停止所有服务"
echo ""

# 捕获退出信号，清理 Daphne 进程
cleanup() {
    echo ""
    echo "正在停止服务..."
    kill $DAPHNE_PID 2>/dev/null || true
    exit 0
}
trap cleanup INT TERM

DJANGO_ENV=$ENVIR python3 backend/manage.py runserver 0.0.0.0:$HTTP_PORT

#!/usr/bin/env bash
# script/start-dev.sh — 启动开发环境（双端口模式）
#
# 端口说明：
# - 8000: Django HTTP (REST API)
# - 8001: Daphne WebSocket
#
# 使用方法：
#   ./script/start-dev.sh
#
# 停止服务：
#   Ctrl+C

set -e

dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd ${dir}/../backend

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=======================================${NC}"
echo -e "${GREEN}  TradeX WebSocket 开发环境启动脚本    ${NC}"
echo -e "${GREEN}=======================================${NC}"
echo ""

# 检查 Python 环境
if ! command -v python &> /dev/null; then
    echo -e "${RED}错误: 未找到 Python${NC}"
    exit 1
fi

# 检查依赖
echo -e "${YELLOW}检查依赖...${NC}"
if ! python -c "import channels" 2>/dev/null; then
    echo -e "${YELLOW}安装 WebSocket 依赖...${NC}"
    pip install -q channels daphne channels-redis
fi

# 数据库迁移
echo -e "${YELLOW}检查数据库迁移...${NC}"
python manage.py migrate --run-syncdb

echo ""
echo -e "${GREEN}启动服务...${NC}"
echo ""

# 启动 Django HTTP (端口 8000)
echo -e "${GREEN}[1/2] 启动 Django HTTP 服务器 (端口 8000)${NC}"
python manage.py runserver 0.0.0.0:8000 &
DJANGO_PID=$!

# 等待 Django 启动
sleep 2

# 启动 Daphne WebSocket (端口 8001)
echo -e "${GREEN}[2/2] 启动 Daphne WebSocket 服务器 (端口 8001)${NC}"
daphne -b 0.0.0.0 -p 8001 tradeX.asgi:application &
DAPHNE_PID=$!

echo ""
echo -e "${GREEN}=======================================${NC}"
echo -e "${GREEN}  服务已启动!                          ${NC}"
echo -e "${GREEN}=======================================${NC}"
echo ""
echo -e "  ${YELLOW}Django HTTP:${NC}   http://localhost:8000"
echo -e "  ${YELLOW}WebSocket:${NC}     ws://localhost:8001/ws/chat/"
echo -e "  ${YELLOW}API 文档:${NC}       http://localhost:8000/api/docs"
echo ""
echo -e "  ${YELLOW}进程 PID:${NC}      Django=$DJANGO_PID, Daphne=$DAPHNE_PID"
echo ""
echo -e "  按 ${YELLOW}Ctrl+C${NC} 停止所有服务"
echo ""

# 优雅关闭处理
cleanup() {
    echo ""
    echo -e "${YELLOW}正在停止服务...${NC}"
    kill $DAPHNE_PID 2>/dev/null || true
    kill $DJANGO_PID 2>/dev/null || true
    wait
    echo -e "${GREEN}服务已停止${NC}"
    exit 0
}

trap cleanup INT TERM

# 保持脚本运行
wait

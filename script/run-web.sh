#!/usr/bin/env bash
# 从 deploy-config.json 读取配置并运行 Flutter Web

dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

cd ${dir}/../mobile || exit 1

API_URL=$(cat ../deploy-config.json | jq -r '.api_base_url')
WS_URL=$(cat ../deploy-config.json | jq -r '.ws_url')

echo "启动 Flutter Web..."
echo "API地址: $API_URL"
echo "WebSocket地址: $WS_URL"

flutter run -d chrome --dart-define=API_BASE_URL="$API_URL" --dart-define=WS_URL="$WS_URL"

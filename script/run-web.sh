#!/bin/bash
# 从 deploy-config.json 读取配置并运行 Flutter Web

cd "$(dirname "$0")/mobile" || exit 1

API_URL=$(cat ../deploy-config.json | jq -r '.api_base_url')

echo "启动 Flutter Web..."
echo "API地址: $API_URL"

flutter run -d chrome --dart-define=API_BASE_URL="$API_URL"

#!/usr/bin/env bash

dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
now=$(date +"%Y%m%d%H%M%S")

cd ${dir}/../

# 1. 切换 development 配置
bash script/switch-config.sh development

# 2. 读取 deploy-config.json 中的 API 和 WS 地址
API_BASE_URL=$(python3 -c "import json; print(json.load(open('deploy-config.json'))['api_base_url'])")
WS_URL=$(python3 -c "import json; print(json.load(open('deploy-config.json'))['ws_url'])")

echo "Building Flutter Web..."
echo "  API_BASE_URL=${API_BASE_URL}"
echo "  WS_URL=${WS_URL}"

# 3. 构建 Flutter Web
cd mobile
flutter build web --release \
  --dart-define=API_BASE_URL="${API_BASE_URL}" \
  --dart-define=WS_URL="${WS_URL}"

# 4. 打包构建产物
cd build
tar zcf web_${now}.tar.gz ./web

# 5. 上传并清理本地压缩包
cd ${dir}/../
scp mobile/build/web_${now}.tar.gz cloud:~/
rm mobile/build/web_${now}.tar.gz

# 6. 远程部署（假定 nginx 已配置好并监听 7005）
ssh -T cloud << EOF
  cd ~
  rm -rf web
  tar xzf web_${now}.tar.gz
  sudo rm -rf /var/www/tradex-web
  sudo mv web /var/www/tradex-web
  sudo chown -R www-data:www-data /var/www/tradex-web
  sudo chmod -R 755 /var/www/tradex-web
  rm -rf web
  rm -f web_${now}.tar.gz
  sudo systemctl reload nginx
EOF

echo "Deploy finished: http://47.104.69.18:7005"

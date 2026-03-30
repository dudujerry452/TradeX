#!/bin/bash
# TradeX 本地打包脚本
# 读取 deploy-config.json 配置，本地构建 APK

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/mobile"

# 读取配置
API_URL=$(cat ../deploy-config.json | jq -r '.api_base_url')
FLUTTER_VERSION=$(cat ../deploy-config.json | jq -r '.flutter_version')
ENVIRONMENT=$(cat ../deploy-config.json | jq -r '.environment')

echo "=== TradeX 本地构建 ==="
echo "环境: $ENVIRONMENT"
echo "API地址: $API_URL"
echo "Flutter版本: $FLUTTER_VERSION"
echo ""

# 检查 flutter
if ! command -v flutter &> /dev/null; then
    echo "错误: 未找到 flutter 命令"
    exit 1
fi

# 获取依赖
echo "==> 获取依赖..."
flutter pub get

# 构建 APK
echo ""
echo "==> 构建 APK..."
flutter build apk --release --dart-define=API_BASE_URL="$API_URL"

# 显示结果
echo ""
echo "=== 构建完成 ==="
ls -lh build/app/outputs/flutter-apk/app-release.apk

# 复制到根目录方便找到
cp build/app/outputs/flutter-apk/app-release.apk ../tradex-$ENVIRONMENT.apk
echo ""
echo "APK已复制到: tradex-$ENVIRONMENT.apk"
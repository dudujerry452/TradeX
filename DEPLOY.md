# TradeX 部署配置

## 统一配置文件

所有配置集中在 `deploy-config.json`：

```json
{
  "_comment": "TradeX 统一配置文件, 请使用./script/switch-config.sh切换",
  "_environment_help": "local=本地开发, development=远程开发(CORS宽松), production=生产",
  "environment": "local",
  "api_base_url": "http://localhost:8000/api",
  "ws_url": "ws://localhost:8001",
  "flutter_version": "3.41.2"
}
```

## 环境说明

- `local`：本地开发（前后端都在本地，CORS 最宽松）
- `development`：远程开发（前端 localhost → 远程后端，CORS 宽松）
- `production`：生产环境（严格配置）

## 使用方法

### 1. 切换配置

使用脚本快速切换环境：

```bash
./script/switch-config.sh local
./script/switch-config.sh development
./script/switch-config.sh production
```

### 2. 启动后端服务

开发环境（双端口：HTTP + WebSocket）：

```bash
./script/start-dev.sh
```

或手动指定端口：

```bash
./script/run-backend.sh 8000 8001
```

### 3. 本地打包 APK

```bash
./script/deploy.sh
```

APK 将输出到 `tradex-<environment>.apk`

### 4. 后端手动部署

配置从 `.env.${DJANGO_ENV}` 读取，默认回退到 `.env.local`：

```bash
cd backend
export DJANGO_ENV=production
# 编辑 .env.production 填入配置
python manage.py migrate
python manage.py collectstatic --noinput
```

生产环境建议用 Gunicorn + Daphne 分别启动 HTTP 与 WebSocket：

```bash
# WebSocket
daphne -b 0.0.0.0 -p 8001 tradeX.asgi:application &

# HTTP
gunicorn tradeX.wsgi:application -b 0.0.0.0:8000
```

## 多环境配置示例

本地开发：

```bash
./script/switch-config.sh local
./script/start-dev.sh
```

Android 模拟器：

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

iOS 模拟器：

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

## GitHub Actions 打包

手动触发：Actions → Build Flutter APK → Run workflow

自动读取 `deploy-config.json` 配置。

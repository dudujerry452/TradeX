# TradeX 部署配置

## 统一配置文件

所有配置集中在 `deploy-config.json`：

```json
{
  "environment": "production",
  "api_base_url": "https://api.yourdomain.com/api",
  "flutter_version": "3.22.0"
}
```

## 使用方法

### 1. 修改配置

编辑 `deploy-config.json`，填入你的域名：

```json
"api_base_url": "https://api.example.com/api"
```

### 2. 本地打包 APK

```bash
./build-apk.sh
```

APK 将输出到 `tradex-production.apk`

### 3. 后端部署

手动部署，配置从 `.env` 读取：

```bash
cd backend
cp .env.example .env
# 编辑 .env 填入配置
python manage.py runserver
```

## 多环境配置

支持的环境变量值：`development`, `staging`, `production`

本地开发示例：

```bash
# Android 模拟器
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api

# iOS 模拟器
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

## GitHub Actions 打包

手动触发：Actions → Build Flutter APK → Run workflow

自动读取 `deploy-config.json` 配置。

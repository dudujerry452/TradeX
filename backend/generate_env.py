#!/usr/bin/env python3
"""
将 deploy-config.json 转换为 .env 文件
支持三个级别: local / development / production
"""

import argparse
import json
import re
from pathlib import Path
from datetime import datetime


def parse_url(url: str) -> str:
    """从 URL 提取主机名"""
    match = re.match(r'https?://([^:/]+)', url)
    return match.group(1) if match else 'localhost'


def parse_port(url: str) -> str:
    """从 URL 提取端口"""
    match = re.match(r'https?://[^:/]+:(\d+)', url)
    return match.group(1) if match else '8000'


def generate_secret_key() -> str:
    """生成随机 SECRET_KEY"""
    import secrets
    return f"django-insecure-{secrets.token_urlsafe(50)}"


def get_config_for_environment(env: str, api_url: str) -> dict:
    """
    根据环境返回配置
    local: 本地开发，前后端都在本地
    development: 远程开发，前端连远程后端，CORS宽松
    production: 生产环境，严格配置
    """
    host = parse_url(api_url)
    port = parse_port(api_url)
    is_https = api_url.startswith("https://")

    # 基础配置
    config = {
        "host": host,
        "port": port,
        "is_https": is_https,
        "api_url": api_url,
    }

    if env == "local":
        # 本地开发：前后端都在 localhost
        config.update({
            "debug": "True",
            "log_level": "DEBUG",
            "cors_allow_all": "True",
            "cors_origins": "http://localhost:5173,http://127.0.0.1:5173,http://localhost:8080,http://localhost:3000",
            "csrf_origins": "http://localhost:5173,http://127.0.0.1:5173,http://localhost:8080,http://localhost:3000,http://localhost:8000",
            "allowed_hosts": "localhost,127.0.0.1,0.0.0.0",
            "session_secure": "False",
            "csrf_secure": "False",
            "cookie_samesite": "Lax",
            "description": "本地开发",
        })

    elif env == "development":
        # 远程开发：前端(localhost随机端口) → 远程后端
        # CORS允许所有，方便Flutter Web随机端口调试
        config.update({
            "debug": "True",
            "log_level": "DEBUG",
            "cors_allow_all": "True",  # 关键：允许所有来源，包括随机端口
            "cors_origins": f"http://{host}:{port},http://{host},http://localhost:*",  # 包含随机端口
            "csrf_origins": f"http://{host}:{port},http://{host},http://localhost:5173,http://localhost:8000",
            "allowed_hosts": f"{host},localhost,127.0.0.1",
            "session_secure": "False",  # HTTP开发环境
            "csrf_secure": "False",
            "cookie_samesite": "Lax",
            "description": "远程开发部署（CORS宽松）",
        })

    elif env == "production":
        # 生产环境：严格配置
        session_secure = "True" if is_https else "False"
        config.update({
            "debug": "False",
            "log_level": "INFO",
            "cors_allow_all": "False",  # 严格：只允许特定域名
            "cors_origins": f"https://{host},https://www.{host}",  # 假设前端同域或指定域名
            "csrf_origins": f"https://{host},https://www.{host}",
            "allowed_hosts": f"{host},www.{host}",
            "session_secure": session_secure,
            "csrf_secure": session_secure,
            "cookie_samesite": "Lax",
            "description": "生产环境（严格配置）",
        })

    else:
        raise ValueError(f"未知环境: {env}，请使用 local/development/production")

    return config


def main():
    parser = argparse.ArgumentParser(description="生成 .env 文件")
    parser.add_argument("-f", "--force", action="store_true", help="强制覆盖已存在的文件")
    args = parser.parse_args()

    backend_dir = Path(__file__).parent
    root_dir = backend_dir.parent

    # 读取 deploy-config.json
    config_path = root_dir / "deploy-config.json"
    if not config_path.exists():
        print(f"[错误] 未找到 {config_path}")
        return 1

    with open(config_path, "r", encoding="utf-8") as f:
        deploy_config = json.load(f)

    api_url = deploy_config.get("api_base_url", "http://127.0.0.1:8000/api")
    environment = deploy_config.get("environment", "local")

    # 获取环境配置
    try:
        cfg = get_config_for_environment(environment, api_url)
    except ValueError as e:
        print(f"[错误] {e}")
        return 1

    # 根据环境决定文件名
    env_filename = f".env.{environment}"
    env_path = backend_dir / env_filename

    # 检查文件是否已存在
    if env_path.exists() and not args.force:
        print(f"[提示] {env_filename} 已存在，跳过生成")
        print(f"如需覆盖，请使用: python {Path(__file__).name} -f")
        return 0

    # 生成 .env 内容
    env_content = f"""# 由 deploy-config.json 自动生成
# 环境级别: {environment}
# 说明: {cfg['description']}
# API地址: {api_url}
# 生成时间: {datetime.now().isoformat()}

SECRET_KEY={generate_secret_key()}
DEBUG={cfg['debug']}
ALLOWED_HOSTS={cfg['allowed_hosts']}

DATABASE_URL=sqlite:///db.sqlite3

OPENROUTER_API_KEY=
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1

# 腾讯云COS图床配置
COS_SECRET_ID=
COS_SECRET_KEY=
COS_REGION=ap-nanjing
COS_BUCKET=

# CORS配置: {'允许所有来源' if cfg['cors_allow_all'] == 'True' else '限制特定域名'}
CORS_ALLOW_ALL_ORIGINS={cfg['cors_allow_all']}
CORS_ALLOWED_ORIGINS={cfg['cors_origins']}
CSRF_TRUSTED_ORIGINS={cfg['csrf_origins']}

# Cookie安全: {'HTTPS' if cfg['session_secure'] == 'True' else 'HTTP（不安全）'}
SESSION_COOKIE_SECURE={cfg['session_secure']}
CSRF_COOKIE_SECURE={cfg['csrf_secure']}
SESSION_COOKIE_SAMESITE={cfg['cookie_samesite']}
CSRF_COOKIE_SAMESITE={cfg['cookie_samesite']}

LOG_LEVEL={cfg['log_level']}
TIME_ZONE=Asia/Shanghai
LANGUAGE_CODE=zh-hans
"""

    with open(env_path, "w", encoding="utf-8") as f:
        f.write(env_content)

    action = "已覆盖" if args.force else "已生成"
    print(f"[{action}] {env_filename}")
    print(f"    级别: {environment}")
    print(f"    说明: {cfg['description']}")
    print(f"    API: {api_url}")
    print(f"    DEBUG: {cfg['debug']}")
    print(f"    CORS: {'允许所有' if cfg['cors_allow_all'] == 'True' else '受限'}")
    print(f"    ALLOWED_HOSTS: {cfg['allowed_hosts']}")

    # 提示
    if environment == "local":
        print(f"\n运行: python manage.py runserver")
    elif environment == "development":
        print(f"\n运行: DJANGO_ENV=development python manage.py runserver 0.0.0.0:{cfg['port']}")
        print(f"    Flutter: flutter run -d chrome --dart-define=API_BASE_URL={api_url}")
    elif environment == "production":
        print(f"\n生产环境请使用 gunicorn:")
        print(f"    DJANGO_ENV=production gunicorn -b 0.0.0.0:{cfg['port']} tradeX.wsgi:application")

    return 0


if __name__ == "__main__":
    exit(main())

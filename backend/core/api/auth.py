"""
core/api/auth.py — 认证相关接口
"""

import jwt
from ninja import Router
from ninja.errors import HttpError
from ninja.security import HttpBearer
from datetime import datetime, timedelta

from core.models import User
from .common import (
    auth,
    JWT_SECRET,
    JWT_EXPIRE_DAYS,
    LoginIn,
    LoginOut,
    generate_token,
)

router = Router()


@router.post("/login", response=LoginOut, tags=["认证"], summary="用户登录",
             auth=None)  # auth=None 明确标记无需鉴权
def login(request, data: LoginIn):
    """验证用户名和密码，返回基本用户信息。

    错误码：
    - 401 用户名不存在或密码错误
    - 403 账号待审核或已被拒绝

    注意：当前直接比对 encrypted_password 字段。
    待 User 模型切换到 AbstractUser 后改用 check_password()。
    """
    if (not data.username) and (not data.email):
        raise HttpError(401, "未提供用户名或邮箱")
    try:
        if data.username:
            user = User.objects.get(username=data.username)
        else:
            user = User.objects.get(email=data.email)
    except User.DoesNotExist:
        raise HttpError(401, "用户名或密码错误")

    if user.encrypted_password != data.password:
        raise HttpError(401, "用户名或密码错误")

    if user.register_status == User.RegisterStatusChoices.PENDING:
        raise HttpError(403, "账号正在审核中，请耐心等待")
    if user.register_status == User.RegisterStatusChoices.REJECTED:
        raise HttpError(403, "账号审核未通过")

    from django.utils import timezone
    user.last_login_time = timezone.now()
    user.save(update_fields=["last_login_time"])

    # 生成 30 天有效期的 JWT Token
    token = generate_token(user)

    return {
        "token": token,
        "user_id": user.user_id,
        "username": user.username,
        "role": user.role,
    }

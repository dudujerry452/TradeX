"""
core/api.py  —  core app 's django-ninja Router
"""

import uuid
from typing import Optional

from django.db import IntegrityError
from django.utils import timezone
from ninja import Router, Schema
from ninja.errors import HttpError

from .models import Product, User

router = Router()


# ── Schemas ───────────────────────────────────────────────────────────────────

class LoginIn(Schema):
    username: str
    password: str


class LoginOut(Schema):
    user_id: str
    username: str
    real_name: str
    role: str


class UserOut(Schema):
    user_id: str
    username: str
    real_name: str
    role: str
    register_status: str
    phone: str
    address: str


class UserIn(Schema):
    user_id: Optional[str] = None   # 可选
    username: str
    encrypted_password: str
    real_name: str
    id_card: str
    phone: str
    address: str


class ProductOut(Schema):
    product_id: str
    product_name: str
    category: str
    description: str
    image_url: str
    price: float       
    stock: int
    product_status: str
    publisher_id: str   # ForeignKey 的 _id 属性


class ProductIn(Schema):
    product_id: Optional[str] = None
    product_name: str
    category: str
    description: str
    image_url: str
    price: float
    stock: int
    publisher_id: str


# ── 认证接口 ──────────────────────────────────────────────────────────────────

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
    try:
        user = User.objects.get(username=data.username)
    except User.DoesNotExist:
        raise HttpError(401, "用户名或密码错误")

    if user.encrypted_password != data.password:
        raise HttpError(401, "用户名或密码错误")

    if user.register_status == User.RegisterStatusChoices.PENDING:
        raise HttpError(403, "账号正在审核中，请耐心等待")
    if user.register_status == User.RegisterStatusChoices.REJECTED:
        raise HttpError(403, "账号审核未通过")

    user.last_login_time = timezone.now()
    user.save(update_fields=["last_login_time"])

    return user


# ── 用户接口 ──────────────────────────────────────────────────────────────────

@router.get(
    "/users/",
    response=list[UserOut],   # 声明返回类型：ninja 用 UserOut schema 逐条序列化 QuerySet
    tags=["用户"],            # Swagger UI 的分组标签
    summary="获取所有用户列表",
)
def list_users(request):
    """
    获取系统中全部用户。
    """
    return User.objects.all()   # QuerySet 直接返回，ninja 负责 ORM → JSON


@router.post(
    "/users/",
    response={201: UserOut},  # {状态码: Schema}，声明非 200 的成功响应
    tags=["用户"],
    summary="注册新用户",
)
def create_user(request, data: UserIn):
    """创建新用户。

    - 字段缺失/类型错误 > 422
    - 唯一约束冲突（username/id_card 重复）> 400
    """
    try:
        user = User.objects.create(
            user_id=data.user_id or uuid.uuid4().hex[:20],
            username=data.username,
            encrypted_password=data.encrypted_password,
            real_name=data.real_name,
            id_card=data.id_card,
            phone=data.phone,
            address=data.address,
        )
    except IntegrityError as e:
        raise HttpError(400, str(e))  

    return 201, user  # (状态码, ORM对象)，ninja 按 response={201: UserOut} 序列化


@router.get("/users/{user_id}/", response=UserOut, tags=["用户"], summary="查询用户详情")
def get_user(request, user_id: str):
    try:
        return User.objects.get(user_id=user_id)
    except User.DoesNotExist:
        raise HttpError(404, "User not found")


# ── 商品接口 ────────────

@router.get("/products/", response=list[ProductOut], tags=["商品"], summary="获取商品列表")
def list_products(request):
    return Product.objects.all()


@router.post("/products/", response={201: ProductOut}, tags=["商品"], summary="发布新商品")
def create_product(request, data: ProductIn):
    try:
        publisher = User.objects.get(user_id=data.publisher_id)
    except User.DoesNotExist:
        raise HttpError(404, "Publisher not found")

    product = Product.objects.create(
        product_id=data.product_id or uuid.uuid4().hex[:20],
        product_name=data.product_name,
        category=data.category,
        description=data.description,
        image_url=data.image_url,
        price=data.price,
        stock=data.stock,
        publisher=publisher,
    )
    return 201, product


@router.get("/products/{product_id}/", response=ProductOut, tags=["商品"], summary="查询商品详情")
def get_product(request, product_id: str):
    try:
        return Product.objects.get(product_id=product_id)
    except Product.DoesNotExist:
        raise HttpError(404, "Product not found")

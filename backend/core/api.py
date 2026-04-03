"""
core/api.py  —  core app 's django-ninja Router
"""

import uuid
import json
from typing import Any, Optional, List
from datetime import datetime, timedelta

import jwt
from openai import OpenAI
from django.http import StreamingHttpResponse
from django.db import IntegrityError, transaction
from django.db.models import Sum, F, Count, Q
from django.conf import settings
from django.utils import timezone
from ninja import Router, Schema
from ninja.errors import HttpError
from ninja.security import HttpBearer

from .models import Product, User, Tag, ProductTag, UserTagPreference, ProductFavorite, Category, Order, OrderDetail, OrderLog, Notification
from .services.notification_service import NotificationService
from .rag_vector_service import (
    build_product_document,
    get_rag_collection,
)

router = Router()

# JWT 配置
JWT_SECRET = getattr(settings, 'SECRET_KEY', 'your-secret-key')
JWT_EXPIRE_DAYS = 30  # Token 30天有效

# JWT 认证器
class AuthBearer(HttpBearer):
    def authenticate(self, request, token):
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
            user = User.objects.get(user_id=payload["user_id"])
            return user
        except (jwt.ExpiredSignatureError, jwt.InvalidTokenError, User.DoesNotExist):
            return None

auth = AuthBearer()


# ── Schemas ───────────────────────────────────────────────────────────────────

class LoginIn(Schema):
    email: Optional[str] = None 
    username: Optional[str] = None
    password: str


class LoginOut(Schema):
    token: str
    user_id: str
    username: str
    role: str


class UserOut(Schema):
    user_id: str
    username: str
    email: str
    real_name: str
    role: str
    register_status: str
    phone: str
    phone_display: Optional[str] = None
    address: str


class RegisterIn(Schema):
    email: str
    username: str
    encrypted_password: str
    real_name: str
    id_card: str
    phone: str
    phone_display: Optional[str] = None
    address: str


class CategoryOut(Schema):
    category_id: str
    name: str
    description: str
    sort_order: int
    is_active: bool


class CategoryIn(Schema):
    category_id: Optional[str] = None
    name: str
    description: str = ""
    sort_order: int = 0
    is_active: bool = True


class ProductOut(Schema):
    product_id: str
    product_name: str
    category: str
    description: str
    image_url: str
    price: float
    stock: int
    product_status: str
    publisher_id: str
    view_count: int
    sales_count: int
    favorite_count: int
    avg_rating: float


class ProductIn(Schema):
    product_id: Optional[str] = None
    product_name: str
    category: str
    description: str
    image_url: str
    price: float
    stock: int
    publisher_id: str
    tag_ids: list[str] = []  # 可选：标签ID列表


class RagAddProductIn(Schema):
    id: str
    name: str
    price: float
    desc: str
    category: str


class RagAddProductOut(Schema):
    status: str
    msg: str


class RagChatIn(Schema):
    question: str
    n_results: int = 3


class RagChatOut(Schema):
    answer: str
    products: list[dict[str, Any]]


class RagChatStreamOut(Schema):
    stream: bool
    message: str


class TagOut(Schema):
    tag_id: str
    tag_name: str
    category: str
    usage_count: int
    create_time: Any


class TagIn(Schema):
    tag_id: Optional[str] = None
    tag_name: str
    category: str


class ProductTagOut(Schema):
    product_id: str
    tag_id: str
    tag_name: str
    weight: float
    tagged_time: Any


class ProductTagIn(Schema):
    product_id: str
    tag_id: str
    weight: float = 1.0


class UserTagPreferenceOut(Schema):
    user_id: str
    tag_id: str
    tag_name: str
    score: float
    update_time: Any


class UserTagPreferenceIn(Schema):
    user_id: str
    tag_id: str
    score: float


class ProductFavoriteOut(Schema):
    user_id: str
    product_id: str
    product_name: str
    price: float
    image_url: str
    favorited_time: Any


class ProductFavoriteIn(Schema):
    user_id: str
    product_id: str


# ── 推荐系统 Schemas ──────────────────────────────────────────────────────────

class RecommendationOut(Schema):
    product_id: str
    product_name: str
    product_url: Optional[str] = None
    category: str
    description: str
    image_url: str
    price: float
    stock: int
    product_status: str
    publisher_id: str
    view_count: int
    sales_count: int
    favorite_count: int
    avg_rating: float
    relevance_score: Optional[float] = None  # 推荐相关度分数
    is_favorited: Optional[bool] = None  # 当前用户是否已收藏


class ProductViewOut(Schema):
    success: bool
    view_count: int


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

    user.last_login_time = timezone.now()
    user.save(update_fields=["last_login_time"])

    # 生成 30 天有效期的 JWT Token
    payload = {
        "user_id": user.user_id,
        "username": user.username,
        "exp": datetime.utcnow() + timedelta(days=JWT_EXPIRE_DAYS),
    }
    token = jwt.encode(payload, JWT_SECRET, algorithm="HS256")

    return {
        "token": token,
        "user_id": user.user_id,
        "username": user.username,
        "role": user.role,
    }


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
def create_user(request, data: RegisterIn):
    """创建新用户。

    - 字段缺失/类型错误 > 422
    - 唯一约束冲突（username/id_card 重复）> 400
    """
    try:
        user = User.objects.create(
            user_id=uuid.uuid4().hex[:20],
            username=data.username,
            email=data.email, 
            encrypted_password=data.encrypted_password,
            real_name=data.real_name,
            id_card=data.id_card,
            phone=data.phone,
            phone_display=data.phone_display or None, 
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

    # 查找分类外键
    category_ref = None
    if data.category:
        try:
            category_ref = Category.objects.get(category_id=data.category)
        except Category.DoesNotExist:
            pass  # 如果分类不存在，则设为None

    product = Product.objects.create(
        product_id=data.product_id or uuid.uuid4().hex[:20],
        product_name=data.product_name,
        category=data.category,  # 保留旧字段兼容
        category_ref=category_ref,  # 新外键关联
        description=data.description,
        image_url=data.image_url,
        price=data.price,
        stock=data.stock,
        publisher=publisher,
        product_status=Product.StatusChoices.APPROVED,  # 默认批准
    )

    # 关联标签（如有）
    if data.tag_ids:
        for tag_id in data.tag_ids:
            try:
                tag = Tag.objects.get(tag_id=tag_id)
                ProductTag.objects.get_or_create(
                    product=product,
                    tag=tag,
                    defaults={"weight": 1.0}
                )
                # 更新标签使用次数
                tag.usage_count = ProductTag.objects.filter(tag=tag).count()
                tag.save()
            except Tag.DoesNotExist:
                pass  # 忽略不存在的标签

    return 201, product


class ProductStatusUpdateIn(Schema):
    """更新商品状态请求参数"""
    product_status: str  # APPROVED, OFF_SHELF, REJECTED


class ProductStatusUpdateOut(Schema):
    """更新商品状态响应"""
    product_id: str
    product_status: str
    message: str


@router.patch(
    "/products/{product_id}/status/",
    response=ProductStatusUpdateOut,
    tags=["商品"],
    summary="更新商品状态（批准/下架/拒绝）",
)
def update_product_status(request, product_id: str, data: ProductStatusUpdateIn):
    """更新商品状态

    - APPROVED: 审核通过
    - OFF_SHELF: 下架
    - REJECTED: 审核驳回
    """
    try:
        product = Product.objects.get(product_id=product_id)
    except Product.DoesNotExist:
        raise HttpError(404, "商品不存在")

    # 验证状态值是否有效
    valid_statuses = [choice[0] for choice in Product.StatusChoices.choices]
    if data.product_status not in valid_statuses:
        raise HttpError(400, f"无效的状态值，可选: {', '.join(valid_statuses)}")

    product.product_status = data.product_status
    product.save(update_fields=["product_status"])

    return {
        "product_id": product.product_id,
        "product_status": product.product_status,
        "message": f"商品状态已更新为: {product.get_product_status_display()}",
    }


# ── 搜索接口（必须在 /products/{product_id}/ 之前）────────────────────────────────

@router.get(
    "/products/search/",
    response=list[RecommendationOut],
    tags=["商品", "搜索"],
    summary="模糊搜索商品（支持分类筛选）",
    auth=None,
)
def search_products(
    request,
    q: str = "",  # 搜索关键词
    category: str = "",  # 分类筛选（精确匹配）
    limit: int = 10,
    offset: int = 0,
    token: Optional[str] = None,  # 可选用户token，用于个性化
):
    """模糊搜索商品（支持分类筛选）

    - 支持按商品名称、描述、分类模糊匹配
    - 支持精确分类筛选（category参数）
    - 可选token用于后续个性化排序（预留）
    - 支持分页

    使用场景：
    - q为空 + category有值：返回该分类下所有商品
    - q有值 + category有值：在该分类内搜索
    - q有值 + category为空：全站搜索
    """
    # 构建基础查询：只返回已审核商品
    products = Product.objects.filter(product_status='APPROVED')

    # 分类精确筛选（优先处理）
    # 支持按 category_ref 外键查询（新的分类体系），同时兼容旧 category 字段和分类名称
    if category.strip():
        # 先尝试按 ID 匹配新外键或旧字段
        filtered = products.filter(
            Q(category_ref__category_id=category.strip()) |
            Q(category=category.strip())
        )
        # 如果没结果，尝试按分类名称匹配（兼容旧数据）
        if not filtered.exists():
            filtered = products.filter(category_ref__name=category.strip())
        products = filtered

    # 关键词模糊搜索
    if q.strip():
        products = products.filter(
            Q(product_name__icontains=q) |  # 商品名称模糊匹配
            Q(description__icontains=q),    # 描述模糊匹配
        ).distinct()

    # 如果有token，可以在这里添加个性化排序逻辑（预留）
    # TODO: 根据token解析用户ID，按用户偏好排序

    # 分页
    paginated = products[offset:offset + limit]

    # 获取用户收藏的商品ID集合（如果提供了token）
    favorited_product_ids = set()
    if token:
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
            user_id = payload.get("user_id")
            if user_id:
                favorited_product_ids = set(
                    ProductFavorite.objects.filter(
                        user__user_id=user_id
                    ).values_list('product__product_id', flat=True)
                )
        except (jwt.ExpiredSignatureError, jwt.InvalidTokenError):
            pass  # Token无效时忽略，继续返回未收藏状态

    # 构建响应（复用RecommendationOut格式）
    result = []
    for p in paginated:
        # 优先使用新分类外键，回退到旧字段
        category_display = p.category_ref.name if p.category_ref else (p.category or "其他")
        category_id = p.category_ref.category_id if p.category_ref else (p.category or "other")

        data = {
            "product_id": p.product_id,
            "product_name": p.product_name,
            "category": category_id,  # 返回分类ID（如 misc, digital）
            "category_name": category_display,  # 返回分类名称
            "description": p.description,
            "image_url": p.image_url,
            "price": float(p.price),
            "stock": p.stock,
            "product_status": p.product_status,
            "publisher_id": p.publisher_id,
            "view_count": p.view_count,
            "sales_count": p.sales_count,
            "favorite_count": p.favorite_count,
            "avg_rating": p.avg_rating,
            "is_favorited": p.product_id in favorited_product_ids,
        }
        result.append(data)

    return result


@router.get("/products/{product_id}/", response=ProductOut, tags=["商品"], summary="查询商品详情")
def get_product(request, product_id: str):
    try:
        return Product.objects.get(product_id=product_id)
    except Product.DoesNotExist:
        raise HttpError(404, "Product not found")


# ── 分类接口 ──────────────────────────────────────────────────────────────────

@router.get("/categories/", response=list[CategoryOut], tags=["分类"], summary="获取分类列表", auth=None)
def list_categories(request):
    """获取所有启用的分类列表（按sort_order排序）"""
    return Category.objects.filter(is_active=True).order_by('sort_order', 'name')


@router.post("/categories/", response={201: CategoryOut}, tags=["分类"], summary="创建分类")
def create_category(request, data: CategoryIn):
    """创建新分类（管理员权限）"""
    category = Category.objects.create(
        category_id=data.category_id or uuid.uuid4().hex[:20],
        name=data.name,
        description=data.description,
        sort_order=data.sort_order,
        is_active=data.is_active,
    )
    return 201, category


@router.get("/categories/{category_id}/", response=CategoryOut, tags=["分类"], summary="查询分类详情", auth=None)
def get_category(request, category_id: str):
    """获取单个分类详情"""
    try:
        return Category.objects.get(category_id=category_id)
    except Category.DoesNotExist:
        raise HttpError(404, "分类不存在")


@router.put("/categories/{category_id}/", response=CategoryOut, tags=["分类"], summary="更新分类")
def update_category(request, category_id: str, data: CategoryIn):
    """更新分类信息"""
    try:
        category = Category.objects.get(category_id=category_id)
    except Category.DoesNotExist:
        raise HttpError(404, "分类不存在")

    category.name = data.name
    category.description = data.description
    category.sort_order = data.sort_order
    category.is_active = data.is_active
    category.save()

    return category


@router.delete("/categories/{category_id}/", tags=["分类"], summary="删除分类")
def delete_category(request, category_id: str):
    """删除分类（软删除：将is_active设为False）"""
    try:
        category = Category.objects.get(category_id=category_id)
    except Category.DoesNotExist:
        raise HttpError(404, "分类不存在")

    # 软删除，避免影响已有商品
    category.is_active = False
    category.save()

    return {"success": True, "message": "分类已禁用"}


# ── 标签接口 ──────────────────────────────────────────────────────────────────

@router.get("/tags/", response=list[TagOut], tags=["标签"], summary="获取标签列表")
def list_tags(request):
    return Tag.objects.all()


@router.post("/tags/", response={201: TagOut}, tags=["标签"], summary="创建新标签")
def create_tag(request, data: TagIn):
    tag = Tag.objects.create(
        tag_id=data.tag_id or uuid.uuid4().hex[:20],
        tag_name=data.tag_name,
        category=data.category,
    )
    return 201, tag


@router.get("/tags/{tag_id}/", response=TagOut, tags=["标签"], summary="查询标签详情")
def get_tag(request, tag_id: str):
    try:
        return Tag.objects.get(tag_id=tag_id)
    except Tag.DoesNotExist:
        raise HttpError(404, "Tag not found")


# ── 商品标签关联接口 ───────────────────────────────────────────────────────────

@router.get("/product-tags/", response=list[ProductTagOut], tags=["商品标签"], summary="获取商品标签关联列表")
def list_product_tags(request):
    pts = ProductTag.objects.select_related('product', 'tag').all()
    result = []
    for pt in pts:
        result.append({
            "product_id": pt.product.product_id,
            "tag_id": pt.tag.tag_id,
            "tag_name": pt.tag.tag_name,
            "weight": pt.weight,
            "tagged_time": pt.tagged_time,
        })
    return result


@router.post("/product-tags/", response={201: ProductTagOut}, tags=["商品标签"], summary="为商品添加标签")
def create_product_tag(request, data: ProductTagIn):
    try:
        product = Product.objects.get(product_id=data.product_id)
        tag = Tag.objects.get(tag_id=data.tag_id)
    except Product.DoesNotExist:
        raise HttpError(404, "Product not found")
    except Tag.DoesNotExist:
        raise HttpError(404, "Tag not found")

    pt, created = ProductTag.objects.get_or_create(
        product=product,
        tag=tag,
        defaults={"weight": data.weight}
    )
    if not created:
        pt.weight = data.weight
        pt.save()

    # 更新标签使用次数
    tag.usage_count = ProductTag.objects.filter(tag=tag).count()
    tag.save()

    return 201, {
        "product_id": product.product_id,
        "tag_id": tag.tag_id,
        "tag_name": tag.tag_name,
        "weight": pt.weight,
        "tagged_time": pt.tagged_time,
    }


@router.get("/products/{product_id}/tags/", response=list[TagOut], tags=["商品标签"], summary="获取商品的所有标签")
def get_product_tags(request, product_id: str):
    try:
        product = Product.objects.get(product_id=product_id)
    except Product.DoesNotExist:
        raise HttpError(404, "Product not found")
    return Tag.objects.filter(tagged_products__product=product)


# ── 用户标签偏好接口 ───────────────────────────────────────────────────────────

@router.get("/user-tag-preferences/", response=list[UserTagPreferenceOut], tags=["用户标签偏好"], summary="获取用户标签偏好列表")
def list_user_tag_preferences(request):
    utps = UserTagPreference.objects.select_related('user', 'tag').all()
    result = []
    for utp in utps:
        result.append({
            "user_id": utp.user.user_id,
            "tag_id": utp.tag.tag_id,
            "tag_name": utp.tag.tag_name,
            "score": utp.score,
            "update_time": utp.update_time,
        })
    return result


@router.post("/user-tag-preferences/", response={201: UserTagPreferenceOut}, tags=["用户标签偏好"], summary="设置用户标签偏好")
def create_user_tag_preference(request, data: UserTagPreferenceIn):
    try:
        user = User.objects.get(user_id=data.user_id)
        tag = Tag.objects.get(tag_id=data.tag_id)
    except User.DoesNotExist:
        raise HttpError(404, "User not found")
    except Tag.DoesNotExist:
        raise HttpError(404, "Tag not found")

    utp, created = UserTagPreference.objects.update_or_create(
        user=user,
        tag=tag,
        defaults={"score": data.score}
    )

    return 201, {
        "user_id": user.user_id,
        "tag_id": tag.tag_id,
        "tag_name": tag.tag_name,
        "score": utp.score,
        "update_time": utp.update_time,
    }


@router.get("/users/{user_id}/tag-preferences/", response=list[UserTagPreferenceOut], tags=["用户标签偏好"], summary="获取用户的标签偏好")
def get_user_tag_preferences(request, user_id: str):
    try:
        user = User.objects.get(user_id=user_id)
    except User.DoesNotExist:
        raise HttpError(404, "User not found")

    utps = UserTagPreference.objects.select_related('tag').filter(user=user)
    return [
        {
            "user_id": utp.user.user_id,
            "tag_id": utp.tag.tag_id,
            "tag_name": utp.tag.tag_name,
            "score": utp.score,
            "update_time": utp.update_time,
        }
        for utp in utps
    ]


# ── 商品收藏接口

@router.get("/product-favorites/", response=list[ProductFavoriteOut], tags=["商品收藏"], summary="获取所有商品收藏列表")
def list_product_favorites(request):
    pfs = ProductFavorite.objects.select_related('user', 'product').all()
    return [
        {
            "user_id": pf.user.user_id,
            "product_id": pf.product.product_id,
            "product_name": pf.product.product_name,
            "price": pf.product.price,
            "image_url": pf.product.image_url,
            "favorited_time": pf.favorited_time,
        }
        for pf in pfs
    ]


@router.post("/product-favorites/", response={201: ProductFavoriteOut}, tags=["商品收藏"], summary="收藏商品")
def create_product_favorite(request, data: ProductFavoriteIn):
    try:
        user = User.objects.get(user_id=data.user_id)
        product = Product.objects.get(product_id=data.product_id)
    except User.DoesNotExist:
        raise HttpError(404, "User not found")
    except Product.DoesNotExist:
        raise HttpError(404, "Product not found")

    pf, created = ProductFavorite.objects.get_or_create(
        user=user,
        product=product,
    )

    # 更新商品收藏数
    product.favorite_count = ProductFavorite.objects.filter(product=product).count()
    product.save()

    # 更新用户标签偏好（基于收藏的商品标签）
    product_tags = ProductTag.objects.filter(product=product).select_related('tag')
    for pt in product_tags:
        pref, created = UserTagPreference.objects.get_or_create(
            user=user,
            tag=pt.tag,
            defaults={'score': 1.0}
        )
        if not created:
            # 增加偏好分数（上限为10.0）
            pref.score = min(pref.score + 0.5, 10.0)
            pref.save()

    return 201, {
        "user_id": user.user_id,
        "product_id": product.product_id,
        "product_name": product.product_name,
        "price": product.price,
        "image_url": product.image_url,
        "favorited_time": pf.favorited_time,
    }


@router.get("/users/{user_id}/favorites/", response=list[ProductFavoriteOut], tags=["商品收藏"], summary="获取用户的收藏列表")
def get_user_favorites(request, user_id: str):
    try:
        user = User.objects.get(user_id=user_id)
    except User.DoesNotExist:
        raise HttpError(404, "User not found")

    pfs = ProductFavorite.objects.select_related('product').filter(user=user)
    return [
        {
            "user_id": pf.user.user_id,
            "product_id": pf.product.product_id,
            "product_name": pf.product.product_name,
            "price": pf.product.price,
            "image_url": pf.product.image_url,
            "favorited_time": pf.favorited_time,
        }
        for pf in pfs
    ]


@router.get("/products/{product_id}/favorites/", response=list[ProductFavoriteOut], tags=["商品收藏"], summary="获取收藏该商品的用户列表")
def get_product_favorites(request, product_id: str):
    try:
        product = Product.objects.get(product_id=product_id)
    except Product.DoesNotExist:
        raise HttpError(404, "Product not found")

    pfs = ProductFavorite.objects.select_related('user').filter(product=product)
    return [
        {
            "user_id": pf.user.user_id,
            "product_id": pf.product.product_id,
            "product_name": pf.product.product_name,
            "price": pf.product.price,
            "image_url": pf.product.image_url,
            "favorited_time": pf.favorited_time,
        }
        for pf in pfs
    ]


@router.get("/product-favorites/check/", tags=["商品收藏"], summary="检查当前用户是否收藏了指定商品")
def check_product_favorite(request, user_id: str, product_id: str):
    """轻量接口：检查用户是否收藏了指定商品

    返回: {"is_favorited": true/false}
    """
    try:
        user = User.objects.get(user_id=user_id)
        product = Product.objects.get(product_id=product_id)
    except User.DoesNotExist:
        raise HttpError(404, "User not found")
    except Product.DoesNotExist:
        raise HttpError(404, "Product not found")

    is_favorited = ProductFavorite.objects.filter(user=user, product=product).exists()
    return {"is_favorited": is_favorited}


@router.delete("/product-favorites/delete/", tags=["商品收藏"], summary="取消收藏（通过user_id和product_id）")
def delete_product_favorite_by_ids(request, user_id: str, product_id: str):
    """通过 user_id 和 product_id 删除收藏记录"""
    try:
        pf = ProductFavorite.objects.get(
            user__user_id=user_id,
            product__product_id=product_id
        )
        pf.delete()

        # 更新商品收藏数
        product = Product.objects.get(product_id=product_id)
        product.favorite_count = ProductFavorite.objects.filter(product=product).count()
        product.save()

        return {"success": True, "message": "已取消收藏"}
    except ProductFavorite.DoesNotExist:
        raise HttpError(404, "收藏记录不存在")
    except Exception as e:
        raise HttpError(500, str(e))


# ── RAG 接口 ──────────────────────────────────────────────────────────────────

@router.post(
    "/rag/add-product",
    response=RagAddProductOut,
    tags=["RAG"],
    summary="向 RAG 知识库添加商品",
)
def rag_add_product(request, data: RagAddProductIn):
    try:
        collection = get_rag_collection(settings.BASE_DIR)
    except Exception as exc:
        raise HttpError(500, f"初始化向量库失败: {exc}")
    text = build_product_document(
        name=data.name,
        category=data.category,
        price=data.price,
        desc=data.desc,
    )

    try:
        collection.upsert(
            documents=[text],
            metadatas=[
                {
                    "id": data.id,
                    "name": data.name,
                    "price": data.price,
                    "desc": data.desc,
                    "category": data.category,
                    "url": f"/product/{data.id}",
                }
            ],
            ids=[data.id],
        )
    except Exception as exc:
        raise HttpError(400, f"写入向量库失败: {exc}")

    return {"status": "ok", "msg": "商品已加入AI知识库"}


@router.post(
    "/rag/chat/stream",
    response={200: None},
    tags=["RAG"],
    summary="基于商品知识库的 AI 流式问答（SSE）",
)
def rag_chat_stream(request, data: RagChatIn):
    try:
        collection = get_rag_collection(settings.BASE_DIR)
    except Exception as exc:
        raise HttpError(500, f"初始化向量库失败: {exc}")
    top_k = max(1, min(data.n_results, 10))
    res = collection.query(query_texts=[data.question], n_results=top_k)
    products = []
    for item in (res.get("metadatas") or [[]])[0]:
        if not item:
            continue
        product_item = dict(item)
        product_id = product_item.get("id")
        if product_id and not product_item.get("url"):
            product_item["url"] = f"/product/{product_id}"
        products.append(product_item)

    if not products:
        raise HttpError(404, "未检索到匹配商品，请先添加商品到知识库")

    api_key = settings.OPENROUTER_API_KEY.strip()
    if not api_key:
        raise HttpError(500, "未配置 OPENROUTER_API_KEY，请在环境变量中设置")

    prompt = (
        "你是电商智能导购，只根据以下商品回答，不许编造。\n"
        f"商品信息：{products}\n"
        f"用户问题：{data.question}\n"
        "请自然语言回答，并推荐商品。"
    )

    client = OpenAI(api_key=api_key, base_url=settings.OPENROUTER_BASE_URL)

    def event_stream():
        yield "event: meta\n"
        yield f"data: {json.dumps({'products': products}, ensure_ascii=False)}\n\n"
        try:
            stream = client.chat.completions.create(
                model="deepseek/deepseek-chat",
                messages=[
                    {"role": "system", "content": "你是一个电商导购助手，只能基于给出的商品信息回答，不许编造。"},
                    {"role": "user", "content": prompt},
                ],
                stream=True,
            )

            for chunk in stream:
                if not chunk.choices:
                    continue
                delta = chunk.choices[0].delta
                token = delta.content if delta else None
                if token:
                    yield f"event: token\n"
                    yield f"data: {json.dumps({'token': token}, ensure_ascii=False)}\n\n"

            yield "event: done\n"
            yield "data: {\"done\": true}\n\n"
        except Exception as exc:
            msg = str(exc).replace("\n", " ")
            yield "event: error\n"
            yield f"data: {json.dumps({'error': msg}, ensure_ascii=False)}\n\n"

    response = StreamingHttpResponse(event_stream(), content_type="text/event-stream")
    response["Cache-Control"] = "no-cache"
    response["X-Accel-Buffering"] = "no"
    return response


# ── 推荐系统接口 ───────────────────────────────────────────────────────────────

def get_trending_recommendations(limit=10):
    """获取热门推荐商品

    基于浏览量、销量、收藏数和评分的综合热度算法
    """
    return Product.objects.filter(
        product_status='APPROVED'
    ).annotate(
        trending_score=F('view_count') * 0.2 +
                      F('sales_count') * 0.3 +
                      F('favorite_count') * 0.3 +
                      F('avg_rating') * 20 * 0.2
    ).order_by('-trending_score')[:limit]


def get_personalized_recommendations(user_id, limit=10):
    """获取个性化推荐商品

    基于用户标签偏好的推荐算法
    1. 获取用户标签偏好（score排序）
    2. 基于偏好标签找商品（包含已收藏）
    3. 无偏好时返回热门推荐
    """
    # 获取用户标签偏好（score排序）
    user_prefs = UserTagPreference.objects.filter(
        user_id=user_id
    ).order_by('-score')[:10]

    if user_prefs.exists():
        # 基于偏好标签找商品（包含已收藏）
        preferred_tags = [p.tag for p in user_prefs]

        # 使用聚合计算商品的相关度分数
        # 相关度 = sum(商品标签权重 * 用户标签偏好分数)
        recommended = Product.objects.filter(
            product_tags__tag__in=preferred_tags,
            product_status='APPROVED'
        ).annotate(
            relevance=Sum(
                F('product_tags__weight') * F('product_tags__tag__user_preferences__score'),
                filter=Q(product_tags__tag__user_preferences__user_id=user_id)
            )
        ).order_by('-relevance').distinct()[:limit]

        return recommended

    # 无偏好时返回热门推荐
    return get_trending_recommendations(limit)


def get_similar_products(product_id, limit=5):
    """获取相似商品

    基于共同标签数量的相似度算法
    """
    # 获取当前商品的标签ID列表
    product_tag_ids = ProductTag.objects.filter(
        product_id=product_id
    ).values_list('tag_id', flat=True)

    if not product_tag_ids:
        return Product.objects.none()

    # 找有相同标签的其他商品，按共同标签数量排序
    return Product.objects.filter(
        product_tags__tag_id__in=product_tag_ids,
        product_status='APPROVED'
    ).exclude(
        product_id=product_id
    ).annotate(
        common_tags=Count('product_tags__tag', filter=Q(product_tags__tag_id__in=product_tag_ids))
    ).filter(
        common_tags__gt=0  # 至少有一个共同标签
    ).order_by('-common_tags')[:limit]


@router.get(
    "/recommendations/personalized/",
    response=list[RecommendationOut],
    tags=["推荐系统"],
    summary="获取个性化推荐",
    auth=None,  # 允许未登录用户访问（返回热门推荐）
)
def personalized_recommendations(request, user_id: Optional[str] = None, limit: int = 10, offset: int = 0):
    """获取个性化推荐商品（支持分页）

    - 已登录用户：基于标签偏好推荐
    - 未登录用户（无user_id）：返回热门推荐
    - 支持offset分页
    - 返回包含is_favorited字段标记是否已收藏
    """
    # 获取推荐商品
    if user_id:
        try:
            User.objects.get(user_id=user_id)
            # 获取更多数据用于分页
            products = list(get_personalized_recommendations(user_id, limit + offset))
        except User.DoesNotExist:
            products = list(get_trending_recommendations(limit + offset))
    else:
        products = list(get_trending_recommendations(limit + offset))

    # 分页切片
    paginated_products = products[offset:offset + limit]

    # 获取用户收藏的商品ID集合（用于标记）
    favorited_product_ids = set()
    if user_id:
        favorited_product_ids = set(
            ProductFavorite.objects.filter(
                user__user_id=user_id
            ).values_list('product__product_id', flat=True)
        )

    # 构建响应数据
    result = []
    for p in paginated_products:
        data = {
            "product_id": p.product_id,
            "product_name": p.product_name,
            "product_url": f"/product/{p.product_id}",
            "category": p.category,
            "description": p.description,
            "image_url": p.image_url,
            "price": float(p.price),
            "stock": p.stock,
            "product_status": p.product_status,
            "publisher_id": p.publisher_id,
            "view_count": p.view_count,
            "sales_count": p.sales_count,
            "favorite_count": p.favorite_count,
            "avg_rating": p.avg_rating,
            "is_favorited": p.product_id in favorited_product_ids if user_id else False,
        }
        # 添加相关度分数（如果有）
        if hasattr(p, 'relevance') and p.relevance is not None:
            data["relevance_score"] = float(p.relevance)
        result.append(data)

    return result


@router.get(
    "/recommendations/trending/",
    response=list[RecommendationOut],
    tags=["推荐系统"],
    summary="获取热门推荐",
    auth=None,
)
def trending_recommendations(request, limit: int = 10, offset: int = 0):
    """获取热门推荐商品（支持分页）

    基于浏览量、销量、收藏数和评分的综合热度排序
    """
    # 获取更多数据用于分页
    products = list(get_trending_recommendations(limit + offset))
    # 分页切片
    paginated_products = products[offset:offset + limit]

    return [
        {
            "product_id": p.product_id,
            "product_name": p.product_name,
            "product_url": f"/product/{p.product_id}",
            "category": p.category,
            "description": p.description,
            "image_url": p.image_url,
            "price": float(p.price),
            "stock": p.stock,
            "product_status": p.product_status,
            "publisher_id": p.publisher_id,
            "view_count": p.view_count,
            "sales_count": p.sales_count,
            "favorite_count": p.favorite_count,
            "avg_rating": p.avg_rating,
        }
        for p in paginated_products
    ]


@router.get(
    "/recommendations/similar/",
    response=list[RecommendationOut],
    tags=["推荐系统"],
    summary="获取相似商品",
    auth=None,
)
def similar_recommendations(request, product_id: str, limit: int = 5):
    """获取与指定商品相似的商品

    基于共同标签数量的相似度算法
    """
    try:
        Product.objects.get(product_id=product_id)
    except Product.DoesNotExist:
        raise HttpError(404, "商品不存在")

    products = get_similar_products(product_id, limit)

    result = []
    for p in products:
        data = {
            "product_id": p.product_id,
            "product_name": p.product_name,
            "product_url": f"/product/{p.product_id}",
            "category": p.category,
            "description": p.description,
            "image_url": p.image_url,
            "price": float(p.price),
            "stock": p.stock,
            "product_status": p.product_status,
            "publisher_id": p.publisher_id,
            "view_count": p.view_count,
            "sales_count": p.sales_count,
            "favorite_count": p.favorite_count,
            "avg_rating": p.avg_rating,
        }
        # 添加共同标签数量作为相关度分数
        if hasattr(p, 'common_tags'):
            data["relevance_score"] = float(p.common_tags)
        result.append(data)

    return result


@router.post(
    "/products/{product_id}/view/",
    response=ProductViewOut,
    tags=["推荐系统", "商品"],
    summary="记录商品浏览",
    auth=None,
)
def record_product_view(request, product_id: str):
    """记录商品浏览，增加view_count

    用于推荐系统的行为数据收集
    """
    try:
        product = Product.objects.get(product_id=product_id)
    except Product.DoesNotExist:
        raise HttpError(404, "商品不存在")

    product.view_count += 1
    product.save(update_fields=["view_count"])

    return {"success": True, "view_count": product.view_count}


# ── System Endpoints ──────────────────────────────────────────────────────────

@router.get("/health", tags=["System"], auth=None)
def health_check(request):
    """健康检查接口"""
    return {"status": "ok", "timestamp": datetime.now().isoformat()}


# ── 订单系统 Schemas ───────────────────────────────────────────────────────────

class OrderProductOut(Schema):
    """订单商品信息"""
    product_id: str
    product_name: str
    image_url: str
    quantity: int
    price: float
    subtotal: float


class OrderOut(Schema):
    """订单输出"""
    order_id: str
    buyer_id: str
    seller_id: str
    total_amount: float
    order_status: str
    order_status_display: str
    order_time: datetime
    ship_time: Optional[datetime] = None
    receive_time: Optional[datetime] = None
    pay_time: Optional[datetime] = None
    logistics_company: Optional[str] = None
    logistics_number: Optional[str] = None
    address_snapshot: str
    phone_snapshot: str
    products: List[OrderProductOut]


class OrderCreateIn(Schema):
    """创建订单输入"""
    product_id: str
    quantity: int = 1
    address: str
    phone: str


class OrderShipIn(Schema):
    """发货输入"""
    logistics_company: str
    logistics_number: str


class OrderCancelIn(Schema):
    """取消订单输入"""
    reason: str = ""


class OrderPayIn(Schema):
    """支付订单输入（模拟支付）"""
    payment_method: str = "mock"  # mock, wechat, alipay


class OrderListOut(Schema):
    """订单列表输出"""
    orders: List[OrderOut]
    total: int


class OrderLogOut(Schema):
    """订单日志输出"""
    log_id: str
    action: str
    action_display: str
    from_status: Optional[str] = None
    to_status: str
    remark: str
    created_at: datetime
    operator_name: Optional[str] = None


# ── 通知系统 Schemas ───────────────────────────────────────────────────────────

class NotificationOut(Schema):
    """通知输出"""
    notification_id: str
    type: str
    type_display: str
    title: str
    content: str
    related_order_id: Optional[str] = None
    is_read: bool
    created_at: datetime


class UnreadCountOut(Schema):
    """未读数量输出"""
    count: int


class SuccessOut(Schema):
    """通用成功输出"""
    success: bool
    message: str


# ── 订单管理接口 ───────────────────────────────────────────────────────────────

def _build_order_out(order: Order) -> dict:
    """构建订单输出数据"""
    products = []
    for detail in order.details.all():
        products.append({
            "product_id": detail.product.product_id,
            "product_name": detail.product.product_name,
            "image_url": detail.product.image_url,
            "quantity": detail.quantity,
            "price": float(detail.price_snapshot),
            "subtotal": float(detail.subtotal),
        })

    return {
        "order_id": order.order_id,
        "buyer_id": order.buyer.user_id,
        "seller_id": order.seller.user_id,
        "total_amount": float(order.total_amount),
        "order_status": order.order_status,
        "order_status_display": order.get_order_status_display(),
        "order_time": order.order_time,
        "ship_time": order.ship_time,
        "receive_time": order.receive_time,
        "pay_time": order.pay_time,
        "logistics_company": order.logistics_company or None,
        "logistics_number": order.logistics_number or None,
        "address_snapshot": order.address_snapshot,
        "phone_snapshot": order.phone_snapshot,
        "products": products,
    }


@router.post("/orders/", response={201: OrderOut}, tags=["订单"], summary="创建订单", auth=auth)
def create_order(request, data: OrderCreateIn):
    """创建订单（直接购买）

    - 从商品直接创建订单
    - 自动扣减库存
    - 通知卖家
    """
    buyer = request.auth

    # 获取商品
    try:
        product = Product.objects.get(product_id=data.product_id)
    except Product.DoesNotExist:
        raise HttpError(404, "商品不存在")

    # 检查库存
    if product.stock < data.quantity:
        raise HttpError(400, f"库存不足，当前库存: {product.stock}")

    # 检查商品状态
    if product.product_status != Product.StatusChoices.APPROVED:
        raise HttpError(400, "商品未上架或已被下架")

    # 不能购买自己的商品
    if product.publisher.user_id == buyer.user_id:
        raise HttpError(400, "不能购买自己发布的商品")

    with transaction.atomic():
        # 创建订单
        order = Order.objects.create(
            order_id=f"ORD{uuid.uuid4().hex[:16].upper()}",
            buyer=buyer,
            seller=product.publisher,
            total_amount=product.price * data.quantity,
            address_snapshot=data.address or buyer.address,
            phone_snapshot=data.phone or (buyer.phone_display or ""),
            order_status=Order.StatusChoices.PENDING_PAY,
        )

        # 创建订单明细
        OrderDetail.objects.create(
            detail_id=f"ORDD{uuid.uuid4().hex[:16].upper()}",
            order=order,
            product=product,
            quantity=data.quantity,
            price_snapshot=product.price,
            subtotal=product.price * data.quantity,
        )

        # 扣减库存
        product.stock -= data.quantity
        product.save(update_fields=["stock"])

        # 创建订单日志
        OrderLog.objects.create(
            log_id=f"ORDL{uuid.uuid4().hex[:16].upper()}",
            order=order,
            operator=buyer,
            action=OrderLog.ActionChoices.CREATE,
            to_status=order.order_status,
            remark="创建订单",
        )

    # 通知卖家（在事务外，避免影响订单创建）
    NotificationService.notify_order_created(order)

    return 201, _build_order_out(order)


@router.get("/orders/", response=OrderListOut, tags=["订单"], summary="获取订单列表", auth=auth)
def list_orders(request, status: Optional[str] = None, role: str = "buyer", limit: int = 20, offset: int = 0):
    """获取订单列表

    - role: buyer（我购买的）/ seller（我卖出的）
    - status: 可选，按状态筛选
    """
    user = request.auth

    # 根据角色过滤
    if role == "buyer":
        orders = Order.objects.filter(buyer=user)
    elif role == "seller":
        orders = Order.objects.filter(seller=user)
    else:
        raise HttpError(400, "role 参数必须是 buyer 或 seller")

    # 状态筛选
    if status:
        valid_statuses = [choice[0] for choice in Order.StatusChoices.choices]
        if status not in valid_statuses:
            raise HttpError(400, f"无效的状态值，可选: {', '.join(valid_statuses)}")
        orders = orders.filter(order_status=status)

    # 统计总数
    total = orders.count()

    # 排序和分页
    orders = orders.order_by("-order_time")[offset:offset + limit]

    # 预加载订单明细
    orders = orders.prefetch_related("details", "details__product")

    return {
        "orders": [_build_order_out(order) for order in orders],
        "total": total,
    }


@router.get("/orders/{order_id}/", response=OrderOut, tags=["订单"], summary="获取订单详情", auth=auth)
def get_order(request, order_id: str):
    """获取订单详情"""
    user = request.auth

    try:
        order = Order.objects.prefetch_related("details", "details__product").get(order_id=order_id)
    except Order.DoesNotExist:
        raise HttpError(404, "订单不存在")

    # 检查权限（买家或卖家才能查看）
    if order.buyer.user_id != user.user_id and order.seller.user_id != user.user_id:
        raise HttpError(403, "无权查看此订单")

    return _build_order_out(order)


@router.post("/orders/{order_id}/pay/", response=OrderOut, tags=["订单"], summary="支付订单", auth=auth)
def pay_order(request, order_id: str, data: OrderPayIn):
    """支付订单（模拟支付）

    - 将订单状态从 PENDING_PAY 变为 PENDING_SHIP
    - 记录支付时间
    """
    buyer = request.auth

    try:
        order = Order.objects.prefetch_related("details", "details__product").get(order_id=order_id)
    except Order.DoesNotExist:
        raise HttpError(404, "订单不存在")

    # 检查权限
    if order.buyer.user_id != buyer.user_id:
        raise HttpError(403, "只能支付自己的订单")

    # 检查状态
    if order.order_status != Order.StatusChoices.PENDING_PAY:
        raise HttpError(400, "订单状态不正确，无法支付")

    with transaction.atomic():
        old_status = order.order_status
        order.order_status = Order.StatusChoices.PENDING_SHIP
        order.pay_time = timezone.now()
        order.save(update_fields=["order_status", "pay_time"])

        # 创建订单日志
        OrderLog.objects.create(
            log_id=f"ORDL{uuid.uuid4().hex[:16].upper()}",
            order=order,
            operator=buyer,
            action=OrderLog.ActionChoices.PAY,
            from_status=old_status,
            to_status=order.order_status,
            remark=f"支付方式: {data.payment_method}",
        )

    # 通知买卖双方
    NotificationService.notify_order_paid(order)

    return _build_order_out(order)


@router.post("/orders/{order_id}/ship/", response=OrderOut, tags=["订单"], summary="卖家发货", auth=auth)
def ship_order(request, order_id: str, data: OrderShipIn):
    """卖家发货

    - 将订单状态从 PENDING_SHIP 变为 SHIPPED
    - 填写物流信息
    """
    seller = request.auth

    try:
        order = Order.objects.prefetch_related("details", "details__product").get(order_id=order_id)
    except Order.DoesNotExist:
        raise HttpError(404, "订单不存在")

    # 检查权限
    if order.seller.user_id != seller.user_id:
        raise HttpError(403, "只能操作自己卖出的订单")

    # 检查状态
    if order.order_status != Order.StatusChoices.PENDING_SHIP:
        raise HttpError(400, "订单状态不正确，无法发货")

    with transaction.atomic():
        old_status = order.order_status
        order.order_status = Order.StatusChoices.SHIPPED
        order.logistics_company = data.logistics_company
        order.logistics_number = data.logistics_number
        order.ship_time = timezone.now()
        # 设置自动确认收货时间（7天后）
        order.auto_receive_time = timezone.now() + timedelta(days=7)
        order.save(update_fields=["order_status", "logistics_company", "logistics_number", "ship_time", "auto_receive_time"])

        # 创建订单日志
        OrderLog.objects.create(
            log_id=f"ORDL{uuid.uuid4().hex[:16].upper()}",
            order=order,
            operator=seller,
            action=OrderLog.ActionChoices.SHIP,
            from_status=old_status,
            to_status=order.order_status,
            remark=f"物流公司: {data.logistics_company}, 单号: {data.logistics_number}",
        )

    # 通知买家
    NotificationService.notify_order_shipped(order)

    return _build_order_out(order)


@router.post("/orders/{order_id}/receive/", response=OrderOut, tags=["订单"], summary="确认收货", auth=auth)
def receive_order(request, order_id: str):
    """买家确认收货

    - 将订单状态从 SHIPPED 变为 COMPLETED
    """
    buyer = request.auth

    try:
        order = Order.objects.prefetch_related("details", "details__product").get(order_id=order_id)
    except Order.DoesNotExist:
        raise HttpError(404, "订单不存在")

    # 检查权限
    if order.buyer.user_id != buyer.user_id:
        raise HttpError(403, "只能操作自己购买的订单")

    # 检查状态
    if order.order_status != Order.StatusChoices.SHIPPED:
        raise HttpError(400, "订单状态不正确，无法确认收货")

    with transaction.atomic():
        old_status = order.order_status
        order.order_status = Order.StatusChoices.COMPLETED
        order.receive_time = timezone.now()
        order.save(update_fields=["order_status", "receive_time"])

        # 更新商品销量
        for detail in order.details.all():
            detail.product.sales_count += detail.quantity
            detail.product.save(update_fields=["sales_count"])

        # 创建订单日志
        OrderLog.objects.create(
            log_id=f"ORDL{uuid.uuid4().hex[:16].upper()}",
            order=order,
            operator=buyer,
            action=OrderLog.ActionChoices.RECEIVE,
            from_status=old_status,
            to_status=order.order_status,
            remark="买家确认收货",
        )

    # 通知卖家
    NotificationService.notify_order_completed(order)

    return _build_order_out(order)


@router.post("/orders/{order_id}/cancel/", response=OrderOut, tags=["订单"], summary="取消订单", auth=auth)
def cancel_order(request, order_id: str, data: OrderCancelIn):
    """取消订单

    - 买家可以在 PENDING_PAY 状态取消
    - 卖家可以在 PENDING_SHIP 状态取消
    """
    user = request.auth

    try:
        order = Order.objects.prefetch_related("details", "details__product").get(order_id=order_id)
    except Order.DoesNotExist:
        raise HttpError(404, "订单不存在")

    # 检查权限
    is_buyer = order.buyer.user_id == user.user_id
    is_seller = order.seller.user_id == user.user_id

    if not is_buyer and not is_seller:
        raise HttpError(403, "无权操作此订单")

    # 检查状态权限
    if is_buyer and order.order_status not in [Order.StatusChoices.PENDING_PAY]:
        raise HttpError(400, "订单状态不正确，买家无法取消")

    if is_seller and order.order_status not in [Order.StatusChoices.PENDING_SHIP]:
        raise HttpError(400, "订单状态不正确，卖家无法取消")

    with transaction.atomic():
        old_status = order.order_status
        order.order_status = Order.StatusChoices.CANCELED
        order.cancel_reason = data.reason
        order.save(update_fields=["order_status", "cancel_reason"])

        # 恢复库存
        for detail in order.details.all():
            detail.product.stock += detail.quantity
            detail.product.save(update_fields=["stock"])

        # 创建订单日志
        OrderLog.objects.create(
            log_id=f"ORDL{uuid.uuid4().hex[:16].upper()}",
            order=order,
            operator=user,
            action=OrderLog.ActionChoices.CANCEL,
            from_status=old_status,
            to_status=order.order_status,
            remark=f"取消原因: {data.reason}" if data.reason else "取消订单",
        )

    # 通知对方
    NotificationService.notify_order_cancelled(order, user)

    return _build_order_out(order)


@router.get("/orders/{order_id}/logs/", response=List[OrderLogOut], tags=["订单"], summary="获取订单日志", auth=auth)
def get_order_logs(request, order_id: str):
    """获取订单操作日志"""
    user = request.auth

    try:
        order = Order.objects.get(order_id=order_id)
    except Order.DoesNotExist:
        raise HttpError(404, "订单不存在")

    # 检查权限
    if order.buyer.user_id != user.user_id and order.seller.user_id != user.user_id:
        raise HttpError(403, "无权查看此订单")

    logs = OrderLog.objects.filter(order=order).order_by("-created_at")

    return [
        {
            "log_id": log.log_id,
            "action": log.action,
            "action_display": log.get_action_display(),
            "from_status": log.from_status,
            "to_status": log.to_status,
            "remark": log.remark,
            "created_at": log.created_at,
            "operator_name": log.operator.username if log.operator else None,
        }
        for log in logs
    ]


# ── 通知接口 ───────────────────────────────────────────────────────────────────

@router.get("/notifications/", response=List[NotificationOut], tags=["通知"], summary="获取通知列表", auth=auth)
def list_notifications(request, is_read: Optional[bool] = None, limit: int = 20, offset: int = 0):
    """获取当前用户的通知列表"""
    user = request.auth

    notifications = Notification.objects.filter(user=user)

    # 已读筛选
    if is_read is not None:
        notifications = notifications.filter(is_read=is_read)

    # 排序和分页
    notifications = notifications.order_by("-created_at")[offset:offset + limit]

    return [
        {
            "notification_id": n.notification_id,
            "type": n.type,
            "type_display": n.get_type_display(),
            "title": n.title,
            "content": n.content,
            "related_order_id": n.related_order.order_id if n.related_order else None,
            "is_read": n.is_read,
            "created_at": n.created_at,
        }
        for n in notifications
    ]


@router.get("/notifications/unread-count/", response=UnreadCountOut, tags=["通知"], summary="获取未读通知数量", auth=auth)
def get_unread_count(request):
    """获取当前用户的未读通知数量"""
    user = request.auth
    count = NotificationService.get_unread_count(user)
    return {"count": count}


@router.post("/notifications/{notification_id}/read/", response=SuccessOut, tags=["通知"], summary="标记通知已读", auth=auth)
def mark_notification_read(request, notification_id: str):
    """标记单个通知为已读"""
    user = request.auth

    success = NotificationService.mark_as_read(notification_id, user)

    if not success:
        raise HttpError(404, "通知不存在")

    return {"success": True, "message": "已标记为已读"}


@router.post("/notifications/read-all/", response=SuccessOut, tags=["通知"], summary="标记所有通知已读", auth=auth)
def mark_all_read(request):
    """标记所有通知为已读"""
    user = request.auth

    count = NotificationService.mark_all_as_read(user)

    return {"success": True, "message": f"已标记 {count} 条通知为已读"}


@router.delete("/notifications/{notification_id}/", response=SuccessOut, tags=["通知"], summary="删除通知", auth=auth)
def delete_notification(request, notification_id: str):
    """删除通知"""
    user = request.auth

    success = NotificationService.delete_notification(notification_id, user)

    if not success:
        raise HttpError(404, "通知不存在")

    return {"success": True, "message": "通知已删除"}

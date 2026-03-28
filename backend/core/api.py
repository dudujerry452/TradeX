"""
core/api.py  —  core app 's django-ninja Router
"""

import uuid
import json
from typing import Any, Optional
from datetime import datetime, timedelta

import jwt
from openai import OpenAI
from django.http import StreamingHttpResponse
from django.db import IntegrityError
from django.db.models import Sum, F, Count, Q
from django.conf import settings
from django.utils import timezone
from ninja import Router, Schema
from ninja.errors import HttpError
from ninja.security import HttpBearer

from .models import Product, User, Tag, ProductTag, UserTagPreference, ProductFavorite
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


# ── 搜索接口（必须在 /products/{product_id}/ 之前）────────────────────────────────

@router.get(
    "/products/search/",
    response=list[RecommendationOut],
    tags=["商品", "搜索"],
    summary="模糊搜索商品",
    auth=None,
)
def search_products(
    request,
    q: str = "",  # 搜索关键词
    limit: int = 10,
    offset: int = 0,
    token: Optional[str] = None,  # 可选用户token，用于个性化
):
    """模糊搜索商品

    - 支持按商品名称、描述、分类模糊匹配
    - 可选token用于后续个性化排序（预留）
    - 支持分页
    """
    if not q.strip():
        return []

    # 使用Q对象进行多字段模糊匹配
    products = Product.objects.filter(
        Q(product_name__icontains=q) |  # 商品名称模糊匹配
        Q(description__icontains=q) |   # 描述模糊匹配
        Q(category__icontains=q),       # 分类模糊匹配
        product_status='APPROVED'       # 只返回已审核商品
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
        data = {
            "product_id": p.product_id,
            "product_name": p.product_name,
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
    products = (res.get("metadatas") or [[]])[0]

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

"""
core/api.py  —  core app 's django-ninja Router
"""

import uuid
import json
from typing import Any, Optional

from openai import OpenAI
from django.http import StreamingHttpResponse
from django.db import IntegrityError
from django.conf import settings
from django.utils import timezone
from ninja import Router, Schema
from ninja.errors import HttpError

from .models import Product, User, Tag, ProductTag, UserTagPreference
from .rag_vector_service import (
    build_product_document,
    get_rag_collection,
)

router = Router()


# ── Schemas ───────────────────────────────────────────────────────────────────

class LoginIn(Schema):
    email: Optional[str] = None 
    username: Optional[str] = None
    password: str


class LoginOut(Schema):
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

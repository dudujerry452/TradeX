"""
core/api/common.py — 共享组件（认证、通用Schemas、工具函数）
"""

import uuid
import jwt
from datetime import datetime, timedelta
from typing import Optional, List, Any
from django.conf import settings
from django.utils import timezone
from ninja import Schema
from ninja.security import HttpBearer

# JWT 配置
JWT_SECRET = getattr(settings, 'SECRET_KEY', 'your-secret-key')
JWT_EXPIRE_DAYS = 30  # Token 30天有效


# JWT 认证器
class AuthBearer(HttpBearer):
    def authenticate(self, request, token):
        from core.models import User
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
            user = User.objects.get(user_id=payload["user_id"])
            return user
        except (jwt.ExpiredSignatureError, jwt.InvalidTokenError, User.DoesNotExist):
            return None


# 认证实例
auth = AuthBearer()


# ── 通用 Schemas ─────────────────────────────────────────────────────────────

class SuccessOut(Schema):
    """通用成功输出"""
    success: bool
    message: str


class ImageUploadOut(Schema):
    success: bool
    url: str
    key: str
    filename: str


# ── 用户相关 Schemas ──────────────────────────────────────────────────────────

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


class UserUpdateIn(Schema):
    """更新用户信息输入"""
    address: Optional[str] = None
    phone_display: Optional[str] = None
    real_name: Optional[str] = None


# ── 商品相关 Schemas ──────────────────────────────────────────────────────────

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


class ProductStatusUpdateIn(Schema):
    """更新商品状态请求参数"""
    product_status: str  # APPROVED, OFF_SHELF, REJECTED


class ProductStatusUpdateOut(Schema):
    """更新商品状态响应"""
    product_id: str
    product_status: str
    message: str


class ProductUpdateIn(Schema):
    """更新商品信息输入"""
    product_name: Optional[str] = None
    description: Optional[str] = None
    price: Optional[float] = None
    stock: Optional[int] = None
    category: Optional[str] = None
    image_url: Optional[str] = None


class ProductViewOut(Schema):
    success: bool
    view_count: int


class SellerStatsOut(Schema):
    """卖家统计数据输出"""
    on_sale_count: int          # 在售商品数
    pending_ship_count: int     # 待发货订单数
    today_sales: float          # 今日销售额
    total_sales: float          # 总销售额


# ── 分类相关 Schemas ─────────────────────────────────────────────────────────

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


# ── 论坛相关 Schemas ──────────────────────────────────────────────────────────

class ForumCategoryOut(Schema):
    category_id: str
    name: str
    description: str
    sort_order: int
    is_active: bool
    created_at: Any
    updated_at: Any


class ForumCategoryIn(Schema):
    category_id: Optional[str] = None
    name: str
    description: str = ""
    sort_order: int = 0
    is_active: bool = True


class ForumTagOut(Schema):
    tag_id: str
    tag_name: str
    usage_count: int
    create_time: Any


class ForumCommentOut(Schema):
    comment_id: str
    post_id: str
    author_id: str
    author_name: str
    content: str
    like_count: int
    is_deleted: bool
    created_at: Any
    updated_at: Any


class ForumPostSummaryOut(Schema):
    post_id: str
    title: str
    content: str
    cover_image_url: Optional[str] = None
    author_id: str
    author_name: str
    category_id: Optional[str] = None
    category_name: Optional[str] = None
    tags: list[str] = []
    view_count: int
    like_count: int
    comment_count: int
    status: str
    is_pinned: bool
    published_at: Any
    updated_at: Any
    is_liked: bool = False


class ForumPostOut(ForumPostSummaryOut):
    comments: Optional[list[ForumCommentOut]] = None


class ForumPostIn(Schema):
    title: str
    content: str
    category_id: Optional[str] = None
    tag_names: list[str] = []
    cover_image_url: Optional[str] = None


class ForumCommentIn(Schema):
    content: str


# ── 标签相关 Schemas ──────────────────────────────────────────────────────────

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


# ── 收藏相关 Schemas ──────────────────────────────────────────────────────────

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


# ── 推荐系统 Schemas ─────────────────────────────────────────────────────────

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
    trending_score: Optional[float] = None  # 热度评分
    is_favorited: Optional[bool] = None  # 当前用户是否已收藏


# ── 订单相关 Schemas ─────────────────────────────────────────────────────────

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


# ── 通知相关 Schemas ─────────────────────────────────────────────────────────

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


# ── RAG 相关 Schemas ─────────────────────────────────────────────────────────

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


# ── 工具函数 ─────────────────────────────────────────────────────────────────

def generate_token(user) -> str:
    """生成 JWT Token"""
    payload = {
        "user_id": user.user_id,
        "username": user.username,
        "exp": datetime.utcnow() + timedelta(days=JWT_EXPIRE_DAYS),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")

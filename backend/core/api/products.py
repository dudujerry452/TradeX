"""
core/api/products.py — 商品相关接口
"""
import uuid
from typing import Optional
from ninja import Router
from ninja.errors import HttpError
from django.db.models import Q, F

from core.models import Product, User, Category, Tag, ProductTag, ProductFavorite
from .common import (
    auth,
    ProductOut,
    ProductIn,
    ProductStatusUpdateIn,
    ProductStatusUpdateOut,
    ProductViewOut,
    RecommendationOut,
    TagOut,
    ProductFavoriteOut,
    ProductUpdateIn,
    SellerStatsOut,
)

router = Router()


@router.get("/", response=list[ProductOut], tags=["商品"], summary="获取商品列表")
def list_products(request):
    return Product.objects.all()


@router.post("/", response={201: ProductOut}, tags=["商品"], summary="发布新商品")
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


# ── 搜索接口（必须在 /{product_id}/ 之前）────────────────────────────────

@router.get(
    "/search/",
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
    from core.models import ProductFavorite
    from .common import JWT_SECRET
    import jwt

    # 构建基础查询：只返回已审核商品
    products = Product.objects.filter(product_status='APPROVED')

    # 分类精确筛选（优先处理）
    if category.strip():
        filtered = products.filter(
            Q(category_ref__category_id=category.strip()) |
            Q(category=category.strip())
        )
        if not filtered.exists():
            filtered = products.filter(category_ref__name=category.strip())
        products = filtered

    # 关键词模糊搜索
    if q.strip():
        products = products.filter(
            Q(product_name__icontains=q) |
            Q(description__icontains=q),
        ).distinct()

    # 添加热度分计算并排序
    products = products.annotate(
        trending_score=F('view_count') * 0.2 +
                      F('sales_count') * 0.3 +
                      F('favorite_count') * 0.3 +
                      F('avg_rating') * 20 * 0.2
    ).order_by('-trending_score')

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
            pass

    # 构建响应（复用RecommendationOut格式）
    result = []
    for p in paginated:
        category_display = p.category_ref.name if p.category_ref else (p.category or "其他")
        category_id = p.category_ref.category_id if p.category_ref else (p.category or "other")

        data = {
            "product_id": p.product_id,
            "product_name": p.product_name,
            "category": category_id,
            "category_name": category_display,
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
            "trending_score": float(getattr(p, 'trending_score', 0)),
            "is_favorited": p.product_id in favorited_product_ids,
        }
        result.append(data)

    return result


@router.get("/{product_id}/", response=ProductOut, tags=["商品"], summary="查询商品详情")
def get_product(request, product_id: str):
    try:
        return Product.objects.get(product_id=product_id)
    except Product.DoesNotExist:
        raise HttpError(404, "Product not found")


@router.patch(
    "/{product_id}/status/",
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


@router.post(
    "/{product_id}/view/",
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


# ── 商品关联数据 ──────────────────────────────────────────────────────────────

@router.get("/{product_id}/tags/", response=list[TagOut], tags=["商品标签"], summary="获取商品的所有标签")
def get_product_tags(request, product_id: str):
    """获取商品的所有标签"""
    try:
        product = Product.objects.get(product_id=product_id)
    except Product.DoesNotExist:
        raise HttpError(404, "Product not found")
    return Tag.objects.filter(tagged_products__product=product)


@router.get("/{product_id}/favorites/", response=list[ProductFavoriteOut], tags=["商品收藏"], summary="获取收藏该商品的用户列表")
def get_product_favorites(request, product_id: str):
    """获取收藏该商品的用户列表"""
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


# ── 卖家中心接口 ──────────────────────────────────────────────────────────────

@router.get("/my/", response=list[ProductOut], tags=["商品", "卖家中心"], summary="获取我发布的商品")
def list_my_products(
    request,
    status: Optional[str] = None,
    limit: int = 20,
    offset: int = 0,
):
    """获取当前用户发布的商品列表

    - status: 筛选状态 (APPROVED/OFF_SHELF/PENDING/REJECTED)
    - limit: 每页数量
    - offset: 分页偏移量
    """
    if not request.auth:
        raise HttpError(401, "请先登录")

    products = Product.objects.filter(publisher=request.auth)

    if status:
        products = products.filter(product_status=status)

    return products[offset:offset + limit]


@router.put("/{product_id}/", response=ProductOut, tags=["商品", "卖家中心"], summary="更新商品信息")
def update_product(request, product_id: str, data: ProductUpdateIn):
    """更新商品信息

    - 只允许修改自己发布的商品
    - 只更新传入的字段
    """
    if not request.auth:
        raise HttpError(401, "请先登录")

    try:
        product = Product.objects.get(product_id=product_id)
    except Product.DoesNotExist:
        raise HttpError(404, "商品不存在")

    # 检查权限
    if product.publisher_id != request.auth.user_id:
        raise HttpError(403, "只能修改自己发布的商品")

    # 更新字段
    update_fields = []
    if data.product_name is not None:
        product.product_name = data.product_name
        update_fields.append("product_name")
    if data.description is not None:
        product.description = data.description
        update_fields.append("description")
    if data.price is not None:
        product.price = data.price
        update_fields.append("price")
    if data.stock is not None:
        product.stock = data.stock
        update_fields.append("stock")
    if data.image_url is not None:
        product.image_url = data.image_url
        update_fields.append("image_url")
    if data.category is not None:
        product.category = data.category
        # 更新分类外键
        try:
            category_ref = Category.objects.get(category_id=data.category)
            product.category_ref = category_ref
            update_fields.append("category_ref")
        except Category.DoesNotExist:
            pass
        update_fields.append("category")

    if update_fields:
        product.save(update_fields=update_fields)

    return product


@router.get("/seller/stats/", response=SellerStatsOut, tags=["卖家中心"], summary="获取卖家统计数据")
def get_seller_stats(request):
    """获取卖家统计数据

    返回：
    - on_sale_count: 在售商品数
    - pending_ship_count: 待发货订单数
    - today_sales: 今日销售额
    - total_sales: 总销售额
    """
    if not request.auth:
        raise HttpError(401, "请先登录")

    from core.models import Order
    from django.utils import timezone
    from datetime import datetime, time

    user = request.auth

    # 在售商品数
    on_sale_count = Product.objects.filter(
        publisher=user,
        product_status=Product.StatusChoices.APPROVED
    ).count()

    # 待发货订单数
    pending_ship_count = Order.objects.filter(
        seller=user,
        order_status='PENDING_SHIP'
    ).count()

    # 今日销售额
    today = timezone.now().date()
    today_start = datetime.combine(today, time.min)
    today_end = datetime.combine(today, time.max)

    today_orders = Order.objects.filter(
        seller=user,
        order_status__in=['SHIPPED', 'COMPLETED'],
        pay_time__range=(today_start, today_end)
    )
    today_sales = sum(o.total_amount for o in today_orders)

    # 总销售额
    total_orders = Order.objects.filter(
        seller=user,
        order_status__in=['SHIPPED', 'COMPLETED']
    )
    total_sales = sum(o.total_amount for o in total_orders)

    return {
        "on_sale_count": on_sale_count,
        "pending_ship_count": pending_ship_count,
        "today_sales": float(today_sales),
        "total_sales": float(total_sales),
    }

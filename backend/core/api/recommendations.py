"""
core/api/recommendations.py — 推荐系统相关接口
"""
from typing import Optional
from ninja import Router
from ninja.errors import HttpError
from django.db.models import F, Q, Sum, Count

from core.models import Product, User, ProductTag, ProductFavorite
from .common import RecommendationOut

router = Router()


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


def get_personalized_recommendations(user_id, limit=10, exclude_product_ids=None):
    """获取个性化推荐商品

    基于用户标签偏好的推荐算法
    1. 获取用户标签偏好（score排序）
    2. 基于偏好标签找商品（包含已收藏）
    3. 无偏好时返回空QuerySet
    """
    from core.models import UserTagPreference

    # 获取用户标签偏好（score排序）
    user_prefs = UserTagPreference.objects.filter(
        user_id=user_id
    ).order_by('-score')[:10]

    if user_prefs.exists():
        # 基于偏好标签找商品（包含已收藏）
        preferred_tags = [p.tag for p in user_prefs]

        # 构建基础查询
        queryset = Product.objects.filter(
            product_tags__tag__in=preferred_tags,
            product_status='APPROVED'
        )

        # 排除指定商品ID
        if exclude_product_ids:
            queryset = queryset.exclude(product_id__in=exclude_product_ids)

        # 使用聚合计算商品的相关度分数和热度分数
        recommended = queryset.annotate(
            relevance=Sum(
                F('product_tags__weight') * F('product_tags__tag__user_preferences__score'),
                filter=Q(product_tags__tag__user_preferences__user_id=user_id)
            ),
            trending_score=F('view_count') * 0.2 +
                          F('sales_count') * 0.3 +
                          F('favorite_count') * 0.3 +
                          F('avg_rating') * 20 * 0.2
        ).order_by('-relevance').distinct()[:limit]

        return recommended

    # 无偏好时返回空QuerySet
    return Product.objects.none()


def get_mixed_recommendations(user_id, limit=10, offset=0):
    """获取混合推荐（偏好+热门）

    策略：
    1. 优先返回个性化推荐商品（带relevance分数）
    2. 个性化不足时用热门推荐补充
    3. 支持分页
    """
    result = []
    personalized_count = 0

    # 获取用户已收藏的商品ID（用于排除）
    favorited_ids = set(
        ProductFavorite.objects.filter(
            user__user_id=user_id
        ).values_list('product__product_id', flat=True)
    )

    # 1. 获取个性化推荐（排除已收藏）
    personalized = list(get_personalized_recommendations(
        user_id,
        limit=limit + offset,
        exclude_product_ids=favorited_ids
    ))

    # 2. 如果offset在个性化范围内，从个性化开始取
    if offset < len(personalized):
        start_idx = offset
        end_idx = min(offset + limit, len(personalized))
        result.extend(personalized[start_idx:end_idx])
        personalized_count = len(result)

    # 3. 如果个性化不足，用热门推荐补充
    remaining = limit - len(result)
    if remaining > 0:
        trending_offset = max(0, offset - len(personalized))

        # 获取热门推荐，排除已收藏和已在个性化中的商品
        personalized_ids = {p.product_id for p in personalized}
        exclude_ids = favorited_ids | personalized_ids

        trending = Product.objects.filter(
            product_status='APPROVED'
        ).exclude(
            product_id__in=exclude_ids
        ).annotate(
            trending_score=F('view_count') * 0.2 +
                          F('sales_count') * 0.3 +
                          F('favorite_count') * 0.3 +
                          F('avg_rating') * 20 * 0.2
        ).order_by('-trending_score')

        trending_list = list(trending[trending_offset:trending_offset + remaining])
        result.extend(trending_list)

    return result, personalized_count


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
        common_tags__gt=0
    ).order_by('-common_tags')[:limit]


@router.get(
    "/personalized/",
    response=list[RecommendationOut],
    tags=["推荐系统"],
    summary="获取个性化推荐",
    auth=None,
)
def personalized_recommendations(request, user_id: Optional[str] = None, limit: int = 10, offset: int = 0):
    """获取个性化推荐商品（支持分页）

    - 已登录用户：基于标签偏好推荐，不足时用热门补充
    - 未登录用户（无user_id）：返回热门推荐
    - 支持offset分页
    - 返回包含is_favorited字段标记是否已收藏
    """
    # 获取推荐商品（混合偏好+热门）
    if user_id:
        try:
            User.objects.get(user_id=user_id)
            paginated_products, personalized_count = get_mixed_recommendations(user_id, limit, offset)
        except User.DoesNotExist:
            paginated_products = list(get_trending_recommendations(limit + offset)[offset:offset + limit])
            personalized_count = 0
    else:
        paginated_products = list(get_trending_recommendations(limit + offset)[offset:offset + limit])
        personalized_count = 0

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
        relevance = getattr(p, 'relevance', None)
        if relevance is not None:
            data["relevance_score"] = float(relevance)
        # 添加热度分数（如果有）
        trending_score = getattr(p, 'trending_score', None)
        if trending_score is not None:
            data["trending_score"] = float(trending_score)
        result.append(data)

    return result


@router.get(
    "/trending/",
    response=list[RecommendationOut],
    tags=["推荐系统"],
    summary="获取热门推荐",
    auth=None,
)
def trending_recommendations(request, limit: int = 10, offset: int = 0):
    """获取热门推荐商品（支持分页）

    基于浏览量、销量、收藏数和评分的综合热度排序
    """
    if offset < 0:
        return []

    if limit > 100:
        limit = 100

    products = list(get_trending_recommendations(limit + offset))
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
            "relevance_score": None,
            "trending_score": float(getattr(p, 'trending_score', 0)),
            "is_favorited": None,
        }
        for p in paginated_products
    ]


@router.get(
    "/similar/",
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

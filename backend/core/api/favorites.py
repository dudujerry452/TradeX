"""
core/api/favorites.py — 收藏相关接口（整合所有收藏相关路由）
"""
from ninja import Router
from ninja.errors import HttpError

from core.models import User, Product, ProductFavorite, Tag, ProductTag, UserTagPreference
from .common import ProductFavoriteOut, ProductFavoriteIn

router = Router()


# ── 收藏 CRUD ────────────────────────────────────────────────────────────────

@router.get("/", response=list[ProductFavoriteOut], tags=["商品收藏"])
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


@router.post("/", response={201: ProductFavoriteOut}, tags=["商品收藏"])
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


@router.delete("/delete/", tags=["商品收藏"])
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


@router.get("/check/", tags=["商品收藏"])
def check_product_favorite(request, user_id: str, product_id: str):
    """检查用户是否收藏了指定商品"""
    try:
        user = User.objects.get(user_id=user_id)
        product = Product.objects.get(product_id=product_id)
    except User.DoesNotExist:
        raise HttpError(404, "User not found")
    except Product.DoesNotExist:
        raise HttpError(404, "Product not found")

    is_favorited = ProductFavorite.objects.filter(user=user, product=product).exists()
    return {"is_favorited": is_favorited}


# ── 用户的收藏（从用户视角）───────────────────────────────────────────────────

@router.get("/users/{user_id}/favorites/", response=list[ProductFavoriteOut], tags=["商品收藏"])
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


# ── 商品的收藏（从商品视角）───────────────────────────────────────────────────

@router.get("/products/{product_id}/favorites/", response=list[ProductFavoriteOut], tags=["商品收藏"])
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

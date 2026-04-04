"""
core/api/users.py — 用户相关接口
"""
import uuid
from ninja import Router
from ninja.errors import HttpError
from django.db import IntegrityError

from core.models import User
from .common import (
    auth,
    UserOut,
    RegisterIn,
    UserUpdateIn,
    UserTagPreferenceOut,
    UserTagPreferenceIn,
    ProductFavoriteOut,
)

router = Router()


@router.get(
    "/",
    response=list[UserOut],
    tags=["用户"],
    summary="获取所有用户列表",
)
def list_users(request):
    """
    获取系统中全部用户。
    """
    return User.objects.all()


@router.post(
    "/",
    response={201: UserOut},
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

    return 201, user


@router.put("/me/", response=UserOut, tags=["用户"], summary="更新当前用户信息", auth=auth)
def update_current_user(request, data: UserUpdateIn):
    """更新当前登录用户的信息（收货地址、联系电话、真实姓名等）"""
    user = request.auth

    # 只更新提供的字段
    update_fields = []
    if data.address is not None:
        user.address = data.address
        update_fields.append("address")
    if data.phone_display is not None:
        user.phone_display = data.phone_display
        update_fields.append("phone_display")
    if data.real_name is not None:
        user.real_name = data.real_name
        update_fields.append("real_name")

    if update_fields:
        user.save(update_fields=update_fields)

    return user


@router.get("/{user_id}/", response=UserOut, tags=["用户"], summary="查询用户详情")
def get_user(request, user_id: str):
    try:
        return User.objects.get(user_id=user_id)
    except User.DoesNotExist:
        raise HttpError(404, "User not found")


@router.get("/{user_id}/tag-preferences/", response=list[UserTagPreferenceOut], tags=["用户标签偏好"], summary="获取用户的标签偏好")
def get_user_tag_preferences(request, user_id: str):
    from core.models import Tag, UserTagPreference
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


@router.get("/{user_id}/favorites/", response=list[ProductFavoriteOut], tags=["商品收藏"], summary="获取用户的收藏列表")
def get_user_favorites(request, user_id: str):
    """获取用户的收藏列表"""
    from core.models import ProductFavorite
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


# 用户标签偏好独立路由（用于注册到 /api/user-tag-preferences/）
user_tag_prefs_router = Router()


@user_tag_prefs_router.get("/", response=list[UserTagPreferenceOut], tags=["用户标签偏好"])
def list_user_tag_preferences(request):
    from core.models import Tag, UserTagPreference
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


@user_tag_prefs_router.post("/", response={201: UserTagPreferenceOut}, tags=["用户标签偏好"])
def create_user_tag_preference(request, data: UserTagPreferenceIn):
    from core.models import Tag, UserTagPreference
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

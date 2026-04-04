"""
core/api/categories.py — 分类相关接口
"""
from ninja import Router
from ninja.errors import HttpError

from core.models import Category
from .common import CategoryOut, CategoryIn

router = Router()


@router.get("/", response=list[CategoryOut], tags=["分类"], summary="获取分类列表", auth=None)
def list_categories(request):
    """获取所有启用的分类列表（按sort_order排序）"""
    return Category.objects.filter(is_active=True).order_by('sort_order', 'name')


@router.post("/", response={201: CategoryOut}, tags=["分类"], summary="创建分类")
def create_category(request, data: CategoryIn):
    """创建新分类（管理员权限）"""
    import uuid
    category = Category.objects.create(
        category_id=data.category_id or uuid.uuid4().hex[:20],
        name=data.name,
        description=data.description,
        sort_order=data.sort_order,
        is_active=data.is_active,
    )
    return 201, category


@router.get("/{category_id}/", response=CategoryOut, tags=["分类"], summary="查询分类详情", auth=None)
def get_category(request, category_id: str):
    """获取单个分类详情"""
    try:
        return Category.objects.get(category_id=category_id)
    except Category.DoesNotExist:
        raise HttpError(404, "分类不存在")


@router.put("/{category_id}/", response=CategoryOut, tags=["分类"], summary="更新分类")
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


@router.delete("/{category_id}/", tags=["分类"], summary="删除分类")
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

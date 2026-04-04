"""
core/api/tags.py — 标签相关接口
"""
import uuid
from ninja import Router
from ninja.errors import HttpError

from core.models import Tag, Product, ProductTag
from .common import TagOut, TagIn, ProductTagOut, ProductTagIn

# 标签主路由
router = Router()


@router.get("/", response=list[TagOut], tags=["标签"])
def list_tags(request):
    return Tag.objects.all()


@router.post("/", response={201: TagOut}, tags=["标签"])
def create_tag(request, data: TagIn):
    tag = Tag.objects.create(
        tag_id=data.tag_id or uuid.uuid4().hex[:20],
        tag_name=data.tag_name,
        category=data.category,
    )
    return 201, tag


@router.get("/{tag_id}/", response=TagOut, tags=["标签"])
def get_tag(request, tag_id: str):
    try:
        return Tag.objects.get(tag_id=tag_id)
    except Tag.DoesNotExist:
        raise HttpError(404, "Tag not found")


@router.get("/products/{product_id}/tags/", response=list[TagOut], tags=["商品标签"])
def get_product_tags(request, product_id: str):
    try:
        product = Product.objects.get(product_id=product_id)
    except Product.DoesNotExist:
        raise HttpError(404, "Product not found")
    return Tag.objects.filter(tagged_products__product=product)


# 商品标签关联路由（用于注册到 /api/product-tags/）
product_tags_router = Router()


@product_tags_router.get("/", response=list[ProductTagOut], tags=["商品标签"])
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


@product_tags_router.post("/", response={201: ProductTagOut}, tags=["商品标签"])
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

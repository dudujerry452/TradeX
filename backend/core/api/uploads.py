"""
core/api/uploads.py — 文件上传相关接口
"""
from ninja import Router
from ninja.errors import HttpError
from django.conf import settings

from core.cos_upload_service import upload_image_to_cos, CosUploadError
from .common import auth, ImageUploadOut

router = Router()


@router.post(
    "/image/",
    response=ImageUploadOut,
    tags=["文件"],
    summary="上传图片到 COS",
    auth=auth,
)
def upload_image(request):
    """接收 multipart图片文件，上传到腾讯云COS,返回可访问 URL。"""
    uploaded_file = request.FILES.get("file") or request.FILES.get("image")
    if not uploaded_file:
        raise HttpError(400, "未找到上传文件，请使用 multipart/form-data 传入 file 或 image 字段")

    max_size = 10 * 1024 * 1024
    if uploaded_file.size > max_size:
        raise HttpError(400, "图片大小不能超过 10MB")

    allowed_types = {"image/jpeg", "image/png", "image/webp", "image/gif"}
    content_type = getattr(uploaded_file, "content_type", "") or ""
    if content_type and content_type not in allowed_types:
        raise HttpError(400, "仅支持 jpeg、png、webp、gif 图片")

    try:
        result = upload_image_to_cos(
            uploaded_file,
            uploaded_file.name or "image.jpg",
            content_type=content_type or None,
        )
    except CosUploadError as exc:
        raise HttpError(500, str(exc))

    return {
        "success": True,
        "url": result.url,
        "key": result.key,
        "filename": uploaded_file.name,
    }

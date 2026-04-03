from __future__ import annotations

import os
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import BinaryIO

try:
    from qcloud_cos import CosConfig, CosS3Client
except ImportError:  # pragma: no cover - 运行环境未安装依赖时提示更明确
    CosConfig = None
    CosS3Client = None


DEFAULT_PUBLIC_SCHEME = "https"


@dataclass
class CosUploadResult:
    key: str
    url: str


class CosUploadError(RuntimeError):
    pass


def _get_env(name: str, default: str = "") -> str:
    return os.getenv(name, default).strip()


def _ensure_sdk():
    if CosConfig is None or CosS3Client is None:
        raise CosUploadError("缺少 cos-python-sdk-v5 依赖，请先安装 cos-python-sdk-v5")


def _build_public_url(bucket: str, region: str, key: str) -> str:
    custom_domain = _get_env("COS_CUSTOM_DOMAIN")
    public_scheme = _get_env("COS_PUBLIC_SCHEME", DEFAULT_PUBLIC_SCHEME)

    if custom_domain:
        return f"{public_scheme}://{custom_domain}/{key}"

    return f"{public_scheme}://{bucket}.cos.{region}.myqcloud.com/{key}"


def get_cos_client():
    _ensure_sdk()

    secret_id = _get_env("COS_SECRET_ID")
    secret_key = _get_env("COS_SECRET_KEY")
    region = _get_env("COS_REGION")

    if not secret_id or not secret_key or not region:
        raise CosUploadError("请先配置 COS_SECRET_ID、COS_SECRET_KEY 和 COS_REGION")

    config = CosConfig(
        Region=region,
        SecretId=secret_id,
        SecretKey=secret_key,
        Token=_get_env("COS_TOKEN"),
        Scheme=_get_env("COS_API_SCHEME", DEFAULT_PUBLIC_SCHEME),
    )
    return CosS3Client(config)


def build_image_key(filename: str) -> str:
    suffix = Path(filename).suffix.lower()
    if not suffix:
        suffix = ".jpg"

    date_prefix = datetime.now().strftime("%Y/%m/%d")
    random_part = os.urandom(8).hex()
    return f"products/{date_prefix}/{random_part}{suffix}"


def upload_image_to_cos(file_obj: BinaryIO, filename: str, content_type: str | None = None) -> CosUploadResult:
    bucket = _get_env("COS_BUCKET")
    region = _get_env("COS_REGION")

    if not bucket or not region:
        raise CosUploadError("请先配置 COS_BUCKET 和 COS_REGION")

    client = get_cos_client()
    key = build_image_key(filename)

    file_bytes = file_obj.read()
    if not file_bytes:
        raise CosUploadError("上传文件为空")

    try:
        client.put_object(
            Bucket=bucket,
            Body=file_bytes,
            Key=key,
        )
    except Exception as exc:
        raise CosUploadError(f"上传到 COS 失败: {exc}") from exc

    return CosUploadResult(key=key, url=_build_public_url(bucket, region, key))
from __future__ import annotations

import os
from dataclasses import dataclass
from decimal import Decimal
from pathlib import Path
from typing import Iterable

from .models import Product

try:
    import chromadb
    from chromadb.utils import embedding_functions
except ImportError:
    chromadb = None
    embedding_functions = None

try:
    from huggingface_hub import snapshot_download
except ImportError:
    snapshot_download = None


COLLECTION_NAME = "products"
VECTOR_DB_DIRNAME = "vector_db"
EMBEDDING_MODEL_REPO_ID = "BAAI/bge-base-zh-v1.5"
EMBEDDING_MODEL_DIRNAME = "embedding_models"


def _embedding_model_dir(base_dir: Path) -> Path:
    return base_dir / EMBEDDING_MODEL_DIRNAME / EMBEDDING_MODEL_REPO_ID


def _embedding_model_is_ready(model_dir: Path) -> bool:
    weight_files = list(model_dir.glob("*.bin")) + list(model_dir.glob("*.safetensors"))
    return (
        model_dir.is_dir()
        and (model_dir / "config.json").is_file()
        and (model_dir / "modules.json").is_file()
        and bool(weight_files)
    )


def _ensure_embedding_model_dir(base_dir: Path) -> Path:
    model_dir = _embedding_model_dir(base_dir)
    if _embedding_model_is_ready(model_dir):
        return model_dir

    if snapshot_download is None:
        raise RuntimeError("缺少 huggingface_hub 依赖，请先安装 huggingface_hub")

    model_dir.parent.mkdir(parents=True, exist_ok=True)

    try:
        snapshot_download(
            repo_id=EMBEDDING_MODEL_REPO_ID,
            local_dir=str(model_dir),
        )
    except Exception as exc:
        raise RuntimeError(
            f"自动下载嵌入模型失败: {exc}\n"
            f"模型会缓存到 {model_dir}，后续运行不会再次访问服务器。"
        ) from exc

    if not _embedding_model_is_ready(model_dir):
        raise RuntimeError(f"嵌入模型下载完成，但目录仍不完整: {model_dir}")

    return model_dir


@dataclass
class SyncResult:
    synced_count: int
    deleted_count: int
    total_db_count: int


def get_rag_collection(base_dir: Path):
    if chromadb is None or embedding_functions is None:
        raise RuntimeError("缺少 chromadb 依赖，请先安装 chromadb")

    model_dir = _ensure_embedding_model_dir(base_dir)
    os.environ.setdefault("HF_HUB_OFFLINE", "1")
    os.environ.setdefault("TRANSFORMERS_OFFLINE", "1")

    client = chromadb.PersistentClient(path=str(base_dir / VECTOR_DB_DIRNAME))
    embedding_func = embedding_functions.SentenceTransformerEmbeddingFunction(
        model_name=str(model_dir),
        device="cpu",
        local_files_only=True,
    )

    return client.get_or_create_collection(
        name=COLLECTION_NAME,
        embedding_function=embedding_func,
    )


def build_product_document(name: str, category: str, price: float, desc: str) -> str:
    return f"商品：{name} | 分类：{category} | 价格：{price}元 | 描述：{desc}"


def _to_float(value: Decimal | float | int) -> float:
    return float(value)


def build_product_payload(product: Product):
    product_url = f"/product/{product.product_id}"
    text = build_product_document(
        name=product.product_name,
        category=product.category,
        price=_to_float(product.price),
        desc=product.description,
    )
    metadata = {
        "id": product.product_id,
        "name": product.product_name,
        "price": _to_float(product.price),
        "desc": product.description,
        "category": product.category,
        "product_url": product_url,
    }
    return product.product_id, text, metadata


def sync_products_to_vector_db(collection, products: Iterable[Product], replace: bool = False) -> SyncResult:
    ids: list[str] = []
    docs: list[str] = []
    metadatas: list[dict] = []

    for product in products:
        pid, doc, metadata = build_product_payload(product)
        ids.append(pid)
        docs.append(doc)
        metadatas.append(metadata)

    if ids:
        collection.upsert(ids=ids, documents=docs, metadatas=metadatas)

    deleted_count = 0
    if replace:
        existing_ids = set(collection.get(include=[]).get("ids", []))
        db_ids = set(ids)
        stale_ids = list(existing_ids - db_ids)
        if stale_ids:
            collection.delete(ids=stale_ids)
            deleted_count = len(stale_ids)

    return SyncResult(
        synced_count=len(ids),
        deleted_count=deleted_count,
        total_db_count=len(ids),
    )

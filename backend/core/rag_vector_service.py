from __future__ import annotations

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


COLLECTION_NAME = "products"
VECTOR_DB_DIRNAME = "vector_db"


@dataclass
class SyncResult:
    synced_count: int
    deleted_count: int
    total_db_count: int


def get_rag_collection(base_dir: Path):
    if chromadb is None or embedding_functions is None:
        raise RuntimeError("缺少 chromadb 依赖，请先安装 chromadb")

    client = chromadb.PersistentClient(path=str(base_dir / VECTOR_DB_DIRNAME))
    embedding_func = embedding_functions.DefaultEmbeddingFunction()
    return client.get_or_create_collection(
        name=COLLECTION_NAME,
        embedding_function=embedding_func,
    )


def build_product_document(name: str, category: str, price: float, desc: str) -> str:
    return f"商品：{name} | 分类：{category} | 价格：{price}元 | 描述：{desc}"


def _to_float(value: Decimal | float | int) -> float:
    return float(value)


def build_product_payload(product: Product):
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

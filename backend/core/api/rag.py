"""
core/api/rag.py — RAG AI相关接口
"""
import json
import re
from ninja import Router
from ninja.errors import HttpError
from django.http import StreamingHttpResponse
from django.conf import settings
from openai import OpenAI

from core.rag_vector_service import build_product_document, get_rag_collection
from .common import RagAddProductIn, RagAddProductOut, RagChatIn

router = Router()


def _normalize_query_fragments(query):
    query_text = str(query or "").strip().lower()
    if not query_text:
        return []

    fragments = [part for part in re.split(r"[\s,，。\.、;；:：/|\\_\-\(\)\[\]{}<>]+", query_text) if part]
    if query_text not in fragments:
        fragments.append(query_text)
    return fragments


def _has_query_overlap(query, product_item):
    haystack = " ".join(
        str(product_item.get(field, "") or "")
        for field in ("name", "category", "desc")
    ).lower()
    if not haystack.strip():
        return False

    for fragment in _normalize_query_fragments(query):
        if fragment and fragment in haystack:
            return True
    return False


@router.post(
    "/add-product",
    response=RagAddProductOut,
    tags=["RAG"],
    summary="向 RAG 知识库添加商品",
)
def rag_add_product(request, data: RagAddProductIn):
    try:
        collection = get_rag_collection(settings.BASE_DIR)
    except Exception as exc:
        raise HttpError(500, f"初始化向量库失败: {exc}")

    text = build_product_document(
        name=data.name,
        category=data.category,
        price=data.price,
        desc=data.desc,
    )

    try:
        collection.upsert(
            documents=[text],
            metadatas=[
                {
                    "id": data.id,
                    "name": data.name,
                    "price": data.price,
                    "desc": data.desc,
                    "category": data.category,
                    "url": f"/product/{data.id}",
                }
            ],
            ids=[data.id],
        )
    except Exception as exc:
        raise HttpError(400, f"写入向量库失败: {exc}")

    return {"status": "ok", "msg": "商品已加入AI知识库"}


@router.post(
    "/chat/stream",
    response={200: None},
    tags=["RAG"],
    summary="基于商品知识库的 AI 流式问答（SSE）",
)
def rag_chat_stream(request, data: RagChatIn):
    try:
        collection = get_rag_collection(settings.BASE_DIR)
    except Exception as exc:
        raise HttpError(500, f"初始化向量库失败: {exc}")

    top_k = max(1, min(data.n_results, 10))
    max_distance = float(getattr(settings, "RAG_MAX_DISTANCE", 0.95))
    res = collection.query(
        query_texts=[data.question],
        n_results=top_k,
        include=["metadatas", "distances"],
    )

    metadatas = (res.get("metadatas") or [[]])[0]
    distances = (res.get("distances") or [[]])[0]

    products = []
    for index, item in enumerate(metadatas):
        if not item:
            continue
        product_item = dict(item)
        product_id = product_item.get("id")
        if product_id and not product_item.get("url"):
            product_item["url"] = f"/product/{product_id}"
        distance = distances[index] if index < len(distances) else None

        is_relevant = False
        if distance is not None:
            try:
                is_relevant = float(distance) <= max_distance
            except (TypeError, ValueError):
                is_relevant = False

        if not is_relevant:
            is_relevant = _has_query_overlap(data.question, product_item)

        if not is_relevant:
            continue

        if distance is not None:
            try:
                product_item["distance"] = float(distance)
            except (TypeError, ValueError):
                pass

        products.append(product_item)

    if not products:
        raise HttpError(404, "未检索到足够相关的商品，请尝试换个关键词")

    api_key = settings.OPENROUTER_API_KEY.strip()
    if not api_key:
        raise HttpError(500, "未配置 OPENROUTER_API_KEY，请在环境变量中设置")

    prompt = (
        "你是电商智能导购，只根据以下商品回答，不许编造。\n"
        f"商品信息：{products}\n"
        f"用户问题：{data.question}\n"
        "请自然语言回答，并推荐商品。"
    )

    client = OpenAI(api_key=api_key, base_url=settings.OPENROUTER_BASE_URL)

    def event_stream():
        yield "event: meta\n"
        yield f"data: {json.dumps({'products': products}, ensure_ascii=False)}\n\n"
        try:
            stream = client.chat.completions.create(
                model="deepseek/deepseek-chat",
                messages=[
                    {"role": "system", "content": "你是一个电商导购助手，只能基于给出的商品信息回答，不许编造。"},
                    {"role": "user", "content": prompt},
                ],
                stream=True,
            )

            for chunk in stream:
                if not chunk.choices:
                    continue
                delta = chunk.choices[0].delta
                token = delta.content if delta else None
                if token:
                    yield f"event: token\n"
                    yield f"data: {json.dumps({'token': token}, ensure_ascii=False)}\n\n"

            yield "event: done\n"
            yield f"data: {{\"done\": true}}\n\n"
        except Exception as exc:
            msg = str(exc).replace("\n", " ")
            yield "event: error\n"
            yield f"data: {json.dumps({'error': msg}, ensure_ascii=False)}\n\n"

    response = StreamingHttpResponse(event_stream(), content_type="text/event-stream")
    response["Cache-Control"] = "no-cache"
    response["X-Accel-Buffering"] = "no"
    return response

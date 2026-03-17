import json
import uuid

from django.db import IntegrityError
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods

from .models import Product, User


def _new_id():
    return str(uuid.uuid4()).replace("-", "")[:20]


# ── User APIs ────────────────────────────────────────────────────────────────

@csrf_exempt
@require_http_methods(["GET", "POST"])
def users(request):
    if request.method == "GET":
        data = list(User.objects.values(
            "user_id", "username", "real_name", "role",
            "register_status", "register_time",
        ))
        return JsonResponse(data, safe=False)

    body = json.loads(request.body)
    try:
        user = User.objects.create(
            user_id=body.get("user_id") or _new_id(),
            username=body["username"],
            encrypted_password=body["encrypted_password"],
            real_name=body["real_name"],
            id_card=body["id_card"],
            phone=body["phone"],
            address=body["address"],
        )
    except IntegrityError as e:
        return JsonResponse({"error": str(e)}, status=400)
    return JsonResponse({"user_id": user.user_id, "username": user.username}, status=201)


@require_http_methods(["GET"])
def user_detail(request, user_id):
    try:
        user = User.objects.get(user_id=user_id)
    except User.DoesNotExist:
        return JsonResponse({"error": "User not found"}, status=404)

    return JsonResponse({
        "user_id": user.user_id,
        "username": user.username,
        "real_name": user.real_name,
        "role": user.role,
        "register_status": user.register_status,
        "phone": user.phone,
        "address": user.address,
    })


# ── Product APIs ─────────────────────────────────────────────────────────────

@csrf_exempt
@require_http_methods(["GET", "POST"])
def products(request):
    if request.method == "GET":
        data = list(Product.objects.values(
            "product_id", "product_name", "category",
            "price", "stock", "product_status",
        ))
        return JsonResponse(data, safe=False)

    body = json.loads(request.body)
    try:
        publisher = User.objects.get(user_id=body["publisher_id"])
    except User.DoesNotExist:
        return JsonResponse({"error": "Publisher not found"}, status=404)

    product = Product.objects.create(
        product_id=body.get("product_id") or _new_id(),
        product_name=body["product_name"],
        category=body["category"],
        description=body["description"],
        image_url=body["image_url"],
        price=body["price"],
        stock=body["stock"],
        publisher=publisher,
    )
    return JsonResponse(
        {"product_id": product.product_id, "product_name": product.product_name},
        status=201,
    )


@require_http_methods(["GET"])
def product_detail(request, product_id):
    try:
        p = Product.objects.get(product_id=product_id)
    except Product.DoesNotExist:
        return JsonResponse({"error": "Product not found"}, status=404)

    return JsonResponse({
        "product_id": p.product_id,
        "product_name": p.product_name,
        "category": p.category,
        "description": p.description,
        "image_url": p.image_url,
        "price": str(p.price),
        "stock": p.stock,
        "product_status": p.product_status,
        "publisher_id": p.publisher_id,
    })

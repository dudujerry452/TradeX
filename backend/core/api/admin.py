"""
core/api/admin.py — 后台管理接口
"""

import uuid
from datetime import timedelta
from typing import Any, Optional

from django.db import transaction
from django.db.models import Q
from django.utils import timezone
from ninja import Router, Schema
from ninja.errors import HttpError

from core.models import (
    Order,
    OrderDetail,
    OrderLog,
    Product,
    ProductReview,
    RegisterReview,
    User,
)
from core.services.notification_service import NotificationService

from .common import auth

router = Router()


class AdminStatsOut(Schema):
    total_users: int
    pending_users: int
    total_products: int
    pending_products: int
    total_orders: int
    pending_orders: int
    shipped_orders: int
    completed_orders: int
    canceled_orders: int


class AdminUserOut(Schema):
    user_id: str
    username: str
    email: str
    real_name: str
    role: str
    register_status: str
    phone: str
    phone_display: Optional[str] = None
    address: str
    register_time: Any
    last_login_time: Optional[Any] = None


class AdminUserListOut(Schema):
    items: list[AdminUserOut]
    total: int


class AdminUserUpdateIn(Schema):
    role: Optional[str] = None
    register_status: Optional[str] = None
    real_name: Optional[str] = None
    phone_display: Optional[str] = None
    address: Optional[str] = None
    opinion: Optional[str] = None


class AdminProductOut(Schema):
    product_id: str
    product_name: str
    category: str
    category_name: str
    description: str
    image_url: str
    price: float
    stock: int
    product_status: str
    publisher_id: str
    publisher_name: str
    publish_time: Any
    review_time: Optional[Any] = None
    view_count: int
    sales_count: int
    favorite_count: int
    avg_rating: float


class AdminProductListOut(Schema):
    items: list[AdminProductOut]
    total: int


class AdminProductStatusIn(Schema):
    product_status: str
    opinion: Optional[str] = None


class AdminOrderProductOut(Schema):
    product_id: str
    product_name: str
    image_url: str
    quantity: int
    price: float
    subtotal: float


class AdminOrderOut(Schema):
    order_id: str
    buyer_id: str
    buyer_name: str
    seller_id: str
    seller_name: str
    total_amount: float
    order_status: str
    order_status_display: str
    order_time: Any
    ship_time: Optional[Any] = None
    receive_time: Optional[Any] = None
    pay_time: Optional[Any] = None
    logistics_company: Optional[str] = None
    logistics_number: Optional[str] = None
    address_snapshot: str
    phone_snapshot: str
    products: list[AdminOrderProductOut]


class AdminOrderListOut(Schema):
    items: list[AdminOrderOut]
    total: int


class AdminOrderStatusIn(Schema):
    order_status: str
    logistics_company: Optional[str] = None
    logistics_number: Optional[str] = None
    reason: Optional[str] = None


class AdminOrderLogOut(Schema):
    log_id: str
    action: str
    action_display: str
    from_status: Optional[str] = None
    to_status: str
    remark: str
    created_at: Any
    operator_name: Optional[str] = None


def _require_admin(request):
    user = request.auth
    if not user:
        raise HttpError(401, "请先登录")

    if user.role != User.RoleChoices.ADMIN:
        raise HttpError(403, "需要管理员权限")

    return user


def _serialize_user(user: User) -> dict[str, Any]:
    return {
        "user_id": user.user_id,
        "username": user.username,
        "email": user.email,
        "real_name": user.real_name,
        "role": user.role,
        "register_status": user.register_status,
        "phone": user.phone,
        "phone_display": user.phone_display,
        "address": user.address,
        "register_time": user.register_time,
        "last_login_time": user.last_login_time,
    }


def _serialize_product(product: Product) -> dict[str, Any]:
    category_name = product.category_ref.name if product.category_ref else (product.category or "")
    category_id = product.category_ref.category_id if product.category_ref else (product.category or "")

    return {
        "product_id": product.product_id,
        "product_name": product.product_name,
        "category": category_id,
        "category_name": category_name,
        "description": product.description,
        "image_url": product.image_url,
        "price": float(product.price),
        "stock": product.stock,
        "product_status": product.product_status,
        "publisher_id": product.publisher_id,
        "publisher_name": product.publisher.username if product.publisher_id else "",
        "publish_time": product.publish_time,
        "review_time": product.review_time,
        "view_count": product.view_count,
        "sales_count": product.sales_count,
        "favorite_count": product.favorite_count,
        "avg_rating": product.avg_rating,
    }


def _serialize_order(order: Order) -> dict[str, Any]:
    products = []
    for detail in order.details.all():
        products.append(
            {
                "product_id": detail.product.product_id,
                "product_name": detail.product.product_name,
                "image_url": detail.product.image_url,
                "quantity": detail.quantity,
                "price": float(detail.price_snapshot),
                "subtotal": float(detail.subtotal),
            }
        )

    return {
        "order_id": order.order_id,
        "buyer_id": order.buyer.user_id,
        "buyer_name": order.buyer.username,
        "seller_id": order.seller.user_id,
        "seller_name": order.seller.username,
        "total_amount": float(order.total_amount),
        "order_status": order.order_status,
        "order_status_display": order.get_order_status_display(),
        "order_time": order.order_time,
        "ship_time": order.ship_time,
        "receive_time": order.receive_time,
        "pay_time": order.pay_time,
        "logistics_company": order.logistics_company or None,
        "logistics_number": order.logistics_number or None,
        "address_snapshot": order.address_snapshot,
        "phone_snapshot": order.phone_snapshot,
        "products": products,
    }


def _serialize_order_log(log: OrderLog) -> dict[str, Any]:
    return {
        "log_id": log.log_id,
        "action": log.action,
        "action_display": log.get_action_display(),
        "from_status": log.from_status,
        "to_status": log.to_status,
        "remark": log.remark,
        "created_at": log.created_at,
        "operator_name": log.operator.username if log.operator else None,
    }


def _apply_product_review(admin_user: User, product: Product, data: AdminProductStatusIn):
    if data.product_status in [Product.StatusChoices.APPROVED, Product.StatusChoices.REJECTED]:
        ProductReview.objects.update_or_create(
            pending_product=product,
            defaults={
                "admin": admin_user,
                "result": data.product_status,
                "opinion": data.opinion or "",
            },
        )


def _apply_user_review(admin_user: User, user: User, data: AdminUserUpdateIn):
    if data.register_status in [User.RegisterStatusChoices.APPROVED, User.RegisterStatusChoices.REJECTED]:
        RegisterReview.objects.update_or_create(
            pending_user=user,
            defaults={
                "admin": admin_user,
                "result": data.register_status,
                "opinion": data.opinion or "",
            },
        )


@router.get("/stats/", response=AdminStatsOut, auth=auth, summary="获取后台统计")
def get_admin_stats(request):
    _require_admin(request)

    return {
        "total_users": User.objects.count(),
        "pending_users": User.objects.filter(register_status=User.RegisterStatusChoices.PENDING).count(),
        "total_products": Product.objects.count(),
        "pending_products": Product.objects.filter(product_status=Product.StatusChoices.PENDING).count(),
        "total_orders": Order.objects.count(),
        "pending_orders": Order.objects.filter(order_status__in=[Order.StatusChoices.PENDING_PAY, Order.StatusChoices.PENDING_SHIP]).count(),
        "shipped_orders": Order.objects.filter(order_status=Order.StatusChoices.SHIPPED).count(),
        "completed_orders": Order.objects.filter(order_status=Order.StatusChoices.COMPLETED).count(),
        "canceled_orders": Order.objects.filter(order_status=Order.StatusChoices.CANCELED).count(),
    }


@router.get("/users/", response=AdminUserListOut, auth=auth, summary="获取后台用户列表")
def list_admin_users(
    request,
    q: str = "",
    role: str = "",
    register_status: str = "",
    limit: int = 50,
    offset: int = 0,
):
    _require_admin(request)

    users = User.objects.all().order_by("-register_time")
    if q.strip():
        keyword = q.strip()
        users = users.filter(
            Q(user_id__icontains=keyword)
            | Q(username__icontains=keyword)
            | Q(email__icontains=keyword)
            | Q(real_name__icontains=keyword)
        )
    if role.strip():
        users = users.filter(role=role.strip())
    if register_status.strip():
        users = users.filter(register_status=register_status.strip())

    total = users.count()
    users = users[offset : offset + limit]

    return {
        "items": [_serialize_user(user) for user in users],
        "total": total,
    }


@router.patch("/users/{user_id}/", response=AdminUserOut, auth=auth, summary="更新后台用户信息")
def update_admin_user(request, user_id: str, data: AdminUserUpdateIn):
    admin_user = _require_admin(request)

    try:
        user = User.objects.get(user_id=user_id)
    except User.DoesNotExist:
        raise HttpError(404, "用户不存在")

    valid_roles = [choice[0] for choice in User.RoleChoices.choices]
    valid_statuses = [choice[0] for choice in User.RegisterStatusChoices.choices]

    update_fields = []
    if data.role is not None:
        if data.role not in valid_roles:
            raise HttpError(400, f"无效的角色值，可选: {', '.join(valid_roles)}")
        user.role = data.role
        update_fields.append("role")

    if data.register_status is not None:
        if data.register_status not in valid_statuses:
            raise HttpError(400, f"无效的审核状态，可选: {', '.join(valid_statuses)}")
        user.register_status = data.register_status
        update_fields.append("register_status")

    if data.real_name is not None:
        user.real_name = data.real_name
        update_fields.append("real_name")

    if data.phone_display is not None:
        user.phone_display = data.phone_display
        update_fields.append("phone_display")

    if data.address is not None:
        user.address = data.address
        update_fields.append("address")

    if update_fields:
        user.save(update_fields=update_fields)

    _apply_user_review(admin_user, user, data)

    return _serialize_user(user)


@router.get("/products/", response=AdminProductListOut, auth=auth, summary="获取后台商品列表")
def list_admin_products(
    request,
    q: str = "",
    status: str = "",
    category: str = "",
    limit: int = 50,
    offset: int = 0,
):
    _require_admin(request)

    products = Product.objects.select_related("publisher", "category_ref").all().order_by("-publish_time")
    if q.strip():
        keyword = q.strip()
        products = products.filter(
            Q(product_id__icontains=keyword)
            | Q(product_name__icontains=keyword)
            | Q(description__icontains=keyword)
            | Q(publisher__username__icontains=keyword)
        )
    if status.strip():
        products = products.filter(product_status=status.strip())
    if category.strip():
        products = products.filter(
            Q(category_ref__category_id=category.strip())
            | Q(category_ref__name=category.strip())
            | Q(category=category.strip())
        )

    total = products.count()
    products = products[offset : offset + limit]

    return {
        "items": [_serialize_product(product) for product in products],
        "total": total,
    }


@router.patch("/products/{product_id}/status/", response=AdminProductOut, auth=auth, summary="更新后台商品状态")
def update_admin_product_status(request, product_id: str, data: AdminProductStatusIn):
    admin_user = _require_admin(request)

    try:
        product = Product.objects.select_related("publisher", "category_ref").get(product_id=product_id)
    except Product.DoesNotExist:
        raise HttpError(404, "商品不存在")

    valid_statuses = [choice[0] for choice in Product.StatusChoices.choices]
    if data.product_status not in valid_statuses:
        raise HttpError(400, f"无效的状态值，可选: {', '.join(valid_statuses)}")

    product.product_status = data.product_status
    product.review_time = timezone.now()
    product.save(update_fields=["product_status", "review_time"])

    _apply_product_review(admin_user, product, data)

    return _serialize_product(product)


@router.get("/orders/", response=AdminOrderListOut, auth=auth, summary="获取后台订单列表")
def list_admin_orders(
    request,
    q: str = "",
    status: str = "",
    limit: int = 50,
    offset: int = 0,
):
    _require_admin(request)

    orders = Order.objects.select_related("buyer", "seller").prefetch_related("details", "details__product").all().order_by("-order_time")
    if q.strip():
        keyword = q.strip()
        orders = orders.filter(
            Q(order_id__icontains=keyword)
            | Q(buyer__username__icontains=keyword)
            | Q(seller__username__icontains=keyword)
            | Q(details__product__product_name__icontains=keyword)
        ).distinct()
    if status.strip():
        orders = orders.filter(order_status=status.strip())

    total = orders.count()
    orders = orders[offset : offset + limit]

    return {
        "items": [_serialize_order(order) for order in orders],
        "total": total,
    }


@router.get("/orders/{order_id}/", response=AdminOrderOut, auth=auth, summary="获取后台订单详情")
def get_admin_order(request, order_id: str):
    _require_admin(request)

    try:
        order = Order.objects.select_related("buyer", "seller").prefetch_related("details", "details__product").get(order_id=order_id)
    except Order.DoesNotExist:
        raise HttpError(404, "订单不存在")

    return _serialize_order(order)


@router.get("/orders/{order_id}/logs/", response=list[AdminOrderLogOut], auth=auth, summary="获取后台订单日志")
def get_admin_order_logs(request, order_id: str):
    _require_admin(request)

    try:
        order = Order.objects.get(order_id=order_id)
    except Order.DoesNotExist:
        raise HttpError(404, "订单不存在")

    logs = OrderLog.objects.filter(order=order).select_related("operator").order_by("-created_at")
    return [_serialize_order_log(log) for log in logs]


@router.patch("/orders/{order_id}/status/", response=AdminOrderOut, auth=auth, summary="更新后台订单状态")
def update_admin_order_status(request, order_id: str, data: AdminOrderStatusIn):
    admin_user = _require_admin(request)

    try:
        order = Order.objects.select_related("buyer", "seller").prefetch_related("details", "details__product").get(order_id=order_id)
    except Order.DoesNotExist:
        raise HttpError(404, "订单不存在")

    valid_statuses = [choice[0] for choice in Order.StatusChoices.choices]
    if data.order_status not in valid_statuses:
        raise HttpError(400, f"无效的订单状态，可选: {', '.join(valid_statuses)}")

    if data.order_status == order.order_status:
        return _serialize_order(order)

    if not order.can_transition_to(data.order_status):
        raise HttpError(400, f"订单状态不允许从 {order.order_status} 变更为 {data.order_status}")

    with transaction.atomic():
        old_status = order.order_status

        if data.order_status == Order.StatusChoices.PENDING_SHIP:
            order.order_status = Order.StatusChoices.PENDING_SHIP
            order.pay_time = timezone.now()
            order.save(update_fields=["order_status", "pay_time"])
            action = OrderLog.ActionChoices.PAY
            remark = data.reason or "管理员确认付款"
            NotificationService.notify_order_paid(order)

        elif data.order_status == Order.StatusChoices.SHIPPED:
            if not data.logistics_company or not data.logistics_number:
                raise HttpError(400, "发货时必须提供物流公司和物流单号")

            order.order_status = Order.StatusChoices.SHIPPED
            order.logistics_company = data.logistics_company
            order.logistics_number = data.logistics_number
            order.ship_time = timezone.now()
            order.auto_receive_time = timezone.now() + timedelta(days=7)
            order.save(update_fields=["order_status", "logistics_company", "logistics_number", "ship_time", "auto_receive_time"])
            action = OrderLog.ActionChoices.SHIP
            remark = data.reason or f"物流公司: {data.logistics_company}, 单号: {data.logistics_number}"
            NotificationService.notify_order_shipped(order)

        elif data.order_status == Order.StatusChoices.COMPLETED:
            if old_status != Order.StatusChoices.SHIPPED:
                raise HttpError(400, "只有已出货订单才能手动完成")

            order.order_status = Order.StatusChoices.COMPLETED
            order.receive_time = timezone.now()
            order.save(update_fields=["order_status", "receive_time"])

            for detail in order.details.all():
                detail.product.sales_count += detail.quantity
                detail.product.save(update_fields=["sales_count"])

            action = OrderLog.ActionChoices.RECEIVE
            remark = data.reason or "管理员确认收货"
            NotificationService.notify_order_completed(order)

        elif data.order_status == Order.StatusChoices.CANCELED:
            order.order_status = Order.StatusChoices.CANCELED
            order.cancel_reason = data.reason or "管理员取消订单"
            order.save(update_fields=["order_status", "cancel_reason"])

            for detail in order.details.all():
                detail.product.stock += detail.quantity
                detail.product.save(update_fields=["stock"])

            action = OrderLog.ActionChoices.CANCEL
            remark = data.reason or "管理员取消订单"
            NotificationService.notify_order_cancelled(order, admin_user)

        else:
            raise HttpError(400, "当前版本仅支持待发货、已发货、已完成和已取消状态处理")

        OrderLog.objects.create(
            log_id=f"ORDL{uuid.uuid4().hex[:16].upper()}",
            order=order,
            operator=admin_user,
            action=action,
            from_status=old_status,
            to_status=order.order_status,
            remark=remark,
        )

    order.refresh_from_db()
    order = Order.objects.select_related("buyer", "seller").prefetch_related("details", "details__product").get(order_id=order_id)
    return _serialize_order(order)
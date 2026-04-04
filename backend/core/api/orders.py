"""
core/api/orders.py — 订单相关接口
"""
import uuid
from typing import List, Optional
from datetime import timedelta
from ninja import Router
from ninja.errors import HttpError
from django.db import transaction
from django.utils import timezone

from core.models import Product, Order, OrderDetail, OrderLog, User
from core.services.notification_service import NotificationService
from .common import (
    auth,
    OrderOut,
    OrderCreateIn,
    OrderShipIn,
    OrderCancelIn,
    OrderPayIn,
    OrderListOut,
    OrderLogOut,
    OrderProductOut,
)

router = Router()


def _build_order_out(order: Order) -> dict:
    """构建订单输出数据"""
    products = []
    for detail in order.details.all():
        products.append({
            "product_id": detail.product.product_id,
            "product_name": detail.product.product_name,
            "image_url": detail.product.image_url,
            "quantity": detail.quantity,
            "price": float(detail.price_snapshot),
            "subtotal": float(detail.subtotal),
        })

    return {
        "order_id": order.order_id,
        "buyer_id": order.buyer.user_id,
        "seller_id": order.seller.user_id,
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


@router.post("/", response={201: OrderOut}, tags=["订单"], summary="创建订单", auth=auth)
def create_order(request, data: OrderCreateIn):
    """创建订单（直接购买）

    - 从商品直接创建订单
    - 自动扣减库存
    - 通知卖家
    """
    buyer = request.auth

    # 获取商品
    try:
        product = Product.objects.get(product_id=data.product_id)
    except Product.DoesNotExist:
        raise HttpError(404, "商品不存在")

    # 检查库存
    if product.stock < data.quantity:
        raise HttpError(400, f"库存不足，当前库存: {product.stock}")

    # 检查商品状态
    if product.product_status != Product.StatusChoices.APPROVED:
        raise HttpError(400, "商品未上架或已被下架")

    # 不能购买自己的商品
    if product.publisher.user_id == buyer.user_id:
        raise HttpError(400, "不能购买自己发布的商品")

    with transaction.atomic():
        # 创建订单
        order = Order.objects.create(
            order_id=f"ORD{uuid.uuid4().hex[:16].upper()}",
            buyer=buyer,
            seller=product.publisher,
            total_amount=product.price * data.quantity,
            address_snapshot=data.address or buyer.address,
            phone_snapshot=data.phone or (buyer.phone_display or ""),
            order_status=Order.StatusChoices.PENDING_PAY,
        )

        # 创建订单明细
        OrderDetail.objects.create(
            detail_id=f"ORDD{uuid.uuid4().hex[:16].upper()}",
            order=order,
            product=product,
            quantity=data.quantity,
            price_snapshot=product.price,
            subtotal=product.price * data.quantity,
        )

        # 扣减库存
        product.stock -= data.quantity
        product.save(update_fields=["stock"])

        # 创建订单日志
        OrderLog.objects.create(
            log_id=f"ORDL{uuid.uuid4().hex[:16].upper()}",
            order=order,
            operator=buyer,
            action=OrderLog.ActionChoices.CREATE,
            to_status=order.order_status,
            remark="创建订单",
        )

    # 通知卖家（在事务外，避免影响订单创建）
    NotificationService.notify_order_created(order)

    return 201, _build_order_out(order)


@router.get("/", response=OrderListOut, tags=["订单"], summary="获取订单列表", auth=auth)
def list_orders(request, status: Optional[str] = None, role: str = "buyer", limit: int = 20, offset: int = 0):
    """获取订单列表

    - role: buyer（我购买的）/ seller（我卖出的）
    - status: 可选，按状态筛选
    """
    user = request.auth

    # 根据角色过滤
    if role == "buyer":
        orders = Order.objects.filter(buyer=user)
    elif role == "seller":
        orders = Order.objects.filter(seller=user)
    else:
        raise HttpError(400, "role 参数必须是 buyer 或 seller")

    # 状态筛选
    if status:
        valid_statuses = [choice[0] for choice in Order.StatusChoices.choices]
        if status not in valid_statuses:
            raise HttpError(400, f"无效的状态值，可选: {', '.join(valid_statuses)}")
        orders = orders.filter(order_status=status)

    # 统计总数
    total = orders.count()

    # 排序和分页
    orders = orders.order_by("-order_time")[offset:offset + limit]

    # 预加载订单明细
    orders = orders.prefetch_related("details", "details__product")

    return {
        "orders": [_build_order_out(order) for order in orders],
        "total": total,
    }


@router.get("/{order_id}/", response=OrderOut, tags=["订单"], summary="获取订单详情", auth=auth)
def get_order(request, order_id: str):
    """获取订单详情"""
    user = request.auth

    try:
        order = Order.objects.prefetch_related("details", "details__product").get(order_id=order_id)
    except Order.DoesNotExist:
        raise HttpError(404, "订单不存在")

    # 检查权限（买家或卖家才能查看）
    if order.buyer.user_id != user.user_id and order.seller.user_id != user.user_id:
        raise HttpError(403, "无权查看此订单")

    return _build_order_out(order)


@router.post("/{order_id}/pay/", response=OrderOut, tags=["订单"], summary="支付订单", auth=auth)
def pay_order(request, order_id: str, data: OrderPayIn):
    """支付订单（模拟支付）

    - 将订单状态从 PENDING_PAY 变为 PENDING_SHIP
    - 记录支付时间
    """
    buyer = request.auth

    try:
        order = Order.objects.prefetch_related("details", "details__product").get(order_id=order_id)
    except Order.DoesNotExist:
        raise HttpError(404, "订单不存在")

    # 检查权限
    if order.buyer.user_id != buyer.user_id:
        raise HttpError(403, "只能支付自己的订单")

    # 检查状态
    if order.order_status != Order.StatusChoices.PENDING_PAY:
        raise HttpError(400, "订单状态不正确，无法支付")

    with transaction.atomic():
        old_status = order.order_status
        order.order_status = Order.StatusChoices.PENDING_SHIP
        order.pay_time = timezone.now()
        order.save(update_fields=["order_status", "pay_time"])

        # 创建订单日志
        OrderLog.objects.create(
            log_id=f"ORDL{uuid.uuid4().hex[:16].upper()}",
            order=order,
            operator=buyer,
            action=OrderLog.ActionChoices.PAY,
            from_status=old_status,
            to_status=order.order_status,
            remark=f"支付方式: {data.payment_method}",
        )

    # 通知买卖双方
    NotificationService.notify_order_paid(order)

    return _build_order_out(order)


@router.post("/{order_id}/ship/", response=OrderOut, tags=["订单"], summary="卖家发货", auth=auth)
def ship_order(request, order_id: str, data: OrderShipIn):
    """卖家发货

    - 将订单状态从 PENDING_SHIP 变为 SHIPPED
    - 填写物流信息
    """
    seller = request.auth

    try:
        order = Order.objects.prefetch_related("details", "details__product").get(order_id=order_id)
    except Order.DoesNotExist:
        raise HttpError(404, "订单不存在")

    # 检查权限
    if order.seller.user_id != seller.user_id:
        raise HttpError(403, "只能操作自己卖出的订单")

    # 检查状态
    if order.order_status != Order.StatusChoices.PENDING_SHIP:
        raise HttpError(400, "订单状态不正确，无法发货")

    with transaction.atomic():
        old_status = order.order_status
        order.order_status = Order.StatusChoices.SHIPPED
        order.logistics_company = data.logistics_company
        order.logistics_number = data.logistics_number
        order.ship_time = timezone.now()
        # 设置自动确认收货时间（7天后）
        order.auto_receive_time = timezone.now() + timedelta(days=7)
        order.save(update_fields=["order_status", "logistics_company", "logistics_number", "ship_time", "auto_receive_time"])

        # 创建订单日志
        OrderLog.objects.create(
            log_id=f"ORDL{uuid.uuid4().hex[:16].upper()}",
            order=order,
            operator=seller,
            action=OrderLog.ActionChoices.SHIP,
            from_status=old_status,
            to_status=order.order_status,
            remark=f"物流公司: {data.logistics_company}, 单号: {data.logistics_number}",
        )

    # 通知买家
    NotificationService.notify_order_shipped(order)

    return _build_order_out(order)


@router.post("/{order_id}/receive/", response=OrderOut, tags=["订单"], summary="确认收货", auth=auth)
def receive_order(request, order_id: str):
    """买家确认收货

    - 将订单状态从 SHIPPED 变为 COMPLETED
    """
    buyer = request.auth

    try:
        order = Order.objects.prefetch_related("details", "details__product").get(order_id=order_id)
    except Order.DoesNotExist:
        raise HttpError(404, "订单不存在")

    # 检查权限
    if order.buyer.user_id != buyer.user_id:
        raise HttpError(403, "只能操作自己购买的订单")

    # 检查状态
    if order.order_status != Order.StatusChoices.SHIPPED:
        raise HttpError(400, "订单状态不正确，无法确认收货")

    with transaction.atomic():
        old_status = order.order_status
        order.order_status = Order.StatusChoices.COMPLETED
        order.receive_time = timezone.now()
        order.save(update_fields=["order_status", "receive_time"])

        # 更新商品销量
        for detail in order.details.all():
            detail.product.sales_count += detail.quantity
            detail.product.save(update_fields=["sales_count"])

        # 创建订单日志
        OrderLog.objects.create(
            log_id=f"ORDL{uuid.uuid4().hex[:16].upper()}",
            order=order,
            operator=buyer,
            action=OrderLog.ActionChoices.RECEIVE,
            from_status=old_status,
            to_status=order.order_status,
            remark="买家确认收货",
        )

    # 通知卖家
    NotificationService.notify_order_completed(order)

    return _build_order_out(order)


@router.post("/{order_id}/cancel/", response=OrderOut, tags=["订单"], summary="取消订单", auth=auth)
def cancel_order(request, order_id: str, data: OrderCancelIn):
    """取消订单

    - 买家可以在 PENDING_PAY 状态取消
    - 卖家可以在 PENDING_SHIP 状态取消
    """
    user = request.auth

    try:
        order = Order.objects.prefetch_related("details", "details__product").get(order_id=order_id)
    except Order.DoesNotExist:
        raise HttpError(404, "订单不存在")

    # 检查权限
    is_buyer = order.buyer.user_id == user.user_id
    is_seller = order.seller.user_id == user.user_id

    if not is_buyer and not is_seller:
        raise HttpError(403, "无权操作此订单")

    # 检查状态权限
    if is_buyer and order.order_status not in [Order.StatusChoices.PENDING_PAY]:
        raise HttpError(400, "订单状态不正确，买家无法取消")

    if is_seller and order.order_status not in [Order.StatusChoices.PENDING_SHIP]:
        raise HttpError(400, "订单状态不正确，卖家无法取消")

    with transaction.atomic():
        old_status = order.order_status
        order.order_status = Order.StatusChoices.CANCELED
        order.cancel_reason = data.reason
        order.save(update_fields=["order_status", "cancel_reason"])

        # 恢复库存
        for detail in order.details.all():
            detail.product.stock += detail.quantity
            detail.product.save(update_fields=["stock"])

        # 创建订单日志
        OrderLog.objects.create(
            log_id=f"ORDL{uuid.uuid4().hex[:16].upper()}",
            order=order,
            operator=user,
            action=OrderLog.ActionChoices.CANCEL,
            from_status=old_status,
            to_status=order.order_status,
            remark=f"取消原因: {data.reason}" if data.reason else "取消订单",
        )

    # 通知对方
    NotificationService.notify_order_cancelled(order, user)

    return _build_order_out(order)


@router.get("/{order_id}/logs/", response=List[OrderLogOut], tags=["订单"], summary="获取订单日志", auth=auth)
def get_order_logs(request, order_id: str):
    """获取订单操作日志"""
    user = request.auth

    try:
        order = Order.objects.get(order_id=order_id)
    except Order.DoesNotExist:
        raise HttpError(404, "订单不存在")

    # 检查权限
    if order.buyer.user_id != user.user_id and order.seller.user_id != user.user_id:
        raise HttpError(403, "无权查看此订单")

    logs = OrderLog.objects.filter(order=order).order_by("-created_at")

    return [
        {
            "log_id": log.log_id,
            "action": log.action,
            "action_display": log.get_action_display(),
            "from_status": log.from_status,
            "to_status": log.to_status,
            "remark": log.remark,
            "created_at": log.created_at,
            "operator_name": log.operator.username if log.operator else None,
        }
        for log in logs
    ]

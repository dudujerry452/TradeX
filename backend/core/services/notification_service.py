"""
通知服务模块
负责创建和管理用户通知
"""
import uuid
from datetime import datetime, timedelta
from typing import Optional
from django.db import transaction
from core.models import Notification, Order, User


class NotificationService:
    """通知服务"""

    @staticmethod
    def create_notification(
        user: User,
        type: str,
        title: str,
        content: str,
        related_order: Optional[Order] = None
    ) -> Notification:
        """创建通知"""
        notification = Notification.objects.create(
            notification_id=f"NOTIF{uuid.uuid4().hex[:16].upper()}",
            user=user,
            type=type,
            title=title,
            content=content,
            related_order=related_order
        )
        return notification

    @staticmethod
    def notify_order_created(order: Order):
        """订单创建通知 - 通知卖家"""
        # 通知卖家有新订单
        product_names = ", ".join([
            detail.product.product_name
            for detail in order.details.all()[:2]  # 最多显示2个商品
        ])
        if order.details.count() > 2:
            product_names += f" 等{order.details.count()}件商品"

        NotificationService.create_notification(
            user=order.seller,
            type='ORDER',
            title='您有新订单',
            content=f'订单 #{order.order_id[-8:]}，商品：{product_names}，金额：¥{order.total_amount}',
            related_order=order
        )

    @staticmethod
    def notify_order_paid(order: Order):
        """订单支付通知 - 通知买卖双方"""
        # 通知卖家
        NotificationService.create_notification(
            user=order.seller,
            type='ORDER',
            title='订单已支付',
            content=f'订单 #{order.order_id[-8:]} 买家已支付 ¥{order.total_amount}，请及时发货',
            related_order=order
        )

        # 通知买家
        NotificationService.create_notification(
            user=order.buyer,
            type='ORDER',
            title='支付成功',
            content=f'订单 #{order.order_id[-8:]} 支付成功，等待卖家发货',
            related_order=order
        )

    @staticmethod
    def notify_order_shipped(order: Order):
        """订单发货通知 - 通知买家"""
        logistics_info = ""
        if order.logistics_company and order.logistics_number:
            logistics_info = f"，物流：{order.logistics_company} {order.logistics_number}"

        NotificationService.create_notification(
            user=order.buyer,
            type='ORDER',
            title='订单已发货',
            content=f'订单 #{order.order_id[-8:]} 已发货{logistics_info}，请注意查收',
            related_order=order
        )

    @staticmethod
    def notify_order_completed(order: Order):
        """订单完成通知 - 通知买卖双方"""
        # 通知卖家
        NotificationService.create_notification(
            user=order.seller,
            type='ORDER',
            title='订单已完成',
            content=f'订单 #{order.order_id[-8:]} 买家已确认收货，交易完成',
            related_order=order
        )

        # 通知买家
        NotificationService.create_notification(
            user=order.buyer,
            type='ORDER',
            title='交易完成',
            content=f'订单 #{order.order_id[-8:]} 交易完成，感谢您的购买',
            related_order=order
        )

    @staticmethod
    def notify_order_cancelled(order: Order, operator: Optional[User] = None):
        """订单取消通知 - 通知买卖双方"""
        cancel_info = ""
        if order.cancel_reason:
            cancel_info = f"，原因：{order.cancel_reason}"

        operator_name = operator.username if operator else "系统"

        # 通知卖家（如果不是卖家自己取消的）
        if not operator or operator.user_id != order.seller.user_id:
            NotificationService.create_notification(
                user=order.seller,
                type='ORDER',
                title='订单已取消',
                content=f'订单 #{order.order_id[-8:]} 已被{operator_name}取消{cancel_info}',
                related_order=order
            )

        # 通知买家（如果不是买家自己取消的）
        if not operator or operator.user_id != order.buyer.user_id:
            NotificationService.create_notification(
                user=order.buyer,
                type='ORDER',
                title='订单已取消',
                content=f'订单 #{order.order_id[-8:]} 已被{operator_name}取消{cancel_info}',
                related_order=order
            )

    @staticmethod
    def notify_auto_receive_warning(order: Order, days_remaining: int):
        """自动确认收货预警通知"""
        NotificationService.create_notification(
            user=order.buyer,
            type='ORDER',
            title='自动确认收货提醒',
            content=f'订单 #{order.order_id[-8:]} 将在{days_remaining}天后自动确认收货，如未收到货请及时联系卖家',
            related_order=order
        )

    @staticmethod
    def mark_as_read(notification_id: str, user: User) -> bool:
        """标记通知为已读"""
        try:
            notification = Notification.objects.get(
                notification_id=notification_id,
                user=user
            )
            notification.is_read = True
            notification.save(update_fields=['is_read'])
            return True
        except Notification.DoesNotExist:
            return False

    @staticmethod
    def mark_all_as_read(user: User) -> int:
        """标记用户所有通知为已读，返回更新的数量"""
        count = Notification.objects.filter(
            user=user,
            is_read=False
        ).update(is_read=True)
        return count

    @staticmethod
    def get_unread_count(user: User) -> int:
        """获取用户未读通知数量"""
        return Notification.objects.filter(
            user=user,
            is_read=False
        ).count()

    @staticmethod
    def delete_notification(notification_id: str, user: User) -> bool:
        """删除通知"""
        try:
            notification = Notification.objects.get(
                notification_id=notification_id,
                user=user
            )
            notification.delete()
            return True
        except Notification.DoesNotExist:
            return False

"""
core/api/notifications.py — 通知相关接口
"""
from typing import List, Optional
from ninja import Router
from ninja.errors import HttpError

from core.models import Notification
from core.services.notification_service import NotificationService
from .common import auth, NotificationOut, UnreadCountOut, SuccessOut

router = Router()


@router.get("/", response=List[NotificationOut], tags=["通知"], summary="获取通知列表", auth=auth)
def list_notifications(request, is_read: Optional[bool] = None, limit: int = 20, offset: int = 0):
    """获取当前用户的通知列表"""
    user = request.auth

    notifications = Notification.objects.filter(user=user)

    # 已读筛选
    if is_read is not None:
        notifications = notifications.filter(is_read=is_read)

    # 排序和分页
    notifications = notifications.order_by("-created_at")[offset:offset + limit]

    return [
        {
            "notification_id": n.notification_id,
            "type": n.type,
            "type_display": n.get_type_display(),
            "title": n.title,
            "content": n.content,
            "related_order_id": n.related_order.order_id if n.related_order else None,
            "is_read": n.is_read,
            "created_at": n.created_at,
        }
        for n in notifications
    ]


@router.get("/unread-count/", response=UnreadCountOut, tags=["通知"], summary="获取未读通知数量", auth=auth)
def get_unread_count(request):
    """获取当前用户的未读通知数量"""
    user = request.auth
    count = NotificationService.get_unread_count(user)
    return {"count": count}


@router.post("/{notification_id}/read/", response=SuccessOut, tags=["通知"], summary="标记通知已读", auth=auth)
def mark_notification_read(request, notification_id: str):
    """标记单个通知为已读"""
    user = request.auth

    success = NotificationService.mark_as_read(notification_id, user)

    if not success:
        raise HttpError(404, "通知不存在")

    return {"success": True, "message": "已标记为已读"}


@router.post("/read-all/", response=SuccessOut, tags=["通知"], summary="标记所有通知已读", auth=auth)
def mark_all_read(request):
    """标记所有通知为已读"""
    user = request.auth

    count = NotificationService.mark_all_as_read(user)

    return {"success": True, "message": f"已标记 {count} 条通知为已读"}


@router.delete("/{notification_id}/", response=SuccessOut, tags=["通知"], summary="删除通知", auth=auth)
def delete_notification(request, notification_id: str):
    """删除通知"""
    user = request.auth

    success = NotificationService.delete_notification(notification_id, user)

    if not success:
        raise HttpError(404, "通知不存在")

    return {"success": True, "message": "通知已删除"}

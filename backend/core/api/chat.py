"""
core/api/chat.py — 聊天相关 REST API
提供对话列表、历史消息、已读标记等功能
"""

from datetime import datetime
from typing import List, Optional
from django.db import models
from django.db.models import Q, Max, Count
from ninja import Router, Schema
from .common import auth, SuccessOut

router = Router(auth=auth)


# ── Schemas ────────────────────────────────────────────────────────────────

class ConversationOut(Schema):
    """对话列表项输出"""
    user_id: str
    username: str
    avatar_url: str
    last_message: str
    last_message_time: datetime
    unread_count: int
    product_id: Optional[str] = None
    product_name: Optional[str] = None
    order_id: Optional[str] = None


class ChatMessageOut(Schema):
    """聊天消息输出"""
    message_id: str
    sender_id: str
    receiver_id: str
    content: str
    is_read: bool
    created_at: datetime
    product_id: Optional[str] = None
    order_id: Optional[str] = None


class ChatMessageListOut(Schema):
    """消息列表输出"""
    messages: List[ChatMessageOut]
    total: int
    has_more: bool


class SendMessageIn(Schema):
    """发送消息输入（HTTP API 方式）"""
    content: str
    product_id: Optional[str] = None
    order_id: Optional[str] = None


class MarkReadIn(Schema):
    """标记已读输入"""
    message_ids: List[str]


class UnreadCountOut(Schema):
    """未读消息数输出"""
    count: int


# ── API Endpoints ──────────────────────────────────────────────────────────

@router.get("/conversations", response=List[ConversationOut])
def get_conversations(request):
    """
    获取当前用户的所有对话列表
    按最后消息时间倒序排列
    """
    from core.models import ChatMessage, User

    user = request.auth

    # 获取所有与该用户相关的消息，按对话分组
    # 使用子查询找到每个对话的最后一条消息
    sent_messages = ChatMessage.objects.filter(sender=user).values('receiver').annotate(
        last_time=Max('created_at')
    )
    received_messages = ChatMessage.objects.filter(receiver=user).values('sender').annotate(
        last_time=Max('created_at')
    )

    # 收集对话用户ID
    conversation_users = set()
    for msg in sent_messages:
        conversation_users.add(msg['receiver'])
    for msg in received_messages:
        conversation_users.add(msg['sender'])

    conversations = []
    for other_user_id in conversation_users:
        try:
            other_user = User.objects.get(user_id=other_user_id)

            # 获取最后一条消息
            last_msg = ChatMessage.objects.filter(
                (Q(sender=user, receiver=other_user) |
                 Q(sender=other_user, receiver=user))
            ).order_by('-created_at').first()

            if not last_msg:
                continue

            # 计算未读数（对方发送的未读消息）
            unread_count = ChatMessage.objects.filter(
                sender=other_user,
                receiver=user,
                is_read=False
            ).count()

            # 获取关联的商品信息（如果有）
            product_id = None
            product_name = None
            if last_msg.related_product:
                product_id = last_msg.related_product.product_id
                product_name = last_msg.related_product.product_name

            # 获取关联的订单信息（如果有）
            order_id = None
            if last_msg.related_order:
                order_id = last_msg.related_order.order_id

            conversations.append({
                "user_id": other_user.user_id,
                "username": other_user.username,
                "avatar_url": other_user.image_url or "",
                "last_message": last_msg.content[:100],  # 截断显示
                "last_message_time": last_msg.created_at,
                "unread_count": unread_count,
                "product_id": product_id,
                "product_name": product_name,
                "order_id": order_id
            })

        except User.DoesNotExist:
            continue

    # 按最后消息时间倒序排列
    conversations.sort(key=lambda x: x['last_message_time'], reverse=True)

    return conversations


@router.get("/messages/{user_id}", response=ChatMessageListOut)
def get_messages(request, user_id: str, before_id: Optional[str] = None, limit: int = 20):
    """
    获取与指定用户的聊天记录

    - user_id: 对方用户ID
    - before_id: 分页用，获取该消息之前的消息
    - limit: 每页数量，默认20
    """
    from core.models import ChatMessage, User

    current_user = request.auth

    try:
        other_user = User.objects.get(user_id=user_id)
    except User.DoesNotExist:
        return {"messages": [], "total": 0, "has_more": False}

    # 构建查询：双方之间的消息
    queryset = ChatMessage.objects.filter(
        (Q(sender=current_user, receiver=other_user) |
         Q(sender=other_user, receiver=current_user))
    )

    # 分页
    if before_id:
        try:
            before_msg = ChatMessage.objects.get(message_id=before_id)
            queryset = queryset.filter(created_at__lt=before_msg.created_at)
        except ChatMessage.DoesNotExist:
            pass

    # 获取消息（按时间倒序，最新的在前面）
    messages = queryset.order_by('-created_at')[:limit + 1]

    has_more = len(messages) > limit
    messages = list(messages[:limit])

    # 倒序排列（最早的在前，用于显示）
    messages.reverse()

    result = []
    for msg in messages:
        result.append({
            "message_id": msg.message_id,
            "sender_id": msg.sender.user_id,
            "receiver_id": msg.receiver.user_id,
            "content": msg.content,
            "is_read": msg.is_read,
            "created_at": msg.created_at,
            "product_id": msg.related_product.product_id if msg.related_product else None,
            "order_id": msg.related_order.order_id if msg.related_order else None
        })

    return {
        "messages": result,
        "total": len(result),
        "has_more": has_more
    }


@router.post("/messages/{user_id}/read", response=SuccessOut)
def mark_conversation_as_read(request, user_id: str):
    """
    将与指定用户的对话中所有未读消息标记为已读
    """
    from core.models import ChatMessage, User

    current_user = request.auth

    try:
        other_user = User.objects.get(user_id=user_id)
    except User.DoesNotExist:
        return {"success": False, "message": "User not found"}

    # 更新接收者为当前用户、发送者为对方、未读的消息
    updated_count = ChatMessage.objects.filter(
        sender=other_user,
        receiver=current_user,
        is_read=False
    ).update(is_read=True)

    return {
        "success": True,
        "message": f"Marked {updated_count} messages as read"
    }


@router.post("/messages/read", response=SuccessOut)
def mark_messages_as_read(request, payload: MarkReadIn):
    """
    批量标记指定消息为已读
    """
    from core.models import ChatMessage

    current_user = request.auth

    updated_count = ChatMessage.objects.filter(
        message_id__in=payload.message_ids,
        receiver=current_user,
        is_read=False
    ).update(is_read=True)

    return {
        "success": True,
        "message": f"Marked {updated_count} messages as read"
    }


@router.delete("/messages/{message_id}", response=SuccessOut)
def delete_message(request, message_id: str):
    """
    删除单条消息（只能删除自己发送的消息）
    """
    from core.models import ChatMessage

    current_user = request.auth

    try:
        message = ChatMessage.objects.get(
            message_id=message_id,
            sender=current_user
        )
        message.delete()
        return {"success": True, "message": "Message deleted"}
    except ChatMessage.DoesNotExist:
        return {"success": False, "message": "Message not found or not authorized"}


@router.get("/unread-count", response=UnreadCountOut)
def get_unread_count(request):
    """
    获取当前用户的未读消息总数
    """
    from core.models import ChatMessage

    user = request.auth

    count = ChatMessage.objects.filter(
        receiver=user,
        is_read=False
    ).count()

    return {"count": count}


@router.get("/sync", response=ChatMessageListOut)
def sync_messages(request, last_message_id: Optional[str] = None):
    """
    同步消息（用于离线后重新连接时获取新消息）

    - last_message_id: 客户端最后收到的消息ID，获取此消息之后的所有新消息
    """
    from core.models import ChatMessage

    user = request.auth

    # 获取涉及当前用户的所有消息
    queryset = ChatMessage.objects.filter(
        Q(sender=user) | Q(receiver=user)
    )

    # 如果提供了最后消息ID，只获取之后的消息
    if last_message_id:
        try:
            last_msg = ChatMessage.objects.get(message_id=last_message_id)
            queryset = queryset.filter(created_at__gt=last_msg.created_at)
        except ChatMessage.DoesNotExist:
            pass

    # 限制最多返回100条
    messages = queryset.order_by('created_at')[:100]

    result = []
    for msg in messages:
        result.append({
            "message_id": msg.message_id,
            "sender_id": msg.sender.user_id,
            "receiver_id": msg.receiver.user_id,
            "content": msg.content,
            "is_read": msg.is_read,
            "created_at": msg.created_at,
            "product_id": msg.related_product.product_id if msg.related_product else None,
            "order_id": msg.related_order.order_id if msg.related_order else None
        })

    return {
        "messages": result,
        "total": len(result),
        "has_more": False
    }

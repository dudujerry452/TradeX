"""
core/consumers.py — WebSocket Chat Consumer
实时聊天 WebSocket 消费者，支持 JWT 认证、心跳检测、消息转发
"""

import json
import jwt
import uuid
from datetime import datetime
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.conf import settings

JWT_SECRET = getattr(settings, 'SECRET_KEY', 'your-secret-key')


class ChatConsumer(AsyncWebsocketConsumer):
    """
    聊天 WebSocket 消费者

    连接地址: ws://localhost:8001/ws/chat/?token=<JWT_TOKEN>

    消息格式:
    - 发送: {"type": "chat_message", "to": "user_id", "content": "message", "product_id": "", "order_id": ""}
    - 心跳: {"type": "ping"} -> 回复: {"type": "pong"}
    - 系统: {"type": "system", "message": "..."}
    """

    # 类级别存储：用户ID -> 连接数
    user_connections = {}

    async def connect(self):
        """处理 WebSocket 连接，进行 JWT 认证"""
        self.user = None
        self.user_id = None
        self.user_group_name = None
        self.heartbeat_missed = 0
        self.last_heartbeat = datetime.now()

        # 从查询参数获取 token
        query_string = self.scope.get('query_string', b'').decode()
        token = None
        if 'token=' in query_string:
            token = query_string.split('token=')[1].split('&')[0]

        if not token:
            await self.close(code=4001)
            return

        # 验证 JWT Token
        try:
            payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
            self.user_id = payload.get("user_id")

            if not self.user_id:
                await self.close(code=4002)
                return

        except jwt.ExpiredSignatureError:
            await self.close(code=4003)
            return
        except jwt.InvalidTokenError:
            await self.close(code=4004)
            return

        # 检查并发连接数限制（单个用户最多 3 个连接）
        current_count = ChatConsumer.user_connections.get(self.user_id, 0)
        if current_count >= 3:
            await self.close(code=4005)
            return

        # 增加连接计数
        ChatConsumer.user_connections[self.user_id] = current_count + 1

        # 设置用户组名
        self.user_group_name = f"user_{self.user_id}"

        # 接受连接
        await self.accept()

        # 加入用户专属组（用于接收消息）
        await self.channel_layer.group_add(
            self.user_group_name,
            self.channel_name
        )

        # 发送连接成功消息
        await self.send(text_data=json.dumps({
            "type": "system",
            "message": "Connected successfully",
            "user_id": self.user_id
        }))

    async def disconnect(self, close_code):
        """处理断开连接"""
        if self.user_id:
            # 减少连接计数
            current_count = ChatConsumer.user_connections.get(self.user_id, 0)
            if current_count > 0:
                ChatConsumer.user_connections[self.user_id] = current_count - 1

            # 离开用户组
            if self.user_group_name:
                await self.channel_layer.group_discard(
                    self.user_group_name,
                    self.channel_name
                )

    async def receive(self, text_data):
        """接收客户端消息"""
        try:
            data = json.loads(text_data)
            msg_type = data.get('type', 'chat_message')

            if msg_type == 'ping':
                # 心跳响应
                self.heartbeat_missed = 0
                self.last_heartbeat = datetime.now()
                await self.send(text_data=json.dumps({
                    "type": "pong",
                    "timestamp": datetime.now().isoformat()
                }))

            elif msg_type == 'chat_message':
                # 处理聊天消息
                await self.handle_chat_message(data)

            elif msg_type == 'read_receipt':
                # 处理已读回执
                await self.handle_read_receipt(data)

            elif msg_type == 'typing':
                # 处理正在输入状态
                await self.handle_typing_status(data)

        except json.JSONDecodeError:
            await self.send(text_data=json.dumps({
                "type": "error",
                "message": "Invalid JSON format"
            }))
        except Exception as e:
            await self.send(text_data=json.dumps({
                "type": "error",
                "message": str(e)
            }))

    async def handle_chat_message(self, data):
        """处理聊天消息：保存到数据库并转发给接收者"""
        to_user_id = data.get('to')
        content = data.get('content', '').strip()
        product_id = data.get('product_id')
        order_id = data.get('order_id')

        if not to_user_id:
            await self.send(text_data=json.dumps({
                "type": "error",
                "message": "Missing 'to' field"
            }))
            return

        if not content:
            await self.send(text_data=json.dumps({
                "type": "error",
                "message": "Content cannot be empty"
            }))
            return

        # 生成消息 ID
        message_id = f"msg_{uuid.uuid4().hex[:20]}"

        # 保存消息到数据库
        try:
            await self.save_message(
                message_id=message_id,
                sender_id=self.user_id,
                receiver_id=to_user_id,
                content=content,
                product_id=product_id,
                order_id=order_id
            )
        except Exception as e:
            await self.send(text_data=json.dumps({
                "type": "error",
                "message": f"Failed to save message: {str(e)}"
            }))
            return

        # 构建消息数据
        message_data = {
            "type": "chat_message",
            "message_id": message_id,
            "from": self.user_id,
            "content": content,
            "created_at": datetime.now().isoformat(),
            "product_id": product_id,
            "order_id": order_id
        }

        # 发送给接收者
        await self.channel_layer.group_send(
            f"user_{to_user_id}",
            {
                "type": "chat_message",
                "message": message_data
            }
        )

        # 发送回执给发送者
        await self.send(text_data=json.dumps({
            "type": "message_sent",
            "message_id": message_id,
            "to": to_user_id,
            "timestamp": datetime.now().isoformat()
        }))

    async def handle_read_receipt(self, data):
        """处理消息已读回执"""
        message_id = data.get('message_id')
        if message_id:
            try:
                await self.mark_message_as_read(message_id, self.user_id)

                # 通知发送者消息已读
                await self.channel_layer.group_send(
                    f"user_{self.user_id}",
                    {
                        "type": "read_receipt",
                        "message_id": message_id,
                        "read_by": self.user_id
                    }
                )
            except Exception as e:
                pass  # 静默处理已读回执错误

    async def handle_typing_status(self, data):
        """处理正在输入状态"""
        to_user_id = data.get('to')
        is_typing = data.get('typing', False)

        if to_user_id:
            await self.channel_layer.group_send(
                f"user_{to_user_id}",
                {
                    "type": "typing_status",
                    "from": self.user_id,
                    "typing": is_typing
                }
            )

    # Channel Layer 事件处理器

    async def chat_message(self, event):
        """接收来自 channel_layer 的消息并发送给客户端"""
        message = event['message']
        await self.send(text_data=json.dumps(message))

    async def read_receipt(self, event):
        """转发已读回执给客户端"""
        await self.send(text_data=json.dumps({
            "type": "read_receipt",
            "message_id": event['message_id'],
            "read_by": event['read_by']
        }))

    async def typing_status(self, event):
        """转发输入状态给客户端"""
        await self.send(text_data=json.dumps({
            "type": "typing",
            "from": event['from'],
            "typing": event['typing']
        }))

    # 数据库操作（同步包装为异步）

    @database_sync_to_async
    def save_message(self, message_id, sender_id, receiver_id, content, product_id=None, order_id=None):
        """保存消息到数据库"""
        from core.models import ChatMessage, User, Product, Order

        sender = User.objects.get(user_id=sender_id)
        receiver = User.objects.get(user_id=receiver_id)

        kwargs = {
            'message_id': message_id,
            'sender': sender,
            'receiver': receiver,
            'content': content,
            'is_read': False
        }

        if product_id:
            try:
                kwargs['related_product'] = Product.objects.get(product_id=product_id)
            except Product.DoesNotExist:
                pass

        if order_id:
            try:
                kwargs['related_order'] = Order.objects.get(order_id=order_id)
            except Order.DoesNotExist:
                pass

        return ChatMessage.objects.create(**kwargs)

    @database_sync_to_async
    def mark_message_as_read(self, message_id, user_id):
        """标记消息为已读"""
        from core.models import ChatMessage
        try:
            message = ChatMessage.objects.get(
                message_id=message_id,
                receiver_id=user_id
            )
            message.is_read = True
            message.save(update_fields=['is_read'])
            return True
        except ChatMessage.DoesNotExist:
            return False

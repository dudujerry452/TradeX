/// 聊天消息模型
class ChatMessage {
  final String messageId;
  final String senderId;
  final String receiverId;
  final String content;
  final bool isRead;
  final DateTime createdAt;
  final String? productId;
  final String? orderId;

  ChatMessage({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.isRead = false,
    required this.createdAt,
    this.productId,
    this.orderId,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: json['message_id'] ?? json['messageId'] ?? '',
      senderId: json['sender_id'] ?? json['senderId'] ?? json['from'] ?? '',
      receiverId: json['receiver_id'] ?? json['receiverId'] ?? json['to'] ?? '',
      content: json['content'] ?? '',
      isRead: json['is_read'] ?? json['isRead'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      productId: json['product_id'] ?? json['productId'],
      orderId: json['order_id'] ?? json['orderId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message_id': messageId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'product_id': productId,
      'order_id': orderId,
    };
  }

  ChatMessage copyWith({
    String? messageId,
    String? senderId,
    String? receiverId,
    String? content,
    bool? isRead,
    DateTime? createdAt,
    String? productId,
    String? orderId,
  }) {
    return ChatMessage(
      messageId: messageId ?? this.messageId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      productId: productId ?? this.productId,
      orderId: orderId ?? this.orderId,
    );
  }
}

/// 对话列表项模型
class Conversation {
  final String userId;
  final String username;
  final String avatarUrl;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final String? productId;
  final String? productName;
  final String? orderId;

  Conversation({
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.productId,
    this.productName,
    this.orderId,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      userId: json['user_id'] ?? '',
      username: json['username'] ?? '',
      avatarUrl: json['avatar_url'] ?? '',
      lastMessage: json['last_message'] ?? '',
      lastMessageTime: json['last_message_time'] != null
          ? DateTime.parse(json['last_message_time'])
          : DateTime.now(),
      unreadCount: json['unread_count'] ?? 0,
      productId: json['product_id'],
      productName: json['product_name'],
      orderId: json['order_id'],
    );
  }
}

/// 连接状态枚举
enum ChatConnectionStatus {
  connecting,    // 正在连接
  connected,     // 已连接
  disconnected,  // 断开（可重连）
  reconnecting,  // 正在重连
  error,         // 错误
}

/// WebSocket 消息类型
enum WebSocketMessageType {
  chatMessage,   // 聊天消息
  ping,          // 心跳请求
  pong,          // 心跳响应
  system,        // 系统消息
  messageSent,   // 发送回执
  readReceipt,   // 已读回执
  typing,        // 输入状态
  error,         // 错误
}

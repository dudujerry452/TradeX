import 'dart:async';
import 'package:flutter/material.dart';
import '../../icons.dart';
import '../../models/chat_message.dart';
import '../../services/chat_service.dart';
import '../../services/chat_api_service.dart';
import '../../services/chat_local_storage.dart';
import '../../auth_manager.dart';
import 'chat_room_page.dart';

/// 对话列表页面
class ConversationListPage extends StatefulWidget {
  const ConversationListPage({super.key});

  @override
  State<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends State<ConversationListPage> {
  final ChatService _chatService = ChatService();
  List<Conversation> _conversations = [];
  bool _isLoading = true;
  String? _currentUserId;
  StreamSubscription? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _currentUserId = await AuthManager.getUserId();

    // 连接 WebSocket
    await _chatService.connect();

    // 订阅新消息
    _messageSubscription = _chatService.messageStream.listen(_onNewMessage);

    // 加载对话列表
    await _loadConversations();

    // 获取未读数
    await _loadUnreadCount();
  }

  void _onNewMessage(ChatMessage message) {
    // 收到新消息时刷新列表（无论是接收还是发送的消息）
    // 只要消息涉及当前用户，就刷新对话列表
    if (message.receiverId == _currentUserId || message.senderId == _currentUserId) {
      _loadConversations();
      _loadUnreadCount();
    }
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 先加载本地缓存
      final cached = await ChatLocalStorage.getCachedConversations();
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _conversations = cached;
        });
      }

      // 从服务器加载
      final result = await ChatApiService.getConversations();

      if (result['success'] && mounted) {
        final conversations = result['data'] as List<Conversation>;
        setState(() {
          _conversations = conversations;
          _isLoading = false;
        });

        // 缓存到本地
        await ChatLocalStorage.saveConversations(conversations);
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('加载对话列表失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUnreadCount() async {
    // 未读数已在每个对话项中显示，此处不需要额外处理
    // 如需显示总未读数，可以在这里更新状态
  }

  /// 从本地消息构建对话列表（用于发送新消息后立即显示）
  Future<void> _buildConversationsFromLocalMessages() async {
    if (_currentUserId == null) return;

    // 直接重新加载对话列表
    await _loadConversations();
  }

  Future<void> _deleteConversation(String userId) async {
    // 删除与该用户的所有本地消息
    // TODO: 添加删除对话的 API

    setState(() {
      _conversations.removeWhere((c) => c.userId == userId);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('对话已删除')),
      );
    }
  }

  void _openChat(Conversation conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoomPage(
          userId: conversation.userId,
          username: conversation.username,
          avatarUrl: conversation.avatarUrl,
          productId: conversation.productId,
          productName: conversation.productName,
          orderId: conversation.orderId,
        ),
      ),
    ).then((result) {
      // 返回后刷新列表
      _loadConversations();
      _loadUnreadCount();

      // 如果有新发送的消息（result 为 true），立即从本地构建对话
      if (result == true) {
        _buildConversationsFromLocalMessages();
      }
    });
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: RefreshIndicator(
        onRefresh: _loadConversations,
        color: const Color(0xFFCE965B),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _conversations.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCE965B)),
        ),
      );
    }

    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(60),
              ),
              child: HeroIcons.chatBubbleAlt(
                size: 50,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '暂无对话',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '与卖家的聊天记录会显示在这里',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conversation = _conversations[index];
        return _buildConversationCard(conversation);
      },
    );
  }

  Widget _buildConversationCard(Conversation conversation) {
    return Dismissible(
      key: Key(conversation.userId),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      onDismissed: (_) => _deleteConversation(conversation.userId),
      child: GestureDetector(
        onTap: () => _openChat(conversation),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // 头像
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: conversation.avatarUrl.isNotEmpty
                        ? NetworkImage(conversation.avatarUrl)
                        : null,
                    child: conversation.avatarUrl.isEmpty
                        ? Text(
                            conversation.username.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2C),
                            ),
                          )
                        : null,
                  ),
                  if (conversation.unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Text(
                          conversation.unreadCount > 99
                              ? '99+'
                              : conversation.unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            conversation.username,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: conversation.unreadCount > 0
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: const Color(0xFF1A1A2C),
                            ),
                          ),
                        ),
                        Text(
                          _formatTime(conversation.lastMessageTime),
                          style: TextStyle(
                            fontSize: 12,
                            color: conversation.unreadCount > 0
                                ? const Color(0xFFCE965B)
                                : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // 关联商品/订单提示
                    if (conversation.productName != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.shopping_bag,
                              size: 12,
                              color: const Color(0xFFCE965B).withOpacity(0.7),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                conversation.productName!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: const Color(0xFFCE965B).withOpacity(0.7),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // 最后消息
                    Text(
                      conversation.lastMessage,
                      style: TextStyle(
                        fontSize: 13,
                        color: conversation.unreadCount > 0
                            ? const Color(0xFF1A1A2C)
                            : Colors.grey.shade500,
                        fontWeight: conversation.unreadCount > 0
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDay = DateTime(time.year, time.month, time.day);

    if (messageDay == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (messageDay == yesterday) {
      return '昨天';
    } else if (now.difference(messageDay).inDays < 7) {
      final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[time.weekday - 1];
    } else {
      return '${time.month}/${time.day}';
    }
  }
}

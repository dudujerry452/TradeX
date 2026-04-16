import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../services/chat_service.dart';
import '../../services/chat_api_service.dart';
import '../../services/chat_local_storage.dart';
import '../../auth_manager.dart';

/// 聊天详情页面（气泡界面）
class ChatRoomPage extends StatefulWidget {
  final String userId;
  final String username;
  final String? avatarUrl;
  final String? productId;
  final String? productName;
  final String? orderId;

  const ChatRoomPage({
    super.key,
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.productId,
    this.productName,
    this.orderId,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  String? _currentUserId;
  bool _isLoading = true;
  bool _hasMore = true;
  bool _isTyping = false;
  bool _otherUserTyping = false;
  Timer? _typingTimer;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _typingSubscription;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    _currentUserId = await AuthManager.getUserId();

    // 连接 WebSocket
    await _chatService.connect();

    // 订阅消息流
    _messageSubscription = _chatService.messageStream.listen(_onNewMessage);
    _typingSubscription = _chatService.typingStream.listen(_onTypingStatus);

    // 加载历史消息
    await _loadMessages();

    // 标记为已读
    await _markAsRead();

    setState(() {
      _isLoading = false;
    });

    // 滚动到底部
    _scrollToBottom();
  }

  void _onNewMessage(ChatMessage message) {
    // 只处理与当前对话相关的消息
    if ((message.senderId == widget.userId && message.receiverId == _currentUserId) ||
        (message.senderId == _currentUserId && message.receiverId == widget.userId)) {
      setState(() {
        _messages.add(message);
      });
      _scrollToBottom();

      // 保存到本地
      ChatLocalStorage.saveMessage(message);

      // 如果是对方发送的消息，发送已读回执
      if (message.senderId == widget.userId) {
        _chatService.sendReadReceipt(message.messageId);
      }
    }
  }

  void _onTypingStatus(Map<String, dynamic> data) {
    if (data['from'] == widget.userId) {
      setState(() {
        _otherUserTyping = data['typing'] ?? false;
      });
    }
  }

  Future<void> _loadMessages() async {
    if (_currentUserId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 先尝试从本地加载
      final localMessages = await ChatLocalStorage.getMessages(
        currentUserId: _currentUserId!,
        otherUserId: widget.userId,
        limit: 50,
      );

      if (localMessages.isNotEmpty) {
        setState(() {
          _messages.addAll(localMessages);
        });
      }

      // 然后从服务器加载
      final result = await ChatApiService.getMessages(
        userId: widget.userId,
        limit: 50,
      );

      if (result['success'] && mounted) {
        final serverMessages = result['data'] as List<ChatMessage>;

        // 合并消息（去重）
        final existingIds = _messages.map((m) => m.messageId).toSet();
        final newMessages = serverMessages.where((m) => !existingIds.contains(m.messageId)).toList();

        if (newMessages.isNotEmpty) {
          setState(() {
            _messages.addAll(newMessages);
            _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          });

          // 保存到本地
          await ChatLocalStorage.saveMessages(newMessages);
        }

        setState(() {
          _hasMore = result['has_more'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('加载消息失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_messages.isEmpty || !_hasMore) return;

    final firstMessage = _messages.first;
    final result = await ChatApiService.getMessages(
      userId: widget.userId,
      beforeId: firstMessage.messageId,
      limit: 20,
    );

    if (result['success'] && mounted) {
      final messages = result['data'] as List<ChatMessage>;
      setState(() {
        _messages.insertAll(0, messages);
        _hasMore = result['has_more'] ?? false;
      });

      // 保存到本地
      await ChatLocalStorage.saveMessages(messages);
    }
  }

  Future<void> _markAsRead() async {
    await ChatApiService.markConversationAsRead(widget.userId);
    if (_currentUserId != null) {
      await ChatLocalStorage.markConversationAsRead(
        currentUserId: _currentUserId!,
        otherUserId: widget.userId,
      );
    }
  }

  bool _hasSentMessage = false; // 是否发送过消息

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();

    // 标记已发送消息
    _hasSentMessage = true;

    // 创建临时消息（乐观更新）
    final tempMessage = ChatMessage(
      messageId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _currentUserId!,
      receiverId: widget.userId,
      content: content,
      isRead: false,
      createdAt: DateTime.now(),
      productId: widget.productId,
      orderId: widget.orderId,
    );

    // 立即显示在列表中
    setState(() {
      _messages.add(tempMessage);
    });
    _scrollToBottom();

    // 保存到本地
    await ChatLocalStorage.saveMessage(tempMessage);

    // 发送消息
    final success = await _chatService.sendMessage(
      toUserId: widget.userId,
      content: content,
      productId: widget.productId,
      orderId: widget.orderId,
    );

    if (!success && mounted) {
      // 发送失败，标记为发送失败（可后续实现重试）
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('发送失败，请检查网络连接')),
      );
    }

    // 停止输入状态
    _stopTyping();
  }

  void _onTyping() {
    if (!_isTyping) {
      _isTyping = true;
      _chatService.sendTypingStatus(widget.userId, true);
    }

    // 重置定时器
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), _stopTyping);
  }

  void _stopTyping() {
    if (_isTyping) {
      _isTyping = false;
      _chatService.sendTypingStatus(widget.userId, false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2C)),
          onPressed: () => Navigator.pop(context, _hasSentMessage),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
                  ? NetworkImage(widget.avatarUrl!)
                  : null,
              child: widget.avatarUrl == null || widget.avatarUrl!.isEmpty
                  ? Text(
                      widget.username.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF1A1A2C),
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.username,
                    style: const TextStyle(
                      color: Color(0xFF1A1A2C),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_otherUserTyping)
                    const Text(
                      '正在输入...',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // 关联商品/订单信息
          if (widget.productName != null)
            _buildContextBar(),

          // 消息列表
          Expanded(
            child: _isLoading && _messages.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCE965B)),
                    ),
                  )
                : _messages.isEmpty
                    ? _buildEmptyView()
                    : _buildMessageList(),
          ),

          // 输入框
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildContextBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFCE965B).withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Icon(
            widget.orderId != null ? Icons.shopping_bag : Icons.shopping_cart,
            size: 16,
            color: const Color(0xFFCE965B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.productName!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1A1A2C),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 60,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            '还没有消息',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '发送第一条消息开始聊天吧',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification &&
            notification.metrics.pixels <= 50 &&
            _hasMore) {
          _loadMoreMessages();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          final isMe = message.senderId == _currentUserId;
          final showTime = _shouldShowTime(index);

          return Column(
            children: [
              if (showTime)
                _buildTimeLabel(message.createdAt),
              _buildMessageBubble(message, isMe),
            ],
          );
        },
      ),
    );
  }

  bool _shouldShowTime(int index) {
    if (index == 0) return true;
    final current = _messages[index].createdAt;
    final previous = _messages[index - 1].createdAt;
    return current.difference(previous).inMinutes > 5;
  }

  Widget _buildTimeLabel(DateTime time) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _formatTime(time),
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe)
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
                    ? NetworkImage(widget.avatarUrl!)
                    : null,
                child: widget.avatarUrl == null || widget.avatarUrl!.isEmpty
                    ? Text(
                        widget.username.substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 12),
                      )
                    : null,
              ),
            if (!isMe) const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFFCE965B) : Colors.white,
                  borderRadius: BorderRadius.circular(20).copyWith(
                    bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                    bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  message.content,
                  style: TextStyle(
                    fontSize: 15,
                    color: isMe ? Colors.white : const Color(0xFF1A1A2C),
                    height: 1.4,
                  ),
                ),
              ),
            ),
            if (isMe) const SizedBox(width: 8),
            if (isMe)
              Icon(
                message.isRead ? Icons.done_all : Icons.done,
                size: 14,
                color: message.isRead ? const Color(0xFFCE965B) : Colors.grey.shade400,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: Colors.grey.shade500),
              onPressed: () {
                // TODO: 添加图片、文件等
              },
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  onChanged: (_) => _onTyping(),
                  decoration: InputDecoration(
                    hintText: '输入消息...',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFCE965B),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(time.year, time.month, time.day);

    if (messageDay == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (messageDay == today.subtract(const Duration(days: 1))) {
      return '昨天 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.month}月${time.day}日 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

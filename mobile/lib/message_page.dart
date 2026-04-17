import 'dart:async';
import 'package:flutter/material.dart';
import 'icons.dart';
import 'services/notification_service.dart';
import 'services/chat_service.dart';
import 'pages/order/order_detail_page.dart';
import 'pages/chat/conversation_list_page.dart';
import 'models/chat_message.dart';

class MessagePage extends StatefulWidget {
  const MessagePage({super.key});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _unreadChatCount = 0;
  int _unreadNotificationCount = 0;
  StreamSubscription? _chatStatusSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUnreadCounts();

    // 监听 WebSocket 连接状态变化刷新未读数
    _chatStatusSubscription = ChatService().statusStream.listen((status) {
      if (status == ChatConnectionStatus.connected) {
        _loadUnreadCounts();
      }
    });
  }

  Future<void> _loadUnreadCounts() async {
    // 获取未读通知数
    final count = await NotificationService.getUnreadCount();
    if (mounted) {
      setState(() {
        _unreadNotificationCount = count;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '消息',
          style: TextStyle(
            color: Color(0xFF1A1A2C),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFCE965B),
          unselectedLabelColor: Colors.grey.shade500,
          indicatorColor: const Color(0xFFCE965B),
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('聊天'),
                  if (_unreadChatCount > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _unreadChatCount > 99 ? '99+' : _unreadChatCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('通知'),
                  if (_unreadNotificationCount > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _unreadNotificationCount > 99 ? '99+' : _unreadNotificationCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const ConversationListPage(),
          _NotificationTab(
            onUnreadCountChanged: (count) {
              setState(() {
                _unreadNotificationCount = count;
              });
            },
          ),
        ],
      ),
    );
  }
}

/// 通知列表 Tab
class _NotificationTab extends StatefulWidget {
  final Function(int) onUnreadCountChanged;

  const _NotificationTab({required this.onUnreadCountChanged});

  @override
  State<_NotificationTab> createState() => _NotificationTabState();
}

class _NotificationTabState extends State<_NotificationTab> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _offset = 0;
        _hasMore = true;
      });
    }

    if (!_hasMore && !refresh) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await NotificationService.getNotifications(
        limit: _limit,
        offset: refresh ? 0 : _offset,
      );

      final notifications = result['notifications'] ?? [];

      setState(() {
        if (refresh) {
          _notifications = notifications;
        } else {
          _notifications.addAll(notifications);
        }
        _offset = _notifications.length;
        _hasMore = notifications.length >= _limit;
        _isLoading = false;
      });

      // 只有在刷新时才更新未读数，避免重复请求
      if (refresh) {
        final count = await NotificationService.getUnreadCount();
        widget.onUnreadCountChanged(count);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载通知失败: $e')),
        );
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await NotificationService.markAsRead(notificationId);
      setState(() {
        final index = _notifications.indexWhere(
          (n) => n['notification_id'] == notificationId,
        );
        if (index != -1) {
          _notifications[index]['is_read'] = true;
        }
      });
      // 不立即刷新未读数，由父组件定时刷新或下次加载时刷新
      // 减少请求频率
    } catch (e) {
      // 静默处理
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await NotificationService.markAllAsRead();
      setState(() {
        for (var notification in _notifications) {
          notification['is_read'] = true;
        }
      });
      widget.onUnreadCountChanged(0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已全部标记为已读')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await NotificationService.deleteNotification(notificationId);
      setState(() {
        _notifications.removeWhere(
          (n) => n['notification_id'] == notificationId,
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  void _onNotificationTap(Map<String, dynamic> notification) {
    if (!notification['is_read']) {
      _markAsRead(notification['notification_id']);
    }

    final orderId = notification['related_order_id'];
    if (orderId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderDetailPage(orderId: orderId),
        ),
      );
    }
  }

  String _getNotificationIcon(String type) {
    switch (type) {
      case 'ORDER':
        return 'shopping-bag';
      case 'SYSTEM':
        return 'bell';
      case 'MESSAGE':
        return 'chat-bubble-left-ellipsis';
      default:
        return 'bell';
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'ORDER':
        return const Color(0xFFCE965B);
      case 'SYSTEM':
        return const Color(0xFF3B82F6);
      case 'MESSAGE':
        return const Color(0xFF10B981);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: RefreshIndicator(
        onRefresh: () => _loadNotifications(refresh: true),
        color: const Color(0xFFCE965B),
        child: _buildBody(),
      ),
      floatingActionButton: _notifications.isNotEmpty
          ? FloatingActionButton.small(
              onPressed: _markAllAsRead,
              backgroundColor: const Color(0xFFCE965B),
              child: const Icon(Icons.done_all, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading && _notifications.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCE965B)),
        ),
      );
    }

    if (_notifications.isEmpty) {
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
              child: HeroIcons.bell(
                size: 50,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '暂无通知',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '当有新消息时会显示在这里',
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
      itemCount: _notifications.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _notifications.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _isLoading
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFCE965B)),
                    )
                  : ElevatedButton(
                      onPressed: () => _loadNotifications(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCE965B),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('加载更多'),
                    ),
            ),
          );
        }

        final notification = _notifications[index];
        return _buildNotificationCard(notification);
      },
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['is_read'] ?? false;
    final type = notification['type'] ?? 'SYSTEM';
    final title = notification['title'] ?? '';
    final content = notification['content'] ?? '';
    final createdAt = notification['created_at'] ?? '';

    return Dismissible(
      key: Key(notification['notification_id']),
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
      onDismissed: (_) {
        _deleteNotification(notification['notification_id']);
      },
      child: GestureDetector(
        onTap: () => _onNotificationTap(notification),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : const Color(0xFFFFF8F0),
            borderRadius: BorderRadius.circular(12),
            border: isRead
                ? null
                : Border.all(
                    color: const Color(0xFFCE965B).withOpacity(0.3),
                    width: 1,
                  ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getNotificationColor(type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: HeroIcons.icon(
                  _getNotificationIcon(type),
                  size: 24,
                  color: _getNotificationColor(type),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                              color: const Color(0xFF1A1A2C),
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      content,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatTime(createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
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

  String _formatTime(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) {
        return '刚刚';
      } else if (diff.inHours < 1) {
        return '${diff.inMinutes}分钟前';
      } else if (diff.inDays < 1) {
        return '${diff.inHours}小时前';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}天前';
      } else {
        return '${dt.month}月${dt.day}日';
      }
    } catch (e) {
      return isoTime;
    }
  }
}

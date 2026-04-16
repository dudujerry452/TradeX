import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';

/// 聊天消息本地存储服务
///
/// 使用 SharedPreferences 缓存最近的消息（支持所有平台包括 Web）
class ChatLocalStorage {
  static SharedPreferences? _prefs;
  static const String _messagesKey = 'chat_messages';
  static const String _conversationsKey = 'chat_conversations';
  static const int _maxCachedMessages = 100; // 最多缓存消息数

  /// 获取 SharedPreferences 实例
  static Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// 保存消息
  static Future<void> saveMessage(ChatMessage message) async {
    try {
      final prefs = await _instance;
      final messages = await _getMessagesFromPrefs(prefs);

      // 添加新消息（去重）
      messages.removeWhere((m) => m.messageId == message.messageId);
      messages.add(message);

      // 限制缓存数量
      if (messages.length > _maxCachedMessages) {
        messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        messages.removeRange(0, messages.length - _maxCachedMessages);
      }

      await _saveMessagesToPrefs(prefs, messages);
    } catch (e) {
      debugPrint('保存消息失败: $e');
    }
  }

  /// 批量保存消息
  static Future<void> saveMessages(List<ChatMessage> messages) async {
    try {
      final prefs = await _instance;
      final existingMessages = await _getMessagesFromPrefs(prefs);

      // 合并消息（去重）
      final existingIds = existingMessages.map((m) => m.messageId).toSet();
      for (final message in messages) {
        if (!existingIds.contains(message.messageId)) {
          existingMessages.add(message);
        }
      }

      // 限制缓存数量
      if (existingMessages.length > _maxCachedMessages) {
        existingMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        existingMessages.removeRange(0, existingMessages.length - _maxCachedMessages);
      }

      await _saveMessagesToPrefs(prefs, existingMessages);
    } catch (e) {
      debugPrint('批量保存消息失败: $e');
    }
  }

  /// 获取与某用户的聊天记录
  static Future<List<ChatMessage>> getMessages({
    required String currentUserId,
    required String otherUserId,
    int limit = 50,
    String? beforeId,
  }) async {
    try {
      final prefs = await _instance;
      final allMessages = await _getMessagesFromPrefs(prefs);

      // 筛选双方对话
      var messages = allMessages.where((m) {
        return (m.senderId == currentUserId && m.receiverId == otherUserId) ||
               (m.senderId == otherUserId && m.receiverId == currentUserId);
      }).toList();

      // 分页
      if (beforeId != null) {
        final beforeIndex = messages.indexWhere((m) => m.messageId == beforeId);
        if (beforeIndex != -1) {
          messages = messages.sublist(0, beforeIndex);
        }
      }

      // 排序（最新的在前）并限制数量
      messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (messages.length > limit) {
        messages = messages.sublist(0, limit);
      }

      // 返回按时间正序排列的消息
      return messages.reversed.toList();
    } catch (e) {
      debugPrint('获取消息失败: $e');
      return [];
    }
  }

  /// 根据 ID 获取消息
  static Future<ChatMessage?> getMessageById(String messageId) async {
    try {
      final prefs = await _instance;
      final messages = await _getMessagesFromPrefs(prefs);
      return messages.firstWhere(
        (m) => m.messageId == messageId,
        orElse: () => null as ChatMessage,
      );
    } catch (e) {
      return null;
    }
  }

  /// 标记消息为已读
  static Future<void> markMessageAsRead(String messageId) async {
    try {
      final prefs = await _instance;
      final messages = await _getMessagesFromPrefs(prefs);

      final index = messages.indexWhere((m) => m.messageId == messageId);
      if (index != -1) {
        messages[index] = messages[index].copyWith(isRead: true);
        await _saveMessagesToPrefs(prefs, messages);
      }
    } catch (e) {
      debugPrint('标记已读失败: $e');
    }
  }

  /// 标记与某用户的所有消息为已读
  static Future<void> markConversationAsRead({
    required String currentUserId,
    required String otherUserId,
  }) async {
    try {
      final prefs = await _instance;
      final messages = await _getMessagesFromPrefs(prefs);

      bool changed = false;
      for (int i = 0; i < messages.length; i++) {
        if (messages[i].senderId == otherUserId &&
            messages[i].receiverId == currentUserId &&
            !messages[i].isRead) {
          messages[i] = messages[i].copyWith(isRead: true);
          changed = true;
        }
      }

      if (changed) {
        await _saveMessagesToPrefs(prefs, messages);
      }
    } catch (e) {
      debugPrint('标记对话已读失败: $e');
    }
  }

  /// 删除消息
  static Future<void> deleteMessage(String messageId) async {
    try {
      final prefs = await _instance;
      final messages = await _getMessagesFromPrefs(prefs);
      messages.removeWhere((m) => m.messageId == messageId);
      await _saveMessagesToPrefs(prefs, messages);
    } catch (e) {
      debugPrint('删除消息失败: $e');
    }
  }

  /// 获取与某用户之间的最后一条消息
  static Future<ChatMessage?> getLastMessage(String userId1, String userId2) async {
    try {
      final prefs = await _instance;
      final messages = await _getMessagesFromPrefs(prefs);

      final conversationMessages = messages.where((m) {
        return (m.senderId == userId1 && m.receiverId == userId2) ||
               (m.senderId == userId2 && m.receiverId == userId1);
      }).toList();

      if (conversationMessages.isEmpty) return null;

      conversationMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return conversationMessages.first;
    } catch (e) {
      return null;
    }
  }

  /// 获取未读消息数
  static Future<int> getUnreadCount(String currentUserId) async {
    try {
      final prefs = await _instance;
      final messages = await _getMessagesFromPrefs(prefs);
      return messages.where((m) => m.receiverId == currentUserId && !m.isRead).length;
    } catch (e) {
      return 0;
    }
  }

  /// 清理旧消息
  static Future<void> cleanupOldMessages() async {
    try {
      final prefs = await _instance;
      final messages = await _getMessagesFromPrefs(prefs);

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      messages.removeWhere((m) => m.createdAt.isBefore(thirtyDaysAgo));

      await _saveMessagesToPrefs(prefs, messages);
    } catch (e) {
      debugPrint('清理旧消息失败: $e');
    }
  }

  /// 清空所有数据
  static Future<void> clearAll() async {
    try {
      final prefs = await _instance;
      await prefs.remove(_messagesKey);
      await prefs.remove(_conversationsKey);
    } catch (e) {
      debugPrint('清空数据失败: $e');
    }
  }

  /// 保存对话缓存
  static Future<void> saveConversations(List<Conversation> conversations) async {
    try {
      final prefs = await _instance;
      final data = conversations.map((c) => {
        'user_id': c.userId,
        'username': c.username,
        'avatar_url': c.avatarUrl,
        'last_message': c.lastMessage,
        'last_message_time': c.lastMessageTime.toIso8601String(),
        'unread_count': c.unreadCount,
        'product_id': c.productId,
        'product_name': c.productName,
        'order_id': c.orderId,
      }).toList();

      await prefs.setString(_conversationsKey, jsonEncode(data));
    } catch (e) {
      debugPrint('保存对话缓存失败: $e');
    }
  }

  /// 获取缓存的对话列表
  static Future<List<Conversation>> getCachedConversations() async {
    try {
      final prefs = await _instance;
      final jsonStr = prefs.getString(_conversationsKey);
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final List<dynamic> data = jsonDecode(jsonStr);
      return data.map((map) => Conversation(
        userId: map['user_id'] ?? '',
        username: map['username'] ?? '',
        avatarUrl: map['avatar_url'] ?? '',
        lastMessage: map['last_message'] ?? '',
        lastMessageTime: DateTime.parse(map['last_message_time'] ?? DateTime.now().toIso8601String()),
        unreadCount: map['unread_count'] ?? 0,
        productId: map['product_id'],
        productName: map['product_name'],
        orderId: map['order_id'],
      )).toList();
    } catch (e) {
      debugPrint('获取对话缓存失败: $e');
      return [];
    }
  }

  // 私有辅助方法

  static Future<List<ChatMessage>> _getMessagesFromPrefs(SharedPreferences prefs) async {
    final jsonStr = prefs.getString(_messagesKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    try {
      final List<dynamic> data = jsonDecode(jsonStr);
      return data.map((json) => ChatMessage.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> _saveMessagesToPrefs(SharedPreferences prefs, List<ChatMessage> messages) async {
    final data = messages.map((m) => m.toJson()).toList();
    await prefs.setString(_messagesKey, jsonEncode(data));
  }
}

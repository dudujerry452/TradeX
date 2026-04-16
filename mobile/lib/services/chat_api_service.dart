import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api.dart';
import '../models/chat_message.dart';

/// 聊天相关 HTTP API 服务
class ChatApiService {
  static String get baseUrl => ApiService.baseUrl;

  /// 获取对话列表
  static Future<Map<String, dynamic>> getConversations() async {
    final url = Uri.parse('$baseUrl/chat/conversations');

    try {
      final response = await http.get(url, headers: await ApiService.getHeaders());

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final conversations = data.map((json) => Conversation.fromJson(json)).toList();
        return {'success': true, 'data': conversations};
      } else if (response.statusCode == 401) {
        return {'success': false, 'message': '登录已过期，请重新登录'};
      } else {
        return {'success': false, 'message': '获取对话列表失败'};
      }
    } catch (e) {
      return {'success': false, 'message': '网络连接错误: $e'};
    }
  }

  /// 获取与某用户的聊天记录
  static Future<Map<String, dynamic>> getMessages({
    required String userId,
    String? beforeId,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
    };
    if (beforeId != null) {
      queryParams['before_id'] = beforeId;
    }

    final url = Uri.parse('$baseUrl/chat/messages/$userId')
        .replace(queryParameters: queryParams);

    try {
      final response = await http.get(url, headers: await ApiService.getHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final messages = (data['messages'] as List)
            .map((json) => ChatMessage.fromJson(json))
            .toList();
        return {
          'success': true,
          'data': messages,
          'has_more': data['has_more'] ?? false,
        };
      } else if (response.statusCode == 401) {
        return {'success': false, 'message': '登录已过期，请重新登录'};
      } else {
        return {'success': false, 'message': '获取聊天记录失败'};
      }
    } catch (e) {
      return {'success': false, 'message': '网络连接错误: $e'};
    }
  }

  /// 标记整个对话为已读
  static Future<Map<String, dynamic>> markConversationAsRead(String userId) async {
    final url = Uri.parse('$baseUrl/chat/messages/$userId/read');

    try {
      final response = await http.post(url, headers: await ApiService.getHeaders());

      if (response.statusCode == 200) {
        return {'success': true};
      } else if (response.statusCode == 401) {
        return {'success': false, 'message': '登录已过期，请重新登录'};
      } else {
        return {'success': false, 'message': '标记已读失败'};
      }
    } catch (e) {
      return {'success': false, 'message': '网络连接错误: $e'};
    }
  }

  /// 批量标记消息为已读
  static Future<Map<String, dynamic>> markMessagesAsRead(List<String> messageIds) async {
    final url = Uri.parse('$baseUrl/chat/messages/read');

    try {
      final response = await http.post(
        url,
        headers: await ApiService.getHeaders(),
        body: jsonEncode({'message_ids': messageIds}),
      );

      if (response.statusCode == 200) {
        return {'success': true};
      } else if (response.statusCode == 401) {
        return {'success': false, 'message': '登录已过期，请重新登录'};
      } else {
        return {'success': false, 'message': '标记已读失败'};
      }
    } catch (e) {
      return {'success': false, 'message': '网络连接错误: $e'};
    }
  }

  /// 删除消息
  static Future<Map<String, dynamic>> deleteMessage(String messageId) async {
    final url = Uri.parse('$baseUrl/chat/messages/$messageId');

    try {
      final response = await http.delete(url, headers: await ApiService.getHeaders());

      if (response.statusCode == 200) {
        return {'success': true};
      } else if (response.statusCode == 401) {
        return {'success': false, 'message': '登录已过期，请重新登录'};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['message'] ?? '删除失败'};
      }
    } catch (e) {
      return {'success': false, 'message': '网络连接错误: $e'};
    }
  }

  /// 获取未读消息数
  static Future<Map<String, dynamic>> getUnreadCount() async {
    final url = Uri.parse('$baseUrl/chat/unread-count');

    try {
      final response = await http.get(url, headers: await ApiService.getHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'count': data['count'] ?? 0};
      } else if (response.statusCode == 401) {
        return {'success': false, 'message': '登录已过期，请重新登录'};
      } else {
        return {'success': false, 'message': '获取未读数失败'};
      }
    } catch (e) {
      return {'success': false, 'message': '网络连接错误: $e'};
    }
  }

  /// 同步消息（离线后获取新消息）
  static Future<Map<String, dynamic>> syncMessages({String? lastMessageId}) async {
    final queryParams = <String, String>{};
    if (lastMessageId != null) {
      queryParams['last_message_id'] = lastMessageId;
    }

    final url = Uri.parse('$baseUrl/chat/sync')
        .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    try {
      final response = await http.get(url, headers: await ApiService.getHeaders());

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final messages = (data['messages'] as List)
            .map((json) => ChatMessage.fromJson(json))
            .toList();
        return {
          'success': true,
          'data': messages,
        };
      } else if (response.statusCode == 401) {
        return {'success': false, 'message': '登录已过期，请重新登录'};
      } else {
        return {'success': false, 'message': '同步消息失败'};
      }
    } catch (e) {
      return {'success': false, 'message': '网络连接错误: $e'};
    }
  }
}

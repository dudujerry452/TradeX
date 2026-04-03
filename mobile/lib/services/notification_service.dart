import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth_manager.dart';

class NotificationService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthManager.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// 获取通知列表
  static Future<Map<String, dynamic>> getNotifications({
    bool? isRead,
    int limit = 20,
    int offset = 0,
  }) async {
    final headers = await _getHeaders();
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (isRead != null) {
      queryParams['is_read'] = isRead.toString();
    }

    final uri = Uri.parse('$baseUrl/notifications/').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> notifications = jsonDecode(response.body);
      return {
        'notifications': notifications,
        'total': notifications.length,
      };
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? '获取通知列表失败');
    }
  }

  /// 获取未读通知数量
  static Future<int> getUnreadCount() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/notifications/unread-count/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['count'] ?? 0;
    } else {
      return 0;
    }
  }

  /// 标记通知为已读
  static Future<void> markAsRead(String notificationId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/notifications/$notificationId/read/'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? '标记已读失败');
    }
  }

  /// 标记所有通知为已读
  static Future<int> markAllAsRead() async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/notifications/read-all/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // 从消息中提取数量
      final message = data['message'] ?? '';
      final match = RegExp(r'\d+').firstMatch(message);
      return match != null ? int.parse(match.group(0)!) : 0;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? '标记全部已读失败');
    }
  }

  /// 删除通知
  static Future<void> deleteNotification(String notificationId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/notifications/$notificationId/'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? '删除通知失败');
    }
  }
}

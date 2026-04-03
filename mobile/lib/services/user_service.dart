import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api.dart';
import '../auth_manager.dart';

class UserService {
  /// 更新当前用户信息（地址、电话、真实姓名）
  static Future<Map<String, dynamic>> updateUserInfo({
    required String token,
    String? address,
    String? phoneDisplay,
    String? realName,
  }) async {
    final url = Uri.parse('${ApiService.baseUrl}/users/me/');

    final body = <String, dynamic>{};
    if (address != null) body['address'] = address;
    if (phoneDisplay != null) body['phone_display'] = phoneDisplay;
    if (realName != null) body['real_name'] = realName;

    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('更新用户信息失败: ${response.body}');
    }
  }

  /// 获取当前用户信息
  static Future<Map<String, dynamic>> getUserInfo({
    required String userId,
  }) async {
    final url = Uri.parse('${ApiService.baseUrl}/users/$userId/');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('获取用户信息失败: ${response.body}');
    }
  }
}

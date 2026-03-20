import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // 请替换为你实际的 Django 后端地址 
  // 如果在安卓模拟器测试本地服务，请使用 http://10.0.2.2:8000
  // 如果是 iOS 模拟器，请使用 http://127.0.0.1:8000
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  /// 用户登录
  /// [identifier] 可以是 username 或 email
  /// [isEmail] 用于区分当前使用的是邮箱还是用户名登录
  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
    required bool isEmail,
  }) async {
    final url = Uri.parse('$baseUrl/login');
    
    // 根据是邮箱登录还是用户名登录构造 Payload
    final Map<String, dynamic> body = {
      "password": password,
    };
    if (isEmail) {
      body["email"] = identifier;
    } else {
      body["username"] = identifier;
    }

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // 成功，返回 LoginOut Schema 数据
        return {'success': true, 'data': responseData};
      } else {
        // 处理 401, 403 或其他错误
        String errorMessage = responseData['detail'] ?? '登录失败，请重试';
        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      return {'success': false, 'message': '网络连接错误: $e'};
    }
  }
}
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

  /// 获取商品列表
  /// [page] 页码，从1开始
  /// [pageSize] 每页数量
  /// [category] 可选，按分类筛选
  /// [ordering] 可选，排序方式，如 '-publish_time' 或 'price'
  static Future<Map<String, dynamic>> getProducts({
    int page = 1,
    int pageSize = 20,
    String? category,
    String? ordering,
  }) async {
    // 后端目前不支持分页参数，直接请求所有商品
    final url = Uri.parse('$baseUrl/products/');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final body = response.body;
        // 尝试解析JSON
        try {
          final responseData = jsonDecode(body);
          // 后端返回的是数组，包装成统一格式
          if (responseData is List) {
            return {'success': true, 'data': {'items': responseData}};
          } else {
            return {'success': false, 'message': '返回数据格式错误'};
          }
        } catch (e) {
          print('JSON解析错误: $e');
          print('响应内容: $body');
          return {'success': false, 'message': '数据解析错误'};
        }
      } else {
        return {'success': false, 'message': '获取商品列表失败: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': '网络连接错误: $e'};
    }
  }

  /// 获取商品详情
  static Future<Map<String, dynamic>> getProductDetail(String productId) async {
    final url = Uri.parse('$baseUrl/products/$productId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'data': responseData};
      } else {
        return {'success': false, 'message': '获取商品详情失败'};
      }
    } catch (e) {
      return {'success': false, 'message': '网络连接错误: $e'};
    }
  }

  /// 获取商品分类列表
  static Future<Map<String, dynamic>> getCategories() async {
    // 目前后端没有专门的分类接口，返回一些预设分类
    // 实际项目中应该从后端获取
    final categories = [
      {'id': 'all', 'name': '全部'},
      {'id': 'electronics', 'name': '数码'},
      {'id': 'clothing', 'name': '服饰'},
      {'id': 'home', 'name': '家居'},
      {'id': 'books', 'name': '图书'},
      {'id': 'sports', 'name': '运动'},
      {'id': 'beauty', 'name': '美妆'},
      {'id': 'food', 'name': '食品'},
    ];

    return {'success': true, 'data': categories};
  }
}
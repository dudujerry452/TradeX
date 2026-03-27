import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_manager.dart';

class ApiService {
  // 请替换为你实际的 Django 后端地址
  // 如果在安卓模拟器测试本地服务，请使用 http://10.0.2.2:8000
  // 如果是 iOS 模拟器，请使用 http://127.0.0.1:8000
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  /// 获取带认证的请求头
  static Future<Map<String, String>> getHeaders() async {
    final token = await AuthManager.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

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
        // 成功，返回包含 token 的数据
        return {
          'success': true,
          'token': responseData['token'],
          'user_id': responseData['user_id'],
          'username': responseData['username'],
          'role': responseData['role'],
        };
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

  /// 获取商品标签列表
  static Future<Map<String, dynamic>> getProductTags(String productId) async {
    final url = Uri.parse('$baseUrl/products/$productId/tags/');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'data': responseData};
      } else {
        return {'success': false, 'message': '获取商品标签失败'};
      }
    } catch (e) {
      return {'success': false, 'message': '网络连接错误: $e'};
    }
  }

  /// 获取用户标签偏好
  static Future<Map<String, dynamic>> getUserTagPreferences(String userId) async {
    final url = Uri.parse('$baseUrl/users/$userId/tag-preferences/');

    try {
      final response = await http.get(url, headers: await getHeaders());

      if (response.statusCode == 401) {
        return {'success': false, 'message': '登录已过期，请重新登录'};
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'data': responseData};
      } else {
        return {'success': false, 'message': '获取用户标签偏好失败'};
      }
    } catch (e) {
      return {'success': false, 'message': '网络连接错误: $e'};
    }
  }

  /// 获取用户收藏列表
  static Future<Map<String, dynamic>> getUserFavorites(String userId) async {
    final url = Uri.parse('$baseUrl/users/$userId/favorites/');

    try {
      final response = await http.get(url, headers: await getHeaders());

      if (response.statusCode == 401) {
        return {'success': false, 'message': '登录已过期，请重新登录'};
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'data': responseData};
      } else {
        return {'success': false, 'message': '获取收藏列表失败'};
      }
    } catch (e) {
      return {'success': false, 'message': '网络连接错误: $e'};
    }
  }

  /// 收藏商品
  static Future<Map<String, dynamic>> addFavorite(String userId, String productId) async {
    final url = Uri.parse('$baseUrl/product-favorites/');

    try {
      final response = await http.post(
        url,
        headers: await getHeaders(),
        body: jsonEncode({
          'user_id': userId,
          'product_id': productId,
        }),
      );

      if (response.statusCode == 401) {
        return {'success': false, 'message': '登录已过期，请重新登录'};
      }

      if (response.statusCode == 201) {
        return {'success': true, 'message': '收藏成功'};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'message': responseData['detail'] ?? '收藏失败'};
      }
    } catch (e) {
      return {'success': false, 'message': '网络连接错误: $e'};
    }
  }

  /// 取消收藏（通过 user_id 和 product_id）
  static Future<Map<String, dynamic>> removeFavorite(String userId, String productId) async {
    final url = Uri.parse('$baseUrl/product-favorites/delete/?user_id=$userId&product_id=$productId');

    try {
      final response = await http.delete(url, headers: await getHeaders());

      if (response.statusCode == 401) {
        return {'success': false, 'message': '登录已过期，请重新登录'};
      }

      if (response.statusCode == 200) {
        return {'success': true, 'message': '已取消收藏'};
      } else {
        final responseData = jsonDecode(response.body);
        return {'success': false, 'message': responseData['detail'] ?? '取消收藏失败'};
      }
    } catch (e) {
      return {'success': false, 'message': '网络连接错误: $e'};
    }
  }

  /// 检查是否已收藏（使用轻量接口）
  static Future<Map<String, dynamic>> checkFavorite(String userId, String productId) async {
    final url = Uri.parse('$baseUrl/product-favorites/check/?user_id=$userId&product_id=$productId');

    try {
      final response = await http.get(url, headers: await getHeaders());

      if (response.statusCode == 401) {
        return {'success': false, 'message': '登录已过期，请重新登录'};
      }

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {'success': true, 'isFavorited': responseData['is_favorited'] ?? false};
      } else {
        return {'success': false, 'message': '检查收藏状态失败'};
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
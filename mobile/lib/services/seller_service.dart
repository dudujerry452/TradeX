import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth_manager.dart';

class SellerService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api',
  );

  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthManager.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// 获取我发布的商品列表
  /// [status] 筛选状态：APPROVED/OFF_SHELF/PENDING/REJECTED
  /// [limit] 每页数量
  /// [offset] 分页偏移量
  static Future<Map<String, dynamic>> getMyProducts({
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    final headers = await _getHeaders();
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final uri = Uri.parse('$baseUrl/products/my/').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> products = jsonDecode(response.body);
      return {
        'success': true,
        'products': products,
        'total': products.length, // 后端返回的是当前页数据
      };
    } else if (response.statusCode == 401) {
      return {'success': false, 'message': '请先登录'};
    } else {
      final error = jsonDecode(response.body);
      return {'success': false, 'message': error['detail'] ?? '获取商品列表失败'};
    }
  }

  /// 更新商品信息
  static Future<Map<String, dynamic>> updateProduct(
    String productId,
    Map<String, dynamic> data,
  ) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/products/$productId/'),
      headers: headers,
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return {
        'success': true,
        'data': jsonDecode(response.body),
      };
    } else if (response.statusCode == 401) {
      return {'success': false, 'message': '请先登录'};
    } else if (response.statusCode == 403) {
      return {'success': false, 'message': '只能修改自己发布的商品'};
    } else {
      final error = jsonDecode(response.body);
      return {'success': false, 'message': error['detail'] ?? '更新商品失败'};
    }
  }

  /// 更新商品状态（上架/下架）
  static Future<Map<String, dynamic>> updateProductStatus(
    String productId,
    String status,
  ) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/products/$productId/status/'),
      headers: headers,
      body: jsonEncode({'product_status': status}),
    );

    if (response.statusCode == 200) {
      return {
        'success': true,
        'data': jsonDecode(response.body),
      };
    } else if (response.statusCode == 401) {
      return {'success': false, 'message': '请先登录'};
    } else {
      final error = jsonDecode(response.body);
      return {'success': false, 'message': error['detail'] ?? '更新状态失败'};
    }
  }

  /// 获取卖家统计数据
  static Future<Map<String, dynamic>> getSellerStats() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/products/seller/stats/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return {
        'success': true,
        'data': jsonDecode(response.body),
      };
    } else if (response.statusCode == 401) {
      return {'success': false, 'message': '请先登录'};
    } else {
      final error = jsonDecode(response.body);
      return {'success': false, 'message': error['detail'] ?? '获取统计数据失败'};
    }
  }
}

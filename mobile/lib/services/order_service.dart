import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth_manager.dart';

class OrderService {
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthManager.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// 创建订单
  static Future<Map<String, dynamic>> createOrder({
    required String productId,
    required int quantity,
    required String address,
    required String phone,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/orders/'),
      headers: headers,
      body: jsonEncode({
        'product_id': productId,
        'quantity': quantity,
        'address': address,
        'phone': phone,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? '创建订单失败');
    }
  }

  /// 获取订单列表
  static Future<Map<String, dynamic>> getOrders({
    String? status,
    String role = 'buyer',
    int limit = 20,
    int offset = 0,
  }) async {
    final headers = await _getHeaders();
    final queryParams = <String, String>{
      'role': role,
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (status != null) {
      queryParams['status'] = status;
    }

    final uri = Uri.parse('$baseUrl/orders/').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? '获取订单列表失败');
    }
  }

  /// 获取订单详情
  static Future<Map<String, dynamic>> getOrderDetail(String orderId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/orders/$orderId/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? '获取订单详情失败');
    }
  }

  /// 支付订单
  static Future<Map<String, dynamic>> payOrder(String orderId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/orders/$orderId/pay/'),
      headers: headers,
      body: jsonEncode({'payment_method': 'mock'}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? '支付订单失败');
    }
  }

  /// 卖家发货
  static Future<Map<String, dynamic>> shipOrder(
    String orderId, {
    required String logisticsCompany,
    required String logisticsNumber,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/orders/$orderId/ship/'),
      headers: headers,
      body: jsonEncode({
        'logistics_company': logisticsCompany,
        'logistics_number': logisticsNumber,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? '发货失败');
    }
  }

  /// 确认收货
  static Future<Map<String, dynamic>> receiveOrder(String orderId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/orders/$orderId/receive/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? '确认收货失败');
    }
  }

  /// 取消订单
  static Future<Map<String, dynamic>> cancelOrder(
    String orderId, {
    String reason = '',
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/orders/$orderId/cancel/'),
      headers: headers,
      body: jsonEncode({'reason': reason}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? '取消订单失败');
    }
  }

  /// 获取订单日志
  static Future<List<dynamic>> getOrderLogs(String orderId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/orders/$orderId/logs/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? '获取订单日志失败');
    }
  }
}

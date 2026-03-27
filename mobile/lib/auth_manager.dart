import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

/// 认证管理器 - 简化版单一 Token（30天有效期）
class AuthManager {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const _keyToken = 'auth_token';
  static const _keyUserData = 'auth_user_data';

  /// 保存登录信息（Token + 用户数据）
  static Future<void> saveLogin(String token, Map<String, dynamic> userData) async {
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keyUserData, value: jsonEncode(userData));
  }

  /// 获取 Token（自动检查是否过期）
  static Future<String?> getToken() async {
    final token = await _storage.read(key: _keyToken);
    if (token == null) return null;

    // 检查是否过期
    if (JwtDecoder.isExpired(token)) {
      // Token 过期，清除登录态
      await clearLogin();
      return null;
    }

    return token;
  }

  /// 获取用户ID
  static Future<String?> getUserId() async {
    final userData = await getUser();
    return userData?['user_id'];
  }

  /// 获取用户名
  static Future<String?> getUsername() async {
    final userData = await getUser();
    return userData?['username'];
  }

  /// 获取用户信息
  static Future<Map<String, dynamic>?> getUser() async {
    final userDataStr = await _storage.read(key: _keyUserData);
    if (userDataStr == null) return null;
    try {
      return jsonDecode(userDataStr) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// 是否已登录（Token 存在且未过期）
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  /// 清除登录态（退出登录）
  static Future<void> clearLogin() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyUserData);
  }

  /// 获取 Token 剩余有效天数
  static Future<int> getTokenRemainingDays() async {
    final token = await _storage.read(key: _keyToken);
    if (token == null) return 0;

    try {
      final expirationDate = JwtDecoder.getExpirationDate(token);
      final now = DateTime.now();
      final difference = expirationDate.difference(now);
      return difference.inDays;
    } catch (e) {
      return 0;
    }
  }
}

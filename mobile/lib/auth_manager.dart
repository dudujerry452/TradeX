import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 认证管理器 - 简化版单一 Token（30天有效期）
/// Web 端使用 localStorage，移动端使用加密存储
class AuthManager {
  // 移动端加密存储
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const _keyToken = 'auth_token';
  static const _keyUserData = 'auth_user_data';

  /// 获取存储实例（Web 用 SharedPreferences，移动端用 FlutterSecureStorage）
  static Future<dynamic> _getStorage() async {
    if (kIsWeb) {
      return await SharedPreferences.getInstance();
    }
    return _secureStorage;
  }

  /// 写入数据
  static Future<void> _write(String key, String value) async {
    final storage = await _getStorage();
    if (kIsWeb) {
      await storage.setString(key, value);
    } else {
      await storage.write(key: key, value: value);
    }
  }

  /// 读取数据
  static Future<String?> _read(String key) async {
    final storage = await _getStorage();
    if (kIsWeb) {
      return storage.getString(key);
    } else {
      return await storage.read(key: key);
    }
  }

  /// 删除数据
  static Future<void> _delete(String key) async {
    final storage = await _getStorage();
    if (kIsWeb) {
      await storage.remove(key);
    } else {
      await storage.delete(key: key);
    }
  }

  /// 保存登录信息（Token + 用户数据）
  static Future<void> saveLogin(String token, Map<String, dynamic> userData) async {
    await _write(_keyToken, token);
    await _write(_keyUserData, jsonEncode(userData));
  }

  /// 获取 Token（自动检查是否过期）
  static Future<String?> getToken() async {
    final token = await _read(_keyToken);
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
    final userDataStr = await _read(_keyUserData);
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
    await _delete(_keyToken);
    await _delete(_keyUserData);
  }

  /// 获取 Token 剩余有效天数
  static Future<int> getTokenRemainingDays() async {
    final token = await _read(_keyToken);
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

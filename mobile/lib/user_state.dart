import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 用户状态管理类 - 用于保存和获取当前登录用户信息
class UserState {
  static const String _keyUserData = 'user_data';

  /// 保存登录用户信息
  static Future<void> saveUser(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserData, jsonEncode(userData));
  }

  /// 获取保存的用户信息
  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_keyUserData);
    if (userData != null) {
      return jsonDecode(userData) as Map<String, dynamic>;
    }
    return null;
  }

  /// 获取当前用户ID
  static Future<String?> getUserId() async {
    final user = await getUser();
    return user?['user_id'];
  }

  /// 获取当前用户名
  static Future<String?> getUsername() async {
    final user = await getUser();
    return user?['username'];
  }

  /// 清除用户数据（退出登录时调用）
  static Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserData);
  }

  /// 检查是否已登录
  static Future<bool> isLoggedIn() async {
    final user = await getUser();
    return user != null;
  }
}

import 'package:flutter/foundation.dart' show kIsWeb;

/// 图片上传服务 - 支持移动端和Web端
///
/// 当前实现：
/// - Web端：直接返回占位图URL（因为Web端无法直接访问本地文件系统）
/// - 移动端：预留接口，后续接入真实图床
///
/// 后续接入真实图床（如 sm.ms、阿里云OSS）时：
/// 1. Web端通过 <input type="file"> 选择图片后上传
/// 2. 移动端通过 image_picker 选择图片后上传
class ImageUploadService {
  /// 上传图片到图床
  ///
  /// Web端：返回占位图URL（模拟上传）
  /// 移动端：预留接口，后续实现真实上传
  static Future<Map<String, dynamic>> uploadImage() async {
    // TODO: 接入真实图床API
    // 模拟上传延迟
    await Future.delayed(const Duration(seconds: 1));

    // Web端和移动端都返回假图片URL（占位图）
    // 后续真实实现：
    // - Web端：通过 file_picker 选择图片后上传到图床
    // - 移动端：通过 image_picker 选择图片后上传到图床
    return {
      'success': true,
      'url': 'https://via.placeholder.com/400x400?text=Product+Image',
    };
  }

  /// 检查当前平台是否支持本地图片选择
  static bool get supportsImagePicker {
    // Web端目前不支持本地图片选择（需要额外配置）
    // 移动端支持
    return !kIsWeb;
  }
}

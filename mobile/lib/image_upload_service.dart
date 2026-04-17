import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';
import 'auth_manager.dart';

/// 图片上传服务 - 通过后端转存到 COS
///
/// 流程：
/// 1. 选择本地图片
/// 2. 上传到后端 /api/uploads/image/
/// 3. 后端转存到腾讯云 COS，返回对象访问 URL
class ImageUploadService {
  /// 根据文件名获取对应的 MIME 类型
  static MediaType? _getMediaTypeFromFilename(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'webp':
        return MediaType('image', 'webp');
      case 'bmp':
        return MediaType('image', 'bmp');
      default:
        return null;
    }
  }

  static Future<Map<String, dynamic>> _uploadPickedFile(
    XFile pickedFile,
  ) async {
    final token = await AuthManager.getToken();
    if (token == null) {
      return {'success': false, 'message': '请先登录'};
    }

    final imageBytes = await pickedFile.readAsBytes();
    if (imageBytes.isEmpty) {
      return {'success': false, 'message': '图片文件为空'};
    }

    final uri = Uri.parse('${ApiService.baseUrl}/uploads/image/');
    final filename = pickedFile.name.isNotEmpty ? pickedFile.name : 'image.jpg';
    final contentType = _getMediaTypeFromFilename(filename);

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: filename,
          contentType: contentType ?? MediaType('application', 'octet-stream'),
        ),
      );

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      Map<String, dynamic> payload = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          payload = decoded;
        }
      } catch (_) {
        // keep fallback payload
      }

      if (response.statusCode == 200) {
        return {
          'success': true,
          'url': payload['url'] ?? '',
          'key': payload['key'] ?? '',
          'filename': payload['filename'] ?? pickedFile.name,
        };
      }

      return {
        'success': false,
        'message':
            payload['detail'] ??
            payload['message'] ??
            '上传失败 (${response.statusCode})',
      };
    } catch (e) {
      return {'success': false, 'message': '网络连接错误: $e'};
    }
  }

  /// 上传图片到图床
  ///
  static Future<Map<String, dynamic>> uploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 1600,
    );

    if (pickedFile == null) {
      return {'success': false, 'message': '未选择图片'};
    }
    return _uploadPickedFile(pickedFile);
  }

  /// 上传一个已经选中的图片文件
  static Future<Map<String, dynamic>> uploadXFile(XFile pickedFile) async {
    return _uploadPickedFile(pickedFile);
  }

  /// 检查当前平台是否支持本地图片选择
  static bool get supportsImagePicker {
    // Web端目前不支持本地图片选择（需要额外配置）
    // 移动端支持
    return true;
  }
}

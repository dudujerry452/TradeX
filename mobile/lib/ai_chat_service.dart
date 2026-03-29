import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api.dart';

/// AI 流式事件基类
abstract class AiStreamEvent {
  const AiStreamEvent();
}

/// 元数据事件 - 包含推荐商品列表
class MetaEvent extends AiStreamEvent {
  final List<Map<String, dynamic>> products;

  const MetaEvent({required this.products});
}

/// Token 事件 - AI 回复的逐字内容
class TokenEvent extends AiStreamEvent {
  final String token;

  const TokenEvent({required this.token});
}

/// 完成事件 - 流式响应结束
class DoneEvent extends AiStreamEvent {
  const DoneEvent();
}

/// 错误事件 - 发生错误
class ErrorEvent extends AiStreamEvent {
  final String message;

  const ErrorEvent({required this.message});
}

/// AI 聊天服务类
/// 处理与后端 RAG 接口的 SSE 流式通信
class AiChatService {
  /// SSE 流式请求 AI 回复
  /// [question] 用户问题
  /// [nResults] 返回的商品数量
  static Stream<AiStreamEvent> sendMessage({
    required String question,
    int nResults = 3,
  }) async* {
    try {
      final request = http.Request(
        'POST',
        Uri.parse('${ApiService.baseUrl}/rag/chat/stream'),
      );

      // 设置请求头
      final headers = await ApiService.getHeaders();
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'text/event-stream';
      request.headers.addAll(headers);

      // 设置请求体
      request.body = jsonEncode({
        'question': question,
        'n_results': nResults,
      });

      // 发送请求并获取流式响应
      final client = http.Client();
      final response = await client.send(request);

      if (response.statusCode != 200) {
        yield ErrorEvent(
          message: '请求失败: HTTP ${response.statusCode}',
        );
        client.close();
        return;
      }

      // 缓冲区用于处理跨分块的 SSE 事件
      String buffer = '';

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;

        // 处理缓冲区中的完整 SSE 事件
        // SSE 事件以 \n\n 分隔
        while (buffer.contains('\n\n')) {
          final endIndex = buffer.indexOf('\n\n');
          final eventBlock = buffer.substring(0, endIndex);
          buffer = buffer.substring(endIndex + 2);

          if (eventBlock.isNotEmpty) {
            final event = _parseSseBlock(eventBlock);
            if (event != null) {
              yield event;
            }
          }
        }
      }

      // 处理缓冲区中剩余的内容
      if (buffer.trim().isNotEmpty) {
        final event = _parseSseBlock(buffer.trim());
        if (event != null) {
          yield event;
        }
      }

      client.close();
    } catch (e) {
      yield ErrorEvent(message: '网络错误: $e');
    }
  }

  /// 解析单个 SSE 事件块
  static AiStreamEvent? _parseSseBlock(String block) {
    final lines = block.split('\n');
    String? eventType;
    String? data;

    for (final line in lines) {
      if (line.startsWith('event:')) {
        eventType = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        data = line.substring(5).trim();
      }
    }

    if (data == null || data.isEmpty) {
      return null;
    }

    try {
      switch (eventType) {
        case 'meta':
          final jsonData = jsonDecode(data);
          final products = List<Map<String, dynamic>>.from(
            jsonData['products'] ?? [],
          );
          return MetaEvent(products: products);

        case 'token':
          final jsonData = jsonDecode(data);
          final token = jsonData['token']?.toString() ?? '';
          return TokenEvent(token: token);

        case 'done':
          return const DoneEvent();

        case 'error':
          final jsonData = jsonDecode(data);
          final message = jsonData['message']?.toString() ?? '未知错误';
          return ErrorEvent(message: message);

        default:
          // 尝试解析为 JSON 判断类型
          try {
            final jsonData = jsonDecode(data);
            if (jsonData.containsKey('products')) {
              final products = List<Map<String, dynamic>>.from(
                jsonData['products'] ?? [],
              );
              return MetaEvent(products: products);
            } else if (jsonData.containsKey('token')) {
              final token = jsonData['token']?.toString() ?? '';
              return TokenEvent(token: token);
            } else if (jsonData.containsKey('done')) {
              return const DoneEvent();
            } else if (jsonData.containsKey('message')) {
              final message = jsonData['message']?.toString() ?? '未知错误';
              return ErrorEvent(message: message);
            }
          } catch (_) {
            // 不是 JSON，直接作为 token 返回
            return TokenEvent(token: data);
          }
          return null;
      }
    } catch (e) {
      return ErrorEvent(message: '解析错误: $e');
    }
  }
}

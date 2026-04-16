import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../auth_manager.dart';
import '../models/chat_message.dart';
import 'chat_api_service.dart';

/// WebSocket 连接管理器
///
/// 单例模式，管理 WebSocket 连接、重连、心跳、消息收发
class ChatService extends ChangeNotifier {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  // WebSocket 配置
  static const String _wsBaseUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'ws://127.0.0.1:8001',
  );
  static const String _wsPath = '/ws/chat/';

  // 心跳配置
  static const int _heartbeatInterval = 30; // 秒
  static const int _heartbeatTimeout = 60; // 秒

  // 重连配置（指数退避）
  static const int _maxReconnectDelay = 30; // 最大重连间隔（秒）
  int _currentReconnectDelay = 1; // 当前重连间隔

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  DateTime? _lastPongTime;

  ChatConnectionStatus _status = ChatConnectionStatus.disconnected;
  String? _errorMessage;
  String? _currentUserId; // 当前用户ID

  // 消息流控制器
  final _messageController = StreamController<ChatMessage>.broadcast();
  final _statusController = StreamController<ChatConnectionStatus>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();

  // Getters
  ChatConnectionStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _status == ChatConnectionStatus.connected;

  // 流访问器
  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<ChatConnectionStatus> get statusStream => _statusController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;

  /// 连接到 WebSocket 服务器
  Future<void> connect() async {
    if (_status == ChatConnectionStatus.connecting ||
        _status == ChatConnectionStatus.connected) {
      return;
    }

    _updateStatus(ChatConnectionStatus.connecting);

    try {
      final token = await AuthManager.getToken();
      if (token == null) {
        _handleError('未登录，无法连接聊天服务器');
        return;
      }

      // 获取当前用户ID
      _currentUserId = await AuthManager.getUserId();

      final wsUrl = '$_wsBaseUrl$_wsPath?token=$token';

      if (kIsWeb) {
        // Web 平台使用 HtmlWebSocketChannel
        _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      } else {
        // 移动端使用 IOWebSocketChannel
        _channel = IOWebSocketChannel.connect(
          Uri.parse(wsUrl),
          pingInterval: const Duration(seconds: _heartbeatInterval),
        );
      }

      // 监听消息
      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      _lastPongTime = DateTime.now();
      _startHeartbeat();

      _updateStatus(ChatConnectionStatus.connected);
      _currentReconnectDelay = 1; // 重置重连间隔

    } catch (e) {
      _handleError('连接失败: $e');
      _scheduleReconnect();
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    _cancelTimers();

    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
    }

    _updateStatus(ChatConnectionStatus.disconnected);
  }

  /// 发送聊天消息
  Future<bool> sendMessage({
    required String toUserId,
    required String content,
    String? productId,
    String? orderId,
  }) async {
    if (!isConnected) {
      debugPrint('ChatService: 未连接，无法发送消息');
      return false;
    }

    try {
      final message = {
        'type': 'chat_message',
        'to': toUserId,
        'content': content,
        if (productId != null) 'product_id': productId,
        if (orderId != null) 'order_id': orderId,
      };

      _channel!.sink.add(jsonEncode(message));
      return true;
    } catch (e) {
      debugPrint('ChatService: 发送消息失败: $e');
      return false;
    }
  }

  /// 发送已读回执
  Future<void> sendReadReceipt(String messageId) async {
    if (!isConnected) return;

    try {
      _channel!.sink.add(jsonEncode({
        'type': 'read_receipt',
        'message_id': messageId,
      }));
    } catch (e) {
      debugPrint('ChatService: 发送已读回执失败: $e');
    }
  }

  /// 发送输入状态
  Future<void> sendTypingStatus(String toUserId, bool isTyping) async {
    if (!isConnected) return;

    try {
      _channel!.sink.add(jsonEncode({
        'type': 'typing',
        'to': toUserId,
        'typing': isTyping,
      }));
    } catch (e) {
      debugPrint('ChatService: 发送输入状态失败: $e');
    }
  }

  /// 处理收到的消息
  void _onMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String);
      final type = json['type'] as String?;

      switch (type) {
        case 'chat_message':
          _handleChatMessage(json);
          break;
        case 'pong':
          _lastPongTime = DateTime.now();
          break;
        case 'system':
          debugPrint('ChatService: 系统消息: ${json['message']}');
          break;
        case 'message_sent':
          debugPrint('ChatService: 消息发送成功: ${json['message_id']}');
          break;
        case 'read_receipt':
          // 消息已被对方阅读
          debugPrint('ChatService: 消息已读: ${json['message_id']}');
          break;
        case 'typing':
          _typingController.add({
            'from': json['from'],
            'typing': json['typing'],
          });
          break;
        case 'error':
          debugPrint('ChatService: 服务器错误: ${json['message']}');
          break;
      }
    } catch (e) {
      debugPrint('ChatService: 解析消息失败: $e');
    }
  }

  /// 处理聊天消息
  void _handleChatMessage(Map<String, dynamic> json) {
    try {
      // 后端消息格式: {type: 'chat_message', message_id, from, content, created_at, product_id, order_id}
      // 转换为 ChatMessage 期望的格式
      final message = ChatMessage(
        messageId: json['message_id'] ?? '',
        senderId: json['from'] ?? '',
        receiverId: _currentUserId ?? '',
        content: json['content'] ?? '',
        isRead: false,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
        productId: json['product_id'],
        orderId: json['order_id'],
      );
      _messageController.add(message);
    } catch (e) {
      debugPrint('ChatService: 处理聊天消息失败: $e');
    }
  }

  /// 处理错误
  void _onError(Object error) {
    debugPrint('ChatService: WebSocket 错误: $error');
    _handleError('连接错误');
  }

  /// 连接关闭
  void _onDone() {
    debugPrint('ChatService: WebSocket 连接关闭');
    if (_status != ChatConnectionStatus.disconnected) {
      _scheduleReconnect();
    }
  }

  /// 处理错误并更新状态
  void _handleError(String message) {
    _errorMessage = message;
    _updateStatus(ChatConnectionStatus.error);
  }

  /// 更新状态并通知监听者
  void _updateStatus(ChatConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(newStatus);
      notifyListeners();
    }
  }

  /// 启动心跳
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: _heartbeatInterval),
      (_) => _sendHeartbeat(),
    );
  }

  /// 发送心跳
  void _sendHeartbeat() {
    if (!isConnected) return;

    // 检查心跳超时
    if (_lastPongTime != null) {
      final elapsed = DateTime.now().difference(_lastPongTime!).inSeconds;
      if (elapsed > _heartbeatTimeout) {
        debugPrint('ChatService: 心跳超时，触发重连');
        _scheduleReconnect();
        return;
      }
    }

    try {
      _channel!.sink.add(jsonEncode({'type': 'ping'}));
    } catch (e) {
      debugPrint('ChatService: 发送心跳失败: $e');
      _scheduleReconnect();
    }
  }

  /// 计划重连（指数退避）
  void _scheduleReconnect() {
    if (_status == ChatConnectionStatus.reconnecting) return;

    _updateStatus(ChatConnectionStatus.reconnecting);
    _cancelTimers();

    debugPrint('ChatService: $_currentReconnectDelay 秒后重连...');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _currentReconnectDelay), () {
      // 增加重连间隔（指数退避，最大30秒）
      _currentReconnectDelay = (_currentReconnectDelay * 2).clamp(1, _maxReconnectDelay);
      connect();
    });
  }

  /// 取消所有定时器
  void _cancelTimers() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// 销毁服务
  void dispose() {
    disconnect();
    _messageController.close();
    _statusController.close();
    _typingController.close();
    super.dispose();
  }
}
